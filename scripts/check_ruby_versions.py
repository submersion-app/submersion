#!/usr/bin/env python3
"""Fail unless every ruby/setup-ruby step in the workflows pins one Ruby.

The fastlane lanes (beta, release, promote, build-all, screenshots) and the
pull-request check that installs their bundles (ci.yaml) each set up Ruby in
their own step. The install check only proves anything if it uses the Ruby
the lanes use: a bundle resolved for 3.4 can fail to install on 3.2 (#3495),
and moving off 3.2 took 11 hand edits. This keeps every copy in step.

Each setup-ruby step must name `ruby-version:` itself. Without it the action
reads a .ruby-version file, which no lane directory keeps, so the step would
run whatever Ruby the action defaults to.

Pure stdlib: the CI job that runs it has no YAML parser. Steps are found by
their `uses: ruby/setup-ruby` line and bounded by indentation.

Usage: check_ruby_versions.py [repo root]   (default: this checkout)
"""

import os
import re
import sys

_WORKFLOWS = os.path.join(".github", "workflows")
_USES_RE = re.compile(r"^\s*(-\s+)?uses:\s*['\"]?ruby/setup-ruby@")
_VERSION_RE = re.compile(r"""^\s*ruby-version:\s*['"]?(?P<v>[^'"\s#]+)""")
_DASH_RE = re.compile(r"^(?P<indent>\s*)-\s")


def _indent(line):
    return len(line) - len(line.lstrip())


def _steps(lines):
    """Yield (uses: line, ruby-version or None, line to report it at).

    A step with no ruby-version is reported at its uses: line.
    """
    for i, line in enumerate(lines):
        uses = _USES_RE.match(line)
        if not uses:
            continue
        # The step's own list item: this line when it carries the dash,
        # otherwise the nearest dash line above it. The step runs until a
        # line indented no deeper than that dash.
        start = i
        while start > 0 and not _DASH_RE.match(lines[start]):
            start -= 1
        dash = _indent(lines[start])
        version, at = None, i + 1
        for j in range(start, len(lines)):
            text = lines[j]
            if j > start and text.strip() and not text.lstrip().startswith("#"):
                if _indent(text) <= dash:
                    break
            pin = _VERSION_RE.match(text)
            if pin:
                version, at = pin.group("v"), j + 1
                break
        yield i + 1, version, at


def pins(root):
    """Return [(workflow path, uses line, version or None, version line)]."""
    found = []
    directory = os.path.join(root, _WORKFLOWS)
    try:
        names = sorted(os.listdir(directory))
    except FileNotFoundError:
        return found
    for name in names:
        if not name.endswith((".yml", ".yaml")):
            continue
        with open(os.path.join(directory, name), encoding="utf-8") as fh:
            lines = fh.read().splitlines()
        rel = os.path.join(_WORKFLOWS, name)
        found.extend((rel, *step) for step in _steps(lines))
    return found


def main(root):
    found = pins(root)
    if not found:
        print(f"No ruby/setup-ruby step found under {_WORKFLOWS}; the scan is broken.")
        return 1
    unpinned = [(path, line) for path, line, version, _ in found if version is None]
    for path, line in unpinned:
        print(f"{path}:{line}: ruby/setup-ruby step has no ruby-version")
    versions = sorted({version for _, _, version, _ in found if version})
    if len(versions) > 1:
        print(f"The workflows set up {len(versions)} Ruby versions: {', '.join(versions)}")
        for path, _, version, line in found:
            if version:
                print(f"{path}:{line}: {version}")
    if unpinned or len(versions) > 1:
        print(
            "Every fastlane lane and the bundle install check must run one Ruby "
            "(#3495). Set the same ruby-version on every ruby/setup-ruby step."
        )
        return 1
    print(f"Every ruby/setup-ruby step pins Ruby {versions[0]} ({len(found)} steps).")
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(
        main(
            sys.argv[1]
            if len(sys.argv) > 1
            else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        )
    )
