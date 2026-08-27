import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid_value.dart';

import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';

/// Single-shot SBE1 envelope: the byte form of every encrypted sync file.
///
/// Layout (spec 3.3): "SBE1"(4) | libraryKeyId(16) | flags(1) | nonce(12)
/// | AES-256-GCM ciphertext || 16-byte tag. AAD = UTF-8 logical filename.
/// flags bit0 = payload was gzipped before encryption.
abstract final class SyncEnvelope {
  static const List<int> magic = [0x53, 0x42, 0x45, 0x31]; // "SBE1"
  static const int _headerLength = 4 + 16 + 1 + 12;
  static const int _flagGzip = 0x01;

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
    List<int>? nonceForTest,
  }) async {
    var payload = plaintext;
    var flags = 0;
    if (compress) {
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
      return Uint8List.fromList(gzip.decode(payload));
    }
    return Uint8List.fromList(payload);
  }
}
