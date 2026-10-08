# Isolate-Safe Tests and Bundled CI Test Runs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut the CI test job's cost by running test files in shared isolates, after repairing every test that leaves process-wide state behind (issue #2500).

**Architecture:** A Python script groups test files by directory into generated entrypoints ("bundles") that import each file and call its `main()` inside a group named after the file. The CI test job runs bundles instead of files; local runs and the pre-push hook are unchanged. Before that switch, 55 test files are repaired (49 that replace a global without restoring it, and 6 that depend on running first in the isolate), and an architecture guard keeps new leaks out. The guard starts with the 49 files and the harness config allowlisted as pending and fails when an allowlisted file no longer offends, so each repair removes its own entries and no commit is red.

**Tech Stack:** Python 3 standard library (`unittest`), Dart and flutter_test, GitHub Actions, Codecov.

**Spec:** `docs/design/specs/2026-09-27-isolate-safe-tests-and-ci-bundling-design.md`

## Global Constraints

- Worktree: every command and file path is inside `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/beautiful-galileo-db6f30`. Never edit or commit in the main checkout. Start every shell command with `cd` to that path.
- Branch: `ericgriffin/test-suite-pruning-f84119`. One PR, `Closes #2500`.
- Leaking tests get their root cause fixed. No file is excused from bundling because it leaks.
- Production code: the only change under `lib/` is `AppShortcuts.debugReset`.
- Bundling applies to CI only. Do not change `hooks/pre-push` or how tests run locally.
- The platform build jobs in `ci.yaml` are not touched.
- `codecov.yml` `after_n_builds` always equals the shard count plus one, and changes in the same commit as the shard matrix.
- Python: standard library only, and it must run on Python 3.9.
- Paths: `p.join` in Dart and `os.path.join` in Python. Dart import strings use forward slashes on every platform.
- Writing: no em-dashes, no en-dashes as punctuation, no double hyphens or spaced hyphens as prose punctuation, no emojis. This covers code, comments, docs, commit messages and the PR.
- Attribution: no trailers, and no mention of any AI tool or its vendor, in commits, the PR, or comments.
- Commits: conventional style, body `Refs #2500`. Stage explicit paths. Never `git add -A` or `git add -u`.
- After each task: `dart format .`, then `flutter analyze` (no issues, infos included). Judge pass or fail from the command's own exit status and summary line, never through a pipe to `grep`.
- Never run two `flutter test` invocations at the same time in this worktree.
- Line numbers are from commit `854715f5c8c`. Earlier tasks shift them, so find each anchor by the quoted code, and read the file before editing it.
- The guard is a ratchet: once a file is repaired, the guard fails until that file's `pending` entry is removed. Remove it in the same task.

## Review Focus

1. **A test file whose path holds a quote or a dollar sign.** The generated Dart must escape it, or the bundle does not compile and every test in it fails to load. Test: Task 1, `test_quotes_and_dollars_in_a_path_are_escaped`.
2. **Bundles left by an earlier run.** A stale bundle names files that may have moved, and would run them twice. Test: Task 1, `test_bundles_from_an_earlier_run_are_removed`.
3. **More shards than there are units.** The generator must print nothing and exit 0, and the CI step must then skip rather than run the whole suite. Tests: Task 1, `test_a_shard_with_nothing_to_run_prints_nothing`; Task 10 keeps the empty-shard guard.
4. **A restore written in an unusual shape.** Capturing in an arrow callback, or into a `final` inside the test body, must be accepted; a comparison must not count as a capture. Tests: Task 2, the `platform singletons` group.
5. **Roboto loaded for one file reaching the next.** Files that read PDF text expect Helvetica, so unloading must clear both `PdfFonts` and the printing cache. Test: Task 8, `unloading leaves nothing behind for the next file`.

## File Structure

| File | Responsibility |
|---|---|
| `scripts/bundle_tests.py` (new) | Discover test files, decide which run alone, group the rest by directory, assign units to shards, write bundles, print paths |
| `scripts/bundle_tests_test.py` (new) | Unit tests for the generator |
| `test/architecture/global_state_scanner.dart` (new) | Pattern scan: assignments to process-wide state with no restore in the same file |
| `test/architecture/global_state_scanner_test.dart` (new) | The scanner's accept and reject shapes, on synthetic source |
| `test/architecture/test_global_state_restored_test.dart` (new) | The guard: runs the scanner over `test/`, with the allowlist |
| `test/helpers/global_test_defaults.dart` (new) | The three harness defaults, in one function |
| `test/helpers/late_bound_share_platform.dart` (new) | A share platform that looks up the current fake on every share |
| `test/helpers/mock_channels.dart` (new) | Clears the path provider and share channel mocks |
| `test/helpers/pdf_roboto.dart` (new) | Loads and unloads Roboto for PDF tests, from the SDK |
| `test/flutter_test_config.dart` | Applies the defaults and pins the share forwarder, once per entrypoint |
| `lib/core/accessibility/app_shortcuts.dart` | Gains `debugReset` |
| 55 test files | Restore what they replace, or stop depending on running first |
| `.github/workflows/ci.yaml`, `codecov.yml`, `.gitignore` | The CI switch, the shard count, the generated directory |
| `docs/developer/testing.md`, the development guide at the repository root | The rule and how to reproduce a CI bundle |

---

### Task 1: Bundle generator

**Files:**
- Create: `scripts/bundle_tests.py`
- Create: `scripts/bundle_tests_test.py`
- Modify: `.gitignore` (append)
- Modify: `.github/workflows/ci.yaml:533-556` (Script Tests job)

**Interfaces:**
- Consumes: nothing.
- Produces: the command `python3 scripts/bundle_tests.py [--shard N] [--total-shards N] [--out DIR] [--max-files N] [--containing TEST_FILE | --files TEST_FILE ...]`. It writes bundles into `--out` (default `test/.bundles`), prints one path per line (bundles first, then files that run alone), and exits 0, or 2 on a usage error. `--files` writes a single bundle, `test/.bundles/bundle_probe.dart`, holding exactly the given files in the given order. Every bundle imports `test/helpers/global_test_defaults.dart` and calls `applyGlobalTestDefaults`, which Task 3 creates. Until Task 3 lands a generated bundle does not compile, so this task is verified by its unit tests alone.

- [ ] **Step 1: Write the failing tests**

Create `scripts/bundle_tests_test.py`:

```python
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

    def test_neighbouring_small_pieces_merge_up_to_the_limit(self):
        a, b, c = names("test/a", 2), names("test/b", 2), names("test/c", 3)
        self.assertEqual(bundler.pack("test", a + b + c, 4), [a + b, c])

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
    def test_counts_declared_cases(self):
        source = (
            "void main() {\n"
            "  test('a', () {});\n"
            "  testWidgets('b', (t) async {});\n"
            "  group('g', () {\n"
            "    test('c', () {});\n"
            "  });\n"
            "}\n"
        )
        self.assertEqual(bundler.weight(source), 3)

    def test_is_never_zero(self):
        self.assertEqual(bundler.weight("void main() {}\n"), 1)


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
        self.assertIn("    t0.main();", source)

    def test_the_harness_defaults_are_reapplied_per_file(self):
        source = bundler.render(["test/a_test.dart"], "test/.bundles")
        self.assertIn(
            "import '../helpers/global_test_defaults.dart';", source
        )
        self.assertIn("    setUpAll(applyGlobalTestDefaults);", source)

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

    def test_zero_shards_is_an_error(self):
        code, _, err = self.run_main("--total-shards", "0")
        self.assertEqual(code, 2)
        self.assertIn("--total-shards must be at least 1", err)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 scripts/bundle_tests_test.py`
Expected: FAIL with `FileNotFoundError` naming `scripts/bundle_tests.py`.

- [ ] **Step 3: Write the generator**

Create `scripts/bundle_tests.py`:

```python
#!/usr/bin/env python3
"""Group test files into bundles that share one isolate, for the CI test job.

`flutter test` compiles and loads every test file as its own entrypoint, and
with --coverage it collects a hit map per file, so CI time grows with the
number of test files rather than the number of tests. A bundle is a generated
entrypoint that imports many test files and calls each one's main() inside a
group named after the file. The files compile once and share an isolate
(issue #2500).

Usage:
    python3 scripts/bundle_tests.py --shard 0 --total-shards 6
    python3 scripts/bundle_tests.py --containing test/core/utils/foo_test.dart
    python3 scripts/bundle_tests.py --files test/a_test.dart test/b_test.dart

Writes the bundles it selects into --out and prints, one per line, the paths
to hand to `flutter test`: bundles first, then the test files that have to run
as their own entrypoint.

Run from the repository root. Standard library only.
"""

import argparse
import os
import posixpath
import re
import sys

DEFAULT_MAX_FILES = 120
DEFAULT_OUT = "test/.bundles"
TEST_ROOT = "test"
DEFAULTS_HELPER = "test/helpers/global_test_defaults.dart"
PROBE_NAME = "bundle_probe.dart"

_RUN_ALONE_MARKER = re.compile(r"^\s*//\s*test-bundle:\s*run-alone\b", re.M)
_LIBRARY_ANNOTATION = re.compile(
    r"^@(Tags|TestOn|Timeout|Skip|Retry|OnPlatform)\s*\(", re.M
)
_GOLDEN = re.compile(r"\bmatchesGoldenFile\s*\(")
_MAIN = re.compile(r"^\s*(?:[\w<>?]+\s+)?main\s*\(([^)]*)\)\s*(async\b)?", re.M)
_TEST_CASE = re.compile(r"^\s*(?:test|testWidgets)\s*\(", re.M)


def to_posix(path):
    """path with forward slashes, whatever the host separator is."""
    return os.path.normpath(path).replace(os.sep, "/")


def read_text(path):
    with open(path, encoding="utf-8", errors="replace") as handle:
        return handle.read()


def discover(root, out_dir):
    """Every *_test.dart under root, as sorted posix paths, skipping out_dir."""
    skip = to_posix(out_dir)
    found = []
    for directory, subdirs, names in os.walk(root):
        here = to_posix(directory)
        if here == skip or here.startswith(skip + "/"):
            subdirs[:] = []
            continue
        subdirs.sort()
        for name in names:
            if name.endswith("_test.dart"):
                found.append(here + "/" + name)
    return sorted(found)


def run_alone_reason(source):
    """Why a test file needs its own entrypoint, or None when it can share."""
    if _RUN_ALONE_MARKER.search(source):
        return "marked run-alone"
    if _LIBRARY_ANNOTATION.search(source):
        return "library-level test annotation"
    if _GOLDEN.search(source):
        return "golden file comparison"
    main = _MAIN.search(source)
    if main is None:
        return "no main() found"
    if main.group(1).strip():
        return "main() takes parameters"
    if main.group(2):
        return "main() is async"
    return None


def weight(source):
    """How much work a test file is: its declared test count, at least 1."""
    return max(1, len(_TEST_CASE.findall(source)))


def pack(directory, files, max_files):
    """Split files, all under directory, into ordered bundles.

    A directory that fits is one bundle. One that does not is split into its
    own files and its subdirectories, each packed the same way, and
    neighbouring pieces are merged while they still fit. Membership follows
    the directory tree, so adding a test file changes the bundle for its own
    directory and leaves the others alone.
    """
    if not files:
        return []
    if len(files) <= max_files:
        return [list(files)]
    prefix = directory + "/"
    direct = []
    children = {}
    for path in files:
        rest = path[len(prefix):]
        if "/" in rest:
            children.setdefault(rest.split("/", 1)[0], []).append(path)
        else:
            direct.append(path)
    pieces = [direct[i:i + max_files] for i in range(0, len(direct), max_files)]
    for child in sorted(children):
        pieces.extend(pack(prefix + child, children[child], max_files))
    merged = []
    for piece in pieces:
        if merged and len(merged[-1]) + len(piece) <= max_files:
            merged[-1] = merged[-1] + piece
        else:
            merged.append(list(piece))
    return merged


def bundle_name(index, files):
    """A file name that says where the bundle's tests live."""
    common = posixpath.commonpath([posixpath.dirname(f) for f in files])
    slug = re.sub(r"[^A-Za-z0-9]+", "_", common[len(TEST_ROOT):]).strip("_")
    return "bundle_%03d_%s.dart" % (index, slug or "root")


def build_units(files, read, max_files):
    """Every unit for the tree: bundles, then the files that run alone.

    A unit is a dict: 'name' (a bundle's file name, or the test file's path),
    'files' (the test files it runs), 'weight', and 'bundle' (True for a
    generated entrypoint).
    """
    sources = {path: read(path) for path in files}
    alone = [path for path in files if run_alone_reason(sources[path])]
    excluded = set(alone)
    shared = [path for path in files if path not in excluded]
    units = []
    for index, members in enumerate(pack(TEST_ROOT, shared, max_files)):
        units.append({
            "name": bundle_name(index, members),
            "files": members,
            "weight": sum(weight(sources[path]) for path in members),
            "bundle": True,
        })
    for path in alone:
        units.append({
            "name": path,
            "files": [path],
            "weight": weight(sources[path]),
            "bundle": False,
        })
    return units


def assign(units, total_shards):
    """Spread units over shards: heaviest first, each to the lightest shard."""
    shards = [[] for _ in range(total_shards)]
    loads = [0] * total_shards
    for unit in sorted(units, key=lambda u: (-u["weight"], u["name"])):
        target = min(range(total_shards), key=lambda i: (loads[i], i))
        shards[target].append(unit)
        loads[target] += unit["weight"]
    return shards


def dart_string(text):
    """text as a single-quoted Dart string literal."""
    escaped = text.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")
    return "'" + escaped + "'"


def render(files, out_dir):
    """The Dart source of a bundle that runs files, in order, in one isolate."""
    out = to_posix(out_dir)
    lines = [
        "// Generated by scripts/bundle_tests.py. Not checked in.",
        "import 'package:flutter_test/flutter_test.dart';",
        "",
        "import %s;" % dart_string(posixpath.relpath(DEFAULTS_HELPER, out)),
    ]
    for index, path in enumerate(files):
        relative = posixpath.relpath(path, out)
        lines.append("import %s as t%d;" % (dart_string(relative), index))
    lines += ["", "void main() {"]
    for index, path in enumerate(files):
        label = posixpath.relpath(path, TEST_ROOT)
        lines.append("  group(%s, () {" % dart_string(label))
        lines.append("    setUpAll(applyGlobalTestDefaults);")
        lines.append("    t%d.main();" % index)
        lines.append("  });")
    lines.append("}")
    return "\n".join(lines) + "\n"


def unit_path(unit, out_dir):
    """The path `flutter test` is given for unit."""
    if unit["bundle"]:
        return to_posix(out_dir) + "/" + unit["name"]
    return unit["name"]


def write_bundles(units, out_dir):
    """Write the bundles among units, replacing any left by an earlier run."""
    os.makedirs(out_dir, exist_ok=True)
    for name in os.listdir(out_dir):
        if name.startswith("bundle_") and name.endswith(".dart"):
            os.remove(os.path.join(out_dir, name))
    for unit in units:
        if not unit["bundle"]:
            continue
        target = os.path.join(out_dir, unit["name"])
        with open(target, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(render(unit["files"], out_dir))


def select(args, parser):
    """The units this invocation runs."""
    if args.files:
        files = [to_posix(path) for path in args.files]
        missing = [path for path in files if not os.path.isfile(path)]
        if missing:
            parser.error("no such test file: %s" % ", ".join(missing))
        return [{
            "name": PROBE_NAME,
            "files": files,
            "weight": len(files),
            "bundle": True,
        }]
    units = build_units(
        discover(TEST_ROOT, args.out), read_text, args.max_files
    )
    if args.containing:
        wanted = to_posix(args.containing)
        chosen = [unit for unit in units if wanted in unit["files"]]
        if not chosen:
            parser.error(
                "%s is not a test file under %s/" % (wanted, TEST_ROOT)
            )
        return chosen
    return assign(units, args.total_shards)[args.shard]


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Group test files into bundles that share one isolate."
    )
    parser.add_argument("--shard", type=int, default=0)
    parser.add_argument("--total-shards", type=int, default=1)
    parser.add_argument("--out", default=DEFAULT_OUT)
    parser.add_argument("--max-files", type=int, default=DEFAULT_MAX_FILES)
    parser.add_argument(
        "--containing",
        metavar="TEST_FILE",
        help="select only the unit that runs this test file",
    )
    parser.add_argument(
        "--files",
        nargs="+",
        metavar="TEST_FILE",
        help="bundle exactly these files, in this order",
    )
    args = parser.parse_args(argv)
    if args.total_shards < 1:
        parser.error("--total-shards must be at least 1")
    if not 0 <= args.shard < args.total_shards:
        parser.error("--shard must be from 0 to --total-shards minus 1")
    if args.max_files < 1:
        parser.error("--max-files must be at least 1")
    if args.files and args.containing:
        parser.error("--files and --containing cannot be combined")

    chosen = select(args, parser)
    write_bundles(chosen, args.out)
    ordered = sorted(chosen, key=lambda u: (not u["bundle"], u["name"]))
    for unit in ordered:
        print(unit_path(unit, args.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 scripts/bundle_tests_test.py`
