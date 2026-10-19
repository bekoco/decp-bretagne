# Étape 1 — Explorer les données brutes

**But :** comprendre ce que contient `raw_decp` *avant* de nettoyer quoi que ce soit.
On ne corrige rien ici : on observe, on mesure, et chaque problème trouvé devient une
règle de nettoyage pour l'étape 2.

**Requêtes :** [`sql/exploration/01_exploration.sql`](../sql/exploration/01_exploration.sql)
**Relancer :** `uv run python -m pipeline.db run sql/exploration/01_exploration.sql`

---

## Q1 — Le volume

| Lignes | Marchés (`uid` distincts) | Acheteurs |
|---:|---:|---:|
| 162 513 | 105 915 | 1 711 |

**Concept SQL :** `count(*)` compte les lignes, `count(DISTINCT x)` compte les valeurs
différentes. L'écart entre les deux est le premier signal : **une ligne ≠ un marché**.

## Q2 — Pourquoi plus de lignes que de marchés ?

- 85 280 marchés tiennent sur une ligne, mais certains en ont des centaines (jusqu'à 244).
- En détaillant le pire (Q2c), on voit la mécanique : **4 titulaires × 61 versions**
  (le marché initial `modification_id = 0`, puis 60 avenants) = 244 lignes.

Un marché occupe donc **une ligne par titulaire et par modification**. La colonne
`donneesActuelles = true` marque la dernière version.

**Concepts SQL :** `GROUP BY uid` regroupe les lignes d'un même marché ; une **sous-requête**
(`SELECT ... FROM (SELECT ...)`) permet de compter « combien de marchés ont N lignes » ;
`HAVING` filtre *après* regroupement (là où `WHERE` filtre avant).

## Q3 — Le piège des montants dupliqués ⚠️

Même en ne gardant que la version actuelle, **4 410 marchés ont encore plusieurs lignes** :
une par titulaire (marchés en lots ou en groupement). Et sur 4 405 d'entre eux, **le montant
est recopié à l'identique sur chaque ligne** : c'est le montant du marché, pas la part du titulaire.

| Méthode | Total |
|---|---:|
| `sum(montant)` naïf sur les lignes actuelles | 141,5 Md€ |
| Un seul montant par marché | 125,2 Md€ |

**16 Md€ comptés en double** si on additionne sans réfléchir. C'est *la* chose à savoir
expliquer en entretien : avant toute somme, se demander **quel est le grain de la table**
(une ligne = quoi ?).

**Concept SQL — fonction de fenêtrage :**
`row_number() OVER (PARTITION BY uid ORDER BY titulaire_id)` numérote les lignes *à
l'intérieur de chaque marché* (1, 2, 3…) sans les regrouper. En gardant `rang = 1`,
on obtient exactement une ligne par marché.

> Les totaux restent **indicatifs** : `montant` est souvent un *montant maximum* d'accord-cadre,
> pas ce qui a été réellement payé. On le dira dans le tableau de bord.

## Q4 — Les dates

- Plus ancienne : **an 2** (`0002-09-24`) — une saisie impossible. 275 lignes avant 2018, 782 vides.
- Volume par année : quelques dizaines avant 2018, puis montée rapide à partir de 2019
  (publication obligatoire depuis octobre 2018), ~15 000 à 18 000 marchés par an depuis 2021.

→ On travaillera sur **2019 et après** ; les dates absurdes seront signalées, pas inventées.

## Q5 — Les montants

| Min | Médiane | Moyenne | Max | Vides | Nuls | Négatifs |
|---:|---:|---:|---:|---:|---:|---:|
| −170 000 € | 103 255 € | 1 251 826 € | 12 311 111 111 € | 6 203 | 4 688 | 49 |

- **Médiane vs moyenne :** la moyenne est 12 fois la médiane, tirée vers le haut par quelques
  montants énormes. Sur des données aussi asymétriques, **la médiane décrit mieux le marché typique**.
- **Les plus gros montants :**
  - **12 311 111 111 €** apparaît 5 fois, toujours pour des achats groupés d'électricité ou de gaz
    par des syndicats d'énergie : ce n'est pas un montant, c'est une **valeur bouche-trou**
    (« pas de maximum »). La colonne `montant_anomalie` en repère 4 sur 5 — **elle rate celui du gaz**.
  - 900 M€ de matériel informatique pour les écoles d'une commune : invraisemblable, probablement des zéros en trop.
  - 945 M€ pour le réseau de fibre de Mégalis Bretagne : énorme mais **plausible** (programme Bretagne Très Haut Débit).
    Un montant élevé n'est pas forcément faux.
- **Encodage :** certains textes contiennent `¿` à la place d'une apostrophe (`d¿électricité`) —
  un problème d'encodage à la source.
- `montant_anomalie` signale 362 lignes « aberrant » et 1 757 « suspect », en comparant chaque
  montant à ceux des marchés similaires.

**Concepts SQL :** `FILTER (WHERE ...)` compte un sous-ensemble dans la même requête ;
`DISTINCT ON (uid)` garde une ligne par marché (spécifique à DuckDB/PostgreSQL) ;
un `ORDER BY` placé *dans* la sous-requête ne trie pas le résultat final — il faut le remettre à l'extérieur.

## Q6 — La répartition

| Type | Marchés | Montant médian |
|---|---:|---:|
| Travaux | 51 601 | 98 594 € |
| Services | 30 559 | 77 008 € |
| Fournitures | 23 515 | 67 650 € |
| Non catégorisé | 224 | 93 200 € |

| Département | Marchés | Montant médian |
|---|---:|---:|
| Ille-et-Vilaine | 42 154 | 82 911 € |
| Finistère | 25 738 | 91 006 € |
| Morbihan | 19 473 | 89 016 € |
| Côtes-d'Armor | 18 534 | 77 000 € |

La commande publique bretonne est d'abord une affaire de **travaux** (près d'un marché sur deux).

---

## Ce qu'on retient : règles pour l'étape 2

| # | Problème | Ampleur | Règle de nettoyage |
|---|---|---:|---|
| 1 | Une ligne par titulaire × modification | 162 513 lignes → 105 915 marchés | Table *marchés* = version actuelle, une ligne par `uid` ; table séparée *marché ↔ titulaires* |
| 2 | Montant recopié sur chaque titulaire | 16 Md€ de double compte | Le montant vit dans la table *marchés*, jamais dans la table des titulaires |
| 3 | Dates impossibles ou vides | 275 avant 2018, 782 vides | Champ `date_valide` ; analyses temporelles sur 2019+ |
| 4 | Montants vides, nuls, négatifs | 6 203 / 4 688 / 49 | Mis à `NULL` dans les calculs, conservés et marqués |
| 5 | Valeur bouche-trou 12 311 111 111 € | 5 marchés | Règle explicite, en plus de `montant_anomalie` |
| 6 | Montants aberrants | 362 aberrants, 1 757 suspects | Garder `montant_anomalie` comme référence ; notre propre détection en étape 6 |
| 7 | Caractère `¿` dans les textes | à mesurer | Remplacer par `'` dans `objet`, `titulaire_nom`, `acheteur_nom` |
