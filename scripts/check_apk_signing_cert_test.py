#!/usr/bin/env python3
"""Tests for check_apk_signing_cert."""

import hashlib
import io
import os
import struct
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import check_apk_signing_cert as guard  # noqa: E402


def _sha1(data):
    """SHA-1 of test bytes, matching the guard's own fingerprint helper.

    See check_apk_signing_cert.sha1_fingerprint for why SHA-1 is fixed here
    and why the CodeQL sensitive-data heuristic does not apply.
    """
    return hashlib.sha1(data, usedforsecurity=False).hexdigest()


def _length_prefixed(payload):
    """u32 length prefix, the encoding used throughout the v2/v3 schemes."""
    return struct.pack("<I", len(payload)) + payload


def _signer_block(cert_der, extra_signed_data=b""):
    """Build one signer entry holding ``cert_der``.

    Mirrors the real layout: signed data is a length-prefixed record whose
    first field is the digest sequence and whose second is the certificate
    sequence.
    """
    digests = _length_prefixed(b"\x00" * 12)  # opaque to this guard
    certificates = _length_prefixed(_length_prefixed(cert_der))
    signed_data = _length_prefixed(digests + certificates + extra_signed_data)
    return _length_prefixed(signed_data + b"\x00" * 8)


def _signing_block(pairs):
    """Assemble an APK Signing Block from ``{id: value}`` pairs."""
    body = b""
    for block_id, value in pairs.items():
        body += struct.pack("<QI", len(value) + 4, block_id) + value
    size = len(body) + 8 + 16
    return (
        struct.pack("<Q", size) + body + struct.pack("<Q", size) + guard.APK_SIG_BLOCK_MAGIC
    )


def _apk_with_signing_block(cert_der, block_id=guard.V2_BLOCK_ID, pairs=None):
    """Write a ZIP and splice a signing block in ahead of its central directory.

    The signing block sits between the last local file entry and the central
    directory, so every central-directory offset shifts by its length.
    """
    raw = io.BytesIO()
    with zipfile.ZipFile(raw, "w") as zf:
        zf.writestr("AndroidManifest.xml", "placeholder")
    data = raw.getvalue()

    eocd = data.rindex(b"PK\x05\x06")
    cd_offset = struct.unpack_from("<I", data, eocd + 16)[0]

    if pairs is None:
        pairs = {block_id: _length_prefixed(_signer_block(cert_der))}
    block = _signing_block(pairs)

    patched = bytearray(data[:cd_offset] + block + data[cd_offset:])
    struct.pack_into("<I", patched, eocd + len(block) + 16, cd_offset + len(block))
    return bytes(patched)


def _write_temp(data, suffix=".apk"):
    handle, path = tempfile.mkstemp(suffix=suffix)
    with os.fdopen(handle, "wb") as f:
        f.write(data)
    return path


class SignerCertificateTest(unittest.TestCase):
    def setUp(self):
        self.cert = b"pretend-x509-der-bytes"
        self.fingerprint = _sha1(self.cert)
        self._paths = []

    def tearDown(self):
        for path in self._paths:
            os.unlink(path)

    def _apk(self, *args, **kwargs):
        path = _write_temp(_apk_with_signing_block(*args, **kwargs))
        self._paths.append(path)
        return path

    def test_reads_fingerprint_from_v2_block(self):
        path = self._apk(self.cert, block_id=guard.V2_BLOCK_ID)
        self.assertEqual(guard.signer_sha1(path), self.fingerprint)

    def test_reads_fingerprint_from_v3_block(self):
        path = self._apk(self.cert, block_id=guard.V3_BLOCK_ID)
        self.assertEqual(guard.signer_sha1(path), self.fingerprint)

    def test_prefers_v3_over_v2_when_both_present(self):
        """A v3 rotation block supersedes v2, so it decides the identity."""
        v3_cert = b"the-v3-certificate"
        path = self._apk(
            self.cert,
            pairs={
                guard.V2_BLOCK_ID: _length_prefixed(_signer_block(self.cert)),
                guard.V3_BLOCK_ID: _length_prefixed(_signer_block(v3_cert)),
            },
        )
        self.assertEqual(guard.signer_sha1(path), _sha1(v3_cert))

    def test_unsigned_apk_raises(self):
        raw = io.BytesIO()
        with zipfile.ZipFile(raw, "w") as zf:
            zf.writestr("AndroidManifest.xml", "placeholder")
        path = _write_temp(raw.getvalue())
        self._paths.append(path)
        with self.assertRaises(guard.SigningBlockError):
            guard.signer_sha1(path)

    def test_pair_running_into_the_trailing_size_field_raises(self):
        """Pairs must fit inside [block_start, end), not overlap the framing.

        The pairs section ends where the trailing size field begins. A pair
        whose declared length reaches into that field is malformed, and
        accepting it would hand the scheme-block parser eight bytes of framing
        as though they were signature data.
        """
        data = bytearray(_apk_with_signing_block(self.cert))
        magic_start = data.index(guard.APK_SIG_BLOCK_MAGIC)
        size = struct.unpack_from("<Q", data, magic_start - 8)[0]
        block_start = (magic_start + 16) - size

        pair_length = struct.unpack_from("<Q", data, block_start)[0]
        struct.pack_into("<Q", data, block_start, pair_length + 8)

        path = _write_temp(bytes(data))
        self._paths.append(path)
        with self.assertRaises(guard.SigningBlockError):
            guard.signer_sha1(path)

    def test_zip_with_no_signing_block_raises(self):
        """An empty ZIP puts the central directory at offset 0.

        That is the shape of an APK signed with v1 only, or not at all: there
        is no room before the central directory for a signing block.
        """
        raw = io.BytesIO()
        with zipfile.ZipFile(raw, "w"):
            pass
        path = _write_temp(raw.getvalue())
        self._paths.append(path)
        with self.assertRaises(guard.SigningBlockError):
            guard.signer_sha1(path)

    def test_disagreeing_size_fields_raise(self):
        """The block is framed by a size field at each end; they must match."""
        data = bytearray(_apk_with_signing_block(self.cert))
        magic_start = data.index(guard.APK_SIG_BLOCK_MAGIC)
        size = struct.unpack_from("<Q", data, magic_start - 8)[0]
        block_start = (magic_start + 16) - size

        # Corrupt the leading size only, so the two disagree.
        struct.pack_into("<Q", data, block_start - 8, size + 8)

        path = _write_temp(bytes(data))
        self._paths.append(path)
        with self.assertRaises(guard.SigningBlockError):
            guard.signer_sha1(path)

    def test_truncated_scheme_block_raises(self):
        """A scheme block too short for its nested lengths must not crash.

        struct.error escaping _first_certificate would surface as a traceback
        rather than a guard failure.
        """
        path = self._apk(self.cert, pairs={guard.V2_BLOCK_ID: b"\x00" * 8})
        with self.assertRaises(guard.SigningBlockError):
            guard.signer_sha1(path)

    def test_scheme_block_with_an_empty_certificate_raises(self):
        """A zero-length certificate would otherwise hash to a real digest."""
        path = self._apk(
            self.cert,
            pairs={guard.V2_BLOCK_ID: _length_prefixed(_signer_block(b""))},
        )
        with self.assertRaises(guard.SigningBlockError):
            guard.signer_sha1(path)

    def test_signing_block_without_a_known_scheme_raises(self):
        path = self._apk(self.cert, pairs={0x12345678: b"\x00" * 8})
        with self.assertRaises(guard.SigningBlockError):
            guard.signer_sha1(path)


