#!/usr/bin/env python3
"""Verify the libdivecomputer JNI callbacks free every local reference.

The Android backend bridges libdivecomputer's synchronous I/O to Kotlin through
the JNI callbacks in ``libdc_jni.cpp`` (``jni_io_read``, ``jni_io_write``,
``jni_io_configure`` ... and the ``jni_on_progress`` / ``jni_on_dive`` download
callbacks). libdivecomputer calls these *repeatedly* from
``Java_..._nativeDownloadRun``, which runs the whole download synchronously on
the Kotlin thread that invoked it.

That thread is already attached to the JVM, so in every callback
``GetEnv()`` returns ``JNI_OK`` -> ``attached = false`` -> ``DetachCurrentThread``
is never called. JNI local references are reclaimed only when the native method
returns to Java *or* when the thread detaches -- neither happens until the whole
download finishes. So every undeleted local ref (the ``jclass`` from
``GetObjectClass``, the byte array from ``CallObjectMethod`` / ``NewByteArray``)
accumulates for the entire session.

A full Mares Puck Pro dump reads 0x40000 bytes in 256-byte packets -- roughly
5,000 read/write callbacks, each leaking ~2 local refs. That overflows ART's
local reference table (``JNI ERROR (app bug): local reference table overflow``),
which aborts the process with SIGABRT: the app "just closes" with no Dart/Java
exception. This is the v1.5.8 face of issue #318. (The earlier #334 serial-read
fix is what let the download run long enough to reach the overflow -- it did not
introduce the leak, it un-masked it.)

This guard is a source-level static check (no build artifact, no NDK). For each
download-thread callback it confirms every local-reference-creating JNI call has
either a matching ``DeleteLocalRef`` or a ``PushLocalFrame`` bracket. It is the
source-level counterpart to ``check_proguard_serial_keep`` /
``check_16kb_alignment`` and is dependency-free (pure stdlib).

Usage:
    check_jni_local_refs.py [libdc_jni.cpp]   # defaults to the Android source
"""

import re
import sys

DEFAULT_SOURCE = (
    "packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp"
)

# JNI calls that return a *local reference* the caller owns and must release
# with DeleteLocalRef. GetMethodID/GetFieldID return IDs (not refs);
# Call{Int,Void,Boolean}Method return primitives (not refs) -- excluded on
# purpose. NewGlobalRef makes a global ref (freed by DeleteGlobalRef) and is
# handled by nativeDownloadRun, not these per-call callbacks.
REF_CREATING = (
    "GetObjectClass",
    "CallObjectMethod",
    "NewByteArray",
    "NewStringUTF",
    "NewString",
    "NewObject",
    "NewObjectArray",
    "GetObjectArrayElement",
)

# Callbacks libdivecomputer invokes on the (already-attached) download thread.
# These names must exist; a rename should fail the guard loudly rather than let
# it silently scan nothing.
EXPECTED_CALLBACKS = ("jni_io_read", "jni_io_write")

# A body that brackets its work in a JNI local frame frees every local ref in
# bulk on pop, so accept that as a complete fix without per-variable accounting.
FRAME_MARKER = "PushLocalFrame"

# Only the per-call libdivecomputer callbacks are audited (see _functions, which
# anchors on these names). nativeDownloadRun manages its refs differently
# (global refs, a single invocation that returns to Java) and is out of scope.


