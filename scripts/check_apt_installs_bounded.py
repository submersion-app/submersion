#!/usr/bin/env python3
"""Verify every workflow installs apt packages through the bounded local action.

A bare `apt-get install` has no time limit of its own. On run 40535224550 a
runner fetched the Linux integration job's 89 MB of packages from the Ubuntu
mirror at about 50 KB/s, and the job reached its 25 minute limit twice while
still downloading; healthy runners finish the same step in 30 seconds
(issue #3751).

`.github/actions/install-apt-packages` downloads under a time limit, retries
on a fresh connection, and can cache the .deb files. This guard keeps it that
way, in three parts:

* No workflow, and no other local action, runs an apt or apt-get command
  that can reach the mirror (install, update, upgrade and the rest) directly
  in its `run:` scripts. A new job copied from an old example would otherwise
  bring back the unbounded download. Scripts those steps call are not read:
  scripts/release/verify_linux_package.sh still installs packages with
  apt-get, inside the containers that check the release packages.
* The local action really bounds the network: every apt-get call that can
  reach the mirror runs under `timeout`, the bounded install is
  `--download-only` (a limit that fires while dpkg unpacks would leave a
  broken package database behind), the install after it is `--no-download`,
  and the download runs inside a loop of at least two attempts.
* The workflows in UNCACHED_WORKFLOWS pass `cache: false` explicitly, because
  apt reuses a cached .deb after checking only its size. The action's cache
  is off by default; the explicit value keeps these workflows safe even if
  that default changes.

Pure stdlib, like the other guards: the job that runs it installs no YAML
parser, and the few things checked here are matched line by line.

Usage: check_apt_installs_bounded.py [repo-root]
"""

import collections
import os
import re
import sys

ACTIONS_DIR = os.path.join(".github", "actions")
ACTION_PATH = os.path.join(ACTIONS_DIR, "install-apt-packages", "action.yml")
WORKFLOW_DIR = os.path.join(".github", "workflows")
# What a workflow step names in `uses:` to get the bounded action.
LOCAL_REF = "./.github/actions/install-apt-packages"

# Workflows that must not cache apt packages, each with the reason.
UNCACHED_WORKFLOWS = {
    "build-all.yml": (
        "it builds the release artifacts, and apt reuses a cached .deb after "
        "checking only its size, so a tampered cache entry would ship"
    ),
}

# apt and apt-get subcommands that never reach the network.
LOCAL_SUBCOMMANDS = {
    "autoclean",
    "autopurge",
    "autoremove",
    "clean",
    "list",
    "policy",
    "purge",
    "remove",
    "search",
    "show",
}
# apt-get options that take the next token as their argument.
_OPTIONS_WITH_ARGUMENT = {
    "-a",
    "-c",
    "-o",
    "-t",
    "--config-file",
    "--default-release",
    "--host-architecture",
    "--option",
    "--target-release",
}

_COMMENT = r"\s*(?:#.*)?$"
_RUN_KEY = re.compile(r"^\s*(?:-\s+)?run:(.*)$")
_STEP_START = re.compile(r"^(\s*)-\s")
# A workflow that builds an older ref checks the action out beside it, so the
# path may carry one leading directory (build-all.yml uses ./.ci-actions/).
_USES_LOCAL = re.compile(
    r"^\s*(?:-\s+)?uses:\s*['\"]?\./(?:[\w.-]+/)?"
    + re.escape(LOCAL_REF[2:])
    + r"['\"]?"
    + _COMMENT
)
_CACHE_OFF = re.compile(r"^\s*cache:\s*(['\"]?)false\1" + _COMMENT)
_ATTEMPTS = re.compile(r"^\s*attempts=(\d+)\s*$")
_RETRY_LOOP = re.compile(
    r'^(\s*)for\s+\w+\s+in\s+\$\(seq\s+1\s+"?\$\{?attempts\}?"?\)\s*;\s*do\s*$'
)
_SHELL_OPERATOR = re.compile(r"&&|\|\||;|\|")

Call = collections.namedtuple(
    "Call", "line command subcommand options packages bounded"
)


