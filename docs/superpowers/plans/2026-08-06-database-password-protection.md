# Database Password Protection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two-tier security: App Lock (password/biometric gate at launch + background-timeout re-lock) and Database Encryption (SQLCipher at-rest encryption of `submersion.db`), sharing one credential with a recovery code and an escape hatch (set aside locked DB, start fresh, restore from backup).

**Architecture:** Swap `sqlite3_flutter_libs` for `sqlcipher_flutter_libs` (one native lib serves plaintext and encrypted DBs). A random 32-byte Master Key is wrapped Argon2id-style into a keyslot sidecar file next to the DB (reusing `Keyslots` from encrypted backups); `HKDF(MLK, 'sdb:v1:dbkey')` becomes the raw SQLCipher key (`PRAGMA key = "x'<hex>'"`). The Master Key is cached in secure storage after first unlock so biometrics and headless background tasks work. A new `DatabaseSecurityService` singleton (pre-provider, like `DatabaseService`) owns state; the startup gate lives in `StartupWrapper` before any DB open.

**Tech Stack:** Flutter, drift, sqlite3 dart package, sqlcipher_flutter_libs, cryptography (Argon2id/AES-GCM/HKDF — already a dep), flutter_secure_storage (already a dep), local_auth (new), Riverpod 3, SharedPreferences.

**Spec:** `docs/superpowers/specs/2026-08-06-database-password-protection-design.md`

## Global Constraints

- Work in worktree `worktree-db-password-protection` only. Never touch the main checkout. Run `pwd` before trusting any shell result (Bash cwd can reset to the main checkout).
- No Drift schema change anywhere in this plan — do not touch the schema version ladder.
- `dart format .` (whole project) must be clean before every commit; `flutter analyze` treats infos as fatal in CI — fix all of them; never pipe analyze/test output through `tail`/`head`.
- Full `flutter test` runs need a 10-minute timeout minimum. Known pre-existing flakes: backup tests, media upload drain, recovery-code yoyo split.
- All new user-facing strings in settings UI go through l10n: add to `lib/l10n/app_en.arb` AND all 10 non-English ARB files, then run `flutter gen-l10n`. Startup/lock-screen strings (pre-l10n MaterialApp) are hardcoded English — that matches the existing splash screen precedent in `startup_page.dart`.
- No emojis anywhere. No hardcoded secrets. Commit at the end of every task (commits are pre-authorized); message style: imperative, no attribution lines.
- The `PRAGMA cipher_version` startup assertion must be skipped when `Platform.environment.containsKey('FLUTTER_TEST')` — host `flutter test` loads system SQLite, which has no cipher.
- `open.overrideFor` (sqlite3 loader override) is per-isolate state: it must be applied in the main isolate, the drift worker isolate opener, AND the Workmanager headless isolate.
- Prefs keys (exact): `app_lock_enabled`, `db_encryption_enabled`, `app_lock_timeout_minutes` (int: 0=immediate, 1/5/15, -1=never; default 5), `app_lock_biometrics_enabled` (default true). Secure-storage keys: `db_security_key_id`, `db_security_mlk`. Sidecar filename: `submersion.keys`. HKDF info string: `sdb:v1:dbkey`. Set-aside suffix: `.locked-<yyyy-MM-dd_HHmmss>`.

---

### Task 1: Engine swap to sqlcipher_flutter_libs

**Files:**
- Modify: `pubspec.yaml:22-32`
- Create: `lib/core/database/sqlcipher_setup.dart`
- Modify: `lib/main.dart` (call setup in `_bootstrap()`)
- Modify: `lib/core/services/database_service.dart` (cipher smoke assertion)
- Test: `test/core/database/sqlcipher_setup_test.dart`

**Interfaces:**
- Produces: `Future<void> setupSqlcipher()` — top-level, idempotent, applies the Android loader override; safe on every platform. `DatabaseService._assertCipherAvailable(AppDatabase db)` — private, called from `initialize()`.

- [ ] **Step 1: Swap the dependency**

Run: `flutter pub remove sqlite3_flutter_libs && flutter pub add sqlcipher_flutter_libs`

Then in `pubspec.yaml`, replace the old 0.5.x pin comment block (lines 26-31) with:

```yaml
  # SQLCipher-enabled replacement for sqlite3_flutter_libs (same maintainer,
  # same sqlite3 Dart API). One native lib serves both plaintext and
  # encrypted databases; the codec only engages when PRAGMA key is set.
  # Replacing also retires the EOL'd sqlite3_flutter_libs 0.5.x pin (#433).
```

- [ ] **Step 2: Check the package README for per-platform requirements**

Run: `dart pub deps | grep sqlcipher` to confirm resolution, then read the package README (`~/.pub-cache/hosted/pub.dev/sqlcipher_flutter_libs-*/README.md`). Confirm: (a) the exact Android override symbol (expected: `openCipherOnAndroid`), (b) whether Windows/Linux/macOS need any override or extra CMake/pod steps, (c) any note about conflicting plugins linking system SQLite. Apply anything it requires in Step 3. Also verify compile-option parity: search the README/CHANGELOG for the enabled SQLite compile options (FTS5, JSON1, RTREE) — then grep the app for reliance: `grep -rn "fts5\|MATCH\|json_extract\|rtree" lib/ --include=*.dart -il`. Record findings in the commit message body.

- [ ] **Step 3: Write `lib/core/database/sqlcipher_setup.dart`**

```dart
import 'dart:io';

import 'package:sqlite3/open.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

/// Applies the per-isolate sqlite3 loader override needed for SQLCipher.
///
/// `open.overrideFor` is per-isolate state: call this in EVERY isolate that
/// opens the database — the main isolate (bootstrap), the drift worker
/// isolate opener, and the Workmanager headless isolate.
///
/// Only Android needs an explicit override with sqlcipher_flutter_libs; on
/// iOS/macOS the pod links SQLCipher, and on Windows/Linux the bundled
/// library is picked up by the default loader. Idempotent.
void setupSqlcipher() {
  if (Platform.isAndroid) {
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  }
}
```

(If Step 2 revealed additional required overrides for other platforms, add them here with a comment citing the README.)

- [ ] **Step 4: Call it from bootstrap**

In `lib/main.dart` `_bootstrap()`, immediately after `WidgetsFlutterBinding.ensureInitialized()` (before anything can touch the DB), add:

```dart
setupSqlcipher();
```

with import `package:submersion/core/database/sqlcipher_setup.dart`.

- [ ] **Step 5: Add the cipher smoke assertion to DatabaseService**

In `lib/core/services/database_service.dart`, add at the end of `initialize()` (after `_database = await _openDatabase(...)`):

```dart
    await _assertCipherAvailable(_database!);
```

and the method:

```dart
  /// Fails loudly at startup if the native library is NOT SQLCipher — e.g.
  /// the dynamic linker resolved sqlite3 symbols to a system/plugin copy on
  /// iOS/macOS. Encrypted databases would be unopenable and enabling
  /// encryption would corrupt silently, so this must be caught on day one.
  ///
  /// Skipped under `flutter test`: the host test runner loads the system
  /// SQLite, which legitimately has no cipher.
  Future<void> _assertCipherAvailable(AppDatabase db) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    final rows = await db.customSelect('PRAGMA cipher_version').get();
    if (rows.isEmpty) {
      throw StateError(
        'SQLCipher is not linked: PRAGMA cipher_version returned nothing. '
        'The app was built against a non-SQLCipher sqlite3 library.',
      );
    }
  }
```

- [ ] **Step 6: Write the test**

`test/core/database/sqlcipher_setup_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/sqlcipher_setup.dart';

void main() {
  test('setupSqlcipher is callable and idempotent on the host', () {
    // On the host (not Android) this must be a no-op that never throws,
    // and calling it twice must be safe (per-isolate re-entry happens on
    // every background open).
    expect(setupSqlcipher, returnsNormally);
    expect(setupSqlcipher, returnsNormally);
  });
}
```

- [ ] **Step 7: Run test + analyze + existing DB tests**

Run: `flutter test test/core/database/ test/core/services/database_service_test.dart` (if that file glob differs, run `flutter test test/core/`) and `flutter analyze`.
Expected: PASS — the swap must not break any plaintext-DB behavior on the host.

- [ ] **Step 8: Verify a real build links SQLCipher**

Run: `flutter build macos --debug`
Expected: builds cleanly. (The runtime cipher_version assertion is exercised by the integration test in Task 15; iOS/Android/Windows/Linux link verification happens in CI on the PR.)

- [ ] **Step 9: Format and commit**

```bash
dart format .
git add -A
git commit -m "Swap sqlite3_flutter_libs for sqlcipher_flutter_libs"
```

---

### Task 2: SecurityPreferences and DatabaseSecurityKeyStore

**Files:**
- Create: `lib/core/services/security/security_preferences.dart`
- Create: `lib/core/services/security/database_security_key_store.dart`
- Test: `test/core/services/security/security_preferences_test.dart`
- Test: `test/core/services/security/database_security_key_store_test.dart`

**Interfaces:**
- Consumes: `FallbackSecureStorage` (`lib/core/services/secure_storage/fallback_secure_storage.dart`), `UnlockedKey` (`lib/core/services/sync/crypto/encryption_key_store.dart`).
- Produces:
  - `SecurityPreferences(SharedPreferences prefs)` with getters/setters: `bool appLockEnabled` / `Future<void> setAppLockEnabled(bool)`, `bool dbEncryptionEnabled` / `Future<void> setDbEncryptionEnabled(bool)`, `int appLockTimeoutMinutes` (default 5) / `Future<void> setAppLockTimeoutMinutes(int)`, `bool appLockBiometricsEnabled` (default true) / `Future<void> setAppLockBiometricsEnabled(bool)`.
  - `DatabaseSecurityKeyStore({FlutterSecureStorage? storage})` with `saveKey({required String libraryKeyId, required List<int> mlkBytes})`, `Future<UnlockedKey?> loadKey()`, `Future<void> clearKey()` — exact same shape as `BackupEncryptionKeyStore`.

- [ ] **Step 1: Write the failing tests**

`test/core/services/security/security_preferences_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/security/security_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SecurityPreferences> makePrefs() async {
    SharedPreferences.setMockInitialValues({});
    return SecurityPreferences(await SharedPreferences.getInstance());
  }

  test('defaults: both tiers off, 5 min timeout, biometrics on', () async {
    final prefs = await makePrefs();
    expect(prefs.appLockEnabled, false);
    expect(prefs.dbEncryptionEnabled, false);
    expect(prefs.appLockTimeoutMinutes, 5);
    expect(prefs.appLockBiometricsEnabled, true);
  });

  test('round-trips every setting', () async {
    final prefs = await makePrefs();
    await prefs.setAppLockEnabled(true);
    await prefs.setDbEncryptionEnabled(true);
    await prefs.setAppLockTimeoutMinutes(-1);
    await prefs.setAppLockBiometricsEnabled(false);
    expect(prefs.appLockEnabled, true);
    expect(prefs.dbEncryptionEnabled, true);
    expect(prefs.appLockTimeoutMinutes, -1);
    expect(prefs.appLockBiometricsEnabled, false);
  });
}
```

`test/core/services/security/database_security_key_store_test.dart` — copy the structure of the existing `test/features/backup/data/services/backup_encryption_key_store_test.dart` if it exists (`ls test/features/backup/data/services/`); otherwise write, using the same in-memory `FlutterSecureStorage` mocking approach found in any existing key-store test (`grep -rln "FlutterSecureStorage" test/ | head`). The three cases:

```dart
  test('loadKey returns null when nothing stored', () async { /* ... */ });
  test('saveKey then loadKey round-trips id and MLK bytes', () async { /* ... */ });
  test('clearKey removes both entries', () async { /* ... */ });
```

