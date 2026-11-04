import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid_value.dart';

import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';
import 'package:submersion/features/backup/data/services/sbe_frames.dart';

/// Decrypts an encrypted backup (SBE1) held in memory, as a browser holds
/// the file its picker read (issue #4121). `BackupCrypto` reads the same
/// envelope from a file; both follow [SbeFrames].
///
/// AES-GCM runs in Web Crypto in a browser and Argon2id in the compute
/// worker (`Keyslots`), so the page stays responsive without an isolate.
abstract final class BackupCryptoImage {
  /// Whether [bytes] start like an encrypted backup.
  static bool isEncrypted(Uint8List bytes) =>
      bytes.length >= SbeFrames.headerFixedLength &&
      SyncEnvelope.hasMagic(bytes);

  /// The library key id the backup in [bytes] was encrypted under.
  static String libraryKeyIdOf(Uint8List bytes) =>
      UuidValue.fromByteList(_header(bytes).keyIdBytes).uuid;

  /// Decrypts with the embedded keyslots and a passphrase or recovery
  /// code. Throws [WrongPassphraseException] when no slot opens.
  static Future<Uint8List> decrypt(
    Uint8List bytes, {
    required String secret,
  }) async {
    final header = _header(bytes);
    final keyslots = KeyslotFile.fromJsonBytes(header.keyslotBytes);
    final mlk = await Keyslots.tryUnwrap(file: keyslots, secret: secret);
    if (mlk == null) throw const WrongPassphraseException();
    return _decryptFrames(
      bytes,
      header.framesAt,
      await Keyslots.deriveDataKey(mlk),
      header.keyIdBytes,
    );
  }

  /// Decrypts with an already unlocked library key. Throws
  /// [SyncEncryptionRequired] when the backup is under another key.
  static Future<Uint8List> decryptWithKey(
    Uint8List bytes, {
    required SecretKey mlk,
    required String expectedLibraryKeyId,
  }) async {
    final header = _header(bytes);
    final keyId = UuidValue.fromByteList(header.keyIdBytes).uuid;
    if (keyId != expectedLibraryKeyId.toLowerCase()) {
      throw SyncEncryptionRequired(
        libraryKeyId: keyId,
        message: 'Backup is encrypted under a different library key',
      );
    }
    return _decryptFrames(
      bytes,
      header.framesAt,
      await Keyslots.deriveDataKey(mlk),
      header.keyIdBytes,
    );
  }

  static ({Uint8List keyIdBytes, Uint8List keyslotBytes, int framesAt}) _header(
    Uint8List bytes,
  ) {
    final fixed = SbeFrames.readFixedHeader(
      Uint8List.sublistView(
        bytes,
        0,
        bytes.length < SbeFrames.headerFixedLength
            ? bytes.length
            : SbeFrames.headerFixedLength,
      ),
    );
    final framesAt = SbeFrames.headerFixedLength + fixed.keyslotLength;
    if (bytes.length < framesAt) {
      throw const EnvelopeCorruptException('Backup keyslot block truncated');
    }
    return (
      keyIdBytes: fixed.keyIdBytes,
      keyslotBytes: Uint8List.sublistView(
        bytes,
        SbeFrames.headerFixedLength,
        framesAt,
      ),
      framesAt: framesAt,
    );
  }

  static Future<Uint8List> _decryptFrames(
    Uint8List bytes,
    int offset,
    SecretKey dataKey,
    Uint8List keyIdBytes,
  ) async {
    final out = BytesBuilder(copy: false);
    var position = offset;
    var index = 0;
    var sawFinal = false;
    while (position < bytes.length) {
      if (position + 4 > bytes.length) {
        throw const EnvelopeCorruptException('Backup frame header truncated');
      }
      final bodyLength = ByteData.sublistView(
        bytes,
        position,
        position + 4,
      ).getUint32(0);
      final bodyStart = position + 4;
      final bodyEnd = bodyStart + bodyLength;
      if (bodyEnd > bytes.length) {
        throw const EnvelopeCorruptException('Backup frame truncated');
      }
      final isFinal = bodyEnd >= bytes.length;
      out.add(
        await SbeFrames.openFrame(
          Uint8List.sublistView(bytes, bodyStart, bodyEnd),
          dataKey: dataKey,
          keyIdBytes: keyIdBytes,
          index: index,
          isFinal: isFinal,
        ),
      );
      if (isFinal) sawFinal = true;
      position = bodyEnd;
      index++;
    }
    if (!sawFinal) {
      throw const EnvelopeCorruptException(
        'Backup truncated: final frame missing',
      );
    }
    return out.takeBytes();
  }
}
