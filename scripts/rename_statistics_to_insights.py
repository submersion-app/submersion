#!/usr/bin/env python3
"""Rename the Statistics section to Insights.

Implements docs/superpowers/specs/2026-09-25-statistics-to-insights-rename-design.md.
Three phases, one commit each, each safe to rerun (for example after a rebase
brings in new code that still uses the old names):

  code    move the feature folders and files; rename identifiers, routes,
          route names, string ids and file-name mentions in lib/ and test/;
          fix test paths named in .github/workflows
  keys    rename the l10n keys in every ARB file and at every Dart use, then
          regenerate with `flutter gen-l10n`
  values  rewrite the values that name the section, in every locale, then
          regenerate

`<phase> --check` changes nothing and exits 1, listing file:line, if anything
that phase renames is still present.

The tables below list what to rename. Anything not listed is left alone; that
is what keeps DiveStatistics, SiteDiveStatistics, the dive-level
"Exclude from statistics" wording and the 'statistics' field category intact.
"""

import argparse
import json
import os
import re
import subprocess
import sys

# --- code phase tables ------------------------------------------------------

OLD_DIRS = ("lib/features/statistics", "test/features/statistics")
NEW_DIRS = ("lib/features/insights", "test/features/insights")

# File-name stems that keep "statistics" because they name a type another
# feature owns (SiteDiveStatistics lives in dive_sites).
PROTECTED_STEMS = ("site_dive_statistics",)

_PAGES = (
    "Overview", "Gas", "Progression", "Conditions", "Social", "Geographic",
    "MarineLife", "TimePatterns", "Equipment", "Profile",
)

IDENTIFIERS = {
    "StatisticsRepository": "InsightsRepository",
    "statisticsRepositoryProvider": "insightsRepositoryProvider",
    "StatisticsPage": "InsightsPage",
    "StatisticsMobileContent": "InsightsMobileContent",
    "StatisticsListContent": "InsightsListContent",
    "StatisticsCategory": "InsightsCategory",
    "_StatisticsCategoryTile": "_InsightsCategoryTile",
    "statisticsCategoriesOf": "insightsCategoriesOf",
    "StatisticsFilterBar": "InsightsFilterBar",
    "StatisticsFilterAction": "InsightsFilterAction",
    "statisticsFilterProvider": "insightsFilterProvider",
    "statisticsGasLaneProvider": "insightsGasLaneProvider",
    "statisticsGasLaneOverrideProvider": "insightsGasLaneOverrideProvider",
    "statisticsFilteredDiveIdsProvider": "insightsFilteredDiveIdsProvider",
    "SpeciesStatistics": "SpeciesInsights",
    "speciesStatisticsProvider": "speciesInsightsProvider",
    "getSpeciesStatistics": "getSpeciesInsights",
    "watchStatisticsChanges": "watchInsightsChanges",
    **{f"Statistics{p}Page": f"Insights{p}Page" for p in _PAGES},
}

# Files in which every bare 'statistics' string literal is the nav id, the
# section id, the accent key, the route name or a test label for the section.
# Paths are post-move. Files not listed keep their 'statistics' literals (the
# field category in TripField, BuddyField, entity_field and dive_edit_page).
BARE_ID_FILES = (
    "lib/core/router/app_router.dart",
    "lib/core/theme/feature_accent_colors.dart",
    "lib/features/insights/presentation/pages/insights_page.dart",
    "lib/shared/widgets/nav/nav_destinations.dart",
    "test/architecture/provider_tick_build_smoke_test.dart",
    "test/architecture/repository_tick_stream_test.dart",
    "test/features/dive_log/presentation/pages/dive_search_page_filter_target_test.dart",
    "test/features/settings/data/repositories/app_settings_repository_nav_test.dart",
    "test/features/settings/presentation/pages/nav_customization_page_test.dart",
    "test/features/settings/presentation/pages/settings_page_test.dart",
    "test/features/settings/presentation/widgets/nav_customization_tile_test.dart",
    "test/shared/widgets/main_scaffold_test.dart",
    "test/shared/widgets/nav/nav_destinations_test.dart",
    "test/shared/widgets/nav/nav_normalize_test.dart",
    "test/shared/widgets/nav/nav_order_provider_test.dart",
    "test/shared/widgets/nav/rail_destination_order_test.dart",
)

# Comments that name the section, edited after the regex passes.
LITERAL_EDITS = (
    ("lib/core/router/app_router.dart", "// Statistics\n", "// Insights\n"),
    (
        "lib/features/setup_wizard/presentation/widgets/steps/finish_step.dart",
        "'/insights', // statistics",
        "'/insights', // insights",
    ),
    (
        "lib/shared/widgets/nav/nav_destinations.dart",
        "// Statistics. Material",
        "// Insights. Material",
    ),
)

