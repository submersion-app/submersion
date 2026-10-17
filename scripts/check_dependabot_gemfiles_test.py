#!/usr/bin/env python3
"""Unit tests for check_dependabot_gemfiles.py."""

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


guard = _load("check_dependabot_gemfiles")

# The Gemfile fastlane generates, and that ios/ and macos/ carried until #2766.
# Dependabot rejected it as `dependency_file_not_parseable` every month.
FASTLANE_TEMPLATE = """source "https://rubygems.org"

gem "fastlane"

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
"""


class ProblemsTest(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.root)
        self.gemfile = os.path.join(self.root, "Gemfile")

    def problems(self, text):
        with open(self.gemfile, "w", encoding="utf-8") as fh:
            fh.write(text)
        return guard.problems(self.gemfile)

    def write_pluginfile(self):
        os.makedirs(os.path.join(self.root, "fastlane"))
        with open(
            os.path.join(self.root, "fastlane", "Pluginfile"), "w", encoding="utf-8"
        ) as fh:
            fh.write('gem "fastlane-plugin-example"\n')

    def test_the_fastlane_template_is_rejected(self):
        found = self.problems(FASTLANE_TEMPLATE)
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0][0], 6)
        self.assertIn("string literal", found[0][1])

    def test_a_gemfile_without_eval_gemfile_passes(self):
        self.assertEqual(self.problems('source "https://rubygems.org"\ngem "fastlane"\n'), [])

    def test_a_literal_path_to_an_existing_file_passes(self):
        self.write_pluginfile()
        self.assertEqual(self.problems('eval_gemfile "fastlane/Pluginfile"\n'), [])
        self.assertEqual(self.problems("eval_gemfile('fastlane/Pluginfile')\n"), [])

    def test_a_literal_path_to_a_missing_file_is_rejected(self):
        found = self.problems('eval_gemfile "fastlane/Pluginfile"\n')
        self.assertEqual(len(found), 1)
        self.assertIn("does not exist", found[0][1])

    def test_an_interpolated_string_is_rejected(self):
        self.write_pluginfile()
        found = self.problems('eval_gemfile "#{__dir__}/fastlane/Pluginfile"\n')
        self.assertEqual(len(found), 1)
        self.assertIn("string literal", found[0][1])

    def test_a_trailing_modifier_is_rejected(self):
        # Dependabot reads the argument, not the condition, but a guarded call
        # is the template's shape and the file it guards is then optional.
        self.write_pluginfile()
        found = self.problems(
            'eval_gemfile "fastlane/Pluginfile" if File.exist?("fastlane/Pluginfile")\n'
        )
        self.assertEqual(len(found), 1)

    def test_a_call_later_in_the_line_is_checked(self):
        found = self.problems("x = 1; eval_gemfile(plugins_path)\n")
        self.assertEqual(len(found), 1)
        self.assertIn("string literal", found[0][1])

    def test_comments_are_ignored(self):
        self.assertEqual(self.problems("# eval_gemfile(plugins_path)\n"), [])

    def test_a_trailing_comment_mention_is_ignored(self):
        self.assertEqual(
            self.problems('gem "fastlane" # see eval_gemfile(plugins_path)\n'), []
        )

    def test_a_mention_inside_a_string_is_ignored(self):
        self.assertEqual(self.problems("puts 'eval_gemfile(plugins_path)'\n"), [])
        self.assertEqual(self.problems('puts "say \\"eval_gemfile(x)\\""\n'), [])

    def test_a_literal_call_with_a_trailing_comment_passes(self):
        self.write_pluginfile()
        self.assertEqual(
            self.problems('eval_gemfile "fastlane/Pluginfile" # plugins\n'), []
        )


class MainTest(unittest.TestCase):
    def test_the_repo_gemfiles_are_parseable_by_dependabot(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            code = guard.main(_REPO)
        self.assertEqual(code, 0, out.getvalue())

    def test_the_repo_has_the_gemfiles_dependabot_updates(self):
        found = {os.path.relpath(p, _REPO) for p in guard.gemfiles(_REPO)}
        self.assertTrue(
            {os.path.join("ios", "Gemfile"), os.path.join("macos", "Gemfile")} <= found,
            found,
        )

    def test_a_bad_gemfile_fails_main(self):
        root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, root)
        os.makedirs(os.path.join(root, "ios"))
        with open(os.path.join(root, "ios", "Gemfile"), "w", encoding="utf-8") as fh:
            fh.write(FASTLANE_TEMPLATE)
        with contextlib.redirect_stdout(io.StringIO()) as out:
            code = guard.main(root)
        self.assertEqual(code, 1)
        self.assertIn(os.path.join("ios", "Gemfile") + ":6", out.getvalue())


if __name__ == "__main__":
    unittest.main()
