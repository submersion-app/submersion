#!/usr/bin/env python3
"""Unit tests for sanitize_apple_store_notes.py."""

import glob
import importlib.util
import io
import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "sanitize_apple_store_notes",
    os.path.join(_HERE, "sanitize_apple_store_notes.py"),
)
san = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(san)

TERMS = san.load_terms()


def matched(text):
    """The matched substrings in text, in order."""
    return [text[s:e] for s, e, _cls in san.find_matches(text, TERMS)]


class TestDetection(unittest.TestCase):
    def test_detects_each_platform_name(self):
        self.assertEqual(matched("Broken on Windows."), ["Windows"])
        self.assertEqual(matched("Broken on Android."), ["Android"])
        self.assertEqual(matched("Broken on Linux."), ["Linux"])

    def test_platform_names_are_case_insensitive_except_windows(self):
        self.assertEqual(matched("broken on android"), ["android"])
        self.assertEqual(matched("broken on linux"), ["linux"])

    def test_distro_and_installer_names(self):
        self.assertEqual(matched("Install the Ubuntu build."), ["Ubuntu"])
        self.assertEqual(matched("Install the Debian build."), ["Debian"])
        self.assertEqual(matched("A Flatpak is provided."), ["Flatpak"])
        self.assertEqual(matched("An AppImage is provided."), ["AppImage"])
        self.assertEqual(matched("Run Submersion.exe now."), [".exe"])
        self.assertEqual(matched("Ships as an MSI package."), ["MSI"])

    def test_linux_distribution_names(self):
        for line, expected in [
            ("Built on Fedora.", "Fedora"),
            ("Built on Red Hat.", "Red Hat"),
            ("Built on RedHat.", "RedHat"),
            ("Built on RHEL.", "RHEL"),
            ("Built on CentOS.", "CentOS"),
            ("Built on AlmaLinux.", "AlmaLinux"),
            ("Built on openSUSE.", "openSUSE"),
            ("Built on SUSE.", "SUSE"),
            ("Built on Manjaro.", "Manjaro"),
            ("Built on Gentoo.", "Gentoo"),
            ("Built on Slackware.", "Slackware"),
            ("Built on NixOS.", "NixOS"),
            ("Built on SteamOS.", "SteamOS"),
            ("Built on Deepin.", "Deepin"),
            ("Built on Solus.", "Solus"),
            ("Built on EndeavourOS.", "EndeavourOS"),
            ("Built on Raspbian.", "Raspbian"),
            ("Built on Pop!_OS.", "Pop!_OS"),
            ("Built on elementary OS.", "elementary OS"),
            ("Built on Zorin OS.", "Zorin OS"),
            ("Built on Raspberry Pi OS.", "Raspberry Pi OS"),
        ]:
            with self.subTest(line=line):
                self.assertIn(expected, matched(line))

    def test_distro_names_containing_linux_are_consumed_whole(self):
        # These must be declared above the bare "\bLinux\b" entry. Declared
        # below it, the bare entry consumes the Linux half first and the rest
        # of the name is stranded in the output ("Arch other platforms") with
        # nothing to report it, because the stranded half is not itself a term.
        #
        # Asserted through replace_terms rather than find_matches: the
        # longest-spelling-wins rule is a property of the rewriting order, and
        # find_matches deliberately reports every overlapping hit.
        for line, expected in [
            ("Built on Arch Linux.", "Built on other platforms."),
            ("Built on Linux Mint.", "Built on other platforms."),
            ("Built on Rocky Linux.", "Built on other platforms."),
            ("Built on Alpine Linux.", "Built on other platforms."),
            ("Built on Kali Linux.", "Built on other platforms."),
            ("Built on Void Linux.", "Built on other platforms."),
            ("Built on MX Linux.", "Built on other platforms."),
            ("Built on Red Hat Enterprise Linux.",
             "Built on other platforms."),
        ]:
            with self.subTest(line=line):
                self.assertEqual(san.replace_terms(line, TERMS), expected)

    def test_declaration_order_puts_linux_compounds_before_bare_linux(self):
        # The structural form of the test above, so a term added in the wrong
        # place fails here even if nobody adds a sentence for it.
        patterns = [pattern.pattern for pattern, _cls in TERMS]
        bare = patterns.index(r"\bLinux\b")
        for position, pattern in enumerate(patterns):
            if pattern == r"\bLinux\b" or r"[ \t]+Linux\b" not in pattern:
                continue
            with self.subTest(pattern=pattern):
                self.assertLess(position, bare,
                                "declare this above the bare Linux term")

    def test_short_distro_names_are_case_sensitive(self):
        # Lowercase "arch" is the usual abbreviation for a CPU architecture and
        # "mint" is ordinary prose, so only the capitalised distro is a term.
        self.assertEqual(matched("Ships an Arch package."), ["Arch"])
        self.assertEqual(matched("Ships a Mint package."), ["Mint"])
        self.assertEqual(matched("covers both arch slices"), [])
        self.assertEqual(matched("a mint-condition regulator"), [])

    def test_ambiguous_short_names_need_their_linux_suffix(self):
        # Rocky, Alpine, Kali, Void and MX are plausible dive-site names and
        # ordinary prose, so they are only terms in their "<name> Linux" form.
        for line in [
            "Rocky Point is a new dive site.",
            "an alpine lake at altitude",
            "returns void when the handle is stale",
            "the MX series regulator",
        ]:
            with self.subTest(line=line):
                self.assertEqual(matched(line), [])

    def test_apt_only_matches_command_context(self):
        self.assertEqual(matched("Run sudo apt install tesseract-ocr"),
                         ["sudo apt install"])
        self.assertEqual(matched("That is an apt description."), [])

    def test_other_package_managers_and_formats(self):
        self.assertEqual(matched("Run sudo dnf install submersion"),
                         ["sudo dnf install"])
        self.assertEqual(matched("Run zypper install submersion"),
                         ["zypper install"])
        self.assertEqual(matched("Yum, that tastes good."), [])
        self.assertEqual(matched("Install with pacman."), ["pacman"])
        self.assertEqual(matched("Grab submersion.rpm now."), [".rpm"])
        self.assertEqual(matched("Grab submersion.deb now."), [".deb"])

    def test_microsoft_and_pc(self):
        self.assertEqual(matched("Your Mac or PC can browse them."), ["PC"])
        self.assertEqual(matched("Reads the Microsoft Store listing."),
                         ["Microsoft Store"])

    def test_store_class_terms(self):
        hits = san.find_matches("Available on Google Play Store today.", TERMS)
        self.assertTrue(hits)
        self.assertEqual({cls for _s, _e, cls in hits}, {"store"})

    def test_google_play_store_is_consumed_whole(self):
        # Declaration order matters: the longer spelling must win, or a stray
        # "Store" is left behind for the replacement pass to mangle.
        self.assertEqual(matched("On Google Play Store.")[0],
                         "Google Play Store")

    # --- The negative corpus: real sentences from docs/releases/ -------------

    def test_lowercase_window_prose_is_never_matched(self):
        for line in [
            "A two-column layout on wide windows for desktop and tablet.",
            "The planner gets the whole window.",
            "photos plainly inside the dive window were rejected",
            "falls only across the windows where it is",
            "on a window that was too narrow, zooming out can unlock it",
        ]:
            with self.subTest(line=line):
                self.assertEqual(matched(line), [])


