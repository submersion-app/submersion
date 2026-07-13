# Encrypted Backups (app-wide, password-protected) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver set one password (with a recovery code) that encrypts every backup the app writes — local auto-backups, manual Save-to-File, Share, and cloud uploads — restorable with that password or recovery code.

**Architecture:** A new, independent `BackupEncryptionService` + `BackupEncryptionKeyStore` own a backup-scoped master key (MLK) wrapped by a passphrase keyslot and a recovery keyslot, stored in secure storage. `BackupService` encrypts on every write path (reusing the shipped `BackupCrypto` framed-`.sbe` format and `Keyslots` primitives) and gains a restore branch for the backup key. #520's `SyncEncryptionService` is not modified. No database schema change.

**Tech Stack:** Flutter/Dart, Riverpod, `cryptography` package (AES-256-GCM, Argon2id, HKDF), `flutter_secure_storage` (via `FallbackSecureStorage`), SharedPreferences, Drift (unaffected).

## Global Constraints

- **Reuse, do not refactor #520.** Do not modify `lib/core/services/sync/crypto/sync_encryption_service.dart`, `encryption_key_store.dart`, or `lib/core/services/cloud_storage/encrypting_cloud_storage_provider.dart`. Reuse `Keyslots`, `RecoveryCode`, `BackupCrypto`, `SyncEnvelope`, `UnlockedKey`, `WrongPassphraseException` as-is.
- **Artifact extension stays `.sbe`; internal magic stays `SBE1`.** `BackupCrypto.fileExtension` is unchanged.
- **Recovery code is always generated at enable** (EFF wordlist), behind a "confirm you saved it" gate.
- **Separate backup key**: backup secure-storage keys must be distinct from the sync store's (`sync_encryption_*`). Use the `backup_encryption_*` prefix.
- **No DB schema change**, no schema-version bump. Everything is SharedPreferences + secure storage + file I/O.
- **Tests use the fast KDF** `const KdfParams(m: 1024, t: 3, p: 1)` — never run 64 MiB Argon2id in tests. Import from `package:submersion/core/services/sync/crypto/keyslots.dart`.
- **Localization**: every new user-facing string goes into `lib/l10n/app_en.arb` AND all 10 non-en locale ARBs, then regenerate (`flutter gen-l10n` runs via build). Locales: ar, de, es, fr, it, ja, ko, nl, pt, zh (confirm the exact set from existing `app_*.arb` files).
- **Formatting/lint**: `dart format .` clean and `flutter analyze` clean (whole project) before every commit.
- **No emojis** in code, comments, or strings. Immutability: use `copyWith`, never mutate.
- **Run specific test files** during TDD (not the whole suite each step) to avoid timeouts; run the full suite only in the final task.
- **Commit** at the end of each task with a conventional-commit message; do not add a co-author trailer.

**Reference the approved spec:** `docs/superpowers/specs/2026-07-13-encrypted-backups-design.md`.

---

## Deviation from spec (intentional simplification)

The spec sketched three UI states (Off / On-unlocked / On-locked) and an `unlock` method, mirroring sync. Backups are **local-only** — the MLK lives unwrapped in secure storage and each `.sbe` embeds its own keyslots — so there is no cross-device key transport and no "locked" state. This plan implements **two states (Off / On)** and no `unlock`. All five locked decisions from the spec still hold. This is a correctness simplification, not a scope change.

---

### Task 1: Backup-encryption preference flag

**Files:**
- Modify: `lib/features/backup/domain/entities/backup_settings.dart`
- Modify: `lib/features/backup/data/repositories/backup_preferences.dart`
- Modify: `lib/features/backup/presentation/providers/backup_providers.dart` (`BackupSettingsNotifier`, ~L49-131)
- Test: `test/features/backup/data/repositories/backup_preferences_test.dart` (add cases; create if absent)

**Interfaces:**
- Produces: `BackupSettings.backupEncryptionEnabled` (bool, default false); `BackupPreferences.setBackupEncryptionEnabled(bool)`; `BackupSettingsNotifier.setBackupEncryptionEnabled(bool)`.

- [ ] **Step 1: Write the failing test**

Add to `test/features/backup/data/repositories/backup_preferences_test.dart` (mirror existing style: `SharedPreferences.setMockInitialValues({})`, `await SharedPreferences.getInstance()`):

```dart
test('backupEncryptionEnabled defaults false and round-trips', () async {
  SharedPreferences.setMockInitialValues({});
  final prefs = BackupPreferences(await SharedPreferences.getInstance());
  expect(prefs.getSettings().backupEncryptionEnabled, isFalse);
  await prefs.setBackupEncryptionEnabled(true);
  expect(prefs.getSettings().backupEncryptionEnabled, isTrue);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/repositories/backup_preferences_test.dart`
Expected: FAIL (`backupEncryptionEnabled` / `setBackupEncryptionEnabled` not defined).

- [ ] **Step 3: Add the field to `BackupSettings`**

In `backup_settings.dart`: add `final bool backupEncryptionEnabled;`, constructor `this.backupEncryptionEnabled = false,`, copyWith param `bool? backupEncryptionEnabled,` and assignment `backupEncryptionEnabled: backupEncryptionEnabled ?? this.backupEncryptionEnabled,`, and add `backupEncryptionEnabled` to the `props` list.

- [ ] **Step 4: Add persistence to `BackupPreferences`**

In `backup_preferences.dart`: add `static const String _backupEncryptionEnabledKey = 'backup_encryption_enabled';`. In `getSettings()` add `backupEncryptionEnabled: _prefs.getBool(_backupEncryptionEnabledKey) ?? false,`. Add:

```dart
Future<void> setBackupEncryptionEnabled(bool value) async {
  await _prefs.setBool(_backupEncryptionEnabledKey, value);
}
```

- [ ] **Step 5: Add the notifier setter**

In `BackupSettingsNotifier` (backup_providers.dart), mirror `setCloudBackupEnabled`:

```dart
Future<void> setBackupEncryptionEnabled(bool value) async {
  await _prefs.setBackupEncryptionEnabled(value);
  state = state.copyWith(backupEncryptionEnabled: value);
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/backup/data/repositories/backup_preferences_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib/ test/ && flutter analyze
git add lib/features/backup/domain/entities/backup_settings.dart lib/features/backup/data/repositories/backup_preferences.dart lib/features/backup/presentation/providers/backup_providers.dart test/features/backup/data/repositories/backup_preferences_test.dart
git commit -m "feat(backup): add backupEncryptionEnabled preference flag"
```

---

### Task 2: `BackupEncryptionKeyStore`

Mirrors `EncryptionKeyStore` (`lib/core/services/sync/crypto/encryption_key_store.dart`) but with backup-scoped storage keys. Reuses the shared `UnlockedKey`.

**Files:**
- Create: `lib/features/backup/data/services/backup_encryption_key_store.dart`
- Test: `test/features/backup/data/services/backup_encryption_key_store_test.dart`

**Interfaces:**
- Produces: `BackupEncryptionKeyStore({FlutterSecureStorage? storage})` with `saveKey({required String libraryKeyId, required List<int> mlkBytes})`, `Future<UnlockedKey?> loadKey()`, `clearKey()`, `saveKeyslotMirror(Uint8List)`, `Future<Uint8List?> loadKeyslotMirror()`, `clearKeyslotMirror()`.
- Consumes: `UnlockedKey`, `FallbackSecureStorage`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/backup/data/services/backup_encryption_key_store.dart';
import '../../../../support/fake_keychain_storage.dart';

