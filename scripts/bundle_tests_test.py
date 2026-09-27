#!/usr/bin/env python3
"""Unit tests for bundle_tests.py."""

import contextlib
import importlib.util
import io
import os
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "bundle_tests",
    os.path.join(_HERE, "bundle_tests.py"),
)
bundler = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bundler)

PLAIN = "void main() {\n  test('a', () {});\n}\n"


def names(directory, count):
    return ["%s/f%02d_test.dart" % (directory, i) for i in range(count)]


class PackTest(unittest.TestCase):
    def test_a_directory_that_fits_is_one_bundle(self):
        files = names("test/a", 3)
        self.assertEqual(bundler.pack("test", files, 4), [files])

    def test_no_files_is_no_bundles(self):
        self.assertEqual(bundler.pack("test", [], 4), [])

    def test_an_oversized_directory_splits_by_subdirectory(self):
        a, b = names("test/a", 3), names("test/b", 3)
        self.assertEqual(bundler.pack("test", a + b, 4), [a, b])

    def test_sibling_directories_are_not_merged_by_size(self):
        a, b, c = names("test/a", 2), names("test/b", 2), names("test/c", 3)
        self.assertEqual(bundler.pack("test", a + b + c, 4), [a, b, c])

    def test_small_subdirectories_share_a_pool_with_the_parent_files(self):
        direct = ["test/x/f_test.dart"]
        a, b, c = names("test/x/a", 2), names("test/x/b", 5), names("test/x/c", 1)
        packed = bundler.pack("test/x", sorted(direct + a + b + c), 6, 3)
        self.assertEqual(packed, [sorted(direct + a + c), b])

    def test_a_pool_too_large_for_one_bundle_splits_in_sorted_order(self):
        a, b, c = names("test/x/a", 2), names("test/x/b", 2), names("test/x/c", 2)
        big = names("test/x/d", 7)
        packed = bundler.pack("test/x", sorted(a + b + c + big), 4, 3)
        self.assertEqual(packed, [a + b, c, big[0:4], big[4:7]])

    def test_an_oversized_leaf_splits_in_sorted_order(self):
        files = names("test/a", 5)
        self.assertEqual(
            bundler.pack("test", files, 2),
            [files[0:2], files[2:4], files[4:5]],
        )

    def test_a_directory_holds_both_files_and_subdirectories(self):
        direct = names("test/a", 3)
        nested = names("test/a/deep", 3)
        packed = bundler.pack("test", sorted(direct + nested), 4)
        self.assertEqual(packed, [direct, nested])

    def test_every_file_lands_in_exactly_one_bundle(self):
        files = sorted(
            names("test/a", 7) + names("test/a/x", 5) + names("test/b", 9)
        )
        packed = bundler.pack("test", files, 4)
        flat = [path for bundle in packed for path in bundle]
        self.assertEqual(sorted(flat), files)
        self.assertEqual(len(flat), len(set(flat)))
        self.assertTrue(all(len(bundle) <= 4 for bundle in packed))

    def test_adding_a_file_leaves_other_directories_alone(self):
        a, b, c = names("test/a", 3), names("test/b", 3), names("test/c", 3)
        before = bundler.pack("test", a + b + c, 4)
        after = bundler.pack("test", a + b + c + ["test/c/new_test.dart"], 4)
        self.assertEqual(before[:2], after[:2])

    def test_growing_one_directory_does_not_move_its_neighbours(self):
        dirs = [names("test/%s" % d, 2) for d in "abcd"]
        files = [f for group in dirs for f in group]
        before = bundler.pack("test", files, 4)
        after = bundler.pack("test", sorted(files + ["test/a/new_test.dart"]), 4)
        untouched = [bundle for bundle in before if "test/a/" not in bundle[0]]
        for bundle in untouched:
            self.assertIn(bundle, after)

    def test_growing_a_large_subdirectory_leaves_the_pool_alone(self):
        pool = names("test/x/a", 2) + names("test/x/b", 2)
        big = names("test/x/c", 5)
        before = bundler.pack("test/x", sorted(pool + big), 6, 3)
        after = bundler.pack("test/x", sorted(pool + big + ["test/x/c/zz_test.dart"]), 6, 3)
        self.assertEqual(before[0], after[0])