def _strip_comments(text):
    """Remove C/C++ comments while preserving string and char literals.

    Comment removal matters twice: a ``//`` comment with an unbalanced ``(`` (the
    ``DC_IOCTL('b', 0)`` note above ``jni_io_ioctl``) would otherwise let the
    signature scan run past it into the next function, and a comment that merely
    *mentions* ``DeleteLocalRef(cls)`` must never be mistaken for a real release.
    Literals are kept verbatim because JNI signatures such as
    ``"(Ljava/lang/String;)..."`` carry ``;`` and ``(`` that the parser relies on.
    """
    out = []
    i, n = 0, len(text)
    while i < n:
        two = text[i:i + 2]
        if two == "//":
            nl = text.find("\n", i)
            i = n if nl < 0 else nl  # leave the newline for the next iteration
        elif two == "/*":
            end = text.find("*/", i + 2)
            out.append(" ")  # keep tokens on either side separated
            i = n if end < 0 else end + 2
        elif text[i] in "\"'":
            quote = text[i]
            out.append(text[i])
            i += 1
            while i < n:
                out.append(text[i])
                if text[i] == "\\" and i + 1 < n:
                    out.append(text[i + 1])
                    i += 2
                    continue
                if text[i] == quote:
                    i += 1
                    break
                i += 1
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def _functions(text):
    """Yield ``(name, body)`` for each ``jni_io_*`` / ``jni_on_*`` definition.

    Anchored to the callback names so an upstream ``(`` cannot start a spurious
    match, and brace-matched so nested blocks do not end a body early. Operates
    on comment-stripped source.
    """
    text = _strip_comments(text)
    for m in re.finditer(r"\b(jni_(?:io|on)_\w*)\s*\([^;{}]*\)\s*\{", text):
        name = m.group(1)
        brace = text.index("{", m.end() - 1)
        depth = 0
        for i in range(brace, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    yield name, text[brace + 1:i]
                    break


def _assign_target(statement):
    """Return the variable a statement assigns to, or ``None``.

    The first plain ``=`` (not ``==`` / ``<=`` / ``>=`` / ``!=``) marks the
    assignment; the identifier to its left is the target. ``jclass cls = ...``
    -> ``cls``; ``auto result = static_cast<jbyteArray>(...)`` -> ``result``.
    """
    m = re.search(r"(\b[A-Za-z_]\w*)\s*=(?!=)", statement)
    return m.group(1) if m else None


def _ref_creating_calls(body):
    """Return ``[(call, var), ...]`` for ref-creating calls in ``body``.

    Split on ``;`` so a statement whose call spills across lines stays intact.
    ``var`` is the assignment target, or ``None`` when the ref is not bound to a
    variable (and so cannot be proven released).
    """
    found = []
    for statement in body.split(";"):
        for call in REF_CREATING:
            # \s*\( so NewString does not match inside NewStringUTF.
            if re.search(r"\b" + call + r"\s*\(", statement):
                found.append((call, _assign_target(statement)))
    return found


def find_leaks(text):
    """Return ``(leaks, seen)``.

    ``leaks`` is a list of ``(function, call, var)`` for every local ref that is
    created but never released. ``seen`` is the set of callback function names
    audited.
    """
    leaks = []
    seen = set()
    for name, body in _functions(text):
        seen.add(name)
        if FRAME_MARKER in body:
            continue  # bulk-freed on PopLocalFrame
        for call, var in _ref_creating_calls(body):
            if var is None:
                leaks.append((name, call, None))
                continue
            released = re.search(
                r"DeleteLocalRef\s*\(\s*" + re.escape(var) + r"\s*\)", body
            )
            if not released:
                leaks.append((name, call, var))
    return leaks, seen


def check_file(path):
    """Check one libdc_jni.cpp. Return ``(ok, lines)`` report."""
    with open(path, encoding="utf-8", errors="replace") as fh:
        leaks, seen = find_leaks(fh.read())

    lines = []
    ok = True

    missing = [c for c in EXPECTED_CALLBACKS if c not in seen]
    if missing:
        ok = False
        lines.append(
            "  FAIL  expected callback(s) not found: "
            f"{', '.join(missing)} -- did the JNI bridge move/rename? "
            "update this guard"
        )

    for name, call, var in leaks:
        ok = False
        target = var if var is not None else "(unbound)"
        lines.append(
            f"  FAIL  {name}: {call} local ref '{target}' is never released "
            "(needs DeleteLocalRef or a PushLocalFrame bracket)"
        )

    if ok:
        lines.append(
            f"  ok    {len(seen)} download-thread JNI callbacks free every "
            "local ref"
        )
    return ok, lines


def main(argv):
    paths = argv[1:] or [DEFAULT_SOURCE]
    all_ok = True
    for path in paths:
        print(f"Checking JNI local-reference hygiene: {path}")
        try:
            ok, lines = check_file(path)
        except OSError as exc:
            print(f"  ERROR reading {path}: {exc}")
            all_ok = False
            continue
        for line in lines:
            print(line)
        if ok:
            print(
                "  -> PASS: download-thread JNI callbacks release their "
                "local refs"
            )
        else:
            print(
                "  -> FAIL: a JNI callback leaks local refs; a long download "
                "(e.g. Mares Puck Pro) overflows the local reference table and "
                "crashes with a silent SIGABRT (see issue #318)"
            )
        all_ok = all_ok and ok

    return 0 if all_ok else 1


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv))
