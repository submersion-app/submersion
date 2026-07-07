#!/usr/bin/env python3
"""Unit tests for check_proguard_serial_keep.py.

Run: python3 scripts/check_proguard_serial_keep_test.py

These exercise the R8 mapping.txt parser and its pass/fail contract, including
the cases the Build Android integration step cannot reproduce (a renamed
method, stripped drivers) and the synthetic-lambda case that must NOT trip a
false positive.
"""

import contextlib
import importlib.util
import io
import os
import tempfile
import unittest

# Load the sibling script by path so the test runs from any working directory.
_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "check_proguard_serial_keep",
    os.path.join(_HERE, "check_proguard_serial_keep.py"),
)
guard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guard)


# Healthy JNI handler sections: the class may be renamed (GetObjectClass is
# name-agnostic) but every JNI-resolved method is identity-mapped. BleIoStream
# also carries an inlined copy of close() under another name, which must not
# mask the identity-mapped method.
HANDLERS_GREEN = """\
com.submersion.libdivecomputer.UsbSerialIoStream -> X5.U:
    0:5:byte[] read(int,int) -> read
    0:3:int write(byte[],int) -> write
    0:2:void purge(int) -> purge
    0:2:void close() -> close
    0:9:int configure(int,int,int,int,int) -> configure
    0:1:int setDtr(int) -> setDtr
    0:1:int setRts(int) -> setRts
com.submersion.libdivecomputer.BleIoStream -> X5.c:
    0:5:byte[] read(int,int) -> read
    0:3:int write(byte[],int) -> write
    0:2:void purge(int) -> purge
    0:2:void close() -> close
    924:932:void close():250:250 -> b
    0:4:java.lang.String onPinCodeRequired(java.lang.String) -> onPinCodeRequired
    0:4:byte[] getAccessCode(java.lang.String) -> getAccessCode
    0:4:void setAccessCode(java.lang.String,byte[]) -> setAccessCode
"""

# A driver class kept verbatim by `-keep class ...driver.** { *; }`: it maps to
# itself and its reflected methods keep their names.
GREEN = """\
com.example.app.MainActivity -> a.b.c:
    void onCreate(android.os.Bundle) -> a
com.hoho.android.usbserial.driver.ProlificSerialDriver -> com.hoho.android.usbserial.driver.ProlificSerialDriver:
    1:1:java.util.Map getSupportedDevices() -> getSupportedDevices
    2:2:boolean probe(android.hardware.usb.UsbDevice) -> probe
    3:5:void <init>(android.hardware.usb.UsbDevice) -> <init>
""" + HANDLERS_GREEN

# The issue #318 signature: no keep rule, so R8 renamed the class to P5.a and
# getSupportedDevices/probe to short names.
RED = """\
com.example.app.MainActivity -> a.b.c:
    void onCreate(android.os.Bundle) -> a
com.hoho.android.usbserial.driver.ProlificSerialDriver -> P5.a:
    1:1:java.util.Map getSupportedDevices() -> a
    2:2:boolean probe(android.hardware.usb.UsbDevice) -> b
""" + HANDLERS_GREEN


class AnalyzeTests(unittest.TestCase):
    def test_green_preserves_reflected_methods(self):
        r = guard.analyze(GREEN)
        self.assertTrue(r["minify_ran"])
        self.assertEqual(r["renamed"], [])
        self.assertIn(
            "com.hoho.android.usbserial.driver.ProlificSerialDriver",
            r["canary_classes"],
        )
        # getSupportedDevices and probe both identity-mapped.
        self.assertEqual({m for _, m in r["kept"]}, {"getSupportedDevices", "probe"})

    def test_red_flags_renamed_methods(self):
        r = guard.analyze(RED)
        self.assertTrue(r["minify_ran"])
        renamed_methods = {m for _, m, _ in r["renamed"]}
        self.assertEqual(renamed_methods, {"getSupportedDevices", "probe"})

    def test_synthetic_lambda_is_not_flagged(self):
        # R8 legitimately renames its own synthetic helper classes inside the
        # kept package; that must NOT be treated as a broken driver.
        text = GREEN + (
            "com.hoho.android.usbserial.driver."
            "ProlificSerialDriver$ProlificSerialPort$$ExternalSyntheticLambda0"
            " -> com.hoho.android.usbserial.driver.a:\n"
        )
        r = guard.analyze(text)
        self.assertEqual(r["renamed"], [])

    def test_no_obfuscation_sets_minify_false(self):
        text = (
            "com.hoho.android.usbserial.driver.ProlificSerialDriver -> "
            "com.hoho.android.usbserial.driver.ProlificSerialDriver:\n"
            "    java.util.Map getSupportedDevices() -> getSupportedDevices\n"
        )
        r = guard.analyze(text)
        self.assertFalse(r["minify_ran"])

    def test_comment_and_blank_lines_are_skipped(self):
        # mapping.txt starts with a "# compiler:" banner and may have blanks.
        r = guard.analyze("# compiler: R8\n\n" + GREEN)
        self.assertEqual(r["renamed"], [])
        self.assertTrue(r["minify_ran"])


