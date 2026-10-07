#!/usr/bin/env python3
"""Keep links into and within docs/ resolvable (issue #3054).

Three checks, each printed as file:line and the unresolved target:

1. Relative Markdown links resolve in docs/README.md, docs/developer/ and
   docs/contributing/. docs/design/ is excluded because design records
   describe the code as it was when written; docs/user/ is excluded until
   the user docs move to their own link rules.
2. A docs path cited from code (lib/, test/, scripts/, .github/,
   README.md, CONTRIBUTING.md, CLAUDE.md) exists. Only paths under a known
   docs folder and ending in a file extension count, which skips lookalikes
   such as "docs/CI-only". A path under a retired folder (docs/superpowers/,
   docs/plans/, docs/api/, docs/import-formats/) fails and names the new
   home, so a branch whose spec git moved still has its comments caught.
3. The retired folders docs/superpowers/ and docs/plans/ do not exist. A
   branch created before the docs restructure fails here and is told where
   its file belongs.

Pure stdlib. Usage: check_docs_links.py [repo-root]; the root defaults to
the repository this script lives in, so it can run from any directory.
"""

import html
import os
import re
import sys
import unicodedata
from urllib.parse import unquote

LINK_ROOTS = (
    os.path.join("docs", "README.md"),
    os.path.join("docs", "developer"),
    os.path.join("docs", "contributing"),
    os.path.join("docs", "user"),
)
CODE_REF_SOURCES = (
    "lib",
    "test",
    "scripts",
    ".github",
    "README.md",
    "CONTRIBUTING.md",
    "CLAUDE.md",
)
NOT_SCANNED = {os.path.join("scripts", "check_docs_links_test.py")}
SKIP_DIRS = {"__pycache__", "node_modules", ".dart_tool", "build"}
RETIRED = {
    os.path.join("docs", "superpowers"): (
        "move specs to docs/design/specs/, plans to docs/design/plans/ and "
        "findings to docs/design/findings/"
    ),
    os.path.join("docs", "plans"): (
        "move a *-design.md file to docs/design/specs/ and an implementation "
        "plan to docs/design/plans/"
    ),
}

# A destination is either <angle-bracketed> (may hold spaces) or a run of
# non-space characters with balanced single-level parentheses, as in
# CommonMark. An optional "title" may follow.
LINK_RE = re.compile(
    r"\]\(\s*(?:<([^>\n]+)>|((?:[^()\s]|\([^()\s]*\))+))"
    r"(?:\s+\"[^\"]*\")?\s*\)"
)
# A reference definition ("[ref]: path"), but not a footnote ("[^1]: text").
REF_DEF_RE = re.compile(r"^\s{0,3}\[(?!\^)[^\]]+\]:\s*(?:<([^>]+)>|(\S+))")
HTML_ATTR_RE = re.compile(r"""(?:href|src)\s*=\s*(?:"([^"]+)"|'([^']+)')""")
INLINE_CODE_RE = re.compile(r"(`+).+?\1")
FENCE_RE = re.compile(r"^\s*(`{3,}|~{3,})")
SCHEME_RE = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
# Folders the restructure retired, and where their files went.
RETIRED_REF_HOMES = {
    "superpowers": "docs/design/",
    "plans": "docs/design/specs/ or docs/design/plans/",
    "api": "docs/developer/reference/",
    "import-formats": "docs/developer/reference/formats/",
}
# A docs path cited from code. The lookbehinds skip "docs/" inside a longer
# path or URL ("example.org/docs/..."), which is not a path in this
# repository, while still matching "./docs/..." and "../docs/...".
DOCS_REF_RE = re.compile(
    r"(?<![A-Za-z0-9_-])(?<![A-Za-z0-9_-]/)docs/"
    r"(user|developer|contributing|design|releases|assets|"
    + "|".join(re.escape(folder) for folder in RETIRED_REF_HOMES)
    + r")/[A-Za-z0-9_./-]+\.(?:md|html|png|jpg|json)\b"
)
DEFAULT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _walk(root, entries, keep):
    """Yield repo-relative paths of the files under entries that keep accepts."""
    for entry in entries:
        full = os.path.join(root, entry)
        if os.path.isfile(full):
            if keep(entry):
                yield entry
        elif os.path.isdir(full):
            for dirpath, dirnames, filenames in os.walk(full):
                dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
                for name in sorted(filenames):
                    rel = os.path.relpath(os.path.join(dirpath, name), root)
                    if keep(rel):
                        yield rel


def _read_text(path):
    """The file's text, or None for a binary or unreadable file.

    A NUL byte in the first block marks a binary file (fonts, fixtures), so
    the rest of it is never read.
    """
    try:
        with open(path, "rb") as fh:
            head = fh.read(8192)
            if b"\0" in head:
                return None
            # A stray non-UTF-8 byte must not hide the rest of the file.
            return (head + fh.read()).decode("utf-8", errors="replace")
    except OSError:
        return None