(Concrete mocking pattern: if no precedent test exists, use `FlutterSecureStorage.setMockInitialValues({})` — available in flutter_secure_storage 10.x — and the real class.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/security/`
Expected: FAIL — files under `lib/core/services/security/` do not exist.

- [ ] **Step 3: Implement `security_preferences.dart`**

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// Typed access to the App Security settings.
///
/// [appLockTimeoutMinutes]: 0 = lock immediately on background,
/// -1 = never re-lock, otherwise minutes in background before re-lock.
class SecurityPreferences {
  static const String appLockEnabledKey = 'app_lock_enabled';
  static const String dbEncryptionEnabledKey = 'db_encryption_enabled';
  static const String appLockTimeoutMinutesKey = 'app_lock_timeout_minutes';
  static const String appLockBiometricsEnabledKey =
      'app_lock_biometrics_enabled';

  final SharedPreferences _prefs;

  SecurityPreferences(this._prefs);

  bool get appLockEnabled => _prefs.getBool(appLockEnabledKey) ?? false;
  Future<void> setAppLockEnabled(bool value) =>
      _prefs.setBool(appLockEnabledKey, value);

  bool get dbEncryptionEnabled =>
      _prefs.getBool(dbEncryptionEnabledKey) ?? false;
  Future<void> setDbEncryptionEnabled(bool value) =>
      _prefs.setBool(dbEncryptionEnabledKey, value);

  int get appLockTimeoutMinutes =>
      _prefs.getInt(appLockTimeoutMinutesKey) ?? 5;
  Future<void> setAppLockTimeoutMinutes(int value) =>
      _prefs.setInt(appLockTimeoutMinutesKey, value);

  bool get appLockBiometricsEnabled =>
      _prefs.getBool(appLockBiometricsEnabledKey) ?? true;
  Future<void> setAppLockBiometricsEnabled(bool value) =>
      _prefs.setBool(appLockBiometricsEnabledKey, value);
}
```

- [ ] **Step 4: Implement `database_security_key_store.dart`**

Mirror `BackupEncryptionKeyStore` exactly (`lib/features/backup/data/services/backup_encryption_key_store.dart`), minus the mirror methods (the on-disk sidecar is the mirror for this feature):

```dart
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart'
    show UnlockedKey;

/// Device-local custody of the database security master key, cached after
/// first unlock so biometric unlock and headless background opens work.
///
/// Independent of the sync and backup key stores — distinct storage keys.
/// No keyslot mirror: the sidecar file next to the database is the durable
/// wrapped copy (see DatabaseSecuritySidecar).
class DatabaseSecurityKeyStore {
  static const String keyIdStorageKey = 'db_security_key_id';
  static const String mlkStorageKey = 'db_security_mlk';

  final FallbackSecureStorage _storage;

  DatabaseSecurityKeyStore({FlutterSecureStorage? storage})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage());

  Future<void> saveKey({
    required String libraryKeyId,
    required List<int> mlkBytes,
  }) async {
    await _storage.write(key: keyIdStorageKey, value: libraryKeyId);
    await _storage.write(key: mlkStorageKey, value: base64Encode(mlkBytes));
  }

  Future<UnlockedKey?> loadKey() async {
    final keyId = await _storage.read(key: keyIdStorageKey);
    final mlk = await _storage.read(key: mlkStorageKey);
    if (keyId == null || mlk == null) return null;
    return UnlockedKey(libraryKeyId: keyId, mlk: SecretKey(base64Decode(mlk)));
  }

  Future<void> clearKey() async {
    await _storage.delete(key: keyIdStorageKey);
    await _storage.delete(key: mlkStorageKey);
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/services/security/`
Expected: PASS

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add security preferences and database security key store"
```

---

### Task 3: Keyslot sidecar, header probe, and DatabaseLockedException

**Files:**
- Create: `lib/core/services/security/database_security_sidecar.dart`
- Create: `lib/core/services/security/database_locked_exception.dart`
- Test: `test/core/services/security/database_security_sidecar_test.dart`

**Interfaces:**
- Consumes: `KeyslotFile` (`lib/core/services/sync/crypto/keyslots.dart`).
- Produces:
  - `DatabaseSecuritySidecar` (abstract final class): `static const String fileName = 'submersion.keys'`, `static String pathFor(String dbPath)`, `static Future<KeyslotFile?> read(String dbPath)`, `static Future<void> write(String dbPath, KeyslotFile file)`, `static Future<void> delete(String dbPath)`.
  - `bool isEncryptedDatabaseFile(String path)` (top-level, in the same sidecar file): true iff the file exists, is >= 16 bytes, and does NOT begin with the SQLite plaintext header. A missing or empty file returns false.
  - `class DatabaseLockedException implements Exception { final String dbPath; final bool wrongKey; }` — `wrongKey` false means "no key was available", true means "a key was tried and rejected".

- [ ] **Step 1: Write the failing tests**

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/security/database_security_sidecar.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('sidecar_test');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  test('pathFor puts submersion.keys next to the database file', () {
    expect(
      DatabaseSecuritySidecar.pathFor('/a/b/submersion.db'),
      '/a/b/submersion.keys',
    );
  });

  test('read returns null when no sidecar exists', () async {
    final dbPath = '${tmp.path}/submersion.db';
    expect(await DatabaseSecuritySidecar.read(dbPath), isNull);
  });

  test('write then read round-trips the keyslot file', () async {
    final dbPath = '${tmp.path}/submersion.db';
    const file = KeyslotFile(version: 1, libraryKeyId: 'kid-1', slots: []);
    await DatabaseSecuritySidecar.write(dbPath, file);
    final back = await DatabaseSecuritySidecar.read(dbPath);
    expect(back, isNotNull);
    expect(back!.libraryKeyId, 'kid-1');
    expect(back.version, 1);
  });

  test('delete removes the sidecar and is a no-op when absent', () async {
    final dbPath = '${tmp.path}/submersion.db';
    const file = KeyslotFile(version: 1, libraryKeyId: 'kid-1', slots: []);
    await DatabaseSecuritySidecar.write(dbPath, file);
    await DatabaseSecuritySidecar.delete(dbPath);
    expect(await DatabaseSecuritySidecar.read(dbPath), isNull);
    await DatabaseSecuritySidecar.delete(dbPath); // must not throw
  });

  group('isEncryptedDatabaseFile', () {
    test('false for missing file', () {
      expect(isEncryptedDatabaseFile('${tmp.path}/nope.db'), false);
    });

    test('false for a plaintext SQLite header', () {
      final f = File('${tmp.path}/plain.db');
      f.writeAsBytesSync([
        ...'SQLite format 3'.codeUnits,
        0,
        ...List.filled(100, 0),
      ]);
      expect(isEncryptedDatabaseFile(f.path), false);
    });

    test('true for random (encrypted-looking) bytes', () {
      final f = File('${tmp.path}/enc.db');
      f.writeAsBytesSync(
        Uint8List.fromList(List.generate(1024, (i) => (i * 37 + 11) % 256)),
      );
      expect(isEncryptedDatabaseFile(f.path), true);
    });

    test('false for a short/empty file', () {
      final f = File('${tmp.path}/tiny.db')..writeAsBytesSync([1, 2, 3]);
      expect(isEncryptedDatabaseFile(f.path), false);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/security/database_security_sidecar_test.dart`
Expected: FAIL — imports missing.

- [ ] **Step 3: Implement**

`lib/core/services/security/database_locked_exception.dart`:

```dart
/// The database file is encrypted and could not be opened: either no key was
/// available ([wrongKey] false — prompt for the password) or a key was tried
/// and rejected ([wrongKey] true — the password/cached key is wrong).
///
/// Startup routes this to the unlock screen; it must never surface as the
/// generic startup-error state.
class DatabaseLockedException implements Exception {
  final String dbPath;
  final bool wrongKey;

  const DatabaseLockedException(this.dbPath, {this.wrongKey = false});

  @override
  String toString() =>
      'DatabaseLockedException($dbPath, wrongKey: $wrongKey)';
}
```

`lib/core/services/security/database_security_sidecar.dart`:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/sync/crypto/keyslots.dart';

/// The 16-byte magic that begins every plaintext SQLite database.
const List<int> _sqliteHeader = [
  0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66, // 'SQLite f'
  0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00, // 'ormat 3\0'
];

/// True iff [path] exists and does NOT start with the plaintext SQLite
/// header — i.e. the file is (presumed) SQLCipher-encrypted. The file
/// header is the source of truth for encryption state; prefs flags are
/// cross-checked against it and the file wins.
bool isEncryptedDatabaseFile(String path) {
  final file = File(path);
  if (!file.existsSync()) return false;
  final raf = file.openSync();
  try {
    final header = raf.readSync(16);
    if (header.length < 16) return false;
    for (var i = 0; i < 16; i++) {
      if (header[i] != _sqliteHeader[i]) return true;
    }
    return false;
  } finally {
    raf.closeSync();
  }
}

/// The keyslot sidecar next to the database — the durable wrapped copy of
/// the Master Key (like a LUKS header). Readable before any DB open; it
/// travels with the database in set-aside, storage-move, and safety-copy
/// flows.
abstract final class DatabaseSecuritySidecar {
  static const String fileName = 'submersion.keys';

  static String pathFor(String dbPath) =>
      p.join(p.dirname(dbPath), fileName);

  static Future<KeyslotFile?> read(String dbPath) async {
    final file = File(pathFor(dbPath));
    if (!await file.exists()) return null;
    return KeyslotFile.fromJsonBytes(await file.readAsBytes());
  }

  static Future<void> write(String dbPath, KeyslotFile keyslots) async {
    await File(pathFor(dbPath)).writeAsBytes(keyslots.toJsonBytes());
  }

  static Future<void> delete(String dbPath) async {
    final file = File(pathFor(dbPath));
    if (await file.exists()) await file.delete();
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/security/database_security_sidecar_test.dart`
Expected: PASS

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add keyslot sidecar, encryption header probe, and DatabaseLockedException"
```

---

### Task 4: DatabaseSecurityService core (credential lifecycle)

**Files:**
- Modify: `lib/core/services/sync/crypto/keyslots.dart` (generalize HKDF helper)
- Create: `lib/core/services/security/database_security_service.dart`
- Test: `test/core/services/security/database_security_service_test.dart`
- Test: modify `test/core/services/sync/crypto/keyslots_test.dart` (or wherever `deriveDataKey` vectors live — find with `grep -rln "deriveDataKey" test/`)

**Interfaces:**
- Consumes: `Keyslots`, `KeyslotFile`, `RecoveryCode`, `DatabaseSecurityKeyStore`, `SecurityPreferences`, `DatabaseSecuritySidecar`, `WrongPassphraseException` (`lib/core/services/sync/crypto/sync_encryption_service.dart`).
- Produces (used by Tasks 7, 8, 10, 11, 12, 13, 14):
  - `Keyslots.deriveSubKey(SecretKey mlk, {required String info})` — generalization; `deriveDataKey(mlk)` becomes `deriveSubKey(mlk, info: 'sbe:v1:data')` and its output must be byte-identical to before (existing vectors prove it).
  - `DatabaseSecurityService.instance` singleton:
    - `Future<void> configure({required SharedPreferences prefs, DatabaseSecurityKeyStore? keyStore})` — idempotent, must be called before anything else (startup, background isolate, tests).
    - `bool get appLockEnabled`, `bool get encryptionEnabled` (prefs-backed)
    - `String? get databaseKeyHex` — non-null only after a successful unlock/cached-key load AND encryption enabled.
    - `bool get isUnlocked` — MLK is in memory.
    - `Future<bool> tryLoadCachedKey()` — keychain to memory; derives `databaseKeyHex` when encryption enabled; false if nothing cached.
    - `Future<bool> unlockWithSecret(String secret, {required String dbPath})` — sidecar unwrap (password or recovery code both work via `Keyslots.tryUnwrap`); on success caches to keychain and derives key hex; false on wrong secret.
    - `Future<String> enableSecurity({required String password, required String dbPath})` — mints MLK + sidecar (passphrase + recovery slots), caches key, flips `app_lock_enabled` true; returns the recovery code. Throws `StateError` if a sidecar already exists.
    - `Future<void> changePassword({required String currentSecret, required String newPassword, required String dbPath})` — rewraps passphrase slot only (mirror `BackupEncryptionService.changePassphrase`); throws `WrongPassphraseException` on bad current secret.
    - `Future<String> regenerateRecoveryCode({required String currentSecret, required String dbPath})`.
    - `Future<void> disableSecurity({required String dbPath})` — throws `StateError` if `encryptionEnabled` (decrypt first, Task 7); else deletes sidecar, clears keychain + both prefs flags + in-memory key.
    - `static Future<String> deriveDbKeyHex(SecretKey mlk)` — `Keyslots.deriveSubKey(mlk, info: 'sdb:v1:dbkey')`, lowercase hex of the 32 bytes.
    - `@visibleForTesting void resetForTesting()`.

- [ ] **Step 1: Generalize the HKDF helper (refactor with existing vectors as the lock)**

In `lib/core/services/sync/crypto/keyslots.dart`, replace `deriveDataKey` with:

```dart
  /// Derives a purpose-bound subkey from the master key. [info] namespaces
  /// the derivation ('sbe:v1:data' for backup/sync payloads, 'sdb:v1:dbkey'
  /// for the SQLCipher database key), so the master key itself never touches
  /// data directly and the derivations cannot collide.
  static Future<SecretKey> deriveSubKey(
    SecretKey mlk, {
    required String info,
  }) async {
    // Pinned to the pure-Dart HKDF: the salt is empty (RFC 5869 default),
    // HKDF keys its extract HMAC with the salt, and the cryptography_flutter
    // implementation that auto-registers as Cryptography.instance on Android
    // rejects empty HMAC keys (SecretKeySpec "Empty key", #737). Output is
    // byte-identical on every platform either way.
    const hkdf = DartHkdf(hmac: DartHmac(DartSha256()), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: mlk,
      nonce: const <int>[],
      info: utf8.encode(info),
    );
  }

  static Future<SecretKey> deriveDataKey(SecretKey mlk) =>
      deriveSubKey(mlk, info: 'sbe:v1:data');
```

Run the existing crypto tests (find them: `grep -rln "deriveDataKey\|Keyslots" test/ | head`) — they MUST pass unchanged; they are the proof the refactor did not alter sync/backup key derivation.

- [ ] **Step 2: Write the failing service tests**

`test/core/services/security/database_security_service_test.dart`. Use small-KDF params to keep Argon2id fast in tests — the service must accept an injectable `KdfParams` for that (see implementation). Independent test vector rule applies to `deriveDbKeyHex`: compute the expected HKDF output with a standalone Dart script (`dart run` a scratch file using the `cryptography` package directly with info `sdb:v1:dbkey` and a fixed 32-byte MLK of `0x01..0x20`), paste the hex literal into the test, and note the script in a comment.

```dart
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/security/database_security_service.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';

/// Cheap Argon2id for tests only (real default stays 64 MiB / t=3).
const testKdf = KdfParams(m: 64, t: 1, p: 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late String dbPath;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dbsec_test');
    dbPath = '${tmp.path}/submersion.db';
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({}); // adjust to the mocking
    // pattern used by the Task 2 key store tests if different.
    DatabaseSecurityService.instance.resetForTesting();
    await DatabaseSecurityService.instance.configure(
      prefs: await SharedPreferences.getInstance(),
    );
  });

  tearDown(() async => tmp.delete(recursive: true));

  test('deriveDbKeyHex matches independently computed vector', () async {
    final mlk = SecretKey(List<int>.generate(32, (i) => i + 1));
    final hex = await DatabaseSecurityService.deriveDbKeyHex(mlk);
    expect(hex, hasLength(64));
    // Vector computed with tool/compute_db_key_vector.dart (standalone
    // cryptography-package HKDF, info 'sdb:v1:dbkey', empty salt).
    expect(hex, '<PASTE-COMPUTED-HEX-HERE>'); // replace before committing
  });

  test('enableSecurity writes sidecar, caches key, flips app lock on',
      () async {
    final svc = DatabaseSecurityService.instance;
    final recovery = await svc.enableSecurity(
      password: 'hunter2', dbPath: dbPath, kdf: testKdf);
    expect(recovery.split('-'), hasLength(8));
    expect(svc.appLockEnabled, true);
    expect(svc.isUnlocked, true);
    expect(File('${tmp.path}/submersion.keys').existsSync(), true);
  });

  test('unlockWithSecret accepts password and recovery code, rejects junk',
      () async {
    final svc = DatabaseSecurityService.instance;
    final recovery = await svc.enableSecurity(
      password: 'hunter2', dbPath: dbPath, kdf: testKdf);
    svc.resetForTesting();
    await svc.configure(prefs: await SharedPreferences.getInstance());
    expect(await svc.unlockWithSecret('wrong', dbPath: dbPath), false);
    expect(await svc.unlockWithSecret('hunter2', dbPath: dbPath), true);
    svc.resetForTesting();
    await svc.configure(prefs: await SharedPreferences.getInstance());
    expect(await svc.unlockWithSecret(recovery, dbPath: dbPath), true);
  });

  test('tryLoadCachedKey restores unlock across service resets', () async {
    final svc = DatabaseSecurityService.instance;
    await svc.enableSecurity(password: 'pw', dbPath: dbPath, kdf: testKdf);
    svc.resetForTesting();
    await svc.configure(prefs: await SharedPreferences.getInstance());
    expect(await svc.tryLoadCachedKey(), true);
    expect(svc.isUnlocked, true);
  });

  test('databaseKeyHex is null until encryption is enabled', () async {
    final svc = DatabaseSecurityService.instance;
    await svc.enableSecurity(password: 'pw', dbPath: dbPath, kdf: testKdf);
    expect(svc.databaseKeyHex, isNull); // app lock only — no DB key exposed
  });

  test('changePassword rewraps; old password stops working', () async {
    final svc = DatabaseSecurityService.instance;
    await svc.enableSecurity(password: 'old', dbPath: dbPath, kdf: testKdf);
    await svc.changePassword(
      currentSecret: 'old', newPassword: 'new',
      dbPath: dbPath, kdf: testKdf);
    svc.resetForTesting();
    await svc.configure(prefs: await SharedPreferences.getInstance());
    expect(await svc.unlockWithSecret('old', dbPath: dbPath), false);
    expect(await svc.unlockWithSecret('new', dbPath: dbPath), true);
  });

  test('disableSecurity clears everything when encryption is off', () async {
    final svc = DatabaseSecurityService.instance;
    await svc.enableSecurity(password: 'pw', dbPath: dbPath, kdf: testKdf);
    await svc.disableSecurity(dbPath: dbPath);
    expect(svc.appLockEnabled, false);
    expect(svc.isUnlocked, false);
    expect(File('${tmp.path}/submersion.keys').existsSync(), false);
  });
}
```

(Adjust the secure-storage mocking line to whatever pattern Task 2 landed on; the tests share it.)

- [ ] **Step 3: Compute the HKDF test vector**

Write `tool/compute_db_key_vector.dart` (a standalone script mirroring `Keyslots.deriveSubKey` with the `cryptography` package directly), run `dart run tool/compute_db_key_vector.dart`, paste the resulting hex into the test, and keep the script committed (project precedent: independently computed test vectors).

- [ ] **Step 4: Run tests to verify they fail**

Run: `flutter test test/core/services/security/database_security_service_test.dart`
Expected: FAIL — service does not exist.

- [ ] **Step 5: Implement `database_security_service.dart`**

```dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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
  String? get databaseKeyHex => _databaseKeyHex;
  SecurityPreferences get preferences => _p;

  static Future<String> deriveDbKeyHex(SecretKey mlk) async {
    final key = await Keyslots.deriveSubKey(mlk, info: 'sdb:v1:dbkey');
    final bytes = await key.extractBytes();
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<bool> tryLoadCachedKey() async {
    final cached = await _keyStore.loadKey();
    if (cached == null) return false;
    await _adoptMlk(cached.mlk, cached.libraryKeyId, persist: false);
    return true;
  }

  Future<bool> unlockWithSecret(
    String secret, {
    required String dbPath,
  }) async {
    final file = await DatabaseSecuritySidecar.read(dbPath);
    if (file == null) return false;
    final mlk = await Keyslots.tryUnwrap(file: file, secret: secret);
    if (mlk == null) return false;
    await _adoptMlk(mlk, file.libraryKeyId, persist: true);
    return true;
  }

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
          type: 'passphrase', secret: password, mlk: mlk, kdf: kdf),
        await Keyslots.createSlot(
          type: 'recovery', secret: recoveryCode, mlk: mlk, kdf: kdf),
      ],
    );
    await DatabaseSecuritySidecar.write(dbPath, file);
    await _adoptMlk(mlk, libraryKeyId, persist: true);
    await _p.setAppLockEnabled(true);
    return recoveryCode;
  }

  Future<void> changePassword({
    required String currentSecret,
    required String newPassword,
    required String dbPath,
    KdfParams kdf = const KdfParams(),
  }) async {
    final (file, mlk) = await _unlockedSidecar(currentSecret, dbPath);
    final updated = file.withReplacedSlot(
      await Keyslots.createSlot(
        type: 'passphrase', secret: newPassword, mlk: mlk, kdf: kdf),
    );
    await DatabaseSecuritySidecar.write(dbPath, updated);
  }

  Future<String> regenerateRecoveryCode({
    required String currentSecret,
    required String dbPath,
    KdfParams kdf = const KdfParams(),
  }) async {
    final (file, mlk) = await _unlockedSidecar(currentSecret, dbPath);
    final code = RecoveryCode.generate();
    final updated = file.withReplacedSlot(
      await Keyslots.createSlot(
        type: 'recovery', secret: code, mlk: mlk, kdf: kdf),
    );
    await DatabaseSecuritySidecar.write(dbPath, updated);
    return code;
  }

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
    _databaseKeyHex =
        encryptionEnabled ? await deriveDbKeyHex(mlk) : null;
    if (persist) {
      await _keyStore.saveKey(
        libraryKeyId: libraryKeyId,
        mlkBytes: await mlk.extractBytes(),
      );
    }
  }

  /// Re-derives [databaseKeyHex] after the encryption flag changes
  /// (enable/disable encryption flows flip the flag while unlocked).
  Future<void> refreshDerivedKey() async {
    final mlk = _mlk;
    _databaseKeyHex =
        (mlk != null && encryptionEnabled) ? await deriveDbKeyHex(mlk) : null;
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
```

Note: `enableSecurity`/`changePassword`/`regenerateRecoveryCode` take an optional `kdf` parameter (tests pass the cheap one). `databaseKeyHex` stays null in app-lock-only mode by design.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/core/services/security/`
Expected: PASS (Argon2id with test params keeps this fast).

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add DatabaseSecurityService credential lifecycle"
```

---

### Task 5: Thread the key through every database open

**Files:**
- Modify: `lib/core/database/sqlcipher_setup.dart` (add top-level `cipherKeyPragma`)
- Modify: `lib/core/services/database_service.dart` (import it `as sqlcipher_setup`)
- Modify: `lib/core/database/background_database_connection.dart`
- Modify: `lib/core/services/database_migration_service.dart:550,693` (raw opens)
- Modify: `lib/features/backup/data/services/backup_service.dart:586` (validation open — stays keyless, switch to helper)
- Modify: `lib/core/presentation/pages/startup_page.dart:189` (probe passes key)
- Test: `test/core/services/database_service_key_test.dart`

**Interfaces:**
- Consumes: `DatabaseLockedException`, `isEncryptedDatabaseFile` (Task 3).
- Produces:
  - `DatabaseService.databaseKeyHex` — settable `String?` field; when non-null every open of the main DB applies `PRAGMA key`.
  - `static sqlite3.Database openRaw(String path, {sqlite3.OpenMode mode = sqlite3.OpenMode.readWrite, String? keyHex})` — THE single raw-open helper; all raw `sqlite3.open` call sites for the main DB go through it.
  - `static int? getStoredSchemaVersion(String dbPath, {String? keyHex})` — now key-aware; throws `DatabaseLockedException` when the file is encrypted and the key is missing/wrong.
  - `String cipherKeyPragma(String keyHex)` — top-level in `sqlcipher_setup.dart` (returns `PRAGMA key = "x'<hex>'"`); `DatabaseService.cipherKeyPragma` is a static delegate to it. ONE definition — the worker isolate (this task) and the migrator (Task 6) import it from `sqlcipher_setup.dart`, never from `DatabaseService`, so no import cycles exist.
  - `BackgroundDatabaseConnection.open(File file, {String? keyHex, debugOpener})` — key rides to the worker isolate.

- [ ] **Step 1: Write the failing tests**

`test/core/services/database_service_key_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/security/database_locked_exception.dart';

void main() {
  test('cipherKeyPragma formats a raw-key pragma', () {
    expect(
      DatabaseService.cipherKeyPragma('ab01'),
      'PRAGMA key = "x\'ab01\'"',
    );
  });

  test('getStoredSchemaVersion still works keyless on a plaintext db',
      () async {
    final tmp = await Directory.systemTemp.createTemp('dbsvc_key');
    addTearDown(() => tmp.delete(recursive: true));
    final path = '${tmp.path}/plain.db';
    final db = DatabaseService.openRaw(path, mode: OpenMode.readWriteCreate);
    db.execute('PRAGMA user_version = 42');
    db.dispose();
    expect(DatabaseService.getStoredSchemaVersion(path), 42);
  });

  test('encrypted-looking file without a key throws DatabaseLockedException',
      () async {
    final tmp = await Directory.systemTemp.createTemp('dbsvc_key');
    addTearDown(() => tmp.delete(recursive: true));
    final path = '${tmp.path}/enc.db';
    File(path).writeAsBytesSync(
      List<int>.generate(4096, (i) => (i * 37 + 11) % 256),
    );
    expect(
      () => DatabaseService.getStoredSchemaVersion(path),
      throwsA(isA<DatabaseLockedException>()
          .having((e) => e.wrongKey, 'wrongKey', false)),
    );
  });
}
```

(Import `OpenMode` from `package:sqlite3/sqlite3.dart` — match however the test file resolves it; `openRaw`'s signature below re-exports nothing, so import sqlite3 directly in the test.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/database_service_key_test.dart`
Expected: FAIL — `cipherKeyPragma` / `openRaw` undefined.

- [ ] **Step 3: Implement in `database_service.dart`**

Add imports for `DatabaseLockedException` and `isEncryptedDatabaseFile`. Add to `DatabaseService`:

```dart
  /// SQLCipher raw key (64 lowercase hex chars) for the main database, set by
  /// DatabaseSecurityService BEFORE initialize()/reinitializeAtPath() when
  /// encryption is enabled. Null = open without a key (plaintext database).
  String? databaseKeyHex;

  /// The PRAGMA that keys a SQLCipher connection with a raw (already
  /// KDF-stretched) key. Must be the first statement on the connection.
  /// Single definition lives in sqlcipher_setup.dart (top-level, so the
  /// worker isolate and the migrator can use it without importing this
  /// service and creating an import cycle); this is a convenience delegate.
  static String cipherKeyPragma(String keyHex) =>
      sqlcipher_setup.cipherKeyPragma(keyHex);

  /// Single choke point for raw (non-drift) opens of the main database.
  /// Applies the cipher key when given, and disposes the handle on failure.
  static sqlite3.Database openRaw(
    String path, {
    sqlite3.OpenMode mode = sqlite3.OpenMode.readWrite,
    String? keyHex,
  }) {
    final db = sqlite3.sqlite3.open(path, mode: mode);
    if (keyHex != null) {
      try {
        db.execute(cipherKeyPragma(keyHex));
      } catch (_) {
        db.dispose();
        rethrow;
      }
    }
    return db;
  }

  /// True when [error] is SQLite's NOTADB ("file is not a database", primary
  /// result code 26) — what SQLCipher raises when reading an encrypted file
  /// with a missing or wrong key.
  static bool _isNotADatabaseError(Object error) =>
      error is sqlite3.SqliteException && error.resultCode == 26;
```

Rework `getStoredSchemaVersion`:

```dart
  static int? getStoredSchemaVersion(String dbPath, {String? keyHex}) {
    final file = File(dbPath);
    if (!file.existsSync()) return null;

    final db = openRaw(dbPath, keyHex: keyHex);
    try {
      final result = db.select('PRAGMA user_version');
      if (result.isEmpty) return null;
      return result.first.values.first as int;
    } on sqlite3.SqliteException catch (e) {
      // An encrypted file read without (or with the wrong) key surfaces as
      // NOTADB on the first real page read. Route it to the unlock flow
      // instead of the generic startup error. The header probe distinguishes
      // "no key supplied" from "key supplied but rejected".
      if (_isNotADatabaseError(e) && isEncryptedDatabaseFile(dbPath)) {
        throw DatabaseLockedException(dbPath, wrongKey: keyHex != null);
      }
      rethrow;
    } finally {
      db.dispose();
    }
  }
```

Update `recoverHotJournal` to use `openRaw(dbPath, keyHex: DatabaseService.instance.databaseKeyHex)` — it is an instance-independent static today; change its signature to `static bool recoverHotJournal(String dbPath, {String? keyHex})` and pass the key at the call site in `startup_page.dart` (`_runRecovery`).

In `_openDatabase`, thread the key:

```dart
    final keyHex = databaseKeyHex;
    final stored = getStoredSchemaVersion(dbPath, keyHex: keyHex);
```

and give both executors the key. The migration-phase open becomes:

```dart
      final migrator = AppDatabase(
        NativeDatabase(file, setup: _cipherSetup(keyHex)),
        onMigrationProgress: onMigrationProgress,
      );
```

with the helper (top-level or static in `database_service.dart`):

```dart
/// drift setup callback that keys a SQLCipher connection before any other
/// statement. Null when no key — plaintext open, zero overhead.
void Function(sqlite3.Database)? _cipherSetup(String? keyHex) {
  if (keyHex == null) return null;
  return (db) => db.execute(DatabaseService.cipherKeyPragma(keyHex));
}
```

and the background open becomes:

```dart
    final background = await BackgroundDatabaseConnection.open(
      file,
      keyHex: keyHex,
    );
```

- [ ] **Step 4: Thread the key through the worker isolate**

In `lib/core/database/background_database_connection.dart`:

```dart
DatabaseConnection Function() _openerFor(String path, String? keyHex) {
  return () {
    // Fresh isolate: the sqlite3 loader override is per-isolate state and
    // must be re-applied here or Android loads the non-cipher system lib.
    setupSqlcipher();
    return DatabaseConnection(
      NativeDatabase(
        File(path),
        setup: keyHex == null
            ? null
            : (db) => db.execute(cipherKeyPragma(keyHex)),
      ),
    );
  };
}
```

Add `String? keyHex` parameter to `BackgroundDatabaseConnection.open(...)` and pass it: `debugOpener ?? _openerFor(file.absolute.path, keyHex)`. Import only `sqlcipher_setup.dart` here — both `setupSqlcipher` and the top-level `cipherKeyPragma` live there, and `database_service.dart` already imports this file, so importing it back would create a cycle.

First add the single pragma-builder definition to `sqlcipher_setup.dart`:

```dart
/// The PRAGMA that keys a SQLCipher connection with a raw (already
/// KDF-stretched) 32-byte key, given as 64 hex chars. Must be the first
/// statement executed on the connection.
String cipherKeyPragma(String keyHex) => 'PRAGMA key = "x\'$keyHex\'"';
```

- [ ] **Step 5: Consolidate the remaining raw opens**

- `lib/core/services/database_migration_service.dart:550` (`PRAGMA quick_check`) and `:693` (`_fetchDatabaseCounts`): replace `sqlite3.sqlite3.open(...)` with `DatabaseService.openRaw(path, keyHex: DatabaseService.instance.databaseKeyHex)`. These always target the live main DB.
- `lib/features/backup/data/services/backup_service.dart:586` (backup validation): replace with `DatabaseService.openRaw(backupPath)` — NO key: backup artifacts are portable plaintext by design, and an encrypted-looking backup file should fail validation loudly.
- `lib/core/presentation/pages/startup_page.dart:189`: `DatabaseService.getStoredSchemaVersion(dbPath, keyHex: DatabaseService.instance.databaseKeyHex)` (the gate in Task 10 sets the field before this line runs).

Verify no raw opens remain unconverted: `grep -rn "sqlite3.open\|sqlite3\.sqlite3\.open" lib/ --include=*.dart` — every hit for the MAIN database must go through `openRaw` (the local-cache DB service keeps its own plain open).

- [ ] **Step 6: Run tests + full analyze**

Run: `flutter test test/core/services/database_service_key_test.dart && flutter test test/core/ && flutter analyze`
Expected: PASS; no analyzer issues.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "Thread SQLCipher key through all main-database open paths"
```

---

### Task 6: DatabaseEncryptionMigrator (encrypt/decrypt in place)

**Files:**
- Create: `lib/core/services/security/database_encryption_migrator.dart`
- Test: `test/core/services/security/database_encryption_migrator_test.dart`

**Interfaces:**
- Consumes: `cipherKeyPragma` (top-level, `sqlcipher_setup.dart` — Task 5), `sqlite3` package directly. Deliberately does NOT import `database_service.dart` (Task 8 imports this file from there).
- Produces:
  - `typedef SqlcipherExporter = Future<void> Function({required String sourcePath, required String targetPath, String? sourceKeyHex, String? targetKeyHex})`
  - `Future<void> sqlcipherExport({...})` — the real exporter (ATTACH + `sqlcipher_export`), used in production; only testable under integration tests (host SQLite lacks the function).
  - `class DatabaseEncryptionMigrator { DatabaseEncryptionMigrator({SqlcipherExporter exporter = sqlcipherExport}); Future<void> encryptInPlace({required String dbPath, required String keyHex}); Future<void> decryptInPlace({required String dbPath, required String keyHex}); }`
  - File choreography (used by tests and by recovery reasoning): staging at `<db>.reencrypt-staging`, aside at `<db>.pre-reencrypt`, WAL/SHM (`<db>-wal`, `<db>-shm`) deleted after the aside rename, staging renamed in, aside best-effort deleted on success; on failure the aside is rolled back and staging deleted.

- [ ] **Step 1: Write the failing tests (fake exporter — choreography only)**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/security/database_encryption_migrator.dart';

void main() {
  late Directory tmp;
  late String dbPath;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('migrator_test');
    dbPath = '${tmp.path}/submersion.db';
    File(dbPath).writeAsStringSync('ORIGINAL');
    File('$dbPath-wal').writeAsStringSync('WAL');
    File('$dbPath-shm').writeAsStringSync('SHM');
  });

  tearDown(() => tmp.delete(recursive: true));

  Future<void> fakeExporter({
    required String sourcePath,
    required String targetPath,
    String? sourceKeyHex,
    String? targetKeyHex,
  }) async {
    File(targetPath).writeAsStringSync('EXPORTED:${targetKeyHex ?? "plain"}');
  }

  test('encryptInPlace swaps the exported file in and cleans sidecars',
      () async {
    final migrator = DatabaseEncryptionMigrator(exporter: fakeExporter);
    await migrator.encryptInPlace(dbPath: dbPath, keyHex: 'aa');
    expect(File(dbPath).readAsStringSync(), 'EXPORTED:aa');
    expect(File('$dbPath-wal').existsSync(), false);
    expect(File('$dbPath-shm').existsSync(), false);
    expect(File('$dbPath.reencrypt-staging').existsSync(), false);
    expect(File('$dbPath.pre-reencrypt').existsSync(), false);
  });

  test('failure during export leaves the original untouched', () async {
    Future<void> failingExporter({
      required String sourcePath,
      required String targetPath,
      String? sourceKeyHex,
      String? targetKeyHex,
    }) async {
      throw StateError('boom');
    }

    final migrator = DatabaseEncryptionMigrator(exporter: failingExporter);
    await expectLater(
      migrator.encryptInPlace(dbPath: dbPath, keyHex: 'aa'),
      throwsStateError,
    );
    expect(File(dbPath).readAsStringSync(), 'ORIGINAL');
    expect(File('$dbPath-wal').existsSync(), true);
    expect(File('$dbPath.reencrypt-staging').existsSync(), false);
  });

  test('decryptInPlace produces a plaintext-target export', () async {
    final migrator = DatabaseEncryptionMigrator(exporter: fakeExporter);
    await migrator.decryptInPlace(dbPath: dbPath, keyHex: 'aa');
    expect(File(dbPath).readAsStringSync(), 'EXPORTED:plain');
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/security/database_encryption_migrator_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/sqlcipher_setup.dart';

typedef SqlcipherExporter = Future<void> Function({
  required String sourcePath,
  required String targetPath,
  String? sourceKeyHex,
  String? targetKeyHex,
});

/// Real exporter: SQLCipher's canonical re-key path. Opens the source raw,
/// ATTACHes the target with the new key ('' = plaintext), copies everything
/// with sqlcipher_export, and carries user_version over explicitly —
/// sqlcipher_export does NOT copy it.
///
/// Opens sqlite3 directly (not via DatabaseService.openRaw) so this file has
/// no import of database_service.dart — DatabaseService imports THIS file in
/// Task 8, and Dart import cycles are avoided by keeping this one-way.
Future<void> sqlcipherExport({
  required String sourcePath,
  required String targetPath,
  String? sourceKeyHex,
  String? targetKeyHex,
}) async {
  final db = sqlite3.sqlite3.open(sourcePath);
  if (sourceKeyHex != null) {
    try {
      db.execute(cipherKeyPragma(sourceKeyHex));
    } catch (_) {
      db.dispose();
      rethrow;
    }
  }
  try {
    // Path is single-quote escaped; the key is an inline literal because a
    // bound parameter would be treated as a text passphrase, not a raw key.
    final escapedPath = targetPath.replaceAll("'", "''");
    final keyLiteral =
        targetKeyHex == null ? "''" : '"x\'$targetKeyHex\'"';
    db.execute(
      "ATTACH DATABASE '$escapedPath' AS target KEY $keyLiteral",
    );
    db.execute("SELECT sqlcipher_export('target')");
    final v = db.select('PRAGMA user_version').first.values.first as int;
    db.execute('PRAGMA target.user_version = $v');
    db.execute('DETACH DATABASE target');
  } finally {
    db.dispose();
  }
}

/// Re-encrypts the database file in place via export-to-staging plus an
/// atomic-rename swap (same choreography as DatabaseService.restore). The
/// database must be CLOSED (strict) before calling either method.
class DatabaseEncryptionMigrator {
  final SqlcipherExporter exporter;

  DatabaseEncryptionMigrator({this.exporter = sqlcipherExport});

  Future<void> encryptInPlace({
    required String dbPath,
    required String keyHex,
  }) =>
      _reencrypt(dbPath: dbPath, sourceKeyHex: null, targetKeyHex: keyHex);

  Future<void> decryptInPlace({
    required String dbPath,
    required String keyHex,
  }) =>
      _reencrypt(dbPath: dbPath, sourceKeyHex: keyHex, targetKeyHex: null);

  Future<void> _reencrypt({
    required String dbPath,
    required String? sourceKeyHex,
    required String? targetKeyHex,
  }) async {
    final stagingPath = '$dbPath.reencrypt-staging';
    final asidePath = '$dbPath.pre-reencrypt';
    await _deleteIfExists(stagingPath);

    try {
      await exporter(
        sourcePath: dbPath,
        targetPath: stagingPath,
        sourceKeyHex: sourceKeyHex,
        targetKeyHex: targetKeyHex,
      );
    } catch (_) {
      await _deleteIfExists(stagingPath);
      rethrow;
    }

    // Swap: original aside (never deleted first), WAL/SHM dropped (they
    // belong to the pre-swap file and would corrupt the new one), staging in.
    await _deleteIfExists(asidePath);
    final dbFile = File(dbPath);
    try {
      await dbFile.rename(asidePath);
      await _deleteIfExists('$dbPath-wal');
      await _deleteIfExists('$dbPath-shm');
      await File(stagingPath).rename(dbPath);
    } catch (_) {
      if (!await dbFile.exists() && await File(asidePath).exists()) {
        await File(asidePath).rename(dbPath);
      }
      await _deleteIfExists(stagingPath);
      rethrow;
    }

    // Success: drop the aside best-effort (a stranded copy is harmless).
    try {
      await _deleteIfExists(asidePath);
    } catch (_) {}
  }

  Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
```

Note: the failure-path test asserts the WAL survives a failed export — the WAL deletion happens only after the export succeeded and the original is aside, so the not-yet-swapped database remains fully consistent.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/security/database_encryption_migrator_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add in-place database encryption migrator"
```

---

### Task 7: Enable/disable encryption orchestration

**Files:**
- Modify: `lib/core/services/security/database_security_service.dart`
- Test: extend `test/core/services/security/database_security_service_test.dart`

**Interfaces:**
- Consumes: `DatabaseEncryptionMigrator`, `DatabaseService` (`close(strict:)`, `reinitializeAtPath`, `backup`, `databasePath`, `databaseKeyHex`), `isEncryptedDatabaseFile`.
- Produces (used by settings UI Task 13 and restore Task 8):
  - `Future<void> enableEncryption({DatabaseEncryptionMigrator? migrator, void Function(String phase)? onPhase})` — requires `isUnlocked`; phases reported: `'backup'`, `'encrypt'`, `'reopen'`.
  - `Future<void> disableEncryption({DatabaseEncryptionMigrator? migrator, void Function(String phase)? onPhase})` — phases: `'decrypt'`, `'reopen'`.
  - Both operate on `DatabaseService.instance` and its current path; both are safe to retry after a crash (header probe self-heal in Task 10 reconciles flag vs file).

- [ ] **Step 1: Write the failing tests**

Add to the service test file. Use a fake migrator (records calls, rewrites the file marker) and a test seam for the DatabaseService interactions: the service methods must accept an injectable `migrator`, and for unit tests we drive them against a real `DatabaseService` pointed at a temp plaintext SQLite file created with `openRaw(..., OpenMode.readWriteCreate)` — `initialize()` is NOT called; instead the test presets `DatabaseService.instance.resetForTesting()` and stubs by calling `enableEncryption(dbPathOverride: ...)`. To keep this tractable, add an `@visibleForTesting String? dbPathOverride` parameter to both methods that bypasses `DatabaseService.instance.databasePath` AND skips the close/reopen steps when `skipReopenForTesting: true` is passed:

```dart
  test('enableEncryption: backs up, migrates, flips flag, derives key',
      () async {
    final svc = DatabaseSecurityService.instance;
    await svc.enableSecurity(password: 'pw', dbPath: dbPath, kdf: testKdf);
    final calls = <String>[];
    final fake = DatabaseEncryptionMigrator(
      exporter: ({
        required String sourcePath,
        required String targetPath,
        String? sourceKeyHex,
        String? targetKeyHex,
      }) async {
        calls.add('export:${targetKeyHex != null}');
        File(targetPath).writeAsStringSync('ENC');
      },
    );
    File(dbPath).writeAsStringSync('PLAIN');
    final phases = <String>[];
    await svc.enableEncryption(
      migrator: fake,
      onPhase: phases.add,
      dbPathOverride: dbPath,
      skipReopenForTesting: true,
    );
    expect(calls, ['export:true']);
    expect(svc.encryptionEnabled, true);
    expect(svc.databaseKeyHex, isNotNull);
    expect(phases, containsAllInOrder(['backup', 'encrypt']));
  });

  test('disableEncryption reverses and clears the derived key', () async {
    final svc = DatabaseSecurityService.instance;
    await svc.enableSecurity(password: 'pw', dbPath: dbPath, kdf: testKdf);
    // ... enable with fake as above ...
    await svc.disableEncryption(
      migrator: fake,
      dbPathOverride: dbPath,
      skipReopenForTesting: true,
    );
    expect(svc.encryptionEnabled, false);
    expect(svc.databaseKeyHex, isNull);
  });

  test('enableEncryption throws when locked', () async {
    final svc = DatabaseSecurityService.instance;
    expect(
      () => svc.enableEncryption(
        dbPathOverride: dbPath, skipReopenForTesting: true),
      throwsStateError,
    );
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/security/database_security_service_test.dart`
Expected: FAIL — methods missing.

- [ ] **Step 3: Implement in DatabaseSecurityService**

```dart
  /// Encrypts the live database in place. Sequence:
  /// 1. safety backup (pre_encrypt_<ts>.db, plaintext — DB is still plain)
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
    final ts = DateTime.now();
    final stamp =
        '${ts.year.toString().padLeft(4, '0')}-'
        '${ts.month.toString().padLeft(2, '0')}-'
        '${ts.day.toString().padLeft(2, '0')}_'
        '${ts.hour.toString().padLeft(2, '0')}'
        '${ts.minute.toString().padLeft(2, '0')}'
        '${ts.second.toString().padLeft(2, '0')}';
    final backupPath = p.join(
      p.dirname(dbPath), 'Backups', 'pre_encrypt_$stamp.db');
    if (!skipReopenForTesting) {
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

  /// Decrypts in place; mirror image of [enableEncryption]. App Lock stays
  /// on — only the at-rest tier is removed.
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

    if (!skipReopenForTesting) {
      onPhase?.call('reopen');
      DatabaseService.instance.databaseKeyHex = null;
      await DatabaseService.instance.reinitializeAtPath(dbPath);
    }
  }
```

Add imports (`path` as `p`, `DatabaseService`, migrator, `visibleForTesting`). Note the ordering justification lives in the doc comment — flag flips between swap and reopen.

- [ ] **Step 4: Run tests, analyze**

Run: `flutter test test/core/services/security/ && flutter analyze`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add enable/disable encryption orchestration"
```

---

### Task 8: Portable backups and restore re-encryption

**Files:**
- Modify: `lib/core/services/database_service.dart` (`backup()`, `restore()`)
- Test: `test/core/services/database_service_portable_backup_test.dart`

**Interfaces:**
- Consumes: `DatabaseEncryptionMigrator`/`SqlcipherExporter`, `isEncryptedDatabaseFile`, `databaseKeyHex`.
- Produces:
  - `DatabaseService.backup(destinationPath)` — HARD RULE: destination is ALWAYS plaintext SQLite. When `databaseKeyHex != null` and the live file is encrypted, exports (decrypt) instead of copying. Everything downstream (SBE1 backup encryption, pre-migration backups, validation) is unchanged.
  - `DatabaseService.restore(backupPath)` — after the swap, when `databaseKeyHex != null` and the swapped-in file is plaintext, encrypts in place before reopen.
  - `@visibleForTesting SqlcipherExporter? debugExporterOverride` on `DatabaseService` — lets host tests fake the export in both paths.

- [ ] **Step 1: Write the failing tests**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/database_service.dart';

void main() {
  // These tests drive backup() against a service with databaseKeyHex set and
  // a fake exporter; no real cipher needed on the host.
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('portable_backup');
    DatabaseService.instance.resetForTesting();
  });

  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    await tmp.delete(recursive: true);
  });

  test('backup of an encrypted db exports plaintext via the exporter',
      () async {
    // Arrange: "encrypted" live file + key set + fake exporter.
    final src = '${tmp.path}/submersion.db';
    File(src).writeAsBytesSync(
      List<int>.generate(4096, (i) => (i * 37 + 11) % 256));
    final calls = <String?>[];
    DatabaseService.instance
      ..databaseKeyHex = 'aa'
      ..debugExporterOverride = ({
        required String sourcePath,
        required String targetPath,
        String? sourceKeyHex,
        String? targetKeyHex,
      }) async {
        calls.add(targetKeyHex);
        File(targetPath).writeAsStringSync('PLAINTEXT-EXPORT');
      };
    // Point the service at the temp path via the test-database seam:
    // backup() resolves databasePath, so use setCurrentPathForTesting (add
    // as @visibleForTesting setter alongside resetForTesting).
    DatabaseService.instance.setCurrentPathForTesting(src);

    final dest = '${tmp.path}/out/backup.db';
    await DatabaseService.instance.backup(dest);
    expect(calls, [null]); // targetKeyHex null = plaintext export
    expect(File(dest).readAsStringSync(), 'PLAINTEXT-EXPORT');
  });

  test('backup of a plaintext db still file-copies (no exporter call)',
      () async {
    final src = '${tmp.path}/submersion.db';
    File(src).writeAsBytesSync([
      ...'SQLite format 3'.codeUnits, 0, ...List.filled(100, 7),
    ]);
    var exporterCalled = false;
    DatabaseService.instance
      ..databaseKeyHex = null
      ..debugExporterOverride = ({
        required String sourcePath,
        required String targetPath,
        String? sourceKeyHex,
        String? targetKeyHex,
      }) async {
        exporterCalled = true;
      };
    DatabaseService.instance.setCurrentPathForTesting(src);
    final dest = '${tmp.path}/out/backup.db';
    await DatabaseService.instance.backup(dest);
    expect(exporterCalled, false);
    expect(File(dest).existsSync(), true);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/database_service_portable_backup_test.dart`
Expected: FAIL — `debugExporterOverride` / `setCurrentPathForTesting` missing.

- [ ] **Step 3: Implement**

In `DatabaseService`, add the seams:

```dart
  /// Test seam for the sqlcipher export used by portable backup/restore.
  @visibleForTesting
  SqlcipherExporter? debugExporterOverride;

  @visibleForTesting
  void setCurrentPathForTesting(String path) {
    _currentDatabasePath = path;
  }
```

(and clear both in `resetForTesting()`).

Rework `backup()`:

```dart
  /// Copies the live database to [destinationPath] as a PLAINTEXT SQLite
  /// file — always. Backups are portable by design: they must restore on a
  /// device where the DB password is unknown, and the existing SBE1 backup
  /// encryption remains the (orthogonal) way to protect backup artifacts.
  ///
  /// Plaintext live DB: plain file copy, as before. Encrypted live DB:
  /// decrypt-export through a staging file, then rename into place.
  Future<void> backup(String destinationPath) async {
    final sourcePath = await databasePath;
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return;

    final destDir = Directory(p.dirname(destinationPath));
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    final keyHex = databaseKeyHex;
    if (keyHex != null && isEncryptedDatabaseFile(sourcePath)) {
      final exporter = debugExporterOverride ?? sqlcipherExport;
      final staging = '$destinationPath.export-staging';
      await _deleteIfExists(staging);
      try {
        await exporter(
          sourcePath: sourcePath,
          targetPath: staging,
          sourceKeyHex: keyHex,
          targetKeyHex: null,
        );
        await _deleteIfExists(destinationPath);
        await File(staging).rename(destinationPath);
      } catch (_) {
        await _bestEffortDelete(staging);
        rethrow;
      }
      return;
    }

    await sourceFile.copy(destinationPath);
  }
```

In `restore()`, right BEFORE the `await initialize(onMigrationProgress: ...)` reopen line, add:

```dart
    // A restored backup is plaintext (portable-backup hard rule). When the
    // live database is protected, re-encrypt the swapped-in file before the
    // reopen so protection survives a restore without user action.
    final keyHex = databaseKeyHex;
    if (keyHex != null && !isEncryptedDatabaseFile(destinationPath)) {
      await DatabaseEncryptionMigrator(
        exporter: debugExporterOverride ?? sqlcipherExport,
      ).encryptInPlace(dbPath: destinationPath, keyHex: keyHex);
    }
```

Imports: `database_encryption_migrator.dart`, `database_security_sidecar.dart` (probe). No import cycle: Task 6 built the migrator without any `database_service.dart` import (it opens sqlite3 directly), so this one-way import is clean.

- [ ] **Step 4: Carry the sidecar through storage-relocation moves**

Spec requirement: "the sidecar moves with the DB" when the user relocates storage. Find every place the migration service moves/copies the main DB file: `grep -n "submersion.db\|\.copy(\|\.rename(" lib/core/services/database_migration_service.dart`. For each move/copy of the `.db` file between directories, mirror the same operation for the sidecar when it exists:

```dart
    final sidecarSource = File(DatabaseSecuritySidecar.pathFor(sourcePath));
    if (await sidecarSource.exists()) {
      await sidecarSource.copy(DatabaseSecuritySidecar.pathFor(targetPath));
    }
```

(copy-then-delete flows delete the source sidecar in the same phase that deletes the source DB; rollback paths restore it the same way the DB is restored). Add a unit test alongside the existing migration-service tests (`ls test/core/services/ | grep migration`) asserting a sidecar file present next to the source DB arrives next to the destination DB in a successful move.

- [ ] **Step 5: Run tests + the existing restore tests**

Run: `flutter test test/core/services/ && flutter analyze`
Expected: PASS — restore behavior for unprotected users unchanged (keyHex null short-circuits everything).

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "Keep backups plaintext-portable and re-encrypt on restore"
```

---

### Task 9: Biometrics (local_auth) and platform config

**Files:**
- Modify: `pubspec.yaml` (add local_auth)
- Create: `lib/core/services/security/biometric_service.dart`
- Modify: `android/app/src/main/kotlin/app/submersion/MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`
- Test: `test/core/services/security/biometric_service_test.dart`

**Interfaces:**
- Produces: `BiometricService` with injectable `LocalAuthentication`:
  - `BiometricService({LocalAuthentication? auth})`
  - `Future<bool> isAvailable()` — false on Linux, otherwise `isDeviceSupported() && canCheckBiometrics`.
  - `Future<bool> authenticate({required String reason})` — false on any `PlatformException` (never throws).

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add local_auth`
Then read the package README for the current platform matrix and any macOS/Windows sub-package requirements (`local_auth_darwin`, `local_auth_windows` are federated defaults — confirm nothing extra is needed in pubspec).

- [ ] **Step 2: Android platform config**

`MainActivity.kt`: change `FlutterActivity` to `FlutterFragmentActivity` (required by local_auth's biometric prompt):

```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
```

(keep the platform-channel registration body unchanged — `configureFlutterEngine` exists on both base classes).

`AndroidManifest.xml`: add inside `<manifest>`:

```xml
    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

- [ ] **Step 3: iOS platform config**

`ios/Runner/Info.plist` — add:

```xml
	<key>NSFaceIDUsageDescription</key>
	<string>Unlock your dive log with Face ID.</string>
```

(macOS Touch ID needs no usage-description key; no entitlement change — verify by building in Task 15. Sandbox and no-sandbox macOS builds both use LAContext, which is entitlement-free.)

- [ ] **Step 4: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/core/services/security/biometric_service.dart';
import 'biometric_service_test.mocks.dart';

@GenerateNiceMocks([MockSpec<LocalAuthentication>()])
void main() {
  test('authenticate returns false instead of throwing', () async {
    final mock = MockLocalAuthentication();
    when(mock.authenticate(
      localizedReason: anyNamed('localizedReason'),
      options: anyNamed('options'),
    )).thenThrow(PlatformException(code: 'NotAvailable'));
    final svc = BiometricService(auth: mock);
    expect(await svc.authenticate(reason: 'test'), false);
  });

  test('authenticate passes through success', () async {
    final mock = MockLocalAuthentication();
    when(mock.authenticate(
      localizedReason: anyNamed('localizedReason'),
      options: anyNamed('options'),
    )).thenAnswer((_) async => true);
    final svc = BiometricService(auth: mock);
    expect(await svc.authenticate(reason: 'test'), true);
  });
}
```

(`PlatformException` import: `package:flutter/services.dart`. Run `dart run build_runner build --delete-conflicting-outputs` for the mocks.)

- [ ] **Step 5: Implement `biometric_service.dart`**

```dart
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Thin, non-throwing wrapper over local_auth. Platform support: iOS,
/// Android, macOS (Touch ID), Windows (Hello). Linux has no local_auth
/// backend — password-only there, and [isAvailable] says so.
class BiometricService {
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  Future<bool> isAvailable() async {
    if (Platform.isLinux) return false;
    try {
      return await _auth.isDeviceSupported() &&
          await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } on PlatformException {
      return false;
    }
  }
}
```

- [ ] **Step 6: Run tests, build check**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/core/services/security/biometric_service_test.dart && flutter build macos --debug`
Expected: PASS; macOS build confirms the new pod integrates (if the build fails on stale pods, run `cd macos && pod install` — known trap after adding a plugin).

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add biometric service and local_auth platform config"
```

---

### Task 10: Startup lock gate

**Files:**
- Create: `lib/core/presentation/widgets/unlock_form.dart`
- Create: `lib/core/presentation/pages/lock_screen_view.dart`
- Modify: `lib/core/presentation/pages/startup_page.dart`
- Test: `test/core/presentation/widgets/unlock_form_test.dart`
- Test: `test/core/presentation/pages/startup_lock_gate_test.dart`

**Interfaces:**
- Consumes: `DatabaseSecurityService`, `BiometricService`, `isEncryptedDatabaseFile`, `DatabaseLockedException`.
- Produces:
  - `UnlockForm` — shared between the startup lock screen and the Task 12 re-lock overlay: `UnlockForm({required Future<bool> Function(String secret) onSubmitSecret, required Future<bool> Function()? onBiometric, bool autoFireBiometric = true, Widget? footer})`. Renders password field + submit, inline "wrong password" error on a false return, biometric button when `onBiometric != null`, optional footer widget (escape hatch links live there).
  - `LockScreenView` — full-screen lock UI for the startup MaterialApp: wraps `UnlockForm` in the `OceanBackground` splash chrome; takes `onUnlocked` callback plus the escape-hatch callbacks (Task 11 fills them in; this task stubs them hidden).
  - `_StartupState.locked` + gate logic in `_runInitialization`.

- [ ] **Step 1: Write the failing widget test for UnlockForm**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/presentation/widgets/unlock_form.dart';

void main() {
  testWidgets('submits secret and shows error on rejection', (tester) async {
    final submitted = <String>[];
    var accept = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UnlockForm(
          autoFireBiometric: false,
          onBiometric: null,
          onSubmitSecret: (s) async {
            submitted.add(s);
            return accept;
          },
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'wrong-pw');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(submitted, ['wrong-pw']);
    expect(find.text('Incorrect password. Try again.'), findsOneWidget);

    accept = true;
    await tester.enterText(find.byType(TextField), 'right-pw');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(submitted, ['wrong-pw', 'right-pw']);
    expect(find.text('Incorrect password. Try again.'), findsNothing);
  });

  testWidgets('shows biometric button when available', (tester) async {
    var fired = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UnlockForm(
          autoFireBiometric: false,
          onBiometric: () async {
            fired++;
            return true;
          },
          onSubmitSecret: (_) async => false,
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.fingerprint));
    await tester.pumpAndSettle();
    expect(fired, 1);
  });
}
```

- [ ] **Step 2: Implement `unlock_form.dart`**

```dart
import 'package:flutter/material.dart';

/// Password + optional-biometric unlock form. Hardcoded English strings by
/// design: at startup this renders inside the pre-l10n splash MaterialApp
/// (same precedent as the splash/migration strings in startup_page.dart),
/// and the re-lock overlay reuses it for visual consistency.
class UnlockForm extends StatefulWidget {
  final Future<bool> Function(String secret) onSubmitSecret;
  final Future<bool> Function()? onBiometric;
  final bool autoFireBiometric;
  final Widget? footer;

  const UnlockForm({
    super.key,
    required this.onSubmitSecret,
    required this.onBiometric,
    this.autoFireBiometric = true,
    this.footer,
  });

  @override
  State<UnlockForm> createState() => _UnlockFormState();
}

class _UnlockFormState extends State<UnlockForm> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoFireBiometric && widget.onBiometric != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onBiometric!();
      // On success the host tears this widget down; on failure fall back to
      // the password field silently (the OS already showed its own error UI).
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _showError = false;
    });
    try {
      final ok = await widget.onSubmitSecret(_controller.text);
      if (!ok && mounted) setState(() => _showError = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            enabled: !_busy,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        if (_showError) ...[
          const SizedBox(height: 8),
          const Text(
            'Incorrect password. Try again.',
            style: TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Unlock'),
        ),
        if (widget.onBiometric != null) ...[
          const SizedBox(height: 12),
          IconButton(
            icon: const Icon(Icons.fingerprint, size: 36),
            onPressed: _busy ? null : _tryBiometric,
            tooltip: 'Unlock with biometrics',
          ),
        ],
        if (widget.footer != null) ...[
          const SizedBox(height: 24),
          widget.footer!,
        ],
      ],
    );
  }
}
```

Run: `flutter test test/core/presentation/widgets/unlock_form_test.dart` — PASS.

- [ ] **Step 3: Implement `lock_screen_view.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/presentation/widgets/ocean_background.dart';
import 'package:submersion/core/presentation/widgets/unlock_form.dart';

/// Full-screen startup lock: splash chrome around an UnlockForm plus the
/// escape-hatch links (recovery code / open a different database).
class LockScreenView extends StatelessWidget {
  final Brightness brightness;
  final Future<bool> Function(String secret) onSubmitSecret;
  final Future<bool> Function()? onBiometric;
  final VoidCallback? onUseRecoveryCode;
  final VoidCallback? onStartFresh;

  const LockScreenView({
    super.key,
    required this.brightness,
    required this.onSubmitSecret,
    required this.onBiometric,
    this.onUseRecoveryCode,
    this.onStartFresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OceanBackground(
        brightness: brightness,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/icon/icon.png', width: 96, height: 96),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Submersion is locked',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 32),
                  UnlockForm(
                    onSubmitSecret: onSubmitSecret,
                    onBiometric: onBiometric,
                    footer: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onUseRecoveryCode != null)
                          TextButton(
                            onPressed: onUseRecoveryCode,
                            child: const Text('Forgot password?'),
                          ),
                        if (onStartFresh != null)
                          TextButton(
                            onPressed: onStartFresh,
                            child: const Text('Open a different database'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Wire the gate into `startup_page.dart`**

Changes, in order:

1. Add `locked` to `_StartupState`.
2. Add fields to `_StartupWrapperState`:

```dart
  Completer<void>? _unlockCompleter;
  bool _biometricAvailable = false;
```

3. At the TOP of `_runInitialization()` (before the schema probe), insert the gate:

```dart
      final security = DatabaseSecurityService.instance;
      await security.configure(prefs: widget.prefs);
      final dbPath = await widget.locationService.getDatabasePath();

      // Trust the file over the flag: an interrupted enable/disable or
      // restored prefs can disagree with the actual header. The file wins.
      final fileEncrypted = isEncryptedDatabaseFile(dbPath);
      if (fileEncrypted != security.encryptionEnabled) {
        await security.preferences.setDbEncryptionEnabled(fileEncrypted);
        await security.refreshDerivedKey();
      }

      if (security.appLockEnabled || security.encryptionEnabled) {
        final cached = await security.tryLoadCachedKey();
        final mustPrompt = security.appLockEnabled ||
            (security.encryptionEnabled && !cached);
        if (mustPrompt) {
          _biometricAvailable = cached &&
              security.preferences.appLockBiometricsEnabled &&
              await BiometricService().isAvailable();
          _unlockCompleter = Completer<void>();
          if (mounted) setState(() => _state = _StartupState.locked);
          await _unlockCompleter!.future;
          if (mounted) setState(() => _state = _StartupState.initializing);
        }
      }
      DatabaseService.instance.databaseKeyHex = security.databaseKeyHex;
```

4. Update the probe line to pass the key (Task 5 already changed the signature): `DatabaseService.getStoredSchemaVersion(dbPath, keyHex: DatabaseService.instance.databaseKeyHex)`.
5. Add the unlock handlers:

```dart
  Future<bool> _unlockWithPassword(String secret) async {
    final security = DatabaseSecurityService.instance;
    final dbPath = await widget.locationService.getDatabasePath();
    final ok = await security.unlockWithSecret(secret, dbPath: dbPath);
    if (ok) _unlockCompleter?.complete();
    return ok;
  }

  Future<bool> _unlockWithBiometric() async {
    final ok = await BiometricService()
        .authenticate(reason: 'Unlock your dive log');
    if (ok) _unlockCompleter?.complete();
    return ok;
  }
```

6. In `build()`, render the lock state inside the splash `MaterialApp` (add a branch alongside the error branch):

```dart
                    : _state == _StartupState.locked
                    ? LockScreenView(
                        brightness: brightness,
                        onSubmitSecret: _unlockWithPassword,
                        onBiometric:
                            _biometricAvailable ? _unlockWithBiometric : null,
                        // Escape hatch callbacks arrive in Task 11.
                        onUseRecoveryCode: null,
                        onStartFresh: null,
                      )
                    : Scaffold( // existing splash scaffold
```

7. Catch `DatabaseLockedException` in `_runInitialization`'s catch chain (before the generic catch): route back to the locked state (wrong cached key — e.g. restored keychain from another device) rather than the error state:

```dart
    } on DatabaseLockedException {
      // Cached/typed key did not open the file: fall back to the password
      // prompt. unlockWithSecret re-derives from the sidecar, which is
      // authoritative.
      _unlockCompleter = Completer<void>();
      if (mounted) setState(() => _state = _StartupState.locked);
      await _unlockCompleter!.future;
      if (mounted) {
        setState(() => _state = _StartupState.initializing);
        await _runInitialization();
      }
    }
```

- [ ] **Step 5: Write the startup gate test**

`test/core/presentation/pages/startup_lock_gate_test.dart` — follow the existing `StartupWrapper` test patterns (find them: `ls test/core/presentation/pages/`). Use `initializerOverride` + `schemaVersionProbeOverride` seams. Scenarios:

```dart
  testWidgets('no security: initializer runs without a lock screen', ...);
  testWidgets('app lock on: shows lock screen, initializer deferred until '
      'unlock succeeds', ...);
  // Arrange the second one by enabling security on a temp dbPath through
  // DatabaseSecurityService with testKdf, then reset the service in-memory
  // state (resetForTesting + configure) so the cached key is gone and the
  // password path is exercised. Drive UnlockForm with tester.enterText.
```

The test must assert ordering: the `initializerOverride` future does not start before unlock (record a timestamp/flag in both).

- [ ] **Step 6: Run tests + analyze**

Run: `flutter test test/core/presentation/ && flutter analyze`
Expected: PASS, including all pre-existing StartupWrapper tests (no-security path must be behaviorally identical).

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add startup lock gate with password and biometric unlock"
```

---

### Task 11: Escape hatch (recovery code + start fresh)

**Files:**
- Create: `lib/core/presentation/pages/lock_escape_dialogs.dart`
- Create: `lib/core/services/security/locked_database_escape.dart`
- Modify: `lib/core/presentation/pages/startup_page.dart` (wire callbacks)
- Modify: the sync-disable provider file (locate: `grep -rln "disableForDatabaseReset" lib/`)
- Test: `test/core/services/security/locked_database_escape_test.dart`

**Interfaces:**
- Consumes: `DatabaseSecurityService.unlockWithSecret` (recovery codes already work through it), `changePassword`, `SecurityPreferences`, `DatabaseSecuritySidecar`.
- Produces:
  - `Future<void> setAsideLockedDatabase({required String dbPath, required SharedPreferences prefs})` (in `locked_database_escape.dart`) — renames `<db>` to `<db>.locked-<stamp>`, `<db>-wal`/`-shm` to `<db>.locked-<stamp>-wal`/`-shm`, sidecar to `submersion.keys.locked-<stamp>`; clears security prefs + keychain; calls the extracted sync-disable function. Never deletes anything.
  - `disableSyncConfigurationInPrefs(SharedPreferences prefs)` — extracted prefs-only core of `disableForDatabaseReset`, callable pre-ProviderScope; the provider method delegates to it.
  - Dialogs: `showRecoveryCodeUnlockDialog(BuildContext, {required Future<bool> Function(String) onSubmit})`, `showStartFreshConfirmDialog(BuildContext)` (returns `Future<bool>`; requires typing `START FRESH` to confirm), `showForcedPasswordResetDialog(BuildContext, {required Future<void> Function(String newPassword) onSubmit})` (modal, no cancel), and `showSidecarRepairDialog(BuildContext, {required Future<bool> Function(String password) onSubmit})`.
  - New `DatabaseSecurityService` members (added in this task):
    - `Future<void> clearInMemoryState()` — nulls the in-memory MLK/keyId/derived key WITHOUT touching prefs wiring (unlike `resetForTesting`).
    - `Future<String> rebuildSidecar({required String password, required String dbPath})` — self-heal for "sidecar lost, keychain intact": requires `isUnlocked` (cached MLK), writes a fresh sidecar wrapping the cached MLK with the confirmed password plus a NEW recovery slot, returns the new recovery code (the old one died with the old sidecar). Throws `StateError` when locked.

- [ ] **Step 1: Extract the sync-disable core**

Locate `disableForDatabaseReset` (`grep -rn "disableForDatabaseReset" lib/`). Read the method; split every statement that only touches SharedPreferences/config into a new top-level function `disableSyncConfigurationInPrefs(SharedPreferences prefs)` in the same file (or the sync prefs file it manipulates — put it where its imports are lightest, with no Riverpod dependency). The provider method calls the function; behavior for the reset flow is unchanged. Run the existing sync tests that cover reset: `grep -rln "disableForDatabaseReset" test/` and run those files.

If the method body turns out to require live provider state (not just prefs), instead expose the narrowest prefs-clearing subset the startup path needs (sync-enabled flag off + provider/back-end selection cleared) as the function, and document in a comment that a running app goes through the provider method.

- [ ] **Step 2: Write the failing escape test**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/security/database_security_service.dart';
import 'package:submersion/core/services/security/locked_database_escape.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('setAsideLockedDatabase renames db, sidecars, keys; clears security',
      () async {
    final tmp = await Directory.systemTemp.createTemp('escape_test');
    addTearDown(() => tmp.delete(recursive: true));
    final dbPath = '${tmp.path}/submersion.db';
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    DatabaseSecurityService.instance.resetForTesting();
    await DatabaseSecurityService.instance.configure(prefs: prefs);
    await DatabaseSecurityService.instance.enableSecurity(
      password: 'pw', dbPath: dbPath, kdf: testKdf);
    File(dbPath).writeAsStringSync('DB');
    File('$dbPath-wal').writeAsStringSync('WAL');

    await setAsideLockedDatabase(dbPath: dbPath, prefs: prefs);

    expect(File(dbPath).existsSync(), false);
    expect(File('${tmp.path}/submersion.keys').existsSync(), false);
    final setAside = tmp
        .listSync()
        .map((e) => e.path.split('/').last)
        .toList()
      ..sort();
    expect(setAside.where((n) => n.startsWith('submersion.db.locked-')),
        hasLength(2)); // db + wal
    expect(setAside.where((n) => n.startsWith('submersion.keys.locked-')),
        hasLength(1));
    expect(DatabaseSecurityService.instance.appLockEnabled, false);
  });
}
```

(`testKdf` shared from the service test — move it to `test/helpers/security_test_kdf.dart` and import from both.)

- [ ] **Step 3: Implement `locked_database_escape.dart`**

```dart
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/security/database_security_key_store.dart';
import 'package:submersion/core/services/security/database_security_sidecar.dart';
import 'package:submersion/core/services/security/security_preferences.dart';
// import for disableSyncConfigurationInPrefs — path from Step 1

/// "Open a different database": sets the locked database ASIDE (never
/// deletes), clears the security configuration, and disables cloud sync so
/// the fresh database cannot cross-contaminate the old sync library (same
/// rationale as the Reset flow). The caller restarts initialization, which
/// creates a fresh plaintext DB and lands in the first-run wizard (where
/// restore-from-backup already lives).
Future<void> setAsideLockedDatabase({
  required String dbPath,
  required SharedPreferences prefs,
}) async {
  final stamp = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());

  Future<void> setAside(String path, String target) async {
    final f = File(path);
    if (await f.exists()) await f.rename(target);
  }

  await setAside(dbPath, '$dbPath.locked-$stamp');
  await setAside('$dbPath-wal', '$dbPath.locked-$stamp-wal');
  await setAside('$dbPath-shm', '$dbPath.locked-$stamp-shm');
  final sidecar = DatabaseSecuritySidecar.pathFor(dbPath);
  await setAside(sidecar, '$sidecar.locked-$stamp');

  final securityPrefs = SecurityPreferences(prefs);
  await securityPrefs.setAppLockEnabled(false);
  await securityPrefs.setDbEncryptionEnabled(false);
  await DatabaseSecurityKeyStore().clearKey();
  disableSyncConfigurationInPrefs(prefs);
}
```

(If the security service holds in-memory state, also clear it: call `DatabaseSecurityService.instance.resetForTesting()` — no; instead add a public `Future<void> clearInMemoryState()` doing `_mlk = null; _libraryKeyId = null; _databaseKeyHex = null;` and call that. `resetForTesting` also nulls prefs wiring, which would break the continuing startup.)

- [ ] **Step 4: Implement the dialogs**

`lock_escape_dialogs.dart` — two plain `showDialog` helpers, hardcoded English (startup context). Recovery dialog: single `TextField` (label `Recovery code`), Cancel/Unlock buttons, inline `Incorrect recovery code.` error on false. Start-fresh dialog: warning copy (`Your current database stays on disk, renamed with a .locked suffix. You can restore it later with your password or by contacting support. Cloud sync will be turned off.`), a `TextField` that must equal `START FRESH` to enable the destructive `FilledButton` (`Set aside and start fresh`). Follow `ResetDatabaseDialog`'s structure (`grep -rln "class ResetDatabaseDialog" lib/`) for the confirm-typing pattern.

- [ ] **Step 5: Wire into the startup gate**

In `startup_page.dart`, replace the two `null` callbacks from Task 10:

```dart
                        onUseRecoveryCode: () => _handleRecoveryUnlock(),
                        onStartFresh: () => _handleStartFresh(),
```

with handlers:

```dart
  Future<void> _handleRecoveryUnlock() async {
    // The splash MaterialApp has its own Navigator; use the locked page's
    // context via a Builder or a navigator key on the splash MaterialApp.
    final ok = await showRecoveryCodeUnlockDialog(
      _splashNavigatorKey.currentContext!,
      onSubmit: (code) => _unlockWithPassword(code), // tryUnwrap handles both
    );
    if (ok == true) {
      // Recovery implies the password is lost: force a new one on next
      // settings visit is NOT enough — prompt immediately per spec.
      await showForcedPasswordResetDialog(
        _splashNavigatorKey.currentContext!,
        onSubmit: (newPassword) async {
          final dbPath = await widget.locationService.getDatabasePath();
          await DatabaseSecurityService.instance.changePassword(
            currentSecret: _lastAcceptedSecret!,
            newPassword: newPassword,
            dbPath: dbPath,
          );
        },
      );
    }
  }

  Future<void> _handleStartFresh() async {
    final confirmed = await showStartFreshConfirmDialog(
      _splashNavigatorKey.currentContext!);
    if (confirmed != true) return;
    final dbPath = await widget.locationService.getDatabasePath();
    await setAsideLockedDatabase(dbPath: dbPath, prefs: widget.prefs);
    await DatabaseSecurityService.instance.clearInMemoryState();
    DatabaseService.instance.databaseKeyHex = null;
    _unlockCompleter?.complete();
  }
```

Implementation details this implies (do them): a `_splashNavigatorKey` (`GlobalKey<NavigatorState>`) passed as `navigatorKey:` to the splash `MaterialApp`; `_lastAcceptedSecret` captured in `_unlockWithPassword` on success (needed for the forced change); a third small dialog `showForcedPasswordResetDialog` (new password + confirm fields, no cancel — modal `barrierDismissible: false`); `clearInMemoryState()` added to `DatabaseSecurityService` (Step 3's note). After `_handleStartFresh` completes the completer, `_runInitialization` continues, opens the now-missing path, and drift creates a fresh empty database — the existing first-run redirect takes over.

- [ ] **Step 6: Sidecar self-heal (spec error-table row: "sidecar lost, keychain intact")**

Implement `clearInMemoryState()` and `rebuildSidecar(...)` on `DatabaseSecurityService`:

```dart
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
          type: 'passphrase', secret: password, mlk: mlk, kdf: kdf),
        await Keyslots.createSlot(
          type: 'recovery', secret: recoveryCode, mlk: mlk, kdf: kdf),
      ],
    );
    await DatabaseSecuritySidecar.write(dbPath, file);
    return recoveryCode;
  }
