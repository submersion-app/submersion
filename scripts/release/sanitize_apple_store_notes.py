#!/usr/bin/env python3
"""Strip non-Apple platform references and contributor credits out of App Store Connect note fields.

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

The same input also carries contributor credits: the release body attributes
every bullet to its author and closes with a New Contributors section. Those
are removed here too, because an @handle is not a name and a PR number is not
something a store reader can follow.

Only Apple-bound text passes through here. Google Play notes, the GitHub
release body, the Sparkle appcast and docs/releases/*.md keep every platform
name and every credit.

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


# A list member is one word, or one whole multi-word banned term.
#
# A member may not be an arbitrary run of words. That looks more general but is
# actively wrong: the leading member is greedy, so "broken on Windows, Linux,
# and Android" would parse its first member as "broken on Windows", which is
# not *entirely* a banned term, and the platform name would survive.
#
# Restricting the multi-word case to the banned terms themselves keeps that
# property, because such a branch can only ever match a banned term and so can
# never absorb the prose in front of the list. It is what makes a two-word
# distro name work in a list: without it "Rocky Linux, AlmaLinux, and CentOS"
# fails to match at "Rocky", matches from "Linux" instead, and collapses to
# "Rocky other platforms", stranding the half of the name that is not itself a
# banned term. Nothing reports that, either: bare "Rocky" is not banned, so the
# survivor check at the end of main() sees a clean result.
#
# The negative lookahead stops "and"/"or" being parsed as a member.
_WORD = r"(?!(?:and|or)\b)[A-Za-z0-9][A-Za-z0-9.+/-]*"

# Horizontal whitespace only. \s matches a newline, and release notes are
# wrapped Markdown prose, so a list can straddle a line break. A pattern that
# consumed that newline would join the two lines, breaking the line-count
# invariant --report's line-by-line diff depends on and, in the beta notes,
# potentially merging two items into one.
_H = r"[ \t]"


def _member_pattern(terms):
    """The member sub-pattern: multi-word banned terms first, then one word.

    A term counts as multi-word when its pattern contains the [ \\t] the JSON
    mandates for whitespace inside a term; \\s is banned there, so there is no
    other spelling to look for.

    Declaration order is carried through into the alternation, which is what
    the JSON's longest-spelling-first rule already guarantees: Python tries
    alternatives left to right, so "Red Hat Enterprise Linux" is offered before
    "Red Hat" and wins where both could match.

    Per-term case sensitivity is preserved with a scoped (?i:...) group rather
    than a flag on the whole list pattern. A single flag would have to be wrong
    for one term or the other, since Microsoft is case-sensitive and Arch Linux
    is not.
    """
    alternatives = []
    for pattern, _cls in terms:
        if "[ \\t]" not in pattern.pattern:
            continue
        if pattern.flags & re.IGNORECASE:
            alternatives.append("(?i:" + pattern.pattern + ")")
        else:
            alternatives.append("(?:" + pattern.pattern + ")")
    alternatives.append(_WORD)
    return "(?:" + "|".join(alternatives) + ")"


def _list_re(terms):
    """The list pattern for these terms. re.compile caches by pattern text."""
    member = _member_pattern(terms)
    return re.compile(
        r"\b" + member +
        r"(?:" + _H + r"*," + _H + r"*" + member + r")*"
        + _H + r"*,?" + _H + r"+(?:and|or)" + _H + r"+" + member + r"\b"
    )

# The conjunction alternative must come first. Python tries alternatives left
# to right, so a leading plain-comma branch would consume the ", " of ", and "
# and leave "and Linux" behind as a member, rebuilding the list as
# "Mac and and Linux".
_SPLIT_RE = re.compile(
    _H + r"*,?" + _H + r"+(?:and|or)" + _H + r"+|" + _H + r"*," + _H + r"*"
)


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
    list_re = _list_re(terms)

    def substitute(match):
        raw = match.group(0)
        members = [m for m in _SPLIT_RE.split(raw) if m]
        if not any(_is_banned_member(m, terms) for m in members):
            return raw
        kept = [m for m in members if not _is_banned_member(m, terms)]
        if not kept:
            return REPLACEMENT["platform"]
        return _join(kept)

    return list_re.sub(substitute, text)


# A sentence or line boundary immediately before the match position.
_SENTENCE_START_RE = re.compile(r"(?:\A|[.!?:]\s+|\n)\s*\Z")


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


# Every pattern here uses _H rather than \s, for the reason given above it:
# these all consume what they match, so a \s would eat a newline and join two
# lines.
_TIDY = [
    # Two adjacent platform names both replaced in place read as a stutter.
    (re.compile(r"\bother platforms(?:,?" + _H + r"+(?:and|or)" + _H +
                r"+other platforms)+\b"),
     "other platforms"),
    (re.compile(r"\banother store(?:,?" + _H + r"+(?:and|or)" + _H +
                r"+another store)+\b"),
     "another store"),
    # A parenthetical emptied by list repair, and the space that preceded it.
    (re.compile(_H + r"*\(" + _H + r"*\)"), ""),
    (re.compile(_H + r"*\[" + _H + r"*\]"), ""),
    (re.compile(r"," + _H + r"*\)"), ")"),
    (re.compile(r"\(" + _H + r"*," + _H + r"*"), "("),
    (re.compile(_H + r"+,"), ","),
    (re.compile(_H + r"{2,}"), " "),
    (re.compile(_H + r"+$", re.MULTILINE), ""),
]


def tidy(text):
    """Repair the punctuation and spacing the earlier passes disturb."""
    for pattern, replacement in _TIDY:
        text = pattern.sub(replacement, text)
    return text


# " by @octocat in #42", and the shorter " by @octocat" a commit that reached
# main without a PR gets. The "@" is what makes this safe: ordinary prose such
# as "Reported by a tester" and "Fixes the crash described in #1182" cannot
# match, so only a real credit is ever removed.
_ATTRIBUTION_RE = re.compile(
    r"[ \t]by @[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:[ \t]in #[0-9]+)?"
)

# The closing credits section, from its heading to the next heading or the end
# of the body. Unlike every other pass here this one removes lines, which is
# why it runs on the input before the line-count invariant is established.
_NEW_CONTRIBUTORS_RE = re.compile(
    r"^#{1,6}[ \t]*New Contributors[ \t]*$.*?(?=^#{1,6}[ \t]|\Z)",
    re.MULTILINE | re.DOTALL,
)


def strip_attribution(text):
    """Remove contributor credits. Returns (text, number of removals).

    The GitHub release body credits every bullet to its author and closes with
    the first-time contributors, which is the point of the release page. None
    of it belongs in App Store "What's New": an @handle is not a name, a PR
    number is not something a store reader can follow, and the section reads as
    project bookkeeping rather than as what changed in the app.

    This is the only pass that changes the line count, so it runs before
    sanitize() rather than inside it.
    """
    text, dropped = _NEW_CONTRIBUTORS_RE.subn("", text)
    text, credits = _ATTRIBUTION_RE.subn("", text)
    return text, dropped + credits


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


_WRAPPED_WS_RE = re.compile(r"[ \t]*\n[ \t]*")


def find_wrapped_only(text, terms):
    """Multi-word terms that appear only once line breaks count as spaces.

    Every consuming pattern uses [ \\t] rather than \\s so it can never join
    two lines. The blind spot that leaves is a multi-word term such as
    "Google Play" hard-wrapped across a break; a single-word term cannot
    straddle a line, so Windows, Android and Linux are unaffected.

    Callers warn on this rather than failing. No release body or release note
    is hard-wrapped today (their paragraphs run to 900+ characters on one
    line), and the guard must never block a release on wording.
    """
    flattened = _WRAPPED_WS_RE.sub(" ", text)
    if len(find_matches(flattened, terms)) <= len(find_matches(text, terms)):
        return []
    return sorted({
        flattened[start:end]
        for start, end, _cls in find_matches(flattened, terms)
        if " " in flattened[start:end]
    })


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
    original, credits = strip_attribution(sys.stdin.read())
    result = sanitize(original, terms)

    if credits:
        print(
            "sanitize_apple_store_notes: removed %d contributor credit(s)"
            % credits,
            file=sys.stderr,
        )

    if args.report:
        _report(original, result, terms)

    # Unconditional: this is a gap in coverage, not a routine redaction, so it
    # must surface in the job log whether or not --report was asked for.
    wrapped = find_wrapped_only(original, terms)
    if wrapped:
        print(
            "sanitize_apple_store_notes: WARNING: %s is split across a line "
            "break and was left in place; rewrap that source line."
            % ", ".join(wrapped),
            file=sys.stderr,
        )

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
