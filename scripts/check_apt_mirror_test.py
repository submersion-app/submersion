#!/usr/bin/env python3
"""Unit tests for check_apt_mirror.py."""

import contextlib
import importlib.util
import io
import os
import shutil
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.dirname(_HERE)


def _load(name):
    spec = importlib.util.spec_from_file_location(
        name, os.path.join(_HERE, f"{name}.py")
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


guard = _load("check_apt_mirror")

MIRROR = "          sudo python3 scripts/apt_mirror.py\n"
UPDATE = "          sudo apt-get update\n"
INSTALL = "          sudo apt-get install -y clang\n"
PLAYWRIGHT = "          python3 -m playwright install --with-deps firefox\n"


def _step(name, *lines):
    return f"      - name: {name}\n        run: |\n" + "".join(lines)


def _job(name, *steps):
    return f"  {name}:\n    runs-on: ubuntu-24.04\n    steps:\n" + "".join(steps)


class GuardTest(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.root)
        os.makedirs(os.path.join(self.root, ".github", "workflows"))

    def write(self, name, *jobs):
        path = os.path.join(self.root, ".github", "workflows", name)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write("on: push\njobs:\n" + "".join(jobs))

    def run_main(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            code = guard.main(self.root)
        return code, out.getvalue()

    def test_mirror_before_install_passes(self):
        self.write("ci.yaml", _job("linux", _step("Deps", MIRROR, UPDATE, INSTALL)))
        code, out = self.run_main()
        self.assertEqual(code, 0, out)

    def test_a_later_step_in_the_same_job_is_covered(self):
        self.write(
            "ci.yaml",
            _job(
                "linux",
                _step("Deps", MIRROR, UPDATE, INSTALL),
                _step("Packaging tools", INSTALL),
            ),
        )
        code, out = self.run_main()
        self.assertEqual(code, 0, out)

    def test_install_without_mirror_fails_naming_the_job(self):
        self.write(
            "build-all.yml",
            _job("ok", _step("Deps", MIRROR, INSTALL)),
            _job("build-linux", _step("Deps", UPDATE, INSTALL)),
        )
        code, out = self.run_main()
        self.assertEqual(code, 1, out)
        self.assertIn("build-all.yml", out)
        self.assertIn("build-linux", out)
        self.assertNotIn(" ok", out)

    def test_mirror_after_install_fails(self):
        self.write("ci.yaml", _job("linux", _step("Deps", UPDATE, INSTALL, MIRROR)))
        code, out = self.run_main()
        self.assertEqual(code, 1, out)

    def test_another_jobs_mirror_does_not_count(self):
        self.write(
            "ci.yaml",
            _job("first", _step("Deps", MIRROR, INSTALL)),
            _job("second", _step("Deps", INSTALL)),
        )
        code, out = self.run_main()
        self.assertEqual(code, 1, out)
        self.assertIn("second", out)

    def test_options_before_install_still_count(self):
        for command in (
            "sudo apt-get -y install clang",
            "sudo apt-get --no-install-recommends install clang",
            "sudo apt-get -o Dpkg::Options::=--force-confnew install clang",
            "sudo apt -qq install clang",
            "sudo DEBIAN_FRONTEND=noninteractive apt-get -y -q install clang",
        ):
            with self.subTest(command=command):
                self.write(
                    "ci.yaml",
                    _job("linux", _step("Deps", f"          {command}\n")),
                )
                code, out = self.run_main()
                self.assertEqual(code, 1, out)
                self.assertIn("linux", out)

    def test_other_apt_commands_are_not_installs(self):
        self.write(
            "ci.yaml",
            _job(
                "linux",
                _step(
                    "Inspect",
                    "          apt-get -s upgrade\n",
                    "          apt-cache policy clang\n",
                    "          sudo apt-get update\n",
                ),
            ),
        )
        code, out = self.run_main()
        self.assertEqual(code, 0, out)

    def test_playwright_with_deps_counts_as_an_install(self):
        self.write("ci.yaml", _job("smoke", _step("Browsers", PLAYWRIGHT)))
        code, out = self.run_main()
        self.assertEqual(code, 1, out)
        self.write("ci.yaml", _job("smoke", _step("Browsers", MIRROR, PLAYWRIGHT)))
        code, out = self.run_main()
        self.assertEqual(code, 0, out)

    def test_commented_lines_are_ignored(self):
        self.write(
            "ci.yaml",
            _job("docs", _step("Note", "          # sudo apt-get install -y clang\n")),
            _job(
                "linux",
                _step("Deps", "          # sudo python3 scripts/apt_mirror.py\n", INSTALL),
            ),
        )
        code, out = self.run_main()
        self.assertEqual(code, 1, out)
        self.assertIn("linux", out)
        self.assertNotIn("docs", out)

    def test_a_step_name_is_not_an_install(self):
        self.write(
            "ci.yaml",
            _job("guards", "      - name: Check every apt install is mirrored\n"),
        )
        code, out = self.run_main()
        self.assertEqual(code, 0, out)

    def test_job_without_apt_passes(self):
        self.write("ci.yaml", _job("dart", _step("Test", "          flutter test\n")))
        code, out = self.run_main()
        self.assertEqual(code, 0, out)

    def test_the_repository_passes(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            code = guard.main(_REPO)
        self.assertEqual(code, 0, out.getvalue())


if __name__ == "__main__":
    unittest.main()