```

Detection + prompt in the startup gate (`_runInitialization`, immediately after the `mustPrompt` block from Task 10 — i.e. once a cached key loaded and no prompt was needed OR unlock completed):

```dart
      if ((security.appLockEnabled || security.encryptionEnabled) &&
          security.isUnlocked &&
          await DatabaseSecuritySidecar.read(dbPath) == null) {
        // Sidecar missing but the keychain saved us. Rebuild it now — the
        // cached key is the only unlock left; losing it too would strand
        // the database permanently.
        final repaired = await showSidecarRepairDialog(
          _splashNavigatorKey.currentContext!,
          onSubmit: (password) async {
            final code = await security.rebuildSidecar(
              password: password, dbPath: dbPath);
            // Show the new recovery code with the existing display dialog.
            return true;
          },
        );
        // Declining is allowed (repair reoffered next launch); log it.
        if (repaired != true) {
          debugPrint('Sidecar repair declined; will reoffer next launch.');
        }
      }
```

`showSidecarRepairDialog`: password field + explanation (`Your security key file was missing and has been restored from this device's keychain. Confirm your password to finish the repair; you will receive a new recovery code.`); validate the password by attempting `rebuildSidecar` inside `onSubmit` — but FIRST verify the password actually matches the cached MLK. The cached MLK cannot verify a password by itself (no sidecar to unwrap), so the dialog copy must be explicit that this SETS the password going forward; that is acceptable because possession of the unlocked keychain is the trust anchor here. Unit-test `rebuildSidecar`: enable security, delete the sidecar file, call `rebuildSidecar` with a new password, then `unlockWithSecret` with that password and with the returned recovery code both succeed.

