#!/usr/bin/env python3
"""Fail when a JUnit XML report ran no tests, or skipped any.

pytest exits 0 when every test skips, so a browser test that could not run
(a missing Playwright browser, no MinIO) would pass its CI step quietly. The
web smoke and stream worker steps write `--junitxml` reports and pass each
one here with a label for the log line. Pure stdlib.

Usage: check_junit_ran.py <label> <report.xml>
"""

import sys
import xml.etree.ElementTree as ET


def counts(root):
    """(tests, skipped), summed over the report's test suites."""
    suites = [root] if root.tag == "testsuite" else list(root)
    tests = sum(int(suite.get("tests", 0)) for suite in suites)
    skipped = sum(int(suite.get("skipped", 0)) for suite in suites)
    return tests, skipped


def main(argv):
    if len(argv) != 3:
        print("usage: check_junit_ran.py <label> <report.xml>")
        return 2
    label, path = argv[1], argv[2]
    tests, skipped = counts(ET.parse(path).getroot())
    print(f"{label} tests {tests} skipped {skipped}")
    return 1 if tests == 0 or skipped else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
