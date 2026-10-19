-- Étape 5 : détection d'anomalies sur les montants (explications : etapes/05-anomalies.md)
--
-- Des règles simples et explicables : chaque achat signalé porte la raison du signalement.
-- On travaille sur le montant BRUT (tel que publié), y compris ceux que le nettoyage a
-- écartés, pour pouvoir comparer honnêtement à la colonne de référence montant_anomalie.

-- Base : les achats de la période d'analyse avec un montant publié positif.
-- Le code CPV donne des niveaux de pairs de plus en plus fins :
-- division (2 chiffres) > groupe (3) > classe (4). Ex. 45 Travaux > 452 Ouvrages > 4521 Bâtiments.
CREATE OR REPLACE TEMP TABLE base_anomalie AS
SELECT uid, cpv_division, left(code_cpv, 3) AS cpv_groupe, left(code_cpv, 4) AS cpv_classe,
       type, procedure, montant_brut, montant_initial, nb_modifications,
       montant_anomalie, log10(montant_brut) AS lg
FROM v_marche
WHERE montant_brut > 0;

-- Règle 1 : montant hors norme par rapport à ses pairs.
-- Les montants s'étalent sur plusieurs ordres de grandeur : on travaille en log10.
-- Écart robuste (« z modifié », Iglewicz & Hoaglin) : 0,6745 × (x − médiane) / MAD,
-- où MAD = médiane des écarts absolus à la médiane. Contrairement à la moyenne et à l'écart-type,
-- la médiane et la MAD ne sont pas tirées par les valeurs extrêmes qu'on cherche justement.
-- Statistiques par niveau de pairs : médiane, MAD, effectif
CREATE OR REPLACE TEMP TABLE stats_pairs AS
WITH niveaux AS (
    SELECT 1 AS niveau, cpv_classe AS pair, lg FROM base_anomalie
    UNION ALL SELECT 2, cpv_groupe, lg FROM base_anomalie
    UNION ALL SELECT 3, cpv_division, lg FROM base_anomalie
    UNION ALL SELECT 4, type, lg FROM base_anomalie
),
med AS (SELECT niveau, pair, median(lg) AS med, count(*) AS n FROM niveaux GROUP BY ALL)
SELECT m.niveau, m.pair, m.med, m.n, median(abs(x.lg - m.med)) AS mad
FROM med m JOIN niveaux x USING (niveau, pair)
GROUP BY ALL;

CREATE OR REPLACE TABLE anomalie AS
WITH candidats AS (
    -- Pour chaque achat, le niveau de pairs le plus fin qui compte au moins 30 achats
    -- (en dessous, la médiane et la MAD ne sont pas une référence fiable)
    SELECT b.*, s.niveau, s.med AS ref_med, s.mad AS ref_mad,
           row_number() OVER (PARTITION BY b.uid ORDER BY s.niveau) AS rang
    FROM base_anomalie b
    JOIN stats_pairs s
      ON s.pair = CASE s.niveau WHEN 1 THEN b.cpv_classe WHEN 2 THEN b.cpv_groupe
                                WHEN 3 THEN b.cpv_division ELSE b.type END
    WHERE s.n >= 30 AND s.mad > 0
),
scores AS (
    SELECT *, ['classe CPV', 'groupe CPV', 'division CPV', 'type de marché'][niveau] AS pairs
    FROM candidats WHERE rang = 1
),
regles AS (
    SELECT
        uid, montant_brut, montant_anomalie, pairs,
        round(0.6745 * (lg - ref_med) / ref_mad, 2) AS z_modifie,
        -- Règle 1 : seuil classique |z| > 3,5
        coalesce(abs(0.6745 * (lg - ref_med) / ref_mad) > 3.5, false) AS r_hors_norme,
        -- Règle 2 : au moins 6 chiffres identiques à la suite (hors zéros), sur un montant ≥ 1 M€
        coalesce(montant_brut >= 1e6 AND regexp_matches(CAST(CAST(montant_brut AS HUGEINT) AS VARCHAR), '1{6,}|2{6,}|3{6,}|4{6,}|5{6,}|6{6,}|7{6,}|8{6,}|9{6,}'), false) AS r_chiffres_repetes,
        -- Règle 3 : les avenants ont plus que doublé le montant initial
        -- (une règle répond toujours oui ou non : coalesce transforme « on ne sait pas » en non)
        coalesce(nb_modifications > 0 AND montant_initial > 0 AND montant_brut >= 2 * montant_initial, false) AS r_avenant_x2,
        -- Règle 4 : procédure adaptée (réservée aux montants sous les seuils européens) avec un
        -- montant de plus du double du seuil : 5 538 000 € HT en travaux, 221 000 € HT en
        -- fournitures et services (seuils 2024-2025 des collectivités)
        coalesce(procedure = 'Procédure adaptée'
          AND montant_brut > 2 * CASE WHEN type = 'Travaux' THEN 5538000 ELSE 221000 END, false) AS r_procedure_montant
    FROM scores
)
SELECT
    *,
    (r_hors_norme::INT + r_chiffres_repetes::INT + r_avenant_x2::INT + r_procedure_montant::INT) AS nb_regles,
    concat_ws(' · ',
        CASE WHEN r_hors_norme THEN CASE WHEN z_modifie > 0 THEN 'Montant très élevé' ELSE 'Montant très faible' END || ' pour sa ' || pairs || ' (z = ' || z_modifie || ')' END,
        CASE WHEN r_chiffres_repetes THEN 'Chiffres répétés' END,
        CASE WHEN r_avenant_x2 THEN 'Avenants : montant plus que doublé' END,
        CASE WHEN r_procedure_montant THEN 'Procédure adaptée au-dessus des seuils' END
    ) AS raisons
FROM regles;

-- Comparaison avec la référence : notre signalement vs montant_anomalie (aberrant ou suspect)
CREATE OR REPLACE VIEW comparaison_anomalie AS
SELECT
    nb_regles > 0                       AS signale_par_nous,
    montant_anomalie IS NOT NULL        AS signale_par_reference,
    count(*)                            AS achats
FROM anomalie
GROUP BY ALL
ORDER BY ALL;

-- Une ligne par règle déclenchée (un achat peut en déclencher plusieurs) : pour compter par règle
CREATE OR REPLACE VIEW v_signalement AS
SELECT uid, 'Montant trop élevé' AS regle FROM anomalie WHERE r_hors_norme AND z_modifie > 0
UNION ALL SELECT uid, 'Montant trop faible' FROM anomalie WHERE r_hors_norme AND z_modifie < 0
UNION ALL SELECT uid, 'Chiffres répétés' FROM anomalie WHERE r_chiffres_repetes
UNION ALL SELECT uid, 'Avenants ×2' FROM anomalie WHERE r_avenant_x2
UNION ALL SELECT uid, 'MAPA hors seuils' FROM anomalie WHERE r_procedure_montant;
