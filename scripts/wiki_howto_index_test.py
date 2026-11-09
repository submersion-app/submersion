#!/usr/bin/env python3
"""Unit tests for wiki_howto_index.py.

Run: python3 scripts/wiki_howto_index_test.py

The wiki Home page lists every How-to page, newest first, between two
markers. The script must find those pages, link them the way the wiki names
them, keep everything else on Home untouched, and order them by when each
page was first created, even after a rename.
"""

import importlib.util
import os
import subprocess
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "wiki_howto_index",
    os.path.join(_HERE, "wiki_howto_index.py"),
)
index = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(index)

START = index.START_MARKER
END = index.END_MARKER


class IsHowtoTest(unittest.TestCase):
    def test_accepts_how_to_pages(self):
        self.assertTrue(index.is_howto("How-to-tag-dives.md"))

    def test_ignores_case_of_the_prefix(self):
        self.assertTrue(index.is_howto("how-To-tag-dives.md"))

    def test_rejects_other_pages(self):
        self.assertFalse(index.is_howto("Home.md"))
        self.assertFalse(index.is_howto("_Sidebar.md"))
        self.assertFalse(index.is_howto("Howto-tag-dives.md"))
        self.assertFalse(index.is_howto("Showing-How-to-tag.md"))

    def test_rejects_non_markdown_files(self):
        self.assertFalse(index.is_howto("How-to-tag-dives.png"))


class PageLinkTest(unittest.TestCase):
    def test_title_turns_dashes_into_spaces(self):
        self.assertEqual(
            index.page_title("How-to-tag-dives-with-rules"),
            "How to tag dives with rules",
        )

    def test_link_escapes_characters_that_break_a_url(self):
        self.assertEqual(
            index.page_link("How-to-use-it?-Yes"),
            "How-to-use-it%3F-Yes",
        )

    def test_list_item_escapes_brackets_in_the_title(self):
        self.assertEqual(
            index.list_item("How-to-read-[beta]-pages"),
            "- [How to read \\[beta\\] pages](How-to-read-%5Bbeta%5D-pages)",
        )


class RenderListTest(unittest.TestCase):
    def test_keeps_the_given_order(self):
        self.assertEqual(
            index.render_list(["How-to-b", "How-to-a"]),
            "- [How to b](How-to-b)\n- [How to a](How-to-a)",
        )

    def test_says_so_when_there_are_no_pages(self):
        self.assertEqual(index.render_list([]), index.EMPTY_LIST)


class UpdateHomeTest(unittest.TestCase):
    def test_replaces_only_the_text_between_the_markers(self):
        home = f"Intro\n\n{START}\n- old\n{END}\n\nOutro\n"
        self.assertEqual(
            index.update_home(home, "- new"),
            f"Intro\n\n{START}\n- new\n{END}\n\nOutro\n",
        )

    def test_appends_a_section_when_home_has_no_markers(self):
        self.assertEqual(
            index.update_home("Welcome!\n", "- new"),
            f"Welcome!\n\n{index.SECTION_HEADING}\n\n{START}\n- new\n{END}\n",
        )

    def test_appends_to_an_empty_home(self):
        self.assertEqual(
            index.update_home("", "- new"),
            f"{index.SECTION_HEADING}\n\n{START}\n- new\n{END}\n",
        )

    def test_is_unchanged_when_the_list_is_current(self):
        home = f"Intro\n\n{START}\n- same\n{END}\n"
        self.assertEqual(index.update_home(home, "- same"), home)

    def test_refuses_a_start_marker_without_an_end_marker(self):
        with self.assertRaises(ValueError):
            index.update_home(f"Intro\n{START}\n- old\n", "- new")

    def test_refuses_markers_in_the_wrong_order(self):
        with self.assertRaises(ValueError):
            index.update_home(f"{END}\n- old\n{START}\n", "- new")


