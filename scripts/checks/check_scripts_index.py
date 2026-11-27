#!/usr/bin/env python3
"""Keep every script findable from scripts/README.md (issue #5100).

scripts/ grew to about a hundred loose entries, and the maintainer and agent
sessions lost time hunting for the one they needed. The cleanup grouped them
into purpose folders and wrote scripts/README.md, an index of every script.
This guard keeps that true:

1. Every script under scripts/ or tool/ is named in scripts/README.md. A
   script is a .py, .sh or .rb file, or a .dart file with a top-level main().
   Tests (names ending _test.<ext>), conftest.py, __init__.py and anything
   under a fixtures/ folder are not scripts.
2. Every scripts/ or tool/ path the index names in a code span exists, as a
   file or as a folder holding one.
3. Only README.md, setup.sh and requirements.txt sit at the top of scripts/.
4. No file lives in a folder the cleanup retired.
5. Every scripts/ or tool/ path named in .github/, hooks/pre-push, a fastlane
   Fastfile or an Xcode project exists (a glob's folder must hold a file).
   Some workflows run only on a schedule, a release or a tag, so a path that
   moved would otherwise fail days after the move. A path written behind a
   shell variable ($GITHUB_WORKSPACE/scripts/x.py), an expression, a quote,
   a subshell or ../ (a step run from ios/) counts; one after another path
   segment (packages/foo/tool/x.dart) or ~/ does not. A line carrying
   the marker `scripts-layout: legacy` is skipped: the pre-push hook names
   the pre-#5100 paths on purpose, for branches cut before the move.

Pure stdlib, like the other guards. Files come from `git ls-files`, so a
local virtualenv or scratch output under scripts/ is never reported.

Usage: check_scripts_index.py [--root REPO_ROOT] [--files PATH ...]
"""

import argparse
import os
import re
import subprocess
import sys

INDEX = "scripts/README.md"
TOP_LEVEL_ALLOWED = {"README.md", "setup.sh", "requirements.txt"}
RETIRED = ("tools/", "codemaps/", ".reports/", "scripts/data/", "scripts/fixtures/")
SCRIPT_EXTENSIONS = (".py", ".sh", ".rb", ".dart")
NOT_SCRIPTS = {"conftest.py", "__init__.py"}

_CODE_SPAN = re.compile(r"`([^`\n]+)`")
_DART_MAIN = re.compile(
    r"^(?:(?:void|Future<void>|Future)[ \t]+)?main[ \t]*\(", re.MULTILINE
)
_WORKFLOW_PATH = re.compile(
    r"(?:scripts|tool)/[\w./-]*?\.(?:py|sh|rb|dart|json|txt|lock|ya?ml|md|toml)(?![\w-])"
)
_WORKFLOW_GLOB = re.compile(r"(?:scripts|tool)/[\w./-]*\*")
_SHELL_VARIABLE_END = re.compile(r"\$(?:\w+|\{\w+\})$")
LEGACY_MARKER = "scripts-layout: legacy"


def _read(root, rel):
    try:
        with open(os.path.join(root, *rel.split("/")), encoding="utf-8") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError):
        return ""


def _is_script(root, rel):
    if not rel.startswith(("scripts/", "tool/")):
        return False
    name = rel.rsplit("/", 1)[-1]
    stem, ext = os.path.splitext(name)
    if ext not in SCRIPT_EXTENSIONS or name in NOT_SCRIPTS:
        return False
    if stem.endswith("_test") or "/fixtures/" in rel:
        return False
    if ext == ".dart":
        return bool(_DART_MAIN.search(_read(root, rel)))
    return True


def _index_entries(root, files):
    if INDEX not in files:
        return set()
    entries = set()
    for span in _CODE_SPAN.findall(_read(root, INDEX)):
        token = span.split()[0] if span.split() else ""
        if token.startswith(("scripts/", "tool/")):
            entries.add(token)
    return entries


