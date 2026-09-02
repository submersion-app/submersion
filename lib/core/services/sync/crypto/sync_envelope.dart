import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid_value.dart';

import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/utils/bounded_inflate.dart';

/// Single-shot SBE1 envelope: the byte form of every encrypted sync file.
///
/// Layout (spec 3.3): "SBE1"(4) | libraryKeyId(16) | flags(1) | nonce(12)
/// | AES-256-GCM ciphertext || 16-byte tag. AAD = UTF-8 logical filename.
/// flags bit0 = payload was gzipped before encryption.
abstract final class SyncEnvelope {
  static const List<int> magic = [0x53, 0x42, 0x45, 0x31]; // "SBE1"
  static const int _headerLength = 4 + 16 + 1 + 12;
  static const int _flagGzip = 0x01;

  /// The largest plaintext an envelope will gzip on seal or inflate to on
  /// open.
  ///
  /// Derived from what a sync payload can legitimately be, not from a
  /// round number. The only structurally bounded kind is a base part, cut
  /// to exactly `BaseChunker.defaultPartSize` (8 MiB), so even a 648 MB
  /// library publishes as 78 small envelopes; this leaves that path 32x of
  /// headroom. The unbounded kind is a changeset, which is built,
  /// JSON-encoded, gzipped and encrypted whole in memory on the writer and
  /// decoded whole in memory on the reader. A plaintext past a few hundred
  /// megabytes therefore cannot be applied even if it inflates, so the cap
  /// refuses only payloads that were already fatal, and turns an OOM kill
  /// into a transient-stop error.
  static const int defaultMaxPlaintextBytes = 256 * 1024 * 1024;

  static final AesGcm _aesGcm = AesGcm.with256bits();

  static bool hasMagic(List<int> bytes) =>
      bytes.length >= magic.length &&
      bytes[0] == magic[0] &&
      bytes[1] == magic[1] &&
      bytes[2] == magic[2] &&
      bytes[3] == magic[3];

  /// The UUID string at header offset 4, without decrypting.
  static String libraryKeyIdOf(Uint8List bytes) {
    if (!hasMagic(bytes) || bytes.length < _headerLength) {
      throw const EnvelopeCorruptException('Not an SBE1 envelope');
    }
    return UuidValue.fromByteList(Uint8List.sublistView(bytes, 4, 20)).uuid;
  }

  static Future<Uint8List> seal({
    required Uint8List plaintext,
    required SecretKey dataKey,
    required String libraryKeyId,
    required String filename,
    bool compress = true,
    int maxPlaintextBytes = defaultMaxPlaintextBytes,
    List<int>? nonceForTest,
  }) async {
    var payload = plaintext;
    var flags = 0;
    // A payload past the cap is stored uncompressed rather than refused: a
    // device must never write an envelope [open] would reject, and only the
    // gzip flag makes that possible. The upload is larger, but the write
    // path stays total and nothing is stranded. Reaching this needs a
    // single changeset of a quarter gigabyte, which the in-memory encode
    // above it would already be struggling with.
    if (compress && plaintext.length <= maxPlaintextBytes) {
      final gz = Uint8List.fromList(gzip.encode(plaintext));
      if (gz.length < plaintext.length) {
        payload = gz;
        flags |= _flagGzip;
      }
    }
    final nonce = nonceForTest ?? _aesGcm.newNonce();
    final box = await _aesGcm.encrypt(
      payload,
      secretKey: dataKey,
      nonce: nonce,
      aad: utf8.encode(filename),
    );
    final keyIdBytes = UuidValue.withValidation(libraryKeyId).toBytes();
    final out = BytesBuilder(copy: false)
      ..add(magic)
      ..add(keyIdBytes)
      ..addByte(flags)
      ..add(box.nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return out.takeBytes();
  }

  static Future<Uint8List> open({
    required Uint8List envelope,
    required SecretKey dataKey,
    required String expectedLibraryKeyId,
    required String filename,
    int maxPlaintextBytes = defaultMaxPlaintextBytes,
  }) async {
    if (!hasMagic(envelope) || envelope.length < _headerLength + 16) {
      throw const EnvelopeCorruptException('Not an SBE1 envelope');
    }
    final keyId = libraryKeyIdOf(envelope);
    if (keyId != expectedLibraryKeyId.toLowerCase()) {
      throw SyncEncryptionRequired(
        libraryKeyId: keyId,
        message: 'File is encrypted under a different library key',
      );
    }
    final flags = envelope[20];
    final nonce = Uint8List.sublistView(envelope, 21, 21 + 12);
    final body = Uint8List.sublistView(envelope, _headerLength);
    final box = SecretBox(
      Uint8List.sublistView(body, 0, body.length - 16),
      nonce: nonce,
      mac: Mac(Uint8List.sublistView(body, body.length - 16)),
    );
    final List<int> payload;
    try {
      payload = await _aesGcm.decrypt(
        box,
        secretKey: dataKey,
        aad: utf8.encode(filename),
      );
    } on SecretBoxAuthenticationError {
      throw const EnvelopeCorruptException(
        'Envelope failed authentication (corrupt, tampered, or wrong name)',
      );
    }
    if ((flags & _flagGzip) != 0) {
      // Bounded and chunked. gzip.decode is a single native call that has
      // already allocated the whole body by the time it returns, so a
      // length check after the fact buys nothing; the guard has to abort
      // from inside the inflate.
      //
      // AES-GCM ran first, so reaching here means the payload authenticated
      // under the library data key: the residual threat is a peer inside
      // the trust boundary, not a network attacker. The gzip flag itself is
      // read from header byte 20, which is outside both the ciphertext and
      // the AAD and so is not authenticated at all, which is what lets a
      // keyless attacker turn any file into "not a gzip stream".
      //
      // The blob cap matches the body cap. For anything this seal wrote
      // that is free: the flag is only set when the gzip came out strictly
      // smaller than its plaintext, so the blob is always the shorter of
      // the two and the body cap is the one that binds. A foreign writer
      // is not bound by that, so a blob over the cap is refused on its
      // length even if it would have inflated to something under it. That
      // is deliberate. Such an envelope is itself a quarter-gigabyte file,
      // and the alternative is copying it whole into the native filter
      // before the first chunk comes back.
      try {
        return inflateBounded(
          payload,
          decoder: gzip.decoder,
          maxBytes: maxPlaintextBytes,
          maxBlobBytes: maxPlaintextBytes,
        );
      } on BoundedInflateException catch (e) {
        throw EnvelopeCorruptException(
          'Envelope payload rejected: ${e.message}',
        );
      }
    }
    return Uint8List.fromList(payload);
  }
}
