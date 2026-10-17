#!/usr/bin/env python3
"""Verify every workflow sets up Flutter through the retrying local action.

`subosito/flutter-action` downloads the Flutter SDK with curl. Its own
`--retry 5` only covers the errors curl counts as transient, and a connection
that stalls mid-transfer (exit 56, "Recv failure: Operation timed out") is not
one of them. That is how run 36852093336 turned `main` red on 2026-10-01: the
Build macOS job lost its SDK download before compiling anything (issue #2765).

`.github/actions/setup-flutter` wraps the upstream action in a step-level
retry. This guard keeps it that way, in two halves:

* No workflow calls `subosito/flutter-action` directly. A new job copied from
  an old example would otherwise bring back the unretried setup.
* The local action really retries: at least two attempts, every attempt but
  the last with `continue-on-error: true` (or the first failure ends the
  action before a retry runs), and the last without it (or an outage that
  outlasts every retry would leave the job running with no Flutter at all).

Pure stdlib, like the other guards: the job that runs it installs no YAML
parser, and the few keys checked here are matched line by line.

Usage: check_flutter_setup_retried.py [repo-root]
"""

import os
import re
import sys

UPSTREAM = "subosito/flutter-action"
ACTION_PATH = os.path.join(".github", "actions", "setup-flutter", "action.yml")
WORKFLOW_DIR = os.path.join(".github", "workflows")
# What a workflow step names in `uses:` to get the retrying action.
LOCAL_REF = "./.github/actions/setup-flutter"

# Every pattern tolerates quotes around the value and a trailing `# comment`,
# both valid YAML that carry no meaning here.
_COMMENT = r"\s*(?:#.*)?$"
_USES_UPSTREAM = re.compile(
    r"^\s*(?:-\s+)?uses:\s*['\"]?" + re.escape(UPSTREAM) + r"@"
)
_TOLERATES = re.compile(
    r"^\s*(?:-\s+)?continue-on-error:\s*(['\"]?)true\1" + _COMMENT
)
_STEPS_KEY = re.compile(r"^\s*steps:" + _COMMENT)
_STEP_START = re.compile(r"^(\s*)-\s")


def _is_comment(line):
    return line.lstrip().startswith("#")


def _steps(text):
    """Return each step under the first `steps:` key, as a list of its lines.

    A step runs from its `- ` line to the next `- ` at the same indent, or to
    the first line indented less than the steps themselves. Comment lines are
    dropped: a commented-out attempt is not an attempt.
    """
    lines = [ln for ln in text.splitlines() if not _is_comment(ln)]
    try:
        start = next(i for i, ln in enumerate(lines) if _STEPS_KEY.match(ln)) + 1
    except StopIteration:
        return []
    steps, current, indent = [], None, None
    for line in lines[start:]:
        if not line.strip():
            continue
        width = len(line) - len(line.lstrip())
        match = _STEP_START.match(line)
        if indent is None:
            if not match:
                break
            indent = len(match.group(1))
        if width < indent:
            break
        if match and len(match.group(1)) == indent:
            current = [line]
            steps.append(current)
        else:
            current.append(line)
    return steps


def flutter_attempts(text):
    """Return the steps of an action that run the upstream action, in order."""
    return [
        step for step in _steps(text) if any(_USES_UPSTREAM.match(ln) for ln in step)
    ]


def tolerates_failure(step):
    """Return True if the step sets `continue-on-error: true`."""
    return any(_TOLERATES.match(ln) for ln in step)


def action_violations(text):
    """Return what keeps the local action from retrying; empty == it retries."""
    attempts = flutter_attempts(text)
    count = len(attempts)
    if count < 2:
        noun = "attempt" if count == 1 else "attempts"
        return [
            f"runs {count} {noun} of {UPSTREAM} -- it needs at least 2, so one "
            "failed SDK download cannot fail the job"
        ]
    violations = []
    for number, step in enumerate(attempts[:-1], start=1):
        if not tolerates_failure(step):
            violations.append(
                f"attempt {number} of {UPSTREAM} lacks continue-on-error: true "
                "-- its failure ends the action before any retry runs"
            )
    if tolerates_failure(attempts[-1]):
        violations.append(
            f"the final attempt of {UPSTREAM} sets continue-on-error -- an "
            "outage that outlasts every retry would leave the job running "
            "without Flutter instead of failing at setup"
        )
    return violations


def direct_uses(text):
    """Return the 1-based line numbers of steps that call the upstream action."""
    return [
        number
        for number, line in enumerate(text.splitlines(), start=1)
        if _USES_UPSTREAM.match(line)
    ]


def _read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def find_violations(root):
    """Return a list of violation strings for the repository at `root`."""
    violations = []
    try:
        action = _read(os.path.join(root, ACTION_PATH))
    except OSError:
        violations.append(
            f"{ACTION_PATH} is missing -- workflows have no retrying Flutter setup"
        )
    else:
        violations.extend(f"{ACTION_PATH}: {v}" for v in action_violations(action))

    workflow_dir = os.path.join(root, WORKFLOW_DIR)
    try:
        names = sorted(os.listdir(workflow_dir))
    except OSError as exc:
        return violations + [f"cannot list {WORKFLOW_DIR}: {exc}"]
    for name in names:
        if not name.endswith((".yml", ".yaml")):
            continue
        rel = os.path.join(WORKFLOW_DIR, name)
        for number in direct_uses(_read(os.path.join(workflow_dir, name))):
            violations.append(
                f"{rel}:{number} uses {UPSTREAM} directly -- use {LOCAL_REF}, "
                "which retries a failed SDK download"
            )
    return violations


def main(argv):
    root = argv[1] if len(argv) > 1 else "."
    print(f"Checking Flutter setup is retried: {os.path.abspath(root)}")
    violations = find_violations(root)
    for violation in violations:
        print(f"  FAIL  {violation}")
    if violations:
        print("  -> FAIL: a transient SDK download failure can turn CI red")
        return 1
    print(f"  ok    every workflow sets up Flutter through {LOCAL_REF}")
    print("  -> PASS")
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv))
