#!/usr/bin/env python3
"""Keep the how-to list on the wiki Home page current.

Usage: python3 scripts/wiki_howto_index.py <path to a clone of the wiki>

Every wiki page whose file name starts with "How-to-" is listed on Home.md,
newest first, between START_MARKER and END_MARKER. Everything else on Home is
left exactly as it is. When Home has no markers yet, a "How-to guides"
section holding them is added at the end, so the list can then be moved
anywhere on the page by moving the markers with it.

A page's date is the commit that first created it, followed through renames,
so renaming a page to give it the How-to prefix does not make it look new.

The workflow .github/workflows/wiki-howto-index.yml runs this whenever a wiki
page is created or edited, and pushes Home.md when it changed.

Exit status: 0 when Home is current (whether or not it was rewritten), 1 when
Home has broken markers and was left alone, 2 on a usage error.
"""

import os
import subprocess
import sys
import urllib.parse

HOWTO_PREFIX = "how-to-"
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
    return ext == ".md" and stem.lower().startswith(HOWTO_PREFIX)


def page_title(stem):
    """The title the wiki shows for a page, from its file name."""
    return stem.replace("-", " ")


def page_link(stem):
    """A link to a page relative to the wiki root."""
    return urllib.parse.quote(stem, safe="-'")


def list_item(stem):
    title = page_title(stem).replace("[", "\\[").replace("]", "\\]")
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


def _created_at(wiki_dir, file_name):
    """Unix time of the commit that first added a page, through renames."""
    result = subprocess.run(
        [
            "git",
            "-C",
            wiki_dir,
            "log",
            "--follow",
            "--diff-filter=A",
            "--format=%at",
            "--",
            file_name,
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    stamps = result.stdout.split()
    return int(stamps[-1]) if stamps else _UNDATED


def howto_pages(wiki_dir):
    """Stems of the wiki's how-to pages, newest first, then by title."""
    names = sorted(name for name in os.listdir(wiki_dir) if is_howto(name))
    dated = [(_created_at(wiki_dir, name), name[: -len(".md")]) for name in names]
    dated.sort(key=lambda pair: (-pair[0], page_title(pair[1]).lower()))
    return [stem for _, stem in dated]


def main(argv):
    if len(argv) != 1:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
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
