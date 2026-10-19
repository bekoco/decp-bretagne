"""Génère les pages du rapport Power BI (format PBIR) à partir d'une description compacte.

Chaque visuel Power BI est un fichier JSON verbeux ; ici, une page tient en quelques lignes
(type de visuel, position, champs). Relancer après modification :

    uv run python powerbi/build_report.py

puis rouvrir powerbi/MarchesBretagne.pbip dans Power BI Desktop.
"""

import json
import re
import shutil
from pathlib import Path

REPORT = Path(__file__).resolve().parent / "MarchesBretagne.Report"
DEF = REPORT / "definition"
SCHEMA = "https://developer.microsoft.com/json-schemas/fabric/item/report/definition"
THEME = "DecpBretagne.json"
BASE_THEME = "CY26SU10"
VERSIONS = {"visual": "2.4.0", "report": "3.0.0", "page": "2.0.0"}

# Palette catégorielle validée (contraste, daltonisme) : bleu, orange, aqua…
COULEURS = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#6250d6", "#e34948"]
ENCRE, ENCRE_2, FOND, GRILLE = "#0b0b0b", "#52514e", "#fcfcfb", "#e6e5e1"

W, H, M = 1280, 720, 24  # page 16:9, marge


# ── Champs ─────────────────────────────────────────────────────────────────────
def col(table: str, name: str, label: str | None = None) -> dict:
    return {"kind": "Column", "table": table, "name": name, "label": label}


def mes(table: str, name: str, label: str | None = None) -> dict:
    return {"kind": "Measure", "table": table, "name": name, "label": label}


def projection(f: dict) -> dict:
    return {
        "field": {f["kind"]: {"Expression": {"SourceRef": {"Entity": f["table"]}}, "Property": f["name"]}},
        "queryRef": f"{f['table']}.{f['name']}",
        "nativeQueryRef": f["name"],
        **({"displayName": f["label"]} if f.get("label") else {}),
    }


def lit(value) -> dict:
    """Valeur littérale au format Power BI : texte entre apostrophes, booléens/nombres bruts."""
    if isinstance(value, bool):
        v = "true" if value else "false"
    elif isinstance(value, (int, float)):
        v = f"{value}D"
    else:
        v = "'" + str(value).replace("'", "''") + "'"
    return {"expr": {"Literal": {"Value": v}}}


def container(title: str | None) -> dict:
    objs = {"title": [{"properties": {"show": lit(bool(title)), **({"text": lit(title)} if title else {})}}]}
    return objs


# ── Visuels ────────────────────────────────────────────────────────────────────
def visual(kind: str, pos: tuple, roles: dict, title: str | None = None, objects: dict | None = None,
           sort: dict | None = None) -> dict:
    v = {
        "visualType": kind,
        "query": {"queryState": {role: {"projections": [projection(f) for f in fields]}
                                 for role, fields in roles.items()}},
        "visualContainerObjects": container(title),
        "drillFilterOtherVisuals": True,
    }
    if sort:
        f, direction = sort["field"], sort.get("direction", "Descending")
        v["query"]["sortDefinition"] = {
            "sort": [{"field": {f["kind"]: {"Expression": {"SourceRef": {"Entity": f["table"]}},
                                            "Property": f["name"]}}, "direction": direction}],
            "isDefaultSort": True,
        }
    if objects:
        v["objects"] = objects
    return {"pos": pos, "visual": v}


def text(pos: tuple, lines: list[tuple[str, int, str]]) -> dict:
    """Zone de texte : lignes (texte, taille en pt, couleur)."""
    paragraphs = [{"textRuns": [{"value": t, "textStyle": {"fontFamily": "Segoe UI", "fontSize": f"{s}pt",
                                                           "color": c, **({"fontWeight": "600"} if s >= 18 else {})}}]}
                  for t, s, c in lines]
    off = lambda: [{"properties": {"show": lit(False)}}]
    return {"pos": pos, "visual": {
        "visualType": "textbox",
        "objects": {"general": [{"properties": {"paragraphs": paragraphs}}]},
        "visualContainerObjects": {"title": off(), "background": off(), "border": off(), "dropShadow": off()},
    }}


def card(pos, measure, title):
    return visual("card", pos, {"Values": [measure]}, title,
                  objects={"categoryLabels": [{"properties": {"show": lit(False)}}],
                           "labels": [{"properties": {"labelDisplayUnits": lit(1)}}]})


def slicer(pos, field, title):
    return visual("slicer", pos, {"Values": [{**field, "label": title}]}, None,
                  objects={"data": [{"properties": {"mode": lit("Dropdown")}}]})


NO_AXIS_TITLE = {"categoryAxis": [{"properties": {"showAxisTitle": lit(False)}}],
                 "valueAxis": [{"properties": {"showAxisTitle": lit(False)}}]}


def columns(pos, category, measures, title, sort=None):
    return visual("clusteredColumnChart", pos, {"Category": [category], "Y": measures}, title, sort=sort,
                  objects={"labels": [{"properties": {"show": lit(True)}}], **NO_AXIS_TITLE})


