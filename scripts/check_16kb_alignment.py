#!/usr/bin/env python3
"""Verify that 64-bit native libraries in an Android APK/AAB are 16 KB-aligned.

Android 15+ devices may use 16 KB memory pages. The dynamic linker refuses to
load a shared library whose ELF ``PT_LOAD`` segments are aligned to less than
16 KB (0x4000) on such a device, raising ``UnsatisfiedLinkError``. In Submersion
this manifested as issue #318: the dive-computer JNI library ``liblibdc_jni.so``
shipped 4 KB-aligned (0x1000) and crashed the app the instant a download started
on a Xiaomi 15T Pro -- silently, because the failure is a native-level error.

This script inspects every native library bundled in an APK or AAB and fails
(exit code 1) if any 64-bit library has a ``PT_LOAD`` segment aligned to less
than 16 KB. Only 64-bit ABIs are enforced: 16 KB pages exist only on 64-bit
devices, so 4 KB-aligned 32-bit libraries (armeabi-v7a, x86) are fine and never
loaded there.

The ELF parser is intentionally dependency-free (pure stdlib) so the check runs
identically in CI (Linux) and locally (macOS) without needing readelf/llvm tools.

Usage:
    check_16kb_alignment.py <app.apk|app.aab> [more.apk ...]
"""

import struct
import sys
import zipfile

PAGE_16K = 16 * 1024  # 0x4000
PT_LOAD = 1
ELFCLASS32 = 1
ELFCLASS64 = 2


class ElfError(Exception):
    """Raised when a file is not a parseable ELF object."""


def load_segment_alignments(data):
    """Return ``(is_64bit, [p_align, ...])`` for every PT_LOAD segment.

    Raises :class:`ElfError` if ``data`` is not a little-endian ELF object.
    """
    if len(data) < 64 or data[:4] != b"\x7fELF":
        raise ElfError("not an ELF file")

    ei_class = data[4]
    ei_data = data[5]
    if ei_data != 1:
        # Android native libs are always little-endian; anything else is unexpected.
        raise ElfError("unsupported ELF endianness")

    if ei_class == ELFCLASS64:
        is_64bit = True
        (e_phoff,) = struct.unpack_from("<Q", data, 0x20)
        (e_phentsize,) = struct.unpack_from("<H", data, 0x36)
        (e_phnum,) = struct.unpack_from("<H", data, 0x38)
        align_off = 48  # p_align within a 64-bit program header
    elif ei_class == ELFCLASS32:
        is_64bit = False
        (e_phoff,) = struct.unpack_from("<I", data, 0x1C)
        (e_phentsize,) = struct.unpack_from("<H", data, 0x2A)
        (e_phnum,) = struct.unpack_from("<H", data, 0x2C)
        align_off = 28  # p_align within a 32-bit program header
    else:
        raise ElfError("unknown ELF class")

    aligns = []
    for i in range(e_phnum):
        base = e_phoff + i * e_phentsize
        (p_type,) = struct.unpack_from("<I", data, base)
        if p_type != PT_LOAD:
            continue
        if is_64bit:
            (p_align,) = struct.unpack_from("<Q", data, base + align_off)
        else:
            (p_align,) = struct.unpack_from("<I", data, base + align_off)
        aligns.append(p_align)
    return is_64bit, aligns


def native_lib_entries(zf):
    """Yield zip entry names for native libs in an APK (lib/) or AAB (base/lib/)."""
    for name in zf.namelist():
        if name.endswith(".so") and ("/lib/" in name or name.startswith("lib/")):
            yield name


def check_archive(path):
    """Check one APK/AAB. Return ``(ok, lines)`` where ``lines`` is the report."""
    lines = []
    ok = True
    with zipfile.ZipFile(path) as zf:
        entries = sorted(native_lib_entries(zf))
        if not entries:
            return False, [f"  no native libraries (.so) found in {path}"]
        for name in entries:
            try:
                is_64bit, aligns = load_segment_alignments(zf.read(name))
            except (ElfError, struct.error) as exc:
                # Fail closed: a native lib we cannot parse (malformed, or a
                # truncated header that trips struct.unpack_from) is a lib we
                # cannot prove is 16 KB-aligned, so do not let the build pass --
                # and keep checking the remaining libs instead of crashing.
                ok = False
                lines.append(
                    f"  FAIL  {name}: not a parseable ELF ({exc}); "
                    "cannot verify alignment"
                )
                continue
            min_align = min(aligns) if aligns else 0
            bits = "64-bit" if is_64bit else "32-bit"
            if not is_64bit:
                # 16 KB pages only exist on 64-bit devices; 32-bit libs are exempt.
                lines.append(f"  ok    {name} ({bits}, align={min_align}, not enforced)")
                continue
            if min_align == 0 or min_align % PAGE_16K != 0:
                ok = False
                lines.append(
                    f"  FAIL  {name} ({bits}, min p_align={min_align}; "
                    f"must be a multiple of {PAGE_16K})"
                )
            else:
                lines.append(f"  ok    {name} ({bits}, align={min_align})")
    return ok, lines


def main(argv):
    paths = argv[1:]
    if not paths:
        print(__doc__)
        return 2

    all_ok = True
    for path in paths:
        print(f"Checking 16 KB alignment: {path}")
        try:
            ok, lines = check_archive(path)
        except (OSError, zipfile.BadZipFile) as exc:
            print(f"  ERROR reading {path}: {exc}")
            all_ok = False
            continue
        for line in lines:
            print(line)
        if ok:
            print("  -> PASS: all 64-bit native libraries are 16 KB-aligned")
        else:
            print("  -> FAIL: a 64-bit native library is not 16 KB-aligned "
                  "(will crash on Android 15+ 16 KB-page devices; see issue #318)")
        all_ok = all_ok and ok

    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