class RunAloneTest(unittest.TestCase):
    def test_a_plain_file_can_share(self):
        self.assertIsNone(bundler.run_alone_reason(PLAIN))

    def test_an_arrow_main_can_share(self):
        source = "void main() => group('g', () {});\n"
        self.assertIsNone(bundler.run_alone_reason(source))

    def test_the_marker_comment(self):
        source = "// test-bundle: run-alone leaks a timer\n" + PLAIN
        self.assertEqual(bundler.run_alone_reason(source), "marked run-alone")

    def test_a_marker_inside_a_string_does_not_count(self):
        source = "const s = '// test-bundle: run-alone';\n" + PLAIN
        self.assertIsNone(bundler.run_alone_reason(source))

    def test_library_level_annotations(self):
        for name in ("Tags", "TestOn", "Timeout", "Skip", "Retry", "OnPlatform"):
            source = "@%s(['x'])\nlibrary;\n%s" % (name, PLAIN)
            self.assertEqual(
                bundler.run_alone_reason(source),
                "library-level test annotation",
                name,
            )

    def test_an_annotation_on_a_member_does_not_count(self):
        source = "class A {\n  @override\n  String toString() => '';\n}\n" + PLAIN
        self.assertIsNone(bundler.run_alone_reason(source))

    def test_a_golden_comparison(self):
        source = "void main() {\n  expect(a, matchesGoldenFile('g.png'));\n}\n"
        self.assertEqual(
            bundler.run_alone_reason(source), "golden file comparison"
        )

    def test_an_async_main(self):
        source = "Future<void> main() async {\n  test('a', () {});\n}\n"
        self.assertEqual(bundler.run_alone_reason(source), "main() is async")

    def test_a_main_with_parameters(self):
        source = "void main(List<String> args) {\n  test('a', () {});\n}\n"
        self.assertEqual(
            bundler.run_alone_reason(source), "main() takes parameters"
        )

    def test_a_file_without_main(self):
        self.assertEqual(
            bundler.run_alone_reason("class A {}\n"), "no main() found"
        )


class WeightTest(unittest.TestCase):
    def test_counts_setup_unit_and_widget_cases(self):
        source = (
            "void main() {\n"
            "  test('a', () {});\n"
            "  testWidgets('b', (t) async {});\n"
            "  group('g', () {\n"
            "    test('c', () {});\n"
            "  });\n"
            "}\n"
        )
        expected = bundler.FILE_COST + 2 + bundler.WIDGET_COST
        self.assertEqual(bundler.weight(source), expected)

    def test_a_widget_case_costs_more_than_a_unit_case(self):
        unit = bundler.weight("void main() {\n  test('a', () {});\n}\n")
        widget = bundler.weight("void main() {\n  testWidgets('a', (t) async {});\n}\n")
        self.assertGreater(widget, unit)

    def test_a_file_with_no_cases_still_costs_its_setup(self):
        self.assertEqual(bundler.weight("void main() {}\n"), bundler.FILE_COST)


class AssignTest(unittest.TestCase):
    @staticmethod
    def unit(name, weight):
        return {"name": name, "files": [name], "weight": weight, "bundle": True}

    def test_shards_are_disjoint_and_complete(self):
        units = [self.unit("u%d" % i, i + 1) for i in range(11)]
        shards = bundler.assign(units, 3)
        flat = [unit["name"] for shard in shards for unit in shard]
        self.assertEqual(sorted(flat), sorted(u["name"] for u in units))
        self.assertEqual(len(flat), len(set(flat)))

    def test_the_heaviest_units_are_spread_first(self):
        units = [self.unit("a", 10), self.unit("b", 9), self.unit("c", 1)]
        shards = bundler.assign(units, 2)
        self.assertEqual([u["name"] for u in shards[0]], ["a"])
        self.assertEqual([u["name"] for u in shards[1]], ["b", "c"])

    def test_the_result_does_not_depend_on_input_order(self):
        units = [self.unit("u%d" % i, (i * 7) % 5 + 1) for i in range(9)]
        forward = bundler.assign(units, 4)
        backward = bundler.assign(list(reversed(units)), 4)
        self.assertEqual(forward, backward)

    def test_more_shards_than_units_leaves_some_empty(self):
        shards = bundler.assign([self.unit("a", 1)], 3)
        self.assertEqual([len(shard) for shard in shards], [1, 0, 0])