def bars(pos, category, measures, title, sort=None):
    return visual("clusteredBarChart", pos, {"Category": [category], "Y": measures}, title, sort=sort,
                  objects={"labels": [{"properties": {"show": lit(True)}}], **NO_AXIS_TITLE})


def line(pos, category, measures, title):
    return visual("lineChart", pos, {"Category": [category], "Y": measures}, title,
                  objects={"labels": [{"properties": {"show": lit(True)}}], **NO_AXIS_TITLE})


def table(pos, fields, title, sort=None):
    return visual("tableEx", pos, {"Values": fields}, title, sort=sort)


# ── Grille ─────────────────────────────────────────────────────────────────────
def header(title: str, subtitle: str) -> dict:
    return text((M, 12, W - 2 * M, 64), [(title, 20, ENCRE), (subtitle, 10, ENCRE_2)])


def slicers() -> list[dict]:
    w = 220
    return [
        slicer((M, 80, w, 56), col("Calendrier", "annee"), "Année"),
        slicer((M + w + 12, 80, w, 56), col("Acheteur", "departement"), "Département de l'acheteur"),
        slicer((M + 2 * (w + 12), 80, w, 56), col("Achat", "type"), "Type de marché"),
    ]


def row(y: int, h: int, n: int, gap: int = 16) -> list[tuple]:
    w = (W - 2 * M - (n - 1) * gap) // n
    return [(M + i * (w + gap), y, w, h) for i in range(n)]


A = "Achat"
SOURCE = "Marchés attribués depuis 2019 par des acheteurs bretons · Source : DECP consolidées (data.gouv.fr) · Montants HT"

PAGES = {
    "vue-ensemble": ("Vue d'ensemble", [
        header("Commande publique en Bretagne", SOURCE),
        *slicers(),
        *[card(p, m, t) for p, (m, t) in zip(row(152, 96, 4), [
            (mes(A, "Achats"), "Achats"),
            (mes(A, "Montant médian"), "Montant médian d'un achat"),
            (mes("Attribution", "Part titulaires bretons"), "Attributions à une entreprise bretonne"),
            (mes(A, "Part modifiés"), "Achats modifiés par avenant"),
        ])],
        columns(row(264, 408, 2)[0], col("Calendrier", "annee"), [mes(A, "Achats")],
                "Achats par année (2026 : année en cours)"),
        bars(row(264, 408, 2)[1], col("Famille achat", "famille_achat"), [mes(A, "Montant total")],
             "Montant par famille d'achat", sort={"field": mes(A, "Montant total")}),
        text((M, 680, W - 2 * M, 32), [("Les montants sont souvent des maximums d'accords-cadres, pas des dépenses : "
                                        "le montant médian décrit mieux l'achat typique que le total.", 9, ENCRE_2)]),
    ]),
    "concurrence": ("Concurrence", [
        header("Concurrence : combien d'entreprises répondent ?",
               "Offre unique = une seule offre reçue · calculé sur les achats où le nombre d'offres est connu"),
        *slicers(),
        bars((M, 152, 600, 256), col(A, "procedure"), [mes(A, "Taux offre unique")],
             "Achats à offre unique, par procédure", sort={"field": mes(A, "Taux offre unique")}),
        columns((M + 616, 152, 592, 256), col("Calendrier", "annee"), [mes(A, "Couverture offres")],
                "Part des achats où le nombre d'offres est renseigné"),
        table((M, 424, W - 2 * M, 248), [col("Famille achat", "famille_achat", "Famille d'achat"), mes(A, "Achats"),
                                         mes(A, "Offres reçues (médiane)"), mes(A, "Taux offre unique"),
                                         mes(A, "Couverture offres")],
              "Concurrence par famille d'achat", sort={"field": mes(A, "Achats")}),
        text((M, 680, W - 2 * M, 32), [("Avant 2024, le nombre d'offres n'est connu que pour ~55 % des achats "
                                        "(changement de format de publication) : les années ne sont comparables qu'à partir de 2024.",
                                        9, ENCRE_2)]),
    ]),
    "entreprises": ("Entreprises", [
        header("Qui remporte les marchés ?",
               "Attribution = un couple achat × titulaire · montant réparti à parts égales entre co-titulaires"),
        *slicers(),
        bars((M, 152, 600, 256), col("Titulaire", "taille_entreprise"),
             [mes("Attribution", "Part des attributions", "Part des marchés"),
              mes("Attribution", "Part du montant", "Part des montants")],
             "Part des marchés et des montants, par taille d'entreprise",
             sort={"field": mes("Attribution", "Part des attributions")}),
        bars((M + 616, 152, 592, 256), col(A, "type"), [mes("Attribution", "Part titulaires bretons")],
             "Titulaires bretons, par type de marché", sort={"field": mes("Attribution", "Part titulaires bretons")}),
        table((M, 424, W - 2 * M, 248), [col("Titulaire", "titulaire_nom", "Titulaire"),
                                         col("Titulaire", "taille_entreprise", "Taille"),
                                         col("Titulaire", "departement", "Département"), mes("Attribution", "Attributions"),
                                         mes("Attribution", "Montant ventilé")],
              "Principaux titulaires", sort={"field": mes("Attribution", "Montant ventilé")}),
    ]),
    "avenants-clauses": ("Avenants et clauses", [
        header("Avenants et clauses sociales / environnementales",
               "Avenant = modification du marché après attribution · clauses : sur les achats où l'information existe"),
        *slicers(),
        columns((M, 152, 400, 256), col(A, "type"), [mes(A, "Part modifiés")],
                "Achats modifiés par avenant", sort={"field": mes(A, "Part modifiés")}),
        columns((M + 416, 152, 400, 256), col(A, "type"), [mes(A, "Évolution montant avenants")],
                "Évolution du montant des achats modifiés"),
        line((M + 832, 152, 376, 256), col("Calendrier", "annee"),
             [mes(A, "Part clause environnementale", "Environnementale"), mes(A, "Part clause sociale", "Sociale")],
             "Achats avec clause, par année"),
        table((M, 424, W - 2 * M, 248), [col("Acheteur", "acheteur_nom", "Acheteur"), col("Acheteur", "departement", "Département"),
                                         mes(A, "Achats"), mes(A, "Montant total"), mes(A, "Montant médian")],
              "Acheteurs", sort={"field": mes(A, "Montant total")}),
    ]),
}


