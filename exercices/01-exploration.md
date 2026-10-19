# Exercice 1 — Explorer les données brutes

**Objectif :** comprendre ce que contient `raw_decp` *avant* de nettoyer quoi que ce soit.
Chaque observation que tu notes ici deviendra une règle de nettoyage à l'exercice 2.

**Où écrire :** `sql/exploration/01_exploration.sql` (Q1 est déjà résolue comme modèle).
**Lancer :** `uv run python -m pipeline.db run sql/exploration/01_exploration.sql`

Commence chaque requête par un commentaire `-- Q2 : ...` : il s'affichera au-dessus du résultat.
La liste des colonnes et leur signification : `schema.md` (ou `DESCRIBE raw_decp;`).

---

## Q2 — Pourquoi plus de lignes que de marchés ?

Q1 montre ~162 000 lignes pour ~106 000 marchés (`uid`). Quelque chose se répète.

1. Compte le nombre de lignes par `uid`, et affiche les 10 `uid` qui en ont le plus.
2. Prends un de ces `uid` et affiche toutes ses lignes avec seulement quelques colonnes utiles :
   `titulaire_nom`, `montant`, `modification_id`, `donneesActuelles`, `dateNotification`.
3. Écris en une phrase ce qui fait qu'un marché occupe plusieurs lignes.

> Indices : `GROUP BY uid`, `count(*)`, `ORDER BY ... DESC LIMIT 10`, puis `WHERE uid = '...'`.

## Q3 — Le piège des montants dupliqués

Filtre sur `donneesActuelles` (la version à jour de chaque marché).

1. Combien de `uid` ont **plus d'une** ligne actuelle ? (Une sous-requête ou `HAVING` aide.)
2. Sur un de ces marchés, regarde la colonne `montant` ligne par ligne. Que remarques-tu ?
3. Conséquence : que se passerait-il si on faisait `sum(montant)` directement sur ces lignes ?
   Comment faudrait-il compter le montant d'un marché ?

> C'est **la** question à savoir expliquer en entretien.

## Q4 — Les dates

Sur `dateNotification` :

1. La plus ancienne, la plus récente, et le nombre de valeurs vides (`IS NULL`).
2. Combien de marchés par année (`year(dateNotification)`) ? À partir de quelle année
   les données te semblent-elles fiables ?
3. Quelle règle proposes-tu pour les dates absurdes ?

## Q5 — Les montants

1. Minimum, médiane (`median()`), maximum de `montant`. Pourquoi la médiane plutôt que la moyenne ici ?
2. Combien de montants vides, nuls ou négatifs ?
3. Les 10 plus gros montants, avec `acheteur_nom` et `objet`. Lesquels te paraissent crédibles,
   lesquels non ? Pourquoi ?
4. Compare avec la colonne `montant_anomalie` déjà fournie : a-t-elle repéré tes suspects ?

## Q6 — La répartition

1. Nombre de marchés actuels par `type` (Travaux / Services / Fournitures).
2. Nombre de marchés et montant médian par `acheteur_departement_nom`.

---

## Mes observations

*(À remplir au fur et à mesure — une ligne par problème trouvé, c'est la liste de
travail de l'exercice 2.)*

| # | Colonne | Problème observé | Nb de lignes | Règle proposée |
|---|---------|------------------|-------------:|----------------|
| 1 |         |                  |              |                |

Quand tu as fini, montre-moi ton fichier SQL et ce tableau : je relis, on discute, puis on passe au nettoyage.
