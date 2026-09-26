# Statistics to Insights Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the Statistics section to Insights everywhere it names the section: visible strings in 11 locales, the nav icon, routes, folders, files, classes, providers and l10n keys.

**Architecture:** A read-time alias in `normalizeNavOrder` keeps a stored `'statistics'` nav id in its slot. Everything else is done by one committed, rerunnable Python script with three phases (`code`, `keys`, `values`) driven by explicit rename tables; anything not in a table is left alone, which is what protects the dive-level "Exclude from statistics" wording and the types other features own.

**Tech Stack:** Flutter/Dart, Riverpod, go_router, `flutter gen-l10n` (ARB), Python 3 (stdlib only, `unittest`).

**Spec:** `docs/superpowers/specs/2026-09-25-statistics-to-insights-rename-design.md`

## Global Constraints

- Never write the em-dash character (U+2014) anywhere: code, comments, commit messages, docs, ARB values. En-dashes and spaced hyphens used as prose punctuation are equally forbidden in new text.
- Follow the Attribution section of the project development guide: no commit message, PR text or file may name the AI tooling used, and no `Co-Authored-By` or tool trailer.
- The dive-level "Exclude from statistics" wording stays, in every locale, in keys and values.
- Names built on types another feature owns stay: `DiveStatistics`, `diveStatisticsProvider`, `getStatistics`, `SiteDiveStatistics`, `getSiteDiveStatistics`, `filteredDiveStatisticsProvider`, `DiveTypeStatistic`, `TagStatistic`, `SiteTypeStatistic`.
- The `'statistics'` field category (`TripField`, `BuddyField`, `entity_field.dart`, `enum_fieldCategory_statistics`) stays.
- Stored settings are never rewritten; the nav alias works at read time only.
- Every l10n change is made in all 11 ARB files (ar, de, en, es, fr, he, hu, it, nl, pt, zh) and followed by `flutter gen-l10n`.
- Run `dart format .` before every commit that touches Dart.
- Stage explicit paths (`git add -A -- <paths>`), never a bare `git add -A`.
- Python: run scripts with `python3`; the script must stay compatible with Python 3.9 (CI and the system interpreter).

## Review Focus

- **An upgrading user with a customised nav order** (phone or rail) that has Statistics in a non-default slot: Insights must appear in that same slot. Pinned by the notifier-level tests added in Task 3.
- **Mixed-version sync** delivering a stored order that holds both `'statistics'` and `'insights'`: exactly one Insights entry, at the first position. Pinned in Task 1.
- **A branch that merges after this one and still imports `features/statistics/`**: it stops compiling on the merge result, on main. The script's `code --check` names every leftover; Task 7 runs it on the two open PRs that touch the folder.
- **A translated value that drops its `{title}` placeholder**: `gen-l10n` would accept it and the screen reader label would lose the category name. Pinned by the script test `test_every_locale_row_is_complete` in Task 2.
- **The dive-level exclusion wording drifting**: the "Statistics" dive-form group and "excluded from statistics" footnote must read exactly as before. Pinned by the existing `dive_edit_statistics_section_test.dart`, `dive_exclusion_toggles_test.dart` and `excluded_dives_footnote_test.dart`, which Task 5 runs explicitly.

---

## Before you start

The worktree must be initialised (submodules, `flutter pub get`, codegen). Check:

```bash
ls lib/core/database/database.g.dart .dart_tool >/dev/null && git status --short
```

Expected: no error and a clean status. If `database.g.dart` is missing, run `git submodule update --init --recursive`, `flutter pub get`, then `dart run build_runner build --delete-conflicting-outputs`.

---

### Task 1: Read a renamed nav id as its replacement

**Files:**
- Create: `lib/shared/widgets/nav/nav_id_aliases.dart`
- Modify: `lib/shared/widgets/nav/nav_destinations.dart` (the `normalizeNavOrder` doc comment and loop, around lines 194-223)
- Test: `test/shared/widgets/nav/nav_id_alias_test.dart` (create)

**Interfaces:**
- Produces: `const Map<String, String> kRenamedNavIds` in `nav_id_aliases.dart`, holding `{'statistics': 'insights'}`. `normalizeNavOrder` keeps its signature.

At this point the real nav id is still `'statistics'`, so the tests use their own `movableIds` list. The alias applies only to an id the build does not know, which makes this task a no-op for the current real ids.

- [ ] **Step 1: Write the failing test**

