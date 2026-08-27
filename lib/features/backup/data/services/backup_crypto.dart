import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid_value.dart';

import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';

/// Framed, self-decrypting encrypted backup artifact (spec 3.4).
///
/// Layout: "SBE1"(4) | libraryKeyId(16) | flags(1, bit1 = framed)
/// | uint32 BE keyslotBlockLen | keyslot JSON (same shape as the cloud
/// keyslot file), then frames of uint32 BE bodyLen | nonce(12) |
/// AES-256-GCM ciphertext || tag(16). AAD per frame = keyId(16) ||
/// uint64 BE frameIndex || finalFlag(1), so frames cannot be reordered,
/// substituted, or truncated undetected. Embedded keyslots make every
/// artifact restorable with just the passphrase or recovery code.
abstract final class BackupCrypto {
  static const String fileExtension = '.sbe';
  static const int frameSize = 8 * 1024 * 1024;
  static const int _flagFramed = 0x02;
  static const int _headerFixedLength = 4 + 16 + 1 + 4;

  static final AesGcm _aesGcm = AesGcm.with256bits();

  /// Encrypt [inPath] into an SBE1 envelope at [outPath].
  ///
  /// The frame loop (synchronous file IO + AES-GCM over the whole file) runs
  /// on a worker isolate: on a multi-hundred-MB database it is seconds to
  /// minutes of pure-Dart work that would otherwise freeze the UI. Only the
  /// key bytes cross the isolate boundary — [SecretKey] itself is not
  /// reliably sendable.
  static Future<void> encryptFile({
    required String inPath,
    required String outPath,
    required SecretKey mlk,
    required String libraryKeyId,
    required Uint8List keyslotBytes,
  }) async {
    final mlkBytes = Uint8List.fromList(await mlk.extractBytes());
    return _encryptOnWorker(
      inPath,
      outPath,
      mlkBytes,
      libraryKeyId,
      keyslotBytes,
    );
  }

  /// Minimal-scope hop to the worker isolate. Kept as its own method so the
  /// [Isolate.run] closure's enclosing scope holds only sendable values —
  /// Dart closures capture the whole scope, not just what they reference.
  static Future<void> _encryptOnWorker(
    String inPath,
    String outPath,
    Uint8List mlkBytes,
    String libraryKeyId,
    Uint8List keyslotBytes,
  ) {
    return Isolate.run(
      () => _encryptFileImpl(
        inPath: inPath,
        outPath: outPath,
        mlkBytes: mlkBytes,
        libraryKeyId: libraryKeyId,
        keyslotBytes: keyslotBytes,
      ),
      debugName: 'sbe-encrypt',
    );
  }

  static Future<void> _encryptFileImpl({
    required String inPath,
    required String outPath,
    required Uint8List mlkBytes,
    required String libraryKeyId,
    required Uint8List keyslotBytes,
  }) async {
    final dataKey = await Keyslots.deriveDataKey(SecretKey(mlkBytes));
    final keyIdBytes = UuidValue.withValidation(libraryKeyId).toBytes();
    final input = File(inPath).openSync();
    final out = File(outPath).openSync(mode: FileMode.write);
    try {
      out.writeFromSync(SyncEnvelope.magic);
      out.writeFromSync(keyIdBytes);
      out.writeByteSync(_flagFramed);
      out.writeFromSync(_uint32be(keyslotBytes.length));
      out.writeFromSync(keyslotBytes);
      final total = input.lengthSync();
      var offset = 0;
      var frameIndex = 0;
      do {
        final n = (total - offset).clamp(0, frameSize);
        final chunk = input.readSync(n);
        offset += n;
        final isFinal = offset >= total;
        final box = await _aesGcm.encrypt(
          chunk,
          secretKey: dataKey,
          aad: _frameAad(keyIdBytes, frameIndex, isFinal),
        );
        final body = BytesBuilder(copy: false)
          ..add(box.nonce)
          ..add(box.cipherText)
          ..add(box.mac.bytes);
        final bodyBytes = body.takeBytes();
        out.writeFromSync(_uint32be(bodyBytes.length));
        out.writeFromSync(bodyBytes);
        frameIndex++;
      } while (offset < total);
    } finally {
      input.closeSync();
      out.closeSync();
    }
  }

