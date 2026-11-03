import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';

/// The layout of the SBE1 backup envelope (see `BackupCrypto`), shared by
/// the file reader and the in-memory one a browser uses (issue #4121), so
/// the two cannot disagree about a frame.
///
/// "SBE1"(4) | libraryKeyId(16) | flags(1, bit1 = framed) | uint32 BE
/// keyslotBlockLen | keyslot JSON, then frames of uint32 BE bodyLen |
/// nonce(12) | AES-256-GCM ciphertext || tag(16).
abstract final class SbeFrames {
  static const int flagFramed = 0x02;
  static const int headerFixedLength = 4 + 16 + 1 + 4;
  static const int nonceLength = 12;
  static const int tagLength = 16;

  static final AesGcm _aesGcm = AesGcm.with256bits();

  /// The key id and the keyslot block's length from the first
  /// [headerFixedLength] bytes of an envelope.
  static ({Uint8List keyIdBytes, int keyslotLength}) readFixedHeader(
    Uint8List fixed,
  ) {
    if (fixed.length < headerFixedLength || !SyncEnvelope.hasMagic(fixed)) {
      throw const EnvelopeCorruptException('Not an encrypted backup');
    }
    if ((fixed[20] & flagFramed) == 0) {
      throw const EnvelopeCorruptException('Backup is not a framed envelope');
    }
    return (
      keyIdBytes: Uint8List.fromList(Uint8List.sublistView(fixed, 4, 20)),
      keyslotLength: ByteData.sublistView(fixed, 21, 25).getUint32(0),
    );
  }

  /// AAD per frame: keyId(16) || uint64 BE frameIndex || finalFlag(1), so
  /// frames cannot be reordered, substituted or truncated undetected.
  static List<int> frameAad(List<int> keyId16, int index, bool isFinal) {
    // Two 32-bit halves: setUint64 throws compiled to JavaScript (#4194).
    final b = ByteData(8)
      ..setUint32(0, index ~/ 0x100000000)
      ..setUint32(4, index % 0x100000000);
    return [...keyId16, ...b.buffer.asUint8List(), isFinal ? 1 : 0];
  }

  /// Decrypts one frame [body] (nonce, ciphertext and tag).
  static Future<List<int>> openFrame(
    Uint8List body, {
    required SecretKey dataKey,
    required List<int> keyIdBytes,
    required int index,
    required bool isFinal,
  }) async {
    if (body.length < nonceLength + tagLength) {
      throw const EnvelopeCorruptException('Backup frame truncated');
    }
    final box = SecretBox(
      Uint8List.sublistView(body, nonceLength, body.length - tagLength),
      nonce: Uint8List.sublistView(body, 0, nonceLength),
      mac: Mac(Uint8List.sublistView(body, body.length - tagLength)),
    );
    try {
      return await _aesGcm.decrypt(
        box,
        secretKey: dataKey,
        aad: frameAad(keyIdBytes, index, isFinal),
      );
    } on SecretBoxAuthenticationError {
      throw const EnvelopeCorruptException(
        'Backup frame failed authentication '
        '(corrupt, tampered, reordered, or truncated)',
      );
    }
  }
}