Create `test/shared/widgets/nav/nav_id_alias_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

void main() {
  group('renamed nav ids', () {
    // A build that already ships the new id; kRenamedNavIds records
    // statistics -> insights.
    const movable = ['dives', 'insights', 'sites', 'gear'];

    test('a renamed id keeps its stored slot under the new id', () {
      expect(
        normalizeNavOrder(
          stored: const ['sites', 'statistics', 'dives'],
          movableIds: movable,
        ),
        ['sites', 'insights', 'dives', 'gear'],
      );
    });

    test('the old and new id together collapse to one entry', () {
      expect(
        normalizeNavOrder(
          stored: const ['statistics', 'sites', 'insights'],
          movableIds: movable,
        ),
        ['insights', 'sites', 'dives', 'gear'],
      );
      expect(
        normalizeNavOrder(
          stored: const ['insights', 'sites', 'statistics'],
          movableIds: movable,
        ),
        ['insights', 'sites', 'dives', 'gear'],
      );
    });

    test('an alias never replaces an id the build still knows', () {
      // An older build that still ships the old id reads it as itself.
      const olderBuild = ['dives', 'statistics', 'sites'];
      expect(
        normalizeNavOrder(
          stored: const ['statistics', 'dives'],
          movableIds: olderBuild,
        ),
        ['statistics', 'dives', 'sites'],
      );
    });

    test('an unknown id with no alias is still dropped', () {
      expect(
        normalizeNavOrder(
          stored: const ['not-a-real-id', 'sites'],
          movableIds: movable,
        ),
        ['sites', 'dives', 'insights', 'gear'],
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/shared/widgets/nav/nav_id_alias_test.dart`
Expected: FAIL. The first two tests fail because `'statistics'` is dropped and `'insights'` is appended in canonical order (actual `['sites', 'dives', 'insights', 'gear']`). The last two pass.

- [ ] **Step 3: Create the alias table**

Create `lib/shared/widgets/nav/nav_id_aliases.dart`:

```dart
/// Nav destination ids that were renamed, mapped to the id that replaced them.
///
/// A stored nav order (`nav_primary_ids`, `nav_rail_ids`) outlives the build
/// that wrote it, and `nav_primary_ids` syncs between devices, so an id can
/// arrive after its destination was renamed. `normalizeNavOrder` reads such
/// an id as its replacement, which keeps the user's slot instead of dropping
/// the id and appending the replacement in canonical order.
///
/// The stored value is never rewritten here; the next save writes the new id.
const Map<String, String> kRenamedNavIds = {
  // The Statistics section became Insights.
  'statistics': 'insights',
};
```

- [ ] **Step 4: Resolve aliases in `normalizeNavOrder`**

In `lib/shared/widgets/nav/nav_destinations.dart`, add the import next to the file's other `package:submersion/...` imports:

```dart
import 'package:submersion/shared/widgets/nav/nav_id_aliases.dart';
```

Replace the doc bullet

```dart
/// - Unknown and pinned ids are dropped; a duplicate keeps its first position.
```

with

```dart
/// - An id this build does not know is first read through [kRenamedNavIds],
///   so a renamed destination keeps its slot. An alias never replaces an id
///   the build still knows.
/// - Unknown and pinned ids are dropped; a duplicate keeps its first position.
```

and replace the first loop

```dart
  for (final id in stored) {
    if (!movableIds.contains(id)) continue;
    if (result.contains(id)) continue;
    result.add(id);
  }
```

with

```dart
  for (final storedId in stored) {
    final id = movableIds.contains(storedId)
        ? storedId
        : kRenamedNavIds[storedId] ?? storedId;
    if (!movableIds.contains(id)) continue;
    if (result.contains(id)) continue;
    result.add(id);
  }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/shared/widgets/nav/`
Expected: PASS, including the existing `nav_normalize_test.dart` and `nav_order_provider_test.dart` (the real ids are unchanged, so the alias never fires for them).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A -- lib/shared/widgets/nav/nav_id_aliases.dart lib/shared/widgets/nav/nav_destinations.dart test/shared/widgets/nav/nav_id_alias_test.dart
git commit -m "feat(nav): read a renamed nav id as its replacement"
```

Expected: `flutter analyze` reports `No issues found!`.

---

### Task 2: The rename script

**Files:**
- Create: `scripts/rename_statistics_to_insights_test.py`
- Create: `scripts/rename_statistics_to_insights.py`
- Modify: `.github/workflows/ci.yaml` (the "Run Python guard tests with coverage" step, around lines 530-552)

**Interfaces:**
- Produces: `python3 scripts/rename_statistics_to_insights.py {code|keys|values} [--check] [--no-gen] [--root DIR]`. Without `--check` a phase applies its renames and prints a one-line summary; with `--check` it changes nothing, prints `file:line: <kind>: <text>` for each leftover, then `<phase>: N leftover(s)`, and exits 1 if N > 0. `keys` and `values` run `flutter gen-l10n` unless `--no-gen`.

The script was dry-run against a full copy of `lib/`, `test/` and `.github/` at plan time: `code` moved 121 files and rewrote 169, every stay-list name kept its exact count, no CRLF file was touched, `keys` mapped 369 keys (363 prefixed plus 6 others) and every phase was a no-op on a second run.

- [ ] **Step 1: Write the failing test**

Create `scripts/rename_statistics_to_insights_test.py` with exactly this content:

```python
#!/usr/bin/env python3
"""Unit tests for rename_statistics_to_insights.py."""

