#!/usr/bin/env python3
"""Fail when a `flutter test` JSON report shows a skipped test, or no tests.

A skipped test exits 0, and so does a file whose tests never ran. That is how
the AVFoundation transcoder integration test skipped on every CI run ("ffmpeg
not on PATH") while `Integration Test (macOS)` stayed green (#2940). CI writes
one report per integration test file with `--file-reporter json:<path>` and
passes them all here, so a test that stops running fails the job instead of
passing quietly.

Reads the test package's JSON reporter protocol: one JSON object per line.
Hidden tests (the "loading <file>" pseudo-test, setUpAll and tearDownAll) are
not the file's own tests and are ignored. Pure stdlib.

Usage: check_no_skipped_tests.py <report.json> [<report.json> ...]
"""

import json
import sys
from collections import namedtuple

# ran: count of visible tests that finished without skipping.
# skipped: (test name, skip reason) for each visible test that skipped.
Summary = namedtuple("Summary", ["ran", "skipped"])


def summarize(lines):
    """Summarize the JSON reporter events in `lines` (an iterable of str)."""
    names = {}
    reasons = {}
    ran = 0
    skipped = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except ValueError:
            # flutter_tools can interleave plain log lines; they are not events.
            continue
        kind = event.get("type")
        if kind == "testStart":
            test = event.get("test", {})
            names[test.get("id")] = test.get("name", "<unnamed>")
            reason = (test.get("metadata") or {}).get("skipReason")
            if reason:
                reasons[test.get("id")] = reason
        elif kind == "print" and event.get("messageType") == "skip":
            reasons[event.get("testID")] = event.get("message", "")
        elif kind == "testDone" and not event.get("hidden"):
            test_id = event.get("testID")
            if event.get("skipped"):
                skipped.append((names.get(test_id, "<unknown>"),
                                reasons.get(test_id, "no reason given")))
            else:
                ran += 1
    return Summary(ran, skipped)


def check_report(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        summary = summarize(fh)
    lines = []
    for name, reason in summary.skipped:
        lines.append(f"  FAIL  skipped: {name} ({reason})")
    if summary.ran == 0 and not summary.skipped:
        lines.append("  FAIL  no tests ran")
    ok = not lines
    if ok:
        plural = "test" if summary.ran == 1 else "tests"
        lines.append(f"  ok    {summary.ran} {plural} ran, none skipped")
    return ok, lines


def main(argv):
    paths = argv[1:]
    if not paths:
        print("FAIL: no test reports were given, so no tests ran")
        return 1
    all_ok = True
    for path in paths:
        print(f"Checking test report: {path}")
        try:
            ok, lines = check_report(path)
        except OSError as exc:
            print(f"  ERROR reading {path}: {exc}")
            all_ok = False
            continue
        for line in lines:
            print(line)
        all_ok = all_ok and ok
    print("  -> PASS" if all_ok else "  -> FAIL: a test skipped or did not run")
    return 0 if all_ok else 1


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv))
