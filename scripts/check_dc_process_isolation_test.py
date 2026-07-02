#!/usr/bin/env python3
"""Unit tests for check_dc_process_isolation.py."""

import importlib.util
import io
import contextlib
import os
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "check_dc_process_isolation",
    os.path.join(_HERE, "check_dc_process_isolation.py"),
)
guard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guard)

GREEN = """\
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.submersion.libdivecomputer">
    <application>
        <service
            android:name=".DiveDownloadService"
            android:process=":dc"
            android:exported="false" />
    </application>
</manifest>
"""

# Service present but NOT in its own process -> a native crash would kill the app.
RED_NO_PROCESS = """\
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application>
        <service android:name=".DiveDownloadService" android:exported="false" />
    </application>
</manifest>
"""

RED_NO_SERVICE = """\
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application />
</manifest>
"""


class GuardTests(unittest.TestCase):
    def test_green_has_no_violations(self):
        self.assertEqual(guard.find_violations(GREEN), [])

    def test_service_without_process_is_flagged(self):
        v = guard.find_violations(RED_NO_PROCESS)
        self.assertTrue(any("process" in x for x in v))

    def test_missing_service_is_flagged(self):
        v = guard.find_violations(RED_NO_SERVICE)
        self.assertTrue(any("DiveDownloadService" in x for x in v))

    def test_check_file_ok(self):
        fd, p = tempfile.mkstemp(suffix=".xml")
        with os.fdopen(fd, "w") as fh:
            fh.write(GREEN)
        self.addCleanup(os.unlink, p)
        ok, _ = guard.check_file(p)
        self.assertTrue(ok)

    def test_main_fails_on_red(self):
        fd, p = tempfile.mkstemp(suffix=".xml")
        with os.fdopen(fd, "w") as fh:
            fh.write(RED_NO_PROCESS)
        self.addCleanup(os.unlink, p)
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = guard.main(["prog", p])
        self.assertEqual(rc, 1)

    def test_main_passes_on_green(self):
        fd, p = tempfile.mkstemp(suffix=".xml")
        with os.fdopen(fd, "w") as fh:
            fh.write(GREEN)
        self.addCleanup(os.unlink, p)
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = guard.main(["prog", p])
        self.assertEqual(rc, 0)
        self.assertIn("PASS", buf.getvalue())

    def test_main_reports_unreadable_path(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = guard.main(["prog", os.path.join(_HERE, "does_not_exist.xml")])
        self.assertEqual(rc, 1)
        self.assertIn("ERROR", buf.getvalue())


if __name__ == "__main__":
    unittest.main()