class RenderTest(unittest.TestCase):
    def test_each_file_runs_in_a_group_named_after_its_path(self):
        source = bundler.render(
            ["test/features/a/x_test.dart"], "test/.bundles"
        )
        self.assertIn("import '../features/a/x_test.dart' as t0;", source)
        self.assertIn("group('features/a/x_test.dart', () {", source)
        self.assertIn("      t0.main();", source)

    def test_the_harness_defaults_are_reapplied_per_file(self):
        source = bundler.render(["test/a_test.dart"], "test/.bundles")
        self.assertIn(
            "import '../helpers/global_test_defaults.dart';", source
        )
        self.assertIn("      applyGlobalTestDefaults();", source)

    def test_each_file_must_put_back_what_it_found(self):
        source = bundler.render(["test/a_test.dart"], "test/.bundles")
        self.assertIn(
            "import '../helpers/global_state_snapshot.dart';", source
        )
        self.assertIn("      before = GlobalStateSnapshot.take();", source)
        self.assertIn(
            "    tearDownAll(() => before.expectRestored());", source
        )

    def test_the_check_is_registered_before_the_files_own_tests(self):
        source = bundler.render(["test/a_test.dart"], "test/.bundles")
        self.assertLess(
            source.index("tearDownAll(() => before.expectRestored());"),
            source.index("t0.main();"),
        )

    def test_a_file_that_throws_while_declaring_fails_on_its_own(self):
        source = bundler.render(["test/a_test.dart"], "test/.bundles")
        self.assertIn("    try {\n      t0.main();\n    } catch", source)
        self.assertIn("(error, stack) {", source)
        self.assertIn("Error.throwWithStackTrace(error, stack)", source)

    def test_files_keep_the_order_they_were_given(self):
        source = bundler.render(
            ["test/z_test.dart", "test/a_test.dart"], "test/.bundles"
        )
        self.assertLess(
            source.index("z_test.dart' as t0"),
            source.index("a_test.dart' as t1"),
        )

    def test_quotes_and_dollars_in_a_path_are_escaped(self):
        source = bundler.render(["test/it's_$5_test.dart"], "test/.bundles")
        self.assertIn("import '../it\\'s_\\$5_test.dart' as t0;", source)
        self.assertIn("group('it\\'s_\\$5_test.dart', () {", source)

    def test_imports_use_forward_slashes(self):
        source = bundler.render(
            ["test/features/a/x_test.dart"], os.path.join("test", ".bundles")
        )
        self.assertNotIn("\\", source)


