"""Extraction : marchés publics bretons depuis le jeu DECP consolidé (data.gouv.fr).

On ne télécharge pas les 2,6 Go du fichier national : DuckDB lit le Parquet
distant par morceaux et ne rapatrie que les lignes de la région Bretagne.

Usage : uv run python -m pipeline.extract
"""

import json
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import duckdb

DATASET_API = "https://www.data.gouv.fr/api/1/datasets/608c055b35eb4e6ee20eb325/"
RESOURCE_TITLE = "decp.parquet"
REGION_BRETAGNE = "53"  # code INSEE de la région

RAW_DIR = Path(__file__).resolve().parent.parent / "data" / "raw"
RAW_FILE = RAW_DIR / "decp_bretagne.parquet"
META_FILE = RAW_DIR / "source.json"


def latest_parquet_url() -> tuple[str, str]:
    """Le fichier est republié chaque jour sous une nouvelle URL : on la lit dans l'API."""
    with urllib.request.urlopen(DATASET_API, timeout=30) as resp:
        dataset = json.load(resp)
    for resource in dataset["resources"]:
        if resource["title"] == RESOURCE_TITLE:
            return resource["url"], resource["last_modified"]
    raise RuntimeError(f"Ressource {RESOURCE_TITLE!r} introuvable dans le jeu DECP")


def main() -> None:
    url, published = latest_parquet_url()
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Source : {url}")

    con = duckdb.connect()
    con.execute("INSTALL httpfs; LOAD httpfs;")
    con.execute(
        f"""
        COPY (
            SELECT * FROM read_parquet('{url}')
            WHERE acheteur_region_code = '{REGION_BRETAGNE}'
        ) TO '{RAW_FILE.as_posix()}' (FORMAT parquet)
        """
    )
    rows = con.execute(f"SELECT count(*) FROM '{RAW_FILE.as_posix()}'").fetchone()[0]

    # Trace de l'extraction : d'où viennent les données et quand
    META_FILE.write_text(
        json.dumps(
            {
                "source_url": url,
                "source_published": published,
                "extracted_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                "filter": f"acheteur_region_code = '{REGION_BRETAGNE}'",
                "rows": rows,
                "licence": "Licence Ouverte v2.0 (Etalab)",
            },
            indent=2,
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )
    print(f"{rows} lignes -> {RAW_FILE}")


if __name__ == "__main__":
    main()
