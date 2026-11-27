#!/usr/bin/env python3
"""Verify every workflow job runs scripts/apt_mirror.py before it installs.

A hosted Ubuntu runner can come up pointed at a regional EC2 mirror that
served packages at about 75 kB/s from 2026-11-18. Every job that installs
from apt then ran past its time limit, and with Web Smoke and the beta's
Linux build among them no beta shipped (issue #4722). scripts/apt_mirror.py
repoints the sources; this guard keeps a new job, or a step moved above the
call, from bringing the slow mirror back.

A job installs from apt when a line runs `apt-get install` or `apt install`
(with or without options such as `-y` before `install`), or
`playwright install --with-deps` (which runs apt-get itself). Comments and
step names are prose, not commands, and are skipped. The first such line in
a job must come after a line that runs scripts/apt_mirror.py.
The rewrite persists on the runner for the rest of the job, so later steps
in that job are covered by the one call.

Pure stdlib, like the other guards: the job that runs it installs no YAML
parser, and jobs are found by their two-space indent under `jobs:`.

Usage: check_apt_mirror.py [repo-root]
"""

import glob
import os
import re
import sys

WORKFLOW_DIR = os.path.join(".github", "workflows")
_JOBS_KEY = re.compile(r"^jobs:\s*(?:#.*)?$")
_JOB_KEY = re.compile(r"^  ([A-Za-z0-9_-]+):\s*(?:#.*)?$")
_TOP_KEY = re.compile(r"^\S")
# Options may sit between apt-get (or apt) and `install`: `-y`,
# `--no-install-recommends`, or `-o Key=value` with its value as a separate
# word. Anything else in that position is a different apt subcommand.
_APT_OPTIONS = r"(?:\s+(?:-o\s+\S+|-\S+))*"
_INSTALL = re.compile(
    r"\bapt(?:-get)?" + _APT_OPTIONS + r"\s+install\b"
    r"|playwright\s+install\s+--with-deps"
)
_MIRROR = re.compile(r"scripts/apt_mirror\.py\b")
# A step name is prose, not a command: "Check every apt install ..." is not one.
_NAME = re.compile(r"^\s*(?:-\s+)?name:")


def _jobs(text):
    """Yield (job name, lines) for each job under the top-level `jobs:` key."""
    name, lines, inside = None, [], False
    for line in text.splitlines():
        if _JOBS_KEY.match(line):
            inside = True
            continue
        if not inside:
            continue
        if _TOP_KEY.match(line):
            break
        match = _JOB_KEY.match(line)
        if match:
            if name is not None:
                yield name, lines
            name, lines = match.group(1), []
        elif name is not None:
            lines.append(line)
    if name is not None:
        yield name, lines


def unprotected_jobs(text):
    """Return the names of jobs that install from apt before the mirror call."""
    bad = []
    for name, lines in _jobs(text):
        mirrored = False
        for line in lines:
            if line.lstrip().startswith("#") or _NAME.match(line):
                continue
            if _MIRROR.search(line):
                mirrored = True
            elif _INSTALL.search(line):
                if not mirrored:
                    bad.append(name)
                break
    return bad


def main(root="."):
    failures = []
    pattern = os.path.join(root, WORKFLOW_DIR, "*.y*ml")
    for path in sorted(glob.glob(pattern)):
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        for job in unprotected_jobs(text):
            failures.append(f"{os.path.basename(path)}: job '{job}'")
    if failures:
        print(
            "These jobs install from apt without first running "
            "`sudo python3 scripts/apt_mirror.py` (issue #4722):"
        )
        for failure in failures:
            print(f"  {failure}")
        return 1
    print("Every job that installs from apt repoints the mirror first.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