class TestListRepair(unittest.TestCase):
    def repair(self, text):
        return san.repair_lists(text, TERMS)

    def test_four_members_one_survivor(self):
        self.assertEqual(
            self.repair("Downloads (macOS, Windows, Linux, and Android)"),
            "Downloads (macOS)",
        )

    def test_three_members_one_survivor(self):
        self.assertEqual(
            self.repair("shown on Mac, Windows, and Linux today"),
            "shown on Mac today",
        )

    def test_five_members_two_survivors_get_a_conjunction(self):
        self.assertEqual(
            self.repair("on iOS, Android, macOS, Windows, and Linux"),
            "on iOS and macOS",
        )

    def test_three_survivors_keep_the_oxford_comma(self):
        self.assertEqual(
            self.repair("on iOS, iPadOS, macOS, Windows, and Android"),
            "on iOS, iPadOS, and macOS",
        )

    def test_no_survivors_collapse_to_the_neutral_phrase(self):
        self.assertEqual(
            self.repair("broken on Windows, Linux, and Android"),
            "broken on other platforms",
        )

    def test_clean_list_is_untouched(self):
        text = "covers dives, dive sites, and gear"
        self.assertEqual(self.repair(text), text)

    def test_conjunction_is_not_parsed_as_a_member(self):
        # The clause after the list must survive: "and continues with the app"
        # is not part of the list and must not be rewritten away with it.
        self.assertEqual(
            self.repair(
                "Recording works on iPhone, iPad, and Android and continues "
                "with the app backgrounded"
            ),
            "Recording works on iPhone and iPad and continues "
            "with the app backgrounded",
        )

    def test_or_lists_are_handled(self):
        self.assertEqual(
            self.repair("use Windows or macOS"),
            "use macOS",
        )

    def test_leading_prose_is_not_absorbed_into_the_first_member(self):
        # The regression that multi-word members caused: the greedy first
        # member swallowed the words before the list ("broken on Windows"),
        # which is not entirely a banned term, so the platform name survived.
        self.assertEqual(
            self.repair("broken on Windows, Linux, and Android today"),
            "broken on other platforms today",
        )
        self.assertEqual(
            self.repair("a fix for Windows or Linux"),
            "a fix for other platforms",
        )

    def test_multi_word_terms_are_whole_list_members(self):
        # A member is one word or one whole banned term. Without the second
        # half, this list fails to match at "Rocky", matches from "Linux"
        # instead, and leaves "Rocky other platforms" behind - a stranded
        # distro name that the survivor check cannot see, because bare "Rocky"
        # is not itself a banned term.
        self.assertEqual(
            self.repair("Rocky Linux, AlmaLinux, and CentOS all work"),
            "other platforms all work",
        )
        self.assertEqual(
            self.repair("packages for Fedora, Red Hat, and Ubuntu today"),
            "packages for other platforms today",
        )
        self.assertEqual(
            self.repair("built on macOS, Arch Linux, and Windows"),
            "built on macOS",
        )

    def test_optional_suffix_is_taken_with_the_member(self):
        # "Zorin OS" must leave as one member. Dropping only "Zorin" would
        # strand its "OS" in the sentence.
        self.assertEqual(
            self.repair("openSUSE and Zorin OS packaging landed"),
            "other platforms packaging landed",
        )

    def test_multi_word_members_do_not_absorb_leading_prose(self):
        # The property the single-word rule existed to protect. A multi-word
        # branch can only match a banned term, so it can never start earlier
        # than one does.
        self.assertEqual(
            self.repair("also broken on Red Hat, Fedora, and Windows today"),
            "also broken on other platforms today",
        )
        self.assertEqual(
            self.repair("tested with Arch Linux and macOS"),
            "tested with macOS",
        )