_ROUTE = re.compile(r"""(['"])/statistics(?=['"/])""")
_ROUTE_NAME = re.compile(
    r"""(['"])statistics(%s)(['"])""" % "|".join(_PAGES)
)
_WIDGET_KEY = re.compile(
    r"""(['"])statistics-(filter-action|excluded-footnote)(['"])"""
)
_BARE_ID = re.compile(r"""(['"])statistics(['"])""")
_IDENTIFIER = re.compile(r"\b(%s)\b" % "|".join(sorted(IDENTIFIERS, key=len, reverse=True)))
_WORKFLOW_PATH = "test/features/statistics/"

# --- keys phase tables ------------------------------------------------------

EXTRA_KEYS = {
    "nav_statistics": "nav_insights",
    "dashboard_quickActions_statistics": "dashboard_quickActions_insights",
    "dashboard_quickActions_statisticsTooltip": "dashboard_quickActions_insightsTooltip",
    "accessibility_shortcut_goToStatistics": "accessibility_shortcut_goToInsights",
    "setup_finish_feature_statistics": "setup_finish_feature_insights",
    "diveLog_summary_action_viewStats": "diveLog_summary_action_viewInsights",
}
SUFFIX_RENAMES = {
    "insights_error_loadingStatistics": "insights_error_loadingInsights",
    "insights_tooltip_refreshStatistics": "insights_tooltip_refreshInsights",
}
ARB_DIR = "lib/l10n/arb"
GENERATED_PREFIX = "lib/l10n/arb/app_localizations"

# --- values phase tables ----------------------------------------------------

VALUE_KEYS = (
    "nav_insights", "insights_appBar_title", "dashboard_quickActions_insights",
    "accessibility_shortcut_goToInsights", "diveLog_summary_action_viewInsights",
    "dashboard_quickActions_insightsTooltip", "setup_finish_feature_insights",
    "insights_summary_header_title", "insights_summary_header_subtitle",
    "insights_categoryCard_semanticLabel", "insights_tooltip_filter",
    "insights_tooltip_refreshInsights", "insights_error_loadingInsights",
)


def _row(name, go_to, view, tooltip, setup, header, subtitle, category,
         filt, refresh, error):
    return dict(zip(VALUE_KEYS, (name, name, name, go_to, view, tooltip,
                                 setup, header, subtitle, category, filt,
                                 refresh, error)))


