#!/usr/bin/env python3
"""Unit tests for check_jni_local_refs.py.

Run: python3 scripts/check_jni_local_refs_test.py

These exercise the JNI local-reference accounting the Build Android step cannot
reproduce without an emulator: a callback that leaks a ``jclass`` (the issue
#318 crash), the ``DeleteLocalRef`` / ``PushLocalFrame`` exemptions, and the
comment/literal hazards that previously hid ``jni_io_ioctl`` from the scanner.
A smoke test runs the guard against the real libdc_jni.cpp so the shipped fix
stays green.
"""

import contextlib
import importlib.util
import io
import os
import tempfile
import unittest

# Load the sibling script by path so the test runs from any working directory.
_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO_ROOT = os.path.dirname(_HERE)
_spec = importlib.util.spec_from_file_location(
    "check_jni_local_refs",
    os.path.join(_HERE, "check_jni_local_refs.py"),
)
guard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guard)

REAL_SOURCE = os.path.join(
    _REPO_ROOT,
    "packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp",
)


# A callback that releases every local ref it makes: cls right after the method
# lookup, the returned array after its last use.
GREEN = """\
static int jni_io_read(void *userdata, void *data, size_t size, size_t *actual) {
    auto *ctx = static_cast<JniIoContext *>(userdata);
    JNIEnv *env = ctx->env;
    jclass cls = env->GetObjectClass(ctx->ioHandler);
    jmethodID method = env->GetMethodID(cls, "read", "(II)[B");
    env->DeleteLocalRef(cls);
    auto result = static_cast<jbyteArray>(env->CallObjectMethod(ctx->ioHandler, method));
    jsize len = env->GetArrayLength(result);
    env->DeleteLocalRef(result);
    *actual = len;
    return 0;
}

static int jni_io_write(void *userdata, const void *data, size_t size, size_t *actual) {
    auto *ctx = static_cast<JniIoContext *>(userdata);
    JNIEnv *env = ctx->env;
    jclass cls = env->GetObjectClass(ctx->ioHandler);
    jmethodID method = env->GetMethodID(cls, "write", "([BI)I");
    env->DeleteLocalRef(cls);
    jbyteArray arr = env->NewByteArray((jint)size);
    env->CallIntMethod(ctx->ioHandler, method, arr);
    env->DeleteLocalRef(arr);
    return 0;
}
"""

# The issue #318 signature: cls and the returned array are never released, so
# every call leaks two local refs.
RED = """\
static int jni_io_read(void *userdata, void *data, size_t size, size_t *actual) {
    auto *ctx = static_cast<JniIoContext *>(userdata);
    JNIEnv *env = ctx->env;
    jclass cls = env->GetObjectClass(ctx->ioHandler);
    jmethodID method = env->GetMethodID(cls, "read", "(II)[B");
    auto result = static_cast<jbyteArray>(env->CallObjectMethod(ctx->ioHandler, method));
    jsize len = env->GetArrayLength(result);
    *actual = len;
    return 0;
}

static int jni_io_write(void *userdata, const void *data, size_t size, size_t *actual) {
    jclass cls = env->GetObjectClass(ctx->ioHandler);
    env->CallIntMethod(ctx->ioHandler, env->GetMethodID(cls, "write", "([BI)I"));
    return 0;
}
"""


class FindLeaksTests(unittest.TestCase):
    def test_green_has_no_leaks(self):
        leaks, seen = guard.find_leaks(GREEN)
        self.assertEqual(leaks, [])
        self.assertEqual(seen, {"jni_io_read", "jni_io_write"})

    def test_red_flags_every_undeleted_ref(self):
        leaks, _ = guard.find_leaks(RED)
        flagged = {(name, var) for name, _, var in leaks}
        self.assertIn(("jni_io_read", "cls"), flagged)
        self.assertIn(("jni_io_read", "result"), flagged)
        self.assertIn(("jni_io_write", "cls"), flagged)

    def test_push_local_frame_exempts_the_body(self):
        # A PushLocalFrame bracket frees every ref in bulk on pop, so the
        # per-variable DeleteLocalRef requirement is waived.
        framed = """\
static void jni_on_progress(unsigned int c, unsigned int m, void *userdata) {
    auto *ctx = static_cast<JniDownloadContext *>(userdata);
    JNIEnv *env = ctx->env;
    env->PushLocalFrame(8);
    jclass cls = env->GetObjectClass(ctx->callback);
    jmethodID method = env->GetMethodID(cls, "onProgress", "(II)V");
    env->CallVoidMethod(ctx->callback, method, (jint)c, (jint)m);
    env->PopLocalFrame(nullptr);
}
static int jni_io_read(void *u) { return 0; }
static int jni_io_write(void *u) { return 0; }
"""
        leaks, seen = guard.find_leaks(framed)
        self.assertEqual(leaks, [])
        self.assertIn("jni_on_progress", seen)

    def test_unbound_ref_is_flagged(self):
        # A ref-creating call whose result is not bound to a variable cannot be
        # proven released -- treat it as a leak.
        body = """\
static int jni_io_read(void *u) {
    env->CallVoidMethod(o, m, env->NewStringUTF("x"));
    return 0;
}
static int jni_io_write(void *u) { return 0; }
"""
        leaks, _ = guard.find_leaks(body)
        self.assertTrue(any(var is None for _, _, var in leaks))


