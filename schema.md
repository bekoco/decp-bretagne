# Colonnes du jeu DECP consolidé

Généré depuis le schéma officiel publié avec le jeu de données (data.gouv.fr).

| Colonne | Type | Description |
|---|---|---|
| `uid` | string | Concaténation du SIRET de l'acheteur (acheteur_id) et de l'identifiant interne de l'acheteur (id). Utilisé comme identifiant de marché unique au niveau national. |
| `id` | string | Identifiant attribué par l'acheteur, censé être unique au sein de ses marchés. |
| `nature` | string | Marché, Marché de partenariat ou Marché de sécurité. |
| `acheteur_id` | string | Identifiant de l'établissement de l'acheteur (SIRET), référencé dans la base SIRENE de l'INSEE. |
| `acheteur_nom` | string | Nom de l'acheteur tel que renseigné dans la base SIRENE de l'INSEE. |
| `titulaire_id` | string | Identifiant du titulaire du marché. Voir 'Type identifiant' pour le référentiel utilisé |
| `titulaire_typeIdentifiant` | string | Référentiel utilisé pour l'identifiant du titulaire. |
| `titulaire_nom` | string | Nom du titulaire. Nom tel que renseigné dans la base SIRENE de l'INSEE si c'est un SIRET. |
| `objet` | string | Objet du marché public. Potentiellement coupé à 256 ou 1 000 caractères par le producteur de données. |
| `montant` | number | Montant forfaitaire ou montant maximum estimé hors-taxes, en euros. Ce montant est le montant attribué. Le montant final payé aux titulaires peut évoluer lors de la signature du contrat et de l'exécution du marché. |
| `type` | string | Type de marché public : fournitures, services ou travaux (dérivé du code CPV). |
| `codeCPV` | string | Catégorie de bien, service ou travaux achetés, selon le Vocabulaire commun pour les marchés publics (CPV). |
| `procedure` | string | Le type de procédure utilisé pour le marché public. |
| `techniques` | string | Les techniques d'achat utilisées pour le marché public. |
| `dureeMois` | integer | Durée en mois du marché attribué. |
| `dureeRestanteMois` | number | Durée approximative en mois restante dans le marché, en tenant compte de la date de notification et de la durée du marché. Ce nombre ne peut être inférieur à 0. |
| `offresRecues` | integer | Le nombre d'offres reçues pendant la phase d'appel d'offres. Comprend aussi les offres irrégulières, inacceptables, inappropriées et anormalement basses. |
| `dateNotification` | date | Date à laquelle le marché public ou de la modification a été notifiée aux titulaires du marché public. |
| `datePublicationDonnees` | date | Date à laquelle les données du marché public ou de la modification ont été publiées sur data.gouv.fr. |
| `formePrix` | string | La forme du prix du marché public. Unitaire, Forfaitaire ou Mixte. |
| `typesPrix` | string | Les types de prix du marché public. |
| `attributionAvance` | boolean | Si une avance sur le montant du marché public a été attribuée aux titulaires. |
| `tauxAvance` | number | Taux de l'avance attribuée au titulaire principal du marché public par rapport au montant du marché (O.1 = 10 % du montant du marché). En fonction de la valeur de attributionAvance, une valeur égale à 0 signifie qu'il y a une avance mais que le taux n'est pas connu (attributionAvance=true). |
| `marcheInnovant` | boolean | Si le marché comporte des travaux, services ou fournitures innovantes. |
| `modalitesExecution` | string | Les modalités d'exécution du marché public. |
| `considerationsSociales` | string | Les considérations sociales prévues dans le marché public. |
| `considerationsEnvironnementales` | string | Les considérations environnementales prévues dans le marché public. |
| `ccag` | string | Cahier des clauses administratives générales et techniques (CCAG) utilisé pour le marché public. |
| `sousTraitanceDeclaree` | boolean | Au moment de la notification du marché, les titulaires du marché ont déclaré s'appuyer sur un ou plusieurs sous-traitants pour ce marché public. |
| `typeGroupementOperateurs` | string | Le type de groupement d'entreprises ou d'opérateurs économiques. |
| `origineUE` | number | Pour les marchés de fournitures de denrées alimentaires, de véhicules, de produits de santé et d'habillement, selon la liste annexée à l'arrêté du 22 décembre 2022, la part des produits issus de l'Union européenne avec laquelle le marché sera exécuté. 0.2 = 20 % de la part des produits provient de l'Union européenne. Cette valeur ne peut pas être inférieure à la valeur de origineFrance. |
| `origineFrance` | number | Pour les marchés de fournitures de denrées alimentaires, de véhicules, de produits de santé et d'habillement, selon la liste annexée à l'arrêté du 22 décembre 2022, la part des produits français avec laquelle le marché sera exécuté. 0.2 = 20 % de la part des produits sont français. Cette valeur ne peut pas être supérieure à la valeur de origineUE. |
| `lieuExecution_code` | string | Code du lieu d'exécution du marché public. Le type de code est renseigné par 'Type code lieu exécution'. |
| `lieuExecution_typeCode` | string | Type du code du lieu d'exécution. |
| `idAccordCadre` | string | Pour un marché subséquent, l'identifiant interne du marché public relevant de la technique d'achat accord-cadre auquel il est lié. |
| `titulaire_distance` | integer | Distance en kilomètres entre l'adresse de l'acheteur et celle du titulaire. |
| `acheteur_categorie` | string | Catégorie de l'acheteur selon son code juridique INSEE. |
| `acheteur_labels` | string | Labels de l'acheteur, séparés par des virgules : Bio (agriculture biologique), RGE (Reconnu Garant de l'Environnement), ESS (économie sociale et solidaire), Association, Qualiopi (certification qualité des organismes de formation), SIAE (structure d'insertion par l'activité économique), Avocat, Achats responsables. Source : Annuaire des Entreprises. |
| `acheteur_commune_code` | string | Code de la commune où se trouve l'acheteur. |
| `acheteur_commune_nom` | string | Nom de la commune où se trouve l'acheteur. |
| `acheteur_departement_code` | string | Code du département où se trouve l'acheteur. |
| `acheteur_departement_nom` | string | Nom du département où se trouve l'acheteur. |
| `acheteur_region_code` | string | Code de la région où se trouve l'acheteur. |
| `acheteur_region_nom` | string | Nom de la région où se trouve l'acheteur. |
| `acheteur_latitude` | number | Latitude des coordonnées géographiques de l'acheteur. |
| `acheteur_longitude` | number | Longitude des coordonnées géographiques de l'acheteur. |
| `acheteur_population` | integer | Population de l'acheteur s'il s'agit d'une ville. Chiffres de 2024. |
| `titulaire_categorie` | string | Catégorie de l'entreprise titulaire selon la classification de l'INSEE. |
| `titulaire_labels` | string | Labels de l'entreprise titulaire, séparés par des virgules : Bio (agriculture biologique), RGE (Reconnu Garant de l'Environnement), ESS (économie sociale et solidaire), Association, Qualiopi (certification qualité des organismes de formation), SIAE (structure d'insertion par l'activité économique), Avocat, Achats responsables. Source : Annuaire des Entreprises. Le label RGE signale une qualification référencée, sans garantie qu'elle soit encore valide. |
| `titulaire_activite_code` | string | Code d'activité principale (NAF rév. 2) de l'établissement titulaire selon le répertoire SIRENE de l'INSEE. |
| `titulaire_activite_libelle` | string | Libellé long de l'activité principale (NAF rév. 2) de l'établissement titulaire selon le répertoire SIRENE de l'INSEE. |
| `titulaire_commune_code` | string | Code de la commune où se trouve le titulaire. |
| `titulaire_commune_nom` | string | Nom de la commune où se trouve le titulaire. |
| `titulaire_departement_code` | string | Code du département où se trouve le titulaire. |
| `titulaire_departement_nom` | string | Nom du département où se trouve le titulaire. |
| `titulaire_region_code` | string | Code de la région où se trouve le titulaire. |
| `titulaire_region_nom` | string | Nom de la région où se trouve le titulaire. |
| `titulaire_latitude` | number | Latitude des coordonnées géographiques du titulaire. |
| `titulaire_longitude` | number | Longitude des coordonnées géographiques du titulaire. |
| `modification_id` | integer | Identifiant de la modification. 0 = données initiales du marché public, 1 = première modification, etc. |
| `donneesActuelles` | boolean | Si les données de cette ligne sont les données actuelles du marché public, une fois les éventuelles modifications prises en compte. |
| `montant_rationalise` | number | Égal à 'montant' sauf pour les marchés classés 'aberrant' (montant_anomalie='aberrant'), où il prend la valeur de la médiane des marchés similaires. À utiliser pour les agrégations (sommes, moyennes) afin d'éviter le biais des montants saisis erronément. |
| `montant_anomalie` | string | Indique si le montant déclaré est jugé anormal par comparaison avec les marchés similaires. 'suspect' = anomalie possible, montant conservé ; 'aberrant' = anomalie forte, montant remplacé dans 'montant_rationalise'. |
| `montant_anomalie_raisons` | string | Code lisible expliquant le critère ayant déclenché la classification : montant_par_habitant_aberrant, montant_par_habitant_suspect, montant_vs_pairs_aberrant, montant_vs_pairs_suspect, titulaire_incoherent_pme_gros_marche, ou groupe_insuffisant. |
| `sourceDataset` | string | Code du jeu de données dont proviennent les données de ce marché public. |
| `sourceFile` | string | Lien vers le fichier de données ouvertes dont proviennent les données de ce marché public. |