import importlib.util
import json
import os
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "rename_statistics_to_insights",
    os.path.join(_HERE, "rename_statistics_to_insights.py"),
)
rename = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(rename)


class NewBasenameTest(unittest.TestCase):
    def test_swaps_the_feature_word(self):
        self.assertEqual(rename.new_basename("statistics_gas_page.dart"),
                         "insights_gas_page.dart")
        self.assertEqual(
            rename.new_basename("equipment_condition_statistics_providers.dart"),
            "equipment_condition_insights_providers.dart")

    def test_keeps_a_protected_stem(self):
        self.assertEqual(
            rename.new_basename(
                "statistics_repository_site_dive_statistics_test.dart"),
            "insights_repository_site_dive_statistics_test.dart")

    def test_leaves_other_names_alone(self):
        self.assertEqual(rename.new_basename("records_page.dart"),
                         "records_page.dart")


class RewriteDartTest(unittest.TestCase):
    basenames = {"statistics_page.dart": "insights_page.dart"}

    def rewrite(self, text, bare_ids=False):
        return rename.rewrite_dart(text, self.basenames, bare_ids)

    def test_package_import(self):
        self.assertEqual(
            self.rewrite("import 'package:submersion/features/statistics/"
                         "presentation/pages/statistics_page.dart';"),
            "import 'package:submersion/features/insights/"
            "presentation/pages/insights_page.dart';")

    def test_relative_import_and_comment_mention(self):
        self.assertEqual(self.rewrite("import 'statistics_page.dart';"),
                         "import 'insights_page.dart';")
        self.assertEqual(self.rewrite("/// see `statistics_page.dart`"),
                         "/// see `insights_page.dart`")

    def test_basename_needs_a_boundary(self):
        # dive_log's statistics_section.dart is not a feature file.
        self.assertEqual(self.rewrite("import 'statistics_section.dart';"),
                         "import 'statistics_section.dart';")

    def test_listed_identifiers_are_renamed(self):
        self.assertEqual(
            self.rewrite("final r = ref.watch(statisticsRepositoryProvider);"),
            "final r = ref.watch(insightsRepositoryProvider);")
        self.assertEqual(self.rewrite("class _StatisticsCategoryTile {}"),
                         "class _InsightsCategoryTile {}")
        self.assertEqual(self.rewrite("const StatisticsMarineLifePage()"),
                         "const InsightsMarineLifePage()")

    def test_names_built_on_outside_types_stay(self):
        for text in ("DiveStatistics s;", "SiteDiveStatistics s;",
                     "filteredDiveStatisticsProvider",
                     "repo.getSiteDiveStatistics(id)"):
            self.assertEqual(self.rewrite(text), text)

    def test_identifier_needs_a_boundary(self):
        self.assertEqual(self.rewrite("MyStatisticsPageHelper"),
                         "MyStatisticsPageHelper")

    def test_routes_route_names_and_widget_keys(self):
        self.assertEqual(self.rewrite("context.go('/statistics');"),
                         "context.go('/insights');")
        self.assertEqual(self.rewrite("'/statistics/$id'"), "'/insights/$id'")
        self.assertEqual(self.rewrite("name: 'statisticsTimePatterns',"),
                         "name: 'insightsTimePatterns',")
        self.assertEqual(self.rewrite("ValueKey('statistics-filter-action')"),
                         "ValueKey('insights-filter-action')")

    def test_route_prefix_needs_a_boundary(self):
        self.assertEqual(self.rewrite("'/statisticsfoo'"), "'/statisticsfoo'")

    def test_bare_id_only_where_allowed(self):
        self.assertEqual(self.rewrite("id: 'statistics',"),
                         "id: 'statistics',")
        self.assertEqual(self.rewrite("id: 'statistics',", bare_ids=True),
                         "id: 'insights',")


