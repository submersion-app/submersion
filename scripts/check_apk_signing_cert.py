#!/usr/bin/env python3
"""Verify that a release APK is signed by a certificate Google will accept.

Android apps hold no OAuth client ID. Google identifies them by package name
plus the SHA-1 of the signing certificate, so on Android the signing key *is*
the OAuth credential. A build signed by a certificate that has no matching
Android OAuth client cannot obtain a Google credential at all: Google Play
services refuses, and google_sign_in surfaces the refusal as
``GoogleSignInException(canceled, "[16] Account reauth failed.")``, which reads
like the user dismissed the dialog.

This repository publishes two differently signed Android binaries from one
workflow. The ``.aab`` goes to Play, which re-signs it with the Play App
Signing key; the ``.apk`` attached to GitHub Releases keeps the CI keystore's
own certificate. Registering only the former is what broke Google Drive sync
for every user who installed the APK from GitHub Releases (the channel
README.md points stable Android users at), while Play open-test users were
unaffected. Upgrading could never fix it, because that APK carries
``UPDATE_CHANNEL=github`` and so self-updates within the same broken channel.

The guard fails (exit code 1) when the APK's signer certificate is not one of
[REGISTERED_SIGNING_CERTS]. Adding a fingerprint there is a claim that an
Android OAuth client for package ``app.submersion`` with that fingerprint
exists in Google Cloud project 433819313354; the claim cannot be verified from
CI, so the entry and the console registration have to be made together.

Only the APK is checked. The AAB's shipped signature is applied by Play after
upload, so its certificate does not exist at build time.

The signing block is parsed with the standard library alone so the check runs
identically in CI (Linux) and locally (macOS) without an Android SDK on PATH.

Usage:
    check_apk_signing_cert.py <app.apk> [more.apk ...]
"""

import hashlib
import mmap
import struct
import sys

APK_SIG_BLOCK_MAGIC = b"APK Sig Block 42"

# Signature scheme block IDs, from the APK signing block specification.
V2_BLOCK_ID = 0x7109871A
V3_BLOCK_ID = 0xF05368C0
V31_BLOCK_ID = 0x1B93AD61

# Highest scheme first: a v3 block supersedes v2 and is what a current device
# uses to decide the app's signing identity.
SCHEME_BLOCK_IDS = (V31_BLOCK_ID, V3_BLOCK_ID, V2_BLOCK_ID)

EOCD_MAGIC = b"PK\x05\x06"
EOCD_MIN_SIZE = 22
MAX_COMMENT_SIZE = 0xFFFF

# SHA-1 fingerprints registered as Android OAuth clients for app.submersion.
# See the module docstring: an entry here without the matching console client
# breaks Google Drive sign-in for everyone running that build.
REGISTERED_SIGNING_CERTS = {
    "61b92267316a4b8ac71663c3b2490c7941cc4b89": (
        "CI release keystore, signs the APK attached to GitHub Releases"
    ),
}


class SigningBlockError(Exception):
    """Raised when an APK has no parseable v2/v3 signing block."""


def normalise(fingerprint):
    """Reduce a fingerprint to lowercase hex, ignoring colons and whitespace."""
    return "".join(fingerprint.split()).replace(":", "").lower()


def _read_u32(data, offset):
    return struct.unpack_from("<I", data, offset)[0]


def _read_u64(data, offset):
    return struct.unpack_from("<Q", data, offset)[0]


def _find_eocd(data):
    """Return the offset of the End Of Central Directory record."""
    search_start = max(0, len(data) - (EOCD_MIN_SIZE + MAX_COMMENT_SIZE))
    offset = data.rfind(EOCD_MAGIC, search_start)
    if offset < 0:
        raise SigningBlockError("not a ZIP archive: no end-of-central-directory record")
    return offset


def _signing_block_pairs(data):
    """Return the ``{id: value}`` pairs of the APK Signing Block.

    The block sits immediately before the central directory, and is framed by
    a size field at each end plus a trailing magic string.
    """
    try:
        return _unchecked_signing_block_pairs(data)
    except struct.error as error:
        # Every _read_u32/_read_u64 below walks offsets taken from the file
        # itself, so a truncated or hostile APK can point past the end. Report
        # that as a guard failure; an escaping struct.error would crash the
        # release build rather than failing it.
        raise SigningBlockError(f"malformed APK Signing Block: {error}") from error


def _unchecked_signing_block_pairs(data):
    """Body of [_signing_block_pairs], minus the struct.error translation."""
    eocd = _find_eocd(data)
    cd_offset = _read_u32(data, eocd + 16)
    if cd_offset < len(APK_SIG_BLOCK_MAGIC) + 8:
        raise SigningBlockError("no APK Signing Block: the APK is not v2/v3 signed")

    magic_start = cd_offset - len(APK_SIG_BLOCK_MAGIC)
    if data[magic_start:cd_offset] != APK_SIG_BLOCK_MAGIC:
        raise SigningBlockError("no APK Signing Block: the APK is not v2/v3 signed")

    size = _read_u64(data, magic_start - 8)
    block_start = cd_offset - size
    if block_start < 8 or _read_u64(data, block_start - 8) != size:
        raise SigningBlockError("APK Signing Block size fields disagree")

    pairs = {}
    offset = block_start
    end = magic_start - 8
    while offset < end:
        pair_length = _read_u64(data, offset)
        # A pair spans [offset, offset + 8 + pair_length) and must stay inside
        # the pairs section, which ends where the trailing size field begins.
        # Allowing it to reach into that field would feed eight bytes of
        # framing to the scheme-block parser as though they were signature
        # data.
        if pair_length < 4 or offset + 8 + pair_length > end:
            raise SigningBlockError("APK Signing Block is truncated")
        block_id = _read_u32(data, offset + 8)
        pairs[block_id] = data[offset + 12 : offset + 8 + pair_length]
        offset += 8 + pair_length

    # Redundant while the per-pair bound above is correct, and kept precisely
    # because that bound was once wrong: it allowed a pair to finish 8 bytes
    # past `end`, which this check would have caught independently.
    if offset != end:  # pragma: no cover - unreachable while the bound holds
        raise SigningBlockError("APK Signing Block pairs do not fill the block")
    return pairs