def _unfenced_lines(text):
    """Yield (number, line) outside fenced code blocks.

    A fence closes only on the same character repeated at least as many
    times as it opened with, so a ```` block can show a ``` example.
    """
    fence = None
    for number, line in enumerate(text.splitlines(), 1):
        match = FENCE_RE.match(line)
        if fence is None:
            if match:
                fence = match.group(1)
                continue
            yield number, line
        elif match and match.group(1)[0] == fence[0] and len(match.group(1)) >= len(fence):
            fence = None


def _link_targets(line):
    """Every link destination on a line: inline, reference definition, HTML."""
    line = INLINE_CODE_RE.sub("", line)
    for regex in (LINK_RE, REF_DEF_RE, HTML_ATTR_RE):
        for match in regex.finditer(line):
            yield match.group(1) or match.group(2)


def check_links(root):
    failures = []
    for rel in _walk(root, LINK_ROOTS, lambda path: path.endswith(".md")):
        text = _read_text(os.path.join(root, rel))
        if text is None:
            continue
        base = os.path.dirname(os.path.join(root, rel))
        for number, line in _unfenced_lines(text):
            for url in _link_targets(line):
                if SCHEME_RE.match(url) or url.startswith(("#", "//")):
                    continue
                target = unquote(url.split("#", 1)[0].split("?", 1)[0])
                if not target:
                    continue
                # GitHub resolves a leading "/" from the repository root.
                if target.startswith("/"):
                    resolved = os.path.join(root, target.lstrip("/"))
                else:
                    resolved = os.path.join(base, target)
                if not os.path.exists(os.path.normpath(resolved)):
                    failures.append(f"{rel}:{number}: broken link -> {url}")
    return failures


def check_code_refs(root):
    failures = []
    for rel in _walk(root, CODE_REF_SOURCES, lambda path: path not in NOT_SCANNED):
        text = _read_text(os.path.join(root, rel))
        if text is None:
            continue
        for number, line in enumerate(text.splitlines(), 1):
            for match in DOCS_REF_RE.finditer(line):
                ref, folder = match.group(0), match.group(1)
                if folder in RETIRED_REF_HOMES:
                    failures.append(
                        f"{rel}:{number}: retired docs path -> {ref} "
                        f"(its file now lives under {RETIRED_REF_HOMES[folder]})"
                    )
                elif not os.path.exists(os.path.join(root, *ref.split("/"))):
                    failures.append(f"{rel}:{number}: missing docs path -> {ref}")
    return failures


# docs/user/ is published by docsify, which resolves links from one root, so
# the folder stays flat (images/ aside), every page must be in the sidebar
# docsify navigates by, and every anchor must mean the same heading on GitHub
# and in docsify.
USER_DOCS = os.path.join("docs", "user")
USER_IMAGES = "images"
USER_HOME = "README.md"
USER_SIDEBAR = "_sidebar.md"
HEADING_RE = re.compile(r"^\s{0,3}#{1,6}\s+(.*?)\s*#*\s*$")
# docsify rebases Markdown links and images onto its base path, but not raw
# HTML, so a relative <a href> or <img src> works on GitHub and breaks on the
# published guide.
RAW_HTML_URL_RE = re.compile(r"""<(?:a|img)\b[^>]*\b(?:href|src)\s*=\s*["']([^"']+)["']""")


def github_slug(heading):
    """The anchor GitHub gives a heading: link text kept, markup and
    punctuation dropped, lowercased, each space a hyphen."""
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", heading)
    text = re.sub(r"<[^>]+>", "", text)
    text = html.unescape(text).replace("`", "").replace("*", "")
    text = re.sub(r"[^\w\- ]", "", text.lower())
    return text.replace(" ", "-")


# The punctuation docsify 5 strips from a heading; anything else, such as
# a mathematical sign or a degree mark, stays in its anchor although GitHub
# drops it.
DOCSIFY_STRIP_RE = re.compile(r"[ -⁯⸀-⹿\\'!\"#$%&()*+,./:;<=>?@\[\]^`{|}~]")


def docsify_slug(heading):
    """The anchor docsify 5 gives a heading (its slugify): link text kept,
    tags and its punctuation set dropped, only A-Z lowercased, each
    whitespace a hyphen, and a leading digit prefixed with '_'. Emoji are
    not modelled; the guide uses none."""
    text = unicodedata.normalize("NFC", html.unescape(heading).strip())
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    text = re.sub(r"[A-Z]+", lambda m: m.group(0).lower(), text)
    text = re.sub(r"<[^>]+>", "", text)
    text = DOCSIFY_STRIP_RE.sub("", text)
    text = re.sub(r"\s", "-", text)
    return re.sub(r"^(\d)", r"_\1", text)