def _indent(line):
    return len(line) - len(line.lstrip())


def _run_lines(text):
    """Yield (line number, text) for every line of every `run:` script."""
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        match = _RUN_KEY.match(lines[i])
        if not match:
            i += 1
            continue
        inline = match.group(1).strip()
        if inline and not inline.startswith(("|", ">")):
            yield i + 1, inline
            i += 1
            continue
        key_indent = lines[i].index("run:")
        i += 1
        while i < len(lines) and (
            not lines[i].strip() or _indent(lines[i]) > key_indent
        ):
            yield i + 1, lines[i]
            i += 1


def _logical_lines(text):
    """Yield (first line number, text) of each shell line, continuations joined.

    Comment lines are dropped: a commented-out install installs nothing.
    """
    start, parts = None, []
    for number, line in _run_lines(text):
        stripped = line.strip()
        if not parts and (not stripped or stripped.startswith("#")):
            continue
        if not parts:
            start = number
        if stripped.endswith("\\"):
            parts.append(stripped[:-1])
            continue
        parts.append(stripped)
        yield start, " ".join(parts)
        start, parts = None, []
    if parts:
        yield start, " ".join(parts)


def _basename(token):
    return token.rsplit("/", 1)[-1]


def apt_calls(text):
    """Return every apt or apt-get command in the file's `run:` scripts."""
    calls = []
    for number, line in _logical_lines(text):
        for command in _SHELL_OPERATOR.split(line):
            tokens = command.split()
            names = [_basename(t) for t in tokens]
            index = next(
                (i for i, n in enumerate(names) if n in ("apt", "apt-get")), None
            )
            if index is None:
                continue
            options, operands, skip = [], [], False
            for token in tokens[index + 1 :]:
                if skip:
                    skip = False
                elif token.startswith("-"):
                    options.append(token)
                    skip = token in _OPTIONS_WITH_ARGUMENT
                else:
                    operands.append(token)
            if not operands:
                continue
            calls.append(
                Call(
                    line=number,
                    command=names[index],
                    subcommand=operands[0],
                    options=options,
                    packages=operands[1:],
                    bounded="timeout" in names[:index],
                )
            )
    return calls


def _retry_loops(text):
    """Return (first, last) line numbers of each `for ... in $(seq 1 "$attempts")`."""
    loops, open_loops = [], []
    for number, line in _run_lines(text):
        match = _RETRY_LOOP.match(line)
        if match:
            open_loops.append((len(match.group(1)), number))
        elif open_loops and line.strip() == "done":
            indent, first = open_loops[-1]
            if _indent(line) == indent:
                open_loops.pop()
                loops.append((first, number))
    return loops


def _attempt_count(text):
    """Return N from the action's `attempts=N`, or None if it sets none."""
    for _, line in _run_lines(text):
        match = _ATTEMPTS.match(line)
        if match:
            return int(match.group(1))
    return None


def action_violations(text):
    """Return what keeps the local action from bounding apt; empty == bounded."""
    violations = []
    bounded_downloads = []
    for call in apt_calls(text):
        name = f"{call.command} {call.subcommand}"
        if call.subcommand in LOCAL_SUBCOMMANDS:
            continue
        if call.subcommand == "install":
            if "--no-download" in call.options:
                continue
            if call.bounded and "--download-only" in call.options:
                bounded_downloads.append(call.line)
                continue
            if call.bounded:
                violations.append(
                    f"line {call.line}: {name} runs under a time limit without "
                    "--download-only; a limit that fires while dpkg unpacks "
                    "leaves a broken package database for the retry"
                )
                continue
        if not call.bounded:
            violations.append(
                f"line {call.line}: {name} can reach the mirror without a time "
                "limit, so a slow mirror holds the job until its own timeout"
            )
    if not bounded_downloads:
        violations.append(
            "never downloads under a time limit (apt-get install "
            "--download-only run by timeout), so nothing bounds the download"
        )
    count = _attempt_count(text)
    if count is None:
        violations.append(
            "has no retry loop (attempts=N), so one slow connection fails the "
            "job instead of retrying on a fresh one"
        )
    elif count < 2:
        noun = "attempt" if count == 1 else "attempts"
        violations.append(
            f"makes {count} {noun} at the download; it needs at least 2, so "
            "one slow connection cannot fail the job"
        )
    loops = _retry_loops(text)
    for line in bounded_downloads:
        if not any(first < line < last for first, last in loops):
            violations.append(
                f"line {line}: the bounded download is not inside a "
                '`for attempt in $(seq 1 "$attempts")` loop, so it runs once '
                "however many attempts are set"
            )
    return violations


