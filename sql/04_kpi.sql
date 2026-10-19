-- Étape 3 : indicateurs (KPI) en SQL (explications : etapes/03-kpi.md)
--
-- Des vues, pas des tables : elles se recalculent à chaque lecture à partir du modèle.
-- Elles servent aussi de valeurs de référence pour vérifier les mesures Power BI.
--
-- Conventions :
--   * période d'analyse : marchés attribués depuis 2019 (avant, la publication est trop rare) ;
--   * un taux est toujours calculé sur les marchés où l'information existe,
--     et accompagné de sa « couverture » (part des marchés où elle existe) ;
--   * montants en euros HT ; ce sont souvent des maximums d'accords-cadres, pas des dépenses ;
--   * un achat publié plusieurs fois (est_doublon_probable) n'est compté qu'une fois.

-- Base commune : un achat + ses attributs de dimension, sur la période d'analyse
CREATE OR REPLACE VIEW v_marche AS
SELECT
    f.*,
    year(f.date_notification)            AS annee,
    year(f.date_notification) < year(current_date) AS annee_complete,
    a.acheteur_nom,
    a.acheteur_categorie,
    a.departement,
    c.famille_achat
FROM fact_marche f
JOIN dim_acheteur a USING (acheteur_id)
JOIN dim_cpv c USING (cpv_division)
WHERE f.date_notification >= DATE '2019-01-01'
  AND NOT f.est_doublon_probable;

-- Macros : la même définition de chaque taux partout (une seule source de vérité)
CREATE OR REPLACE MACRO taux_offre_unique(offres) AS
    round(100.0 * count(*) FILTER (WHERE offres = 1) / nullif(count(offres), 0), 1);
CREATE OR REPLACE MACRO couverture(col) AS
    round(100.0 * count(col) / count(*), 1);

-- KPI 1 — Évolution annuelle
CREATE OR REPLACE VIEW kpi_annuel AS
SELECT
    annee,
    annee_complete,
    count(*)                                              AS marches,
    round(sum(montant))                                   AS montant_total,
    round(median(montant))                                AS montant_median,
    taux_offre_unique(offres_recues)                      AS taux_offre_unique_pct,
    couverture(offres_recues)                             AS couverture_offres_pct,
    round(100.0 * avg(clause_environnementale::INT), 1)   AS part_clause_env_pct,
    round(100.0 * avg(clause_sociale::INT), 1)            AS part_clause_sociale_pct,
    couverture(clause_environnementale)                   AS couverture_clauses_pct
FROM v_marche
GROUP BY annee, annee_complete
ORDER BY annee;

-- KPI 2 — Par département de l'acheteur
CREATE OR REPLACE VIEW kpi_departement AS
SELECT
    departement,
    count(*)                         AS marches,
    round(sum(montant))              AS montant_total,
    round(median(montant))           AS montant_median,
    taux_offre_unique(offres_recues) AS taux_offre_unique_pct,
    couverture(offres_recues)        AS couverture_offres_pct
FROM v_marche
GROUP BY departement
ORDER BY marches DESC;

-- KPI 3 — Concurrence selon la procédure
CREATE OR REPLACE VIEW kpi_procedure AS
SELECT
    procedure,
    count(*)                                         AS marches,
    round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS part_marches_pct,
    median(offres_recues)                            AS offres_mediane,
    taux_offre_unique(offres_recues)                 AS taux_offre_unique_pct,
    couverture(offres_recues)                        AS couverture_offres_pct
FROM v_marche
GROUP BY procedure
ORDER BY marches DESC;

-- KPI 4 — Familles d'achat
CREATE OR REPLACE VIEW kpi_famille AS
SELECT
    cpv_division,
    famille_achat,
    count(*)                         AS marches,
    round(sum(montant))              AS montant_total,
    round(median(montant))           AS montant_median,
    taux_offre_unique(offres_recues) AS taux_offre_unique_pct,
    couverture(offres_recues)        AS couverture_offres_pct
FROM v_marche
GROUP BY ALL
ORDER BY montant_total DESC NULLS LAST;