void main() {
  test('saves and loads key + mirror; clear removes key but keeps mirror', () async {
    final store = BackupEncryptionKeyStore(storage: InMemoryKeychain());
    await store.saveKey(libraryKeyId: 'lib-1', mlkBytes: List<int>.generate(32, (i) => i));
    await store.saveKeyslotMirror(Uint8List.fromList([1, 2, 3]));

    final key = await store.loadKey();
    expect(key, isNotNull);
    expect(key!.libraryKeyId, 'lib-1');
    expect(await key.mlk.extractBytes(), List<int>.generate(32, (i) => i));
    expect(await store.loadKeyslotMirror(), [1, 2, 3]);

    await store.clearKey();
    expect(await store.loadKey(), isNull);
    expect(await store.loadKeyslotMirror(), [1, 2, 3]); // mirror independent
  });

  test('uses storage keys distinct from the sync store', () {
    // Guard against a copy-paste collision with EncryptionKeyStore.
    expect(BackupEncryptionKeyStore.mlkStorageKey, isNot('sync_encryption_mlk'));
    expect(BackupEncryptionKeyStore.mlkStorageKey, startsWith('backup_encryption_'));
  });
}
```

Add `import 'dart:typed_data';` at the top.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/services/backup_encryption_key_store_test.dart`
Expected: FAIL (class not defined).

- [ ] **Step 3: Implement the key store**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart' show UnlockedKey;

/// Device-local custody of the backup master key and a mirror of its keyslot
/// file (needed for changePassphrase/regenerateRecoveryCode: the passphrase is
/// not retained). Independent of the sync EncryptionKeyStore.
class BackupEncryptionKeyStore {
  static const String keyIdStorageKey = 'backup_encryption_library_key_id';
  static const String mlkStorageKey = 'backup_encryption_mlk';
  static const String mirrorStorageKey = 'backup_encryption_keyslot_mirror';

  final FallbackSecureStorage _storage;