class TestReplacement(unittest.TestCase):
    def replace(self, text):
        return san.replace_terms(text, TERMS)

    def test_default_replacement(self):
        self.assertEqual(
            self.replace("a crash specific to Android devices"),
            "a crash specific to other platforms devices",
        )

    def test_preposition_form_falls_out_of_the_default(self):
        self.assertEqual(
            self.replace("On Android this works through the USB Host API."),
            "On other platforms this works through the USB Host API.",
        )

    def test_possessive_does_not_leave_an_orphan_s(self):
        self.assertEqual(
            self.replace("reads Windows's certificate store"),
            "reads other platforms' certificate store",
        )
        self.assertEqual(
            self.replace("uses Android’s folder picker"),
            "uses other platforms’ folder picker",
        )

    def test_sentence_initial_is_capitalised(self):
        self.assertEqual(
            self.replace("Fixed a bug. Android backups now work."),
            "Fixed a bug. Other platforms backups now work.",
        )

    def test_line_initial_is_capitalised(self):
        self.assertEqual(
            self.replace("- Fixed a thing\nLinux users are unblocked"),
            "- Fixed a thing\nOther platforms users are unblocked",
        )

    def test_store_class_uses_its_own_phrase(self):
        self.assertEqual(
            self.replace("also on Google Play"),
            "also on another store",
        )


