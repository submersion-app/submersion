#!/usr/bin/env python3
"""Require every pull request description to link the issue it relates to.

GitHub closes an issue on merge only when a closing keyword sits directly in
front of the issue number in the PR description (or in a commit message that
reaches the default branch). A number in the title, or a passing mention in
prose, links nothing. Issue #1800 found issues left open after the PR that
resolved them had merged, because the description never said `Closes #N`.

This guard makes the link a deliberate, checked part of every PR. It passes
when the description contains at least one of:

  * a closing link:     Close[sd] / Fix(e[sd]) / Resolve[sd] #N
  * a non-closing link: Refs / Part of / Related to #N

The non-closing forms exist for phased work and follow-ups that relate to an
issue without resolving it, so the issue is not closed early. When the branch
name encodes an issue number (`github-issue-1800-...`, `feature-request-1803-
...`, `fix/issue-12`), that particular issue must be one of the links: the
branch says which issue the work is for, so a description that forgets it is
almost certainly the #1800 mistake.

Bot-authored PRs (the version bump promote.yml opens, Dependabot) pass
unconditionally: they have no issue, and blocking them would stall the bump
PR's auto-merge and with it the beta train.

Text GitHub does not parse for links is ignored: HTML comments (where the PR
template keeps its examples, so an untouched template fails), fenced code
blocks and inline code spans. Indented code blocks are not stripped, because
telling them apart from nested list content needs a full Markdown parser.

Pure stdlib, so the workflow needs no dependency install.

Usage: check_pr_issue_link.py --body-file PATH [--branch NAME]
                              [--author-type User|Bot] [--repo OWNER/NAME]
"""

import argparse
import re
import sys

CLOSING_KEYWORD = r"(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)"
LINKING_KEYWORD = r"(?:refs|part[ \t]+of|related[ \t]+to)"

# GitHub accepts an optional colon after the keyword, but the keyword and the
# reference must still be separated by it or by whitespace.
_SEPARATOR = r"(?::[ \t]*|[ \t]+)"
_REFERENCE = r"(?:(?P<repo>[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+))?#(?P<num>\d+)\b"

# re.ASCII: without it `\d` also matches digits such as Arabic-Indic ones,
# which GitHub does not treat as an issue number.
_CLOSING = re.compile(
    r"\b" + CLOSING_KEYWORD + r"\b" + _SEPARATOR + _REFERENCE,
    re.IGNORECASE | re.ASCII,
)
_LINKING = re.compile(
    r"\b" + LINKING_KEYWORD + r"\b" + _SEPARATOR + _REFERENCE,
    re.IGNORECASE | re.ASCII,
)

# `issue-N` must start a path segment or follow a hyphen/underscore, so
# `tissue-5` is not an issue branch.
_BRANCH_ISSUE = re.compile(
    r"(?:^|[/_-])(?:issue|feature-request)-(\d+)(?=$|[/_-])",
    re.IGNORECASE | re.ASCII,
)

_FENCE_OPEN = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
_COMMENT_BLOCK_OPEN = re.compile(r"^ {0,3}<!--")
_PARAGRAPH_BREAK = re.compile(r"\n[ \t]*\n")
_INLINE_OPEN = re.compile(r"<!--|`+")

HOW_TO_FIX = (
    "Every PR must relate to an issue. Add `Closes #N` (or Fixes/Resolves) to "
    "the description if this PR resolves the issue, or `Refs #N`, `Part of "
    "#N` or `Related to #N` if it does not. A number in the title or in "
    "passing prose links nothing. Editing the description re-runs this check."
)


def _closes_fence(line, fence):
    """A closing fence repeats the opening character, at least as many times,
    with nothing after it: a line such as ```text inside a block is content."""
    stripped = line.strip()
    return (
        bool(stripped)
        and set(stripped) == {fence[0]}
        and len(stripped) >= len(fence)
        and len(line) - len(line.lstrip(" ")) <= 3
    )