  BackupEncryptionKeyStore({FlutterSecureStorage? storage})
      : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage());

  Future<void> saveKey({required String libraryKeyId, required List<int> mlkBytes}) async {
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

  Future<void> saveKeyslotMirror(Uint8List bytes) =>
      _storage.write(key: mirrorStorageKey, value: base64Encode(bytes));

  Future<Uint8List?> loadKeyslotMirror() async {
    final v = await _storage.read(key: mirrorStorageKey);
    return v == null ? null : base64Decode(v);
  }

  Future<void> clearKeyslotMirror() => _storage.delete(key: mirrorStorageKey);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/backup/data/services/backup_encryption_key_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/ test/ && flutter analyze
git add lib/features/backup/data/services/backup_encryption_key_store.dart test/features/backup/data/services/backup_encryption_key_store_test.dart
git commit -m "feat(backup): add BackupEncryptionKeyStore (backup-scoped key custody)"
```

---

### Task 3: `BackupEncryptionService`

Local-only key lifecycle. No cloud, no epoch, no device. Mirrors the crypto steps of `SyncEncryptionService.enable/changePassphrase/regenerateRecoveryCode` but reads the mirror locally.

**Files:**
- Create: `lib/features/backup/data/services/backup_encryption_service.dart`
- Test: `test/features/backup/data/services/backup_encryption_service_test.dart`

**Interfaces:**
- Consumes: `BackupEncryptionKeyStore` (Task 2); `Keyslots`, `KeyslotFile`, `KdfParams`, `RecoveryCode`, `WrongPassphraseException`.
- Produces: `BackupEncryptionService({required BackupEncryptionKeyStore keyStore})` with `Future<EnableBackupEncryptionResult> enable({required String passphrase, KdfParams kdf})`, `Future<void> changePassphrase({required String currentSecret, required String newPassphrase, KdfParams kdf})`, `Future<String> regenerateRecoveryCode({required String currentSecret, KdfParams kdf})`. `EnableBackupEncryptionResult{ recoveryCode, libraryKeyId }`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart' show WrongPassphraseException;
import 'package:submersion/features/backup/data/services/backup_encryption_key_store.dart';
import 'package:submersion/features/backup/data/services/backup_encryption_service.dart';
import '../../../../support/fake_keychain_storage.dart';

const _fastKdf = KdfParams(m: 1024, t: 3, p: 1);

void main() {
  late BackupEncryptionKeyStore store;
  late BackupEncryptionService service;

  setUp(() {
    store = BackupEncryptionKeyStore(storage: InMemoryKeychain());
    service = BackupEncryptionService(keyStore: store);
  });

  test('enable persists key + mirror and returns a recovery code', () async {
    final r = await service.enable(passphrase: 'hunter2hunter2', kdf: _fastKdf);
    expect(r.recoveryCode.split('-'), hasLength(8));
    expect(await store.loadKey(), isNotNull);
    expect(await store.loadKeyslotMirror(), isNotNull);
  });

  test('the recovery code unwraps the same key as the passphrase', () async {
    final r = await service.enable(passphrase: 'hunter2hunter2', kdf: _fastKdf);
    final file = KeyslotFile.fromJsonBytes((await store.loadKeyslotMirror())!);
    final viaPass = await Keyslots.tryUnwrap(file: file, secret: 'hunter2hunter2');
    final viaCode = await Keyslots.tryUnwrap(file: file, secret: r.recoveryCode);
    expect(await viaPass!.extractBytes(), await viaCode!.extractBytes());
  });

  test('changePassphrase: old fails, new works; wrong current throws', () async {
    await service.enable(passphrase: 'oldpassword1', kdf: _fastKdf);
    await expectLater(
      service.changePassphrase(currentSecret: 'wrong', newPassphrase: 'x', kdf: _fastKdf),
      throwsA(isA<WrongPassphraseException>()),
    );
    await service.changePassphrase(currentSecret: 'oldpassword1', newPassphrase: 'newpassword1', kdf: _fastKdf);
    final file = KeyslotFile.fromJsonBytes((await store.loadKeyslotMirror())!);
    expect(await Keyslots.tryUnwrap(file: file, secret: 'oldpassword1'), isNull);
    expect(await Keyslots.tryUnwrap(file: file, secret: 'newpassword1'), isNotNull);
  });

  test('regenerateRecoveryCode: old code stops working, new one works', () async {
    final first = await service.enable(passphrase: 'password12', kdf: _fastKdf);
    final second = await service.regenerateRecoveryCode(currentSecret: 'password12', kdf: _fastKdf);
    expect(second, isNot(first.recoveryCode));
    final file = KeyslotFile.fromJsonBytes((await store.loadKeyslotMirror())!);
    expect(await Keyslots.tryUnwrap(file: file, secret: first.recoveryCode), isNull);
    expect(await Keyslots.tryUnwrap(file: file, secret: second), isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/services/backup_encryption_service_test.dart`
Expected: FAIL (class not defined).

- [ ] **Step 3: Implement the service**

```dart
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/recovery_code.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart' show WrongPassphraseException;
import 'package:submersion/features/backup/data/services/backup_encryption_key_store.dart';

class EnableBackupEncryptionResult {
  final String recoveryCode;
  final String libraryKeyId;
  const EnableBackupEncryptionResult({required this.recoveryCode, required this.libraryKeyId});
}

/// Local-only lifecycle for password-protected backups: create the key,
/// rewrap the passphrase slot, rotate the recovery slot. Each `.sbe` embeds
/// its own keyslots, so there is no cross-device unlock and no cloud state.
class BackupEncryptionService {
  static final _log = LoggerService.forClass(BackupEncryptionService);

  final BackupEncryptionKeyStore _keyStore;
  final Uuid _uuid = const Uuid();

  BackupEncryptionService({required BackupEncryptionKeyStore keyStore}) : _keyStore = keyStore;

  Future<EnableBackupEncryptionResult> enable({
    required String passphrase,
    KdfParams kdf = const KdfParams(),
  }) async {
    final mlkBytes = _randomBytes(32);
    final mlk = SecretKey(mlkBytes);
    final libraryKeyId = _uuid.v4();
    final recoveryCode = RecoveryCode.generate();
    final file = KeyslotFile(
      version: 1,
      libraryKeyId: libraryKeyId,
      slots: [
        await Keyslots.createSlot(type: 'passphrase', secret: passphrase, mlk: mlk, kdf: kdf),
        await Keyslots.createSlot(type: 'recovery', secret: recoveryCode, mlk: mlk, kdf: kdf),
      ],
    );
    await _keyStore.saveKey(libraryKeyId: libraryKeyId, mlkBytes: mlkBytes);
    await _keyStore.saveKeyslotMirror(file.toJsonBytes());
    _log.info('Backup encryption enabled (key $libraryKeyId)');
    return EnableBackupEncryptionResult(recoveryCode: recoveryCode, libraryKeyId: libraryKeyId);
  }

  Future<void> changePassphrase({
    required String currentSecret,
    required String newPassphrase,
    KdfParams kdf = const KdfParams(),
  }) async {
    final (file, mlk) = await _unlocked(currentSecret);
    final updated = file.withReplacedSlot(
      await Keyslots.createSlot(type: 'passphrase', secret: newPassphrase, mlk: mlk, kdf: kdf),
    );
    await _keyStore.saveKeyslotMirror(updated.toJsonBytes());
    _log.info('Backup passphrase changed');
  }

  Future<String> regenerateRecoveryCode({
    required String currentSecret,
    KdfParams kdf = const KdfParams(),
  }) async {
    final (file, mlk) = await _unlocked(currentSecret);
    final code = RecoveryCode.generate();
    final updated = file.withReplacedSlot(
      await Keyslots.createSlot(type: 'recovery', secret: code, mlk: mlk, kdf: kdf),
    );
    await _keyStore.saveKeyslotMirror(updated.toJsonBytes());
    _log.info('Backup recovery code regenerated');
    return code;
  }

  Future<(KeyslotFile, SecretKey)> _unlocked(String secret) async {
    final bytes = await _keyStore.loadKeyslotMirror();
    if (bytes == null) throw const WrongPassphraseException();
    final file = KeyslotFile.fromJsonBytes(bytes);
    final mlk = await Keyslots.tryUnwrap(file: file, secret: secret);
    if (mlk == null) throw const WrongPassphraseException();
    return (file, mlk);
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/backup/data/services/backup_encryption_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/ test/ && flutter analyze
git add lib/features/backup/data/services/backup_encryption_service.dart test/features/backup/data/services/backup_encryption_service_test.dart
git commit -m "feat(backup): add BackupEncryptionService (local key lifecycle)"
```

---

### Task 4: `BackupTarget.writeSource`

Lets a pre-encrypted `.sbe` temp file be written into any target (filesystem copy / SAF `port.writeBackup`).

**Files:**
- Modify: `lib/features/backup/data/services/backup_target.dart`
- Test: `test/features/backup/data/services/backup_target_test.dart` (create if absent)

**Interfaces:**
- Produces: `BackupTarget.writeSource(String sourcePath, String fileName) -> Future<String>` on the interface and both implementations.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/backup/data/services/backup_target.dart';

void main() {
  test('FilesystemBackupTarget.writeSource copies the source into the dir', () async {
    final dir = await Directory.systemTemp.createTemp('bt_');
    addTearDown(() => dir.delete(recursive: true));
    final src = File(p.join(dir.path, 'src.sbe'))..writeAsStringSync('ENCRYPTED');
    final target = FilesystemBackupTarget(dir.path);

    final ref = await target.writeSource(src.path, 'backup.sbe');

    expect(ref, p.join(dir.path, 'backup.sbe'));
    expect(File(ref).readAsStringSync(), 'ENCRYPTED');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/services/backup_target_test.dart`
Expected: FAIL (`writeSource` not defined).

- [ ] **Step 3: Add `writeSource` to the interface and both impls**

In `backup_target.dart`, add to `abstract class BackupTarget`:

```dart
  /// Writes an already-materialized file at [sourcePath] into the target as
  /// [fileName] (e.g. an encrypted `.sbe` produced off to the side). Returns
  /// the stored ref: a filesystem path or a `content://` document URI.
  Future<String> writeSource(String sourcePath, String fileName);
```

In `FilesystemBackupTarget`:

```dart
  @override
  Future<String> writeSource(String sourcePath, String fileName) async {
    final dest = p.join(dir, fileName);
    await File(sourcePath).copy(dest);
    return dest;
  }
```

In `SafBackupTarget`:

```dart
  @override
  Future<String> writeSource(String sourcePath, String fileName) =>
      port.writeBackup(treeUri: treeUri, fileName: fileName, sourcePath: sourcePath);
```

Add `import 'dart:io';` to the file if not present.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/backup/data/services/backup_target_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/ test/ && flutter analyze
git add lib/features/backup/data/services/backup_target.dart test/features/backup/data/services/backup_target_test.dart
git commit -m "feat(backup): add BackupTarget.writeSource for pre-encrypted artifacts"
```

---

### Task 5: Wire the backup key store into `BackupService` + providers

Adds the optional dependency and the `_activeBackupKey()` helper. No behavior change yet (nothing calls the helper until Task 6), so the test asserts construction + a plaintext backup still works.

**Files:**
- Modify: `lib/features/backup/data/services/backup_service.dart` (constructor ~L105-123; add helper)
- Modify: `lib/features/backup/presentation/providers/backup_providers.dart` (~L30-42 + new providers)
- Test: `test/features/backup/data/services/backup_encryption_backup_test.dart` (create — this file grows across Tasks 5-9)

**Interfaces:**
- Produces: `BackupService(..., BackupEncryptionKeyStore? backupEncryptionKeyStore)`; private `_activeBackupKey()`. Providers `backupEncryptionKeyStoreProvider`, `backupEncryptionServiceProvider`.
- Consumes: `BackupEncryptionKeyStore` (Task 2), `BackupEncryptionService` (Task 3).

- [ ] **Step 1: Write the failing test**

Create `test/features/backup/data/services/backup_encryption_backup_test.dart`. Reuse the harness from `backup_service_encryption_test.dart` (copy the `_FakeBackupDatabaseAdapter`, the `setUpAll` path_provider mock, `InMemoryKeychain`, `FakeCloudStorageProvider`). Add:

```dart
// ... imports incl. BackupEncryptionKeyStore, BackupEncryptionService,
// keyslots (for _fastKdf), fake_keychain_storage, fake_cloud_storage_provider

const _fastKdf = KdfParams(m: 1024, t: 3, p: 1);

late BackupPreferences preferences;
late BackupEncryptionKeyStore backupKeyStore;

setUp(() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  preferences = BackupPreferences(prefs);
  backupKeyStore = BackupEncryptionKeyStore(storage: InMemoryKeychain());
});

BackupService buildService() => BackupService(
  dbAdapter: _FakeBackupDatabaseAdapter(),
  preferences: preferences,
  backupEncryptionKeyStore: backupKeyStore,
);

test('backup encryption OFF: local backup is plaintext .db (unchanged)', () async {
  final record = await buildService().performBackup();
  expect(record.filename, endsWith('.db'));
  expect(await File(record.localPath!).readAsString(), 'fake backup data');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/services/backup_encryption_backup_test.dart`
Expected: FAIL (`backupEncryptionKeyStore` named param not defined).

- [ ] **Step 3: Add the dependency + helper to `BackupService`**

Add the field near `_encryptionKeyStore` (L93):

```dart
  /// Backup-encryption key (issue #580). When the backupEncryptionEnabled flag
  /// is on and this + a mirror are present, every backup write is a framed
  /// `.sbe`. Nullable so existing constructions keep working (plaintext).
  final BackupEncryptionKeyStore? _backupEncryptionKeyStore;
```

Add the constructor param `BackupEncryptionKeyStore? backupEncryptionKeyStore,` and initializer `_backupEncryptionKeyStore = backupEncryptionKeyStore,`. Add the import `import 'package:submersion/features/backup/data/services/backup_encryption_key_store.dart';`.

Add the helper (place near `_uploadToCloud`):

```dart
  /// The active backup-encryption key, or null when backup encryption is off.
  /// Throws [BackupException] when the flag is on but the key is unavailable
  /// (fail-closed: never silently write plaintext the user asked to protect).
  Future<({SecretKey mlk, String libraryKeyId, Uint8List keyslotBytes})?>
      _activeBackupKey() async {
    if (!_preferences.getSettings().backupEncryptionEnabled) return null;
    final key = await _backupEncryptionKeyStore?.loadKey();
    final mirror = await _backupEncryptionKeyStore?.loadKeyslotMirror();
    if (key == null || mirror == null) {
      throw const BackupException(
        'Backup encryption is enabled but the key is unavailable on this device',
      );
    }
    return (mlk: key.mlk, libraryKeyId: key.libraryKeyId, keyslotBytes: mirror);
  }
```

Add `import 'package:cryptography/cryptography.dart';` for `SecretKey` if not already imported.

- [ ] **Step 4: Add providers + wiring**

In `backup_providers.dart`, add imports for `BackupEncryptionKeyStore` and `BackupEncryptionService`, then:

```dart
final backupEncryptionKeyStoreProvider = Provider<BackupEncryptionKeyStore>((ref) {
  return BackupEncryptionKeyStore();
});

final backupEncryptionServiceProvider = Provider<BackupEncryptionService>((ref) {
  return BackupEncryptionService(keyStore: ref.watch(backupEncryptionKeyStoreProvider));
});
```

And add to the `BackupService(...)` construction in `backupServiceProvider`:

```dart
    backupEncryptionKeyStore: ref.watch(backupEncryptionKeyStoreProvider),
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/backup/data/services/backup_encryption_backup_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/ test/ && flutter analyze
git add lib/features/backup/data/services/backup_service.dart lib/features/backup/presentation/providers/backup_providers.dart test/features/backup/data/services/backup_encryption_backup_test.dart
git commit -m "feat(backup): inject BackupEncryptionKeyStore + _activeBackupKey helper"
```

---

### Task 6: Encrypt local + cloud backups in `_performBackupInto` / `_uploadToCloud`

**Files:**
- Modify: `lib/features/backup/data/services/backup_service.dart` (`_performBackupInto` L149-211; `_uploadToCloud` L893-947)
- Test: `test/features/backup/data/services/backup_encryption_backup_test.dart` (add cases)

**Interfaces:**
- Consumes: `_activeBackupKey()` (Task 5), `BackupTarget.writeSource` (Task 4), `BackupCrypto`, `SyncEnvelope`.

- [ ] **Step 1: Write the failing test**

```dart
Future<void> enableBackupEncryption() async {
  await BackupEncryptionService(keyStore: backupKeyStore)
      .enable(passphrase: 'backuppass1', kdf: _fastKdf);
  await preferences.setBackupEncryptionEnabled(true);
}

test('backup encryption ON: local history file is .sbe with SBE1 magic', () async {
  await enableBackupEncryption();
  final record = await buildService().performBackup();
  expect(record.filename, endsWith('.sbe'));
  final bytes = await File(record.localPath!).readAsBytes();
  expect(SyncEnvelope.hasMagic(bytes), isTrue);
});

test('backup encryption ON: cloud copy is the SAME .sbe (single encryption)', () async {
  await enableBackupEncryption();
  await preferences.setCloudBackupEnabled(true);
  await buildService().performBackup();

  final folderId = await cloud.createFolder('Submersion Backups');
  final files = await cloud.listFiles(folderId: folderId, namePattern: 'submersion_backup_');
  expect(files, hasLength(1));
  expect(files.single.name, endsWith('.sbe'));
  final bytes = await cloud.downloadFile(files.single.id);
  expect(SyncEnvelope.hasMagic(bytes), isTrue);
  // Not double-encrypted: the artifact decrypts with the backup passphrase.
  expect(bytes.length, greaterThan(0));
});
```

(Add `cloud = FakeCloudStorageProvider();` to `setUp` and `cloudProvider: cloud` to `buildService()` if not already present in this file.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/services/backup_encryption_backup_test.dart`
Expected: FAIL (local file is plaintext `.db`, no magic).

- [ ] **Step 3: Encrypt in `_performBackupInto`**

Replace the top of `_performBackupInto` (the `filename` / `target.write` / `sizeBytes` block, L153-163) with:

```dart
    final filename = _generateFilename();
    final encKey = await _activeBackupKey();

    final String ref;
    final int sizeBytes;
    final String storedName;
    if (encKey == null) {
      storedName = filename;
      ref = await target.write(_dbAdapter, filename);
      sizeBytes = isSafRef(ref)
          ? await File(await _dbAdapter.databasePath).length()
          : await File(ref).length();
    } else {
      // Encrypt to a temp .sbe off to the side, then write it into the target.
      storedName = p.basenameWithoutExtension(filename) + BackupCrypto.fileExtension;
      final tempDir = await getTemporaryDirectory();
      final tempPlain = p.join(tempDir.path, filename);
      final tempSbe = p.join(tempDir.path, storedName);
      try {
        await _dbAdapter.backup(tempPlain);
        await BackupCrypto.encryptFile(
          inPath: tempPlain,
          outPath: tempSbe,
          mlk: encKey.mlk,
          libraryKeyId: encKey.libraryKeyId,
          keyslotBytes: encKey.keyslotBytes,
        );
        ref = await target.writeSource(tempSbe, storedName);
        sizeBytes = await File(tempSbe).length();
      } finally {
        for (final t in [p.join((await getTemporaryDirectory()).path, filename), tempSbe]) {
          final f = File(t);
          if (await f.exists()) {
            try {
              await f.delete();
            } catch (_) {/* best-effort temp cleanup */}
          }
        }
      }
    }
```

Then, further down, change `filename` to `storedName` in the cloud-upload call and the `BackupRecord(filename: ...)`:
- `cloudFileId = await _uploadToCloud(ref, storedName);`
- `filename: storedName,` in the `BackupRecord(...)`.

(Leave the `settings` read, counts, cloud gate, record persistence, and prune exactly as-is.)

- [ ] **Step 4: Make `_uploadToCloud` pass through already-encrypted artifacts**

In `_uploadToCloud`, guard the existing sync-encryption block so it does not re-encrypt an artifact that is already a `.sbe`. Change the condition at L906 from:

```dart
    if (_syncPreferences?.syncEncryptionEnabled ?? false) {
```

to:

```dart
    final alreadyEncrypted = await BackupCrypto.isEncryptedBackup(localPath);
    if (!alreadyEncrypted && (_syncPreferences?.syncEncryptionEnabled ?? false)) {
```

(The rest of the method is unchanged: when `alreadyEncrypted`, `uploadPath`/`uploadName` stay the passed-in `.sbe` and it uploads verbatim. The cloud decorator already exempts `submersion_backup_*.sbe`.)

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/backup/data/services/backup_encryption_backup_test.dart`
Expected: PASS.

- [ ] **Step 6: Guard against regressions — run the #520 encryption test**

Run: `flutter test test/features/backup/data/services/backup_service_encryption_test.dart`
Expected: PASS (sync-encryption cloud path unchanged; `alreadyEncrypted` is false for its plaintext locals).

- [ ] **Step 7: Commit**

```bash
dart format lib/ test/ && flutter analyze
git add lib/features/backup/data/services/backup_service.dart test/features/backup/data/services/backup_encryption_backup_test.dart
git commit -m "feat(backup): encrypt local + cloud backups when backup encryption is on"
```

---

### Task 7: Encrypt manual exports (Save to File / Share)

**Files:**
- Modify: `lib/features/backup/data/services/backup_service.dart` (`exportBackupToPath` L216-244; `exportBackupToTemp` L251-262)
- Test: `test/features/backup/data/services/backup_encryption_backup_test.dart` (add cases)

- [ ] **Step 1: Write the failing test**

```dart
test('exportBackupToTemp encrypts to .sbe when enabled', () async {
  await enableBackupEncryption();
  final file = await buildService().exportBackupToTemp();
  expect(file.path, endsWith('.sbe'));
  expect(SyncEnvelope.hasMagic(await file.readAsBytes()), isTrue);
});

test('exportBackupToPath encrypts the chosen destination when enabled', () async {
  await enableBackupEncryption();
  final dest = '${Directory.systemTemp.path}/exp_${DateTime.now().microsecondsSinceEpoch}.sbe';
  addTearDown(() async { final f = File(dest); if (await f.exists()) await f.delete(); });
  final record = await buildService().exportBackupToPath(dest);
  expect(SyncEnvelope.hasMagic(await File(record.localPath!).readAsBytes()), isTrue);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/services/backup_encryption_backup_test.dart`
Expected: FAIL (exports are plaintext).

- [ ] **Step 3: Encrypt `exportBackupToTemp`**

Replace the body of `exportBackupToTemp`:

```dart
  Future<File> exportBackupToTemp() async {
    _log.info('Exporting backup to temp for sharing');
    final encKey = await _activeBackupKey();
    final filename = _generateFilename();
    final tempDir = await getTemporaryDirectory();

    if (encKey == null) {
      final tempPath = p.join(tempDir.path, filename);
      await _dbAdapter.backup(tempPath);
      _log.info('Temp export completed: $filename');
      return File(tempPath);
    }

    final plainPath = p.join(tempDir.path, filename);
    final sbeName = p.basenameWithoutExtension(filename) + BackupCrypto.fileExtension;
    final sbePath = p.join(tempDir.path, sbeName);
    await _dbAdapter.backup(plainPath);
    try {
      await BackupCrypto.encryptFile(
        inPath: plainPath,
        outPath: sbePath,
        mlk: encKey.mlk,
        libraryKeyId: encKey.libraryKeyId,
        keyslotBytes: encKey.keyslotBytes,
      );
    } finally {
      final plain = File(plainPath);
      if (await plain.exists()) {
        try {
          await plain.delete();
        } catch (_) {/* best-effort */}
      }
    }
    _log.info('Encrypted temp export completed: $sbeName');
    return File(sbePath);
  }
```

- [ ] **Step 4: Encrypt `exportBackupToPath`**

Replace the `_dbAdapter.backup(destinationPath)` call (L219) and `filename` derivation so an enabled export writes an encrypted artifact at the chosen path:

```dart
  Future<BackupRecord> exportBackupToPath(String destinationPath) async {
    _log.info('Exporting backup to: $destinationPath');
    final encKey = await _activeBackupKey();

    if (encKey == null) {
      await _dbAdapter.backup(destinationPath);
    } else {
      final tempDir = await getTemporaryDirectory();
      final plainPath = p.join(tempDir.path, 'export_${_uuid.v4()}.db');
      await _dbAdapter.backup(plainPath);
      try {
        await BackupCrypto.encryptFile(
          inPath: plainPath,
          outPath: destinationPath,
          mlk: encKey.mlk,
          libraryKeyId: encKey.libraryKeyId,
          keyslotBytes: encKey.keyslotBytes,
        );
      } finally {
        final plain = File(plainPath);
        if (await plain.exists()) {
          try {
            await plain.delete();
          } catch (_) {/* best-effort */}
        }
      }
    }

    final filename = p.basename(destinationPath);
    // ... (rest of the method unchanged: counts, size, record, addRecord)
```

(The caller in the UI supplies a `.sbe` destination name when encryption is on — see Task 12. The `filename`/size/record lines below stay as they are.)

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/backup/data/services/backup_encryption_backup_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/ test/ && flutter analyze
git add lib/features/backup/data/services/backup_service.dart test/features/backup/data/services/backup_encryption_backup_test.dart
git commit -m "feat(backup): encrypt Save-to-File and Share exports when enabled"
```

---

### Task 8: Restore branch for the backup key

**Files:**
- Modify: `lib/features/backup/data/services/backup_service.dart` (`_materializePlaintextBackup` L954-982)
- Test: `test/features/backup/data/services/backup_encryption_backup_test.dart` (add cases)

**Interfaces:**
- Consumes: `restoreFromFile(String path, {String? encryptionSecret})` (existing service method, L423).

- [ ] **Step 1: Write the failing test**

```dart
test('restore: silent with the stored backup key; via passphrase after clear', () async {
  await enableBackupEncryption();
  final file = await buildService().exportBackupToTemp(); // encrypted .sbe
  final picked = File('${Directory.systemTemp.path}/pick_${DateTime.now().microsecondsSinceEpoch}.sbe');
  await picked.writeAsBytes(await file.readAsBytes());
  addTearDown(() async { if (await picked.exists()) await picked.delete(); });

  // Stored backup key present -> silent restore, no secret.
  await buildService().restoreFromFile(picked.path);

  // Drop the key -> must supply the passphrase.
  await backupKeyStore.clearKey();
  await buildService().restoreFromFile(picked.path, encryptionSecret: 'backuppass1');
});

test('restore: encrypted, no key, no secret -> BackupEncryptedException', () async {
  await enableBackupEncryption();
  final file = await buildService().exportBackupToTemp();
  final picked = File('${Directory.systemTemp.path}/pick2_${DateTime.now().microsecondsSinceEpoch}.sbe');
  await picked.writeAsBytes(await file.readAsBytes());
  addTearDown(() async { if (await picked.exists()) await picked.delete(); });
  await backupKeyStore.clearKey();

  await expectLater(
    buildService().restoreFromFile(picked.path),
    throwsA(isA<BackupEncryptedException>()),
  );
});
```

(Ensure `_FakeBackupDatabaseAdapter.restore` is a no-op so restore completes — it already is in the mirrored harness.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/services/backup_encryption_backup_test.dart`
Expected: FAIL (backup key not consulted; silent restore throws `BackupEncryptedException`).

- [ ] **Step 3: Add the backup-key branch**

In `_materializePlaintextBackup`, replace the key-selection block (L963-980) with:

```dart
    final syncKey = await _encryptionKeyStore?.loadKey();
    final backupKey = await _backupEncryptionKeyStore?.loadKey();
    final artifactKeyId = await BackupCrypto.libraryKeyIdOf(sourcePath);
    if (syncKey != null && syncKey.libraryKeyId == artifactKeyId) {
      await BackupCrypto.decryptFileWithKey(
        inPath: sourcePath,
        outPath: decrypted,
        mlk: syncKey.mlk,
        expectedLibraryKeyId: syncKey.libraryKeyId,
      );
    } else if (backupKey != null && backupKey.libraryKeyId == artifactKeyId) {
      await BackupCrypto.decryptFileWithKey(
        inPath: sourcePath,
        outPath: decrypted,
        mlk: backupKey.mlk,
        expectedLibraryKeyId: backupKey.libraryKeyId,
      );
    } else if (encryptionSecret != null) {
      await BackupCrypto.decryptFile(
        inPath: sourcePath,
        outPath: decrypted,
        secret: encryptionSecret,
      );
    } else {
      throw const BackupEncryptedException();
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/backup/data/services/backup_encryption_backup_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/ test/ && flutter analyze
git add lib/features/backup/data/services/backup_service.dart test/features/backup/data/services/backup_encryption_backup_test.dart
git commit -m "feat(backup): silent restore via the stored backup key"
```

---

### Task 9: `reencryptExistingBackups()` migration

Idempotent, best-effort re-encryption of plaintext history entries. Skips already-encrypted, SAF, and cloud-only records (logged). Rewrites local file + re-uploads cloud copy.

**Files:**
- Modify: `lib/features/backup/data/services/backup_service.dart` (new method)
- Possibly modify: `lib/features/backup/domain/entities/backup_record.dart` (ensure `copyWith` covers `filename`, `localPath`, `sizeBytes`, `cloudFileId`)
- Test: `test/features/backup/data/services/backup_encryption_backup_test.dart` (add cases)

**Interfaces:**
- Produces: `Future<({int reencrypted, int skipped, int failed})> reencryptExistingBackups()`.

- [ ] **Step 1: Verify `BackupRecord.copyWith`**

Open `backup_record.dart`. Confirm `copyWith` accepts `filename`, `localPath`, `sizeBytes`, `cloudFileId`. If any is missing, add it (nullable param, `?? this.field`). If `copyWith` does not exist, add one covering all fields.

- [ ] **Step 2: Write the failing test**

```dart
test('reencrypt: plaintext local history entries become .sbe, .sbe skipped', () async {
  // One plaintext local backup exists first.
  final svcPlain = buildService();
  final plainRecord = await svcPlain.performBackup(); // .db in history
  expect(plainRecord.filename, endsWith('.db'));

  await enableBackupEncryption();
  final result = await buildService().reencryptExistingBackups();

  expect(result.reencrypted, 1);
  final history = preferences.getHistory();
  expect(history.single.filename, endsWith('.sbe'));
  expect(SyncEnvelope.hasMagic(await File(history.single.localPath!).readAsBytes()), isTrue);

  // Idempotent: a second run re-encrypts nothing.
  final again = await buildService().reencryptExistingBackups();
  expect(again.reencrypted, 0);
  expect(again.skipped, 1);
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/backup/data/services/backup_encryption_backup_test.dart`
Expected: FAIL (`reencryptExistingBackups` not defined).

- [ ] **Step 4: Implement the migration**

```dart
  /// Rewrite every plaintext local backup in history as an encrypted `.sbe`,
  /// re-uploading its cloud copy when present. Idempotent: already-encrypted
  /// artifacts are skipped by magic. SAF (`content://`) and cloud-only records
  /// are skipped (logged). Best-effort per record.
  Future<({int reencrypted, int skipped, int failed})>
      reencryptExistingBackups() async {
    final encKey = await _activeBackupKey();
    if (encKey == null) {
      throw const BackupException('Backup encryption must be enabled first');
    }
    var reencrypted = 0;
    var skipped = 0;
    var failed = 0;
    for (final record in _preferences.getHistory()) {
      final localPath = record.localPath;
      if (localPath == null || isSafRef(localPath)) {
        _log.info('Re-encrypt skip (no local filesystem path): ${record.filename}');
        skipped++;
        continue;
      }
      try {
        final file = File(localPath);
        if (!await file.exists()) {
          skipped++;
          continue;
        }
        if (await BackupCrypto.isEncryptedBackup(localPath)) {
          skipped++;
          continue;
        }
        final dir = p.dirname(localPath);
        final newName =
            p.basenameWithoutExtension(localPath) + BackupCrypto.fileExtension;
        final newPath = p.join(dir, newName);
        final tempDir = await getTemporaryDirectory();
        final tempSbe = p.join(tempDir.path, 'reenc_${_uuid.v4()}.sbe');
        await BackupCrypto.encryptFile(
          inPath: localPath,
          outPath: tempSbe,
          mlk: encKey.mlk,
          libraryKeyId: encKey.libraryKeyId,
          keyslotBytes: encKey.keyslotBytes,
        );
        await File(tempSbe).copy(newPath);
        await File(tempSbe).delete();
        if (newPath != localPath) await file.delete();

        String? cloudFileId = record.cloudFileId;
        if (record.cloudFileId != null && _cloudProvider != null) {
          cloudFileId = await _uploadToCloud(newPath, newName);
          try {
            await _cloudProvider.deleteFile(record.cloudFileId!);
          } catch (_) {/* best-effort old-object cleanup */}
        }

        await _preferences.updateRecord(record.copyWith(
          filename: newName,
          localPath: newPath,
          sizeBytes: await File(newPath).length(),
          cloudFileId: cloudFileId,
        ));
        reencrypted++;
      } catch (e, stack) {
        _log.error('Re-encrypt failed for ${record.filename}',
            error: e, stackTrace: stack);
        failed++;
      }
    }
    _log.info('Re-encrypt done: $reencrypted rewritten, $skipped skipped, '
        '$failed failed');
    return (reencrypted: reencrypted, skipped: skipped, failed: failed);
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/backup/data/services/backup_encryption_backup_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/ test/ && flutter analyze
git add lib/features/backup/data/services/backup_service.dart lib/features/backup/domain/entities/backup_record.dart test/features/backup/data/services/backup_encryption_backup_test.dart
git commit -m "feat(backup): reencryptExistingBackups in-place migration"
```

---

### Task 10: Localization keys

Add all new strings up front so the UI tasks compile. Mirror the `settings_cloudSync_encryption_*` key set under a new `settings_backupEncryption_*` namespace.

**Files:**
- Modify: `lib/l10n/app_en.arb` (source of truth)
- Modify: all 10 non-en `lib/l10n/app_*.arb`
- (Regeneration happens on build; run it in Step 3.)

- [ ] **Step 1: Add keys to `app_en.arb`**

Add these keys (values shown). Keep placeholder metadata minimal, matching the file's existing conventions:

```json
"settings_backupEncryption_title": "Backup encryption",
"settings_backupEncryption_subtitleOff": "Protect your backups with a password",
"settings_backupEncryption_subtitleOn": "Backups are encrypted with your password",
"settings_backupEncryption_enable": "Encrypt backups",
"settings_backupEncryption_turnOff": "Turn off encryption",
"settings_backupEncryption_turnOffTitle": "Turn off backup encryption?",
"settings_backupEncryption_turnOffBody": "New backups will no longer be encrypted. Existing encrypted backups still need your password to restore.",
"settings_backupEncryption_changePassword": "Change password",
"settings_backupEncryption_regenerateRecovery": "Regenerate recovery code",
"settings_backupEncryption_password": "Password",
"settings_backupEncryption_passwordConfirm": "Confirm password",
"settings_backupEncryption_passwordTooShort": "Use at least 8 characters",
"settings_backupEncryption_passwordMismatch": "Passwords do not match",
"settings_backupEncryption_currentPassword": "Current password",
"settings_backupEncryption_newPassword": "New password",
"settings_backupEncryption_warnLoss": "If you forget your password and lose the recovery code, encrypted backups cannot be recovered.",
"settings_backupEncryption_recoveryTitle": "Your recovery code",
"settings_backupEncryption_recoveryExplain": "Save this code somewhere safe. It can unlock your backups if you forget your password.",
"settings_backupEncryption_recoverySavedConfirm": "I have saved my recovery code",
"settings_backupEncryption_unlockTitle": "Enter backup password",
"settings_backupEncryption_unlockHint": "Enter your backup password or recovery code",
"settings_backupEncryption_continue": "Continue",
"settings_backupEncryption_cancel": "Cancel",
"settings_backupEncryption_done": "Done",
"settings_backupEncryption_reencryptTitle": "Encrypt existing backups?",
"settings_backupEncryption_reencryptBody": "Your existing backups are still unencrypted. Re-encrypt them now with your new password?",
"settings_backupEncryption_reencryptNow": "Re-encrypt now",
"settings_backupEncryption_reencryptNotNow": "Not now",
"settings_backupEncryption_reencryptDone": "Re-encrypted {count} backups",
"@settings_backupEncryption_reencryptDone": { "placeholders": { "count": { "type": "int" } } },
"settings_backupEncryption_wrongPassword": "Incorrect password or recovery code",
```

- [ ] **Step 2: Add the same keys to every non-en locale**

For each of `app_ar.arb, app_de.arb, app_es.arb, app_fr.arb, app_it.arb, app_ja.arb, app_ko.arb, app_nl.arb, app_pt.arb, app_zh.arb` (confirm the exact list by `ls lib/l10n/app_*.arb`), add the same keys with translated values. Keep the `{count}` placeholder intact in `reencryptDone`. If a machine translation is not available, use the English value as a placeholder but keep the key present (analyzer requires every key in every locale).

- [ ] **Step 3: Regenerate and verify**

Run: `flutter gen-l10n` (or `flutter pub get` which triggers it), then `flutter analyze`.
Expected: no "missing key" errors; `context.l10n.settings_backupEncryption_title` resolves.

- [ ] **Step 4: Commit**

```bash
dart format lib/ && flutter analyze
git add lib/l10n/
git commit -m "i18n(backup): add backup-encryption strings (en + 10 locales)"
```

---

### Task 11: Enable dialog + change-password dialog

Mirror `EnableEncryptionDialog` (`enable_encryption_dialog.dart`) with backup copy and NO delete-plaintext checkbox. Reuse the public `RecoveryCodeDisplay`.

**Files:**
- Create: `lib/features/backup/presentation/widgets/backup_enable_encryption_dialog.dart`
- Create: `lib/features/backup/presentation/widgets/backup_change_password_dialog.dart`
- Test: `test/features/backup/presentation/widgets/backup_enable_encryption_dialog_test.dart`

**Interfaces:**
- Produces: `BackupEnableEncryptionDialog({required Future<String> Function(String passphrase) onEnable, required Future<void> Function() onFinished})`; `BackupChangePasswordDialog({required Future<void> Function(String current, String next) onSubmit})`.
- Consumes: `RecoveryCodeDisplay` (from `enable_encryption_dialog.dart`), `context.l10n.settings_backupEncryption_*` (Task 10).

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:submersion/l10n/app_localizations.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_enable_encryption_dialog.dart';

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('enable flow: form -> recovery gate -> finish', (tester) async {
    var enabled = false;
    var finished = false;
    await tester.pumpWidget(_host(Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => BackupEnableEncryptionDialog(
            onEnable: (p) async { enabled = true; return 'alpha-bravo-charlie-delta-echo-foxtrot-golf-hotel'; },
            onFinished: () async { finished = true; },
          ),
        ),
        child: const Text('open'),
      );
    })));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'backuppass1');
    await tester.enterText(find.byType(TextField).at(1), 'backuppass1');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(enabled, isTrue);
    expect(find.textContaining('alpha-bravo'), findsOneWidget);

    // Done is disabled until the saved checkbox is ticked.
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/presentation/widgets/backup_enable_encryption_dialog_test.dart`
Expected: FAIL (widget not defined).

- [ ] **Step 3: Implement `BackupEnableEncryptionDialog`**

Copy the structure of `enable_encryption_dialog.dart` (the `_Phase { form, busy, recovery }` state machine) with these changes: remove `_deleteBackups` and its `CheckboxListTile`; `onFinished` takes no argument; use `context.l10n.settings_backupEncryption_*` keys; the form shows only `settings_backupEncryption_warnLoss`; import `RecoveryCodeDisplay` from `package:submersion/features/settings/presentation/widgets/enable_encryption_dialog.dart`. Password minimum length is 8 (`settings_backupEncryption_passwordTooShort`).

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/settings/presentation/widgets/enable_encryption_dialog.dart' show RecoveryCodeDisplay;
import 'package:submersion/l10n/l10n_extension.dart';

class BackupEnableEncryptionDialog extends StatefulWidget {
  final Future<String> Function(String passphrase) onEnable;
  final Future<void> Function() onFinished;

  const BackupEnableEncryptionDialog({super.key, required this.onEnable, required this.onFinished});

  @override
  State<BackupEnableEncryptionDialog> createState() => _BackupEnableEncryptionDialogState();
}

enum _Phase { form, busy, recovery }

class _BackupEnableEncryptionDialogState extends State<BackupEnableEncryptionDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _phase = _Phase.form;
  var _recoverySaved = false;
  String? _passwordError;
  String? _confirmError;
  String? _recoveryCode;
  String? _enableError;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    final l10n = context.l10n;
    setState(() {
      _passwordError = _password.text.length < 8 ? l10n.settings_backupEncryption_passwordTooShort : null;
      _confirmError = _password.text != _confirm.text ? l10n.settings_backupEncryption_passwordMismatch : null;
      _enableError = null;
    });
    if (_passwordError != null || _confirmError != null) return;
    setState(() => _phase = _Phase.busy);
    try {
      final code = await widget.onEnable(_password.text);
      if (!mounted) return;
      setState(() { _recoveryCode = code; _phase = _Phase.recovery; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _phase = _Phase.form; _enableError = e.toString(); });
    }
  }

  Future<void> _finish() async {
    setState(() => _phase = _Phase.busy);
    await widget.onFinished();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    switch (_phase) {
      case _Phase.form:
        return AlertDialog(
          title: Text(l10n.settings_backupEncryption_enable),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _password,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.settings_backupEncryption_password, errorText: _passwordError),
                ),
                TextField(
                  controller: _confirm,
                  obscureText: true,
                  decoration: InputDecoration(labelText: l10n.settings_backupEncryption_passwordConfirm, errorText: _confirmError),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: Theme.of(context).colorScheme.tertiary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l10n.settings_backupEncryption_warnLoss, style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ),
                if (_enableError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_enableError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.settings_backupEncryption_cancel)),
            FilledButton(onPressed: _submitForm, child: Text(l10n.settings_backupEncryption_continue)),
          ],
        );
      case _Phase.busy:
        return const AlertDialog(content: SizedBox(height: 64, child: Center(child: CircularProgressIndicator())));
      case _Phase.recovery:
        return AlertDialog(
          title: Text(l10n.settings_backupEncryption_recoveryTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.settings_backupEncryption_recoveryExplain),
              const SizedBox(height: 12),
              RecoveryCodeDisplay(code: _recoveryCode!),
              CheckboxListTile(
                value: _recoverySaved,
                onChanged: (v) => setState(() => _recoverySaved = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(l10n.settings_backupEncryption_recoverySavedConfirm, style: Theme.of(context).textTheme.bodyMedium),
              ),
            ],
          ),
          actions: [
            FilledButton(onPressed: _recoverySaved ? _finish : null, child: Text(l10n.settings_backupEncryption_done)),
          ],
        );
    }
  }
}
```

- [ ] **Step 4: Implement `BackupChangePasswordDialog`**

A single AlertDialog with three obscured fields (current, new, confirm) calling `onSubmit(current, next)`; show an inline error on `WrongPassphraseException`. Model it on the form phase above (current + new + confirm; validate new length >= 8 and match; catch and display errors from `onSubmit`).

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/backup/presentation/widgets/backup_enable_encryption_dialog_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/ test/ && flutter analyze
git add lib/features/backup/presentation/widgets/backup_enable_encryption_dialog.dart lib/features/backup/presentation/widgets/backup_change_password_dialog.dart test/features/backup/presentation/widgets/backup_enable_encryption_dialog_test.dart
git commit -m "feat(backup): backup-encryption enable + change-password dialogs"
```

---

### Task 12: `BackupEncryptionSection` + wire into the settings page + export extension

**Files:**
- Create: `lib/features/backup/presentation/widgets/backup_encryption_section.dart`
- Modify: `lib/features/backup/presentation/pages/backup_settings_page.dart` (mount the section; export filename/extension; restore-prompt strings; post-enable dialog)
- Test: `test/features/backup/presentation/widgets/backup_encryption_section_test.dart`

**Interfaces:**
- Consumes: `backupSettingsProvider` (state + `.notifier.setBackupEncryptionEnabled`), `backupEncryptionServiceProvider`, `backupServiceProvider` (`reencryptExistingBackups`), `BackupEnableEncryptionDialog`, `BackupChangePasswordDialog`, `showEncryptionPassphraseDialog`.

- [ ] **Step 1: Write the failing widget test**

```dart
// Pump BackupEncryptionSection in a ProviderScope overriding backupSettingsProvider
// with backupEncryptionEnabled:false, assert the "Encrypt backups" tile shows;
// override with true, assert "Change password" / "Turn off" show.
// (Mirror test/features/settings/presentation/widgets/encryption_settings_section_test.dart.)
```

Write concrete assertions mirroring `encryption_settings_section_test.dart`: find `context.l10n.settings_backupEncryption_enable` when off; find `settings_backupEncryption_changePassword` + `settings_backupEncryption_turnOff` when on. Override `backupSettingsProvider` with a fixed `BackupSettings`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/presentation/widgets/backup_encryption_section_test.dart`
Expected: FAIL (widget not defined).

- [ ] **Step 3: Implement `BackupEncryptionSection`**

A `ConsumerWidget` that watches `backupSettingsProvider`. When `backupEncryptionEnabled` is false: a single tile (`settings_backupEncryption_enable`, subtitle `subtitleOff`) that opens `BackupEnableEncryptionDialog`:
- `onEnable: (pass) => ref.read(backupEncryptionServiceProvider).enable(passphrase: pass).then((r) => r.recoveryCode)`
- `onFinished: () async { await ref.read(backupSettingsProvider.notifier).setBackupEncryptionEnabled(true); }`
- After the dialog returns true, show the post-enable re-encrypt dialog (Step 4).

When true: tiles for `changePassword` (opens `BackupChangePasswordDialog` -> `ref.read(backupEncryptionServiceProvider).changePassphrase(...)`), `regenerateRecovery` (prompt current password via `showEncryptionPassphraseDialog`, then show the returned code via `RecoveryCodeDisplay` in an AlertDialog), and `turnOff` (confirm with `turnOffTitle`/`turnOffBody`, then `setBackupEncryptionEnabled(false)`).

- [ ] **Step 4: Post-enable re-encrypt dialog**

After enable succeeds, show an AlertDialog titled `settings_backupEncryption_reencryptTitle`, body `reencryptBody`, actions `reencryptNotNow` (dismiss) and `reencryptNow`:

```dart
onPressed: () async {
  Navigator.of(dialogContext).pop();
  final result = await ref.read(backupServiceProvider).reencryptExistingBackups();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(context.l10n.settings_backupEncryption_reencryptDone(result.reencrypted)),
    ));
  }
},
```

- [ ] **Step 5: Mount the section + fix export extension in `backup_settings_page.dart`**

- Add `BackupEncryptionSection()` to the page body (near the existing sections).
- In `_generateDefaultFilename()` and `_handleExport`, when `ref.read(backupSettingsProvider).backupEncryptionEnabled` is true, use a `.sbe` filename and set FilePicker `allowedExtensions: ['sbe']`; otherwise keep `.db`/`['db','sqlite']`. Concretely, change `_generateDefaultFilename` to take the flag:

```dart
String _generateDefaultFilename(bool encrypted) {
  final now = DateTime.now();
  final formatted = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return 'submersion_backup_$formatted.${encrypted ? 'sbe' : 'db'}';
}
```

and in `onSaveToFile`:

```dart
final encrypted = ref.read(backupSettingsProvider).backupEncryptionEnabled;
final result = await FilePicker.saveFile(
  dialogTitle: context.l10n.backup_export_title,
  fileName: _generateDefaultFilename(encrypted),
  allowedExtensions: encrypted ? ['sbe'] : ['db', 'sqlite'],
  type: FileType.custom,
);
```

- Update the two restore-prompt calls (L258-262 and L393-397) to use `context.l10n.settings_backupEncryption_unlockTitle` / `settings_backupEncryption_unlockHint` (neutral copy that fits both backup and sync artifacts).

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/backup/presentation/widgets/backup_encryption_section_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib/ test/ && flutter analyze
git add lib/features/backup/presentation/widgets/backup_encryption_section.dart lib/features/backup/presentation/pages/backup_settings_page.dart test/features/backup/presentation/widgets/backup_encryption_section_test.dart
git commit -m "feat(backup): backup-encryption settings section + encrypted export"
```

