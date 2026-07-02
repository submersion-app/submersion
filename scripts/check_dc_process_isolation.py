#!/usr/bin/env python3
"""Verify the dive-download service stays isolated in its own process (#318).

The Android serial download runs libdivecomputer's native code, which can crash
with a native SIGSEGV. To keep such a crash from killing the app, the download
runs in a separate process declared as `android:process=":dc"`. A Java
try/catch cannot catch a native signal, so this process boundary IS the
containment; if it is dropped, the crash becomes fatal again. This guard fails
if the DiveDownloadService is missing or not in its own process. Pure stdlib.

Usage: check_dc_process_isolation.py <AndroidManifest.xml>
"""

import re
import sys

DEFAULT_MANIFEST = (
    "packages/libdivecomputer_plugin/android/src/main/AndroidManifest.xml"
)
SERVICE = "DiveDownloadService"


def find_violations(text):
    """Return a list of violation strings; empty == compliant."""
    # Match each <service ...> element (attributes may span lines).
    services = [s for s in re.findall(r"<service\b.*?>", text, re.DOTALL)
                if SERVICE in s]
    if not services:
        return [f"{SERVICE} is not declared in a <service> element"]
    violations = []
    for svc in services:
        if 'android:process=":dc"' not in re.sub(r"\s+", " ", svc):
            violations.append(
                f"{SERVICE} is declared without android:process=\":dc\" -- a "
                "native download crash would kill the app (see issue #318)"
            )
    return violations


def check_file(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        violations = find_violations(fh.read())
    lines = [f"  FAIL  {v}" for v in violations]
    if not violations:
        lines.append(f"  ok    {SERVICE} runs in its own :dc process")
    return not violations, lines


def main(argv):
    paths = argv[1:] or [DEFAULT_MANIFEST]
    all_ok = True
    for path in paths:
        print(f"Checking dive-download process isolation: {path}")
        try:
            ok, lines = check_file(path)
        except OSError as exc:
            print(f"  ERROR reading {path}: {exc}")
            all_ok = False
            continue
        for line in lines:
            print(line)
        print("  -> PASS" if ok else "  -> FAIL: download is not process-isolated (#318)")
        all_ok = all_ok and ok
    return 0 if all_ok else 1


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv))
