#!/usr/bin/env python3
"""Unit tests for check_ruby_versions.py."""

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


guard = _load("check_ruby_versions")


def _step(version, quote="'"):
    lines = [
        "      - name: Setup Ruby",
        "        uses: ruby/setup-ruby@v1",
        "        with:",
    ]
    if version is not None:
        lines.append(f"          ruby-version: {quote}{version}{quote}")
    lines += ["          bundler-cache: true", "          working-directory: ios", ""]
    return "\n".join(lines)


class GuardTest(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.root)
        os.makedirs(os.path.join(self.root, ".github", "workflows"))

    def write(self, name, *steps):
        path = os.path.join(self.root, ".github", "workflows", name)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write("jobs:\n  a:\n    steps:\n" + "".join(steps))

    def run_main(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            code = guard.main(self.root)
        return code, out.getvalue()

    def test_one_version_everywhere_passes(self):
        self.write("beta.yml", _step("3.4"), _step("3.4", quote='"'))
        self.write("ci.yaml", _step("3.4", quote=""))
        code, out = self.run_main()
        self.assertEqual(code, 0, out)
        self.assertIn("3.4", out)

    def test_a_second_version_fails_and_names_every_pin(self):
        # The install check in ci.yaml testing 3.4 while a lane moved on to
        # 3.5 would pass a bundle that lane cannot install.
        self.write("beta.yml", _step("3.5"))
        self.write("ci.yaml", _step("3.4"))
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn(os.path.join(".github", "workflows", "beta.yml") + ":7: 3.5", out)
        self.assertIn(os.path.join(".github", "workflows", "ci.yaml") + ":7: 3.4", out)

    def test_a_setup_ruby_step_without_a_version_fails(self):
        # setup-ruby then reads .ruby-version, which no lane keeps, so the
        # step would run whatever default the action picks.
        self.write("beta.yml", _step("3.4"), _step(None))
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("ruby-version", out)

    def test_no_setup_ruby_step_fails(self):
        # Every fastlane lane needs Ruby; finding none means the scan broke.
        self.write("ci.yaml", "")
        code, out = self.run_main()
        self.assertEqual(code, 1)

    def test_a_dash_led_uses_step_is_bounded_by_its_sibling(self):
        # `- uses:` carries the step's dash itself; the next step's pin must
        # not be read as this step's.
        self.write(
            "beta.yml",
            "      - uses: ruby/setup-ruby@v1\n"
            "        with:\n"
            "          bundler-cache: true\n"
            "      - uses: ruby/setup-ruby@v1\n"
            "        with:\n"
            "          ruby-version: '3.4'\n",
        )
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn(
            os.path.join(".github", "workflows", "beta.yml")
            + ":4: ruby/setup-ruby step has no ruby-version",
            out,
        )

    def test_a_missing_workflows_directory_fails_without_a_traceback(self):
        shutil.rmtree(os.path.join(self.root, ".github"))
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("scan is broken", out)

    def test_files_that_are_not_workflows_are_skipped(self):
        self.write("beta.yml", _step("3.4"))
        with open(
            os.path.join(self.root, ".github", "workflows", "README.md"),
            "w",
            encoding="utf-8",
        ) as fh:
            fh.write("ruby-version: '3.2'\n")
        code, out = self.run_main()
        self.assertEqual(code, 0, out)

    def test_a_commented_out_pin_is_ignored(self):
        self.write(
            "beta.yml",
            _step("3.4"),
            "          # ruby-version: '3.2'\n",
        )
        code, out = self.run_main()
        self.assertEqual(code, 0, out)

    def test_the_repo_pins_one_ruby(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            code = guard.main(_REPO)
        self.assertEqual(code, 0, out.getvalue())


if __name__ == "__main__":
    unittest.main()