class KeysTest(unittest.TestCase):
    def test_new_key(self):
        self.assertEqual(rename.new_key("statistics_appBar_title"),
                         "insights_appBar_title")
        self.assertEqual(rename.new_key("statistics_error_loadingStatistics"),
                         "insights_error_loadingInsights")
        self.assertEqual(rename.new_key("diveLog_summary_action_viewStats"),
                         "diveLog_summary_action_viewInsights")

    def test_arb_rename_keeps_layout_and_metadata(self):
        keys = {"statistics_a": "insights_a"}
        before = ('{\n  "statistics_a": "A",\n  "statistics_ab": "AB",\n'
                  '  "other": "x",\n  "@statistics_a": {\n'
                  '    "description": "statistics_a stays in prose"\n  }\n}\n')
        after = rename.rename_arb_keys(before, keys)
        self.assertEqual(
            after,
            '{\n  "insights_a": "A",\n  "statistics_ab": "AB",\n'
            '  "other": "x",\n  "@insights_a": {\n'
            '    "description": "statistics_a stays in prose"\n  }\n}\n')

    def test_dart_key_use_across_a_line_break(self):
        keys = {"statistics_a": "insights_a", "statistics_ab": "insights_ab"}
        self.assertEqual(
            rename.rename_dart_keys("context.l10n\n    .statistics_ab(x)", keys),
            "context.l10n\n    .insights_ab(x)")
        self.assertEqual(rename.rename_dart_keys("l10n.statistics_a", keys),
                         "l10n.insights_a")


class ArbValueTest(unittest.TestCase):
    def test_sets_value_and_escapes(self):
        text = '{\n  "k": "old \\"q\\"",\n  "@k": {}\n}\n'
        out, count = rename.set_arb_value(text, "k", 'Catégorie d\'"x"')
        self.assertEqual(count, 1)
        self.assertEqual(json.loads(out)["k"], 'Catégorie d\'"x"')
        self.assertIn("Catégorie", out)

    def test_missing_key_counts_zero(self):
        _, count = rename.set_arb_value('{\n  "a": "b"\n}\n', "k", "v")
        self.assertEqual(count, 0)

    def test_every_locale_row_is_complete(self):
        for locale, values in rename.VALUES.items():
            self.assertEqual(set(values), set(rename.VALUE_KEYS), locale)
            self.assertIn("{title}", values["insights_categoryCard_semanticLabel"],
                          locale)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python3 scripts/rename_statistics_to_insights_test.py`
Expected: FAIL with `FileNotFoundError` naming `rename_statistics_to_insights.py`.

- [ ] **Step 3: Write the script**

Create `scripts/rename_statistics_to_insights.py` with exactly this content:

```python
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
```

Then make it executable: `chmod +x scripts/rename_statistics_to_insights.py`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `python3 scripts/rename_statistics_to_insights_test.py`
Expected: `Ran 18 tests` and `OK`.

- [ ] **Step 5: Confirm the check sees the work ahead**

Run: `python3 scripts/rename_statistics_to_insights.py code --check | tail -1`
Expected: `code: 1156 leftover(s)` (approximately; main may have moved) and exit status 1. This proves the check detects the old names before anything is renamed.

- [ ] **Step 6: Register the test in CI**

In `.github/workflows/ci.yaml`, in the "Run Python guard tests with coverage" step, append `,scripts/rename_statistics_to_insights.py` to the end of the `guards='...'` list (inside the quotes), and add these two lines directly after the last existing `python3 -m coverage run --append --include="$guards" \` / script pair:

```yaml
          python3 -m coverage run --append --include="$guards" \
            scripts/rename_statistics_to_insights_test.py
```

- [ ] **Step 7: Commit**

```bash
git add -A -- scripts/rename_statistics_to_insights.py scripts/rename_statistics_to_insights_test.py .github/workflows/ci.yaml
git commit -m "chore: add the Statistics to Insights rename script"
```

---

### Task 3: Rename the feature in code

**Files:**
- Move: `lib/features/statistics/` to `lib/features/insights/`, `test/features/statistics/` to `test/features/insights/` (done by the script, file names included)
- Modify: every Dart file under `lib/` and `test/` that uses a renamed path, identifier, route, route name or string id (done by the script), and `.github/workflows/ci.yaml` line with `test/features/statistics/data/dive_filter_sql_test.dart` (done by the script)
- Modify: `test/shared/widgets/nav/nav_id_alias_test.dart` (add the real-destination tests)

**Interfaces:**
- Consumes: the script from Task 2; `kRenamedNavIds` from Task 1.
- Produces, for later tasks: `lib/features/insights/...` paths; routes `/insights` and `/insights/:id`; route names `insights`, `insightsOverview`, `insightsGas`, `insightsProgression`, `insightsConditions`, `insightsSocial`, `insightsGeographic`, `insightsMarineLife`, `insightsTimePatterns`, `insightsEquipment`, `insightsProfile`; nav id `'insights'`; classes and providers per the spec's rename table (`InsightsRepository`, `insightsRepositoryProvider`, `InsightsPage`, `Insights*Page`, `InsightsCategory`, `insightsFilterProvider`, `SpeciesInsights`, `speciesInsightsProvider`, `watchInsightsChanges`, and so on).

- [ ] **Step 1: Run the code phase**

```bash
python3 scripts/rename_statistics_to_insights.py code
```

Expected: `moved 121 files, rewrote 169 files` (counts may differ slightly if main has moved), and no `note:` line. A `note: ... still holds untracked files` line means a stray untracked file sits in an old folder; inspect it and delete it by hand.

- [ ] **Step 2: Format and confirm nothing is left**

```bash
dart format .
python3 scripts/rename_statistics_to_insights.py code --check
```

Expected: `code: 0 leftover(s)`, exit 0.

- [ ] **Step 3: Confirm the stay list is untouched**

```bash
for p in DiveStatistics SiteDiveStatistics filteredDiveStatisticsProvider getSiteDiveStatistics statistics_section enum_fieldCategory_statistics; do
  echo "$p committed=$(git grep -ow "$p" HEAD -- lib test | wc -l) now=$(git grep -ow "$p" -- lib test | wc -l)"
