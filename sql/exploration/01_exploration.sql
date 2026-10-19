-- Étape 1 : exploration des données brutes (explications : etapes/01-exploration.md)
-- Lancer : uv run python -m pipeline.db run sql/exploration/01_exploration.sql

-- Q1 : volume global
SELECT
    count(*)                    AS lignes,
    count(DISTINCT uid)         AS marches,
    count(DISTINCT acheteur_id) AS acheteurs
FROM raw_decp;

-- Q2a : les marchés qui occupent le plus de lignes
SELECT uid, count(*) AS lignes
FROM raw_decp
GROUP BY uid
ORDER BY lignes DESC
LIMIT 10;

-- Q2b : distribution du nombre de lignes par marché
SELECT lignes_par_marche, count(*) AS marches
FROM (SELECT uid, count(*) AS lignes_par_marche FROM raw_decp GROUP BY uid)
GROUP BY lignes_par_marche
ORDER BY lignes_par_marche
LIMIT 10;

-- Q2c : détail d'un marché à plusieurs lignes (titulaires x modifications)
SELECT titulaire_nom, montant, modification_id, donneesActuelles, dateNotification
FROM raw_decp
WHERE uid = (
    SELECT uid FROM raw_decp
    GROUP BY uid
    HAVING count(DISTINCT titulaire_id) > 1 AND max(modification_id) > 0
    ORDER BY count(*) DESC
    LIMIT 1
)
ORDER BY modification_id, titulaire_nom;

-- Q3a : marchés ayant plus d'une ligne « actuelle »
SELECT count(*) AS marches_multi_titulaires
FROM (
    SELECT uid FROM raw_decp
    WHERE donneesActuelles
    GROUP BY uid
    HAVING count(*) > 1
);

-- Q3b : sur ces marchés, le montant est-il le même sur chaque ligne ?
SELECT
    count(*) FILTER (WHERE nb_montants = 1) AS montant_repete,
    count(*) FILTER (WHERE nb_montants > 1) AS montants_differents
FROM (
    SELECT uid, count(DISTINCT montant) AS nb_montants
    FROM raw_decp
    WHERE donneesActuelles
    GROUP BY uid
    HAVING count(*) > 1
);

-- Q3c : l'erreur à ne pas faire : somme naïve contre somme d'un montant par marché
SELECT
    round(sum(montant) / 1e9, 2) AS somme_naive_md_eur,
    round(sum(montant) FILTER (WHERE rang = 1) / 1e9, 2) AS somme_par_marche_md_eur
FROM (
    SELECT montant, row_number() OVER (PARTITION BY uid ORDER BY titulaire_id) AS rang
    FROM raw_decp
    WHERE donneesActuelles
);

-- Q4a : bornes et trous dans les dates de notification
SELECT
    min(dateNotification) AS plus_ancienne,
    max(dateNotification) AS plus_recente,
    count(*) FILTER (WHERE dateNotification IS NULL) AS vides,
    count(*) FILTER (WHERE dateNotification < DATE '2018-01-01') AS avant_2018
FROM raw_decp;

-- Q4b : marchés (version actuelle) par année de notification
SELECT year(dateNotification) AS annee, count(DISTINCT uid) AS marches
FROM raw_decp
WHERE donneesActuelles AND dateNotification >= DATE '2015-01-01'
GROUP BY annee
ORDER BY annee;

-- Q5a : distribution des montants
SELECT
    min(montant) AS minimum,
    round(median(montant)) AS mediane,
    round(avg(montant)) AS moyenne,
    max(montant) AS maximum,
    count(*) FILTER (WHERE montant IS NULL) AS vides,
    count(*) FILTER (WHERE montant = 0) AS nuls,
    count(*) FILTER (WHERE montant < 0) AS negatifs
FROM raw_decp;

-- Q5b : les 10 plus gros montants et le verdict de montant_anomalie
SELECT * FROM (
    SELECT DISTINCT ON (uid)
        montant, acheteur_nom, left(objet, 60) AS objet, montant_anomalie
    FROM raw_decp
    WHERE donneesActuelles
)
ORDER BY montant DESC NULLS LAST
LIMIT 10;

-- Q5c : ce que la colonne montant_anomalie signale déjà
SELECT montant_anomalie, montant_anomalie_raisons, count(*) AS lignes
FROM raw_decp
WHERE montant_anomalie IS NOT NULL
GROUP BY ALL
ORDER BY lignes DESC
LIMIT 10;

-- Q6a : répartition par type de marché
SELECT type, count(DISTINCT uid) AS marches, round(median(montant)) AS montant_median
FROM raw_decp
WHERE donneesActuelles
GROUP BY type
ORDER BY marches DESC;

-- Q6b : répartition par département de l'acheteur
SELECT acheteur_departement_nom, count(DISTINCT uid) AS marches, round(median(montant)) AS montant_median
FROM raw_decp
WHERE donneesActuelles
GROUP BY acheteur_departement_nom
ORDER BY marches DESC
