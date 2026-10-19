"""Export du modèle vers Parquet, pour Power BI.

Un fichier par table du modèle en étoile, sur la période d'analyse (2019+) et avec
les achats dédoublonnés : Power BI reçoit des données déjà propres, il ne fait que les afficher.

Usage : uv run python -m pipeline.export   (après  uv run python -m pipeline.db build)
"""

import sys

from pipeline.db import ROOT, connect

EXPORT_DIR = ROOT / "data" / "export"

# Nom du fichier -> requête. Les noms de colonnes sont ceux qu'on verra dans Power BI.
TABLES = {
    # Faits : un achat (marché dédoublonné), depuis 2019.
    # achat_cle : clé technique numérique. Power BI compare les textes sans tenir compte
    # de la casse : deux uid qui ne diffèrent que par « L » / « l » y seraient confondus.
    "achat": """
        SELECT cle.achat_cle, uid AS achat_id, acheteur_id, cpv_division, date_notification,
               objet, nature, type, procedure, forme_prix, duree_mois, offres_recues,
               nb_titulaires, nb_modifications, montant_initial, montant, montant_brut,
               motif_exclusion_montant, montant_anomalie,
               clause_sociale, clause_environnementale, marche_innovant
        FROM v_marche JOIN cle_achat cle USING (uid)
    """,
    # Pont : un couple achat × titulaire, avec le montant ventilé (étape 3)
    "attribution": """
        SELECT cle.achat_cle, a.titulaire_id, a.titulaire_distance_km, a.montant_ventile
        FROM v_attribution a JOIN cle_achat cle ON cle.uid = a.achat_id
    """,
    # Dimensions
    "acheteur": "SELECT * FROM dim_acheteur WHERE acheteur_id IN (SELECT acheteur_id FROM v_marche)",
    "titulaire": "SELECT * FROM dim_titulaire WHERE titulaire_id IN (SELECT titulaire_id FROM v_attribution)",
    "famille_achat": "SELECT * FROM dim_cpv",
    "calendrier": "SELECT * FROM dim_date WHERE date >= DATE '2019-01-01'",
}


def main() -> None:
    con = connect()
    con.execute("CREATE OR REPLACE TEMP TABLE cle_achat AS SELECT uid, row_number() OVER (ORDER BY uid) AS achat_cle FROM v_marche")
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    for name, query in TABLES.items():
        path = EXPORT_DIR / f"{name}.parquet"
        con.execute(f"COPY ({query}) TO '{path.as_posix()}' (FORMAT parquet)")
        rows = con.execute(f"SELECT count(*) FROM '{path.as_posix()}'").fetchone()[0]
        print(f"{name:<14} {rows:>8} lignes -> {path.relative_to(ROOT)}")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