done
git diff HEAD --stat -- lib/features/trips lib/features/buddies lib/shared/constants lib/core/database lib/core/services/export
```

Expected: every line shows the same `committed` and `now` count (`HEAD` is still the pre-rename tree, since nothing is committed yet). The `git diff` prints nothing: none of those folders changed.

- [ ] **Step 4: Add the real-destination tests (Review Focus: upgrading user)**

Replace the imports at the top of `test/shared/widgets/nav/nav_id_alias_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
import 'package:submersion/shared/widgets/nav/nav_id_aliases.dart';
import 'package:submersion/shared/widgets/nav/nav_order_provider.dart';

import '../../../support/fake_app_settings_repository.dart';

ProviderContainer _container(AppSettingsRepository repo) {
  return ProviderContainer(
    overrides: [appSettingsRepositoryProvider.overrideWithValue(repo)],
  );
}

/// Reads a notifier and lets its async load settle.
Future<List<String>> _loaded(
  ProviderContainer container,
  StateNotifierProvider<NavOrderNotifier, List<String>> provider,
) async {
  container.read(provider);
  await Future<void>.delayed(Duration.zero);
  return container.read(provider);
}
```

and add this group inside `main()`, after the existing `group('renamed nav ids', ...)`:

```dart
  group('renamed nav ids against the real destinations', () {
    test('every alias points at a current destination and retires its '
        'source', () {
      for (final entry in kRenamedNavIds.entries) {
        expect(movableNavIds, contains(entry.value), reason: entry.key);
        expect(movableNavIds, isNot(contains(entry.key)), reason: entry.key);
      }
    });

    test('a phone order saved before the rename keeps Insights in its '
        'slot', () async {
      final repo = FakeAppSettingsRepository()
        ..navPrimaryIds = ['equipment', 'statistics', 'buddies'];
      final container = _container(repo);
      addTearDown(container.dispose);

      final order = await _loaded(container, navPhoneOrderNotifierProvider);

      expect(order.take(3).toList(), ['equipment', 'insights', 'buddies']);
      expect(order.toSet(), movableNavIds.toSet());
    });

    test('a rail order saved before the rename keeps Insights in its '
        'slot', () async {
      final repo = FakeAppSettingsRepository()
        ..navRailIds = ['statistics', 'gps-log'];
      final container = _container(repo);
      addTearDown(container.dispose);

      final order = await _loaded(container, navRailOrderNotifierProvider);

      expect(order.take(2).toList(), ['insights', 'gps-log']);
    });

    test('the next save writes the new id', () async {
      final repo = FakeAppSettingsRepository()
        ..navPrimaryIds = ['equipment', 'statistics', 'buddies'];
      final container = _container(repo);
      addTearDown(container.dispose);

      final order = await _loaded(container, navPhoneOrderNotifierProvider);
      await container
          .read(navPhoneOrderNotifierProvider.notifier)
          .setOrder(order);

      expect(repo.navPrimaryIds, contains('insights'));
      expect(repo.navPrimaryIds, isNot(contains('statistics')));
    });
  });
