-- Étape 3 : afficher tous les KPI (explications : etapes/03-kpi.md)
-- Lancer : uv run python -m pipeline.db run sql/exploration/03_kpi.sql

-- KPI 1 — Évolution annuelle
SELECT * FROM kpi_annuel;
-- KPI 2 — Par département
SELECT * FROM kpi_departement;
-- KPI 3 — Concurrence selon la procédure
SELECT * FROM kpi_procedure;
-- KPI 4 — Familles d'achat (10 premières en montant)
SELECT * FROM kpi_famille LIMIT 10;
-- KPI 5 — Taille des entreprises titulaires
SELECT * FROM kpi_taille_entreprise;
-- KPI 6 — Achat local
SELECT * FROM kpi_achat_local;
-- KPI 7 — Avenants
SELECT * FROM kpi_avenants;
-- KPI 8 — Top acheteurs
SELECT acheteur_nom, departement, marches, montant_total FROM kpi_top_acheteurs LIMIT 10;
