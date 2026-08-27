#!/usr/bin/env python3
"""Verify R8 kept the reflected usb-serial-for-android driver methods intact.

The libdivecomputer plugin vendors usb-serial-for-android
(``com.hoho.android.usbserial.driver.*``) to download serial-over-USB dive
computers such as the Mares Puck Pro. That library discovers drivers purely by
reflection -- it never references the members from a visible call site:

    ProbeTable.addDriver()      -> Class.getMethod("getSupportedDevices")
                                   Class.getMethod("probe", UsbDevice.class)
    UsbSerialProber.probeDevice -> Class.getConstructor(UsbDevice.class)

Flutter release builds run R8 with obfuscation enabled by default. Without a
keep rule R8 renames ``getSupportedDevices`` (and the driver class becomes e.g.
``P5.a``); the reflective ``getMethod("getSupportedDevices")`` then throws
``NoSuchMethodException`` and every serial-USB download crashes with "Download
failed unexpectedly (RuntimeException)". This was issue #318. The keep rule
lives in the plugin's ``consumer-rules.pro``.

The plugin's own Kotlin I/O handlers are reflected the same way, from JNI
rather than Java: ``libdc_jni.cpp`` resolves the handler passed to
``nativeDownloadRun`` with ``GetMethodID(GetObjectClass(handler), "read", ...)``
and friends. R8 cannot see those call sites either, so without keep rules it
*deletes* the methods outright (there is no visible caller). That was the
fourth #318 root cause: every release-build serial download died natively
right after ``nativeDownloadRun begin`` because ``UsbSerialIoStream``'s
``read/write/purge/close/configure/setDtr/setRts`` did not exist in the APK --
the failed ``GetMethodID`` in ``jni_io_purge`` left a pending
``NoSuchMethodError`` and the next JNI call was undefined behavior. The keep
rules for the handler interfaces live in ``consumer-rules.pro`` next to the
driver rules.

Because both lookups are by method name on a runtime ``Class`` object, the
precise thing that must survive is the *method name*, not the class name -- R8
may freely rename the class (``GetObjectClass`` is name-agnostic) or synthetic
helpers (e.g. ``$$ExternalSyntheticLambda``) without harm. This script reads
the R8 ``mapping.txt`` from a release build and fails (exit code 1) if a
reflectively-accessed driver method was renamed or stripped, or if a
JNI-resolved handler method was renamed, stripped, or its class removed from
an obfuscated mapping. A mapping showing no obfuscation at all only warns,
since it cannot prove the members survived (Submersion's release builds always
obfuscate, so CI never hits that case). It is the build-artifact counterpart
to ``check_16kb_alignment`` and is dependency-free (pure stdlib).

Usage:
    check_proguard_serial_keep.py <mapping.txt>
"""

import sys

# All reflectively-probed driver classes live in this package.
DRIVER_PKG = "com.hoho.android.usbserial.driver."

# Methods looked up by name via reflection in ProbeTable / UsbSerialProber.
# getSupportedDevices is fatal if renamed (its NoSuchMethodException is thrown,
# not caught); probe is reflected too and kept for the same reason. The
# (UsbDevice) constructor is also reflected, but R8 never renames <init> and the
# class-level keep prevents its removal, so the named methods are the signal.
REFLECTED_METHODS = ("getSupportedDevices", "probe")

# getSupportedDevices is declared by every concrete driver and is the canary:
# if it survives, the keep rule is effective for the whole class.
CANARY = "getSupportedDevices"

# Kotlin I/O handlers whose methods libdc_jni.cpp resolves by name with
# GetMethodID on the object passed to nativeDownloadRun. Each method must
# survive R8 under its source name or the serial/BLE download breaks at
# runtime (issue #318, fourth root cause). The class name itself may be
# renamed: JNI uses GetObjectClass, never FindClass.
JNI_HANDLERS = {
    "com.submersion.libdivecomputer.UsbSerialIoStream": (
        "read", "write", "purge", "close", "configure", "setDtr", "setRts",
    ),
    "com.submersion.libdivecomputer.BleIoStream": (
        "read", "write", "purge", "close",
        "onPinCodeRequired", "getAccessCode", "setAccessCode",
    ),
}


def _method_name(left):
    """Return the source-level method name from the left side of a mapping line.

    ``left`` looks like ``[start:end:]<returnType> name(args)[:orig:lines]`` for
    a method, or ``<type> name`` for a field. Returns ``None`` for fields (no
    parenthesis) so callers skip them.
    """
    if "(" not in left:
        return None
    before_paren = left.split("(", 1)[0]
    before_paren = before_paren.lstrip("0123456789:")  # drop "12:34:" line range
    tokens = before_paren.split()
    if not tokens:
        return None
    return tokens[-1].rsplit(".", 1)[-1]  # strip owner qualifier on inlined frames