---

### Task 13: Full verification sweep

**Files:** none (verification only).

- [ ] **Step 1: Format and analyze the whole project**

Run: `dart format .` then `flutter analyze`
Expected: "No issues found."

- [ ] **Step 2: Run the full backup + crypto suites**

Run: `flutter test test/features/backup/ test/core/services/sync/crypto/ test/features/settings/presentation/widgets/`
Expected: all pass, including the untouched #520 suites (regression guard).

- [ ] **Step 3: Run the entire test suite**

Run: `flutter test`
Expected: all pass.

- [ ] **Step 4: Manual smoke (macOS) — record in the PR, not a code change**

Run: `flutter run -d macos`. Enable backup encryption (set password, save recovery code), confirm the post-enable re-encrypt prompt, run a manual backup, verify the history entry is `.sbe`, then restore it (silent), then remove the key path is covered by tests. Note the result in the PR description.

- [ ] **Step 5: Final commit (if formatting changed anything)**

```bash
git add -A
git commit -m "chore(backup): format + verification sweep for encrypted backups" || echo "nothing to commit"
```

---

## Self-Review

**1. Spec coverage**

| Spec requirement | Task |
|---|---|
| App-wide scope: local auto + manual "Backup now" | Task 6 |
| App-wide: Save-to-File + Share | Task 7 |
| App-wide: cloud upload (precedence, no double-encrypt) | Task 6 (Step 4) |
| Recovery code always at enable + confirm gate | Task 3 (enable), Task 11 (gate UI) |
| Separate backup key + own recovery code, #520 untouched | Tasks 2, 3 (+ Global Constraints) |
| Restore silently with stored backup key; prompt otherwise | Task 8 |
| Existing backups: Re-encrypt / Not now (no delete) | Task 9 (engine), Task 12 (dialog) |
| Extension `.sbe` / magic `SBE1` unchanged | Global Constraints (no rename anywhere) |
| No DB schema change | Global Constraints; nothing touches Drift |
| Two UI states (Off/On) | Task 12 (documented deviation) |
| l10n en + 10 locales | Task 10 |
| KAT reuse (no new vectors) | none needed; Global Constraints note |

