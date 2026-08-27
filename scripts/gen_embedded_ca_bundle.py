#!/usr/bin/env python3
"""Regenerate lib/core/network/embedded_ca_bundle.dart.

The embedded bundle is the public root CA *baseline* for TLS verification on
Windows builds (see app_security_context.dart). Dart bundles BoringSSL and
builds that context with `withTrustedRoots: false`; the live Windows store is
read and unioned on top for enterprise/private roots. But the public roots
must always be present and complete -- Windows materializes roots lazily, so
a store read can succeed yet still be missing a common root that an endpoint
chains to. Baking the full public set in here closes that gap.

It must therefore be the *complete, current* public root set. The
authoritative source is the Mozilla CA set as published by the curl project
(https://curl.se/ca/cacert.pem), which is fetched by default.

Do NOT generate it from the host's /etc/ssl/cert.pem: on macOS that is
Apple's divergent root set, which omits roots (e.g. GlobalSign Root CA - R3,
which tile.openstreetmap.org chains to) that public endpoints depend on.

The certificates are emitted as a Dart raw-string constant so the
SecurityContext can be built synchronously with no asset loading.

Usage:
    python3 scripts/gen_embedded_ca_bundle.py [path-to-cacert.pem]

With no argument, fetches the canonical bundle from curl.se. Pass a local
path to pin a vendored copy for offline or reproducible builds.
"""

import re
import sys
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
OUT = REPO_ROOT / "lib" / "core" / "network" / "embedded_ca_bundle.dart"
CANONICAL_URL = "https://curl.se/ca/cacert.pem"

CERT_RE = re.compile(
    r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----",
    re.DOTALL,
)


def load_source(arg):
    """Return (pem_text, source_label) from a local path or the canonical URL."""
    if arg is not None:
        path = Path(arg)
        if not path.exists():
            raise FileNotFoundError(f"no such CA bundle file: {arg}")
        return path.read_text(encoding="utf-8"), str(path)
    with urllib.request.urlopen(CANONICAL_URL, timeout=30) as resp:
        return resp.read().decode("utf-8"), CANONICAL_URL


def main() -> int:
    try:
        text, source = load_source(sys.argv[1] if len(sys.argv) > 1 else None)
    except Exception as exc:  # noqa: BLE001 - surface any fetch/read failure
        print(f"error: could not load CA source: {exc}")
        return 1

    certs = CERT_RE.findall(text)
    if not certs:
        print(f"error: no certificates found in {source}")
        return 1

    # Strip each cert and join with a single newline, plus one trailing
    # newline -- so consecutive PEM blocks are separated by exactly one "\n".
    bundle = "\n".join(c.strip() for c in certs) + "\n"

    if "'''" in bundle:
        print("error: bundle contains triple-quote; cannot emit as raw string")
        return 1

    dart = (
        "// GENERATED FILE - DO NOT EDIT BY HAND.\n"
        "// Regenerate with: python3 scripts/gen_embedded_ca_bundle.py\n"
        f"// Source: {source} ({len(certs)} root certificates).\n"
        "//\n"
        "// Public root CA baseline for Windows TLS verification. Always merged\n"
        "// with the live OS certificate store. See app_security_context.dart.\n"
        "library;\n"
        "\n"
        "/// Concatenated public root CA certificates in PEM form.\n"
        "const String embeddedCaBundlePem = r'''\n"
        f"{bundle}"
        "''';\n"
    )
    OUT.write_text(dart)
    print(f"wrote {OUT} ({len(certs)} certs, {len(dart)} bytes) from {source}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
