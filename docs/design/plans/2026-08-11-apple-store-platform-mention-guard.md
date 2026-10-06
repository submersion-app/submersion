# Apple App Store platform-mention guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Guarantee that Windows, Android, Linux, and their by-another-name variants never reach either of the two Apple App Store Connect note fields, without changing the multi-platform text those fields are derived from.

**Architecture:** A single pure-stdlib Python filter, `scripts/release/sanitize_apple_store_notes.py`, reads note text on stdin and writes redacted text on stdout. Its term list lives in a JSON file shared with a Ruby backstop in the two Apple Fastfiles, so the two implementations cannot drift. The filter is wired into the only two Apple-bound paths: `promote.yml`'s "Prepare What's New" step, and `beta_release_notes.sh`'s per-item section assembly. The misleadingly named `--format store` is hard-renamed to `--format apple` so the Apple-only gate reads correctly.

**Tech Stack:** Python 3 (stdlib only), Bash, Ruby (fastlane), GitHub Actions.

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-08-11-apple-store-platform-mention-guard-design.md`.
- **Stdout purity.** Every script in `scripts/release/` writes notes and only notes to stdout; all progress and diagnostics go to stderr. `generate_changelog.sh` previously violated this and embedded `Changelog: ...` lines in every published beta release body.
- **Pure stdlib.** No new Python or Ruby dependencies. `ci.yaml`'s `script-tests` job installs only `coverage`.
- **`Windows`, `PC`, and `Microsoft` are matched case-sensitively.** Across every file in `docs/releases/`, capitalized `Windows` is the operating system and lowercase `window`/`windows` is a UI window or a time window. Case-insensitive matching would corrupt real prose.
- **`APK` is deliberately not a banned term.**
- **Only Apple-bound text is sanitized.** `--format play`, `--format markdown`, the Sparkle appcast, `CHANGELOG.md`, and `docs/releases/*.md` must all pass through untouched.
- **Exit code 2 from the sanitizer is fatal and means a bug in the sanitizer**, never bad input. It fires only if a banned term survives every redaction pass.
- **No emojis** in code, comments, or documentation (project rule).
- Replacement phrases, exact: platform-class terms become `other platforms`; store-class terms become `another store`.
- Fallback text for the App Store path, exact: `This release includes bug fixes and improvements.`

---

## File Structure

| File | Responsibility |
| --- | --- |
| `scripts/release/apple_store_banned_terms.json` (create) | The single term list. Consumed by both the Python sanitizer and the Ruby backstop. |
| `scripts/release/sanitize_apple_store_notes.py` (create) | Detection, list repair, replacement, tidy, assert, fallback, CLI. |
| `scripts/release/sanitize_apple_store_notes_test.py` (create) | Unit tests plus the `docs/releases/` corpus test. |
| `scripts/release/beta_release_notes.sh` (modify) | `--format store` to `--format apple`; sanitize items in `add_section`. |
| `scripts/release/beta_release_notes_test.sh` (modify) | Rename call sites; add sanitization and format-rejection cases. |
| `.github/workflows/beta.yml` (modify) | Rename the format flag and the `beta-notes-store.txt` artifact file. |
| `.github/workflows/promote.yml` (modify) | Pipe the App Store What's New through the sanitizer. |
| `.github/workflows/ci.yaml` (modify) | Register the new Python test in `script-tests`. |
| `ios/fastlane/Fastfile`, `macos/fastlane/Fastfile` (modify) | Ruby backstop in `beta_changelog`. |
| `scripts/release/fastlane_beta_changelog_test.rb` (modify) | Fixture rename; backstop test. |

---

### Task 1: Term list and detection

The riskiest part of the whole change is deciding what counts as a match. Build and prove the detector before anything rewrites text.

**Files:**
- Create: `scripts/release/apple_store_banned_terms.json`
- Create: `scripts/release/sanitize_apple_store_notes.py`
- Test: `scripts/release/sanitize_apple_store_notes_test.py`

**Interfaces:**
- Consumes: nothing.
- Produces: `load_terms(path=TERMS_PATH) -> list[tuple[re.Pattern, str]]` in declaration order; `find_matches(text: str, terms) -> list[tuple[int, int, str]]` sorted by start offset, each tuple `(start, end, term_class)`; module constants `TERMS_PATH: str` and `REPLACEMENT: dict[str, str]`.

- [ ] **Step 1: Write the failing test**

Create `scripts/release/sanitize_apple_store_notes_test.py`:

```python
#!/usr/bin/env python3
"""Unit tests for sanitize_apple_store_notes.py."""

import importlib.util
import os
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

    def test_apt_only_matches_command_context(self):
        self.assertEqual(matched("Run sudo apt install tesseract-ocr"),
                         ["sudo apt install"])
        self.assertEqual(matched("That is an apt description."), [])

    def test_microsoft_and_pc(self):
        self.assertEqual(matched("Your Mac or PC can browse them."), ["PC"])
        self.assertEqual(matched("Reads the Microsoft Store listing."),
                         ["Microsoft Store"])

    def test_store_class_terms(self):
        hits = san.find_matches("Available on Google Play Store today.", TERMS)
        self.assertEqual([c for _s, _e, c in hits], ["store"])

    def test_google_play_store_is_consumed_whole(self):
        # Declaration order matters: the longer spelling must win, or a stray
        # "Store" is left behind for the replacement pass to mangle.
        self.assertEqual(matched("On Google Play Store."), ["Google Play Store"])

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


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python3 scripts/release/sanitize_apple_store_notes_test.py -v`

Expected: FAIL immediately at import with `FileNotFoundError` or `ModuleNotFoundError`, because `sanitize_apple_store_notes.py` does not exist yet.

- [ ] **Step 3: Create the term list**

Create `scripts/release/apple_store_banned_terms.json`.

Note on escaping: JSON `\b` is a backspace character, so every regex word boundary must be written `\\b` in this file. It decodes to `\b` for both Python's `re` and Ruby's `Regexp`.

```json
{
  "_comment": [
    "Terms that must never reach an Apple App Store Connect note field",
    "(App Review guideline 2.3.10). Consumed by",
    "sanitize_apple_store_notes.py and by the beta_changelog backstop in",
    "ios/fastlane/Fastfile and macos/fastlane/Fastfile, so the two can never",
    "drift apart.",
    "Order is significant: the longest spelling of an overlapping pair is",
    "declared first, so 'Google Play Store' is consumed whole rather than",
    "leaving a stray 'Store' behind.",
    "Windows, PC and Microsoft are case-sensitive on purpose. Across every",
    "file in docs/releases/, capitalised Windows is the operating system and",
    "lowercase window/windows is a UI window or a time window.",
    "Patterns use only the regex subset common to Python re and Ruby Regexp:",
    "\\b boundaries and (?: ) non-capturing groups. No named groups, no",
    "lookbehind."
  ],
  "terms": [
    { "pattern": "\\bWindows\\b", "ignorecase": false, "class": "platform" },
    { "pattern": "\\bPCs?\\b", "ignorecase": false, "class": "platform" },
    { "pattern": "\\bMicrosoft(?:\\s+Store)?\\b", "ignorecase": false, "class": "platform" },
    { "pattern": "\\bMSI\\b", "ignorecase": false, "class": "platform" },
    { "pattern": "\\.exe\\b", "ignorecase": true, "class": "platform" },
    { "pattern": "\\.msi\\b", "ignorecase": true, "class": "platform" },
    { "pattern": "\\bAndroid\\b", "ignorecase": true, "class": "platform" },
    { "pattern": "\\bLinux\\b", "ignorecase": true, "class": "platform" },
    { "pattern": "\\bUbuntu\\b", "ignorecase": true, "class": "platform" },
    { "pattern": "\\bDebian\\b", "ignorecase": true, "class": "platform" },
    { "pattern": "\\bFlatpak\\b", "ignorecase": true, "class": "platform" },
    { "pattern": "\\bAppImage\\b", "ignorecase": true, "class": "platform" },
    { "pattern": "\\b(?:sudo\\s+)?apt(?:-get)?\\s+(?:install|update|upgrade)\\b", "ignorecase": true, "class": "platform" },
    { "pattern": "\\bGoogle\\s+Play(?:\\s+Store)?\\b", "ignorecase": true, "class": "store" },
    { "pattern": "\\bPlay\\s+Store\\b", "ignorecase": true, "class": "store" }
  ]
}
```

- [ ] **Step 4: Write the detection half of the sanitizer**

Create `scripts/release/sanitize_apple_store_notes.py`:

```python
#!/usr/bin/env python3
"""Strip non-Apple platform references out of App Store Connect note fields.

App Review guideline 2.3.10 forbids referring to other platforms in App Store
metadata, but the text both Apple-bound note fields are generated from is
multi-platform by nature. The App Store "What's New" comes from the GitHub
release body, written for every platform at once, and the TestFlight "What to
Test" comes from PR titles that carry scopes like `fix(android):`. Every file
in docs/releases/ contains at least one banned term.

This rewrites that text rather than rejecting it, so a release is never blocked
on wording. Redaction is word-level: platform names are dropped out of lists
("macOS, Windows, Linux, and Android" becomes "macOS") and otherwise replaced
with a neutral phrase. The accepted trade-off is that a clause written about
one platform can survive as a non-sequitur.

Only Apple-bound text passes through here. Google Play notes, the GitHub
release body, the Sparkle appcast and docs/releases/*.md keep every platform
name.

Usage: sanitize_apple_store_notes.py [--fallback TEXT] [--report] < in > out

Diagnostics go to stderr; stdout is only ever the sanitized text. Exit 2 means
a banned term survived every pass, which is a bug in this script rather than a
problem with the input. Pure stdlib.
"""

import argparse
import json
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
TERMS_PATH = os.path.join(_HERE, "apple_store_banned_terms.json")

REPLACEMENT = {"platform": "other platforms", "store": "another store"}


def load_terms(path=TERMS_PATH):
    """Return [(compiled_pattern, term_class)] in declaration order.

    Declaration order is preserved and significant; see the note in the JSON.
    """
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    terms = []
    for term in data["terms"]:
        flags = re.IGNORECASE if term["ignorecase"] else 0
        terms.append((re.compile(term["pattern"], flags), term["class"]))
    return terms


def find_matches(text, terms):
    """Return [(start, end, term_class)] for every banned term, by position.

    Overlapping hits from different patterns are all reported; callers use
    this for detection and reporting, never for rewriting.
    """
    hits = []
    for pattern, term_class in terms:
        for match in pattern.finditer(text):
            hits.append((match.start(), match.end(), term_class))
    return sorted(hits)
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `python3 scripts/release/sanitize_apple_store_notes_test.py -v`

Expected: PASS, 9 tests.

If `test_google_play_store_is_consumed_whole` fails with `['Google Play', 'Play Store']`, the sorted output is reporting both overlapping patterns. That is correct behavior for `find_matches`; fix the test to assert `matched(...)[0] == "Google Play Store"` rather than reordering the term list.

- [ ] **Step 6: Commit**

```bash
git add scripts/release/apple_store_banned_terms.json \
        scripts/release/sanitize_apple_store_notes.py \
        scripts/release/sanitize_apple_store_notes_test.py
git commit -m "feat(release): detect non-Apple platform terms in store notes

Term list plus detection only, no rewriting yet. Windows, PC and Microsoft
match case-sensitively so the lowercase 'window'/'windows' that appears
throughout docs/releases/ is never touched."
```

---

### Task 2: List repair

**Files:**
- Modify: `scripts/release/sanitize_apple_store_notes.py`
- Test: `scripts/release/sanitize_apple_store_notes_test.py`

**Interfaces:**
- Consumes: `load_terms`, `REPLACEMENT` from Task 1.
- Produces: `repair_lists(text: str, terms) -> str`.

- [ ] **Step 1: Write the failing test**

Append to `scripts/release/sanitize_apple_store_notes_test.py`, before the `if __name__` block:

```python
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python3 scripts/release/sanitize_apple_store_notes_test.py TestListRepair -v`

Expected: FAIL, all 8 tests error with `AttributeError: module 'sanitize_apple_store_notes' has no attribute 'repair_lists'`.

- [ ] **Step 3: Implement list repair**

Append to `scripts/release/sanitize_apple_store_notes.py` after `find_matches`:

```python
# A list member is exactly one word. Allowing multi-word members looks more
# general but is actively wrong: the leading member is greedy, so
# "broken on Windows, Linux, and Android" would parse its first member as
# "broken on Windows", which is not *entirely* a banned term, and the platform
# name would survive. Real platform lists are single tokens (macOS, Windows,
# iOS, Android). The one multi-word banned term that shows up in a list,
# "Google Play", is left to the replacement pass instead.
#
# The negative lookahead stops "and"/"or" being parsed as a member.
_WORD = r"(?!(?:and|or)\b)[A-Za-z0-9][A-Za-z0-9.+/-]*"
_MEMBER = _WORD

_LIST_RE = re.compile(
    r"\b" + _MEMBER +
    r"(?:\s*,\s*" + _MEMBER + r")*"
    r"\s*,?\s+(?:and|or)\s+" + _MEMBER + r"\b"
)

_SPLIT_RE = re.compile(r"\s*,\s*|\s*,?\s+(?:and|or)\s+")


def _is_banned_member(member, terms):
    """True when the member is *entirely* one banned term.

    A member that merely contains a banned term is left for the replacement
    pass; dropping it would delete real content alongside the platform name.
    """
    stripped = member.strip()
    return any(pattern.fullmatch(stripped) for pattern, _cls in terms)


def _join(members):
    """Rebuild a list with the Oxford comma the surrounding prose uses."""
    if len(members) >= 3:
        return ", ".join(members[:-1]) + ", and " + members[-1]
    if len(members) == 2:
        return members[0] + " and " + members[1]
    return members[0]


def repair_lists(text, terms):
    """Drop banned members from comma/conjunction lists, repairing punctuation.

    "(macOS, Windows, Linux, and Android)" becomes "(macOS)". A list whose
    members are all banned collapses to the neutral phrase, and the tidy pass
    removes the parentheses that are left empty around it.
    """
    def substitute(match):
        raw = match.group(0)
        members = [m for m in _SPLIT_RE.split(raw) if m]
        if not any(_is_banned_member(m, terms) for m in members):
            return raw
        kept = [m for m in members if not _is_banned_member(m, terms)]
        if not kept:
            return REPLACEMENT["platform"]
        return _join(kept)

    return _LIST_RE.sub(substitute, text)
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `python3 scripts/release/sanitize_apple_store_notes_test.py -v`

Expected: PASS, 17 tests.

- [ ] **Step 5: Commit**

```bash
git add scripts/release/sanitize_apple_store_notes.py \
        scripts/release/sanitize_apple_store_notes_test.py
git commit -m "feat(release): repair platform lists in Apple store notes

Drops banned members from comma/conjunction lists and rebuilds the
punctuation, so '(macOS, Windows, Linux, and Android)' reads '(macOS)'
rather than losing the whole parenthetical."
```

---

### Task 3: Replacement and tidy

**Files:**
- Modify: `scripts/release/sanitize_apple_store_notes.py`
- Test: `scripts/release/sanitize_apple_store_notes_test.py`

**Interfaces:**
- Consumes: `load_terms`, `REPLACEMENT` from Task 1.
- Produces: `replace_terms(text: str, terms) -> str`; `tidy(text: str) -> str`.

Note on the design: the spec lists a preposition-aware rule (`on <Term>` becomes `on other platforms`). No special case is needed for it. The preposition is never part of the match, so replacing the term in place already produces exactly that text. The rule collapses into the default. The test for it is kept because the behavior was specified.

- [ ] **Step 1: Write the failing test**

Append to `scripts/release/sanitize_apple_store_notes_test.py`, before the `if __name__` block:

```python
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python3 scripts/release/sanitize_apple_store_notes_test.py TestReplacement TestTidy -v`

Expected: FAIL, 11 tests error with `AttributeError: ... has no attribute 'replace_terms'`.

- [ ] **Step 3: Implement replacement and tidy**

Append to `scripts/release/sanitize_apple_store_notes.py` after `repair_lists`:

```python
# A sentence or line boundary immediately before the match position.
_SENTENCE_START_RE = re.compile(r"(?:\A|[.!?:]\s+|\n)\s*\Z")

# Straight and typographic apostrophes both appear in hand-written notes.
_POSSESSIVE = r"['’]s\b"


def replace_terms(text, terms):
    """Replace every surviving banned term with its neutral phrase.

    The possessive form is handled first so the general pass never leaves an
    orphaned "'s" behind: "Android's" must become "other platforms'", not
    "other platforms''s".

    No preposition special case is needed. The preposition is not part of the
    match, so "on Android" becomes "on other platforms" through the default
    path.
    """
    for pattern, term_class in terms:
        phrase = REPLACEMENT[term_class]

        # Possessive first. The apostrophe style of the source is preserved.
        text = re.sub(
            pattern.pattern + r"(['’])s\b",
            lambda m, phrase=phrase: phrase + m.group(1),
            text,
            flags=pattern.flags,
        )

        current = text

        def substitute(match, phrase=phrase, current=current):
            head = current[:match.start()]
            if _SENTENCE_START_RE.search(head):
                return phrase[0].upper() + phrase[1:]
            return phrase

        text = pattern.sub(substitute, text)

    return text


_TIDY = [
    # Two adjacent platform names both replaced in place read as a stutter.
    (re.compile(r"\bother platforms(?:,?\s+(?:and|or)\s+other platforms)+\b"),
     "other platforms"),
    (re.compile(r"\banother store(?:,?\s+(?:and|or)\s+another store)+\b"),
     "another store"),
    # A parenthetical emptied by list repair, and the space that preceded it.
    (re.compile(r"\s*\(\s*\)"), ""),
    (re.compile(r"\s*\[\s*\]"), ""),
    (re.compile(r",\s*\)"), ")"),
    (re.compile(r"\(\s*,\s*"), "("),
    (re.compile(r"[ \t]+,"), ","),
    (re.compile(r"[ \t]{2,}"), " "),
    (re.compile(r"[ \t]+$", re.MULTILINE), ""),
]


def tidy(text):
    """Repair the punctuation and spacing the earlier passes disturb."""
    for pattern, replacement in _TIDY:
        text = pattern.sub(replacement, text)
    return text
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `python3 scripts/release/sanitize_apple_store_notes_test.py -v`

Expected: PASS, 28 tests.

If `test_possessive_does_not_leave_an_orphan_s` fails for `Windows's`, check that `pattern.pattern` (`\bWindows\b`) followed by `(['’])s\b` still matches: the `\b` between `s` and `'` is a real boundary, so the concatenation is valid.

- [ ] **Step 5: Commit**

```bash
git add scripts/release/sanitize_apple_store_notes.py \
        scripts/release/sanitize_apple_store_notes_test.py
git commit -m "feat(release): replace surviving platform terms and tidy up

Possessives are rewritten before the general pass so no orphaned \"'s\"
is left behind, and sentence-initial matches keep their capital."
```

---

### Task 4: CLI, assert, fallback, and the corpus test

**Files:**
- Modify: `scripts/release/sanitize_apple_store_notes.py`
- Modify: `.github/workflows/ci.yaml:369-383`
- Test: `scripts/release/sanitize_apple_store_notes_test.py`

**Interfaces:**
- Consumes: everything from Tasks 1 to 3.
- Produces: `sanitize(text: str, terms=None) -> str`; `main(argv=None) -> int` (0 clean, 2 a banned term survived). Executable at `scripts/release/sanitize_apple_store_notes.py`, reading stdin and writing stdout.

- [ ] **Step 1: Write the failing test**

Append to `scripts/release/sanitize_apple_store_notes_test.py`, before the `if __name__` block:

```python
import glob
import io


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
        self.assertEqual(
            san.sanitize(text).count("\n"), text.count("\n")
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
```

Add `import sys` to the import block at the top of the test file.

- [ ] **Step 2: Run the test to verify it fails**

Run: `python3 scripts/release/sanitize_apple_store_notes_test.py TestSanitize TestMain TestReleaseNotesCorpus -v`

Expected: FAIL with `AttributeError: ... has no attribute 'sanitize'`.

- [ ] **Step 3: Implement the pipeline and CLI**

Append to `scripts/release/sanitize_apple_store_notes.py`:

```python
def sanitize(text, terms=None):
    """Run every pass. The result may be empty; the caller supplies a fallback.

    No pass inserts or removes a newline, so the output has the same number of
    lines as the input. --report relies on that to diff them line by line.
    """
    terms = load_terms() if terms is None else terms
    text = text.replace("\r\n", "\n")
    text = repair_lists(text, terms)
    text = replace_terms(text, terms)
    return tidy(text)


def _report(original, result, terms):
    """Describe what was redacted, on stderr.

    The guard never blocks on content, so a CI log is the only place a human
    can see what was silently changed.
    """
    hits = find_matches(original, terms)
    if not hits:
        print("sanitize_apple_store_notes: no banned terms found",
              file=sys.stderr)
        return
    found = sorted({original[start:end] for start, end, _cls in hits})
    print(
        "sanitize_apple_store_notes: redacted %d occurrence(s) of: %s"
        % (len(hits), ", ".join(found)),
        file=sys.stderr,
    )
    for number, (before, after) in enumerate(
        zip(original.split("\n"), result.split("\n")), start=1
    ):
        if before != after:
            print("  line %d:" % number, file=sys.stderr)
            print("    - %s" % before, file=sys.stderr)
            print("    + %s" % after, file=sys.stderr)


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Strip non-Apple platform references from store notes.",
    )
    parser.add_argument(
        "--fallback", default="",
        help="text to emit when the input sanitizes away to nothing",
    )
    parser.add_argument(
        "--report", action="store_true",
        help="describe every redaction on stderr",
    )
    args = parser.parse_args(argv)

    terms = load_terms()
    original = sys.stdin.read()
    result = sanitize(original, terms)

    if args.report:
        _report(original, result, terms)

    leftovers = find_matches(result, terms)
    if leftovers:
        for start, end, _cls in leftovers:
            print(
                "sanitize_apple_store_notes: BUG: %r survived every pass"
                % result[start:end],
                file=sys.stderr,
            )
        return 2

    if not result.strip():
        result = args.fallback

    sys.stdout.write(result)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Make it executable and run the tests**

```bash
chmod +x scripts/release/sanitize_apple_store_notes.py
python3 scripts/release/sanitize_apple_store_notes_test.py -v
```

Expected: PASS, all tests including one subtest per file in `docs/releases/`.

The corpus test is the one most likely to fail on the first run, because it is the only test using real input. If a term survives, read the reported substring and its line: the fix is almost always a list shape `_LIST_RE` does not cover, in which case the replacement pass should have caught it, so the real bug is in `replace_terms`.

- [ ] **Step 5: Verify the script works as a filter from the shell**

```bash
printf '### Downloads (macOS, Windows, Linux, and Android)\nOn Android this works.\n' \
  | ./scripts/release/sanitize_apple_store_notes.py --report
```

Expected on stdout:
```
### Downloads (macOS)
On other platforms this works.
```
Expected on stderr: a `redacted 3 occurrence(s) of: Android, Linux, Windows` line and two line diffs.

- [ ] **Step 6: Register the test in CI**

In `.github/workflows/ci.yaml`, in the `script-tests` job, extend the existing "Run Python guard tests with coverage" step (currently at lines 369-383) to include the new module and test. Change the `guards=` assignment and add one `coverage run --append` invocation:

```yaml
      - name: Run Python guard tests with coverage
        run: |
          mkdir -p coverage
          guards='scripts/check_proguard_serial_keep.py,scripts/check_native_libs_present.py,scripts/check_jni_local_refs.py,scripts/check_dc_process_isolation.py,scripts/release/sanitize_apple_store_notes.py'
          python3 -m coverage run --include="$guards" \
            scripts/check_proguard_serial_keep_test.py
          python3 -m coverage run --append --include="$guards" \
            scripts/check_native_libs_present_test.py
          python3 -m coverage run --append --include="$guards" \
            scripts/check_jni_local_refs_test.py
          python3 -m coverage run --append --include="$guards" \
            scripts/check_dc_process_isolation_test.py
          python3 -m coverage run --append --include="$guards" \
            scripts/release/sanitize_apple_store_notes_test.py
          python3 -m coverage report -m --include="$guards"
          python3 -m coverage xml --include="$guards" \
            -o coverage/scripts.xml
```

- [ ] **Step 7: Commit**

```bash
git add scripts/release/sanitize_apple_store_notes.py \
        scripts/release/sanitize_apple_store_notes_test.py \
        .github/workflows/ci.yaml
git commit -m "feat(release): finish the Apple store notes sanitizer CLI

Adds the pipeline, the --report stderr diff, the empty-input fallback and
the exit-2 assert that fires only on a sanitizer bug. The corpus test runs
every docs/releases/*.md through it and asserts nothing survives."
```

---

### Task 5: Rename `--format store` to `--format apple`

A hard rename with no alias. `beta-notes-store.txt` is uploaded and downloaded across `beta.yml` jobs by name, so every reference must move together.

**Files:**
- Modify: `scripts/release/beta_release_notes.sh:15-17, 23, 36, 77-79, 307, 309`
- Modify: `.github/workflows/beta.yml:132-133, 139, 147, 322, 388`
- Modify: `scripts/release/beta_release_notes_test.sh` (16 call sites plus the workflow-wiring loop)
- Modify: `scripts/release/fastlane_beta_changelog_test.rb:96`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `beta_release_notes.sh --format apple`; artifact file `beta-notes-apple.txt`.

- [ ] **Step 1: Write the failing test**

In `scripts/release/beta_release_notes_test.sh`, append before the final `echo "PASS: ..."` line:

```bash
# --- The Apple format is named for its destination ---------------------------
# "store" was ambiguous: Google Play is a store too, and the file it produces
# feeds only the iOS and macOS TestFlight jobs. The rename is hard, so a stale
# --format store invocation must fail loudly rather than silently do nothing.

if printf '%s\n' 'feat: something' | "$GEN" --stdin --format store >/dev/null 2>&1; then
  fail "--format store was accepted; the rename to --format apple is incomplete"
fi

OUT=$(printf '%s\n' 'feat: something real' | "$GEN" --stdin --format apple)
echo "$OUT" | grep -q "something real" || fail "--format apple produced no items"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `./scripts/release/beta_release_notes_test.sh`

Expected: FAIL with `FAIL: --format store was accepted; the rename to --format apple is incomplete`.

- [ ] **Step 3: Rename in the generator**

In `scripts/release/beta_release_notes.sh`:

Line 15, in the usage block, change `--format store` to `--format apple`.

Lines 22-25, the Formats block, replace the `store` line:

```
# Formats:
#   apple     TestFlight whatsNew and App Store What's New (plain text, 4000
#             chars). The only format that reaches Apple, and the only one
#             that has non-Apple platform names stripped out of it.
#   play      Play release notes (plain text, 500 chars)
#   markdown  GitHub beta release body (uncapped, keeps internal work)
```

Line 36, rename the constant:

```bash
APPLE_LIMIT=4000
```

Lines 76-80, the format validation:

```bash
case "$FORMAT" in
  apple|play|markdown) ;;
  "") die "--format is required (apple, play, or markdown)" ;;
  *)  die "unknown --format: $FORMAT (expected apple, play, or markdown)" ;;
esac
```

Line 307, the section comment:

```bash
# --- Capped formats: plain text within a hard character budget --------------
```

Line 309, the limit selection:

```bash
if [ "$FORMAT" = play ]; then LIMIT=$PLAY_LIMIT; else LIMIT=$APPLE_LIMIT; fi
```

- [ ] **Step 4: Rename the remaining call sites**

```bash
sed -i '' 's/--format store/--format apple/g' scripts/release/beta_release_notes_test.sh
sed -i '' 's/for fmt in store play markdown/for fmt in apple play markdown/' scripts/release/beta_release_notes_test.sh
sed -i '' 's/--format store/--format apple/g; s/beta-notes-store\.txt/beta-notes-apple.txt/g' .github/workflows/beta.yml
sed -i '' 's/beta-notes-store\.txt/beta-notes-apple.txt/g' scripts/release/fastlane_beta_changelog_test.rb
```

Then confirm nothing was missed:

```bash
grep -rn -- "--format store\|beta-notes-store" scripts/release/ .github/workflows/
```

Expected: no output.

- [ ] **Step 5: Run the tests to verify they pass**

```bash
./scripts/release/beta_release_notes_test.sh
ruby scripts/release/fastlane_beta_changelog_test.rb
```

Expected: `PASS: all beta_release_notes tests passed`, and the Ruby suite passing.

- [ ] **Step 6: Commit**

```bash
git add scripts/release/beta_release_notes.sh \
        scripts/release/beta_release_notes_test.sh \
        scripts/release/fastlane_beta_changelog_test.rb \
        .github/workflows/beta.yml
git commit -m "refactor(release): rename --format store to --format apple

The file it produces feeds only the iOS and macOS TestFlight jobs; Google
Play reads beta-notes-play.txt and the GitHub release reads beta-notes.md.
Calling it 'store' invited sanitizing the Play notes too. Hard rename, no
alias: a stale --format store now fails loudly."
```

---

### Task 6: Sanitize the TestFlight notes

**Files:**
- Modify: `scripts/release/beta_release_notes.sh:316-325` (`add_section`) and the header block
- Test: `scripts/release/beta_release_notes_test.sh`

**Interfaces:**
- Consumes: `scripts/release/sanitize_apple_store_notes.py` from Task 4; `--format apple` from Task 5.
- Produces: no new interface. `--format apple` output is sanitized; `play` and `markdown` are not.

- [ ] **Step 1: Write the failing test**

In `scripts/release/beta_release_notes_test.sh`, append before the final `echo "PASS: ..."` line:

```bash
# --- Only the Apple format is sanitized --------------------------------------
# Apple bans references to other platforms in App Store metadata (guideline
# 2.3.10) and PR titles name them constantly. Google Play must NOT be
# sanitized: Android is not a banned word there.

PLATFORM_SUBJECTS=$(printf '%s\n' \
  'fix(android): stop the USB download crashing' \
  'feat: read the Windows certificate store' \
  'fix: parse raw data on Linux')

OUT=$(printf '%s\n' "$PLATFORM_SUBJECTS" | "$GEN" --stdin --format apple)
echo "$OUT" | grep -qi "android" && fail "Android reached the Apple notes"
echo "$OUT" | grep -q "Windows" && fail "Windows reached the Apple notes"
echo "$OUT" | grep -qi "linux" && fail "Linux reached the Apple notes"
echo "$OUT" | grep -q "stop the USB download crashing" \
  || fail "sanitizing dropped the rest of the item"

OUT=$(printf '%s\n' "$PLATFORM_SUBJECTS" | "$GEN" --stdin --format play)
echo "$OUT" | grep -q "Windows" || fail "play notes were sanitized; they must not be"

OUT=$(printf '%s\n' "$PLATFORM_SUBJECTS" | "$GEN" --stdin --format markdown)
echo "$OUT" | grep -q "Windows" || fail "markdown notes were sanitized; they must not be"

# An item that is nothing but a platform name leaves no bare heading behind,
# and the script's existing empty-body fallback takes over.
OUT=$(printf '%s\n' 'feat: Android' | "$GEN" --stdin --format apple)
echo "$OUT" | grep -q "New in this build" \
  && fail "a heading survived after its only item sanitized away"
echo "$OUT" | grep -q "no new changes were recorded" \
  || fail "the empty-body fallback did not fire after every item sanitized away"
[ -n "$OUT" ] || fail "Apple notes came out empty; a tester reads that as 'the previous build's notes still apply'"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `./scripts/release/beta_release_notes_test.sh`

Expected: FAIL with `FAIL: Android reached the Apple notes`.

- [ ] **Step 3: Add SCRIPT_DIR and sanitize in add_section**

`beta_release_notes.sh` has never called a sibling script and has no `SCRIPT_DIR`. Add one immediately after the `set -euo pipefail` line (line 33):

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANITIZE="$SCRIPT_DIR/sanitize_apple_store_notes.py"
```

Then replace `add_section` (lines 316-325) with:

```bash
add_section() {
  items="$2"

  # Apple bans references to other platforms in App Store metadata (App Review
  # guideline 2.3.10), and PR titles name them constantly. `apple` is the only
  # format that reaches Apple; `play` must NOT be sanitized, because Android is
  # not a banned word on Google Play, and `markdown` keeps everything for the
  # GitHub release body.
  #
  # This runs per item rather than over the finished body because the body is
  # assembled item by item and then truncated against a hard character budget:
  # sanitizing afterwards would invalidate that arithmetic and could re-orphan
  # a heading. An item left empty, or reduced to the replacement phrase alone,
  # is dropped so the heading above it is not left bare.
  if [ "$FORMAT" = apple ] && [ -n "$items" ]; then
    items=$(printf '%s\n' "$items" | "$SANITIZE" \
      | sed -e '/^[[:space:]]*$/d' \
            -e '/^[[:space:]]*\(other platforms\|another store\)[[:space:]]*$/d')
  fi

  [ -n "$items" ] || return 0
  [ -n "$LINES" ] && add "H:"
  add "H:$1"
  while IFS= read -r item; do
    [ -n "$item" ] && add "I:- $item"
  done <<EOF
$items
EOF
}
```

Two things to preserve: the emptiness guard now tests `$items` rather than `$2`, so it sees the post-sanitization list; and the heredoc feeds `$items`, not `$2`.

The sanitizer exits 2 on its own bug. Under `set -euo pipefail` that aborts the generator, which is the intended fatal behavior.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `./scripts/release/beta_release_notes_test.sh`

Expected: `PASS: all beta_release_notes tests passed`.

If the last case fails because a heading survived, check that `[ -n "$items" ] || return 0` was moved *below* the sanitization block rather than left at the top of the function.

- [ ] **Step 5: Commit**

```bash
git add scripts/release/beta_release_notes.sh \
        scripts/release/beta_release_notes_test.sh
git commit -m "feat(release): sanitize the TestFlight notes, not the Play notes

Runs per item inside add_section, before the character budget is computed,
so truncation arithmetic and the dangling-heading repair both still hold."
```

---

### Task 7: Sanitize the App Store What's New

**Files:**
- Modify: `.github/workflows/promote.yml:263-282`

**Interfaces:**
- Consumes: `scripts/release/sanitize_apple_store_notes.py` from Task 4.
- Produces: no new interface.

- [ ] **Step 1: Verify the current behavior by hand**

The step has no unit test; the check is a local dry run of the exact pipeline against a real release body.

```bash
gh release view v1.7.1.118 --repo submersion-app/submersion --json body -q .body \
  | grep -c 'Windows\|Android\|Linux'
```

Expected: a non-zero count, confirming the current pipeline would ship banned terms.

- [ ] **Step 2: Rewrite the step**

Replace lines 263-282 of `.github/workflows/promote.yml` with:

```yaml
      - name: Prepare What's New from the release notes
        env:
          GH_TOKEN: ${{ github.token }}
          TAG_NAME: ${{ needs.promote.outputs.tag }}
        run: |
          set -euo pipefail
          # Apple requires whatsNew on a new App Store version; deliver reads
          # it from metadata/en-US/release_notes.txt (the only metadata file
          # we provide, so nothing else is touched).
          #
          # The GitHub release body is written for every platform at once, and
          # App Review guideline 2.3.10 forbids naming other platforms in App
          # Store metadata, so it is sanitized first. --report puts every
          # redaction in this job's log, which is the only place a human can
          # see what was silently changed. CRLF normalization happens inside
          # the sanitizer. Truncated afterwards, in CHARACTERS (not bytes,
          # which could split a multi-byte UTF-8 sequence and produce invalid
          # text) below Apple's 4000-char limit.
          mkdir -p ios/fastlane/metadata/en-US macos/fastlane/metadata/en-US
          gh release view "$TAG_NAME" --repo ${{ github.repository }} \
            --json body -q .body \
            | ./scripts/release/sanitize_apple_store_notes.py --report \
                --fallback 'This release includes bug fixes and improvements.' \
            | python3 -c 'import sys; sys.stdout.write(sys.stdin.read()[:3900])' \
            > ios/fastlane/metadata/en-US/release_notes.txt
          cp ios/fastlane/metadata/en-US/release_notes.txt \
            macos/fastlane/metadata/en-US/release_notes.txt
          test -s ios/fastlane/metadata/en-US/release_notes.txt
```

- [ ] **Step 3: Dry-run the new pipeline locally**

```bash
gh release view v1.7.1.118 --repo submersion-app/submersion --json body -q .body \
  | ./scripts/release/sanitize_apple_store_notes.py --report \
      --fallback 'This release includes bug fixes and improvements.' \
  | python3 -c 'import sys; sys.stdout.write(sys.stdin.read()[:3900])' \
  > /tmp/whats-new.txt
grep -c 'Windows\|Android\|Linux' /tmp/whats-new.txt || echo "clean"
test -s /tmp/whats-new.txt && echo "non-empty"
```

Expected: `clean` and `non-empty`. Read `/tmp/whats-new.txt` and confirm it is coherent English before committing.

- [ ] **Step 4: Validate the workflow file parses**

```bash
python3 -c "import sys,json; print('yaml ok')" && \
  ruby -ryaml -e "YAML.load_file('.github/workflows/promote.yml'); puts 'yaml ok'"
```

Expected: `yaml ok`.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/promote.yml
git commit -m "feat(release): sanitize the App Store What's New

The GitHub release body names every platform by design; guideline 2.3.10
forbids that in App Store metadata. Sanitized before truncation so the
character budget counts final text, with --report logging each redaction."
```

---

### Task 8: Ruby backstop in the Apple Fastfiles

Covers the one path that never touches the shell script: a local `fastlane` run with a hand-set `BETA_CHANGELOG`.

**Files:**
- Modify: `ios/fastlane/Fastfile:74-113`
- Modify: `macos/fastlane/Fastfile:28-68`
- Test: `scripts/release/fastlane_beta_changelog_test.rb`

**Interfaces:**
- Consumes: `scripts/release/apple_store_banned_terms.json` from Task 1.
- Produces: `strip_non_apple_platforms(text) -> String`, defined at top level in both Fastfiles.

- [ ] **Step 1: Write the failing test**

Append to `scripts/release/fastlane_beta_changelog_test.rb`, before the block that reports failures:

```ruby
# --- The Apple lanes must not publish another platform's name ----------------
# Notes handed straight to fastlane via BETA_CHANGELOG never pass through
# sanitize_apple_store_notes.py, so the Fastfile carries a last-resort sweep
# over the same shared term list.

with_env('BETA_CHANGELOG_FILE' => nil,
         'BETA_CHANGELOG' => "Fixed the Android USB download and the Windows updater.") do
  notes = beta_changelog
  check(!notes.match?(/Android/i), 'Android reached the TestFlight changelog')
  check(!notes.include?('Windows'), 'Windows reached the TestFlight changelog')
  check(notes.include?('USB download'), 'the backstop ate the rest of the note')
end

# Already-sanitized text from the pipeline must survive unchanged.
with_env('BETA_CHANGELOG_FILE' => nil,
         'BETA_CHANGELOG' => 'Fixed the other platforms USB download.') do
  check(beta_changelog == 'Fixed the other platforms USB download.',
        'the backstop is not idempotent over already-sanitized notes')
end
```

If the file has no `with_env` helper, add one near the other helpers:

```ruby
# Sets environment variables for the duration of the block and restores them.
def with_env(vars)
  previous = vars.keys.to_h { |key| [key, ENV[key]] }
  vars.each { |key, value| ENV[key] = value }
  yield
ensure
  previous.each { |key, value| ENV[key] = value }
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `ruby scripts/release/fastlane_beta_changelog_test.rb`

Expected: FAIL reporting `Android reached the TestFlight changelog` and `Windows reached the TestFlight changelog`.

- [ ] **Step 3: Add the backstop to both Fastfiles**

In **both** `ios/fastlane/Fastfile` and `macos/fastlane/Fastfile`, add `require 'json'` alongside the existing top-of-file requires, then insert this immediately before the `beta_changelog` definition (`ios:95`, `macos:50`):

```ruby
  # Last resort for a local run. Notes handed straight to fastlane through
  # BETA_CHANGELOG never pass through sanitize_apple_store_notes.py, and App
  # Review guideline 2.3.10 forbids naming other platforms in App Store
  # metadata. The term list is shared with that script so the two cannot
  # drift.
  #
  # This only redacts. The Python path additionally repairs platform lists,
  # which is what keeps the prose readable, so this is a safety net rather
  # than an equivalent implementation.
  APPLE_BANNED_TERMS_PATH = File.expand_path(
    "../../scripts/release/apple_store_banned_terms.json", __dir__
  )
  APPLE_TERM_REPLACEMENT = {
    "platform" => "other platforms",
    "store" => "another store",
  }.freeze

  def strip_non_apple_platforms(text)
    unless File.exist?(APPLE_BANNED_TERMS_PATH)
      UI.important(
        "Banned-term list missing at #{APPLE_BANNED_TERMS_PATH}; " \
        "publishing notes unsanitized."
      )
      return text
    end

    terms = JSON.parse(File.read(APPLE_BANNED_TERMS_PATH))["terms"]
    terms.reduce(text) do |acc, term|
      options = term["ignorecase"] ? Regexp::IGNORECASE : 0
      acc.gsub(
        Regexp.new(term["pattern"], options),
        APPLE_TERM_REPLACEMENT[term["class"]],
      )
    end
  end
```

Then change the first line of `beta_changelog` in both files from:

```ruby
    notes = read_beta_notes.strip
```

to:

```ruby
    notes = strip_non_apple_platforms(read_beta_notes).strip
```

`__dir__` is `ios/fastlane` (or `macos/fastlane`), so `../../scripts/release/...` resolves to the repository root. This is unaffected by fastlane wrapping actions in `Dir.chdir("..")`, because `File.expand_path` with `__dir__` never consults the working directory.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
ruby scripts/release/fastlane_beta_changelog_test.rb
```

Expected: the suite passes with no failures reported.

- [ ] **Step 5: Verify the two Fastfiles did not drift**

```bash
diff <(sed -n '/Last resort for a local run/,/^  end$/p' ios/fastlane/Fastfile) \
     <(sed -n '/Last resort for a local run/,/^  end$/p' macos/fastlane/Fastfile) \
  && echo "backstops identical"
```

Expected: `backstops identical`.

- [ ] **Step 6: Commit**

```bash
git add ios/fastlane/Fastfile macos/fastlane/Fastfile \
        scripts/release/fastlane_beta_changelog_test.rb
git commit -m "feat(release): backstop platform terms in the Apple Fastfiles

Covers a local fastlane run with a hand-set BETA_CHANGELOG, which never
passes through the Python sanitizer. Shares the term list so the two
implementations cannot drift."
```

---

### Task 9: Full verification

**Files:** none modified.

- [ ] **Step 1: Run every affected test suite**

```bash
python3 scripts/release/sanitize_apple_store_notes_test.py -v
./scripts/release/beta_release_notes_test.sh
./scripts/release/generate_changelog_test.sh
ruby scripts/release/fastlane_beta_changelog_test.rb
```

Expected: all four pass. Paste the actual output; do not summarize it.

- [ ] **Step 2: Confirm no stale references remain**

```bash
grep -rn -- "--format store\|beta-notes-store\|STORE_LIMIT" \
  scripts/ .github/workflows/ ios/fastlane/Fastfile macos/fastlane/Fastfile
```

Expected: no output.

- [ ] **Step 3: Confirm the non-Apple paths are genuinely untouched**

```bash
grep -rn "sanitize_apple_store_notes" .github/workflows/ scripts/
```

Expected: exactly three call sites, none of them on a Play, markdown, or Sparkle path: the `add_section` gate in `beta_release_notes.sh`, the "Prepare What's New" step in `promote.yml`, and the `script-tests` registration in `ci.yaml`.

- [ ] **Step 4: End-to-end check against the most recent real release body**

```bash
gh release view "$(gh release list --repo submersion-app/submersion \
  --limit 1 --json tagName -q '.[0].tagName')" \
  --repo submersion-app/submersion --json body -q .body \
  | ./scripts/release/sanitize_apple_store_notes.py --report \
      --fallback 'This release includes bug fixes and improvements.' \
  > /tmp/whats-new-final.txt
echo "exit=$?"
grep -nE '\b(Windows|Android|Linux|Ubuntu|Debian|Flatpak|AppImage)\b' \
  /tmp/whats-new-final.txt || echo "clean"
```

Expected: `exit=0` and `clean`. Read `/tmp/whats-new-final.txt` and confirm the prose is coherent. Report anything that reads badly rather than fixing it silently: the spec accepts dangling clauses, but a genuinely broken sentence is a bug in the replacement pass.

- [ ] **Step 5: Format and analyze**

```bash
dart format .
flutter analyze
```

Expected: no changes from `dart format` and no new analyzer findings. No Dart source is touched by this change, so both should be clean; run them anyway because the pre-push hook does.

- [ ] **Step 6: Commit any formatting changes**

Only if `dart format` reported changes:

```bash
git add -A && git commit -m "style: dart format"
```

---

## Notes for the implementer

- **The corpus test is the one that finds real bugs.** Everything else uses invented input. Expect the first run of `TestReleaseNotesCorpus` to fail and to teach you a list shape you had not considered.
- **Do not add `APK` to the term list.** It was considered and explicitly rejected.
- **Do not sanitize the Play notes.** Android is not a banned word on Google Play, and stripping it would make those notes worse for no benefit.
- **Known and accepted limitations**, which are not bugs to fix: counts go stale (`on all five platforms (iOS and macOS)`), clauses about a single platform survive as non-sequiturs, and a lowercase `windows` meaning the OS is not caught.