  /// Decrypt using the artifact's embedded keyslots and a passphrase or
  /// recovery code. Throws [WrongPassphraseException] when no slot opens.
  ///
  /// Runs on a worker isolate: the Argon2id KDF (64 MiB, several passes) and
  /// the full-file AES-GCM frame loop are both heavy pure-Dart work. The
  /// thrown exceptions are simple const classes, so they propagate across the
  /// isolate boundary unchanged.
  static Future<void> decryptFile({
    required String inPath,
    required String outPath,
    required String secret,
  }) {
    return Isolate.run(
      () => _decryptFileImpl(inPath: inPath, outPath: outPath, secret: secret),
      debugName: 'sbe-decrypt',
    );
  }

  static Future<void> _decryptFileImpl({
    required String inPath,
    required String outPath,
    required String secret,
  }) async {
    final input = File(inPath).openSync();
    try {
      final header = _readHeader(input);
      final keyslotFile = KeyslotFile.fromJsonBytes(header.keyslotBytes);
      final mlk = await Keyslots.tryUnwrap(file: keyslotFile, secret: secret);
      if (mlk == null) throw const WrongPassphraseException();
      final dataKey = await Keyslots.deriveDataKey(mlk);
      await _decryptFrames(input, outPath, dataKey, header.keyIdBytes);
    } finally {
      input.closeSync();
    }
  }

  /// Decrypt silently with an already-unlocked key. Throws
  /// [SyncEncryptionRequired] when the artifact's key differs.
  ///
  /// Runs on a worker isolate for the same reason as [decryptFile].
  static Future<void> decryptFileWithKey({
    required String inPath,
    required String outPath,
    required SecretKey mlk,
    required String expectedLibraryKeyId,
  }) async {
    final mlkBytes = Uint8List.fromList(await mlk.extractBytes());
    return _decryptWithKeyOnWorker(
      inPath,
      outPath,
      mlkBytes,
      expectedLibraryKeyId,
    );
  }

  /// See [_encryptOnWorker] for why this hop is a separate minimal scope.
  static Future<void> _decryptWithKeyOnWorker(
    String inPath,
    String outPath,
    Uint8List mlkBytes,
    String expectedLibraryKeyId,
  ) {
    return Isolate.run(
      () => _decryptFileWithKeyImpl(
        inPath: inPath,
        outPath: outPath,
        mlkBytes: mlkBytes,
        expectedLibraryKeyId: expectedLibraryKeyId,
      ),
      debugName: 'sbe-decrypt',
    );
  }

  static Future<void> _decryptFileWithKeyImpl({
    required String inPath,
    required String outPath,
    required Uint8List mlkBytes,
    required String expectedLibraryKeyId,
  }) async {
    final input = File(inPath).openSync();
    try {
      final header = _readHeader(input);
      final artifactKeyId = UuidValue.fromByteList(header.keyIdBytes).uuid;
      if (artifactKeyId != expectedLibraryKeyId.toLowerCase()) {
        throw SyncEncryptionRequired(
          libraryKeyId: artifactKeyId,
          message: 'Backup is encrypted under a different library key',
        );
      }
      final dataKey = await Keyslots.deriveDataKey(SecretKey(mlkBytes));
      await _decryptFrames(input, outPath, dataKey, header.keyIdBytes);
    } finally {
      input.closeSync();
    }
  }

  static Future<bool> isEncryptedBackup(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    final raf = file.openSync();
    try {
      if (raf.lengthSync() < _headerFixedLength) return false;
      final head = raf.readSync(4);
      return SyncEnvelope.hasMagic(head);
    } finally {
      raf.closeSync();
    }
  }

