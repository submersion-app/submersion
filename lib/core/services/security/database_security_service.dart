import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/security/database_encryption_migrator.dart';
import 'package:submersion/core/services/security/database_security_key_store.dart';
import 'package:submersion/core/services/security/database_security_sidecar.dart';
import 'package:submersion/core/services/security/security_preferences.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/recovery_code.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart'
    show WrongPassphraseException;

/// Owns the App Security credential: one Master Key wrapped into a sidecar
/// keyslot file (password + recovery slots), cached in secure storage after
/// unlock. App Lock verifies the password by unwrapping the Master Key;
/// Database Encryption derives the SQLCipher key from the same Master Key.
///
/// A plain singleton (not a provider): the startup gate and the Workmanager
/// headless isolate both need it before any ProviderScope exists — the same
/// reason DatabaseService is a singleton.
class DatabaseSecurityService {
  DatabaseSecurityService._();

  static final DatabaseSecurityService instance = DatabaseSecurityService._();

  SecurityPreferences? _prefs;
  DatabaseSecurityKeyStore _keyStore = DatabaseSecurityKeyStore();
  SecretKey? _mlk;
  String? _libraryKeyId;
  String? _databaseKeyHex;
  final Uuid _uuid = const Uuid();

  /// Must be called before anything else (startup, background isolate,
  /// tests). Idempotent for prefs; a [keyStore] override always wins so
  /// tests can swap in a fake keychain.
  Future<void> configure({
    required SharedPreferences prefs,
    DatabaseSecurityKeyStore? keyStore,
  }) async {
    _prefs ??= SecurityPreferences(prefs);
    if (keyStore != null) _keyStore = keyStore;
  }

  SecurityPreferences get _p {
    final p = _prefs;
    if (p == null) {
      throw StateError('DatabaseSecurityService.configure() not called');
    }
    return p;
  }

  bool get appLockEnabled => _p.appLockEnabled;
  bool get encryptionEnabled => _p.dbEncryptionEnabled;
  bool get isUnlocked => _mlk != null;

  /// Whether durable security credentials already exist for [dbPath].
  bool hasCredential({required String dbPath}) =>
      DatabaseSecuritySidecar.existsFor(dbPath);

  /// The key id minted at enableSecurity, once unlocked. Stable across
  /// password changes (rewrap only); used to label rebuilt sidecars.
  String? get libraryKeyId => _libraryKeyId;

  /// Non-null only after a successful unlock/cached-key load AND while
  /// encryption is enabled. App-lock-only mode never exposes a DB key.
  String? get databaseKeyHex => _databaseKeyHex;

  SecurityPreferences get preferences => _p;

