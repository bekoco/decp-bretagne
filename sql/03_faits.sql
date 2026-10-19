-- Étape 2c : tables de faits (explications : etapes/02-modele.md)
--
-- fact_marche      : une ligne par marché (uid), dans sa version actuelle.
-- lien_marche_titulaire : une ligne par couple marché × titulaire.
-- Le montant est porté UNIQUEMENT par fact_marche : c'est ce qui évite le double compte (règle 2).

-- Ce qu'on sait d'un marché sur toute son histoire (version initiale, nombre d'avenants)
CREATE OR REPLACE TEMP TABLE historique AS
SELECT
    uid,
    min(date_notification) FILTER (WHERE modification_id = 0) AS date_notification,
    max(montant_retenu)    FILTER (WHERE modification_id = 0) AS montant_initial,
    max(modification_id)                                      AS nb_modifications,
    count(DISTINCT titulaire_id) FILTER (WHERE est_actuelle)  AS nb_titulaires
FROM stg_decp
GROUP BY uid;

-- La version actuelle, ramenée à une ligne par marché (les titulaires partent dans le lien)
CREATE OR REPLACE TEMP TABLE actuel AS
SELECT DISTINCT ON (uid) *
FROM stg_decp
WHERE est_actuelle
ORDER BY uid, titulaire_id;

CREATE OR REPLACE TABLE fact_marche AS
SELECT
    a.uid,
    a.acheteur_id,
    CASE WHEN a.cpv_division IN (SELECT cpv_division FROM dim_cpv) THEN a.cpv_division ELSE '??' END AS cpv_division,
    a.code_cpv,
    h.date_notification,                                   -- date d'attribution (modification 0)
    CASE WHEN h.nb_modifications > 0 THEN a.date_notification END AS date_derniere_modification,
    a.objet,
    a.nature,
    a.type,
    a.procedure,
    a.forme_prix,
    a.duree_mois,
    a.offres_recues,
    h.nb_titulaires,
    h.nb_modifications,
    h.montant_initial,
    a.montant_retenu AS montant,                           -- montant actuel, avenants compris
    a.montant_brut,
    a.motif_exclusion_montant,
    a.montant_anomalie,
    a.clause_sociale,
    a.clause_environnementale,
    a.marche_innovant,
    a.sous_traitance_declaree,
    a.id_accord_cadre
FROM actuel a
JOIN historique h USING (uid);

CREATE OR REPLACE TABLE lien_marche_titulaire AS
SELECT
    uid,
    coalesce(titulaire_id, 'INCONNU') AS titulaire_id,
    max(titulaire_distance_km) AS titulaire_distance_km  -- 3 couples ont la distance sur une ligne, vide sur l'autre
FROM stg_decp
WHERE est_actuelle
GROUP BY ALL;