```

`FakeAppSettingsRepository` (`test/support/fake_app_settings_repository.dart`) keeps the stored orders in the public fields `navPrimaryIds` and `navRailIds`, and `setNavPrimaryIds` writes a copy into `navPrimaryIds`, so the last test reads back exactly what a save persisted.

- [ ] **Step 5: Run the affected tests**

```bash
flutter test test/shared/widgets test/features/insights test/features/settings test/architecture test/core/router test/features/dashboard test/accessibility test/features/dive_log/presentation/pages/dive_search_page_filter_target_test.dart
```

Expected: PASS. Visible labels still read "Statistics" at this point; only ids, routes and names changed.

- [ ] **Step 6: Analyze and commit**

```bash
flutter analyze
git add -A -- lib test .github/workflows/ci.yaml
git status --short | grep -v '^[RMAD] ' || true
git commit -m "refactor: rename the statistics feature to insights"
```

Expected: `No issues found!`; the `git status` filter prints nothing (no untracked or unstaged leftovers).

---

### Task 4: Rename the l10n keys

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb` (key names and `@` metadata keys only; values untouched)
- Modify: every Dart file that reads a renamed key (36 at plan time)
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Consumes: the script from Task 2.
- Produces: getters `insights_*` replacing `statistics_*`, plus `nav_insights`, `dashboard_quickActions_insights`, `dashboard_quickActions_insightsTooltip`, `accessibility_shortcut_goToInsights`, `setup_finish_feature_insights`, `diveLog_summary_action_viewInsights`, `insights_error_loadingInsights`, `insights_tooltip_refreshInsights`.

- [ ] **Step 1: Run the keys phase (it runs `flutter gen-l10n`)**

```bash
python3 scripts/rename_statistics_to_insights.py keys
```

Expected: `369 keys mapped; rewrote 11 ARB and 36 Dart files` (Dart count may differ slightly), then gen-l10n completes without errors. A gen-l10n error naming a key means an `@` metadata entry no longer matches its key; fix that ARB line and rerun.

- [ ] **Step 2: Check, and confirm the ARB diff only renamed**

```bash
dart format .
python3 scripts/rename_statistics_to_insights.py keys --check
git diff --numstat -- lib/l10n/arb/*.arb
```

Expected: `keys: 0 leftover(s)`; for every ARB file the insertions equal the deletions (a pure rename, no reordering).

- [ ] **Step 3: Run the l10n and feature tests**

```bash
flutter test test/l10n test/features/insights test/accessibility test/features/dashboard test/shared/widgets
```

Expected: PASS.

- [ ] **Step 4: Analyze and commit**

```bash
flutter analyze
git add -A -- lib test
git commit -m "refactor(l10n): rename statistics_* keys to insights_*"
```

---

### Task 5: Show the section as Insights

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb` (13 values each; 2 English descriptions) via the script
- Modify: `lib/shared/widgets/nav/nav_destinations.dart` (the Insights destination icons)
- Modify: `lib/features/dashboard/presentation/widgets/quick_actions_card.dart` (the Insights quick action icon)
- Modify: `lib/features/dive_log/presentation/widgets/dive_summary_widget.dart` (the "View Insights" button icon)
- Test: `test/shared/widgets/nav/nav_destinations_test.dart`, `test/shared/widgets/main_scaffold_test.dart`, `test/accessibility/keyboard_shortcuts_test.dart`, `test/features/dashboard/presentation/widgets/dashboard_cards_test.dart`

**Interfaces:**
- Consumes: the renamed keys from Task 4; `kNavDestinations` entries (`id`, `icon`, `selectedIcon`).

- [ ] **Step 1: Update the tests to the new label and icon**

In `test/shared/widgets/main_scaffold_test.dart`, replace the nav label `'Statistics'` with `'Insights'` in these four places: `find.widgetWithText(NavigationDestination, 'Statistics')`, the `'Statistics',` entry in the full label list (between `'Species',` and `'Planning',`), the `'Statistics',` entry in the rail labels list (between `'Settings',` and `'Dives',`), and `find.widgetWithText(ListTile, 'Statistics')`.

In `test/accessibility/keyboard_shortcuts_test.dart`, replace `contains('Go to Statistics')` with `contains('Go to Insights')`.

In `test/features/dashboard/presentation/widgets/dashboard_cards_test.dart`, replace `('Statistics', '/insights'),` with `('Insights', '/insights'),`.

In `test/shared/widgets/nav/nav_destinations_test.dart`, add `import 'package:flutter/material.dart';` above the `flutter_test` import, and add inside `group('kNavDestinations', ...)`:

```dart
    test('Insights uses the insights glyph', () {
      final insights = kNavDestinations.singleWhere((d) => d.id == 'insights');
      expect(insights.icon, Icons.insights_outlined);
      expect(insights.selectedIcon, Icons.insights);
    });
