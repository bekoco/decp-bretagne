"""Connexion à la base DuckDB locale et exécution des fichiers SQL.

Deux commandes :
  uv run python -m pipeline.db build            exécute sql/NN_*.sql dans l'ordre
  uv run python -m pipeline.db run fichier.sql  exécute un fichier et affiche chaque résultat
"""

import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
DB_FILE = ROOT / "data" / "decp.duckdb"
RAW_FILE = ROOT / "data" / "raw" / "decp_bretagne.parquet"
SQL_DIR = ROOT / "sql"


def connect() -> duckdb.DuckDBPyConnection:
    if not RAW_FILE.exists():
        sys.exit("Données absentes : lancer d'abord  uv run python -m pipeline.extract")
    con = duckdb.connect(str(DB_FILE))
    # Les chemins relatifs dans le SQL (ex. sql/seeds/…) partent de la racine du projet
    con.execute(f"SET file_search_path = '{ROOT.as_posix()}'")
    # Point d'entrée de toutes les requêtes : les données brutes, telles qu'extraites
    con.execute(f"CREATE OR REPLACE VIEW raw_decp AS SELECT * FROM '{RAW_FILE.as_posix()}'")
    return con


def statements(path: Path) -> list[str]:
    """Une requête se termine par un « ; » en fin de ligne, commentaire « -- » ignoré.
    Un « ; » dans un commentaire ne coupe donc pas la requête."""
    result, current = [], []
    for line in path.read_text(encoding="utf-8").splitlines():
        current.append(line)
        code = line.split("--", 1)[0].rstrip()
        if code.endswith(";"):
            result.append("\n".join(current))
            current = []
    result.append("\n".join(current))
    has_code = lambda s: any(l.split("--", 1)[0].strip() for l in s.splitlines())
    return [s.strip() for s in result if has_code(s)]


def label(stmt: str) -> str:
    """Le dernier commentaire au-dessus de la requête (ex. « -- Q2 : ... »), sinon sa 1re ligne."""
    comments = [l.strip() for l in stmt.splitlines() if l.strip().startswith("--")]
    return comments[-1] if comments else stmt.splitlines()[0]


def run(path: Path) -> None:
    con = connect()
    for stmt in statements(path):
        print(f"\n{label(stmt)[:100]}")
        result = con.sql(stmt)
        if result is not None:
            result.show(max_rows=30)


def build() -> None:
    con = connect()
    for path in sorted(SQL_DIR.glob("[0-9][0-9]_*.sql")):
        print(f"{path.name}")
        for stmt in statements(path):
            con.execute(stmt)

    # Les contrôles (sql/09_controles.sql) bloquent le build s'ils échouent
    con.sql("SELECT * FROM controles").show(max_width=120)
    failed = con.execute("SELECT count(*) FROM controles WHERE NOT ok").fetchone()[0]
    if failed:
        sys.exit(f"{failed} contrôle(s) en échec : base construite mais à ne pas utiliser")
    print(f"Base à jour : {DB_FILE}")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")  # console Windows : accents et tableaux
    sys.stderr.reconfigure(encoding="utf-8")
    match sys.argv[1:]:
        case ["build"]:
            build()
        case ["run", file]:
            run(Path(file))
        case _:
            sys.exit(__doc__)
