-- Exercice 1 : exploration des données brutes (voir exercices/01-exploration.md)
-- Lancer : uv run python -m pipeline.db run sql/exploration/01_exploration.sql

-- Q1 (exemple résolu) : volume global
SELECT
    count(*)                    AS lignes,
    count(DISTINCT uid)         AS marches,
    count(DISTINCT acheteur_id) AS acheteurs
FROM raw_decp;

-- Q2 : à toi de jouer