```

Do not touch `find.text('Statistics')` in `dive_exclusion_toggles_test.dart` or `dive_edit_statistics_section_test.dart`: that is the dive-form group, which keeps its name.

- [ ] **Step 2: Run the tests to verify they fail**

```bash
flutter test test/shared/widgets/nav/nav_destinations_test.dart test/shared/widgets/main_scaffold_test.dart test/accessibility/keyboard_shortcuts_test.dart test/features/dashboard/presentation/widgets/dashboard_cards_test.dart
```

Expected: FAIL. The label tests find "Statistics" instead of "Insights"; the icon test gets `Icons.bar_chart_outlined`.

- [ ] **Step 3: Write the values (the script runs `flutter gen-l10n`)**

```bash
python3 scripts/rename_statistics_to_insights.py values
python3 scripts/rename_statistics_to_insights.py values --check
```

Expected: `values written`, gen-l10n succeeds, then `values: 0 leftover(s)`.

- [ ] **Step 4: Switch the icons**

In `lib/shared/widgets/nav/nav_destinations.dart`, in the destination with `id: 'insights'`, replace

```dart
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
```

with

```dart
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
```

In `lib/features/dashboard/presentation/widgets/quick_actions_card.dart`, in the button whose `onPressed` is `() => context.go('/insights')`, replace `icon: const Icon(Icons.bar_chart),` with `icon: const Icon(Icons.insights),`.

In `lib/features/dive_log/presentation/widgets/dive_summary_widget.dart`, in the `OutlinedButton.icon` whose `onPressed` is `() => context.go('/insights')`, replace `icon: const Icon(Icons.bar_chart),` with `icon: const Icon(Icons.insights),`.

Leave `Icons.bar_chart_outlined` in `dive_list_page.dart`, `dive_filter_sheet.dart` and `edit_sections/statistics_section.dart`: those are the excluded-from-statistics badge, filter and toggle.

- [ ] **Step 5: Run the tests to verify they pass, including the stay guards**

```bash
flutter test test/shared/widgets/nav/nav_destinations_test.dart test/shared/widgets/main_scaffold_test.dart test/accessibility/keyboard_shortcuts_test.dart test/features/dashboard/presentation/widgets/dashboard_cards_test.dart test/features/dive_log/presentation/dive_exclusion_toggles_test.dart test/features/dive_log/presentation/pages/dive_edit_statistics_section_test.dart test/features/insights/excluded_dives_footnote_test.dart test/l10n
```

Expected: PASS. The three dive-level tests passing unchanged is the proof that the exclusion wording stayed.

- [ ] **Step 6: Spot-check the ARB diff**

```bash
git diff -U0 -- lib/l10n/arb/app_de.arb lib/l10n/arb/app_en.arb | grep '^[-+] '
```

Expected: 13 value lines changed in `app_de.arb`; 13 value lines and 2 description lines in `app_en.arb`; nothing else.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A -- lib test
git commit -m "feat: show the Statistics section as Insights"
```

---

### Task 6: Docs

**Files:**
- Move: `docs/guide/statistics.md` to `docs/guide/insights.md`
- Modify: `docs/_sidebar.md`, `docs/guide/README.md`, `docs/README.md`, `docs/features/README.md`, `README.md`, `docs/developer/navigation.md`, `docs/developer/architecture.md`, `docs/ARCHITECTURE.md`

Historical specs, plans and release notes are not edited. The README screenshot `07-statistics.jpg` keeps its file name.

- [ ] **Step 1: Move the guide page and rename its section headings**

```bash
git mv docs/guide/statistics.md docs/guide/insights.md
```

In `docs/guide/insights.md` make these replacements (each string occurs once):

| Old | New |
| --- | --- |
| `# Statistics & Analytics` | `# Insights` |
| `## Statistics Dashboard` | `## Insights Dashboard` |
| `The **Stats** tab is your analytics hub` | `The **Insights** tab is your analytics hub` |
| `<strong>Screenshot: Main Statistics Dashboard</strong>` | `<strong>Screenshot: Main Insights Dashboard</strong>` |
| `Filter statistics by:` | `Filter insights by:` |
| `## Tips for Using Statistics` | `## Tips for Using Insights` |

Leave the remaining uses of "statistics" in the page (gas statistics, species sighting statistics, a statistics report): they describe numbers.

- [ ] **Step 2: Fix the links and section names**

| File | Old | New |
| --- | --- | --- |
| `docs/_sidebar.md` | `* [Statistics & Analytics](guide/statistics.md)` | `* [Insights](guide/insights.md)` |
| `docs/guide/README.md` | `[**Statistics**](guide/statistics.md)` | `[**Insights**](guide/insights.md)` |
| `docs/README.md` | `### Statistics & Analytics` | `### Insights` |
| `docs/README.md` | `[View statistics features &rarr;](guide/statistics.md)` | `[View Insights features &rarr;](guide/insights.md)` |
| `docs/features/README.md` | `[**Statistics**](guide/statistics.md)` | `[**Insights**](guide/insights.md)` |
| `README.md` | `### Statistics &amp; Records` | `### Insights &amp; Records` |
| `README.md` | `│   ├── statistics/       # Analytics & records` | `│   ├── insights/         # Analytics & records` |
| `docs/developer/architecture.md` | `│   ├── statistics/` | `│   ├── insights/` |
| `docs/ARCHITECTURE.md` | `│   │   ├── statistics/              # Analytics (11 dashboard pages)` | `│   │   ├── insights/                # Analytics (11 dashboard pages)` |
| `docs/ARCHITECTURE.md` | `├── /statistics` | `├── /insights` |
| `docs/ARCHITECTURE.md` | `│   ├── /statistics/records` | `│   ├── /insights/overview` |
| `docs/ARCHITECTURE.md` | `│   ├── /statistics/gas` | `│   ├── /insights/gas` |
| `docs/ARCHITECTURE.md` | `│   ├── /statistics/progression` | `│   ├── /insights/progression` |

