#!/usr/bin/env python3
"""Unit tests for check_scripts_index.py."""

import contextlib
import importlib.util
import io
import os
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "check_scripts_index", os.path.join(_HERE, "check_scripts_index.py")
)
guard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guard)


def write(root, rel, content=""):
    path = os.path.join(root, *rel.split("/"))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)


class GuardCase(unittest.TestCase):
    """Builds a tree in a temporary folder and runs the guard over it."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = self._tmp.name
        self.files = []

    def tearDown(self):
        self._tmp.cleanup()

    def add(self, rel, content=""):
        write(self.root, rel, content)
        self.files.append(rel)

    def index(self, *paths):
        lines = ["# Scripts", ""] + [f"- `{p}`: does a thing." for p in paths]
        self.add("scripts/README.md", "\n".join(lines) + "\n")

    def problems(self):
        return guard.find_problems(self.root, sorted(self.files))


class IndexTest(GuardCase):
    def test_clean_tree_has_no_problems(self):
        self.index("scripts/checks/a.py")
        self.add("scripts/checks/a.py")
        self.add("scripts/checks/a_test.py")
        self.assertEqual(self.problems(), [])

    def test_unindexed_script_is_reported(self):
        self.index()
        self.add("scripts/checks/a.py")
        problems = self.problems()
        self.assertEqual(len(problems), 1)
        self.assertIn("scripts/checks/a.py", problems[0])
        self.assertIn("add it to scripts/README.md", problems[0])

    def test_tests_conftest_and_fixtures_are_exempt(self):
        self.index()
        self.add("scripts/web/conftest.py")
        self.add("scripts/web/x_test.py")
        self.add("scripts/web/fixtures/y.py")
        self.assertEqual(self.problems(), [])

    def test_dart_entry_point_needs_index_but_library_does_not(self):
        self.index()
        self.add("tool/a.dart", "void main() {}\n")
        self.add("tool/src/b.dart", "int answer() => 42;\n")
        problems = self.problems()
        self.assertEqual(len(problems), 1)
        self.assertIn("tool/a.dart", problems[0])

    def test_dangling_index_entry_is_reported(self):
        self.index("scripts/gone.py")
        problems = self.problems()
        self.assertEqual(len(problems), 1)
        self.assertIn("scripts/gone.py", problems[0])
        self.assertIn("remove or correct", problems[0])

    def test_index_folder_entry_is_not_dangling(self):
        self.index("scripts/brand/", "scripts/brand/x.py")
        self.add("scripts/brand/x.py")
        self.assertEqual(self.problems(), [])


class LayoutTest(GuardCase):
    def test_loose_top_level_file_is_reported(self):
        self.index("scripts/new_thing.py")
        self.add("scripts/new_thing.py")
        problems = self.problems()
        self.assertEqual(len(problems), 1)
        self.assertIn("scripts/new_thing.py", problems[0])
        self.assertIn("move it into a purpose folder", problems[0])

    def test_allowed_top_level_files_pass(self):
        self.index("scripts/setup.sh")
        self.add("scripts/setup.sh")
        self.add("scripts/requirements.txt")
        self.assertEqual(self.problems(), [])

    def test_retired_folder_is_reported(self):
        self.index()
        self.add("tools/bench.txt")
        self.add("scripts/data/map.json")
        problems = self.problems()
        self.assertEqual(len(problems), 2)
        joined = "\n".join(problems)
        self.assertIn("tools/", joined)
        self.assertIn("scripts/data/", joined)


class WorkflowPathTest(GuardCase):
    def test_missing_workflow_path_is_reported(self):
        self.index()
        self.add(".github/workflows/w.yml", "run: python3 scripts/checks/gone.py\n")
        problems = self.problems()
        self.assertEqual(len(problems), 1)
        self.assertIn(".github/workflows/w.yml", problems[0])
        self.assertIn("scripts/checks/gone.py", problems[0])

    def test_existing_workflow_path_passes(self):
        self.index("scripts/checks/here.py")
        self.add("scripts/checks/here.py")
        self.add(".github/workflows/w.yml", "run: python3 scripts/checks/here.py\n")
        self.assertEqual(self.problems(), [])

    def test_variable_prefixed_paths_are_checked(self):
        self.index()
        self.add(
            ".github/workflows/w.yml",
            'run: python3 "$GITHUB_WORKSPACE/scripts/gone.py"\n',
        )
        self.add("hooks/pre-push", '. "${REPO_ROOT}/scripts/gone2.sh"\n')
        problems = self.problems()
        self.assertEqual(len(problems), 2)
        joined = "\n".join(problems)
        self.assertIn("scripts/gone.py", joined)
        self.assertIn("scripts/gone2.sh", joined)

    def test_relative_and_nested_paths_are_ignored(self):
        self.index()
        self.add(
            ".github/workflows/w.yml",
            "# see ../scripts/gone.sh\nrun: dart run packages/foo/tool/gone.dart\n",
        )
        self.assertEqual(self.problems(), [])


class MainTest(unittest.TestCase):
    def test_main_returns_one_and_prints_problems(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, "scripts/README.md", "# Scripts\n")
            write(root, "scripts/loose.py")
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                status = guard.main(
                    ["--root", root, "--files", "scripts/README.md", "scripts/loose.py"]
                )
        self.assertEqual(status, 1)
        self.assertIn("scripts/loose.py", out.getvalue())

    def test_main_returns_zero_on_clean_tree(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, "scripts/README.md", "# Scripts\n")
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                status = guard.main(["--root", root, "--files", "scripts/README.md"])
        self.assertEqual(status, 0)


if __name__ == "__main__":
    unittest.main()