def _with_suffixes(slugs):
    """Number repeats the way GitHub and docsify both do: foo, foo-1, foo-2."""
    seen, out = {}, []
    for base in slugs:
        count = seen.get(base, 0)
        seen[base] = count + 1
        out.append(base if count == 0 else f"{base}-{count}")
    return out


def _heading_slugs(text):
    """Each heading's GitHub anchor, mapped to its docsify anchor."""
    headings = []
    for _number, line in _unfenced_lines(text):
        match = HEADING_RE.match(line)
        if match:
            headings.append(match.group(1))
    return dict(
        zip(
            _with_suffixes(github_slug(h) for h in headings),
            _with_suffixes(docsify_slug(h) for h in headings),
        )
    )


def check_user_docs(root):
    base = os.path.join(root, USER_DOCS)
    if not os.path.isdir(base):
        return []
    failures, pages = [], {}
    for entry in sorted(os.listdir(base)):
        full = os.path.join(base, entry)
        rel = os.path.join(USER_DOCS, entry)
        if os.path.isfile(full) and not entry.endswith(".md"):
            failures.append(f"{rel}: only pages sit in docs/user/; put images in images/")
            continue
        if os.path.isdir(full):
            if entry != USER_IMAGES:
                failures.append(f"{rel}/: docs/user/ is flat; move these pages up a level")
                continue
            for dirpath, _dirnames, filenames in os.walk(full):
                for name in sorted(filenames):
                    if name.endswith(".md"):
                        stray = os.path.relpath(os.path.join(dirpath, name), root)
                        failures.append(f"{stray}: pages belong in docs/user/, not images/")
        elif entry.endswith(".md"):
            pages[entry] = _read_text(full) or ""

    sidebar = pages.get(USER_SIDEBAR, "")
    linked = {
        os.path.basename(unquote(url.split("#", 1)[0]))
        for _number, line in _unfenced_lines(sidebar)
        for url in _link_targets(line)
        if not SCHEME_RE.match(url)
    }
    for name in sorted(pages):
        if name not in (USER_HOME, USER_SIDEBAR) and name not in linked:
            failures.append(
                f"{os.path.join(USER_DOCS, name)}: not linked from {USER_SIDEBAR}, "
                "so the published guide cannot reach it"
            )

    slugs = {name: _heading_slugs(text) for name, text in pages.items()}
    for name, text in sorted(pages.items()):
        rel = os.path.join(USER_DOCS, name)
        for number, line in _unfenced_lines(text):
            for match in RAW_HTML_URL_RE.finditer(INLINE_CODE_RE.sub("", line)):
                url = match.group(1)
                if not (SCHEME_RE.match(url) or url.startswith(("#", "//"))):
                    failures.append(
                        f"{rel}:{number}: raw HTML link or image -> {url}; use Markdown "
                        "([text](page.md) or ![alt](images/x.png)) so the published guide resolves it"
                    )
            for url in _link_targets(line):
                if SCHEME_RE.match(url) or "#" not in url:
                    continue
                path, fragment = url.split("#", 1)
                path = unquote(path.split("?", 1)[0])
                if "/" in path or (path and path not in pages):
                    continue  # outside docs/user/, or missing: check_links reports it
                target = path or name
                fragment = unquote(fragment)
                if fragment not in slugs[target]:
                    failures.append(f"{rel}:{number}: no heading for anchor -> {url}")
                elif slugs[target][fragment] != fragment:
                    failures.append(
                        f"{rel}:{number}: docsify gives this heading the anchor "
                        f"'{slugs[target][fragment]}', not '{fragment}', so the link "
                        f"breaks on the site; reword the heading -> {url}"
                    )
    return failures


def _has_files(folder):
    """True when the folder holds a file git could track.

    git mv leaves emptied directories behind and Finder drops .DS_Store
    files; neither reaches a commit, so neither counts as the folder
    coming back.
    """
    for _dirpath, _dirnames, filenames in os.walk(folder):
        if any(name != ".DS_Store" for name in filenames):
            return True
    return False


def check_retired(root):
    failures = []
    for folder, advice in sorted(RETIRED.items()):
        if _has_files(os.path.join(root, folder)):
            failures.append(f"{folder}/ is retired: {advice}")
    return failures


def main(argv):
    root = argv[1] if len(argv) > 1 else DEFAULT_ROOT
    if not os.path.isdir(os.path.join(root, "docs")):
        print(f"{root}: no docs/ folder; pass the repository root")
        return 2
    checks = (
        ("Relative links in docs", check_links),
        ("Docs paths cited from code", check_code_refs),
        ("Retired docs folders", check_retired),
        ("User docs rules", check_user_docs),
    )
    all_ok = True
    for title, check in checks:
        failures = check(root)
        print(f"{title}: {'ok' if not failures else f'{len(failures)} problem(s)'}")
        for failure in failures:
            print(f"  FAIL  {failure}")
        all_ok = all_ok and not failures
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