class TestTidy(unittest.TestCase):
    def test_collapses_adjacent_duplicate_phrases(self):
        self.assertEqual(
            san.tidy("broken on other platforms and other platforms today"),
            "broken on other platforms today",
        )

    def test_removes_emptied_parentheses(self):
        self.assertEqual(san.tidy("Downloads ( )"), "Downloads")

    def test_repairs_dangling_commas(self):
        self.assertEqual(san.tidy("Downloads (macOS, )"), "Downloads (macOS)")

    def test_collapses_runs_of_spaces(self):
        self.assertEqual(san.tidy("a  b"), "a b")

    def test_strips_trailing_whitespace_per_line(self):
        self.assertEqual(san.tidy("a  \nb"), "a\nb")


class TestSanitize(unittest.TestCase):
    def test_end_to_end(self):
        self.assertEqual(
            san.sanitize("### Downloads (macOS, Windows, Linux, and Android)"),
            "### Downloads (macOS)",
        )

    def test_normalises_crlf(self):
        self.assertEqual(san.sanitize("a\r\nb"), "a\nb")

    def test_is_idempotent(self):
        text = (
            "### USB-serial downloads (macOS, Windows, Linux, and Android)\n"
            "On Android this works through the USB Host API.\n"
            "- Videos showed a movie icon on Mac, Windows, and Linux.\n"
        )
        once = san.sanitize(text)
        self.assertEqual(san.sanitize(once), once)

    def test_line_count_is_preserved(self):
        # --report diffs the two texts line by line, which is only valid if no
        # pass ever inserts or removes a newline.
        text = "a\nBroken on Windows, Linux, and Android\nb\n"
        self.assertEqual(san.sanitize(text).count("\n"), text.count("\n"))

    def test_line_count_survives_constructs_wrapped_across_lines(self):
        # Every consuming pattern must use [ \t] rather than \s. Markdown prose
        # wraps, so a list, a two-word term, or an emptied parenthetical can
        # straddle a newline; a pattern matching \s swallows that newline and
        # joins the lines, which misaligns the --report diff and can merge two
        # beta note items into one.
        for name, text in [
            ("list wrapped mid-way",
             "Downloads work on macOS, Windows,\nLinux, and Android today.\n"),
            ("conjunction on the next line",
             "Runs on macOS, Windows\nand Linux.\n"),
            ("two-word term wrapped",
             "Also available on Google\nPlay now.\n"),
            ("Microsoft Store wrapped",
             "See the Microsoft\nStore listing.\n"),
            ("apt command wrapped",
             "Run sudo apt\ninstall tesseract-ocr first.\n"),
            ("parenthetical emptied after a newline",
             "Downloads\n(Windows, Linux, and Android)\nare available.\n"),
        ]:
            with self.subTest(name=name):
                self.assertEqual(
                    san.sanitize(text).count("\n"), text.count("\n"),
                    "a newline was consumed, joining two lines",
                )


class TestMain(unittest.TestCase):
    def run_main(self, stdin_text, argv):
        stdin, stdout, stderr = sys.stdin, sys.stdout, sys.stderr
        sys.stdin = io.StringIO(stdin_text)
        out, err = io.StringIO(), io.StringIO()
        sys.stdout, sys.stderr = out, err
        try:
            code = san.main(argv)
        finally:
            sys.stdin, sys.stdout, sys.stderr = stdin, stdout, stderr
        return code, out.getvalue(), err.getvalue()

    def test_clean_run(self):
        code, out, err = self.run_main("Broken on Android.\n", [])
        self.assertEqual(code, 0)
        self.assertEqual(out, "Broken on other platforms.\n")
        self.assertEqual(err, "")

    def test_report_goes_to_stderr_only(self):
        code, out, err = self.run_main("Broken on Android.\n", ["--report"])
        self.assertEqual(code, 0)
        self.assertEqual(out, "Broken on other platforms.\n")
        self.assertIn("Android", err)

    def test_empty_input_uses_the_fallback(self):
        code, out, _err = self.run_main("", ["--fallback", "Bug fixes."])
        self.assertEqual(code, 0)
        self.assertEqual(out, "Bug fixes.")

    def test_no_fallback_leaves_empty_empty(self):
        code, out, _err = self.run_main("   \n", [])
        self.assertEqual(code, 0)
        self.assertEqual(out, "")

    def test_warns_about_a_term_split_across_a_line_break(self):
        # The consuming patterns use [ \t] so they can never join two lines.
        # The blind spot that leaves is a multi-word term hard-wrapped across a
        # break. It warns rather than failing: the guard must not block a
        # release on wording, and no release body is hard-wrapped today.
        code, out, err = self.run_main("Also on Google\nPlay now.\n", [])
        self.assertEqual(code, 0)
        self.assertIn("Google", err)
        self.assertIn("line break", err)
        self.assertEqual(out, "Also on Google\nPlay now.\n")

    def test_no_wrap_warning_when_the_term_is_on_one_line(self):
        _code, _out, err = self.run_main("Also on Google Play now.\n", [])
        self.assertNotIn("line break", err)

    def test_survivor_exits_two(self):
        # Stub the rewriting passes so a term reaches the assert. This can only
        # happen through a bug in this script, which is what exit 2 reports.
        original = san.replace_terms
        san.replace_terms = lambda text, terms: text
        try:
            code, out, err = self.run_main("Broken on Android.\n", [])
        finally:
            san.replace_terms = original
        self.assertEqual(code, 2)
        self.assertEqual(out, "")
        self.assertIn("survived", err)