def direct_calls(text):
    """Return the line numbers of apt calls that reach the mirror unbounded."""
    return [
        call.line
        for call in apt_calls(text)
        if call.subcommand not in LOCAL_SUBCOMMANDS
    ]


def _step_end(lines, start, dash_indent):
    """Return the index just past the step whose `- ` line is at `start`."""
    end = start + 1
    while end < len(lines):
        line = lines[end]
        if line.strip() and not line.lstrip().startswith("#"):
            if _indent(line) <= dash_indent:
                break
        end += 1
    return end


def cached_uses(text):
    """Return the `uses:` line numbers of local action steps that cache."""
    lines = text.splitlines()
    found = []
    for index, line in enumerate(lines):
        if not _USES_LOCAL.match(line):
            continue
        start, match = index, None
        while start >= 0:
            match = _STEP_START.match(lines[start])
            if match and len(match.group(1)) < lines[index].index("uses:"):
                break
            start -= 1
        if start < 0:
            continue
        dash_indent = len(match.group(1))
        step = lines[start : _step_end(lines, start, dash_indent)]
        if not any(_CACHE_OFF.match(ln) for ln in step):
            found.append(index + 1)
    return found


def _read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def _caller_files(root):
    """Return every workflow, and every other local action, relative to root.

    Other local actions count as callers too: a composite action that ran
    apt-get itself would bring the unbounded download back into every workflow
    that uses it. Raises OSError if the workflow directory is missing.
    """
    names = sorted(os.listdir(os.path.join(root, WORKFLOW_DIR)))
    files = [
        os.path.join(WORKFLOW_DIR, n) for n in names if n.endswith((".yml", ".yaml"))
    ]
    actions = []
    for dirpath, _, filenames in os.walk(os.path.join(root, ACTIONS_DIR)):
        for meta in ("action.yml", "action.yaml"):
            if meta in filenames:
                rel = os.path.relpath(os.path.join(dirpath, meta), root)
                if rel != ACTION_PATH:
                    actions.append(rel)
    return files + sorted(actions)


def find_violations(root):
    """Return a list of violation strings for the repository at `root`."""
    violations = []
    try:
        action = _read(os.path.join(root, ACTION_PATH))
    except OSError:
        violations.append(
            f"{ACTION_PATH} is missing, so workflows have no bounded apt install"
        )
    else:
        violations.extend(f"{ACTION_PATH}: {v}" for v in action_violations(action))

    try:
        callers = _caller_files(root)
    except OSError as exc:
        return violations + [f"cannot list {WORKFLOW_DIR}: {exc}"]
    for rel in callers:
        text = _read(os.path.join(root, rel))
        for number in direct_calls(text):
            violations.append(
                f"{rel}:{number} runs apt directly with no time limit; use "
                f"{LOCAL_REF}, which bounds the download and retries it"
            )
        reason = UNCACHED_WORKFLOWS.get(os.path.basename(rel))
        if reason and rel.startswith(WORKFLOW_DIR):
            for number in cached_uses(text):
                violations.append(
                    f"{rel}:{number} uses {LOCAL_REF} without cache: false; "
                    f"{reason}"
                )
    return violations


def main(argv):
    root = argv[1] if len(argv) > 1 else "."
    print(f"Checking apt installs are bounded: {os.path.abspath(root)}")
    violations = find_violations(root)
    for violation in violations:
        print(f"  FAIL  {violation}")
    if violations:
        print("  -> FAIL: a slow package mirror can hold a job until it times out")
        return 1
    print(f"  ok    every workflow installs apt packages through {LOCAL_REF}")
    print("  -> PASS")
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv))