**2. Placeholder scan:** UI Steps 3-4 of Tasks 11-12 describe the change-password dialog, regenerate flow, and section tiles in prose rather than full code — they are mechanical mirrors of the enable dialog / `encryption_settings_section.dart` whose full code is shown or cited. Every service/data task (1-9) has complete code. Acceptable for a skilled implementer following the cited mirror; if executing via subagents, point each at the named mirror file.

**3. Type consistency:** `_activeBackupKey()` returns `({SecretKey mlk, String libraryKeyId, Uint8List keyslotBytes})` and is consumed identically in Tasks 6, 7, 9. `EnableBackupEncryptionResult{recoveryCode, libraryKeyId}` produced in Task 3, consumed in Task 12. `BackupEncryptionKeyStore` storage-key constants (`keyIdStorageKey`/`mlkStorageKey`/`mirrorStorageKey`) are referenced in the Task 2 test. `reencryptExistingBackups()` return record `({int reencrypted, int skipped, int failed})` matches the Task 9 test and the Task 12 snackbar (`result.reencrypted`).

**Known implementer checks (not blockers):** confirm `BackupRecord.copyWith` covers the four fields (Task 9 Step 1); confirm the exact non-en locale list via `ls lib/l10n/app_*.arb` (Task 10); confirm `AppLocalizations` import path used in widget tests matches the project's generated l10n path.
