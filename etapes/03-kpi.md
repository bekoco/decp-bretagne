# Étape 3 — Les indicateurs (KPI) en SQL

**But :** répondre à des questions concrètes sur la commande publique bretonne, avec des
définitions écrites une fois pour toutes en SQL. Ces vues serviront aussi de **valeurs de
référence** : quand on recréera les mesures dans Power BI, elles devront donner les mêmes chiffres.

**Fichiers :** [`sql/04_kpi.sql`](../sql/04_kpi.sql) (définitions) ·
[`sql/exploration/03_kpi.sql`](../sql/exploration/03_kpi.sql) (affichage)
**Afficher :** `uv run python -m pipeline.db run sql/exploration/03_kpi.sql`

---

## Les règles du jeu

1. **Période : 2019 et après.** Avant, la publication était trop rare (étape 1). 2026 est
   marquée `annee_complete = false` : on ne la compare pas aux années pleines.
2. **Un taux se calcule sur les marchés où l'information existe**, et s'accompagne toujours de
   sa **couverture**. Exemple : le nombre d'offres n'est connu que pour ~55 % des marchés
   jusqu'en 2023, puis ~91 % à partir de 2024 (nouveau format de publication). Sans la
   couverture, on comparerait des années qui ne sont pas comparables.
3. **Les montants sont des ordres de grandeur** : souvent des maximums d'accords-cadres.
   On privilégie la **médiane**, stable, au total, sensible au moindre marché géant.
4. **Un achat publié plusieurs fois n'est compté qu'une fois** (voir ci-dessous).

**Concepts :**
- **Vue** (`CREATE VIEW`) : une requête enregistrée, recalculée à chaque lecture — jamais
  désynchronisée du modèle.
- **Macro** `taux_offre_unique()` : la définition du taux écrite une fois, réutilisée dans
  chaque KPI. Si on change la définition, elle change partout.
- `sum(count(*)) OVER ()` : le total général à côté de chaque groupe, pour calculer une part
  en une seule requête.

## Une découverte en chemin : les publications en double

En lisant le top des acheteurs, le même marché de gaz (165 933 300 €, même date, même objet)
apparaissait **deux fois**, sous deux identifiants. En cherchant systématiquement les marchés
identiques (même acheteur, même date, même montant, même objet) :

| | |
|---:|---|
| 4 477 | groupes de marchés identiques |
| 6 159 | publications « en trop » |
| 9,1 Md€ | comptés en double |

Deux causes :
- **Le même marché remonté par deux sources** de données, avec un identifiant légèrement
  différent (`…2024518452` d'un côté, `…20245184` de l'autre) ;
- **Un accord-cadre publié une fois par lot ou par attributaire**, avec le montant maximum
  global recopié à chaque publication.

**Règle 9 :** ces publications forment **un seul achat** (`achat_id` dans `fact_marche`,
`est_doublon_probable = true` pour les copies). Les KPI comptent l'achat une fois ; ses
titulaires sont tous rattachés à l'achat, et son montant réparti entre eux. Un nouveau
contrôle vérifie que chaque copie pointe bien vers un achat original.

> Limite assumée : deux marchés réellement distincts, passés le même jour par le même acheteur
> pour le même objet et exactement le même montant, seraient fusionnés. C'est très improbable,
> et l'erreur inverse (9 Md€ en double) est bien pire.

J'ai aussi corrigé une erreur de l'étape 2 : un champ « clause environnementale » **vide**
était traité comme « pas de clause ». Or ce champ n'existe que dans le format récent : vide
veut dire « on ne sait pas ». Il vaut maintenant `NULL`, et le KPI affiche sa couverture.

---

## Les résultats

Sur la période : **98 958 achats, 43,6 Md€** (montants retenus, dédoublonnés).

### KPI 1 — Évolution annuelle