def _first_certificate(scheme_block):
    """Extract the first signer's DER certificate from a v2/v3 scheme block.

    Layout, every field length-prefixed with a u32: signers -> signer ->
    signed data -> (digests, certificates) -> certificate. Only the first
    signer is read; Submersion signs with a single key, and the first entry is
    the one whose identity Google matches.
    """
    try:
        # Step into signers, then the first signer, then its signed data.
        offset = 4  # length of the signers sequence
        offset += 4  # length of the first signer
        signed_data_length = _read_u32(scheme_block, offset)
        offset += 4
        signed_data = scheme_block[offset : offset + signed_data_length]

        digests_length = _read_u32(signed_data, 0)
        certificates_start = 4 + digests_length
        certificates_length = _read_u32(signed_data, certificates_start)
        certificates = signed_data[
            certificates_start + 4 : certificates_start + 4 + certificates_length
        ]

        first_length = _read_u32(certificates, 0)
        certificate = certificates[4 : 4 + first_length]
    except struct.error as error:
        raise SigningBlockError(f"malformed signature scheme block: {error}") from error

    if not certificate:
        raise SigningBlockError("signature scheme block carries no certificate")
    return certificate


def sha1_fingerprint(certificate):
    """Return a DER certificate's SHA-1 digest, as Google's console shows it.

    SHA-1 is not a security choice here and cannot be exchanged for a stronger
    digest. An Android OAuth client is registered against the SHA-1
    fingerprint of the signing certificate, so this value is only meaningful
    when computed the way Google computes it; a SHA-256 digest would match
    nothing the console exposes.

    Nothing secret is hashed: a signing certificate is public and ships inside
    every copy of the APK. No integrity decision rests on the digest either.
    Android verifies the signature itself, and this guard only compares
    identifiers. Hence the `usedforsecurity=False` declaration.

    CodeQL's py/weak-sensitive-data-hashing fires here on a name-based
    heuristic, and is excluded in .github/codeql/codeql-config.yml, which
    carries the full reasoning. Inline suppression comments do not work:
    GitHub code scanning does not honour them.
    """
    return hashlib.sha1(certificate, usedforsecurity=False).hexdigest()


def signer_sha1(path):
    """Return the lowercase SHA-1 hex digest of the APK's signer certificate."""
    with open(path, "rb") as apk:
        # Mapped rather than read: a release APK runs to hundreds of MB and
        # this parser only ever seeks, slices and unpacks, so a full in-memory
        # copy buys nothing. The slices handed back are ordinary bytes, so
        # they outlive the mapping.
        try:
            mapped = mmap.mmap(apk.fileno(), 0, access=mmap.ACCESS_READ)
        except ValueError as error:
            # mmap rejects a zero-length file; report it like any other
            # unparseable input rather than escaping as a ValueError.
            raise SigningBlockError(f"cannot read APK: {error}") from error
        with mapped as data:
            pairs = _signing_block_pairs(data)
            for block_id in SCHEME_BLOCK_IDS:
                if block_id in pairs:
                    return sha1_fingerprint(_first_certificate(pairs[block_id]))
    raise SigningBlockError(
        "APK Signing Block holds no v2, v3 or v3.1 signature scheme block"
    )


def main(argv, registered=None):
    if not argv:
        print(f"Usage: {sys.argv[0]} <app.apk> [more.apk ...]", file=sys.stderr)
        return 2

    registered = REGISTERED_SIGNING_CERTS if registered is None else registered
    expected = {normalise(key): value for key, value in registered.items()}

    failed = False
    for path in argv:
        try:
            fingerprint = signer_sha1(path)
        except (SigningBlockError, OSError) as error:
            print(f"FAIL {path}: {error}", file=sys.stderr)
            failed = True
            continue

        if fingerprint in expected:
            print(f"OK   {path}: signed by {expected[fingerprint]} ({fingerprint})")
            continue

        failed = True
        print(
            f"FAIL {path}: signer certificate SHA-1 {fingerprint} is not registered\n"
            "     as an Android OAuth client, so Google Sign-In cannot work in this\n"
            "     build. Users would see 'Google Sign-In was cancelled' with\n"
            "     '[16] Account reauth failed.' and have no way to recover.\n"
            "     Either register package app.submersion with this SHA-1 in Google\n"
            "     Cloud project 433819313354 and add it to REGISTERED_SIGNING_CERTS,\n"
            "     or sign with a keystore that is already registered.\n"
            "     Registered: " + ", ".join(sorted(expected)),
            file=sys.stderr,
        )

    return 1 if failed else 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv[1:]))