  /// HKDF of the master key, namespaced for the SQLCipher raw key, as 64
  /// lowercase hex chars.
  static Future<String> deriveDbKeyHex(SecretKey mlk) async {
    final key = await Keyslots.deriveSubKey(mlk, info: 'sdb:v1:dbkey');
    final bytes = await key.extractBytes();
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Keychain to memory. Derives [databaseKeyHex] when encryption is
  /// enabled. False when nothing is cached (new device, keychain wipe).
  Future<bool> tryLoadCachedKey() async {
    final cached = await _keyStore.loadKey();
    if (cached == null) return false;
    await _adoptMlk(cached.mlk, cached.libraryKeyId, persist: false);
    return true;
  }

  /// Sidecar unwrap — [secret] may be the password or the recovery code
  /// (Keyslots.tryUnwrap walks both slots). On success caches the key to
  /// the keychain and derives the DB key. False on a wrong secret.
  Future<bool> unlockWithSecret(String secret, {required String dbPath}) async {
    final file = await DatabaseSecuritySidecar.read(dbPath);
    if (file == null) return false;
    final mlk = await Keyslots.tryUnwrap(file: file, secret: secret);
    if (mlk == null) return false;
    await _adoptMlk(mlk, file.libraryKeyId, persist: true);
    return true;
  }

  /// Mints the Master Key and sidecar (password + recovery slots), caches
  /// the key, and returns the recovery code — shown to the user exactly once.
  /// App Lock is an independent tier and must be enabled explicitly with
  /// [setAppLockEnabled].
  Future<String> enableSecurity({
    required String password,
    required String dbPath,
    KdfParams kdf = const KdfParams(),
  }) async {
    if (await DatabaseSecuritySidecar.read(dbPath) != null) {
      throw StateError('Security is already enabled for $dbPath');
    }
    final mlkBytes = _randomBytes(32);
    final mlk = SecretKey(mlkBytes);
    final libraryKeyId = _uuid.v4();
    final recoveryCode = RecoveryCode.generate();
    final file = KeyslotFile(
      version: 1,
      libraryKeyId: libraryKeyId,
      slots: [
        await Keyslots.createSlot(
          type: 'passphrase',
          secret: password,
          mlk: mlk,
          kdf: kdf,
        ),
        await Keyslots.createSlot(
          type: 'recovery',
          secret: recoveryCode,
          mlk: mlk,
          kdf: kdf,
        ),
      ],
    );
    await DatabaseSecuritySidecar.write(dbPath, file);
    await _adoptMlk(mlk, libraryKeyId, persist: true);
    return recoveryCode;
  }

  /// Enables or disables the App Lock UI gate without changing database
  /// encryption, keyslots, or the cached Master Key.
  Future<void> setAppLockEnabled(bool enabled) async {
    if (enabled && _mlk == null) {
      throw StateError('Cannot enable App Lock without an unlocked credential');
    }
    await _p.setAppLockEnabled(enabled);
  }

  /// Rewraps the passphrase slot only — the master key and recovery slot
  /// are untouched (NOT key rotation; the database is never re-encrypted).
  Future<void> changePassword({
    required String currentSecret,
    required String newPassword,
    required String dbPath,
    KdfParams kdf = const KdfParams(),
  }) async {
    final (file, mlk) = await _unlockedSidecar(currentSecret, dbPath);
    final updated = file.withReplacedSlot(
      await Keyslots.createSlot(
        type: 'passphrase',
        secret: newPassword,
        mlk: mlk,
        kdf: kdf,
      ),
    );
    await DatabaseSecuritySidecar.write(dbPath, updated);
  }

  /// Replaces the recovery slot with a freshly generated code and returns it.
  Future<String> regenerateRecoveryCode({
    required String currentSecret,
    required String dbPath,
    KdfParams kdf = const KdfParams(),
  }) async {
    final (file, mlk) = await _unlockedSidecar(currentSecret, dbPath);
    final code = RecoveryCode.generate();
    final updated = file.withReplacedSlot(
      await Keyslots.createSlot(
        type: 'recovery',
        secret: code,
        mlk: mlk,
        kdf: kdf,
      ),
    );
    await DatabaseSecuritySidecar.write(dbPath, updated);
    return code;
  }

  /// Removes all security: sidecar, cached key, prefs flags, memory.
  /// Encryption must be disabled first (the file would be unopenable
  /// otherwise) — throws [StateError] if it is still on.
  Future<void> disableSecurity({required String dbPath}) async {
    if (encryptionEnabled) {
      throw StateError('Disable encryption before disabling security');
    }
    await DatabaseSecuritySidecar.delete(dbPath);
    await _keyStore.clearKey();
    await _p.setAppLockEnabled(false);
    await _p.setDbEncryptionEnabled(false);
    _mlk = null;
    _libraryKeyId = null;
    _databaseKeyHex = null;
  }

  /// Encrypts the live database in place. Sequence:
  /// 1. safety backup (`pre_encrypt_<stamp>.db`, plaintext — DB still plain)
  /// 2. strict close
  /// 3. sqlcipher_export to encrypted staging + atomic swap
  /// 4. flag on, derive key, hand it to DatabaseService, reopen
  ///
  /// The flag flips only AFTER the file swap succeeded, so a crash mid-way
  /// leaves flag=off + plaintext file (consistent), or flag=off + encrypted
  /// file (header-probe self-heal at next startup flips the flag).
  Future<void> enableEncryption({
    DatabaseEncryptionMigrator? migrator,
    void Function(String phase)? onPhase,
    @visibleForTesting String? dbPathOverride,
    @visibleForTesting bool skipReopenForTesting = false,
  }) async {
    final mlk = _mlk;
    if (mlk == null) {
      throw StateError('Cannot enable encryption while locked');
    }
    if (encryptionEnabled) return;
    final m = migrator ?? DatabaseEncryptionMigrator();
    final dbPath =
        dbPathOverride ?? await DatabaseService.instance.databasePath;

    onPhase?.call('backup');
    if (!skipReopenForTesting) {
      final backupPath = p.join(
        p.dirname(dbPath),
        'Backups',
        'pre_encrypt_${_timestamp()}.db',
      );
      await DatabaseService.instance.backup(backupPath);
      await DatabaseService.instance.close(strict: true);
    }

    onPhase?.call('encrypt');
    final keyHex = await deriveDbKeyHex(mlk);
    await m.encryptInPlace(dbPath: dbPath, keyHex: keyHex);

    await _p.setDbEncryptionEnabled(true);
    await refreshDerivedKey();

    if (!skipReopenForTesting) {
      onPhase?.call('reopen');
      DatabaseService.instance.databaseKeyHex = _databaseKeyHex;
      await DatabaseService.instance.reinitializeAtPath(dbPath);
    }
  }

  /// Decrypts in place; mirror image of [enableEncryption]. When App Lock is
  /// still enabled, the shared credential remains for that tier. Otherwise
  /// this was the last enabled tier, so the unused sidecar and cached key are
  /// removed as well.
  Future<void> disableEncryption({
    DatabaseEncryptionMigrator? migrator,
    void Function(String phase)? onPhase,
    @visibleForTesting String? dbPathOverride,
    @visibleForTesting bool skipReopenForTesting = false,
  }) async {
    final mlk = _mlk;
    if (mlk == null) {
      throw StateError('Cannot disable encryption while locked');
    }
    if (!encryptionEnabled) return;
    final m = migrator ?? DatabaseEncryptionMigrator();
    final dbPath =
        dbPathOverride ?? await DatabaseService.instance.databasePath;

    if (!skipReopenForTesting) {
      await DatabaseService.instance.close(strict: true);
    }

    onPhase?.call('decrypt');
    final keyHex = await deriveDbKeyHex(mlk);
    await m.decryptInPlace(dbPath: dbPath, keyHex: keyHex);

    await _p.setDbEncryptionEnabled(false);
    await refreshDerivedKey();
    if (!appLockEnabled) {
      await disableSecurity(dbPath: dbPath);
    }

    if (!skipReopenForTesting) {
      onPhase?.call('reopen');
      DatabaseService.instance.databaseKeyHex = null;
      await DatabaseService.instance.reinitializeAtPath(dbPath);
    }
  }

  static String _timestamp() {
    final ts = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${ts.year.toString().padLeft(4, '0')}-${two(ts.month)}-'
        '${two(ts.day)}_${two(ts.hour)}${two(ts.minute)}${two(ts.second)}';
  }

  /// Nulls the in-memory MLK/key state WITHOUT touching prefs wiring
  /// (unlike [resetForTesting]) — used by the start-fresh escape hatch,
  /// which continues running in the same process.
  Future<void> clearInMemoryState() async {
    _mlk = null;
    _libraryKeyId = null;
    _databaseKeyHex = null;
  }

  /// Self-heal for a lost sidecar while the keychain still holds the MLK:
  /// rewraps the cached MLK under the user-confirmed password and a fresh
  /// recovery slot (the old recovery code died with the old sidecar).
  /// Returns the new recovery code for display.
  Future<String> rebuildSidecar({
    required String password,
    required String dbPath,
    KdfParams kdf = const KdfParams(),
  }) async {
    final mlk = _mlk;
    final keyId = _libraryKeyId;
    if (mlk == null || keyId == null) {
      throw StateError('Cannot rebuild sidecar while locked');
    }
    final recoveryCode = RecoveryCode.generate();
    final file = KeyslotFile(
      version: 1,
      libraryKeyId: keyId,
      slots: [
        await Keyslots.createSlot(
          type: 'passphrase',
          secret: password,
          mlk: mlk,
          kdf: kdf,
        ),
        await Keyslots.createSlot(
          type: 'recovery',
          secret: recoveryCode,
          mlk: mlk,
          kdf: kdf,
        ),
      ],
    );
    await DatabaseSecuritySidecar.write(dbPath, file);
    return recoveryCode;
  }

  /// Re-derives [databaseKeyHex] after the encryption flag changes
  /// (enable/disable encryption flows flip the flag while unlocked).
  Future<void> refreshDerivedKey() async {
    final mlk = _mlk;
    _databaseKeyHex = (mlk != null && encryptionEnabled)
        ? await deriveDbKeyHex(mlk)
        : null;
  }

  Future<(KeyslotFile, SecretKey)> _unlockedSidecar(
    String secret,
    String dbPath,
  ) async {
    final file = await DatabaseSecuritySidecar.read(dbPath);
    if (file == null) throw const WrongPassphraseException();
    final mlk = await Keyslots.tryUnwrap(file: file, secret: secret);
    if (mlk == null) throw const WrongPassphraseException();
    return (file, mlk);
  }

  Future<void> _adoptMlk(
    SecretKey mlk,
    String libraryKeyId, {
    required bool persist,
  }) async {
    _mlk = mlk;
    _libraryKeyId = libraryKeyId;
    _databaseKeyHex = encryptionEnabled ? await deriveDbKeyHex(mlk) : null;
    if (persist) {
      await _keyStore.saveKey(
        libraryKeyId: libraryKeyId,
        mlkBytes: await mlk.extractBytes(),
      );
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _prefs = null;
    _keyStore = DatabaseSecurityKeyStore();
    _mlk = null;
    _libraryKeyId = null;
    _databaseKeyHex = null;
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }
}