class MethodNameTests(unittest.TestCase):
    def test_strips_line_range_and_return_type(self):
        self.assertEqual(
            guard._method_name("1:1:java.util.Map getSupportedDevices()"),
            "getSupportedDevices",
        )

    def test_handles_inlined_owner_qualifier(self):
        self.assertEqual(
            guard._method_name(
                "0:2:com.hoho.android.usbserial.driver.UsbSerialDriver getDriver()"
            ),
            "getDriver",
        )

    def test_fields_return_none(self):
        self.assertIsNone(guard._method_name("int USB_READ_TIMEOUT_MILLIS"))

    def test_empty_signature_returns_none(self):
        # Defensive: a "()" with nothing before it yields no name token.
        self.assertIsNone(guard._method_name("()"))


class CheckMappingTests(unittest.TestCase):
    def _run(self, text):
        with tempfile.NamedTemporaryFile(
            "w", suffix=".txt", delete=False, encoding="utf-8"
        ) as fh:
            fh.write(text)
            path = fh.name
        try:
            return guard.check_mapping(path)
        finally:
            os.unlink(path)

    def test_green_passes(self):
        ok, lines = self._run(GREEN)
        self.assertTrue(ok)
        self.assertTrue(any("preserved on 1 drivers" in line for line in lines))

    def test_red_fails(self):
        ok, lines = self._run(RED)
        self.assertFalse(ok)
        self.assertTrue(any("getSupportedDevices" in line for line in lines))

    def test_member_renamed_without_class_rename_fails(self):
        # R8 can rename getSupportedDevices while KEEPING the class name (partial
        # keep rules / -keepnames). No class is renamed, so the obfuscation-ran
        # heuristic is false -- but this is still the #318 regression and must
        # fail, not be skipped. (Regression test for the early-return bug.)
        ok, lines = self._run(
            "com.hoho.android.usbserial.driver.ProlificSerialDriver -> "
            "com.hoho.android.usbserial.driver.ProlificSerialDriver:\n"
            "    java.util.Map getSupportedDevices() -> a\n"
        )
        self.assertFalse(ok)
        self.assertTrue(any("getSupportedDevices" in line for line in lines))

    def test_non_obfuscated_with_drivers_present_passes(self):
        # A shrink-only/non-obfuscated mapping that still lists the driver and
        # its un-renamed getSupportedDevices is genuinely fine.
        ok, lines = self._run(
            "com.hoho.android.usbserial.driver.ProlificSerialDriver -> "
            "com.hoho.android.usbserial.driver.ProlificSerialDriver:\n"
            "    java.util.Map getSupportedDevices() -> getSupportedDevices\n"
        )
        self.assertTrue(ok)
        self.assertTrue(any("preserved" in line for line in lines))

    def test_warns_when_no_obfuscation_and_no_drivers(self):
        # Cannot prove the drivers survived; warn rather than pass or fail.
        ok, lines = self._run("com.example.Foo -> com.example.Foo:\n"
                              "    void bar() -> bar\n")
        self.assertTrue(ok)
        self.assertTrue(any("WARN" in line for line in lines))

    def test_stripped_drivers_fail(self):
        # Obfuscation ran (MainActivity renamed) but no driver declares
        # getSupportedDevices -> the drivers were stripped or renamed away.
        ok, lines = self._run("com.example.app.MainActivity -> a.b.c:\n"
                              "    void onCreate(android.os.Bundle) -> a\n")
        self.assertFalse(ok)
        self.assertTrue(any("stripped" in line for line in lines))