class CommentAndLiteralHazardTests(unittest.TestCase):
    def test_comment_with_unbalanced_paren_does_not_hide_next_function(self):
        # Regression: a `//` comment with a stray '(' directly above a function
        # whose preamble has no ';{}' (the real DC_IOCTL note + #defines) used to
        # let the signature scan run past jni_io_ioctl entirely.
        src = """\
// DC_IOCTL('b', 0) = (0x62 << 8) | 0 = 0x6200
#define BLE_IOCTL_GET_NAME 0x6200
#define BLE_IOCTL_ACCESSCODE_NR 2
static int jni_io_ioctl(void *userdata, unsigned int request,
                         void *data, size_t size) {
    jclass cls = env->GetObjectClass(ctx->ioHandler);
    return 0;
}
static int jni_io_read(void *u) { return 0; }
static int jni_io_write(void *u) { return 0; }
"""
        leaks, seen = guard.find_leaks(src)
        self.assertIn("jni_io_ioctl", seen)
        self.assertIn(("jni_io_ioctl", "GetObjectClass", "cls"), leaks)

    def test_deletelocalref_in_a_comment_is_not_a_real_release(self):
        src = """\
static int jni_io_read(void *u) {
    jclass cls = env->GetObjectClass(o);
    // we intentionally do NOT call env->DeleteLocalRef(cls) yet
    return 0;
}
static int jni_io_write(void *u) { return 0; }
"""
        leaks, _ = guard.find_leaks(src)
        self.assertIn(("jni_io_read", "GetObjectClass", "cls"), leaks)

    def test_semicolon_inside_a_string_literal_is_preserved(self):
        # A JNI signature carries ';'; stripping must keep it so the method
        # lookup statement is not mis-split and the real leak is still seen.
        src = """\
static int jni_io_ioctl(void *u) {
    jclass cls = env->GetObjectClass(o);
    jmethodID m = env->GetMethodID(cls, "onPinCodeRequired",
        "(Ljava/lang/String;)Ljava/lang/String;");
    return 0;
}
static int jni_io_read(void *u) { return 0; }
static int jni_io_write(void *u) { return 0; }
"""
        leaks, seen = guard.find_leaks(src)
        self.assertIn("jni_io_ioctl", seen)
        self.assertIn(("jni_io_ioctl", "GetObjectClass", "cls"), leaks)

    def test_block_comment_is_stripped(self):
        stripped = guard._strip_comments("a /* b ; { } */ c")
        self.assertNotIn("b", stripped)
        self.assertIn("a", stripped)
        self.assertIn("c", stripped)


class AssignTargetTests(unittest.TestCase):
    def test_simple_and_auto_targets(self):
        self.assertEqual(guard._assign_target("jclass cls = env->Foo()"), "cls")
        self.assertEqual(
            guard._assign_target("auto result = static_cast<jbyteArray>(x)"),
            "result",
        )

    def test_comparison_is_not_an_assignment(self):
        self.assertIsNone(guard._assign_target("if (r == 0)"))
        self.assertIsNone(guard._assign_target("while (n >= size)"))


class CheckFileTests(unittest.TestCase):
    def _write(self, text):
        fd, path = tempfile.mkstemp(suffix=".cpp")
        with os.fdopen(fd, "w") as fh:
            fh.write(text)
        self.addCleanup(os.unlink, path)
        return path

    def test_green_file_passes(self):
        ok, lines = guard.check_file(self._write(GREEN))
        self.assertTrue(ok)
        self.assertTrue(any("free every local ref" in ln for ln in lines))

    def test_red_file_fails(self):
        ok, lines = guard.check_file(self._write(RED))
        self.assertFalse(ok)
        self.assertTrue(any("never released" in ln for ln in lines))

    def test_missing_expected_callback_fails(self):
        # No jni_io_read/jni_io_write at all -- the bridge moved or the guard is
        # pointed at the wrong file; fail loudly rather than scan nothing.
        ok, lines = guard.check_file(self._write("static int jni_on_dive(void *u) { return 0; }"))
        self.assertFalse(ok)
        self.assertTrue(any("expected callback" in ln for ln in lines))

    def test_real_source_is_clean(self):
        # The shipped libdc_jni.cpp must satisfy the guard (the #318 fix).
        if not os.path.exists(REAL_SOURCE):
            self.skipTest("libdc_jni.cpp not present")
        ok, lines = guard.check_file(REAL_SOURCE)
        self.assertTrue(ok, msg="\n".join(lines))


class MainTests(unittest.TestCase):
    def _write(self, text):
        fd, path = tempfile.mkstemp(suffix=".cpp")
        with os.fdopen(fd, "w") as fh:
            fh.write(text)
        self.addCleanup(os.unlink, path)
        return path

    def _run(self, argv):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = guard.main(argv)
        return rc, buf.getvalue()

    def test_main_passes_on_clean_file(self):
        rc, out = self._run(["prog", self._write(GREEN)])
        self.assertEqual(rc, 0)
        self.assertIn("PASS", out)

    def test_main_fails_on_leaky_file(self):
        rc, out = self._run(["prog", self._write(RED)])
        self.assertEqual(rc, 1)
        self.assertIn("FAIL", out)

    def test_main_reports_unreadable_path(self):
        rc, out = self._run(["prog", os.path.join(_HERE, "does_not_exist.cpp")])
        self.assertEqual(rc, 1)
        self.assertIn("ERROR", out)

    def test_main_default_path_resolves_from_repo_root(self):
        cwd = os.getcwd()
        os.chdir(_REPO_ROOT)
        try:
            rc, out = self._run(["prog"])
        finally:
            os.chdir(cwd)
        self.assertEqual(rc, 0)
        self.assertIn("PASS", out)


if __name__ == "__main__":
    unittest.main()