class FingerprintNormalisationTest(unittest.TestCase):
    def test_accepts_colon_separated_uppercase(self):
        self.assertEqual(
            guard.normalise("B3:25:29:FF"),
            guard.normalise("b32529ff"),
        )

    def test_strips_whitespace(self):
        self.assertEqual(guard.normalise("  ab cd  "), "abcd")


class RegisteredCertsTest(unittest.TestCase):
    def test_every_registered_fingerprint_is_a_sha1_hex_digest(self):
        self.assertTrue(guard.REGISTERED_SIGNING_CERTS)
        for fingerprint in guard.REGISTERED_SIGNING_CERTS:
            self.assertEqual(len(fingerprint), 40, fingerprint)
            self.assertEqual(fingerprint, fingerprint.lower(), fingerprint)
            int(fingerprint, 16)  # raises if not hex

    def test_every_registered_fingerprint_names_where_it_is_registered(self):
        for description in guard.REGISTERED_SIGNING_CERTS.values():
            self.assertTrue(description.strip())


class MainTest(unittest.TestCase):
    def setUp(self):
        self._paths = []

    def tearDown(self):
        for path in self._paths:
            os.unlink(path)

    def _apk(self, cert):
        path = _write_temp(_apk_with_signing_block(cert))
        self._paths.append(path)
        return path

    def test_accepts_a_registered_certificate(self):
        cert = b"registered-cert"
        registered = {_sha1(cert): "test keystore"}
        self.assertEqual(guard.main([self._apk(cert)], registered=registered), 0)

    def test_rejects_an_unregistered_certificate(self):
        cert = b"some-other-cert"
        registered = {_sha1(b"registered-cert"): "test keystore"}
        self.assertEqual(guard.main([self._apk(cert)], registered=registered), 1)

    def test_rejects_an_unparseable_apk(self):
        path = _write_temp(b"not a zip at all")
        self._paths.append(path)
        self.assertEqual(guard.main([path], registered={"ab" * 20: "test"}), 1)

    def test_rejects_an_empty_file(self):
        """A zero-length file must fail as a guard error, not crash it."""
        path = _write_temp(b"")
        self._paths.append(path)
        self.assertEqual(guard.main([path], registered={"ab" * 20: "test"}), 1)

    def test_rejects_a_truncated_end_of_central_directory(self):
        """Unpacking past the end must fail as a guard error, not a traceback.

        The EOCD magic is present but the record is cut short, so reading the
        central-directory offset runs off the end of the file. struct.error
        escaping here would crash the release build instead of failing it.
        """
        path = _write_temp(b"PK\x05\x06" + b"\x00" * 5)
        self._paths.append(path)
        self.assertEqual(guard.main([path], registered={"ab" * 20: "test"}), 1)

    def test_requires_at_least_one_apk(self):
        self.assertEqual(guard.main([]), 2)


if __name__ == "__main__":
    unittest.main()
