#!/usr/bin/env python3
"""Unit tests for check_junit_ran.py."""

import importlib.util
import io
import os
import tempfile
import unittest
from contextlib import redirect_stdout

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "check_junit_ran",
    os.path.join(_HERE, "check_junit_ran.py"),
)
checker = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(checker)


def _report(xml):
    handle = tempfile.NamedTemporaryFile(
        "w", suffix=".xml", delete=False, encoding="utf-8"
    )
    with handle:
        handle.write(xml)
    return handle.name


class CheckJunitRanTest(unittest.TestCase):
    def run_main(self, xml):
        path = _report(xml)
        self.addCleanup(os.remove, path)
        out = io.StringIO()
        with redirect_stdout(out):
            code = checker.main(["check_junit_ran.py", "stream", path])
        return code, out.getvalue()

    def test_tests_that_ran_pass(self):
        code, out = self.run_main(
            '<testsuites><testsuite tests="10" skipped="0"/></testsuites>'
        )
        self.assertEqual(code, 0)
        self.assertEqual(out.strip(), "stream tests 10 skipped 0")

    def test_a_bare_testsuite_root_is_read(self):
        code, _ = self.run_main('<testsuite tests="3" skipped="0"/>')
        self.assertEqual(code, 0)

    def test_suites_are_summed(self):
        code, out = self.run_main(
            "<testsuites>"
            '<testsuite tests="2" skipped="0"/>'
            '<testsuite tests="3" skipped="1"/>'
            "</testsuites>"
        )
        self.assertEqual(code, 1)
        self.assertEqual(out.strip(), "stream tests 5 skipped 1")

    def test_a_skip_fails(self):
        code, _ = self.run_main('<testsuite tests="4" skipped="1"/>')
        self.assertEqual(code, 1)

    def test_no_tests_fails(self):
        code, _ = self.run_main('<testsuites><testsuite tests="0"/></testsuites>')
        self.assertEqual(code, 1)

    def test_wrong_arguments_are_a_usage_error(self):
        with redirect_stdout(io.StringIO()):
            self.assertEqual(checker.main(["check_junit_ran.py"]), 2)


if __name__ == "__main__":
    unittest.main()