-- Attributions : un couple achat × titulaire, avec le montant VENTILÉ à parts égales
-- entre co-titulaires (sinon on retomberait dans le double compte de l'étape 1).
-- Les titulaires des publications en double sont rattachés à leur achat.
CREATE OR REPLACE VIEW v_attribution AS
WITH titulaires_achat AS (
    SELECT f.achat_id, l.titulaire_id, max(l.titulaire_distance_km) AS titulaire_distance_km
    FROM fact_marche f
    JOIN lien_marche_titulaire l USING (uid)
    GROUP BY ALL
)
SELECT
    m.uid AS achat_id,
    m.annee,
    m.type,
    m.departement AS departement_acheteur,
    ta.titulaire_id,
    ta.titulaire_distance_km,
    t.taille_entreprise,
    t.est_breton,
    m.montant / count(*) OVER (PARTITION BY m.uid) AS montant_ventile
FROM v_marche m
JOIN titulaires_achat ta ON ta.achat_id = m.uid
JOIN dim_titulaire t USING (titulaire_id);

-- KPI 5 — Taille des entreprises titulaires (PME / ETI / GE)
CREATE OR REPLACE VIEW kpi_taille_entreprise AS
SELECT
    taille_entreprise,
    count(*)                                               AS attributions,
    round(100.0 * count(*) / sum(count(*)) OVER (), 1)     AS part_attributions_pct,
    round(sum(montant_ventile))                            AS montant_ventile,
    round(100.0 * sum(montant_ventile) / sum(sum(montant_ventile)) OVER (), 1) AS part_montant_pct
FROM v_attribution
GROUP BY taille_entreprise
ORDER BY attributions DESC;

-- KPI 6 — Achat local : part des attributions à des entreprises bretonnes
CREATE OR REPLACE VIEW kpi_achat_local AS
SELECT
    type,
    count(*)                                                  AS attributions,
    round(100.0 * avg(est_breton::INT), 1)                    AS part_titulaires_bretons_pct,  -- région connue seulement
    couverture(est_breton)                                    AS couverture_region_pct,
    round(100.0 * sum(montant_ventile) FILTER (WHERE est_breton) / sum(montant_ventile) FILTER (WHERE est_breton IS NOT NULL), 1) AS part_montant_bretons_pct,
    median(titulaire_distance_km)                             AS distance_mediane_km,
    couverture(titulaire_distance_km)                         AS couverture_distance_pct
FROM v_attribution
WHERE titulaire_id <> 'INCONNU'
GROUP BY type
ORDER BY attributions DESC;

-- KPI 7 — Avenants : combien de marchés sont modifiés, et de combien leur montant évolue
CREATE OR REPLACE VIEW kpi_avenants AS
SELECT
    type,
    count(*)                                                        AS marches,
    round(100.0 * avg((nb_modifications > 0)::INT), 1)              AS part_modifies_pct,
    -- mêmes marchés au numérateur et au dénominateur : modifiés, avec les deux montants connus
    round(100.0 * (sum(montant)         FILTER (WHERE nb_modifications > 0 AND montant > 0 AND montant_initial > 0)
                 / sum(montant_initial) FILTER (WHERE nb_modifications > 0 AND montant > 0 AND montant_initial > 0) - 1), 1)
                                                                    AS evolution_montant_modifies_pct,
    round(100.0 * median(montant / montant_initial - 1) FILTER (WHERE nb_modifications > 0 AND montant > 0 AND montant_initial > 0), 1)
                                                                    AS evolution_mediane_pct
FROM v_marche
GROUP BY type
ORDER BY marches DESC;

-- KPI 8 — Les 20 acheteurs qui engagent le plus
CREATE OR REPLACE VIEW kpi_top_acheteurs AS
SELECT
    acheteur_nom,
    acheteur_categorie,
    departement,
    count(*)               AS marches,
    round(sum(montant))    AS montant_total,
    round(median(montant)) AS montant_median
FROM v_marche
GROUP BY ALL
ORDER BY montant_total DESC NULLS LAST
LIMIT 20;