def _git(repo, *args, when=None):
    env = dict(os.environ)
    env.update(
        GIT_AUTHOR_NAME="Test",
        GIT_AUTHOR_EMAIL="test@example.com",
        GIT_COMMITTER_NAME="Test",
        GIT_COMMITTER_EMAIL="test@example.com",
    )
    if when is not None:
        stamp = f"{when} +0000"
        env.update(GIT_AUTHOR_DATE=stamp, GIT_COMMITTER_DATE=stamp)
    subprocess.run(
        ["git", "-C", repo, *args],
        check=True,
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def _add_page(repo, name, when, text="Some text.\n"):
    with open(os.path.join(repo, name), "w", encoding="utf-8") as handle:
        handle.write(text)
    _git(repo, "add", name)
    _git(repo, "commit", "-m", f"Add {name}", when=when)


class WikiRepoTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.repo = self._tmp.name
        _git(self.repo, "init", "-q")
        _add_page(self.repo, "Home.md", 1_700_000_000, "Welcome!\n")

    def test_lists_how_to_pages_newest_first(self):
        _add_page(self.repo, "How-to-old.md", 1_700_000_100)
        _add_page(self.repo, "Glossary.md", 1_700_000_200)
        _add_page(self.repo, "How-to-new.md", 1_700_000_300)
        self.assertEqual(
            index.howto_pages(self.repo),
            ["How-to-new", "How-to-old"],
        )

    def test_a_renamed_page_keeps_its_original_creation_date(self):
        _add_page(self.repo, "Tag-dives-with-rules.md", 1_700_000_100)
        _add_page(self.repo, "How-to-newer.md", 1_700_000_200)
        _git(
            self.repo,
            "mv",
            "Tag-dives-with-rules.md",
            "How-to-tag-dives-with-rules.md",
        )
        _git(self.repo, "commit", "-m", "Rename", when=1_700_000_300)
        self.assertEqual(
            index.howto_pages(self.repo),
            ["How-to-newer", "How-to-tag-dives-with-rules"],
        )

    def test_pages_created_together_sort_by_title(self):
        for name in ("How-to-b.md", "How-to-a.md"):
            with open(os.path.join(self.repo, name), "w", encoding="utf-8") as f:
                f.write("Text.\n")
        _git(self.repo, "add", "-A")
        _git(self.repo, "commit", "-m", "Add two", when=1_700_000_100)
        self.assertEqual(index.howto_pages(self.repo), ["How-to-a", "How-to-b"])

    def test_main_rewrites_home_and_reports_the_change(self):
        _add_page(self.repo, "How-to-start.md", 1_700_000_100)
        self.assertEqual(index.main([self.repo]), 0)
        with open(os.path.join(self.repo, "Home.md"), encoding="utf-8") as f:
            home = f.read()
        self.assertIn(f"{START}\n- [How to start](How-to-start)\n{END}", home)
        self.assertTrue(home.startswith("Welcome!\n"))

    def test_main_leaves_a_current_home_alone(self):
        _add_page(self.repo, "How-to-start.md", 1_700_000_100)
        index.main([self.repo])
        path = os.path.join(self.repo, "Home.md")
        before = os.stat(path).st_mtime_ns
        self.assertEqual(index.main([self.repo]), 0)
        self.assertEqual(os.stat(path).st_mtime_ns, before)

    def test_main_creates_home_when_the_wiki_has_none(self):
        os.remove(os.path.join(self.repo, "Home.md"))
        _add_page(self.repo, "How-to-start.md", 1_700_000_100)
        self.assertEqual(index.main([self.repo]), 0)
        with open(os.path.join(self.repo, "Home.md"), encoding="utf-8") as f:
            self.assertIn("- [How to start](How-to-start)", f.read())

    def test_main_fails_on_broken_markers_without_writing(self):
        path = os.path.join(self.repo, "Home.md")
        with open(path, "w", encoding="utf-8") as f:
            f.write(f"Intro\n{START}\n")
        self.assertEqual(index.main([self.repo]), 1)
        with open(path, encoding="utf-8") as f:
            self.assertEqual(f.read(), f"Intro\n{START}\n")

    def test_main_needs_exactly_one_argument(self):
        self.assertEqual(index.main([]), 2)


if __name__ == "__main__":
    unittest.main()
