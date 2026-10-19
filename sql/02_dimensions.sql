-- Étape 2b : dimensions du modèle en étoile (explications : etapes/02-modele.md)
--
-- Une dimension décrit un « qui / quoi / quand » : une ligne par acheteur, par titulaire,
-- par famille d'achat, par jour. Les faits (étape 2c) y font référence par leur clé.

-- Acheteurs : un acheteur apparaît sur des milliers de lignes ; on garde ses attributs
-- les plus récents (arg_max = « la valeur de la ligne où la date est la plus grande »).
CREATE OR REPLACE TABLE dim_acheteur AS
SELECT
    acheteur_id,
    arg_max(acheteur_nom, date_publication)              AS acheteur_nom,
    coalesce(arg_max(acheteur_categorie, date_publication), 'Non renseignée') AS acheteur_categorie,
    arg_max(acheteur_commune_nom, date_publication)      AS commune,
    arg_max(acheteur_departement_code, date_publication) AS departement_code,
    arg_max(acheteur_departement_nom, date_publication)  AS departement,
    arg_max(acheteur_latitude, date_publication)         AS latitude,
    arg_max(acheteur_longitude, date_publication)        AS longitude,
    arg_max(acheteur_population, date_publication)       AS population
FROM stg_decp
GROUP BY acheteur_id;

-- Titulaires : même principe. Les lignes sans identifiant pointent vers un titulaire
-- « INCONNU » plutôt que de disparaître (sinon Power BI perdrait leurs marchés).
CREATE OR REPLACE TABLE dim_titulaire AS
SELECT
    titulaire_id,
    arg_max(titulaire_type_identifiant, date_publication) AS type_identifiant,
    -- Règle 10 : 1 129 identifiants mal formés (ex. SIREN répété) ne sont pas retrouvés dans SIRENE,
    -- donc sans nom. On les nomme explicitement pour qu'ils ne fusionnent pas en une ligne vide.
    coalesce(arg_max(titulaire_nom, date_publication),
             'Non retrouvé dans SIRENE (' || titulaire_id || ')') AS titulaire_nom,
    coalesce(arg_max(titulaire_categorie, date_publication), 'Non renseignée') AS taille_entreprise,
    arg_max(titulaire_activite_code, date_publication)    AS activite_code,
    arg_max(titulaire_activite_libelle, date_publication) AS activite,
    arg_max(titulaire_commune_nom, date_publication)      AS commune,
    arg_max(titulaire_departement_nom, date_publication)  AS departement,
    arg_max(titulaire_region_nom, date_publication)       AS region,
    -- Région inconnue = on ne sait pas (NULL), pas « non breton » : sinon la part d'achat
    -- local serait sous-estimée (65,5 % au lieu de 68,3 %)
    arg_max(titulaire_region_code, date_publication) = '53' AS est_breton
FROM stg_decp
WHERE titulaire_id IS NOT NULL
GROUP BY titulaire_id
UNION ALL
SELECT 'INCONNU', NULL, 'Titulaire non renseigné', 'Non renseignée', NULL, NULL, NULL, NULL, NULL, NULL;

-- Familles d'achat : les 45 divisions de la nomenclature CPV (2 premiers chiffres du code),
-- plus une ligne pour les codes absents ou invalides.
CREATE OR REPLACE TABLE dim_cpv AS
SELECT cpv_division, famille_achat
FROM read_csv('sql/seeds/cpv_divisions.csv', header = true, columns = {'cpv_division': 'VARCHAR', 'famille_achat': 'VARCHAR'})
UNION ALL
SELECT '??', 'Code CPV absent ou non reconnu';

-- Calendrier : un jour par ligne, sans trou, pour les analyses dans le temps.
CREATE OR REPLACE TABLE dim_date AS
SELECT
    d::DATE                                   AS date,
    year(d)                                   AS annee,
    quarter(d)                                AS trimestre,
    month(d)                                  AS mois,
    ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août',
     'septembre', 'octobre', 'novembre', 'décembre'][month(d)] AS mois_nom,
    strftime(d, '%Y-%m')                      AS annee_mois
FROM generate_series(DATE '2010-01-01', last_day(make_date(year(current_date), 12, 1)), INTERVAL 1 DAY) AS t(d);