VALUES = {
    "en": _row(
        "Insights", "Go to Insights", "View Insights", "View dive insights",
        "Explore insights about your diving", "Insights Overview",
        "Select a category to explore detailed insights",
        "{title} insights category", "Filter insights", "Refresh insights",
        "Error loading insights"),
    "de": _row(
        "Einblicke", "Zu Einblicken", "Einblicke anzeigen",
        "Einblicke in Ihre Tauchgänge anzeigen",
        "Einblicke in Ihre Tauchgänge entdecken", "Einblicke im Überblick",
        "Wählen Sie eine Kategorie, um detaillierte Einblicke zu erkunden",
        "Einblicke: Kategorie {title}", "Einblicke filtern",
        "Einblicke aktualisieren", "Fehler beim Laden der Einblicke"),
    "es": _row(
        "Análisis", "Ir a Análisis", "Ver análisis", "Ver análisis de buceo",
        "Explora análisis sobre tus inmersiones", "Resumen de análisis",
        "Selecciona una categoría para explorar análisis detallados",
        "Categoría de análisis: {title}", "Filtrar análisis",
        "Actualizar análisis", "Error al cargar los análisis"),
    "fr": _row(
        "Analyses", "Aller aux analyses", "Voir les analyses",
        "Voir les analyses de plongée", "Explorez les analyses de vos plongées",
        "Aperçu des analyses",
        "Sélectionne une catégorie pour explorer les analyses détaillées",
        "Catégorie d'analyses {title}", "Filtrer les analyses",
        "Actualiser les analyses", "Erreur de chargement des analyses"),
    "it": _row(
        "Analisi", "Vai ad Analisi", "Visualizza analisi",
        "Visualizza analisi immersioni",
        "Esplora le analisi delle tue immersioni", "Panoramica analisi",
        "Seleziona una categoria per esplorare le analisi dettagliate",
        "Categoria analisi {title}", "Filtra analisi", "Aggiorna analisi",
        "Errore nel caricamento delle analisi"),
    "pt": _row(
        "Análises", "Ir para Análises", "Ver Análises",
        "Ver análises de mergulho", "Explore análises sobre seus mergulhos",
        "Visão Geral das Análises",
        "Selecione uma categoria para explorar análises detalhadas",
        "Categoria de análises: {title}", "Filtrar análises",
        "Atualizar análises", "Erro ao carregar análises"),
    "nl": _row(
        "Inzichten", "Ga naar Inzichten", "Inzichten bekijken",
        "Duikinzichten bekijken", "Inzichten over je duiken verkennen",
        "Overzicht van inzichten",
        "Selecteer een categorie om gedetailleerde inzichten te bekijken",
        "Inzichtencategorie {title}", "Inzichten filteren",
        "Inzichten verversen", "Fout bij laden van inzichten"),
    "hu": _row(
        "Elemzések", "Ugrás az elemzésekhez", "Elemzések megtekintése",
        "Merülési elemzések megtekintése", "Merülési elemzések felfedezése",
        "Elemzések áttekintése",
        "Válasszon kategóriát a részletes elemzések megtekintéséhez",
        "{title} elemzési kategória", "Elemzések szűrése",
        "Elemzések frissítése", "Hiba az elemzések betöltésekor"),
    "ar": _row(
        "الرؤى", "الانتقال إلى الرؤى", "عرض الرؤى", "عرض رؤى الغوص",
        "استكشف رؤى حول غوصك", "نظرة عامة على الرؤى",
        "اختر فئة لاستكشاف رؤى مفصلة", "فئة رؤى {title}", "تصفية الرؤى",
        "تحديث الرؤى", "خطأ في تحميل الرؤى"),
    "he": _row(
        "תובנות", "מעבר לתובנות", "הצג תובנות", "הצגת תובנות צלילה",
        "חקר תובנות על הצלילות שלכם", "סקירת תובנות",
        "בחר קטגוריה כדי לחקור תובנות מפורטות", "קטגוריית תובנות {title}",
        "סינון תובנות", "רענן תובנות", "שגיאה בטעינת תובנות"),
    "zh": _row(
        "洞察", "前往洞察", "查看洞察", "查看潜水洞察", "探索你的潜水洞察",
        "洞察概览", "选择一个类别以查看详细洞察", "{title} 洞察类别", "筛选洞察",
        "刷新洞察", "加载洞察时出错"),
}

EN_DESCRIPTIONS = (
    ("Navigation label for statistics section",
     "Navigation label for the Insights section"),
    ("Keyboard shortcut label for navigating to statistics",
     "Keyboard shortcut label for navigating to Insights"),
)


# --- helpers ----------------------------------------------------------------

def new_basename(name):
    """Swap "statistics" for "insights" outside the protected stems."""
    pattern = "(%s)" % "|".join(map(re.escape, PROTECTED_STEMS))
    return "".join(
        part if part in PROTECTED_STEMS else part.replace("statistics", "insights")
        for part in re.split(pattern, name)
    )


def _git(root, *args):
    return subprocess.run(
        ["git", *args], cwd=root, check=True, capture_output=True, text=True
    ).stdout


def _tracked(root, *pathspecs):
    out = _git(root, "ls-files", "--", *pathspecs)
    return [line for line in out.splitlines() if line]


def _read(root, path):
    with open(os.path.join(root, path), encoding="utf-8", newline="") as f:
        return f.read()


def _write(root, path, text):
    with open(os.path.join(root, path), "w", encoding="utf-8", newline="") as f:
        f.write(text)


def _dart_files(root):
    return [
        p for p in _tracked(root, "lib/*.dart", "test/*.dart")
        if not p.startswith(GENERATED_PREFIX)
    ]


def basename_map(root):
    """Old basename -> new basename for every file the code phase renames.

    Derived from the files as they stand, so it is the same before and after
    the move: an old name is a new name with "insights" put back.
    """
    mapping = {}
    for path in _tracked(root, *OLD_DIRS, *NEW_DIRS):
        base = os.path.basename(path)
        if "statistics" in base.replace(PROTECTED_STEMS[0], ""):
            mapping[base] = new_basename(base)
        elif "insights" in base:
            mapping[base.replace("insights", "statistics")] = base
    return mapping