Expected: `Ran 41 tests` and `OK`.

- [ ] **Step 5: Run it on the real tree**

```bash
python3 scripts/bundle_tests.py --total-shards 1 | wc -l
ls test/.bundles | head -3
rm -rf test/.bundles
```

Expected: about 48 lines (41 bundles and 7 files that run alone; the count moves as tests are added), and names such as `bundle_000_root.dart`.

- [ ] **Step 6: Ignore the generated directory**

Append to `.gitignore`:

```text
# Test bundles, generated per run by scripts/bundle_tests.py (issue #2500)
test/.bundles/
```

`dart format` and the analyzer both skip directories whose name starts with a dot, so nothing else needs excluding.

- [ ] **Step 7: Run the generator's tests in CI**

In `.github/workflows/ci.yaml`, step `Run Python guard tests with coverage`:

Append `,scripts/bundle_tests.py` inside the quotes of the `guards='...'` line, after `scripts/release/sanitize_apple_store_notes.py`.

Insert these two lines directly above the line `python3 -m coverage report -m --include="$guards"`:

```yaml
          python3 -m coverage run --append --include="$guards" \
            scripts/bundle_tests_test.py
```

- [ ] **Step 8: Commit**

```bash
git add scripts/bundle_tests.py scripts/bundle_tests_test.py .gitignore .github/workflows/ci.yaml
git commit -m "test(ci): add a generator that bundles test files by directory" -m "Refs #2500"
```

---

### Task 2: Scanner and guard

**Files:**
- Create: `test/architecture/global_state_scanner.dart`
- Create: `test/architecture/global_state_scanner_test.dart`
- Create: `test/architecture/test_global_state_restored_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `List<GlobalStateOffence> scanForUnrestoredGlobals(String path, String source)`; the rule names `platformRule`, `httpRule`, `harnessRule`, `channelRule`; and the guard's `allowed` map, from which Tasks 3 to 6 remove entries. The scanner accepts the names `applyGlobalTestDefaults` (Task 3) and `clearPathAndShareChannelMocks` (Task 6) as restores.

- [ ] **Step 1: Write the scanner's failing tests**

Create `test/architecture/global_state_scanner_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'global_state_scanner.dart';