- [ ] **Step 7: Reset Database clears security state (spec Feature Interactions)**

In `storage_settings_page.dart` `_handleResetDatabase` (line ~419): the confirm dialog copy must mention security removal when security is on, and after the reset the fresh database must start unprotected. Sequence (chosen so the pre-reset backup still decrypt-exports with the old key, and the transient fresh-encrypted file is handled by the existing machinery):

1. `await DatabaseService.instance.resetDatabase(backupPath: backupPath)` — runs entirely with the old key: its internal `backup()` decrypt-exports a plaintext pre-reset backup (Task 8), and the fresh empty file it reinitializes is created encrypted (key still set).
2. If encryption was on: `await security.disableEncryption()` — a fast no-data export that leaves the fresh file plaintext.
3. `await security.disableSecurity(dbPath: await DatabaseService.instance.databasePath)` — deletes the sidecar, clears keychain and flags, nulls in-memory state.

```dart
      await DatabaseService.instance.resetDatabase(backupPath: backupPath);

      // A fresh database starts unprotected: the data the credential
      // protected is gone, and keeping a lock over an empty database with a
      // credential the user may not remember would only strand them again.
      final security = DatabaseSecurityService.instance;
      if (security.encryptionEnabled) {
        await security.disableEncryption();
      }
      if (security.appLockEnabled) {
        await security.disableSecurity(
          dbPath: await DatabaseService.instance.databasePath);
      }
```

