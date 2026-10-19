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
data/decp.duckdb  (tables de faits / dimensions, vues KPI)
        │
        ▼
app/ : tableau de bord Streamlit  +  détection d'anomalies
```

## Démarrage

Prérequis : [uv](https://docs.astral.sh/uv/) (il installe Python et les dépendances).

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
| `sql/` | Transformations, exécutées dans l'ordre (`01_`, `02_`…) par `build` |
| `sql/exploration/` | Requêtes d'exploration, non exécutées par `build` |
| `exercices/` | Étapes du projet et observations |
| `app/` | Tableau de bord Streamlit (à venir) |
| `schema.md` | Description de chaque colonne du jeu DECP |

## Avancement

- [x] Extraction des données bretonnes
- [ ] Exploration et liste des problèmes de qualité
- [ ] Nettoyage et modèle en étoile
- [ ] KPI en SQL
- [ ] Tableau de bord Streamlit
- [ ] Détection d'anomalies, comparée à `montant_anomalie`