def analyze(text):
    """Return a report dict describing how R8 treated the reflected methods."""
    minify_ran = False
    renamed = []          # (class, method, obfuscated) -- a reflected method renamed
    kept = []             # (class, method) -- reflected method identity-mapped
    canary_classes = set()  # driver classes that declared getSupportedDevices
    # handler class -> {method name -> set of obfuscated names seen}. A class
    # key is present only if its mapping section exists at all; a missing key
    # means R8 removed or merged the class away.
    handler_methods = {}

    current_orig = None
    current_is_driver = False
    current_handler = None

    for raw in text.splitlines():
        if not raw or raw.startswith("#") or " -> " not in raw:
            continue

        if not raw[0].isspace():
            # Class line: "<orig> -> <obf>:"
            left, right = raw.split(" -> ", 1)
            current_orig = left.strip()
            if right.rstrip(":").strip() != current_orig:
                minify_ran = True
            current_is_driver = current_orig.startswith(DRIVER_PKG)
            current_handler = (
                current_orig if current_orig in JNI_HANDLERS else None
            )
            if current_handler is not None:
                handler_methods.setdefault(current_handler, {})
            continue

        if current_handler is not None:
            # Member line within a JNI handler class. Record every mapping of
            # a JNI-resolved name; identity vs renamed is classified later so
            # an inlined copy (e.g. "close():250 -> b") cannot mask the real
            # identity-mapped method also present in the section.
            left, right = raw.rsplit(" -> ", 1)
            name = _method_name(left.strip())
            if name in JNI_HANDLERS[current_handler]:
                handler_methods[current_handler].setdefault(name, set()).add(
                    right.strip())
            continue

        if not current_is_driver:
            continue

        # Member line within a driver-package class.
        left, right = raw.rsplit(" -> ", 1)
        name = _method_name(left.strip())
        if name not in REFLECTED_METHODS:
            continue
        obf = right.strip()
        if name == CANARY:
            canary_classes.add(current_orig)
        if obf != name:
            renamed.append((current_orig, name, obf))
        else:
            kept.append((current_orig, name))

    return {
        "minify_ran": minify_ran,
        "renamed": renamed,
        "kept": kept,
        "canary_classes": sorted(canary_classes),
        "handler_methods": handler_methods,
    }


def check_mapping(path):
    """Check one mapping.txt. Return ``(ok, lines)`` report."""
    with open(path, encoding="utf-8", errors="replace") as fh:
        report = analyze(fh.read())

    lines = []
    ok = True

    # A renamed reflected method is always the #318 regression -- check it
    # unconditionally. R8 can rename members while keeping class names (partial
    # keep rules, -keepnames), so this must NOT be gated on class obfuscation.
    for cls, method, obf in report["renamed"]:
        ok = False
        lines.append(f"  FAIL  {cls}.{method}() renamed to '{obf}' "
                     "-- ProbeTable/UsbSerialProber reflect on this exact name")

    # JNI-resolved handler methods (fourth #318 root cause). GetMethodID needs
    # the exact source name to exist on the handler's runtime class; a method
    # counts as kept only if at least one identity mapping survives (inlined
    # copies under other names are just debug info for the inliner).
    for cls, methods in sorted(JNI_HANDLERS.items()):
        seen = report["handler_methods"].get(cls)
        if seen is None:
            if report["minify_ran"]:
                ok = False
                lines.append(f"  FAIL  {cls} has no mapping section -- R8 "
                             "removed or merged the JNI handler class")
            else:
                lines.append(f"  WARN  {cls} not in a non-obfuscated mapping; "
                             "cannot verify the JNI handler survived")
            continue
        bad = []
        for method in methods:
            obfs = seen.get(method, set())
            if method in obfs:
                continue
            if obfs:
                bad.append(f"{method}() renamed to {sorted(obfs)}")
            else:
                bad.append(f"{method}() stripped")
        if bad:
            ok = False
            for b in bad:
                lines.append(f"  FAIL  {cls}.{b} -- libdc_jni.cpp resolves "
                             "this exact name via GetMethodID")
        else:
            lines.append(f"  ok    {cls.rsplit('.', 1)[-1]}: all "
                         f"{len(methods)} JNI-resolved methods preserved")

    if report["canary_classes"]:
        if ok:
            kept = ", ".join(sorted({m for _, m in report["kept"]})) or "n/a"
            lines.append(f"  ok    {CANARY}() preserved on "
                         f"{len(report['canary_classes'])} drivers; "
                         f"reflected methods kept: {kept}")
    elif report["minify_ran"]:
        # Obfuscation ran but no driver declares getSupportedDevices: the
        # reflected methods were stripped or renamed away.
        ok = False
        lines.append(f"  FAIL  no driver declares {CANARY}() in an obfuscated "
                     "mapping -- the serial drivers were stripped or renamed away")
    else:
        # No obfuscation and no driver methods enumerated: a shrink-only or
        # non-obfuscated mapping where we cannot prove the drivers survived
        # (R8 can also strip an unused reflected member here). Warn rather than
        # pass silently. Submersion's release builds always obfuscate, so this
        # branch should not occur in CI.
        lines.append(f"  WARN  no obfuscation and no {CANARY}() seen; cannot "
                     "verify the serial drivers (minification may be disabled)")
    return ok, lines


def main(argv):
    paths = argv[1:]
    if not paths:
        print(__doc__)
        return 2

    all_ok = True
    for path in paths:
        print(f"Checking ProGuard serial-driver keep rules: {path}")
        try:
            ok, lines = check_mapping(path)
        except OSError as exc:
            print(f"  ERROR reading {path}: {exc}")
            all_ok = False
            continue
        for line in lines:
            print(line)
        if ok:
            print("  -> PASS: reflected driver methods and JNI handler methods "
                  "survive R8 obfuscation")
        else:
            print("  -> FAIL: a reflectively- or JNI-accessed method was "
                  "obfuscated or stripped (dive computer downloads will "
                  "crash; see issue #318)")
        all_ok = all_ok and ok

    return 0 if all_ok else 1


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv))