Widget-test the reset flow change with the existing reset-flow test file (`grep -rln "resetDatabase" test/features/settings/`).

- [ ] **Step 8: Run tests + analyze**

Run: `flutter test test/core/ test/features/settings/ && flutter analyze`
Expected: PASS, including the Step 2 escape test and the Step 1 sync-reset tests.

- [ ] **Step 9: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add escape hatch, sidecar self-heal, and reset security clearing"
```

---

### Task 12: Background-timeout re-lock overlay

**Files:**
- Create: `lib/core/presentation/providers/app_lock_provider.dart`
- Create: `lib/core/presentation/widgets/lock_barrier.dart`
- Modify: `lib/app.dart` (lifecycle hook + builder wrap)
- Test: `test/core/presentation/providers/app_lock_provider_test.dart`
- Test: `test/core/presentation/widgets/lock_barrier_test.dart`

**Interfaces:**
- Consumes: `DatabaseSecurityService` (appLockEnabled, unlock verification via `unlockWithSecret`), `BiometricService`, `SecurityPreferences.appLockTimeoutMinutes`, `clock` package (zone-aware `clock.now()` — project convention for testable time).
- Produces:
  - `appLockNotifierProvider` (`NotifierProvider<AppLockNotifier, bool>` — state true = locked):
    - `void noteBackgrounded()` — records `clock.now()`; no-op when app lock disabled.
    - `void noteResumed()` — locks when elapsed >= timeout (`0` locks always, `-1` never).
    - `Future<bool> unlockWithSecret(String secret)`, `Future<bool> unlockWithBiometric()` — set state false on success.
  - `LockBarrier` — watches the provider; when locked, covers the whole app with an opaque full-screen `UnlockForm` (reused from Task 10); DB stays open behind it.

- [ ] **Step 1: Write the failing provider test**

```dart
import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/presentation/providers/app_lock_provider.dart';
import 'package:submersion/core/services/security/database_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> makeContainer({required int timeoutMinutes}) async {
    SharedPreferences.setMockInitialValues({
      'app_lock_enabled': true,
      'app_lock_timeout_minutes': timeoutMinutes,
    });
    final prefs = await SharedPreferences.getInstance();
    DatabaseSecurityService.instance.resetForTesting();
    await DatabaseSecurityService.instance.configure(prefs: prefs);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('locks after timeout elapses in background', () async {
    final container = await makeContainer(timeoutMinutes: 5);
    final notifier = container.read(appLockNotifierProvider.notifier);
    withClock(Clock.fixed(DateTime(2026, 8, 6, 12, 0)), () {
      notifier.noteBackgrounded();
    });
    withClock(Clock.fixed(DateTime(2026, 8, 6, 12, 6)), () {
      notifier.noteResumed();
    });
    expect(container.read(appLockNotifierProvider), true);
  });

  test('does not lock before timeout', () async {
    final container = await makeContainer(timeoutMinutes: 5);
    final notifier = container.read(appLockNotifierProvider.notifier);
    withClock(Clock.fixed(DateTime(2026, 8, 6, 12, 0)), () {
      notifier.noteBackgrounded();
    });
    withClock(Clock.fixed(DateTime(2026, 8, 6, 12, 3)), () {
      notifier.noteResumed();
    });
    expect(container.read(appLockNotifierProvider), false);
  });

  test('timeout -1 never locks; 0 locks immediately', () async {
    final never = await makeContainer(timeoutMinutes: -1);
    final n1 = never.read(appLockNotifierProvider.notifier);
    n1.noteBackgrounded();
    n1.noteResumed();
    expect(never.read(appLockNotifierProvider), false);

    final immediate = await makeContainer(timeoutMinutes: 0);
    final n2 = immediate.read(appLockNotifierProvider.notifier);
    n2.noteBackgrounded();
    n2.noteResumed();
    expect(immediate.read(appLockNotifierProvider), true);
  });

  test('no-op entirely when app lock disabled', () async {
    SharedPreferences.setMockInitialValues({'app_lock_enabled': false});
    // ... same wiring; noteBackgrounded/noteResumed leave state false.
  });
}
```

- [ ] **Step 2: Implement the provider**

```dart
import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/security/biometric_service.dart';
import 'package:submersion/core/services/security/database_security_service.dart';