  static Future<String> libraryKeyIdOf(String path) async {
    final raf = File(path).openSync();
    try {
      final header = _readHeader(raf);
      return UuidValue.fromByteList(header.keyIdBytes).uuid;
    } finally {
      raf.closeSync();
    }
  }

  static ({Uint8List keyIdBytes, Uint8List keyslotBytes}) _readHeader(
    RandomAccessFile input,
  ) {
    input.setPositionSync(0);
    if (input.lengthSync() < _headerFixedLength) {
      throw const EnvelopeCorruptException('Not an encrypted backup');
    }
    final fixed = input.readSync(_headerFixedLength);
    if (!SyncEnvelope.hasMagic(fixed)) {
      throw const EnvelopeCorruptException('Not an encrypted backup');
    }
    final keyIdBytes = Uint8List.sublistView(fixed, 4, 20);
    final flags = fixed[20];
    if ((flags & _flagFramed) == 0) {
      throw const EnvelopeCorruptException('Backup is not a framed envelope');
    }
    final slotLen = ByteData.sublistView(fixed, 21, 25).getUint32(0);
    if (input.lengthSync() < _headerFixedLength + slotLen) {
      throw const EnvelopeCorruptException('Backup keyslot block truncated');
    }
    final keyslotBytes = input.readSync(slotLen);
    return (
      keyIdBytes: Uint8List.fromList(keyIdBytes),
      keyslotBytes: keyslotBytes,
    );
  }

  static Future<void> _decryptFrames(
    RandomAccessFile input,
    String outPath,
    SecretKey dataKey,
    Uint8List keyIdBytes,
  ) async {
    final out = File(outPath).openSync(mode: FileMode.write);
    try {
      final total = input.lengthSync();
      var frameIndex = 0;
      var sawFinal = false;
      while (true) {
        final pos = input.positionSync();
        if (pos >= total) break;
        if (sawFinal) {
          throw const EnvelopeCorruptException(
            'Backup has data after the final frame',
          );
        }
        final lenBytes = input.readSync(4);
        if (lenBytes.length < 4) {
          throw const EnvelopeCorruptException('Backup frame header truncated');
        }
        final bodyLen = ByteData.sublistView(lenBytes).getUint32(0);
        final body = input.readSync(bodyLen);
        if (body.length < bodyLen || bodyLen < 12 + 16) {
          throw const EnvelopeCorruptException('Backup frame truncated');
        }
        final isFinal = input.positionSync() >= total;
        final box = SecretBox(
          Uint8List.sublistView(body, 12, body.length - 16),
          nonce: Uint8List.sublistView(body, 0, 12),
          mac: Mac(Uint8List.sublistView(body, body.length - 16)),
        );
        final List<int> plain;
        try {
          plain = await _aesGcm.decrypt(
            box,
            secretKey: dataKey,
            aad: _frameAad(keyIdBytes, frameIndex, isFinal),
          );
        } on SecretBoxAuthenticationError {
          throw const EnvelopeCorruptException(
            'Backup frame failed authentication '
            '(corrupt, tampered, reordered, or truncated)',
          );
        }
        out.writeFromSync(plain);
        if (isFinal) sawFinal = true;
        frameIndex++;
      }
      if (!sawFinal) {
        throw const EnvelopeCorruptException(
          'Backup truncated: final frame missing',
        );
      }
    } finally {
      out.closeSync();
    }
  }

  static List<int> _frameAad(List<int> keyId16, int index, bool isFinal) {
    final b = ByteData(8)..setUint64(0, index);
    return [...keyId16, ...b.buffer.asUint8List(), isFinal ? 1 : 0];
  }

  static Uint8List _uint32be(int v) =>
      Uint8List(4)..buffer.asByteData().setUint32(0, v);
}
