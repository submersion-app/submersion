#!/usr/bin/env python3
"""Keep the how-to list on the wiki Home page current.

Usage: python3 scripts/wiki_howto_index.py <path to a clone of the wiki>

Every wiki page whose file name starts with "How-to-", in any markup the wiki
renders and in any folder, is listed on Home.md, newest first, between START_MARKER and END_MARKER. Everything else on Home is
left exactly as it is. When Home has no markers yet, a "How-to guides"
section holding them is added at the end, so the list can then be moved
anywhere on the page by moving the markers with it.

A page's date is the commit that first created it, followed through renames,
so renaming a page to give it the How-to prefix does not make it look new.
The whole wiki history is read once; `git log --follow` per page is not used
because it also treats a new page that resembles an existing one as a copy
and dates it from the older page.

The workflow .github/workflows/wiki-howto-index.yml runs this whenever a wiki
page is created or edited, and pushes Home.md when it changed.

Exit status: 0 when Home is current (whether or not it was rewritten), 1 when
Home has broken markers and was left alone, 2 on a usage error.
"""

import os
import re
import subprocess
import sys
import urllib.parse

USAGE = "Usage: python3 scripts/wiki_howto_index.py <path to a clone of the wiki>"
HOWTO_PREFIX = "how-to-"
# Every markup the wiki editor can save a page in, plus the other Markdown
# spellings and plain-text pages the wiki renders when pushed with git.
PAGE_EXTENSIONS = frozenset(
    {
        ".md",
        ".markdown",
        ".mdown",
        ".mdwn",
        ".mkd",
        ".mkdn",
        ".txt",
        ".asciidoc",
        ".adoc",
        ".creole",
        ".mediawiki",
        ".wiki",
        ".org",
        ".pod",
        ".rdoc",
        ".rest",
        ".rst",
        ".textile",
    }
)
# Characters that would format link text instead of showing as themselves.
_MARKDOWN_SPECIAL = re.compile(r"([\\`*_\[\]<>])")
HOME_FILE = "Home.md"
SECTION_HEADING = "## How-to guides"
START_MARKER = (
    "<!-- how-to-index:start (generated from the wiki's How-to pages; "
    "edits between these markers are replaced) -->"
)
END_MARKER = "<!-- how-to-index:end -->"
EMPTY_LIST = "_No how-to guides yet._"

# Sorts pages that git has no creation date for (not committed yet) first.
_UNDATED = sys.maxsize


def is_howto(file_name):
    """Whether a wiki file is a how-to page."""
    stem, ext = os.path.splitext(file_name)
    return ext.lower() in PAGE_EXTENSIONS and stem.lower().startswith(HOWTO_PREFIX)


def page_title(stem):
    """The title the wiki shows for a page, from its file name."""
    return stem.replace("-", " ")


def page_link(stem):
    """A link to a page relative to the wiki root."""
    return urllib.parse.quote(stem, safe="-'")


def list_item(stem):
    title = _MARKDOWN_SPECIAL.sub(r"\\\1", page_title(stem))
    return f"- [{title}]({page_link(stem)})"


def render_list(stems):
    if not stems:
        return EMPTY_LIST
    return "\n".join(list_item(stem) for stem in stems)


def update_home(home, block):
    """Home with the text between the markers replaced by block.

    Raises ValueError when only one marker is present or they are out of
    order, rather than guessing which part of the page is the list.
    """
    start = home.find(START_MARKER)
    end = home.find(END_MARKER)
    if start == -1 and end == -1:
        section = f"{SECTION_HEADING}\n\n{START_MARKER}\n{block}\n{END_MARKER}\n"
        body = home.rstrip("\n")
        return f"{body}\n\n{section}" if body else section
    if start == -1 or end == -1 or end < start:
        raise ValueError(
            f"{HOME_FILE} needs both {START_MARKER!r} and {END_MARKER!r}, "
            "in that order"
        )
    before = home[: start + len(START_MARKER)]
    return f"{before}\n{block}\n{home[end:]}"


def _apply_change(created, stamp, status, paths):
    """created after one file change from `git log --name-status`."""
    if status.startswith("R"):
        old, new = paths
        kept = {path: when for path, when in created.items() if path != old}
        return {**kept, new: created.get(old, stamp)}
    if status == "A":
        return {**created, paths[0]: stamp}
    if status == "D":
        return {path: when for path, when in created.items() if path != paths[0]}
    return created


def parse_creation_times(log):
    """Path to creation time from `git log --reverse -M --name-status -z`.

    Expects --format=%x01%at, so each commit reads "\\x01<time>\\0\\n"
    followed by "<status>\\0<path>\\0" entries, a rename carrying its old
    and new path. Renames keep the page's original date; only real renames
    count, so a new page that starts as a near-copy of another keeps its own.
    """
    created = {}
    for commit in log.split("\x01")[1:]:
        stamp, _, changes = commit.partition("\0")
        tokens = changes.lstrip("\n").split("\0")
        index = 0
        while index < len(tokens) and tokens[index]:
            status = tokens[index]
            count = 2 if status[0] in "RC" else 1
            paths = tokens[index + 1 : index + 1 + count]
            created = _apply_change(created, int(stamp), status, paths)
            index += 1 + count
    return created


def _creation_times(wiki_dir):
    """Path (with "/" separators) to the time the commit creating it was made."""
    result = subprocess.run(
        [
            "git",
            "-C",
            wiki_dir,
            "log",
            "--reverse",
            "-M",
            "--name-status",
            "-z",
            "--format=%x01%at",
        ],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return parse_creation_times(result.stdout)


def _page_files(wiki_dir):
    """Paths, relative to the wiki root, of every how-to page.

    The wiki serves a page from any folder under its own file name, so
    pages pushed into folders count too.
    """
    for folder, _, files in os.walk(wiki_dir):
        if ".git" in os.path.relpath(folder, wiki_dir).split(os.sep):
            continue
        for name in files:
            if is_howto(name):
                yield os.path.relpath(os.path.join(folder, name), wiki_dir)


def howto_pages(wiki_dir):
    """Stems of the wiki's how-to pages, newest first, then by title."""
    created = _creation_times(wiki_dir)
    dated = sorted(
        (
            (
                created.get(path.replace(os.sep, "/"), _UNDATED),
                os.path.splitext(os.path.basename(path))[0],
            )
            for path in _page_files(wiki_dir)
        ),
        key=lambda pair: (-pair[0], page_title(pair[1]).lower()),
    )
    return [stem for _, stem in dated]


def main(argv):
    if len(argv) != 1:
        print(USAGE, file=sys.stderr)
        return 2
    wiki_dir = argv[0]
    path = os.path.join(wiki_dir, HOME_FILE)
    try:
        with open(path, encoding="utf-8") as handle:
            home = handle.read()
    except FileNotFoundError:
        home = ""

    try:
        updated = update_home(home, render_list(howto_pages(wiki_dir)))
    except ValueError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    if updated == home:
        print(f"{HOME_FILE} already lists every how-to page.")
        return 0
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(updated)
    print(f"Updated the how-to list in {HOME_FILE}.")
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv[1:]))