/// True = the running app is locked behind the re-lock overlay. The database
/// stays open — this is a UI gate (App Lock tier), not a DB close.
final appLockNotifierProvider =
    NotifierProvider<AppLockNotifier, bool>(AppLockNotifier.new);

class AppLockNotifier extends Notifier<bool> {
  DateTime? _backgroundedAt;

  @override
  bool build() => false;

  DatabaseSecurityService get _security => DatabaseSecurityService.instance;

  void noteBackgrounded() {
    if (!_security.appLockEnabled) return;
    _backgroundedAt ??= clock.now();
  }

  void noteResumed() {
    final at = _backgroundedAt;
    _backgroundedAt = null;
    if (!_security.appLockEnabled || at == null) return;
    final timeout = _security.preferences.appLockTimeoutMinutes;
    if (timeout < 0) return;
    if (clock.now().difference(at).inMinutes >= timeout) {
      state = true;
    }
  }

  Future<bool> unlockWithSecret(String secret) async {
    final dbPath = await DatabaseService.instance.databasePath;
    final ok = await _security.unlockWithSecret(secret, dbPath: dbPath);
    if (ok) state = false;
    return ok;
  }

  Future<bool> unlockWithBiometric() async {
    if (!_security.preferences.appLockBiometricsEnabled) return false;
    final ok =
        await BiometricService().authenticate(reason: 'Unlock Submersion');
    if (ok) state = false;
    return ok;
  }
}
```

(`timeout == 0` locks because `>= 0` minutes always holds. Riverpod 3 note: mutating `state` from lifecycle callbacks is fine; do NOT touch `state` in `dispose`.)

- [ ] **Step 3: Implement `LockBarrier` + wire `app.dart`**

`lock_barrier.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/presentation/providers/app_lock_provider.dart';
import 'package:submersion/core/presentation/widgets/unlock_form.dart';