def rewrite_dart(text, basenames, bare_ids):
    """Apply the code-phase renames to one Dart file's text."""
    text = text.replace("features/statistics/", "features/insights/")
    for old, new in basenames.items():
        text = re.sub(r"(?<![\w])%s(?![\w])" % re.escape(old), new, text)
    text = _IDENTIFIER.sub(lambda m: IDENTIFIERS[m.group(1)], text)
    text = _ROUTE.sub(r"\1/insights", text)
    text = _ROUTE_NAME.sub(r"\1insights\2\3", text)
    text = _WIDGET_KEY.sub(r"\1insights-\2\3", text)
    if bare_ids:
        text = _BARE_ID.sub(r"\1insights\2", text)
    return text


def new_key(old):
    if old in EXTRA_KEYS:
        return EXTRA_KEYS[old]
    key = "insights_" + old[len("statistics_"):]
    return SUFFIX_RENAMES.get(key, key)


def old_key_names(root):
    """Every old key name, whether or not the ARB files are renamed yet.

    Rebuilt from app_en.arb as it stands: a statistics_* key is old as-is,
    and an insights_* key maps back to exactly one old name. That keeps a
    rerun after a rebase able to find old keys a merged branch brought in.
    """
    en = json.loads(_read(root, f"{ARB_DIR}/app_en.arb"))
    back = {new: old for old, new in SUFFIX_RENAMES.items()}
    names = set(EXTRA_KEYS)
    for key in (k.lstrip("@") for k in en):
        if key.startswith("statistics_"):
            names.add(key)
        elif key.startswith("insights_"):
            names.add("statistics_" + back.get(key, key)[len("insights_"):])
    return names


def key_map(root):
    return {old: new_key(old) for old in old_key_names(root)}


def rename_arb_keys(text, keys):
    """Rename keys and their @metadata entries in ARB text, line by line.

    Text-level, not json.load/dump, so file order and formatting survive.
    """
    pattern = re.compile(
        r'^(\s*)"(@?)(%s)"(\s*:)' % "|".join(map(re.escape, keys)), re.M
    )
    return pattern.sub(lambda m: f'{m.group(1)}"{m.group(2)}{keys[m.group(3)]}"{m.group(4)}', text)


def rename_dart_keys(text, keys):
    pattern = re.compile(
        r"(?<![\w])(%s)(?![\w])" % "|".join(sorted(map(re.escape, keys), key=len, reverse=True))
    )
    return pattern.sub(lambda m: keys[m.group(1)], text)


def set_arb_value(text, key, value):
    """Replace one key's string value; returns (text, number replaced)."""
    pattern = re.compile(r'^(\s*"%s"\s*:\s*)"(?:[^"\\]|\\.)*"' % re.escape(key), re.M)
    encoded = json.dumps(value, ensure_ascii=False)
    return pattern.subn(lambda m: m.group(1) + encoded, text)


# --- phases -----------------------------------------------------------------

def _findings(root, path, text, patterns):
    out = []
    for lineno, line in enumerate(text.splitlines(), 1):
        for label, rx in patterns:
            if rx.search(line):
                out.append(f"{path}:{lineno}: {label}: {line.strip()}")
    return out


def code_phase(root, check):
    basenames = basename_map(root)
    for old in basenames:
        clashes = [
            p for p in _tracked(root, "lib", "test")
            if os.path.basename(p) == old
            and not p.startswith(OLD_DIRS + NEW_DIRS)
        ]
        if clashes:
            sys.exit(f"basename {old} also exists outside the feature: {clashes}")

    if check:
        problems = []
        for path in _tracked(root, *OLD_DIRS):
            problems.append(f"{path}: still under the old folder")
        for path in _tracked(root, *NEW_DIRS):
            if new_basename(os.path.basename(path)) != os.path.basename(path):
                problems.append(f"{path}: file name still says statistics")
        patterns = [
            ("import path", re.compile(r"features/statistics/")),
            ("identifier", _IDENTIFIER),
            ("route", _ROUTE),
            ("route name", _ROUTE_NAME),
            ("widget key", _WIDGET_KEY),
            ("file name", re.compile(r"(?<![\w])(%s)(?![\w])" % "|".join(
                map(re.escape, basenames)))),
        ]
        for path in _dart_files(root):
            extra = [("bare id", _BARE_ID)] if path in BARE_ID_FILES else []
            problems += _findings(root, path, _read(root, path), patterns + extra)
        for path in _tracked(root, ".github/workflows"):
            problems += _findings(root, path, _read(root, path),
                                  [("test path", re.compile(re.escape(_WORKFLOW_PATH)))])
        return problems

    moved = 0
    for path in _tracked(root, *OLD_DIRS, *NEW_DIRS):
        dest = path
        for old_dir, new_dir in zip(OLD_DIRS, NEW_DIRS):
            if dest.startswith(old_dir + "/"):
                dest = new_dir + dest[len(old_dir):]
        dest = os.path.join(os.path.dirname(dest), new_basename(os.path.basename(dest)))
        if dest != path:
            os.makedirs(os.path.join(root, os.path.dirname(dest)), exist_ok=True)
            _git(root, "mv", path, dest)
            moved += 1

    changed = 0
    for path in _dart_files(root):
        before = _read(root, path)
        after = rewrite_dart(before, basenames, path in BARE_ID_FILES)
        if after != before:
            _write(root, path, after)
            changed += 1

    for path, old, new in LITERAL_EDITS:
        text = _read(root, path)
        if old in text:
            _write(root, path, text.replace(old, new, 1))
        elif new not in text:
            sys.exit(f"{path}: neither {old!r} nor {new!r} found")

    for path in _tracked(root, ".github/workflows"):
        text = _read(root, path)
        if _WORKFLOW_PATH in text:
            _write(root, path, text.replace(_WORKFLOW_PATH, "test/features/insights/"))
            changed += 1

    # git mv leaves the emptied folders behind; drop them, bottom-up.
    for old_dir in OLD_DIRS:
        top = os.path.join(root, old_dir)
        for dirpath, _, _ in sorted(os.walk(top), key=lambda w: -len(w[0])):
            if not os.listdir(dirpath):
                os.rmdir(dirpath)
        if os.path.isdir(top):
            print(f"note: {old_dir} still holds untracked files; remove it by hand")
    print(f"moved {moved} files, rewrote {changed} files")
    return []


