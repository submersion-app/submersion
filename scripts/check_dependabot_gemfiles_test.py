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


def _write(root, relpath, text):
    path = os.path.join(root, *relpath.split("/"))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


# The shape of .github/dependabot.yml: a directories list for bundler, a scalar
# directory for the other ecosystems.
DEPENDABOT_YML = """version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"

  # Ruby/Bundler (Fastlane)
  - package-ecosystem: "bundler"
    directories:
      - "/ios"
      - '/macos'  # quoted either way
    schedule:
      interval: "monthly"

  - package-ecosystem: "pub"
    directory: "/"
"""


class CoverageTest(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.root)

    def test_bundler_directories_reads_the_directories_list(self):
        _write(self.root, ".github/dependabot.yml", DEPENDABOT_YML)
        self.assertEqual(guard.bundler_directories(self.root), ["ios", "macos"])

    def test_bundler_directories_reads_a_scalar_directory(self):
        _write(
            self.root,
            ".github/dependabot.yml",
            'updates:\n  - package-ecosystem: bundler\n    directory: "/"\n',
        )
        self.assertEqual(guard.bundler_directories(self.root), [""])

    def test_bundler_directories_without_a_config_is_empty(self):
        self.assertEqual(guard.bundler_directories(self.root), [])

    def test_a_gemfile_outside_every_bundler_directory_is_uncovered(self):
        # android/ was left out when its Gemfile arrived (#2292), so Dependabot
        # never proposed an update for the Play lanes' fastlane (#3495).
        _write(self.root, ".github/dependabot.yml", DEPENDABOT_YML)
        for d in ("ios", "macos", "android"):
            _write(self.root, f"{d}/Gemfile", 'gem "fastlane"\n')
        self.assertEqual(guard.uncovered(self.root), [os.path.join("android", "Gemfile")])

    def test_a_glob_directory_covers_the_gemfiles_it_matches(self):
        _write(
            self.root,
            ".github/dependabot.yml",
            'updates:\n  - package-ecosystem: "bundler"\n    directories:\n      - "/*"\n',
        )
        _write(self.root, "android/Gemfile", 'gem "fastlane"\n')
        self.assertEqual(guard.uncovered(self.root), [])

    def test_a_single_star_stays_within_one_segment(self):
        _write(
            self.root,
            ".github/dependabot.yml",
            'updates:\n  - package-ecosystem: "bundler"\n    directories:\n      - "/*"\n',
        )
        _write(self.root, "tools/ci/Gemfile", 'gem "rake"\n')
        self.assertEqual(guard.uncovered(self.root), [os.path.join("tools", "ci", "Gemfile")])

    def test_a_double_star_spans_segments_and_the_root(self):
        _write(
            self.root,
            ".github/dependabot.yml",
            'updates:\n  - package-ecosystem: "bundler"\n    directories:\n      - "/**"\n',
        )
        _write(self.root, "Gemfile", 'gem "rake"\n')
        _write(self.root, "tools/ci/Gemfile", 'gem "rake"\n')
        self.assertEqual(guard.uncovered(self.root), [])

    def test_another_ecosystems_directories_list_does_not_count(self):
        _write(
            self.root,
            ".github/dependabot.yml",
            "updates:\n"
            '  - package-ecosystem: "bundler"\n'
            "    directories:\n"
            '      - "/ios"\n'
            '  - package-ecosystem: "npm"\n'
            "    directories:\n"
            '      - "/android"\n',
        )
        self.assertEqual(guard.bundler_directories(self.root), ["ios"])

    def test_the_ecosystem_key_need_not_come_first(self):
        _write(
            self.root,
            ".github/dependabot.yml",
            "updates:\n"
            '  - directory: "/ios"\n'
            '    package-ecosystem: "bundler"\n'
            '  - directory: "/android"\n'
            '    package-ecosystem: "pub"\n',
        )
        self.assertEqual(guard.bundler_directories(self.root), ["ios"])

    def test_a_flow_style_directories_list_is_read(self):
        _write(
            self.root,
            ".github/dependabot.yml",
            "updates:\n"
            '  - package-ecosystem: "bundler"\n'
            "    directories: [\"/ios\", '/macos', /android]  # all three\n"
            '    schedule:\n      interval: "monthly"\n',
        )
        self.assertEqual(
            guard.bundler_directories(self.root), ["ios", "macos", "android"]
        )

    def test_lists_under_other_top_level_keys_are_not_entries(self):
        # A registries list before updates: its items are not update entries,
        # even though they are key-led list items with a directory-like value.
        _write(
            self.root,
            ".github/dependabot.yml",
            "version: 2\n"
            "registries:\n"
            "  ruby-github:\n"
            "    type: rubygems-server\n"
            '    url: "https://rubygems.pkg.github.com/acme"\n'
            "updates:\n"
            '  - package-ecosystem: "bundler"\n'
            '    directory: "/ios"\n',
        )
        self.assertEqual(guard.bundler_directories(self.root), ["ios"])

    def test_a_double_star_slash_matches_any_depth_including_none(self):
        _write(
            self.root,
            ".github/dependabot.yml",
            'updates:\n  - package-ecosystem: "bundler"\n    directories:\n'
            '      - "/**/fastlane"\n',
        )
        _write(self.root, "fastlane/Gemfile", 'gem "rake"\n')
        _write(self.root, "ios/fastlane/Gemfile", 'gem "rake"\n')
        _write(self.root, "ios/Gemfile", 'gem "rake"\n')
        self.assertEqual(guard.uncovered(self.root), [os.path.join("ios", "Gemfile")])

    def test_a_question_mark_matches_one_character_in_a_segment(self):
        _write(
            self.root,
            ".github/dependabot.yml",
            'updates:\n  - package-ecosystem: "bundler"\n    directories:\n'
            '      - "/i?s"\n',
        )
        _write(self.root, "ios/Gemfile", 'gem "rake"\n')
        _write(self.root, "iOS2/Gemfile", 'gem "rake"\n')
        self.assertEqual(guard.uncovered(self.root), [os.path.join("iOS2", "Gemfile")])

    def test_unindented_update_items_are_entries(self):
        _write(
            self.root,
            ".github/dependabot.yml",
            "version: 2\n"
            "updates:\n"
            '- package-ecosystem: "bundler"\n'
            "  directories:\n"
            '  - "/ios"\n'
            '- package-ecosystem: "pub"\n'
            '  directory: "/"\n',
        )
        self.assertEqual(guard.bundler_directories(self.root), ["ios"])

    def test_an_ignore_list_does_not_end_the_entry(self):
        _write(
            self.root,
            ".github/dependabot.yml",
            "updates:\n"
            '  - package-ecosystem: "bundler"\n'
            "    ignore:\n"
            '      - dependency-name: "rake"\n'
            "    directories:\n"
            '      - "/ios"\n',
        )
        self.assertEqual(guard.bundler_directories(self.root), ["ios"])

    def test_an_uncovered_gemfile_fails_main(self):
        _write(self.root, ".github/dependabot.yml", DEPENDABOT_YML)
        _write(self.root, "android/Gemfile", 'gem "fastlane"\n')
        with contextlib.redirect_stdout(io.StringIO()) as out:
            code = guard.main(self.root)
        self.assertEqual(code, 1)
        self.assertIn(os.path.join("android", "Gemfile") + ":", out.getvalue())
        self.assertIn("dependabot.yml", out.getvalue())


class MainTest(unittest.TestCase):
    def test_the_repo_gemfiles_are_parseable_by_dependabot(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            code = guard.main(_REPO)
        self.assertEqual(code, 0, out.getvalue())

    def test_the_repo_has_the_gemfiles_dependabot_updates(self):
        found = {os.path.relpath(p, _REPO) for p in guard.gemfiles(_REPO)}
        self.assertTrue(
            {
                os.path.join("ios", "Gemfile"),
                os.path.join("macos", "Gemfile"),
                os.path.join("android", "Gemfile"),
            }
            <= found,
            found,
        )

    def test_a_bad_gemfile_fails_main(self):
        root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, root)
        _write(root, ".github/dependabot.yml", DEPENDABOT_YML)
        _write(root, "ios/Gemfile", FASTLANE_TEMPLATE)
        with contextlib.redirect_stdout(io.StringIO()) as out:
            code = guard.main(root)
        self.assertEqual(code, 1)
        self.assertIn(os.path.join("ios", "Gemfile") + ":6", out.getvalue())


if __name__ == "__main__":
    unittest.main()