/// Full-screen opaque overlay while the app is re-locked. Mirrors
/// RestoreBarrier's placement in the MaterialApp builder; sits OUTSIDE it so
/// the lock covers restore UI too.
class LockBarrier extends ConsumerWidget {
  final Widget child;

  const LockBarrier({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(appLockNotifierProvider);
    return Stack(
      children: [
        child,
        if (locked)
          Positioned.fill(
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                child: Center(
                  child: UnlockForm(
                    onSubmitSecret: (s) => ref
                        .read(appLockNotifierProvider.notifier)
                        .unlockWithSecret(s),
                    onBiometric: () => ref
                        .read(appLockNotifierProvider.notifier)
                        .unlockWithBiometric(),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

In `lib/app.dart`:
- `didChangeAppLifecycleState`: add before the existing resumed branch:

```dart
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      ref.read(appLockNotifierProvider.notifier).noteBackgrounded();
    }
    if (state == AppLifecycleState.resumed) {
      ref.read(appLockNotifierProvider.notifier).noteResumed();
      _maybeSyncOnResume();
    }
```

- In the MaterialApp `builder` (`app.dart:340` area), wrap OUTSIDE `RestoreBarrier`: `return LockBarrier(child: RestoreBarrier(child: ...));`

**Riverpod 3 consumer-test warning:** `LockBarrier` adds a provider dependency under the app root. Existing widget tests that pump the full app builder may now need the security service configured — the provider reads `DatabaseSecurityService.instance`, which throws `StateError` if unconfigured. Guard in the notifier instead: wrap `_security.appLockEnabled` reads so an unconfigured service means "disabled" — change the getter usage to:

```dart
  bool get _appLockEnabled {
    try {
      return _security.appLockEnabled;
    } on StateError {
      return false; // unconfigured (tests, early frames): treat as disabled
    }
  }
```

and use `_appLockEnabled` in both note methods and `build`.

- [ ] **Step 4: Widget test for LockBarrier**

```dart
  testWidgets('shows overlay when locked, hides after successful unlock', ...);
  // Pump ProviderScope > MaterialApp > LockBarrier(child: Text('APP')),
  // drive the notifier to locked via noteBackgrounded/noteResumed with a
  // fixed clock and timeout 0, verify 'APP' is obscured (UnlockForm found),
  // then complete an unlock (override unlockWithSecret path by enabling
  // security on a temp sidecar with testKdf) and verify the overlay is gone.
```

- [ ] **Step 5: Run tests + FULL suite for consumer-test fallout**

Run: `flutter test test/core/presentation/ && flutter analyze`, then the full `flutter test` (10-minute timeout) — the app-root widget change is exactly the shape that breaks distant consumer tests; fix any that fail (usual fix: configure the security service or rely on the StateError guard above).

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add background-timeout re-lock overlay"
```

---

### Task 13: Security settings page + l10n

**Files:**
- Create: `lib/features/settings/presentation/pages/security_settings_page.dart`
- Create: `lib/features/settings/presentation/widgets/security_setup_dialog.dart`
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (section registration — mirror how `SafetySettingsPage` is registered at `settings_page.dart:136` and `:270`)
- Modify: `lib/l10n/app_en.arb` + all 10 non-English ARB files
- Test: `test/features/settings/presentation/pages/security_settings_page_test.dart`

**Interfaces:**
- Consumes: `DatabaseSecurityService` (all lifecycle methods), `BiometricService.isAvailable`, `SecurityPreferences`, existing recovery-code display widget patterns (`lib/features/backup/presentation/widgets/backup_recovery_code*.dart` — read for structure), `RestoreBarrier`-style progress dialog for encryption runs.
- Produces: a `SecuritySettingsPage` reachable from the settings list with:
  - App Lock master switch. OFF -> ON: `security_setup_dialog` flow — set password (with confirm field, min 4 chars), then full-screen recovery-code display with an "I saved it" confirm (mirror the backup enable-encryption widget flow). ON -> OFF: require current password or biometric; blocked (explanatory dialog) while encryption is on.
  - Biometric toggle (visible only when `BiometricService.isAvailable()`).
  - Auto-lock timeout selector (Immediately / 1 minute / 5 minutes / 15 minutes / Never) — `SegmentedButton` or dropdown matching nearby settings idiom.
  - Database Encryption switch. OFF -> ON with app lock already on: confirmation dialog explaining the safety backup, then a blocking `PopScope(canPop: false)` progress dialog driven by `enableEncryption(onPhase: ...)`. OFF -> ON with app lock OFF: per spec, run the password-setup flow first (same `security_setup_dialog` as the App Lock switch — sets the password, shows the recovery code, turns App Lock on), then continue straight into the encryption confirmation. ON -> OFF: reverse via `disableEncryption`.
  - Change password tile (current + new + confirm) and Regenerate recovery code tile (current secret, then the display screen) — both mirror the backup equivalents.
- New l10n keys (exact, in `app_en.arb`; translate to all 10 locales): `settings_security_title`, `settings_security_subtitle`, `settings_security_appLock`, `settings_security_appLock_subtitle`, `settings_security_biometrics`, `settings_security_autoLock`, `settings_security_autoLock_immediately`, `settings_security_autoLock_minutes` (plural-parameterized), `settings_security_autoLock_never`, `settings_security_encryption`, `settings_security_encryption_subtitle`, `settings_security_encryption_progress_backup`, `settings_security_encryption_progress_encrypt`, `settings_security_encryption_progress_decrypt`, `settings_security_encryption_progress_reopen`, `settings_security_changePassword`, `settings_security_regenerateRecovery`, `settings_security_setPassword`, `settings_security_confirmPassword`, `settings_security_passwordMismatch`, `settings_security_wrongPassword`, `settings_security_recoveryCode_title`, `settings_security_recoveryCode_saved`, `settings_security_disableBlockedByEncryption`.

- [ ] **Step 1: Read the precedents**

Read `lib/features/backup/presentation/widgets/backup_enable_encryption_dialog.dart` (or closest-named file: `ls lib/features/backup/presentation/widgets/`), the recovery-code widget, and `settings_page.dart:120-160` + `:260-280` (section registration + navigation). The settings page and dialogs must match these structures — same dialog shapes, same section registration mechanics.

- [ ] **Step 2: Write the failing widget tests**

Mock `DatabaseSecurityService` state via its real singleton + temp sidecar + `testKdf` (no service interface change). Cases:

```dart
  testWidgets('shows both toggles off by default', ...);
  testWidgets('enabling app lock walks password -> recovery code flow', ...);
  testWidgets('encryption toggle with app lock off launches the password '
      'setup flow first', ...);
  testWidgets('disable app lock is blocked while encryption is on', ...);
```

Follow the widget-test conventions used by the backup settings tests (find: `ls test/features/backup/presentation/`), including `MaterialApp` + l10n delegate hosting and pinned locale.

- [ ] **Step 3: Implement page + dialogs + register the section + add all l10n strings**

Implementation mirrors precedents from Step 1; every user-visible string through `context.l10n.*`. Add English strings first, run `flutter gen-l10n`, implement, then translate all 10 non-English ARBs (de, es, fr, it, ja, ko, nl, pt, ru, zh — confirm exact set with `ls lib/l10n/*.arb`) and re-run `flutter gen-l10n`.

- [ ] **Step 4: Run tests + analyze**

Run: `flutter test test/features/settings/ && flutter analyze`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add App Security settings page with l10n"
```

---

### Task 14: Headless background-task key loading

**Files:**
- Modify: `lib/core/services/background_service.dart`
- Test: `test/core/services/background_service_security_test.dart` (only if the file's dispatcher is host-testable — check for existing tests: `ls test/core/services/ | grep background`; if the dispatcher is not under test today, add the guard logic as a separately-testable function)

**Interfaces:**
- Consumes: `DatabaseSecurityService.configure/tryLoadCachedKey/encryptionEnabled/databaseKeyHex`, `setupSqlcipher`.
- Produces: `Future<bool> prepareHeadlessDatabaseKey({required SharedPreferences prefs})` (top-level in `background_service.dart`) — returns false when the task must be skipped (encryption on, no cached key). Callers: the Workmanager `callbackDispatcher` before `DatabaseService.instance.initialize()`.

- [ ] **Step 1: Implement the helper + wire the dispatcher**

In `background_service.dart`, add:

```dart
/// Headless isolates have no unlock UI. Load the cached key (keychain) and
/// hand it to DatabaseService; when the database is encrypted and no cached
/// key exists (fresh device, keychain wipe), the task must SKIP — never
/// prompt, never open, never corrupt.
Future<bool> prepareHeadlessDatabaseKey({
  required SharedPreferences prefs,
}) async {
  // Fresh isolate: re-apply the per-isolate sqlite3 loader override.
  setupSqlcipher();
  final security = DatabaseSecurityService.instance;
  await security.configure(prefs: prefs);
  if (!security.encryptionEnabled) return true;
  final loaded = await security.tryLoadCachedKey();
  if (!loaded || security.databaseKeyHex == null) return false;
  DatabaseService.instance.databaseKeyHex = security.databaseKeyHex;
  return true;
}
```

In `callbackDispatcher`, before the `DatabaseService.instance.initialize()` call (find it around `background_service.dart:29`; it already obtains SharedPreferences — reuse that instance or fetch one):

```dart
    final ready = await prepareHeadlessDatabaseKey(prefs: prefs);
    if (!ready) {
      debugPrint(
        'Background task skipped: database is encrypted and no cached key '
        'is available in this headless context.');
      return true; // task "succeeded" — do not retry-loop a locked DB
    }
```

- [ ] **Step 2: Test the helper**

Host test with mock prefs + the Task 2/4 secure-storage mocking: encryption off returns true; encryption on + no cached key returns false; encryption on + cached key returns true and sets `DatabaseService.instance.databaseKeyHex`.

- [ ] **Step 3: Run + commit**

Run: `flutter test test/core/services/ && flutter analyze`

```bash
dart format .
git add -A
git commit -m "Load cached database key in headless background tasks"
```

---

### Task 15: Integration tests and final verification

**Files:**
- Create: `integration_test/db_security_test.dart`
- Test: full suite

**Interfaces:**
- Consumes: everything above; real SQLCipher (this is the only place the actual cipher runs in tests).

- [ ] **Step 1: Write the integration test (single app launch — macOS gotcha: a second `app.main()` launch in one file hangs)**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/sqlcipher_setup.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/security/database_encryption_migrator.dart';
import 'package:submersion/core/services/security/database_security_sidecar.dart';
import 'package:submersion/core/services/security/database_security_service.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const testKdf = KdfParams(m: 64, t: 1, p: 1);

  testWidgets('full encryption lifecycle against real SQLCipher',
      (tester) async {
    setupSqlcipher();
    final tmp = await Directory.systemTemp.createTemp('dbsec_integration');
    addTearDown(() => tmp.delete(recursive: true));
    final dbPath = '${tmp.path}/submersion.db';

    // 0. Cipher is linked: raw open answers cipher_version.
    final probe = DatabaseService.openRaw(
      dbPath, mode: OpenMode.readWriteCreate);
    expect(probe.select('PRAGMA cipher_version'), isNotEmpty,
        reason: 'sqlcipher_flutter_libs must be the linked sqlite3');
    probe.execute('CREATE TABLE t (v TEXT)');
    probe.execute("INSERT INTO t VALUES ('dive-1')");
    probe.execute('PRAGMA user_version = 7');
    probe.dispose();
    expect(isEncryptedDatabaseFile(dbPath), false);

    // 1. Security + encryption.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final svc = DatabaseSecurityService.instance;
    svc.resetForTesting();
    await svc.configure(prefs: prefs);
    await svc.enableSecurity(
      password: 'correct-horse', dbPath: dbPath, kdf: testKdf);
    final keyHex = await DatabaseSecurityService.deriveDbKeyHex(
      (await Keyslots.tryUnwrap(
        file: (await DatabaseSecuritySidecar.read(dbPath))!,
        secret: 'correct-horse',
      ))!,
    );

    // 2. Encrypt in place with the REAL exporter.
    await DatabaseEncryptionMigrator()
        .encryptInPlace(dbPath: dbPath, keyHex: keyHex);
    expect(isEncryptedDatabaseFile(dbPath), true);

    // 3. Keyless open fails as DatabaseLockedException; keyed open works
    //    and user_version survived the export.
    expect(() => DatabaseService.getStoredSchemaVersion(dbPath),
        throwsA(isA<DatabaseLockedException>()));
    expect(
      DatabaseService.getStoredSchemaVersion(dbPath, keyHex: keyHex), 7);
    final keyed = DatabaseService.openRaw(dbPath, keyHex: keyHex);
    expect(keyed.select('SELECT v FROM t').first.values.first, 'dive-1');
    keyed.dispose();

    // 4. Portable backup: decrypt-export produces a plaintext file.
    final backupPath = '${tmp.path}/backup.db';
    await sqlcipherExport(
      sourcePath: dbPath,
      targetPath: backupPath,
      sourceKeyHex: keyHex,
      targetKeyHex: null,
    );
    expect(isEncryptedDatabaseFile(backupPath), false);
    expect(DatabaseService.getStoredSchemaVersion(backupPath), 7);

    // 5. Decrypt in place round-trips.
    await DatabaseEncryptionMigrator()
        .decryptInPlace(dbPath: dbPath, keyHex: keyHex);
    expect(isEncryptedDatabaseFile(dbPath), false);
    expect(DatabaseService.getStoredSchemaVersion(dbPath), 7);
  });
}
```

(Add the missing import for `DatabaseLockedException` and `OpenMode`; wrong-key behavior — `getStoredSchemaVersion(dbPath, keyHex: 'ff' * 32)` throwing with `wrongKey: true` — add as an extra expect in section 3.)

- [ ] **Step 2: Run it on macOS**

Run: `flutter test integration_test/db_security_test.dart -d macos` (long timeout; first run compiles the app)
Expected: PASS. This is the proof the real cipher, the export choreography, and the key derivation all agree.

- [ ] **Step 3: Full-suite + format + analyze final gate**

Run, in order, no output piping:

```bash
dart format .
flutter analyze
flutter test
```

Expected: format idempotent, analyze clean, full suite green (pre-existing known flakes excepted — rerun any flaky file once to confirm it is the known flake, not a regression).

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Add SQLCipher integration test for the encryption lifecycle"
```

---

## Post-plan checklist (for the finishing session, not a task)

- CI must build all five platforms on the PR — watch the Android APK job (bundled `libsqlcipher.so` replaces `libsqlite3.so`) and Windows/Linux CMake jobs specifically.
- Manual smoke on a real device/simulator per platform before merge: enable app lock, relaunch, biometric unlock, enable encryption, relaunch, verify data.
- Consider surfacing "database is encrypted" in the storage settings page status area (nice-to-have, not in scope).