/// Unit tests for the scanner that backs
/// `test/architecture/test_global_state_restored_test.dart`.
///
/// Uses synthetic source rather than the real `test/` tree, so the accept and
/// reject shapes stay pinned as the suite changes.
void main() {
  List<GlobalStateOffence> scan(String source) =>
      scanForUnrestoredGlobals('test/x_test.dart', source);

  group('platform singletons', () {
    test('an assignment with no capture is an offence', () {
      final offences = scan('''
void main() {
  setUp(() {
    PathProviderPlatform.instance = _Fake();
  });
}
''');

      expect(offences, hasLength(1));
      expect(offences.single.rule, platformRule);
      expect(offences.single.line, 3);
      expect(offences.single.text, 'PathProviderPlatform.instance = _Fake();');
      expect(
        offences.single.toString(),
        'test/x_test.dart:3: [platform singleton] '
        'PathProviderPlatform.instance = _Fake();',
      );
    });

    test('capturing the previous value in setUp is accepted', () {
      final offences = scan('''
late PathProviderPlatform original;
setUp(() {
  original = PathProviderPlatform.instance;
  PathProviderPlatform.instance = _Fake();
});
tearDown(() => PathProviderPlatform.instance = original);
''');

      expect(offences, isEmpty);
    });

    test('capturing inside an arrow callback is accepted', () {
      final offences = scan('''
setUp(() => original = PermissionHandlerPlatform.instance);
tearDown(() => PermissionHandlerPlatform.instance = original);
''');

      expect(offences, isEmpty);
    });

    test('capturing into a final inside the test body is accepted', () {
      final offences = scan('''
test('t', () {
  final original = VideoPlayerPlatform.instance;
  VideoPlayerPlatform.instance = _Fake();
  addTearDown(() => VideoPlayerPlatform.instance = original);
});
''');

      expect(offences, isEmpty);
    });

    test('a comparison is not a capture', () {
      final offences = scan('''
setUp(() => SharePlatform.instance = fake);
test('t', () => expect(fake == SharePlatform.instance, isTrue));
''');

      expect(offences.map((o) => o.rule), [platformRule]);
    });

    test('capturing one platform does not excuse another', () {
      final offences = scan('''
final original = SharePlatform.instance;
SharePlatform.instance = share;
PathProviderPlatform.instance = paths;
''');

      expect(offences.map((o) => o.line), [3]);
    });

    test('every unrestored assignment is reported', () {
      final offences = scan('''
test('a', () => PathProviderPlatform.instance = one);
test('b', () => PathProviderPlatform.instance = two);
''');

      expect(offences.map((o) => o.line), [1, 2]);
    });

    test('an assignment in a comment is ignored', () {
      final offences = scan('''
// PathProviderPlatform.instance = _Fake();
void main() {}
''');

      expect(offences, isEmpty);
    });
  });

  group('HTTP overrides', () {
    test('an assignment with no capture is an offence', () {
      final offences = scan('HttpOverrides.global = _Overrides();\n');

      expect(offences.map((o) => o.rule), [httpRule]);
    });

    test('capturing HttpOverrides.current is accepted', () {
      final offences = scan('''
final previous = HttpOverrides.current;
HttpOverrides.global = _Overrides();
addTearDown(() => HttpOverrides.global = previous);
''');

      expect(offences, isEmpty);
    });
  });

  group('harness defaults', () {
    for (final name in harnessDefaults) {
      test('changing $name without the helper is an offence', () {
        final offences = scan('setUp(() => $name = true);\n');

        expect(offences.map((o) => o.rule), [harnessRule]);
      });

      test('changing $name and calling the helper is accepted', () {
        final offences = scan('''
setUp(() => $name = true);
tearDown(applyGlobalTestDefaults);
''');

        expect(offences, isEmpty);
      });
    }

    test('restoring by hand is still an offence', () {
      final offences = scan('''
setUp(() => QualityScanScheduler.enabled = true);
tearDown(() => QualityScanScheduler.enabled = false);
''');

      expect(offences.map((o) => o.line), [1, 2]);
    });

    test('reading a default is not an offence', () {
      final offences = scan('''
test('t', () => expect(QualityScanScheduler.enabled == false, isTrue));
''');

      expect(offences, isEmpty);
    });
  });

  group('channel mocks', () {
    const install = '''
setUpAll(() {
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => dir.path,
  );
});
''';

    test('a handler that is never removed is an offence', () {
      final offences = scan(install);

      expect(offences, hasLength(1));
      expect(offences.single.rule, channelRule);
      expect(offences.single.line, 2);
    });

    test('calling the clearing helper is accepted', () {
      final offences = scan(
        '${install}tearDownAll(clearPathAndShareChannelMocks);\n',
      );

      expect(offences, isEmpty);
    });

    test('removing the handler by hand is accepted', () {
      final offences = scan('''
${install}tearDownAll(() {
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    null,
  );
});
''');

      expect(offences, isEmpty);
    });

    test('a handler that answers null is not a removal', () {
      final offences = scan('''
setUpAll(() {
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/share'),
    (call) async => null,
  );
});
''');

      expect(offences.map((o) => o.rule), [channelRule]);
    });

    test('a mock on any other channel is not covered', () {
      final offences = scan('''
setUpAll(() {
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/url_launcher'),
    (call) async => true,
  );
});
''');

      expect(offences, isEmpty);
    });
  });

  test('a file with Windows line endings reports clean text', () {
    final offences = scan(
      'SharePlatform.instance = fake;\r\nvoid main() {}\r\n',
    );

    expect(offences.single.text, 'SharePlatform.instance = fake;');
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/architecture/global_state_scanner_test.dart`
Expected: FAIL to load, with an error that `global_state_scanner.dart` does not exist.

- [ ] **Step 3: Write the scanner**

Create `test/architecture/global_state_scanner.dart`:

```dart
/// Finds test code that replaces process-wide state and does not put it back.
///
/// CI runs many test files in one isolate (issue #2500), so whatever one file
/// leaves in a global is what the next file starts with. The scan is a pattern
/// match over source text: it proves a restore is written, not that it runs on
/// every path.
library;

/// One assignment that nothing in the same file undoes.
class GlobalStateOffence {
  const GlobalStateOffence({
    required this.path,
    required this.line,
    required this.rule,
    required this.text,
  });

  final String path;
  final int line;
  final String rule;
  final String text;

  @override
  String toString() => '$path:$line: [$rule] $text';
}

/// Globals `test/flutter_test_config.dart` sets once per entrypoint.
const harnessDefaults = [
  'QualityScanScheduler.enabled',
  'SensorSummaryScheduler.enabled',
  'debugCanShareFiles',
];

/// Channels whose mock handlers change what the path provider and the share
/// sheet answer for every file that runs afterwards.
const mockedChannels = [
  'plugins.flutter.io/path_provider',
  'dev.fluttercommunity.plus/share',
];

const platformRule = 'platform singleton';
const httpRule = 'HTTP overrides';
const harnessRule = 'harness default';
const channelRule = 'channel mock';

final _platformAssignment = RegExp(r'\b([A-Z]\w*Platform)\.instance\s*=(?!=)');
final _httpAssignment = RegExp(r'\bHttpOverrides\.global\s*=(?!=)');
final _httpCapture = RegExp(r'(?<![=!<>])=\s*HttpOverrides\.current\b');
final _nullHandler = RegExp(
  r'setMockMethodCallHandler\([^;]*?,\s*null\s*,?\s*\)',
  dotAll: true,
);

/// Every assignment in [source] that replaces a global without the file also
/// holding on to what was there.
List<GlobalStateOffence> scanForUnrestoredGlobals(String path, String source) {
  final lines = source.split('\n');
  // Comments may describe an assignment freely.
  final code = [for (final line in lines) line.split('//').first];
  final all = code.join('\n');
  final offences = <GlobalStateOffence>[];

  void flag(int index, String rule) {
    offences.add(
      GlobalStateOffence(
        path: path,
        line: index + 1,
        rule: rule,
        text: lines[index].trim(),
      ),
    );
  }

  final restoresDefaults = all.contains('applyGlobalTestDefaults');
  for (var i = 0; i < code.length; i++) {
    for (final match in _platformAssignment.allMatches(code[i])) {
      final name = match.group(1)!;
      final capture = RegExp('(?<![=!<>])=\\s*$name\\.instance\\b');
      if (!capture.hasMatch(all)) flag(i, platformRule);
    }
    if (_httpAssignment.hasMatch(code[i]) && !_httpCapture.hasMatch(all)) {
      flag(i, httpRule);
    }
    if (!restoresDefaults) {
      for (final name in harnessDefaults) {
        final assignment = RegExp('\\b${RegExp.escape(name)}\\s*=(?!=)');
        if (assignment.hasMatch(code[i])) flag(i, harnessRule);
      }
    }
  }

  final mocksChannel =
      all.contains('setMockMethodCallHandler') &&
      mockedChannels.any(all.contains);
  final clearsChannel =
      all.contains('clearPathAndShareChannelMocks') ||
      _nullHandler.hasMatch(all);
  if (mocksChannel && !clearsChannel) {
    flag(
      code.indexWhere((line) => line.contains('setMockMethodCallHandler')),
      channelRule,
    );
  }
  return offences;
}
```

- [ ] **Step 4: Run the scanner's tests to verify they pass**

Run: `flutter test test/architecture/global_state_scanner_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Write the guard, with every current offender pending**

Create `test/architecture/test_global_state_restored_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'global_state_scanner.dart';

/// A test that replaces process-wide state has to put it back.
///
/// CI runs many test files in one isolate (issue #2500). A platform singleton,
/// a harness default or a channel mock that one file leaves behind is what the
/// next file starts with, so the failure shows up in a different file from the
/// one that caused it, often in an unrelated change. This scan catches the
/// leak where it is written.
///
/// What to write instead:
///
/// * A `*Platform.instance` or `HttpOverrides.global`: read the previous value
///   into a variable first, and assign it back in `tearDown` or `addTearDown`.
/// * `QualityScanScheduler.enabled`, `SensorSummaryScheduler.enabled` or
///   `debugCanShareFiles`: call `applyGlobalTestDefaults()` from
///   `test/helpers/global_test_defaults.dart` in `tearDown`.
/// * A mock on the path provider or share channel: call
///   `clearPathAndShareChannelMocks()` from `test/helpers/mock_channels.dart`
///   in `tearDownAll`.
void main() {
  /// Written by `scripts/bundle_tests.py` and never checked in.
  bool isGenerated(String path) => path.startsWith('test/.bundles/');

  /// Files that replace a global on purpose, each with the reason. The
  /// entries marked pending are repaired by the change that adds this test.
  const allowed = <String, String>{
    'test/core/services/background_service_backup_test.dart':
        'pending repair, issue #2500',
    'test/core/services/cloud_storage/google_drive/google_sign_in_authenticator_test.dart':
        'pending repair, issue #2500',
    'test/core/services/database_service_headless_upgrade_guard_test.dart':
        'pending repair, issue #2500',
    'test/core/services/database_service_isolate_test.dart':
        'pending repair, issue #2500',
    'test/core/services/database_service_location_adoption_test.dart':
        'pending repair, issue #2500',
    'test/core/services/database_service_vacuum_test.dart':
        'pending repair, issue #2500',
    'test/core/services/export/excel/maintenance_excel_export_service_test.dart':
        'pending repair, issue #2500',
    'test/core/services/export/export_service_dive_types_test.dart':
        'pending repair, issue #2500',
    'test/core/services/export/export_service_pdf_units_test.dart':
        'pending repair, issue #2500',
    'test/core/services/export/pdf/pdf_course_export_service_test.dart':
        'pending repair, issue #2500',
    'test/core/services/export/pdf/pdf_trip_export_test.dart':
        'pending repair, issue #2500',
    'test/core/services/export/shared/save_and_share_file_test.dart':
        'pending repair, issue #2500',
    'test/core/services/export/shared/share_file_fallback_test.dart':
        'pending repair, issue #2500',
    'test/core/services/export_service_test.dart':
        'pending repair, issue #2500',
    'test/core/services/local_cache_database_service_test.dart':
        'pending repair, issue #2500',
    'test/core/services/sync/base_export_blob_paging_test.dart':
        'pending repair, issue #2500',
    'test/core/services/sync/base_export_fact_clock_watermark_test.dart':
        'pending repair, issue #2500',
    'test/features/backup/data/services/backup_encryption_backup_test.dart':
        'pending repair, issue #2500',
    'test/features/backup/data/services/backup_service_database_copy_restore_test.dart':
        'pending repair, issue #2500',
    'test/features/backup/data/services/backup_service_encryption_test.dart':
        'pending repair, issue #2500',
    'test/features/backup/data/services/backup_service_newer_schema_test.dart':
        'pending repair, issue #2500',
    'test/features/backup/data/services/backup_service_premigration_restore_test.dart':
        'pending repair, issue #2500',
    'test/features/backup/data/services/backup_service_replace_test.dart':
        'pending repair, issue #2500',
    'test/features/backup/data/services/backup_service_saf_io_test.dart':
        'pending repair, issue #2500',
    'test/features/backup/data/services/backup_service_saf_refs_test.dart':
        'pending repair, issue #2500',
    'test/features/backup/data/services/backup_service_test.dart':
        'pending repair, issue #2500',
    'test/features/backup/data/services/backup_target_lease_test.dart':
        'pending repair, issue #2500',
    'test/features/courses/presentation/pages/course_detail_export_units_test.dart':
        'pending repair, issue #2500',
    'test/features/data_quality/data/quality_scan_service_test.dart':
        'pending repair, issue #2500',
    'test/features/data_quality/presentation/data_quality_inbox_page_test.dart':
        'pending repair, issue #2500',
    'test/features/data_quality/presentation/quality_inbox_providers_test.dart':
        'pending repair, issue #2500',
    'test/features/data_quality/repairs/profile_repair_service_test.dart':
        'pending repair, issue #2500',
    'test/features/data_quality/repairs/quality_repair_executor_test.dart':
        'pending repair, issue #2500',
    'test/features/equipment/data/services/sensor_summary_scheduler_test.dart':
        'pending repair, issue #2500',
    'test/features/gas_calculators/blender_invoice_test.dart':
        'pending repair, issue #2500',
    'test/features/media/presentation/media_selection_test.dart':
        'pending repair, issue #2500',
    'test/features/media/presentation/media_share_helper_test.dart':
        'pending repair, issue #2500',
    'test/features/media/presentation/pages/media_viewer_video_test.dart':
        'pending repair, issue #2500',
    'test/features/media_store/media_cache_eviction_provider_test.dart':
        'pending repair, issue #2500',
    'test/features/media_store/media_cache_root_test.dart':
        'pending repair, issue #2500',
    'test/features/planner/plan_canvas_share_anchor_test.dart':
        'pending repair, issue #2500',
    'test/features/planner/saved_plans_sheet_test.dart':
        'pending repair, issue #2500',
    'test/features/settings/presentation/pages/storage_settings_pick_failure_test.dart':
        'pending repair, issue #2500',
    'test/features/settings/presentation/pages/storage_settings_reset_test.dart':
        'pending repair, issue #2500',
    'test/features/settings/presentation/providers/debug_log_providers_test.dart':
        'pending repair, issue #2500',
    'test/features/settings/presentation/providers/export_pdf_logbook_test.dart':
        'pending repair, issue #2500',
    'test/features/settings/presentation/providers/export_uddf_profiles_test.dart':
        'pending repair, issue #2500',
    'test/features/settings/presentation/providers/storage_usage_wiring_test.dart':
        'pending repair, issue #2500',
    'test/flutter_test_config.dart': 'pending repair, issue #2500',
    'test/integration/uddf_round_trip_test.dart': 'pending repair, issue #2500',
  };

  Map<String, List<GlobalStateOffence>> scan() {
    final found = <String, List<GlobalStateOffence>>{};
    for (final entity in Directory('test').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (isGenerated(path)) continue;
      final offences = scanForUnrestoredGlobals(
        path,
        entity.readAsStringSync(),
      );
      if (offences.isNotEmpty) found[path] = offences;
    }
    return found;
  }

  test('no test leaves a replaced global behind', () {
    final offenders = [
      for (final entry in scan().entries)
        if (!allowed.containsKey(entry.key)) ...entry.value,
    ];
    expect(
      offenders,
      isEmpty,
      reason:
          'These assignments replace process-wide state that nothing in the '
          'same file restores. The comment at the top of this test says what '
          'to write instead:\n${offenders.join('\n')}',
    );
  });

  test('every allowlisted file still exists', () {
    for (final path in allowed.keys) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('every allowlisted file still needs its entry', () {
    final found = scan();
    final stale = [
      for (final path in allowed.keys)
        if (!found.containsKey(path)) path,
    ];
    expect(
      stale,
      isEmpty,
      reason:
          'These files no longer replace a global without restoring it. '
          'Remove their entries from the allowlist:\n${stale.join('\n')}',
    );
  });
}
```

- [ ] **Step 6: Run the guard**

Run: `flutter test test/architecture/test_global_state_restored_test.dart`
Expected: `All tests passed!`

If `no test leaves a replaced global behind` fails, main has gained a new offender since this plan was written. Add each file it names to `allowed` as `'pending repair, issue #2500'` and repair it in the task that covers its rule (the rule is in square brackets in the message).

- [ ] **Step 7: Prove the guard bites**

Delete the entry for `test/features/media_store/media_cache_root_test.dart` from `allowed` and run the guard again.
Expected: FAIL, naming `test/features/media_store/media_cache_root_test.dart:34: [platform singleton] PathProviderPlatform.instance = platform;`.
Put the entry back and confirm the guard passes.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add test/architecture/global_state_scanner.dart test/architecture/global_state_scanner_test.dart test/architecture/test_global_state_restored_test.dart
git commit -m "test(architecture): guard against tests that leave a replaced global behind" -m "Refs #2500"
```

---

### Task 3: Harness defaults

**Files:**
- Create: `test/helpers/global_test_defaults.dart`
- Create: `test/helpers/global_test_defaults_test.dart`
- Modify: `test/flutter_test_config.dart` (whole file)
- Modify: nine test files, listed in Step 5
- Modify: `test/architecture/test_global_state_restored_test.dart` (remove 7 entries)

**Interfaces:**
- Consumes: the guard from Task 2.
- Produces: `void applyGlobalTestDefaults()`, which generated bundles call before each file and tests call in `tearDown`.

- [ ] **Step 1: Write the failing test**

Create `test/helpers/global_test_defaults_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';

import 'global_test_defaults.dart';

void main() {
  tearDown(applyGlobalTestDefaults);

  test('the harness applies the defaults before any test runs', () {
    expect(QualityScanScheduler.enabled, isFalse);
    expect(SensorSummaryScheduler.enabled, isFalse);
    expect(canShareFiles, isTrue);
  });

  test('puts every harness default back', () {
    QualityScanScheduler.enabled = true;
    SensorSummaryScheduler.enabled = true;
    debugCanShareFiles = false;

    applyGlobalTestDefaults();

    expect(QualityScanScheduler.enabled, isFalse);
    expect(SensorSummaryScheduler.enabled, isFalse);
    expect(canShareFiles, isTrue);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/helpers/global_test_defaults_test.dart`
Expected: FAIL to load, with an error that `global_test_defaults.dart` does not exist.

- [ ] **Step 3: Write the helper**

Create `test/helpers/global_test_defaults.dart`:

```dart
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';

/// The state every test file starts from.
///
/// `test/flutter_test_config.dart` applies it once per entrypoint, and a
/// generated bundle applies it again before each file it runs, because the
/// files in a bundle share one isolate (issue #2500). A test that changes one
/// of these calls this in its `tearDown`, so the next test starts from the
/// same place whichever file it is in.
///
/// The data-quality scan scheduler is fire-and-forget: import, save,
/// consolidation and repair flows call `scheduleQualityScan(...)`, which runs
/// a real scan against `DatabaseService.instance.database`. In widget and
/// adapter tests that is unwanted work that can leave pending async
/// operations, so it is off unless a test turns it on. The sensor summary
/// scheduler is off for the same reason.
///
/// `canShareFiles` reads the host platform, and it is false on Linux because
/// share_plus cannot put files on the sheet there. Left alone, every test that
/// runs an export would take the save-dialog fallback on Linux and the share
/// sheet everywhere else. It is pinned to the share sheet, which is what those
/// tests assert against.
void applyGlobalTestDefaults() {
  QualityScanScheduler.enabled = false;
  SensorSummaryScheduler.enabled = false;
  debugCanShareFiles = true;
}
```

- [ ] **Step 4: Make the harness use it**

Replace the whole of `test/flutter_test_config.dart` with:

```dart
import 'dart:async';

import 'helpers/global_test_defaults.dart';

/// Global test harness config, run once per entrypoint by `flutter test`.
///
/// An entrypoint is a test file, or in CI a generated bundle of test files
/// that share one isolate (issue #2500).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  applyGlobalTestDefaults();
  await testMain();
}
```

Run: `flutter test test/helpers/global_test_defaults_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Restore through the helper in the nine files**

In each file, add the import to the block of relative imports, in alphabetical order, and make the replacement. Every replacement is one line.

| File | Import | Replace | With |
|---|---|---|---|
| `test/features/data_quality/presentation/data_quality_inbox_page_test.dart` (line 288) | `import '../../../helpers/global_test_defaults.dart';` | `    QualityScanScheduler.enabled = true;` | `    applyGlobalTestDefaults();` |
| `test/features/data_quality/presentation/quality_inbox_providers_test.dart` (line 28) | `import '../../../helpers/global_test_defaults.dart';` | `    QualityScanScheduler.enabled = true;` | `    applyGlobalTestDefaults();` |
| `test/features/data_quality/repairs/profile_repair_service_test.dart` (line 145) | `import '../../../helpers/global_test_defaults.dart';` | `      QualityScanScheduler.enabled = true;` | `      applyGlobalTestDefaults();` |
| `test/features/data_quality/repairs/quality_repair_executor_test.dart` (line 31) | `import '../../../helpers/global_test_defaults.dart';` | `    QualityScanScheduler.enabled = true;` | `    applyGlobalTestDefaults();` |
| `test/features/data_quality/data/quality_scan_service_test.dart` (line 108) | `import '../../../helpers/global_test_defaults.dart';` | `    addTearDown(() => QualityScanScheduler.enabled = false);` | `    addTearDown(applyGlobalTestDefaults);` |
| `test/features/equipment/data/services/sensor_summary_scheduler_test.dart` (line 32, inside `addTearDown`) | `import '../../../../helpers/global_test_defaults.dart';` | `      SensorSummaryScheduler.enabled = false;` | `      applyGlobalTestDefaults();` |
| `test/core/services/export/export_service_pdf_units_test.dart` (line 72) | `import '../../../helpers/global_test_defaults.dart';` | `    debugCanShareFiles = null;` | `    applyGlobalTestDefaults();` |
| `test/features/courses/presentation/pages/course_detail_export_units_test.dart` (line 87) | `import '../../../../helpers/global_test_defaults.dart';` | `    debugCanShareFiles = null;` | `    applyGlobalTestDefaults();` |
| `test/core/services/export/shared/share_file_fallback_test.dart` (line 58) | `import '../../../../helpers/global_test_defaults.dart';` | `    debugCanShareFiles = true;` | `    applyGlobalTestDefaults();` |

In `sensor_summary_scheduler_test.dart` only the assignment inside the `addTearDown` block at line 32 changes. The assignments at lines 22, 88 and 349 are the tests' own setup and stay.

The four `data_quality` files used to leave the scheduler on, which is the production default and not the harness default. The two `debugCanShareFiles = null` files used to leave the platform's own answer, which is "cannot share" on Linux, where CI runs.

- [ ] **Step 6: Run the nine files**

```bash
flutter test \
  test/features/data_quality/presentation/data_quality_inbox_page_test.dart \
  test/features/data_quality/presentation/quality_inbox_providers_test.dart \
  test/features/data_quality/repairs/profile_repair_service_test.dart \
  test/features/data_quality/repairs/quality_repair_executor_test.dart \
  test/features/data_quality/data/quality_scan_service_test.dart \
  test/features/equipment/data/services/sensor_summary_scheduler_test.dart \
  test/core/services/export/export_service_pdf_units_test.dart \
  test/features/courses/presentation/pages/course_detail_export_units_test.dart \
  test/core/services/export/shared/share_file_fallback_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 7: Let the guard fail, then remove the entries it names**

Run: `flutter test test/architecture/test_global_state_restored_test.dart`
Expected: FAIL in `every allowlisted file still needs its entry`, listing exactly these seven:

```text
test/features/data_quality/data/quality_scan_service_test.dart
test/features/data_quality/presentation/data_quality_inbox_page_test.dart
test/features/data_quality/presentation/quality_inbox_providers_test.dart
test/features/data_quality/repairs/profile_repair_service_test.dart
test/features/data_quality/repairs/quality_repair_executor_test.dart
test/features/equipment/data/services/sensor_summary_scheduler_test.dart
test/flutter_test_config.dart
```

Remove those seven entries from `allowed`. The other three files from Step 5 stay pending: they still offend under another rule, repaired in Tasks 5 and 6.

Run the guard again. Expected: `All tests passed!`

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add test/helpers/global_test_defaults.dart test/helpers/global_test_defaults_test.dart test/flutter_test_config.dart test/architecture/test_global_state_restored_test.dart \
  test/features/data_quality/presentation/data_quality_inbox_page_test.dart \
  test/features/data_quality/presentation/quality_inbox_providers_test.dart \
  test/features/data_quality/repairs/profile_repair_service_test.dart \
  test/features/data_quality/repairs/quality_repair_executor_test.dart \
  test/features/data_quality/data/quality_scan_service_test.dart \
  test/features/equipment/data/services/sensor_summary_scheduler_test.dart \
  test/core/services/export/export_service_pdf_units_test.dart \
  test/features/courses/presentation/pages/course_detail_export_units_test.dart \
  test/core/services/export/shared/share_file_fallback_test.dart
git commit -m "test: restore the harness defaults through one helper" -m "Refs #2500"
```

---

### Task 4: Share platform forwarder

**Files:**
- Create: `test/helpers/late_bound_share_platform.dart`
- Create: `test/helpers/late_bound_share_platform_test.dart`
- Modify: `test/flutter_test_config.dart`
- Modify: eight test files, listed in Step 6
- Modify: `test/architecture/test_global_state_restored_test.dart` (remove 2 entries)

**Interfaces:**
- Consumes: `applyGlobalTestDefaults` (Task 3); the generator's `--files` (Task 1).
- Produces: `class LateBoundSharePlatform extends SharePlatform` and `void pinLateBoundSharePlatform()`. This task must land before Task 5: once the path provider is restored, export tests run far enough to share, and without the forwarder they would pin the real platform.

- [ ] **Step 1: Reproduce the failure**

```bash
flutter test --exclude-tags performance $(python3 scripts/bundle_tests.py --files \
  test/features/media/presentation/media_selection_test.dart \
  test/features/media/presentation/media_share_helper_test.dart)
```

Expected: `+17 -7: Some tests failed.` The seven failures are in `media_share_helper_test.dart`, with `Expected: an object with length of <1>` and `Actual: []`. This takes over a minute, because each failing test polls for ten seconds.

- [ ] **Step 2: Write the failing test**

Create `test/helpers/late_bound_share_platform_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

import 'late_bound_share_platform.dart';

class _RecordingSharePlatform extends SharePlatform {
  final calls = <ShareParams>[];

  @override
  Future<ShareResult> share(ShareParams params) async {
    calls.add(params);
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharePlatform original;

  setUp(() => original = SharePlatform.instance);
  tearDown(() => SharePlatform.instance = original);

  test('the harness pins the forwarder before any test runs', () {
    expect(SharePlatform.instance, isA<LateBoundSharePlatform>());
  });

  test('a share reaches whichever fake is installed at the time', () async {
    final first = _RecordingSharePlatform();
    final second = _RecordingSharePlatform();

    SharePlatform.instance = first;
    await SharePlus.instance.share(ShareParams(text: 'one'));
    SharePlatform.instance = second;
    await SharePlus.instance.share(ShareParams(text: 'two'));

    expect(first.calls.map((c) => c.text), ['one']);
    expect(second.calls.map((c) => c.text), ['two']);
  });

  test('with no fake installed a share goes to the plugin channel', () async {
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    final methods = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return 'dev.fluttercommunity.plus/share/unavailable';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await SharePlus.instance.share(ShareParams(text: 'three'));

    expect(methods, ['share']);
  });

  test('pinning twice keeps the first forwarder', () {
    final pinned = SharePlatform.instance;

    pinLateBoundSharePlatform();

    expect(SharePlatform.instance, same(pinned));
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/helpers/late_bound_share_platform_test.dart`
Expected: FAIL to load, with an error that `late_bound_share_platform.dart` does not exist.

- [ ] **Step 4: Write the forwarder**

Create `test/helpers/late_bound_share_platform.dart`:

```dart
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/method_channel/method_channel_share.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

/// A share platform that looks up [SharePlatform.instance] on every share.
///
/// `SharePlus.instance` is a `static final` that keeps whichever platform it
/// reads first, for the life of the isolate. With many test files in one
/// isolate, the first file to share would pin its own fake and every later
/// fake would be ignored. Pinning this forwarder instead lets each file install
/// its fake the usual way, through `SharePlatform.instance`.
class LateBoundSharePlatform extends SharePlatform {
  final SharePlatform _channel = MethodChannelShare();

  @override
  Future<ShareResult> share(ShareParams params) {
    final current = SharePlatform.instance;
    // Nothing installed: behave as the plugin does out of the box, so tests
    // that mock the share channel keep working.
    return (identical(current, this) ? _channel : current).share(params);
  }
}

/// Make [SharePlus.instance] capture a [LateBoundSharePlatform].
///
/// Call once per isolate, before any test shares.
void pinLateBoundSharePlatform() {
  if (SharePlatform.instance is! LateBoundSharePlatform) {
    SharePlatform.instance = LateBoundSharePlatform();
  }
  // Reading the instance is what makes SharePlus capture the forwarder.
  SharePlus.instance;
}
```

- [ ] **Step 5: Pin it in the harness**

Replace the whole of `test/flutter_test_config.dart` with:

```dart
import 'dart:async';

import 'helpers/global_test_defaults.dart';
import 'helpers/late_bound_share_platform.dart';

/// Global test harness config, run once per entrypoint by `flutter test`.
///
/// An entrypoint is a test file, or in CI a generated bundle of test files
/// that share one isolate (issue #2500).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  applyGlobalTestDefaults();
  pinLateBoundSharePlatform();
  await testMain();
}
```

Run: `flutter test test/helpers/late_bound_share_platform_test.dart`
Expected: `All tests passed!`

Run the command from Step 1 again.
Expected: `+24: All tests passed!`, in a few seconds.

- [ ] **Step 6: Restore the share platform in the eight files**

Each file installs its fake in a `setUpAll` and never takes it out. With the forwarder the fake is looked up on every share, so it has to be removed when the file is done.

In each file, replace the single line in the "Replace" column, and any comment directly above it about `SharePlus.instance` being a `static final`, with the block below. Use the fake's existing variable name from the table, and keep the block at the indentation of the line it replaces.

```dart
  // The harness pins a forwarder that looks the platform up on every share
  // (test/helpers/late_bound_share_platform.dart), so the fake comes out
  // again when this file is done.
  late SharePlatform originalSharePlatform;

  setUpAll(() {
    originalSharePlatform = SharePlatform.instance;
    SharePlatform.instance = FAKE;
  });
  tearDownAll(() => SharePlatform.instance = originalSharePlatform);
```

| File | Line | Replace | `FAKE` |
|---|---|---|---|
| `test/core/services/export/shared/save_and_share_file_test.dart` | 42, comment at 39 to 41 | `  setUpAll(() => SharePlatform.instance = platform);` | `platform` |
| `test/core/services/export/shared/share_file_fallback_test.dart` | 44 | `  setUpAll(() => SharePlatform.instance = sharePlatform);` | `sharePlatform` |
| `test/features/gas_calculators/blender_invoice_test.dart` | 1524 | `    setUpAll(() => SharePlatform.instance = platform);` | `platform` |
| `test/features/media/presentation/media_selection_test.dart` | 503 | `    setUpAll(() => SharePlatform.instance = platform);` | `platform` |
| `test/features/media/presentation/media_share_helper_test.dart` | 69, comment at 60 to 64 | `  setUpAll(() => SharePlatform.instance = platform);` | `platform` |
| `test/features/planner/plan_canvas_share_anchor_test.dart` | 58, comment at 56 to 57 | `  setUpAll(() => SharePlatform.instance = sharePlatform);` | `sharePlatform` |
| `test/features/planner/saved_plans_sheet_test.dart` | 75, comment at 72 to 74 | `  setUpAll(() => SharePlatform.instance = sharePlatform);` | `sharePlatform` |
| `test/features/settings/presentation/providers/debug_log_providers_test.dart` | 853, comment at 850 to 851 | `    setUpAll(() => SharePlatform.instance = sharePlatform);` | `sharePlatform` |

In `media_share_helper_test.dart` the comment at lines 60 to 64 also explains why there is one fake that is reset between tests. Keep that part as one sentence: `// One fake for the whole file, reset between tests.`

- [ ] **Step 7: Run the eight files, then the pair**

```bash
flutter test \
  test/core/services/export/shared/save_and_share_file_test.dart \
  test/core/services/export/shared/share_file_fallback_test.dart \
  test/features/gas_calculators/blender_invoice_test.dart \
  test/features/media/presentation/media_selection_test.dart \
  test/features/media/presentation/media_share_helper_test.dart \
  test/features/planner/plan_canvas_share_anchor_test.dart \
  test/features/planner/saved_plans_sheet_test.dart \
  test/features/settings/presentation/providers/debug_log_providers_test.dart
```

Expected: `All tests passed!`

Run the command from Step 1 once more. Expected: `+24: All tests passed!`

- [ ] **Step 8: Let the guard fail, then remove the entries it names**

Run: `flutter test test/architecture/test_global_state_restored_test.dart`
Expected: FAIL in `every allowlisted file still needs its entry`, listing exactly:

```text
test/features/media/presentation/media_selection_test.dart
test/features/media/presentation/media_share_helper_test.dart
```

Remove those two entries. The other six files still replace the path provider without restoring it; Task 5 repairs them. Run the guard again. Expected: `All tests passed!`

- [ ] **Step 9: Format, analyze, commit**

```bash
dart format .
flutter analyze
rm -rf test/.bundles
git add test/helpers/late_bound_share_platform.dart test/helpers/late_bound_share_platform_test.dart test/flutter_test_config.dart test/architecture/test_global_state_restored_test.dart \
  test/core/services/export/shared/save_and_share_file_test.dart \
  test/core/services/export/shared/share_file_fallback_test.dart \
  test/features/gas_calculators/blender_invoice_test.dart \
  test/features/media/presentation/media_selection_test.dart \
  test/features/media/presentation/media_share_helper_test.dart \
  test/features/planner/plan_canvas_share_anchor_test.dart \
  test/features/planner/saved_plans_sheet_test.dart \
  test/features/settings/presentation/providers/debug_log_providers_test.dart
git commit -m "test: let each test file install its own share sheet fake" -m "Refs #2500"
```

---

### Task 5: Platform singletons

**Files:**
- Modify: nineteen test files, listed in Steps 2 to 5
- Modify: `test/architecture/test_global_state_restored_test.dart` (remove 19 entries)

**Interfaces:**
- Consumes: the forwarder (Task 4), the generator's `--files` (Task 1).
- Produces: nothing new. Every `*Platform.instance` a test replaces is restored.

- [ ] **Step 1: Reproduce the failure**

```bash
flutter test --exclude-tags performance $(python3 scripts/bundle_tests.py --files \
  test/core/services/local_cache_database_service_test.dart \
  test/core/services/media_store/store_marker_test.dart)
```

Expected: `+6 -5: Some tests failed.` The five failures are in `store_marker_test.dart`, with `UnimplementedError: getTemporaryPath() has not been implemented.`

- [ ] **Step 2: Restore the path provider where a `setUp` installs it**

The idiom, already used in `test/features/media/presentation/media_share_helper_test.dart`:

```dart
  late PathProviderPlatform originalPathProvider;

  setUp(() async {
    // ...
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    // The fake points into a temp dir this deletes, so it must not outlive it.
    PathProviderPlatform.instance = originalPathProvider;
    // ...
  });
```

For each file below make three edits, all at the indentation of the code around them:

1. **Declare.** Add `late PathProviderPlatform originalPathProvider;` on a new line directly below the line in the "Declare below" column.
2. **Capture.** Add `originalPathProvider = PathProviderPlatform.instance;` on a new line directly above the line in the "Capture above" column.
3. **Restore.** Add `PathProviderPlatform.instance = originalPathProvider;` inside the `tearDown`, placed as the "Restore" column says.

| File | Declare below | Capture above | Restore |
|---|---|---|---|
| `test/core/services/database_service_headless_upgrade_guard_test.dart` | `late String dbPath;` (38) | `PathProviderPlatform.instance = _FakePathProvider(tempDir.path);` (46) | First statement of the `finally` block, above `DatabaseService.instance.resetForTesting();` (54) |
| `test/core/services/database_service_isolate_test.dart` | `late String dbPath;` (104) | the same assignment (109) | First statement of the `finally` block (121) |
| `test/core/services/database_service_location_adoption_test.dart` | `late String customPath;` (40) | the same assignment (47) | First statement of the `finally` block (55) |
| `test/core/services/database_service_vacuum_test.dart` | `late String dbPath;` (43) | the same assignment (48) | First statement of the `finally` block (56) |
| `test/core/services/local_cache_database_service_test.dart` | `final service = LocalCacheDatabaseService.instance;` (29) | `PathProviderPlatform.instance = _FakePathProvider(support.path);` (33) | Below `service.resetForTesting();` (39) |
| `test/features/media_store/media_cache_eviction_provider_test.dart` | `late LocalCacheDatabase db;` (22) | the same assignment (26) | Below `resetMediaCacheRootForTesting();` (36) |
| `test/features/media_store/media_cache_root_test.dart` | `late _CountingPathProvider platform;` (29) | `PathProviderPlatform.instance = platform;` (34) | Below `resetMediaCacheRootForTesting();` (39) |
| `test/features/settings/presentation/pages/storage_settings_pick_failure_test.dart` | `late Directory tempDir;` (73) | `PathProviderPlatform.instance = _FakePathProvider(tempDir.path);` (80) | Below `DatabaseService.instance.resetForTesting();` (87) |
| `test/features/settings/presentation/pages/storage_settings_reset_test.dart` | `late Directory tempDir;` (61) | the same assignment (68) | Below `DatabaseService.instance.resetForTesting();` (78) |
| `test/features/settings/presentation/providers/storage_usage_wiring_test.dart` | `late LocalCacheDatabase db;` (30) | `PathProviderPlatform.instance = _FakePathProvider(support.path);` (34) | Below `resetMediaCacheRootForTesting();` (44) |
| `test/core/services/export/shared/share_file_fallback_test.dart` | `late FilePickerPlatform originalPicker;` (41) | `PathProviderPlatform.instance = _FakePathProvider(documents.path);` (49) | Below `FilePickerPlatform.instance = originalPicker;` (59) |
| `test/features/planner/plan_canvas_share_anchor_test.dart` | `late Directory documents;` (53) | the same assignment (63) | Below `DatabaseService.instance.resetForTesting();` (68) |
| `test/features/planner/saved_plans_sheet_test.dart` | `late Directory documents;` (69) | the same assignment (81) | Below `DatabaseService.instance.resetForTesting();` (86) |

- [ ] **Step 3: Restore the path provider where the `tearDown` is an arrow**

Two files have a one-line `tearDown`. Make the Declare and Capture edits as in Step 2, and replace the `tearDown` with a block.

`test/core/services/export/shared/save_and_share_file_test.dart`: declare below `late Directory documents;` (36), capture above `PathProviderPlatform.instance = _FakePathProvider(documents.path);` (46), and replace line 50

```dart
  tearDown(() => documents.deleteSync(recursive: true));
```

with

```dart
  tearDown(() {
    PathProviderPlatform.instance = originalPathProvider;
    documents.deleteSync(recursive: true);
  });
```

`test/features/gas_calculators/blender_invoice_test.dart`, inside `group('export', ...)`: declare below `late Directory documents;` (1521), capture above the assignment (1528), and replace line 1532

```dart
    tearDown(() => documents.deleteSync(recursive: true));
```

with

```dart
    tearDown(() {
      PathProviderPlatform.instance = originalPathProvider;
      documents.deleteSync(recursive: true);
    });
```

- [ ] **Step 4: Restore the path provider where a test body installs it**

`test/features/settings/presentation/providers/debug_log_providers_test.dart` assigns inside two tests, at lines 871 and 896. Directly above each of the two lines

```dart
      PathProviderPlatform.instance = _FakePathProvider(shareTemp.path);
```

add

```dart
      final originalPathProvider = PathProviderPlatform.instance;
      addTearDown(() => PathProviderPlatform.instance = originalPathProvider);
```

- [ ] **Step 5: Restore the other three platforms**

`test/core/services/cloud_storage/google_drive/google_sign_in_authenticator_test.dart`. Replace lines 93 to 100

```dart
  late _FakePlatform platform;
  late GoogleSignInAuthenticator auth;

  setUp(() {
    platform = _FakePlatform();
    GoogleSignInPlatform.instance = platform;
    auth = GoogleSignInAuthenticator();
  });
```

with

```dart
  late _FakePlatform platform;
  late GoogleSignInAuthenticator auth;
  late GoogleSignInPlatform originalPlatform;

  setUp(() {
    platform = _FakePlatform();
    originalPlatform = GoogleSignInPlatform.instance;
    GoogleSignInPlatform.instance = platform;
    auth = GoogleSignInAuthenticator();
  });

  tearDown(() => GoogleSignInPlatform.instance = originalPlatform);
```

The assignment inside the test at line 184 is covered by the same `tearDown`.

`test/core/services/export/excel/maintenance_excel_export_service_test.dart`, inside `group('delivery paths', ...)`. Replace lines 139 to 150

```dart
    late MockFilePickerPlatform picker;
    late Directory tmp;

    setUp(() {
      picker = MockFilePickerPlatform();
      FilePickerPlatform.instance = picker;
      tmp = Directory.systemTemp.createTempSync('maintenance_export');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
```

with

```dart
    late MockFilePickerPlatform picker;
    late FilePickerPlatform originalPicker;
    late Directory tmp;

    setUp(() {
      picker = MockFilePickerPlatform();
      originalPicker = FilePickerPlatform.instance;
      FilePickerPlatform.instance = picker;
      tmp = Directory.systemTemp.createTempSync('maintenance_export');
    });

    tearDown(() {
      FilePickerPlatform.instance = originalPicker;
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
```

`test/features/media/presentation/pages/media_viewer_video_test.dart`. Replace lines 179 to 180

```dart
    final platform = _FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
```

with

```dart
    final platform = _FakeVideoPlatform();
    final originalPlatform = VideoPlayerPlatform.instance;
    addTearDown(() => VideoPlayerPlatform.instance = originalPlatform);
    VideoPlayerPlatform.instance = platform;
```

- [ ] **Step 6: Run the nineteen files, then the pair**

```bash
flutter test \
  test/core/services/database_service_headless_upgrade_guard_test.dart \
  test/core/services/database_service_isolate_test.dart \
  test/core/services/database_service_location_adoption_test.dart \
  test/core/services/database_service_vacuum_test.dart \
  test/core/services/local_cache_database_service_test.dart \
  test/features/media_store/media_cache_eviction_provider_test.dart \
  test/features/media_store/media_cache_root_test.dart \
  test/features/settings/presentation/pages/storage_settings_pick_failure_test.dart \
  test/features/settings/presentation/pages/storage_settings_reset_test.dart \
  test/features/settings/presentation/providers/storage_usage_wiring_test.dart \
  test/core/services/export/shared/share_file_fallback_test.dart \
  test/features/planner/plan_canvas_share_anchor_test.dart \
  test/features/planner/saved_plans_sheet_test.dart \
  test/core/services/export/shared/save_and_share_file_test.dart \
  test/features/gas_calculators/blender_invoice_test.dart \
  test/features/settings/presentation/providers/debug_log_providers_test.dart \
  test/core/services/cloud_storage/google_drive/google_sign_in_authenticator_test.dart \
  test/core/services/export/excel/maintenance_excel_export_service_test.dart \
  test/features/media/presentation/pages/media_viewer_video_test.dart
```

Expected: `All tests passed!`

Run the command from Step 1 again. Expected: `+11: All tests passed!`

- [ ] **Step 7: Let the guard fail, then remove the entries it names**

Run: `flutter test test/architecture/test_global_state_restored_test.dart`
Expected: FAIL in `every allowlisted file still needs its entry`, listing exactly the nineteen files from Step 6. Remove those nineteen entries and run the guard again. Expected: `All tests passed!`

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze
rm -rf test/.bundles
git add test/architecture/test_global_state_restored_test.dart \
  test/core/services/database_service_headless_upgrade_guard_test.dart \
  test/core/services/database_service_isolate_test.dart \
  test/core/services/database_service_location_adoption_test.dart \
  test/core/services/database_service_vacuum_test.dart \
  test/core/services/local_cache_database_service_test.dart \
  test/features/media_store/media_cache_eviction_provider_test.dart \
  test/features/media_store/media_cache_root_test.dart \
  test/features/settings/presentation/pages/storage_settings_pick_failure_test.dart \
  test/features/settings/presentation/pages/storage_settings_reset_test.dart \
  test/features/settings/presentation/providers/storage_usage_wiring_test.dart \
  test/core/services/export/shared/share_file_fallback_test.dart \
  test/features/planner/plan_canvas_share_anchor_test.dart \
  test/features/planner/saved_plans_sheet_test.dart \
  test/core/services/export/shared/save_and_share_file_test.dart \
  test/features/gas_calculators/blender_invoice_test.dart \
  test/features/settings/presentation/providers/debug_log_providers_test.dart \
  test/core/services/cloud_storage/google_drive/google_sign_in_authenticator_test.dart \
  test/core/services/export/excel/maintenance_excel_export_service_test.dart \
  test/features/media/presentation/pages/media_viewer_video_test.dart
git commit -m "test: restore every platform singleton a test replaces" -m "Refs #2500"
```

---

### Task 6: Channel mocks

**Files:**
- Create: `test/helpers/mock_channels.dart`
- Modify: twenty-two test files, listed in Step 3
- Modify: `test/architecture/test_global_state_restored_test.dart` (remove 22 entries)

**Interfaces:**
- Consumes: the generator's `--files` (Task 1).
- Produces: `void clearPathAndShareChannelMocks()`.

The spec listed seven files for this repair. A scan found twenty-two that mock the path provider or share channel and never clear it, so the repair and the guard cover all of them.

- [ ] **Step 1: Reproduce the failure**

```bash
flutter test --exclude-tags performance $(python3 scripts/bundle_tests.py --files \
  test/features/settings/presentation/providers/export_uddf_profiles_test.dart \
  test/features/settings/presentation/providers/sync_providers_epoch_test.dart)
```

Expected: `+19 -3: Some tests failed.` The three failures are in `sync_providers_epoch_test.dart`, two of them with `MissingPlatformDirectoryException(Unable to get application support directory)`.

- [ ] **Step 2: Write the helper**

Create `test/helpers/mock_channels.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

/// Remove the mock handlers from the path provider and share channels.
///
/// Flutter keeps a mock handler until it is replaced, so one left behind
/// answers for every test file that runs later in the same isolate, usually
/// with a directory the file that installed it has already deleted.
void clearPathAndShareChannelMocks() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_pathProviderChannel, null);
  messenger.setMockMethodCallHandler(_shareChannel, null);
}
```

- [ ] **Step 3: Clear the mocks in the twenty-two files**

In each file, add the import to the block of relative imports, in alphabetical order. Then add

```dart
  tearDownAll(clearPathAndShareChannelMocks);
```

on a new line directly below the closing `});` of the `setUpAll` that starts at the line in the table, at that `setUpAll`'s indentation.

| File | `setUpAll` starts at | Import |
|---|---|---|
| `test/core/services/background_service_backup_test.dart` | 85 | `import '../../helpers/mock_channels.dart';` |
| `test/core/services/export_service_test.dart` | 13 | `import '../../helpers/mock_channels.dart';` |
| `test/core/services/sync/base_export_blob_paging_test.dart` | 24 | `import '../../../helpers/mock_channels.dart';` |
| `test/core/services/sync/base_export_fact_clock_watermark_test.dart` | 23 | `import '../../../helpers/mock_channels.dart';` |
| `test/core/services/export/export_service_dive_types_test.dart` | 22 | `import '../../../helpers/mock_channels.dart';` |
| `test/core/services/export/export_service_pdf_units_test.dart` | 46 | `import '../../../helpers/mock_channels.dart';` |
| `test/core/services/export/pdf/pdf_course_export_service_test.dart` | 40 | `import '../../../../helpers/mock_channels.dart';` |
| `test/core/services/export/pdf/pdf_trip_export_test.dart` | 38 | `import '../../../../helpers/mock_channels.dart';` |
| `test/integration/uddf_round_trip_test.dart` | 48 | `import '../helpers/mock_channels.dart';` |
| `test/features/settings/presentation/providers/export_pdf_logbook_test.dart` | 146 | `import '../../../../helpers/mock_channels.dart';` |
| `test/features/settings/presentation/providers/export_uddf_profiles_test.dart` | 48 | `import '../../../../helpers/mock_channels.dart';` |
| `test/features/backup/data/services/backup_encryption_backup_test.dart` | 67 | `import '../../../../helpers/mock_channels.dart';` |
| `test/features/backup/data/services/backup_service_database_copy_restore_test.dart` | 87 | `import '../../../../helpers/mock_channels.dart';` |
| `test/features/backup/data/services/backup_service_encryption_test.dart` | 66 | `import '../../../../helpers/mock_channels.dart';` |
| `test/features/backup/data/services/backup_service_newer_schema_test.dart` | 63 | `import '../../../../helpers/mock_channels.dart';` |
| `test/features/backup/data/services/backup_service_premigration_restore_test.dart` | 76 | `import '../../../../helpers/mock_channels.dart';` |
| `test/features/backup/data/services/backup_service_replace_test.dart` | 77 | `import '../../../../helpers/mock_channels.dart';` |
| `test/features/backup/data/services/backup_service_saf_io_test.dart` | 111 | `import '../../../../helpers/mock_channels.dart';` |
| `test/features/backup/data/services/backup_service_saf_refs_test.dart` | 80 | `import '../../../../helpers/mock_channels.dart';` |
| `test/features/backup/data/services/backup_service_test.dart` | 279 (inside a group, four spaces) | `import '../../../../helpers/mock_channels.dart';` |
| `test/features/backup/data/services/backup_target_lease_test.dart` | 44 | `import '../../../../helpers/mock_channels.dart';` |

The twenty-second file installs its handlers in `setUp`, not `setUpAll`. In `test/features/courses/presentation/pages/course_detail_export_units_test.dart`, add the import `import '../../../../helpers/mock_channels.dart';` and add `clearPathAndShareChannelMocks();` as the first statement of the `tearDown` at line 86.

Several of these files already have a `tearDownAll` that deletes a temp directory. Leave it as it is. A group may register any number of `tearDownAll` callbacks.

- [ ] **Step 4: Run the twenty-two files, then the pair**

```bash
flutter test \
  test/core/services/background_service_backup_test.dart \
  test/core/services/export_service_test.dart \
  test/core/services/sync/base_export_blob_paging_test.dart \
  test/core/services/sync/base_export_fact_clock_watermark_test.dart \
  test/core/services/export/export_service_dive_types_test.dart \
  test/core/services/export/export_service_pdf_units_test.dart \
  test/core/services/export/pdf/pdf_course_export_service_test.dart \
  test/core/services/export/pdf/pdf_trip_export_test.dart \
  test/integration/uddf_round_trip_test.dart \
  test/features/settings/presentation/providers/export_pdf_logbook_test.dart \
  test/features/settings/presentation/providers/export_uddf_profiles_test.dart \
  test/features/backup/data/services/backup_encryption_backup_test.dart \
  test/features/backup/data/services/backup_service_database_copy_restore_test.dart \
  test/features/backup/data/services/backup_service_encryption_test.dart \
  test/features/backup/data/services/backup_service_newer_schema_test.dart \
  test/features/backup/data/services/backup_service_premigration_restore_test.dart \
  test/features/backup/data/services/backup_service_replace_test.dart \
  test/features/backup/data/services/backup_service_saf_io_test.dart \
  test/features/backup/data/services/backup_service_saf_refs_test.dart \
  test/features/backup/data/services/backup_service_test.dart \
  test/features/backup/data/services/backup_target_lease_test.dart \
  test/features/courses/presentation/pages/course_detail_export_units_test.dart
```

Expected: `All tests passed!`

Run the command from Step 1 again. Expected: `+22: All tests passed!`

- [ ] **Step 5: Let the guard fail, then remove the entries it names**

Run: `flutter test test/architecture/test_global_state_restored_test.dart`
Expected: FAIL in `every allowlisted file still needs its entry`, listing exactly the twenty-two files from Step 4. Remove those entries. The `allowed` map is now empty; keep it, with its comment changed to:

```dart
  /// Files that replace a global on purpose, each with the reason.
  const allowed = <String, String>{};
```

Run the guard again. Expected: `All tests passed!`

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
rm -rf test/.bundles
git add test/helpers/mock_channels.dart test/architecture/test_global_state_restored_test.dart \
  test/core/services/background_service_backup_test.dart \
  test/core/services/export_service_test.dart \
  test/core/services/sync/base_export_blob_paging_test.dart \
  test/core/services/sync/base_export_fact_clock_watermark_test.dart \
  test/core/services/export/export_service_dive_types_test.dart \
  test/core/services/export/export_service_pdf_units_test.dart \
  test/core/services/export/pdf/pdf_course_export_service_test.dart \
  test/core/services/export/pdf/pdf_trip_export_test.dart \
  test/integration/uddf_round_trip_test.dart \
  test/features/settings/presentation/providers/export_pdf_logbook_test.dart \
  test/features/settings/presentation/providers/export_uddf_profiles_test.dart \
  test/features/backup/data/services/backup_encryption_backup_test.dart \
  test/features/backup/data/services/backup_service_database_copy_restore_test.dart \
  test/features/backup/data/services/backup_service_encryption_test.dart \
  test/features/backup/data/services/backup_service_newer_schema_test.dart \
  test/features/backup/data/services/backup_service_premigration_restore_test.dart \
  test/features/backup/data/services/backup_service_replace_test.dart \
  test/features/backup/data/services/backup_service_saf_io_test.dart \
  test/features/backup/data/services/backup_service_saf_refs_test.dart \
  test/features/backup/data/services/backup_service_test.dart \
  test/features/backup/data/services/backup_target_lease_test.dart \
  test/features/courses/presentation/pages/course_detail_export_units_test.dart
git commit -m "test: clear path provider and share channel mocks when a file is done" -m "Refs #2500"
```

---

### Task 7: Declaration-time client and the shortcut latch

**Files:**
- Modify: `test/features/maps/offline_map_providers_test.dart:181`
- Modify: `lib/core/accessibility/app_shortcuts.dart:33`
- Modify: `test/accessibility/keyboard_shortcuts_test.dart:175-182` and the end of that group
- Modify: `test/accessibility/shortcut_display_test.dart:8-11`
- Modify: `test/core/accessibility/app_shortcuts_help_key_test.dart:153-156`

**Interfaces:**
- Consumes: the generator's `--files` (Task 1).
- Produces: `static void AppShortcuts.debugReset()`, marked `@visibleForTesting`.

- [ ] **Step 1: Reproduce both failures**

```bash
flutter test --exclude-tags performance $(python3 scripts/bundle_tests.py --files \
  test/features/maps/map_attribution_test.dart \
  test/features/maps/offline_map_providers_test.dart)
```

Expected: `+0 -1: Some tests failed.`, with `Failed to load` and `Bad state: There is no current invoker.`

```bash
flutter test --exclude-tags performance $(python3 scripts/bundle_tests.py --files \
  test/accessibility/keyboard_shortcuts_test.dart \
  test/accessibility/shortcut_display_test.dart)
```

Expected: `+15 -1: Some tests failed.`, with `Expected: non-empty`.

- [ ] **Step 2: Build the tile layer on first use**

In `test/features/maps/offline_map_providers_test.dart`, replace lines 181 to 183

```dart
  final tileLayer = TileLayer(
    urlTemplate: 'https://tile.example/{z}/{x}/{y}.png',
  );
```

with

```dart
  // Lazy: TileLayer creates an HTTP client, and the body of main() runs while
  // the file is declared. By then another file in the isolate may have set up
  // the test binding, whose HTTP layer only works inside a test.
  late final tileLayer = TileLayer(
    urlTemplate: 'https://tile.example/{z}/{x}/{y}.png',
  );
```

Run the first command from Step 1. Expected: `All tests passed!`

- [ ] **Step 3: Write the failing test for the reset seam**

In `test/accessibility/keyboard_shortcuts_test.dart`, add this as the last test of `group('AppShortcuts', ...)`, below `navigation shortcuts use expected categories`:

```dart

    test('debugReset lets a cleared catalog be filled again', () {
      ShortcutCatalog.instance.clear();
      AppShortcuts.ensureRegistered();
      expect(ShortcutCatalog.instance.entries, isEmpty);

      AppShortcuts.debugReset();
      AppShortcuts.ensureRegistered();

      expect(ShortcutCatalog.instance.entries, isNotEmpty);
    });
```

Run: `flutter test test/accessibility/keyboard_shortcuts_test.dart`
Expected: FAIL to compile: `The method 'debugReset' isn't defined for the type 'AppShortcuts'`.

- [ ] **Step 4: Add the seam**

In `lib/core/accessibility/app_shortcuts.dart`, directly below `static bool _registered = false;` (line 33), add:

```dart

  /// Forget that the shortcuts were registered, so the next
  /// [ensureRegistered] fills the catalog again.
  ///
  /// [ShortcutCatalog.clear] empties the catalog but cannot reach this flag,
  /// so a test that clears the catalog resets the flag with it.
  @visibleForTesting
  static void debugReset() => _registered = false;
```

`package:flutter/foundation.dart` is already imported.

Run: `flutter test test/accessibility/keyboard_shortcuts_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Start the three files from a known catalog**

`test/accessibility/keyboard_shortcuts_test.dart`. Replace lines 176 to 182

```dart
    // Clear stale entries from earlier groups and register once.
    // AppShortcuts._registered is a static flag, so ensureRegistered()
    // only populates the catalog on its first call.
    setUpAll(() {
      ShortcutCatalog.instance.clear();
      AppShortcuts.ensureRegistered();
    });
```

with

```dart
    // Earlier groups, or another file in the isolate, may have cleared the
    // catalog after the shortcuts were registered. Start from a known state.
    setUpAll(() {
      ShortcutCatalog.instance.clear();
      AppShortcuts.debugReset();
      AppShortcuts.ensureRegistered();
    });
```

`test/accessibility/shortcut_display_test.dart`. Replace lines 8 to 11

```dart
  setUp(() {
    ShortcutCatalog.instance.clear();
    AppShortcuts.ensureRegistered();
  });
```

with

```dart
  setUp(() {
    ShortcutCatalog.instance.clear();
    AppShortcuts.debugReset();
    AppShortcuts.ensureRegistered();
  });
```

`test/core/accessibility/app_shortcuts_help_key_test.dart`. Replace lines 154 to 156

```dart
    // No clear() first: the widget tests above already registered through
    // globalBindings, and AppShortcuts' static flag would stop a re-register.
    setUpAll(AppShortcuts.ensureRegistered);
```

with

```dart
    // Another file in the isolate may have cleared the catalog after the
    // shortcuts were registered. Start from a known state.
    setUpAll(() {
      ShortcutCatalog.instance.clear();
      AppShortcuts.debugReset();
      AppShortcuts.ensureRegistered();
    });
```

- [ ] **Step 6: Run the files, then the pair**

```bash
flutter test \
  test/accessibility/keyboard_shortcuts_test.dart \
  test/accessibility/shortcut_display_test.dart \
  test/core/accessibility/app_shortcuts_help_key_test.dart \
  test/features/maps/offline_map_providers_test.dart
```

Expected: `All tests passed!`

Run the second command from Step 1. Expected: `All tests passed!`

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
rm -rf test/.bundles
git add lib/core/accessibility/app_shortcuts.dart \
  test/accessibility/keyboard_shortcuts_test.dart \
  test/accessibility/shortcut_display_test.dart \
  test/core/accessibility/app_shortcuts_help_key_test.dart \
  test/features/maps/offline_map_providers_test.dart
git commit -m "test: stop two tests depending on being first in the isolate" -m "Refs #2500"
```

---

### Task 8: PDF fonts without the network

**Files:**
- Create: `test/helpers/pdf_roboto.dart`
- Create: `test/helpers/pdf_roboto_test.dart`
- Modify: `test/core/services/export/pdf/pdf_export_generated_at_test.dart:26-29`
- Modify: `test/core/services/export/pdf/pdf_export_template_routing_test.dart:34-36`

**Interfaces:**
- Consumes: the generator's `--files` (Task 1).
- Produces: `Future<void> loadPdfRoboto()` and `Future<void> unloadPdfRoboto()`.

- [ ] **Step 1: Reproduce the failure**

```bash
flutter test --exclude-tags performance $(python3 scripts/bundle_tests.py --files \
  test/core/services/accounts/account_deduplicator_test.dart \
  test/core/services/export/pdf/pdf_export_template_routing_test.dart)
```

Expected: `+15 -1: Some tests failed.`, in `embeds a Unicode font so accented site names survive`, with `Error loading Roboto-Regular, fallback to Helvetica.` in the output.

- [ ] **Step 2: Write the failing test**

Create `test/helpers/pdf_roboto_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';

import 'pdf_roboto.dart';

const _styles = ['Regular', 'Bold', 'Italic', 'BoldItalic'];

void main() {
  // The test binding answers every HTTP request with 400, so a font that
  // loads here did not come from the network.
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(unloadPdfRoboto);

  test('loads all four Roboto styles with the network blocked', () async {
    await loadPdfRoboto();

    expect(PdfFonts.instance.isInitialized, isTrue);
    expect(PdfFonts.instance.regular, isA<pw.TtfFont>());
    expect(PdfFonts.instance.bold, isA<pw.TtfFont>());
    expect(PdfFonts.instance.italic, isA<pw.TtfFont>());
    expect(PdfFonts.instance.boldItalic, isA<pw.TtfFont>());
  });

  test('unloading leaves nothing behind for the next file', () async {
    await loadPdfRoboto();

    await unloadPdfRoboto();

    expect(PdfFonts.instance.isInitialized, isFalse);
    for (final style in _styles) {
      expect(
        await PdfBaseCache.defaultCache.contains('Roboto-$style'),
        isFalse,
        reason: style,
      );
    }
  });

  test(
    'without the helper the blocked download falls back to Helvetica',
    () async {
      await PdfFonts.instance.initialize();

      expect(PdfFonts.instance.regular, isNot(isA<pw.TtfFont>()));
    },
  );
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/helpers/pdf_roboto_test.dart`
Expected: FAIL to load, with an error that `pdf_roboto.dart` does not exist.

- [ ] **Step 4: Write the helper**

Create `test/helpers/pdf_roboto.dart`:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';

const _styles = ['Regular', 'Bold', 'Italic', 'BoldItalic'];

/// Where the Flutter SDK keeps its own copy of Roboto.
String _materialFontsDir() {
  final root = Platform.environment['FLUTTER_ROOT'];
  final artifacts = root != null
      ? p.join(root, 'bin', 'cache', 'artifacts')
      // flutter_tester lives in bin/cache/artifacts/engine/<platform>/.
      : p.dirname(p.dirname(p.dirname(Platform.resolvedExecutable)));
  return p.join(artifacts, 'material_fonts');
}

/// Load Roboto into [PdfFonts] from the Flutter SDK, with no network.
///
/// [PdfFonts] downloads Roboto on first use. The test binding answers every
/// HTTP request with 400, the printing package then falls back to Helvetica
/// without throwing, and [PdfFonts] caches that. Seeding the printing cache
/// first means the download is never attempted.
Future<void> loadPdfRoboto() async {
  for (final style in _styles) {
    final file = File(p.join(_materialFontsDir(), 'Roboto-$style.ttf'));
    await PdfBaseCache.defaultCache.add(
      'Roboto-$style',
      await file.readAsBytes(),
    );
  }
  PdfFonts.instance.reset();
  await PdfFonts.instance.initialize();
}

/// Undo [loadPdfRoboto], so later files get Helvetica as they expect.
Future<void> unloadPdfRoboto() async {
  for (final style in _styles) {
    await PdfBaseCache.defaultCache.remove('Roboto-$style');
  }
  PdfFonts.instance.reset();
}
```

Run: `flutter test test/helpers/pdf_roboto_test.dart`
Expected: `All tests passed!` The output holds four `Error loading Roboto-... fallback to Helvetica.` lines. They come from the third test, which proves the fallback happens without the helper.

- [ ] **Step 5: Use it in the two files**

`test/core/services/export/pdf/pdf_export_generated_at_test.dart`. Add `import '../../../../helpers/pdf_roboto.dart';` directly above the `pdf_text.dart` import, and replace lines 28 to 29

```dart
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);
```

with

```dart
  setUpAll(loadPdfRoboto);
  tearDownAll(unloadPdfRoboto);

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);
```

`test/core/services/export/pdf/pdf_export_template_routing_test.dart`. Add the same import in the same place, and add directly above `setUp(() async {` (line 36):

```dart
  setUpAll(loadPdfRoboto);
  tearDownAll(unloadPdfRoboto);

```

- [ ] **Step 6: Run the files, then the pair with a Helvetica reader after it**

```bash
flutter test \
  test/core/services/export/pdf/pdf_export_generated_at_test.dart \
  test/core/services/export/pdf/pdf_export_template_routing_test.dart
```

Expected: `All tests passed!`

```bash
flutter test --exclude-tags performance $(python3 scripts/bundle_tests.py --files \
  test/core/services/accounts/account_deduplicator_test.dart \
  test/core/services/export/pdf/pdf_export_template_routing_test.dart \
  test/core/services/pdf_templates/pdf_generated_at_test.dart)
```

Expected: `All tests passed!` The third file reads text set in Helvetica, so this also proves the unload.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
rm -rf test/.bundles
git add test/helpers/pdf_roboto.dart test/helpers/pdf_roboto_test.dart \
  test/core/services/export/pdf/pdf_export_generated_at_test.dart \
  test/core/services/export/pdf/pdf_export_template_routing_test.dart
git commit -m "test: load PDF fonts from the SDK so the tests need no network" -m "Refs #2500"
```

---

### Task 9: The whole suite, bundled

**Files:**
- Modify: whatever test files this run shows still leak. None are expected.

**Interfaces:**
- Consumes: everything from Tasks 1 to 8.
- Produces: a suite that passes both as files and as bundles.

Each half takes about five minutes. Run them one after the other.

- [ ] **Step 1: Check whether the timing race in `buddy_merge_test` is fixed on main**

```bash
git fetch origin main
git log origin/main --oneline -3 -- test/features/buddies/data/repositories/buddy_merge_test.dart
git merge origin/main
```

Read the test `merge re-points certifications.instructorId to the survivor`. If it still compares two timestamps taken a moment apart with `greaterThan(preMergeRow.updatedAt)` and nothing sets the first one into the past, the fix has not landed. In that case add this as the first line of `test/features/buddies/data/repositories/buddy_merge_test.dart`:

```dart
// test-bundle: run-alone updatedAt race in a warm isolate, fixed separately
```

and remove the line again in whichever later task first finds the fix on main.

If the merge brought in changes to `lib/core/database/`, regenerate: `dart run build_runner build --delete-conflicting-outputs`.

Then run `flutter analyze` and `flutter test test/architecture/test_global_state_restored_test.dart`. A test added on main since this work began may replace a global without restoring it. Repair each file the guard names with the idiom for its rule (Task 3, 5 or 6), and commit that on its own.

- [ ] **Step 2: Run the first half**

```bash
flutter test --exclude-tags performance -j 8 $(python3 scripts/bundle_tests.py --shard 0 --total-shards 2)
```

Expected: `All tests passed!`

- [ ] **Step 3: Run the second half**

```bash
flutter test --exclude-tags performance -j 8 $(python3 scripts/bundle_tests.py --shard 1 --total-shards 2)
```

Expected: `All tests passed!`

- [ ] **Step 4: For every failure, find the cause and fix it**

A failing test's name starts with the path of its file. For each one:

1. Run the file on its own: `flutter test test/<path>`. If it fails alone too, bundling is not the cause. Check whether main is red for the same test, and stop and report.
2. If it passes alone, find the file it depends on. Open the bundle (the path is in the failure's `loading` line, or use `python3 scripts/bundle_tests.py --containing test/<path>`), take the files imported before the failing one, and run `--files <first half of them> test/<path>`. Halve again on whichever half still fails, until one file is left.
3. Fix that file, by the kind of state it leaves:

| It leaves | Fix | Guard |
|---|---|---|
| A `*Platform.instance`, a harness default, a path provider or share channel mock | The idiom from Task 3, 5 or 6 | It should have been caught. Add a scanner test for the shape that slipped through, then fix the scanner |
| A mock on any other channel | Clear it in `tearDownAll` with `setMockMethodCallHandler(channel, null)` | Add the channel to `mockedChannels` in the scanner, with a scanner test |
| A static flag or cache in `lib/` | A `@visibleForTesting` reset, called from the test's `setUp`, as in Task 7 | None. Note it in the PR |
| Code that runs while the file is declared | Move it into `setUp` or the test, or make it `late final`, as in Task 7 | None |
| An assertion that depends on time passing | Build the difference in, for example by seeding the earlier timestamp into the past. Never weaken the assertion | None |

4. Re-run the bundle that failed, then the file on its own.

Commit each fix on its own, as `test: <what the file now restores>` with body `Refs #2500`.

- [ ] **Step 5: Run the architecture tests and clean up**

```bash
flutter test test/architecture
rm -rf test/.bundles
git status --short
```

Expected: `All tests passed!`, and no untracked files.

---

### Task 10: Switch CI to bundles

**Files:**
- Modify: `.github/workflows/ci.yaml:346-372` (the `Run tests` step of the `test` job)
- Modify: `docs/developer/testing.md` (new section above `## Best Practices`)
- Modify: the development guide at the repository root (Gotchas section)

**Interfaces:**
- Consumes: the generator (Task 1) and a suite that passes bundled (Task 9).
- Produces: a PR whose CI runs bundles on 16 shards, and the timings Task 11 needs.

- [ ] **Step 1: Replace the `Run tests` step**

In `.github/workflows/ci.yaml`, replace the whole step, from `- name: Run tests` through `flutter test --coverage --exclude-tags performance "${files[@]}"`, with:

```yaml
      - name: Run tests
        # `flutter test` compiles and loads every test file as its own
        # entrypoint, and --coverage collects a hit map per entrypoint, so the
        # cost of a run follows the number of entrypoints, not the number of
        # tests. scripts/bundle_tests.py groups the test files by directory
        # into bundles that share one isolate, and spreads the bundles over
        # the shards by weight. The few files that need their own entrypoint
        # (a library-level @Tags or @TestOn, a golden file) are passed as they
        # are. Codecov merges the partial coverage reports via the per-shard
        # flag below. See issue #2500 and docs/developer/testing.md.
        run: |
          # Written to a file first: a generator failure inside a process
          # substitution would be lost, leave the list empty, and let the
          # guard below pass the shard without running anything.
          python3 scripts/bundle_tests.py \
            --shard "${{ matrix.shard }}" --total-shards "${TOTAL_SHARDS}" \
            > bundle-paths.txt
          mapfile -t paths < bundle-paths.txt
          echo "Shard ${{ matrix.shard }}/${TOTAL_SHARDS}: ${#paths[@]} entrypoints"
          # Guard: with no paths, `flutter test` runs the ENTIRE suite. An empty
          # shard (more shards than bundles) would silently re-run everything and
          # defeat sharding, so skip it and emit an empty lcov so the Codecov
          # step still has a file to upload.
          if [ "${#paths[@]}" -eq 0 ]; then
            echo "No entrypoints assigned to this shard; skipping."
            mkdir -p coverage && : > coverage/lcov.info
            exit 0
          fi
          printf '  %s\n' "${paths[@]}"
          flutter test --coverage --exclude-tags performance "${paths[@]}"
```

The shard matrix, `TOTAL_SHARDS: 16` and `codecov.yml` do not change in this task.

- [ ] **Step 2: Document the rule**

In `docs/developer/testing.md`, insert this section directly above `## Best Practices`:

````markdown
## Shared Isolates in CI

`flutter test` compiles and loads every test file as its own entrypoint. In CI
that made the cost of a run follow the number of test files, so the test job
runs bundles instead: generated entrypoints that import many test files and
call each one's `main()` inside a group named after the file
(`scripts/bundle_tests.py`, issue #2500). Local runs and the pre-push hook still
run test files one by one. At local concurrency a bundle is no faster, because
it runs its files one after another in a single isolate.

### The rule: put back what you replace

The files in a bundle share process-wide state. A test that replaces a global
restores it, so the next file starts from the same place.

| You change | Put it back with |
|---|---|
| A `*Platform.instance`, or `HttpOverrides.global` | Read the previous value into a variable, and assign it back in `tearDown` or `addTearDown` |
| `QualityScanScheduler.enabled`, `SensorSummaryScheduler.enabled` or `debugCanShareFiles` | `applyGlobalTestDefaults()` from `test/helpers/global_test_defaults.dart`, in `tearDown` |
| A mock handler on the path provider or share channel | `clearPathAndShareChannelMocks()` from `test/helpers/mock_channels.dart`, in `tearDownAll` |
| The share sheet | Assign your fake to `SharePlatform.instance` and restore it. The harness pins a forwarder, so the fake is looked up on every share |
| PDF fonts | `loadPdfRoboto()` in `setUpAll` and `unloadPdfRoboto()` in `tearDownAll`, from `test/helpers/pdf_roboto.dart` |

`test/architecture/test_global_state_restored_test.dart` fails on an assignment
that nothing in the same file restores.

A shared isolate exposes two more things:

- Code in the body of `main()` or `group()` runs while the file is declared,
  before any test. By then an earlier file has set up the test binding. Build
  anything that touches the network or a platform channel inside `setUp` or the
  test, or make it `late final`.
- A warm isolate is faster than a cold one. An assertion that two timestamps
  differ needs the difference built in, not left to the clock.

### Reproducing a CI failure locally

```bash
# The bundle that runs a given test file:
flutter test $(python3 scripts/bundle_tests.py --containing test/path/to/my_test.dart)

# A whole CI shard. The shard count is TOTAL_SHARDS in .github/workflows/ci.yaml:
flutter test --exclude-tags performance $(python3 scripts/bundle_tests.py --shard 2 --total-shards 6)

# Exactly these files, in this order, in one isolate:
flutter test $(python3 scripts/bundle_tests.py --files test/a_test.dart test/b_test.dart)
```

A failure names the file it came from: every test in a bundle sits in a group
named after its file's path. To find the earlier file a failing test depends
on, take the files imported before it in the bundle and halve the list with
`--files` until one is left.

### Files that run as their own entrypoint

A file is left out of the bundles when it has a library-level `@Tags`,
`@TestOn`, `@Timeout`, `@Skip`, `@Retry` or `@OnPlatform` annotation (the test
runner reads those from an entrypoint only), calls `matchesGoldenFile`, or has
a `main` that is `async` or takes parameters.

The comment `// test-bundle: run-alone <reason>`, on a line of its own, does the
same for any file. It is there to unblock main while a conflict is fixed, not
to leave one in place.

````

In the development guide at the repository root, add to the end of the Gotchas list, below the entry about platform-agnostic paths:

```markdown
- A test that replaces process-wide state puts it back. CI runs many test files
  in one isolate (issue #2500), so a platform singleton, a harness default or a
  channel mock left behind breaks a different file from the one that set it.
  `test/architecture/test_global_state_restored_test.dart` fails on the
  assignment, and `docs/developer/testing.md` lists the helper for each case.
```

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yaml docs/developer/testing.md CLAUDE.md
git commit -m "ci: run test files in bundles that share an isolate" -m "Refs #2500"
```

- [ ] **Step 4: Push**

The pre-push hook would pick most of the suite as affected, because the harness config and helpers changed, and Task 9 has just run all of it. Skip the hook's test step and keep its format and analyze checks:

```bash
SKIP_TESTS=1 git push -u origin ericgriffin/test-suite-pruning-f84119
git ls-remote origin ericgriffin/test-suite-pruning-f84119
```

Expected: the remote ref matches `git rev-parse HEAD`.

- [ ] **Step 5: Open the PR**

First check that no other open PR already covers the issue:

```bash
gh pr list --state open --search "2500 in:body" --json number,title
```

Expected: an empty list.

Write the description to a file, following `.github/PULL_REQUEST_TEMPLATE.md`. This PR touches no UI path, so the Screenshots section is deleted.

```markdown
## Related Issue

Closes #2500

## Summary

CI test time followed the number of test files, not the number of tests: about
4.8 seconds per file, 81% of a run's job-minutes. The test job now runs bundles,
generated entrypoints that import many test files and share one isolate.

A shared isolate exposes tests that leave process-wide state behind, so this
also repairs every one of them and adds a guard that keeps new ones out.

## Changes

- `scripts/bundle_tests.py` groups test files by directory into bundles and
  spreads them over the shards by weight. Files with a library-level annotation
  or a golden comparison keep their own entrypoint.
- 49 test files now restore what they replace: platform singletons, the three
  harness defaults, and mocks on the path provider and share channels.
- A maps test builds its tile layer on first use instead of while the file is
  declared.
- The harness pins a share platform that looks up the current fake on every
  share, because `SharePlus.instance` keeps the first platform it sees.
- Two PDF tests load Roboto from the Flutter SDK. They used to download it from
  the public internet.
- `AppShortcuts.debugReset` lets a test that clears the shortcut catalog fill
  it again. This is the only change under `lib/`.
- `test/architecture/test_global_state_restored_test.dart` fails on an
  assignment to process-wide state that nothing in the same file restores.
- Local runs and the pre-push hook are unchanged. At local concurrency a bundle
  is no faster.

## Test Plan

- [x] `flutter test` passes, as separate files and as bundles
- [x] `flutter analyze` passes
- [x] `python3 scripts/bundle_tests_test.py` passes
- [ ] Codecov project coverage unchanged against main
- [ ] Test job-minutes per run, before and after, recorded in a comment
```

```bash
gh pr create --base main --head ericgriffin/test-suite-pruning-f84119 \
  --title "ci: run test files in shared isolates and repair the tests that leak state" \
  --body-file <path to the description file>
```

- [ ] **Step 6: Read the run**

When CI finishes, every test shard must be green. For a red shard, read its log, find the failing test's file from the group name, and go back to Task 9 Step 4.

Then collect the timings. Replace `<run id>` with the id of the PR's CI run:

```bash
gh run view <run id> --json jobs > ci-jobs.json
python3 - <<'EOF'
import datetime
import json

def minutes(start, end):
    fmt = "%Y-%m-%dT%H:%M:%SZ"
    span = datetime.datetime.strptime(end, fmt) - datetime.datetime.strptime(start, fmt)
    return span.total_seconds() / 60

jobs = json.load(open("ci-jobs.json"))["jobs"]
tests, setups, builds = [], [], []
for job in jobs:
    if job["conclusion"] != "success":
        continue
    whole = minutes(job["startedAt"], job["completedAt"])
    if job["name"].startswith("Test (shard"):
        step = next(s for s in job["steps"] if s["name"] == "Run tests")
        run = minutes(step["startedAt"], step["completedAt"])
        tests.append(run)
        setups.append(whole - run)
    elif job["name"].startswith("Build "):
        builds.append((whole, job["name"]))
total = sum(tests)
setup = sum(setups) / len(setups)
slowest_build, name = max(builds)
print("shards %d, Run tests total %.1f min, slowest %.1f min" % (len(tests), total, max(tests)))
print("setup per shard %.1f min" % setup)
print("slowest build %.1f min (%s)" % (slowest_build, name))
for count in range(2, 17):
    estimate = 1.25 * total / count + setup
    if estimate <= slowest_build:
        print("fewest shards: %d (estimated slowest shard %.1f min)" % (count, estimate))
        break
EOF
rm ci-jobs.json
```

The factor 1.25 allows for imbalance between shards and for the suite growing. Record the printed numbers; Task 11 uses them.

---

### Task 11: Cut the shard count

**Files:**
- Modify: `.github/workflows/ci.yaml:286-306` (the `test` job's matrix and its comment)
- Modify: `codecov.yml:5-26`

**Interfaces:**
- Consumes: from Task 10 Step 6, the fewest shards `N`, the estimated slowest shard, and the slowest build.
- Produces: the finished PR.

- [ ] **Step 1: Change the matrix**

In `.github/workflows/ci.yaml`, replace the comment block above the matrix, the `shard:` list and `TOTAL_SHARDS` (from `# 0-based shard indices` through `TOTAL_SHARDS: 16`) with the following, writing `N` indices in the list, `N` in `TOTAL_SHARDS`, and the measured numbers and today's date in the last sentence of the comment:

```yaml
        # 0-based shard indices; keep TOTAL_SHARDS below in sync with the count.
        # NOTE: the shard count is coupled to codecov.yml `after_n_builds`, which
        # must equal (shard count + 1) for the scripts job. Codecov holds the
        # patch/project status until every partial lcov arrives (see codecov.yml).
        #
        # Test files run in bundles that share an isolate
        # (scripts/bundle_tests.py, issue #2500), so a shard's time follows the
        # number of tests it runs, not the number of test files. The count is
        # the fewest shards that keep the slowest shard under the slowest
        # platform build, which sets the critical path. Fewer would lengthen
        # CI. More would only take jobs from the account-wide cap (60 on
        # GitHub Team) that the builds, analyze and script jobs share.
        # Measured <date>: slowest shard <minutes> min at <N> shards, slowest
        # build <minutes> min.
        shard: [0, 1, ...]
    env:
      TOTAL_SHARDS: <N>
```

- [ ] **Step 2: Change Codecov in the same commit**

In `codecov.yml`, with `M` standing for `N + 1`:

- Line 6: `# Coverage arrives as 17 separate uploads: the 16 file-sharded test jobs` becomes `# Coverage arrives as M separate uploads: the N test shards`.
- Line 7: `(flags shard-0..15)` becomes `(flags shard-0..` followed by `N - 1` and `)`.
- Lines 7 to 9: the sentence `Tests are sharded BY FILE (ci.yaml), so each shard's lcov only marks the lines its subset executed and Codecov must union them.` becomes `Each shard runs a disjoint set of test bundles (ci.yaml), so its lcov only marks the lines its subset executed and Codecov must union them.`
- Line 13: `until all 17 uploads arrive` becomes `until all M uploads arrive`.
- Line 15: `so exactly 17 uploads occur` becomes `so exactly M uploads occur`.
- Line 21 and line 26: `after_n_builds: 17` becomes `after_n_builds: M`.

Re-wrap the comment to the file's line width. Write the numbers, not the letters.

Check the two files agree:

```bash
grep -n "TOTAL_SHARDS:" .github/workflows/ci.yaml
grep -n "after_n_builds:" codecov.yml
```

Expected: `after_n_builds` is `TOTAL_SHARDS` plus one, on both lines.

- [ ] **Step 3: Update the example in the docs**

In `docs/developer/testing.md`, in the section added in Task 10, change `--total-shards 6` to `--total-shards <N>`, and the shard index in the same command to one that exists.

- [ ] **Step 4: Commit and push**

```bash
git add .github/workflows/ci.yaml codecov.yml docs/developer/testing.md
git commit -m "ci: cut the test shards to the fewest that keep tests off the critical path" -m "Refs #2500"
SKIP_TESTS=1 git push origin ericgriffin/test-suite-pruning-f84119
```

- [ ] **Step 5: Confirm the result**

When CI finishes:

1. Every shard is green.
2. The `codecov/patch` and `codecov/project` statuses have settled. If they stay pending after every job has finished, `after_n_builds` does not match the number of uploads: recount and fix it.
3. Project coverage on the PR is within 0.5 points of main.
4. Run the script from Task 10 Step 6 on this run. The slowest shard is under the slowest build. If it is not, add one shard, change `after_n_builds` with it, and push again.

Post a comment on the PR with the before and after: shard count, total job-minutes of the test job, the slowest shard, and project coverage. Tick the two open boxes in the PR's Test Plan.