class JniHandlerTests(unittest.TestCase):
    """The fourth #318 root cause: JNI GetMethodID-resolved handler methods."""

    def _run(self, text):
        with tempfile.NamedTemporaryFile(
            "w", suffix=".txt", delete=False, encoding="utf-8"
        ) as fh:
            fh.write(text)
            path = fh.name
        try:
            return guard.check_mapping(path)
        finally:
            os.unlink(path)

    # Driver section is healthy; only the handlers vary per test.
    DRIVERS_OK = (
        "com.example.app.MainActivity -> a.b.c:\n"
        "    void onCreate(android.os.Bundle) -> a\n"
        "com.hoho.android.usbserial.driver.ProlificSerialDriver -> "
        "com.hoho.android.usbserial.driver.ProlificSerialDriver:\n"
        "    1:1:java.util.Map getSupportedDevices() -> getSupportedDevices\n"
        "    2:2:boolean probe(android.hardware.usb.UsbDevice) -> probe\n"
    )

    def test_removed_handler_class_fails(self):
        # The real-world regression: R8 merged UsbSerialIoStream away and
        # stripped its methods, so the class has no mapping section at all.
        ok, lines = self._run(self.DRIVERS_OK)
        self.assertFalse(ok)
        self.assertTrue(any("UsbSerialIoStream has no mapping section" in line
                            for line in lines))

    def test_stripped_handler_method_fails(self):
        # Section exists but configure() has no mapping line: R8 deleted the
        # method (its only caller is native code).
        broken = HANDLERS_GREEN.replace(
            "    0:9:int configure(int,int,int,int,int) -> configure\n", "")
        ok, lines = self._run(self.DRIVERS_OK + broken)
        self.assertFalse(ok)
        self.assertTrue(any("configure() stripped" in line for line in lines))

    def test_renamed_handler_method_fails(self):
        broken = HANDLERS_GREEN.replace(
            "    0:5:byte[] read(int,int) -> read\n"
            "    0:3:int write(byte[],int) -> write\n"
            "    0:2:void purge(int) -> purge\n"
            "    0:2:void close() -> close\n"
            "    0:9:int configure(int,int,int,int,int) -> configure\n",
            "    0:5:byte[] read(int,int) -> a\n"
            "    0:3:int write(byte[],int) -> write\n"
            "    0:2:void purge(int) -> purge\n"
            "    0:2:void close() -> close\n"
            "    0:9:int configure(int,int,int,int,int) -> configure\n",
            1,
        )
        ok, lines = self._run(self.DRIVERS_OK + broken)
        self.assertFalse(ok)
        self.assertTrue(any("read() renamed" in line for line in lines))

    def test_inlined_copy_does_not_mask_identity_mapping(self):
        # BleIoStream in HANDLERS_GREEN carries "close():250:250 -> b" (an
        # inlined copy) alongside "close() -> close"; the identity mapping
        # must win and the mapping must pass.
        r = guard.analyze(self.DRIVERS_OK + HANDLERS_GREEN)
        ble = r["handler_methods"]["com.submersion.libdivecomputer.BleIoStream"]
        self.assertEqual(ble["close"], {"close", "b"})
        ok, _ = self._run(self.DRIVERS_OK + HANDLERS_GREEN)
        self.assertTrue(ok)

    def test_renamed_handler_class_name_is_allowed(self):
        # HANDLERS_GREEN maps the classes to X5.U / X5.c. That must pass:
        # JNI resolves the class via GetObjectClass, never by name.
        ok, lines = self._run(self.DRIVERS_OK + HANDLERS_GREEN)
        self.assertTrue(ok)
        self.assertTrue(any("JNI-resolved methods preserved" in line
                            for line in lines))

    def test_missing_handlers_warn_when_not_obfuscated(self):
        # Shrink-only mapping: cannot prove anything, warn rather than fail.
        ok, lines = self._run(
            "com.example.Foo -> com.example.Foo:\n    void bar() -> bar\n")
        self.assertTrue(ok)
        self.assertTrue(any("WARN" in line and "UsbSerialIoStream" in line
                            for line in lines))


class MainTests(unittest.TestCase):
    def _main(self, *args):
        """Run main() with its console output captured; return (code, output)."""
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = guard.main(["check_proguard_serial_keep.py", *args])
        return code, buf.getvalue()

    def _file(self, text):
        with tempfile.NamedTemporaryFile(
            "w", suffix=".txt", delete=False, encoding="utf-8"
        ) as fh:
            fh.write(text)
            self.addCleanup(os.unlink, fh.name)
            return fh.name

    def test_no_args_prints_usage(self):
        code, out = self._main()
        self.assertEqual(code, 2)
        self.assertIn("Usage:", out)

    def test_missing_file_is_error(self):
        code, out = self._main("/no/such/mapping.txt")
        self.assertEqual(code, 1)
        self.assertIn("ERROR reading", out)

    def test_green_file_exits_zero_and_reports_pass(self):
        code, out = self._main(self._file(GREEN))
        self.assertEqual(code, 0)
        self.assertIn("PASS", out)

    def test_red_file_exits_one_and_reports_fail(self):
        code, out = self._main(self._file(RED))
        self.assertEqual(code, 1)
        self.assertIn("FAIL", out)


if __name__ == "__main__":
    unittest.main()