# ── Écriture ───────────────────────────────────────────────────────────────────
def dump(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def theme() -> dict:
    return {
        "name": "DECP Bretagne",
        "dataColors": COULEURS,
        "foreground": ENCRE, "foregroundNeutralSecondary": ENCRE_2,
        "background": "#ffffff", "backgroundLight": FOND, "tableAccent": COULEURS[0],
        "textClasses": {
            "callout": {"fontSize": 26, "fontFace": "Segoe UI Semibold", "color": ENCRE},
            "title": {"fontSize": 11, "fontFace": "Segoe UI Semibold", "color": ENCRE},
            "header": {"fontSize": 11, "fontFace": "Segoe UI Semibold", "color": ENCRE},
            "label": {"fontSize": 10, "fontFace": "Segoe UI", "color": ENCRE_2},
        },
        "visualStyles": {"*": {"*": {
            "background": [{"color": {"solid": {"color": FOND}}}],
            "border": [{"show": False}],
            "valueAxis": [{"gridlineColor": {"solid": {"color": GRILLE}}, "gridlineThickness": 1}],
        }}, "page": {"*": {"background": [{"color": {"solid": {"color": "#ffffff"}}, "transparency": 0}]}}},
    }


def main() -> None:
    pages_dir = DEF / "pages"
    shutil.rmtree(pages_dir, ignore_errors=True)

    dump(REPORT / "StaticResources" / "RegisteredResources" / THEME, theme())
    dump(DEF / "report.json", {
        "$schema": f"{SCHEMA}/report/3.0.0/schema.json",
        "themeCollection": {
            "baseTheme": {"name": BASE_THEME, "reportVersionAtImport": VERSIONS, "type": "SharedResources"},
            "customTheme": {"name": THEME, "reportVersionAtImport": VERSIONS, "type": "RegisteredResources"},
        },
        "settings": {"useStylableVisualContainerHeader": True, "defaultDrillFilterOtherVisuals": True},
        "resourcePackages": [
            {"name": "SharedResources", "type": "SharedResources",
             "items": [{"name": BASE_THEME, "path": f"BaseThemes/{BASE_THEME}.json", "type": "BaseTheme"}]},
            {"name": "RegisteredResources", "type": "RegisteredResources",
             "items": [{"name": THEME, "path": THEME, "type": "CustomTheme"}]},
        ],
    })
    dump(pages_dir / "pages.json", {
        "$schema": f"{SCHEMA}/pagesMetadata/1.0.0/schema.json",
        "pageOrder": list(PAGES), "activePageName": next(iter(PAGES)),
    })
    for page_id, (display, visuals) in PAGES.items():
        dump(pages_dir / page_id / "page.json", {
            "$schema": f"{SCHEMA}/page/2.0.0/schema.json",
            "name": page_id, "displayName": display, "displayOption": "FitToPage", "height": H, "width": W,
        })
        for i, v in enumerate(visuals):
            x, y, w, h = v["pos"]
            name = re.sub(r"[^a-z0-9]", "", f"{page_id}{i:02d}")[:20]
            dump(pages_dir / page_id / "visuals" / name / "visual.json", {
                "$schema": f"{SCHEMA}/visualContainer/2.4.0/schema.json",
                "name": name,
                "position": {"x": x, "y": y, "z": i * 100, "height": h, "width": w, "tabOrder": i},
                "visual": v["visual"],
            })
        print(f"{display:<22} {len(visuals)} visuels")


if __name__ == "__main__":
    main()
