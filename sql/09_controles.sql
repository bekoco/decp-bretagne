-- Étape 2d : contrôles qualité, rejoués à chaque build (explications : etapes/02-modele.md)
--
-- Chaque ligne est un test : ce qu'on attend, ce qu'on observe. Le build échoue si un test
-- est faux — on préfère une erreur visible à un tableau de bord silencieusement faux.

CREATE OR REPLACE TABLE controles AS
WITH c AS (
    SELECT 'Un marché = une ligne dans fact_marche' AS controle,
           (SELECT count(*) - count(DISTINCT uid) FROM fact_marche) AS ecart
    UNION ALL
    SELECT 'Aucun marché perdu entre la source et fact_marche',
           (SELECT count(DISTINCT uid) FROM raw_decp) - (SELECT count(*) FROM fact_marche)
    UNION ALL
    SELECT 'Un couple marché × titulaire = une ligne dans le lien',
           (SELECT count(*) - count(DISTINCT (uid, titulaire_id)) FROM lien_marche_titulaire)
    UNION ALL
    SELECT 'Chaque marché a au moins un titulaire dans le lien',
           (SELECT count(*) FROM fact_marche f WHERE NOT EXISTS (SELECT 1 FROM lien_marche_titulaire l WHERE l.uid = f.uid))
    UNION ALL
    SELECT 'Chaque acheteur des faits existe dans dim_acheteur',
           (SELECT count(*) FROM fact_marche f ANTI JOIN dim_acheteur d USING (acheteur_id))
    UNION ALL
    SELECT 'Chaque titulaire du lien existe dans dim_titulaire',
           (SELECT count(*) FROM lien_marche_titulaire l ANTI JOIN dim_titulaire d USING (titulaire_id))
    UNION ALL
    SELECT 'Chaque famille CPV des faits existe dans dim_cpv',
           (SELECT count(*) FROM fact_marche f ANTI JOIN dim_cpv d USING (cpv_division))
    UNION ALL
    SELECT 'Chaque date des faits existe dans dim_date',
           (SELECT count(*) FROM fact_marche f ANTI JOIN dim_date d ON f.date_notification = d.date WHERE f.date_notification IS NOT NULL)
    UNION ALL
    SELECT 'Aucun montant retenu nul, négatif ou bouche-trou',
           (SELECT count(*) FROM fact_marche WHERE montant <= 0 OR montant = 12311111111)
    UNION ALL
    SELECT 'Clés uniques dans les dimensions',
           (SELECT count(*) - count(DISTINCT acheteur_id) FROM dim_acheteur)
         + (SELECT count(*) - count(DISTINCT titulaire_id) FROM dim_titulaire)
         + (SELECT count(*) - count(DISTINCT cpv_division) FROM dim_cpv)
)
SELECT controle, ecart, ecart = 0 AS ok FROM c;
