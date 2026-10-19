-- Étape 2a : staging — nettoyage ligne à ligne (explications : etapes/02-modele.md)
--
-- Même grain que la source : une ligne par marché × titulaire × modification.
-- On ne supprime rien ici : on normalise, on type, et on remplace les valeurs
-- inexploitables par NULL en gardant la valeur brute à côté quand elle compte.

CREATE OR REPLACE MACRO sans_accent(s) AS lower(strip_accents(replace(replace(s, '’', ''''), ' d offres', ' d''offres')));

CREATE OR REPLACE TABLE stg_decp AS
SELECT
    -- Identifiants et version
    uid,
    -- 16 marchés n'ont ni numéro de version ni indicateur « actuel » (règle 8) :
    -- s'ils n'ont aucune autre version, leur ligne est à la fois l'initiale et l'actuelle
    coalesce(modification_id, 0) AS modification_id,
    coalesce(donneesActuelles, bool_or(donneesActuelles) OVER (PARTITION BY uid) IS NULL) AS est_actuelle,
    acheteur_id,
    titulaire_id,
    CASE upper(replace(titulaire_typeIdentifiant, '-', '_'))
        WHEN 'SIRET' THEN 'SIRET'
        WHEN 'TVA_INTRACOMMUNAUTAIRE' THEN 'TVA'
        ELSE upper(replace(titulaire_typeIdentifiant, '-', '_'))
    END AS titulaire_type_identifiant,

    -- Texte : le « ¿ » vient d'une apostrophe mal encodée à la source (règle 7)
    nullif(trim(replace(objet, '¿', '''')), '') AS objet,

    -- Catégories : même valeur écrite de plusieurs façons → un seul libellé
    CASE sans_accent(nature)
        WHEN 'marche' THEN 'Marché'
        WHEN 'accord-cadre' THEN 'Accord-cadre'
        WHEN 'marche subsequent' THEN 'Marché subséquent'
        WHEN 'marche de partenariat' THEN 'Marché de partenariat'
        WHEN 'marche de defense ou de securite' THEN 'Marché de défense ou de sécurité'
        ELSE 'Non renseignée'
    END AS nature,
    coalesce(type, 'Non catégorisé') AS type,
    CASE
        WHEN procedure IS NULL THEN 'Non renseignée'
        WHEN sans_accent(procedure) = 'procedure adaptee' THEN 'Procédure adaptée'
        WHEN sans_accent(procedure) = 'appel d''offres ouvert' THEN 'Appel d''offres ouvert'
        WHEN sans_accent(procedure) = 'appel d''offres restreint' THEN 'Appel d''offres restreint'
        WHEN sans_accent(procedure) LIKE '%sans publicite ni mise en concurrence%' THEN 'Sans publicité ni mise en concurrence'
        WHEN sans_accent(procedure) = 'procedure concurrentielle avec negociation' THEN 'Procédure concurrentielle avec négociation'
        WHEN sans_accent(procedure) = 'procedure avec negociation' THEN 'Procédure avec négociation'
        WHEN sans_accent(procedure) = 'procedure negociee avec mise en concurrence prealable' THEN 'Procédure négociée avec mise en concurrence'
        WHEN sans_accent(procedure) = 'dialogue competitif' THEN 'Dialogue compétitif'
        ELSE procedure
    END AS procedure,
    coalesce(formePrix, 'Non renseignée') AS forme_prix,

    -- CPV : 8 chiffres attendus ; la division (2 premiers chiffres) sert de famille d'achat
    codeCPV AS code_cpv,
    CASE WHEN regexp_full_match(codeCPV, '\d{8}') THEN left(codeCPV, 2) END AS cpv_division,

    -- Dates : hors de [2010, aujourd'hui] = saisie impossible (règle 3)
    dateNotification AS date_notification_brute,
    CASE WHEN dateNotification BETWEEN DATE '2010-01-01' AND current_date
         THEN dateNotification END AS date_notification,

    -- Montants (règles 4, 5, 6) : on garde le brut, et un montant « retenu » pour les calculs
    montant AS montant_brut,
    montant_anomalie,
    CASE
        WHEN montant IS NULL THEN 'vide'
        WHEN montant <= 0 THEN 'nul ou négatif'
        WHEN montant = 12311111111 THEN 'valeur bouche-trou'
        WHEN montant_anomalie = 'aberrant' THEN 'aberrant (montant_anomalie)'
    END AS motif_exclusion_montant,
    CASE WHEN montant > 0
          AND montant <> 12311111111
          AND montant_anomalie IS DISTINCT FROM 'aberrant'
         THEN montant END AS montant_retenu,

    -- Durée et concurrence : valeurs impossibles → NULL
    CASE WHEN dureeMois BETWEEN 1 AND 360 THEN dureeMois END AS duree_mois,
    CASE WHEN offresRecues >= 1 THEN offresRecues END AS offres_recues,

    -- Clauses : « Sans objet » = pas de clause ; vide = on ne sait pas (le champ n'existe
    -- que dans le format de publication récent), donc NULL et non « pas de clause »
    considerationsSociales <> 'Sans objet' AS clause_sociale,
    considerationsEnvironnementales <> 'Sans objet' AS clause_environnementale,
    marcheInnovant AS marche_innovant,
    sousTraitanceDeclaree AS sous_traitance_declaree,
    idAccordCadre AS id_accord_cadre,
    titulaire_distance AS titulaire_distance_km,

    -- Attributs repris tels quels pour les dimensions
    acheteur_nom, acheteur_categorie, acheteur_commune_code, acheteur_commune_nom,
    acheteur_departement_code, acheteur_departement_nom,
    acheteur_latitude, acheteur_longitude, acheteur_population,
    titulaire_nom, titulaire_categorie, titulaire_activite_code, titulaire_activite_libelle,
    titulaire_commune_code, titulaire_commune_nom,
    titulaire_departement_code, titulaire_departement_nom,
    titulaire_region_code, titulaire_region_nom,
    datePublicationDonnees AS date_publication
FROM raw_decp;
