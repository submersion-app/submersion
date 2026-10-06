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

Pure stdlib. Usage: check_docs_links.py [repo-root]
"""

import os
import re
import sys
from urllib.parse import unquote

LINK_ROOTS = (
    os.path.join("docs", "README.md"),
    os.path.join("docs", "developer"),
    os.path.join("docs", "contributing"),
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

LINK_RE = re.compile(r"\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
FENCE_RE = re.compile(r"^\s*(```|~~~)")
SCHEME_RE = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
CODE_REF_RE = re.compile(
    r"docs/(?:user|developer|contributing|design|releases|assets)/"
    r"[A-Za-z0-9_./-]+\.(?:md|html|png|jpg|json)\b"
)
# Folders the restructure retired, and where their files went. The
# lookbehind skips "docs/" inside a longer path or URL.
RETIRED_REF_HOMES = {
    "superpowers": "docs/design/",
    "plans": "docs/design/specs/ or docs/design/plans/",
    "api": "docs/developer/reference/",
    "import-formats": "docs/developer/reference/formats/",
}
RETIRED_REF_RE = re.compile(
    r"(?<![A-Za-z0-9_./-])docs/(superpowers|plans|api|import-formats)/"
    r"[A-Za-z0-9_./-]+\.(?:md|html|png|jpg|json)\b"
)


def _markdown_files(root):
    for entry in LINK_ROOTS:
        full = os.path.join(root, entry)
        if os.path.isfile(full):
            yield entry
        elif os.path.isdir(full):
            for dirpath, dirnames, filenames in os.walk(full):
                dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
                for name in sorted(filenames):
                    if name.endswith(".md"):
                        yield os.path.relpath(os.path.join(dirpath, name), root)


def _unfenced_lines(text):
    in_fence = False
    for number, line in enumerate(text.splitlines(), 1):
        if FENCE_RE.match(line):
            in_fence = not in_fence
            continue
        if not in_fence:
            yield number, line


def check_links(root):
    failures = []
    for rel in _markdown_files(root):
        with open(os.path.join(root, rel), encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        base = os.path.dirname(os.path.join(root, rel))
        for number, line in _unfenced_lines(text):
            for match in LINK_RE.finditer(line):
                url = match.group(1)
                if SCHEME_RE.match(url) or url.startswith(("#", "/")):
                    continue
                target = unquote(url.split("#", 1)[0].split("?", 1)[0])
                if not target:
                    continue
                if not os.path.exists(os.path.normpath(os.path.join(base, target))):
                    failures.append(f"{rel}:{number}: broken link -> {url}")
    return failures


def _code_files(root):
    for entry in CODE_REF_SOURCES:
        full = os.path.join(root, entry)
        if os.path.isfile(full):
            yield entry
        elif os.path.isdir(full):
            for dirpath, dirnames, filenames in os.walk(full):
                dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
                for name in sorted(filenames):
                    rel = os.path.relpath(os.path.join(dirpath, name), root)
                    if rel not in NOT_SCANNED:
                        yield rel


def check_code_refs(root):
    failures = []
    for rel in _code_files(root):
        try:
            with open(os.path.join(root, rel), encoding="utf-8") as fh:
                lines = fh.read().splitlines()
        except (UnicodeDecodeError, OSError):
            continue
        for number, line in enumerate(lines, 1):
            for match in CODE_REF_RE.finditer(line):
                ref = match.group(0)
                if not os.path.exists(os.path.join(root, *ref.split("/"))):
                    failures.append(f"{rel}:{number}: missing docs path -> {ref}")
            for match in RETIRED_REF_RE.finditer(line):
                home = RETIRED_REF_HOMES[match.group(1)]
                failures.append(
                    f"{rel}:{number}: retired docs path -> {match.group(0)} "
                    f"(its file now lives under {home})"
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
    root = argv[1] if len(argv) > 1 else os.getcwd()
    checks = (
        ("Relative links in docs", check_links),
        ("Docs paths cited from code", check_code_refs),
        ("Retired docs folders", check_retired),
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