def _strip_blocks(text):
    """Drop fenced code blocks and HTML comment blocks, line by line.

    Block structure is decided before inline markup, so a `<!--` inside a
    fence is content. A comment block starts with `<!--` at the start of a
    line (it may interrupt a paragraph) and ends on the line holding `-->`.
    An unclosed fence or comment block runs to the end of the text.
    """
    kept, fence, in_comment = [], None, False
    for line in text.splitlines():
        if fence is not None:
            if _closes_fence(line, fence):
                fence = None
            continue
        if in_comment:
            in_comment = "-->" not in line
            continue
        opening = _FENCE_OPEN.match(line)
        # A backtick fence's info string cannot contain a backtick, so a line
        # like ```x``` is an inline code span, not a fence.
        if opening and not (
            opening.group(1)[0] == "`" and "`" in opening.group(2)
        ):
            fence = opening.group(1)
            continue
        if _COMMENT_BLOCK_OPEN.match(line):
            in_comment = "-->" not in line[line.index("<!--") + 4:]
            continue
        kept.append(line)
    return "\n".join(kept)


def _strip_inline(paragraph):
    """Drop code spans and inline HTML comments, in document order.

    Whichever construct opens first wins, so a `<!--` inside a code span is
    code and a backtick inside a comment is comment. An opener with no closer
    in the same paragraph is literal text.
    """
    out, pos = [], 0
    while True:
        opening = _INLINE_OPEN.search(paragraph, pos)
        if not opening:
            out.append(paragraph[pos:])
            return "".join(out)
        out.append(paragraph[pos:opening.start()])
        token = opening.group()
        if token == "<!--":
            end = paragraph.find("-->", opening.end())
            close_end = end + 3 if end >= 0 else None
        else:
            # A code span closes on a backtick run of exactly the same length.
            closer = re.compile(r"(?<!`)" + token + r"(?!`)").search(
                paragraph, opening.end()
            )
            close_end = closer.end() if closer else None
        if close_end is None:
            out.append(token)
            pos = opening.end()
        else:
            pos = close_end


def prose(body):
    """Return only the text GitHub scans for issue links."""
    paragraphs = _PARAGRAPH_BREAK.split(_strip_blocks(body or ""))
    return "\n\n".join(_strip_inline(p) for p in paragraphs)


def _refs(pattern, body, repo):
    refs = set()
    for match in pattern.finditer(prose(body)):
        ref_repo, number = match.group("repo"), match.group("num")
        if ref_repo and ref_repo.lower() != (repo or "").lower():
            refs.add(f"{ref_repo}#{number}")
        else:
            refs.add(f"#{number}")
    return refs


def closing_refs(body, repo):
    """Issues GitHub will close when this PR merges into the default branch."""
    return _refs(_CLOSING, body, repo)


def linking_refs(body, repo):
    """Issues the description explicitly relates to without closing them."""
    return _refs(_LINKING, body, repo)


def branch_issue(branch):
    """Return `#N` when the branch name encodes an issue number, else None."""
    match = _BRANCH_ISSUE.search(branch or "")
    return f"#{match.group(1)}" if match else None


def evaluate(body, branch, author_type, repo):
    """Return (ok, lines) for one pull request."""
    if (author_type or "").lower() == "bot":
        return True, ["  ok    bot-authored PR: exempt from the issue-link rule"]

    closes = closing_refs(body, repo)
    relates = linking_refs(body, repo)
    lines = []
    ok = True

    if not closes and not relates:
        ok = False
        lines.append(f"  FAIL  the description links no issue. {HOW_TO_FIX}")

    expected = branch_issue(branch)
    if expected and expected not in closes | relates:
        ok = False
        lines.append(
            f"  FAIL  branch '{branch}' is for issue {expected}, but the "
            f"description neither closes nor references it. Add `Closes "
            f"{expected}`, or `Refs {expected}` if this PR does not resolve it."
        )

    if ok:
        if closes:
            lines.append("  ok    closes " + ", ".join(sorted(closes)))
        if relates:
            lines.append("  ok    relates to " + ", ".join(sorted(relates)))
    return ok, lines


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--body-file", required=True)
    parser.add_argument("--branch", default="")
    parser.add_argument("--author-type", default="User")
    parser.add_argument("--repo", default="")
    args = parser.parse_args(argv[1:])

    print("Checking the PR description for an issue link")
    try:
        with open(args.body_file, encoding="utf-8", errors="replace") as fh:
            body = fh.read()
    except OSError as exc:
        print(f"::error::could not read the PR description: {exc}")
        return 1

    ok, lines = evaluate(body, args.branch, args.author_type, args.repo)
    for line in lines:
        print(line)
    if ok:
        print("  -> PASS")
        return 0
    for line in lines:
        if line.startswith("  FAIL"):
            print("::error::" + line[len("  FAIL  "):])
    print("  -> FAIL: link the issue this PR relates to")
    return 1


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv))