class TestStripAttribution(unittest.TestCase):
    """Contributor credits belong in the release body, not in store copy.

    The App Store "What's New" is derived from the published GitHub release
    body, so the @handles and #PR numbers the changelog adds arrive here. They
    mean nothing to a store reader, and an @handle is not a name.
    """

    def test_drops_handle_and_pr(self):
        self.assertEqual(
            san.strip_attribution("- fixed a thing by @octocat in #42")[0],
            "- fixed a thing",
        )

    def test_drops_handle_without_a_pr(self):
        self.assertEqual(
            san.strip_attribution("- fixed a thing by @octo-cat")[0],
            "- fixed a thing",
        )

    def test_leaves_ordinary_prose_alone(self):
        for line in (
            "Reported by a tester in the field.",
            "Sorted by depth, then by date.",
            "Fixes the crash described in #1182.",
        ):
            with self.subTest(line=line):
                self.assertEqual(san.strip_attribution(line)[0], line)

    def test_drops_the_new_contributors_section(self):
        body = (
            "### Bug Fixes\n"
            "\n"
            "- fixed a thing by @octocat in #42\n"
            "\n"
            "### New Contributors\n"
            "\n"
            "- @octocat made their first contribution in #42\n"
        )
        result, count = san.strip_attribution(body)
        self.assertNotIn("New Contributors", result)
        self.assertNotIn("@octocat", result)
        self.assertIn("- fixed a thing", result)
        self.assertEqual(count, 2)

    def test_a_later_section_survives_the_drop(self):
        body = (
            "### New Contributors\n"
            "\n"
            "- @octocat made their first contribution in #42\n"
            "\n"
            "## Upgrade notes\n"
            "\n"
            "- the schema is unchanged\n"
        )
        result, _count = san.strip_attribution(body)
        self.assertNotIn("@octocat", result)
        self.assertIn("the schema is unchanged", result)

    def test_end_to_end_through_main(self):
        body = "- fixed a thing on Windows by @octocat in #42\n"
        stdin, stdout = sys.stdin, sys.stdout
        sys.stdin, sys.stdout = io.StringIO(body), io.StringIO()
        try:
            code = san.main([])
            result = sys.stdout.getvalue()
        finally:
            sys.stdin, sys.stdout = stdin, stdout
        self.assertEqual(code, 0)
        self.assertNotIn("@octocat", result)
        self.assertNotIn("#42", result)
        self.assertNotIn("Windows", result)


class TestReleaseNotesCorpus(unittest.TestCase):
    """The real input distribution: every historical release announcement."""

    def test_every_release_note_sanitizes_clean(self):
        paths = sorted(glob.glob(
            os.path.join(_HERE, "..", "..", "docs", "releases", "*.md")
        ))
        self.assertTrue(paths, "no release notes found to check")
        for path in paths:
            with self.subTest(path=os.path.basename(path)):
                with open(path, encoding="utf-8") as fh:
                    text = fh.read()
                result = san.sanitize(text)
                leftovers = [result[s:e]
                             for s, e, _c in san.find_matches(result, TERMS)]
                self.assertEqual(leftovers, [])
                self.assertEqual(
                    result.count("\n"), text.count("\n"),
                    "sanitizing consumed a newline and joined two lines",
                )


if __name__ == "__main__":
    unittest.main()