The `/statistics/records` line was already wrong (Records is the top-level `/records` route), so it becomes the real first sub-page. Keep the column alignment of the tree lines exactly as shown.

- [ ] **Step 3: Update the developer route table**

In `docs/developer/navigation.md`:
- In the top-level table, replace ``| `/statistics` | StatisticsPage | Analytics |`` with ``| `/insights` | InsightsPage | Insights |``.
- Replace the heading `### Statistics` (above the per-page route table) with `### Insights`.
- In that table's ten rows, apply three substitutions: `/statistics` becomes `/insights`, the route name prefix `statistics` becomes `insights` (for example `statisticsGas` becomes `insightsGas`), and the page class prefix `Statistics` becomes `Insights` (for example `StatisticsGasPage` becomes `InsightsGasPage`).

- [ ] **Step 4: Verify no stale doc links remain**

```bash
git grep -nE "guide/statistics|features/statistics|/statistics([/\`' ]|$)" -- docs README.md ':!docs/superpowers' ':!docs/releases' ':!docs/plans' ':!docs/CODE_OPTIMIZATION_PLAN.md'
```

Expected: no output. (Before this task the same command lists exactly the lines Steps 1 to 3 change; `docs/plans/` and `CODE_OPTIMIZATION_PLAN.md` are historical and excluded.)

- [ ] **Step 5: Commit**

```bash
git add -A -- docs README.md
git commit -m "docs: Statistics is now Insights"
```

---

### Task 7: Verify, then open the issues and PR

**Files:** none changed unless a check fails.

- [ ] **Step 1: Run every script check**

```bash
python3 scripts/rename_statistics_to_insights.py code --check
python3 scripts/rename_statistics_to_insights.py keys --check
python3 scripts/rename_statistics_to_insights.py values --check
python3 scripts/rename_statistics_to_insights_test.py
```

Expected: `0 leftover(s)` three times and `OK`.

- [ ] **Step 2: Full analyze and one full test run**

```bash
flutter analyze
flutter test
```

Expected: `No issues found!` and all tests pass. Run the suite once; do not start a second run while one is going.

- [ ] **Step 3: Manual check on macOS**

1. On the `main` build, open Settings, customise the navigation so Statistics sits in a non-default slot (phone order and, on a wide window, the rail), then quit.
2. Build and run this branch on macOS. Launch it from a standalone terminal such as Ghostty; launching from a terminal embedded in another app makes macOS attribute the app's permissions to that host app and crash it after the first frame.
3. Confirm: the nav item reads "Insights" with the insights glyph and sits in the slot chosen in step 1; the master-detail view opens on a wide window; a narrow window navigates to `/insights/<category>`; the dashboard quick action and the "View Insights" button on the dive-log summary open Insights; the keyboard shortcut labelled "Go to Insights" opens it; the dive edit form still has its "Statistics" group with "Exclude from statistics".

- [ ] **Step 4: Ask the user before creating anything on GitHub**

Propose these two issues and wait for approval:

- Umbrella: "Insights: broaden the Statistics section". Body: the four sub-projects from the spec's program table (rename; surface existing findings; home for upcoming features such as Connections #2321 and NL search #2195; derived observations), with this rename as phase 1.
- Phase 1: "Rename the Statistics section to Insights". Body: a summary of the spec's Decisions section and a link to the spec path.

After both exist, set their issue type over REST if the repo uses issue types (`gh issue create` leaves it empty).

- [ ] **Step 5: Push and open the PR (after the user says to)**

The PR body must contain `Closes #<phase-1>` and `Refs #<umbrella>`, summarise the six commits, list the two open PRs that touch the old folder (#2315, #2196) as needing a rebase plus `code --check` after this merges, and ask for native-speaker review of the ten translated section names.

- [ ] **Step 6: After merge**

Rebase #2315 and #2196 (or tell their owners), running `python3 scripts/rename_statistics_to_insights.py code` then `code --check` on each. Add "Statistics is now Insights" to the next release notes. Sub-project 3 starts by revising the Connections and NL search specs.
