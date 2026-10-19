# Marchés publics Bretagne

Pipeline ETL et tableau de bord sur la commande publique en Bretagne : qui achète quoi,
à qui, pour combien, et avec quelle concurrence.

**Données :** [Données essentielles de la commande publique (DECP) consolidées](https://www.data.gouv.fr/fr/datasets/donnees-essentielles-de-la-commande-publique-consolidees-format-tabulaire/),
publiées sur data.gouv.fr sous Licence Ouverte v2.0. Aucune donnée inventée : seules
les lignes dont l'acheteur est situé en Bretagne (région 53) sont extraites.

## Architecture

```
data.gouv.fr (Parquet national, ~250 Mo)
        │  extract.py : lecture distante, filtre région 53
        ▼
data/raw/decp_bretagne.parquet  + source.json (URL, date, nb de lignes)
        │  sql/NN_*.sql : nettoyage, dédoublonnage, catégorisation
        ▼
data/decp.duckdb  (tables de faits / dimensions, KPI, anomalies)
        │  export Parquet
        ▼
data/export/*.parquet  →  powerbi/ : tableau de bord Power BI
```

Power BI Desktop lit directement les fichiers Parquet exportés (Obtenir les données → Parquet) :
pas de pilote à installer. Le rapport est enregistré au format projet Power BI (`.pbip`),
en fichiers texte, pour être versionné proprement dans Git.

## Démarrage

Prérequis : [uv](https://docs.astral.sh/uv/) (il installe Python et les dépendances)
et [Power BI Desktop](https://www.microsoft.com/fr-fr/power-platform/products/power-bi/desktop) (gratuit, Windows) pour le tableau de bord.

```bash
uv sync                                   # installe l'environnement
uv run python -m pipeline.extract         # télécharge les marchés bretons
uv run python -m pipeline.db build        # construit la base à partir de sql/
```

Explorer avec un fichier SQL quelconque :

```bash
uv run python -m pipeline.db run sql/exploration/01_exploration.sql
```

## Organisation

| Dossier | Contenu |
|---|---|
| `pipeline/` | Extraction et exécution des fichiers SQL (Python) |
| `sql/` | Transformations, exécutées dans l'ordre (`01_`, `02_`…) par `build`, puis contrôles (`09_`) |
| `sql/seeds/` | Petites tables de référence versionnées (familles CPV) |
| `sql/exploration/` | Requêtes d'exploration, non exécutées par `build` |
| `etapes/` | Une note par étape : ce qui a été fait, pourquoi, et les résultats |
| `powerbi/` | Rapport Power BI au format `.pbip` (à venir) |
| `schema.md` | Description de chaque colonne du jeu DECP |

## Avancement

- [x] Extraction des données bretonnes
- [x] Exploration et liste des problèmes de qualité ([étape 1](etapes/01-exploration.md))
- [x] Nettoyage et modèle en étoile ([étape 2](etapes/02-modele.md))
- [x] KPI en SQL ([étape 3](etapes/03-kpi.md))
- [ ] Export Parquet pour Power BI
- [ ] Tableau de bord Power BI
- [ ] Détection d'anomalies, comparée à `montant_anomalie`