def _arb_files(root):
    return sorted(p for p in _tracked(root, ARB_DIR) if p.endswith(".arb"))


def _gen_l10n(root):
    subprocess.run(["flutter", "gen-l10n"], cwd=root, check=True)


def keys_phase(root, check, gen):
    keys = key_map(root)
    if check:
        alternation = "|".join(sorted(map(re.escape, keys), key=len, reverse=True))
        arb_key = re.compile(r'^\s*"@?(%s)"\s*:' % alternation)
        dart_use = re.compile(r"(?<![\w])(%s)(?![\w])" % alternation)
        problems = []
        for path in _arb_files(root):
            problems += _findings(root, path, _read(root, path), [("key", arb_key)])
        # Generated files included: after gen-l10n they must be clean too.
        for path in _tracked(root, "lib/*.dart", "test/*.dart"):
            problems += _findings(root, path, _read(root, path), [("l10n key", dart_use)])
        return problems

    arb_changed = 0
    for path in _arb_files(root):
        before = _read(root, path)
        after = rename_arb_keys(before, keys)
        if after != before:
            _write(root, path, after)
            arb_changed += 1
    changed = 0
    for path in _dart_files(root):
        before = _read(root, path)
        after = rename_dart_keys(before, keys)
        if after != before:
            _write(root, path, after)
            changed += 1
    print(f"{len(keys)} keys mapped; rewrote {arb_changed} ARB and {changed} Dart files")
    if gen:
        _gen_l10n(root)
    return []


def values_phase(root, check, gen):
    problems = []
    for locale, values in VALUES.items():
        path = f"{ARB_DIR}/app_{locale}.arb"
        text = _read(root, path)
        data = json.loads(text)
        for key, value in values.items():
            if check:
                if data.get(key) != value:
                    problems.append(f"{path}: {key} is {data.get(key)!r}, want {value!r}")
                continue
            text, count = set_arb_value(text, key, value)
            if count != 1:
                sys.exit(f"{path}: expected one {key}, found {count}")
        if locale == "en":
            for old, new in EN_DESCRIPTIONS:
                if check:
                    if old in text:
                        problems.append(f"{path}: description still reads {old!r}")
                elif old in text:
                    text = text.replace(old, new, 1)
        if not check:
            _write(root, path, text)
    if check:
        return problems
    print("values written")
    if gen:
        _gen_l10n(root)
    return []


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("phase", choices=("code", "keys", "values"))
    parser.add_argument("--check", action="store_true",
                        help="change nothing; exit 1 if the phase has work left")
    parser.add_argument("--no-gen", action="store_true",
                        help="skip `flutter gen-l10n` after keys/values")
    parser.add_argument("--root", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir))
    args = parser.parse_args(argv)
    root = os.path.abspath(args.root)

    if args.phase == "code":
        problems = code_phase(root, args.check)
    elif args.phase == "keys":
        problems = keys_phase(root, args.check, not args.no_gen)
    else:
        problems = values_phase(root, args.check, not args.no_gen)

    for p in problems:
        print(p)
    if args.check:
        print(f"{args.phase}: {len(problems)} leftover(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