def _counts_as_path(text, start):
    """True when the match at `start` is a repository-root path.

    It is when it starts a word, or follows "./", any run of "../" (a step
    run from ios/, a Fastfile, an Xcode build phase), a shell variable, an
    expression (`${{ ... }}/`), a closing quote (`"$ROOT"/`) or a subshell
    (`$(pwd)/`). After a path segment (packages/foo/tool/), `~/` or a bare
    leading `/` (an absolute path) it is some other folder's.
    """
    if start == 0:
        return True
    before = text[start - 1]
    if before != "/":
        return not (before.isalnum() or before in "_.-")
    head = text[: start - 1]
    if not head:
        return False
    if head.endswith("..") or _SHELL_VARIABLE_END.search(head):
        return True
    if head[-1] in "}\"')":
        return True
    # "./scripts/x.sh" is root-relative.
    return head.endswith(".") and (
        len(head) == 1 or not (head[-2].isalnum() or head[-2] in "_/-.")
    )


def _scans_for_paths(rel):
    """Files whose script paths must exist: CI, the hook, fastlane, Xcode."""
    return (
        rel.startswith(".github/")
        or rel == "hooks/pre-push"
        or rel.rsplit("/", 1)[-1] == "Fastfile"
        or rel.endswith(".xcodeproj/project.pbxproj")
    )


def _on_legacy_line(text, match):
    line_start = text.rfind("\n", 0, match.start()) + 1
    line_end = text.find("\n", match.end())
    return LEGACY_MARKER in text[line_start : line_end if line_end != -1 else None]


def _workflow_problems(root, files, file_set):
    problems = []
    for rel in files:
        if not _scans_for_paths(rel):
            continue
        text = _read(root, rel)
        seen = set()
        for match in _WORKFLOW_PATH.finditer(text):
            path = match.group(0)
            if path in seen or path in file_set:
                continue
            if not _counts_as_path(text, match.start()) or _on_legacy_line(text, match):
                continue
            seen.add(path)
            problems.append(
                f"{rel}: names {path}, which does not exist: "
                "the file moved or was deleted; update the path"
            )
        for match in _WORKFLOW_GLOB.finditer(text):
            prefix = match.group(0).split("*", 1)[0]
            prefix = prefix[: prefix.rfind("/") + 1]
            if prefix in seen or any(f.startswith(prefix) for f in files):
                continue
            if not _counts_as_path(text, match.start()) or _on_legacy_line(text, match):
                continue
            seen.add(prefix)
            problems.append(
                f"{rel}: names the folder {prefix}, which holds no file: "
                "the folder moved or was deleted; update the path"
            )
    return problems


def find_problems(root, files):
    """Return one message per broken rule; `files` are repo-relative paths."""
    file_set = set(files)
    entries = _index_entries(root, file_set)
    problems = []

    for rel in files:
        if _is_script(root, rel) and rel not in entries:
            problems.append(f"{rel}: not in {INDEX}: add it to {INDEX}")

    for entry in sorted(entries):
        folder = entry if entry.endswith("/") else entry + "/"
        if entry not in file_set and not any(f.startswith(folder) for f in files):
            problems.append(
                f"{INDEX}: names {entry}, which does not exist: "
                "remove or correct the index entry"
            )

    for rel in files:
        parts = rel.split("/")
        if len(parts) == 2 and parts[0] == "scripts" and parts[1] not in TOP_LEVEL_ALLOWED:
            problems.append(
                f"{rel}: only {', '.join(sorted(TOP_LEVEL_ALLOWED))} sit at the top "
                f"of scripts/: move it into a purpose folder (see {INDEX}) and index it"
            )

    for folder in RETIRED:
        holders = [f for f in files if f.startswith(folder)]
        if holders:
            problems.append(
                f"{folder}: retired by the scripts cleanup (#5100) but holds "
                f"{holders[0]}: move it to its purpose folder (see {INDEX})"
            )

    problems.extend(_workflow_problems(root, files, file_set))
    return problems


def _tracked_files(root):
    out = subprocess.run(
        ["git", "ls-files", "-z"], cwd=root, check=True, capture_output=True
    ).stdout
    return sorted(p for p in out.decode("utf-8").split("\0") if p)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    default_root = os.path.dirname(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    )
    parser.add_argument("--root", default=default_root)
    parser.add_argument("--files", nargs="*", help="tracked paths (default: git ls-files)")
    args = parser.parse_args(argv)
    files = sorted(args.files) if args.files is not None else _tracked_files(args.root)
    problems = find_problems(args.root, files)
    for problem in problems:
        print(problem)
    return 1 if problems else 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