| Année | Achats | Montant total | Montant médian | Offre unique | *couv.* | Clause env. | Clause sociale | *couv.* |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 2019 | 3 414 | 1,8 Md€ | 71 171 € | 7,0 % | *10 %* | 0,2 % | 0,2 % | *14 %* |
| 2020 | 10 030 | 2,3 Md€ | 60 140 € | 6,4 % | *57 %* | 0,0 % | 0,0 % | *61 %* |
| 2021 | 13 708 | 2,8 Md€ | 68 902 € | 7,5 % | *54 %* | 0,1 % | 0,1 % | *56 %* |
| 2022 | 14 980 | 5,2 Md€ | 86 561 € | 10,8 % | *52 %* | 1,0 % | 0,7 % | *56 %* |
| 2023 | 14 976 | 5,3 Md€ | 90 000 € | 13,3 % | *56 %* | 3,1 % | 1,5 % | *63 %* |
| 2024 | 15 603 | 15,8 Md€ | 90 000 € | 22,1 % | *91 %* | 26,4 % | 7,6 % | *93 %* |
| 2025 | 16 586 | 7,3 Md€ | 90 873 € | 22,6 % | *91 %* | 33,1 % | 9,6 % | *99 %* |
| 2026 *(partielle)* | 9 661 | 3,1 Md€ | 83 350 € | 21,2 % | *93 %* | 42,0 % | 13,5 % | *100 %* |

**Lecture :**
- **Le pic de 2024 (15,8 Md€) est un seul marché** : la fourniture d'électricité du Syndicat
  départemental d'énergie 35, déclarée à 5,4 Md€ (marquée « suspect » par `montant_anomalie`).
  La médiane, elle, ne bouge pas (90 000 €). Exactement pourquoi on la préfère.
- **L'offre unique passe de 7 % à 22 %… mais la couverture passe de 55 % à 91 % au même
  moment.** On ne peut **pas** conclure que la concurrence a baissé : on mesure surtout un
  changement de format. Seules les années 2024 → 2026 sont comparables entre elles (~22 %).
- **Les clauses environnementales**, elles, progressent **à couverture comparable** : 26 % →
  33 % → 42 % entre 2024 et 2026. C'est une vraie tendance, cohérente avec la loi Climat et
  résilience (2021) qui généralise la prise en compte environnementale dans les marchés publics.

### KPI 2 — Par département de l'acheteur

| Département | Achats | Montant total | Médian | Offre unique |
|---|---:|---:|---:|---:|
| Ille-et-Vilaine | 39 502 | 22,7 Md€ | 79 503 € | 18,9 % |
| Finistère | 23 845 | 7,5 Md€ | 88 825 € | 17,3 % |
| Morbihan | 18 564 | 7,1 Md€ | 90 000 € | 13,2 % |
| Côtes-d'Armor | 17 047 | 6,4 Md€ | 72 610 € | 14,8 % |

L'Ille-et-Vilaine concentre 40 % des achats (Rennes, la Région, le CHU) — et le marché
d'électricité géant du SDE 35, qui gonfle son total.

### KPI 3 — Concurrence selon la procédure

| Procédure | Part des achats | Offres (médiane) | Offre unique |
|---|---:|---:|---:|
| Procédure adaptée | 46,4 % | 3 | 18,6 % |
| Appel d'offres ouvert | 25,6 % | 6 | 11,9 % |
| Non renseignée | 22,5 % | 6 | 9,4 % |
| Sans publicité ni mise en concurrence | 2,9 % | 1 | 92,1 % |
| Procédure avec négociation | 1,6 % | 3 | 15,1 % |

- L'**appel d'offres ouvert** attire deux fois plus d'offres que la procédure adaptée (6 contre 3).
- **Contrôle de bon sens :** les marchés « sans mise en concurrence » ont une offre unique à
  92 % — normal, par définition. Si ce chiffre avait été bas, il aurait signalé un problème
  dans les données ou dans le calcul.

### KPI 4 — Familles d'achat (en montant)

