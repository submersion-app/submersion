import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/recovery_code.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';

/// A sealed library file under a key this device does not hold (issue
/// #2567): the library is locked, or its passphrase changed.
class LibraryLockedException implements Exception {
  const LibraryLockedException(this.keyId);

  final String keyId;

  @override
  String toString() => 'LibraryLockedException($keyId)';
}

/// The key of an encrypted shared site library (issue #2567). Files are
/// SBE1 envelopes (AES-256-GCM) sealed with a data key derived from it,
/// bound to their path inside the library so one cannot stand in for
/// another.
class LibraryCipher {
  LibraryCipher({required this.keyId, required SecretKey libraryKey})
    : _libraryKey = libraryKey;

  final String keyId;
  final SecretKey _libraryKey;
  SecretKey? _dataKey;

  static Future<LibraryCipher> generate() async {
    final r = Random.secure();
    return LibraryCipher(
      keyId: const Uuid().v4(),
      libraryKey: SecretKey([for (var i = 0; i < 32; i++) r.nextInt(256)]),
    );
  }

  static Future<LibraryCipher> fromExported({
    required String keyId,
    required String key,
  }) async =>
      LibraryCipher(keyId: keyId, libraryKey: SecretKey(base64Decode(key)));

  Future<String> exportKey() async =>
      base64Encode(await _libraryKey.extractBytes());

  Future<SecretKey> _data() async => _dataKey ??= await Keyslots.deriveSubKey(
    _libraryKey,
    info: 'ssl:v1:data',
  );

  static bool isSealed(Uint8List bytes) => SyncEnvelope.hasMagic(bytes);

  static String keyIdOf(Uint8List bytes) => SyncEnvelope.libraryKeyIdOf(bytes);

  Future<Uint8List> seal(String path, Uint8List plain) async =>
      SyncEnvelope.seal(
        plaintext: plain,
        dataKey: await _data(),
        libraryKeyId: keyId,
        filename: path,
      );

  Future<Uint8List> open(String path, Uint8List sealed) async {
    final keyOfFile = keyIdOf(sealed);
    if (keyOfFile != keyId.toLowerCase()) {
      throw LibraryLockedException(keyOfFile);
    }
    return SyncEnvelope.open(
      envelope: sealed,
      dataKey: await _data(),
      expectedLibraryKeyId: keyId,
      filename: path,
    );
  }

  /// The library key wrapped for the passphrase and for the recovery code.
  Future<KeyslotFile> keyslots({
    required String passphrase,
    required String recoveryCode,
    KdfParams kdf = const KdfParams(),
  }) async => KeyslotFile(
    version: 1,
    libraryKeyId: keyId,
    slots: [
      await Keyslots.createSlot(
        type: 'passphrase',
        secret: passphrase,
        mlk: _libraryKey,
        kdf: kdf,
      ),
      await Keyslots.createSlot(
        type: 'recovery',
        secret: RecoveryCode.normalize(recoveryCode),
        mlk: _libraryKey,
        kdf: kdf,
      ),
    ],
  );

  /// A recovery slot for [recoveryCode], to replace the old one in the
  /// keyslots when a new code is issued.
  Future<Keyslot> recoverySlot(
    String recoveryCode, {
    KdfParams kdf = const KdfParams(),
  }) => Keyslots.createSlot(
    type: 'recovery',
    secret: RecoveryCode.normalize(recoveryCode),
    mlk: _libraryKey,
    kdf: kdf,
  );

  /// The cipher [secret] (the passphrase or the recovery code) unlocks
  /// from [file], or null when it unlocks nothing.
  static Future<LibraryCipher?> unlock(KeyslotFile file, String secret) async {
    final key = await Keyslots.tryUnwrap(file: file, secret: secret);
    return key == null
        ? null
        : LibraryCipher(keyId: file.libraryKeyId, libraryKey: key);
  }
}
