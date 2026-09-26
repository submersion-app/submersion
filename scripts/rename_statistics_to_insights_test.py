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

    def test_git_show_of_an_old_commit_keeps_its_path(self):
        # The path names a file inside that commit, where it still lives
        # under the old name.
        line = ("// `git show 30234a3:lib/features/statistics/data/repositories/"
                "statistics_repository.dart`\n")
        self.assertEqual(
            rename.rewrite_dart(line, {"statistics_repository.dart":
                                       "insights_repository.dart"}, False),
            line)
        self.assertTrue(rename.is_historical_reference(line))
        self.assertFalse(rename.is_historical_reference(
            "import 'package:submersion/features/statistics/x.dart';"))

    def test_bare_id_only_where_allowed(self):
        self.assertEqual(self.rewrite("id: 'statistics',"),
                         "id: 'statistics',")
        self.assertEqual(self.rewrite("id: 'statistics',", bare_ids=True),
                         "id: 'insights',")


class FrozenScopeTest(unittest.TestCase):
    """The gate checks what existed at rename time, not the live tree, so
    later Insights work cannot trip it."""

    def test_file_names_are_the_ones_renamed_at_rename_time(self):
        mapping = rename.basename_map()
        self.assertEqual(len(mapping), 56)
        self.assertEqual(mapping["statistics_page.dart"], "insights_page.dart")
        # dive_log's own file; a future insights_section.dart must not map
        # back onto it.
        self.assertNotIn("statistics_section.dart", mapping)

    def test_bare_ids_are_only_rewritten_in_lib(self):
        # Tests may hold the legacy 'statistics' nav id on purpose, to
        # exercise the alias.
        for path in rename.BARE_ID_FILES:
            self.assertTrue(path.startswith("lib/"), path)


class RewriteDartEquivalenceTest(unittest.TestCase):
    def test_whole_file_and_line_by_line_agree(self):
        basenames = {"statistics_page.dart": "insights_page.dart"}
        text = ("import 'statistics_page.dart';\n"
                "final r = ref.watch(statisticsRepositoryProvider);\n"
                "context.go('/statistics');\n")
        expected = ("import 'insights_page.dart';\n"
                    "final r = ref.watch(insightsRepositoryProvider);\n"
                    "context.go('/insights');\n")
        self.assertEqual(rename.rewrite_dart(text, basenames, False), expected)
        # A git show line anywhere switches to line-by-line; the other lines
        # still get renamed.
        mixed = "// git show abc1234:lib/features/statistics/x.dart\n" + text
        self.assertEqual(
            rename.rewrite_dart(mixed, basenames, False),
            "// git show abc1234:lib/features/statistics/x.dart\n" + expected)


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