| Famille | Achats | Montant total | Médian | Offre unique |
|---|---:|---:|---:|---:|
| Travaux de construction | 48 435 | 14,9 Md€ | 93 885 € | 13,3 % |
| Énergie (électricité, combustibles) | 1 262 | 9,7 Md€ | 130 059 € | 20,1 % |
| Matériel médical, pharmaceutique | 5 267 | 3,4 Md€ | 37 918 € | 12,7 % |
| Architecture, ingénierie | 9 586 | 1,9 Md€ | 54 170 € | 20,4 % |
| Eaux usées, déchets, environnement | 3 484 | 1,9 Md€ | 100 000 € | 21,5 % |

L'énergie : peu d'achats (1 %), mais un cinquième des montants — ce sont les grands
groupements d'achat d'électricité et de gaz des syndicats d'énergie.

### KPI 5 — Taille des entreprises titulaires

| Taille | Part des attributions | Part des montants |
|---|---:|---:|
| PME | **54,2 %** | **21,6 %** |
| ETI | 21,3 % | 37,7 % |
| Grandes entreprises | 17,0 % | 32,2 % |
| Non renseignée | 7,5 % | 8,5 % |

Les **PME remportent plus d'un marché sur deux, mais à peine plus d'un euro sur cinq** :
elles gagnent beaucoup de petits marchés, les gros vont aux ETI et grandes entreprises.

**Montant ventilé :** un marché à 3 titulaires et 300 000 € compte pour 100 000 € chacun.
Un contrôle vérifie que la somme ventilée retombe exactement sur la somme des montants.

### KPI 6 — Achat local

| Type | Titulaires bretons | Distance médiane acheteur → titulaire |
|---|---:|---:|
| Travaux | **87,0 %** | 29 km |
| Services | 58,8 % | 99 km |
| Fournitures | 40,1 % | 226 km |

> *Corrigé à l'étape 4b :* la part est calculée sur les titulaires dont la région est connue
> (~96 %). Compter les régions inconnues comme « non bretonnes » la sous-estimait
> (83,4 % au lieu de 87,0 % pour les travaux).

Les travaux se font avec des entreprises du coin ; les fournitures viennent de loin
(distributeurs nationaux).

### KPI 7 — Avenants

| Type | Marchés modifiés | Évolution du montant (cumul) | Évolution médiane |
|---|---:|---:|---:|
| Travaux | 20,2 % | +5,0 % | +1,7 % |
| Services | 10,6 % | +2,2 % | +1,9 % |
| Fournitures | 7,8 % | −2,5 % | 0,0 % |

**Un marché de travaux sur cinq est modifié en cours de route**, pour +5 % en cumulé :
aléas de chantier, travaux supplémentaires.

### KPI 8 — Les acheteurs qui engagent le plus

| Acheteur | Achats | Montant total |
|---|---:|---:|
| Syndicat départemental d'énergie 35 | 416 | 7,3 Md€ |
| CH de Saint-Brieuc, Paimpol et Tréguier | 2 081 | 2,3 Md€ |
| Région Bretagne | 2 248 | 2,0 Md€ |
| Syndicat départemental d'énergies du Morbihan | 726 | 1,4 Md€ |
| CHU de Rennes (Pontchaillou) | 3 018 | 1,2 Md€ |

Le SDE 35 en tête… à cause d'un seul marché à 5,4 Md€. Ce marché « suspect » sera le premier
cas étudié à l'étape de détection d'anomalies.

---

## Ce qu'on sait dire, et ce qu'on ne sait pas dire

| Affirmation | Solide ? |
|---|---|
| Les PME gagnent la majorité des marchés mais une minorité des montants | ✅ couverture > 90 % |
| Les travaux vont surtout à des entreprises bretonnes | ✅ |
| Les clauses environnementales progressent depuis 2024 | ✅ à couverture comparable |
| La concurrence a baissé depuis 2019 | ❌ artefact de format de publication |
| La Bretagne a engagé 43,6 Md€ de marchés | ⚠️ ordre de grandeur (maximums d'accords-cadres, marchés suspects inclus) |

**Prochaine étape :** exporter le modèle en Parquet et construire le tableau de bord Power BI.
