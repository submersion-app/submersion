#!/usr/bin/env python3
"""Unit tests for check_docs_links.py."""

import contextlib
import importlib.util
import io
import os
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "check_docs_links", os.path.join(_HERE, "check_docs_links.py")
)
guard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guard)


def write(root, rel, content=""):
    path = os.path.join(root, *rel.split("/"))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)


class LinkTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = self._tmp.name
        self.addCleanup(self._tmp.cleanup)

    def test_resolving_link_passes(self):
        write(self.root, "docs/developer/testing.md")
        write(self.root, "docs/developer/README.md", "[T](testing.md)\n")
        self.assertEqual(guard.check_links(self.root), [])

    def test_broken_link_fails_with_location(self):
        write(self.root, "docs/developer/README.md", "x\n[T](missing.md)\n")
        failures = guard.check_links(self.root)
        self.assertEqual(len(failures), 1)
        self.assertIn(os.path.join("docs", "developer", "README.md") + ":2", failures[0])
        self.assertIn("missing.md", failures[0])

    def test_fragment_is_stripped(self):
        write(self.root, "docs/contributing/code-style.md")
        write(self.root, "docs/contributing/README.md", "[S](code-style.md#imports)\n")
        self.assertEqual(guard.check_links(self.root), [])

    def test_urls_and_anchors_are_skipped(self):
        write(
            self.root,
            "docs/README.md",
            "[a](https://example.com/x.md) [b](#top) [c](mailto:a@b.c)\n",
        )
        self.assertEqual(guard.check_links(self.root), [])

    def test_fenced_code_is_ignored(self):
        write(self.root, "docs/developer/README.md", "```\n[T](missing.md)\n```\n")
        self.assertEqual(guard.check_links(self.root), [])

    def test_excluded_trees_are_not_checked(self):
        write(self.root, "docs/design/specs/a.md", "[x](../../lib/gone.dart)\n")
        write(self.root, "docs/design/plans/b.md", "[x](gone.md)\n")
        self.assertEqual(guard.check_links(self.root), [])

    def test_root_relative_link_resolves_from_repo_root(self):
        write(self.root, "CONTRIBUTING.md")
        write(self.root, "docs/developer/README.md", "[C](/CONTRIBUTING.md) [G](/gone.md)\n")
        failures = guard.check_links(self.root)
        self.assertEqual(len(failures), 1)
        self.assertIn("/gone.md", failures[0])

    def test_inline_code_is_ignored(self):
        write(self.root, "docs/contributing/README.md", "Write `[Testing](testing.md)` like this.\n")
        self.assertEqual(guard.check_links(self.root), [])

    def test_angle_bracket_and_parenthesized_destinations(self):
        write(self.root, "docs/developer/release notes.md")
        write(self.root, "docs/developer/foo_(v2).md")
        write(
            self.root,
            "docs/developer/README.md",
            '[a](<release notes.md>) [b](foo_(v2).md) [c](foo_(v2).md "Title")\n',
        )
        self.assertEqual(guard.check_links(self.root), [])

    def test_invalid_utf8_file_is_still_checked(self):
        path = os.path.join(self.root, "docs", "developer", "README.md")
        os.makedirs(os.path.dirname(path))
        with open(path, "wb") as fh:
            fh.write(b"caf\xe9 notes\n[x](gone.md)\n")
        self.assertEqual(len(guard.check_links(self.root)), 1)

    def test_fence_closes_only_on_matching_marker(self):
        write(
            self.root,
            "docs/contributing/README.md",
            "````\n```\n[a](inside.md)\n```\n````\n[b](after.md)\n",
        )
        failures = guard.check_links(self.root)
        self.assertEqual(len(failures), 1)
        self.assertIn("after.md", failures[0])

    def test_reference_definitions_and_html_are_checked(self):
        write(self.root, "docs/developer/ok.md")
        write(
            self.root,
            "docs/developer/README.md",
            "[ok]: ok.md\n[gone]: gone.md \"Title\"\n<img src=\"missing.png\">\n"
            '<a href="https://example.com/x.md">ext</a>\n',
        )
        failures = guard.check_links(self.root)
        self.assertEqual(len(failures), 2)
        self.assertIn("gone.md", failures[0])
        self.assertIn("missing.png", failures[1])

    def test_link_to_directory_with_readme_passes(self):
        write(self.root, "docs/contributing/README.md")
        write(self.root, "docs/README.md", "[C](contributing/)\n")
        self.assertEqual(guard.check_links(self.root), [])


class CodeRefTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = self._tmp.name
        self.addCleanup(self._tmp.cleanup)

    def test_resolving_reference_passes(self):
        write(self.root, "docs/design/specs/2026-01-01-x-design.md")
        write(self.root, "lib/a.dart", "/// See docs/design/specs/2026-01-01-x-design.md.\n")
        self.assertEqual(guard.check_code_refs(self.root), [])

    def test_broken_reference_fails(self):
        write(self.root, "lib/a.dart", "// docs/developer/gone.md\n")
        failures = guard.check_code_refs(self.root)
        self.assertEqual(len(failures), 1)
        self.assertIn(os.path.join("lib", "a.dart") + ":1", failures[0])

    def test_lookalikes_are_ignored(self):
        write(
            self.root,
            ".github/workflows/ci.yaml",
            "# a docs/CI-only change; docs/img/x.png; docs/scanned_logs/1.jpg\n",
        )
        self.assertEqual(guard.check_code_refs(self.root), [])

    def test_docs_path_inside_external_url_is_ignored(self):
        write(self.root, "lib/a.dart", "// https://example.org/docs/developer/guide.md\n")
        self.assertEqual(guard.check_code_refs(self.root), [])

    def test_dot_relative_references_are_checked(self):
        write(self.root, "scripts/a.py", "# see ../docs/design/specs/gone-design.md\n")
        write(self.root, "README.md", "[x](./docs/developer/gone.md)\n")
        write(self.root, "lib/b.dart", "// ../docs/plans/old-plan.md\n")
        failures = guard.check_code_refs(self.root)
        self.assertEqual(len(failures), 3)
        self.assertTrue(any("retired docs path" in f for f in failures))

    def test_binary_files_are_skipped(self):
        path = os.path.join(self.root, "test", "fixture.bin")
        os.makedirs(os.path.dirname(path))
        with open(path, "wb") as fh:
            fh.write(b"\x00\x01docs/developer/gone.md")
        self.assertEqual(guard.check_code_refs(self.root), [])

    def test_top_level_files_are_scanned(self):
        write(self.root, "CLAUDE.md", "See docs/contributing/gone.md\n")
        self.assertEqual(len(guard.check_code_refs(self.root)), 1)

    def test_retired_path_cited_from_code_fails(self):
        write(self.root, "lib/a.dart", "/// docs/superpowers/specs/2026-01-01-x-design.md\n")
        write(self.root, "lib/b.dart", "// see docs/api/entities.md\n")
        failures = guard.check_code_refs(self.root)
        self.assertEqual(len(failures), 2)
        self.assertIn("docs/design/", failures[0])
        self.assertIn("docs/developer/reference/", failures[1])

    def test_retired_path_inside_a_url_is_ignored(self):
        write(self.root, "lib/a.dart", "// https://example.com/docs/api/index.html\n")
        self.assertEqual(guard.check_code_refs(self.root), [])

    def test_guard_test_file_is_not_scanned(self):
        write(self.root, "scripts/check_docs_links_test.py", "'docs/developer/gone.md'\n")
        self.assertEqual(guard.check_code_refs(self.root), [])


class RetiredTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = self._tmp.name
        self.addCleanup(self._tmp.cleanup)

    def test_retired_folder_absent_passes(self):
        write(self.root, "docs/design/specs/a.md")
        self.assertEqual(guard.check_retired(self.root), [])

    def test_empty_retired_folder_passes(self):
        os.makedirs(os.path.join(self.root, "docs", "superpowers", "specs"))
        write(self.root, "docs/plans/.DS_Store")
        self.assertEqual(guard.check_retired(self.root), [])

    def test_retired_folder_present_fails(self):
        write(self.root, "docs/superpowers/specs/2026-10-07-x-design.md")
        write(self.root, "docs/plans/2026-10-07-y-plan.md")
        failures = guard.check_retired(self.root)
        self.assertEqual(len(failures), 2)
        self.assertIn("docs/design/", failures[0])
        self.assertIn("docs/design/", failures[1])


class UserDocsTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = self._tmp.name
        self.addCleanup(self._tmp.cleanup)
        write(self.root, "docs/user/README.md", "# Home\n")
        write(self.root, "docs/user/_sidebar.md", "* [Home](README.md)\n* [Sites](dive-sites.md)\n")
        write(self.root, "docs/user/dive-sites.md", "# Dive Sites\n\n## Maps & Layers\n")

    def test_valid_tree_passes(self):
        self.assertEqual(guard.check_user_docs(self.root), [])

    def test_no_user_docs_folder_passes(self):
        with tempfile.TemporaryDirectory() as root:
            self.assertEqual(guard.check_user_docs(root), [])

    def test_subfolder_fails(self):
        write(self.root, "docs/user/guide/old.md")
        failures = guard.check_user_docs(self.root)
        self.assertEqual(len(failures), 1)
        self.assertIn("flat", failures[0])

    def test_images_folder_is_allowed_but_not_for_pages(self):
        write(self.root, "docs/user/images/shot.png")
        self.assertEqual(guard.check_user_docs(self.root), [])
        write(self.root, "docs/user/images/stray.md")
        self.assertEqual(len(guard.check_user_docs(self.root)), 1)

    def test_page_missing_from_sidebar_fails(self):
        write(self.root, "docs/user/trips.md", "# Trips\n")
        failures = guard.check_user_docs(self.root)
        self.assertEqual(len(failures), 1)
        self.assertIn("trips.md", failures[0])

    def test_same_page_and_cross_page_anchors_resolve(self):
        write(
            self.root,
            "docs/user/README.md",
            "# Home\n\n## Getting Started\n\n[a](#getting-started) "
            "[b](dive-sites.md#maps--layers)\n",
        )
        self.assertEqual(guard.check_user_docs(self.root), [])

    def test_missing_anchor_fails(self):
        write(self.root, "docs/user/README.md", "# Home\n\n[a](#nowhere) [b](dive-sites.md#gone)\n")
        failures = guard.check_user_docs(self.root)
        self.assertEqual(len(failures), 2)
        self.assertIn("#nowhere", failures[0])

    def test_github_slug_rules(self):
        self.assertEqual(guard.github_slug("Security & Privacy"), "security--privacy")
        self.assertEqual(guard.github_slug("Use `ppO2` limits"), "use-ppo2-limits")
        self.assertEqual(guard.github_slug("See [Sites](dive-sites.md) **now**"), "see-sites-now")
        self.assertEqual(guard.github_slug("Tanks &mdash; or gear?"), "tanks--or-gear")

    def test_repeated_heading_gets_a_suffix(self):
        write(self.root, "docs/user/README.md", "# Home\n\n## Notes\n\n## Notes\n\n[a](#notes-1)\n")
        self.assertEqual(guard.check_user_docs(self.root), [])

    def test_link_to_digit_leading_heading_fails(self):
        write(
            self.root,
            "docs/user/README.md",
            "# Home\n\n## 1. Enable R2\n\n## 2. Create a bucket\n\n[a](#1-enable-r2)\n",
        )
        failures = guard.check_user_docs(self.root)
        self.assertEqual(len(failures), 1)
        self.assertIn("'_1-enable-r2'", failures[0])

    def test_docsify_slug_rules(self):
        # docsify 5 drops only its fixed punctuation set and lowercases A-Z.
        self.assertEqual(guard.docsify_slug("Security & Privacy"), "security--privacy")
        self.assertEqual(guard.docsify_slug("Depth \u2265 30 m"), "depth-\u2265-30-m")
        self.assertEqual(guard.docsify_slug("\u00dcber Gas"), "\u00dcber-gas")
        self.assertEqual(guard.docsify_slug("1. Enable R2"), "_1-enable-r2")

    def test_link_to_heading_docsify_slugs_differently_fails(self):
        write(self.root, "docs/user/README.md", "# Home\n\n## Depth \u2265 30 m\n\n[a](#depth--30-m)\n")
        failures = guard.check_user_docs(self.root)
        self.assertEqual(len(failures), 1)
        self.assertIn("docsify", failures[0])

    def test_external_sidebar_link_does_not_count_as_a_page(self):
        write(
            self.root,
            "docs/user/_sidebar.md",
            "* [Home](README.md)\n* [Sites](dive-sites.md)\n"
            "* [Spec](https://github.com/o/r/blob/main/trips.md)\n",
        )
        write(self.root, "docs/user/trips.md", "# Trips\n")
        failures = guard.check_user_docs(self.root)
        self.assertEqual(len(failures), 1)
        self.assertIn("trips.md", failures[0])

    def test_stray_file_beside_the_pages_fails(self):
        write(self.root, "docs/user/shot.png")
        failures = guard.check_user_docs(self.root)
        self.assertEqual(len(failures), 1)
        self.assertIn("images/", failures[0])

    def test_links_outside_user_docs_are_left_to_check_links(self):
        write(self.root, "docs/user/README.md", "# Home\n\n[a](../developer/x.md#y) [b](https://e.org/a#b)\n")
        self.assertEqual(guard.check_user_docs(self.root), [])

    def test_raw_relative_html_link_or_image_fails(self):
        write(
            self.root,
            "docs/user/README.md",
            '# Home\n\n<a href="dive-sites.md">Sites</a>\n<img src="images/x.png" alt="x">\n'
            '<a href="https://example.com">ok</a>\n',
        )
        failures = guard.check_user_docs(self.root)
        self.assertEqual(len(failures), 2)
        self.assertIn("Markdown", failures[0])


class MainTests(unittest.TestCase):
    def test_default_root_is_the_repository(self):
        self.assertTrue(os.path.isdir(os.path.join(guard.DEFAULT_ROOT, "docs")))
        self.assertTrue(os.path.isdir(os.path.join(guard.DEFAULT_ROOT, "scripts")))

    def test_root_without_docs_is_an_error(self):
        with tempfile.TemporaryDirectory() as root:
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(guard.main(["prog", root]), 2)
            self.assertIn("no docs/ folder", out.getvalue())

    def test_exit_codes(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, "docs/README.md", "ok\n")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(guard.main(["prog", root]), 0)
            write(root, "docs/README.md", "[x](gone.md)\n")
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(guard.main(["prog", root]), 1)
            self.assertIn("gone.md", out.getvalue())


if __name__ == "__main__":
    unittest.main()