class MainTest(unittest.TestCase):
    def setUp(self):
        self._previous = os.getcwd()
        self._temp = tempfile.TemporaryDirectory()
        os.chdir(self._temp.name)
        os.makedirs(os.path.join("test", "helpers"))
        for directory, count in (("a", 3), ("b", 3), ("c", 3)):
            os.makedirs(os.path.join("test", directory))
            for index in range(count):
                self.write(
                    os.path.join(
                        "test", directory, "f%02d_test.dart" % index
                    ),
                    PLAIN,
                )
        self.write(
            os.path.join("test", "c", "tagged_test.dart"),
            "@Tags(['slow'])\nlibrary;\n" + PLAIN,
        )

    def tearDown(self):
        os.chdir(self._previous)
        self._temp.cleanup()

    @staticmethod
    def write(path, source):
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(source)

    def run_main(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        code = 0
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                code = bundler.main(list(argv))
            except SystemExit as stop:
                code = stop.code
        return code, out.getvalue().splitlines(), err.getvalue()

    def covered(self, paths):
        """The test files that the printed paths run."""
        files = []
        for path in paths:
            if "/.bundles/" not in path:
                files.append(path)
                continue
            for line in bundler.read_text(path).splitlines():
                if line.startswith("import '../") and "_test.dart" in line:
                    files.append("test/" + line.split("'")[1][3:])
        return files

    def test_bundles_are_printed_before_files_that_run_alone(self):
        code, lines, _ = self.run_main("--max-files", "4")
        self.assertEqual(code, 0)
        self.assertEqual(lines[-1], "test/c/tagged_test.dart")
        self.assertTrue(
            all(line.startswith("test/.bundles/bundle_") for line in lines[:-1])
        )
        self.assertTrue(all(os.path.isfile(line) for line in lines))

    def test_the_shards_together_run_every_test_file_once(self):
        files = []
        for shard in range(3):
            code, lines, _ = self.run_main(
                "--shard", str(shard), "--total-shards", "3",
                "--max-files", "4",
            )
            self.assertEqual(code, 0)
            files.extend(self.covered(lines))
        self.assertEqual(sorted(files), bundler.discover("test", "test/.bundles"))
        self.assertEqual(len(files), len(set(files)))

    def test_a_shard_with_nothing_to_run_prints_nothing(self):
        code, lines, _ = self.run_main(
            "--shard", "7", "--total-shards", "8", "--max-files", "120"
        )
        self.assertEqual(code, 0)
        self.assertEqual(lines, [])

    def test_bundles_from_an_earlier_run_are_removed(self):
        os.makedirs(os.path.join("test", ".bundles"))
        stale = os.path.join("test", ".bundles", "bundle_999_stale.dart")
        self.write(stale, "void main() {}\n")
        self.run_main("--max-files", "4")
        self.assertFalse(os.path.exists(stale))

    def test_generated_bundles_are_not_discovered_as_tests(self):
        self.run_main("--max-files", "4")
        first = self.run_main("--max-files", "4")[1]
        second = self.run_main("--max-files", "4")[1]
        self.assertEqual(first, second)

    def test_containing_selects_the_one_unit_that_runs_the_file(self):
        code, lines, _ = self.run_main(
            "--containing", "test/b/f01_test.dart", "--max-files", "4"
        )
        self.assertEqual(code, 0)
        self.assertEqual(len(lines), 1)
        self.assertIn("test/b/f01_test.dart", self.covered(lines))

    def test_containing_a_file_that_runs_alone_prints_the_file(self):
        code, lines, _ = self.run_main(
            "--containing", "test/c/tagged_test.dart", "--max-files", "4"
        )
        self.assertEqual(code, 0)
        self.assertEqual(lines, ["test/c/tagged_test.dart"])

    def test_containing_an_unknown_file_is_an_error(self):
        code, lines, err = self.run_main("--containing", "test/nope_test.dart")
        self.assertEqual(code, 2)
        self.assertEqual(lines, [])
        self.assertIn("test/nope_test.dart is not a test file", err)

    def test_files_bundles_exactly_the_given_files_in_order(self):
        code, lines, _ = self.run_main(
            "--files", "test/c/f00_test.dart", "test/a/f02_test.dart"
        )
        self.assertEqual(code, 0)
        self.assertEqual(lines, ["test/.bundles/bundle_probe.dart"])
        self.assertEqual(
            self.covered(lines),
            ["test/c/f00_test.dart", "test/a/f02_test.dart"],
        )

    def test_files_that_do_not_exist_are_an_error(self):
        code, _, err = self.run_main("--files", "test/nope_test.dart")
        self.assertEqual(code, 2)
        self.assertIn("no such test file: test/nope_test.dart", err)

    def test_a_shard_outside_the_range_is_an_error(self):
        code, _, err = self.run_main("--shard", "3", "--total-shards", "3")
        self.assertEqual(code, 2)
        self.assertIn("--shard must be from 0", err)

    def test_zero_max_files_is_an_error(self):
        code, lines, err = self.run_main("--max-files", "0")
        self.assertEqual(code, 2)
        self.assertEqual(lines, [])
        self.assertIn("--max-files must be at least 1", err)

    def test_files_and_containing_together_are_an_error(self):
        code, lines, err = self.run_main(
            "--files", "test/a/f00_test.dart",
            "--containing", "test/a/f00_test.dart",
        )
        self.assertEqual(code, 2)
        self.assertEqual(lines, [])
        self.assertIn("--files and --containing cannot be combined", err)

    def test_zero_shards_is_an_error(self):
        code, _, err = self.run_main("--total-shards", "0")
        self.assertEqual(code, 2)
        self.assertIn("--total-shards must be at least 1", err)


if __name__ == "__main__":
    unittest.main()
