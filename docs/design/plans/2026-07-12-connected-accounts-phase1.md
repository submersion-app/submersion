# Connected Accounts (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An app-level Connected Accounts layer (synced secret-free roster + per-account keychain credentials + capability registry) that Data Sync, Media Storage, and Lightroom select from independently, severing the media/sync provider coupling.

**Architecture:** New synced `connected_accounts` table (schema v107) holds secret-free account rows; credentials live per-account in the keychain under `account_<id>_credentials`. An `AccountProviderRegistry` maps `AccountKind` to adapters exposing `SyncCapable` / `MediaStoreCapable` / `MediaSourceCapable`. A one-time startup migration seeds account rows from existing config and re-keys legacy keychain blobs. Existing settings UI is unchanged in Phase 1 (Phase 3 rebuilds it); a compatibility shim maps today's provider-type selection onto accounts.

**Tech Stack:** Flutter/Dart, Drift ORM, Riverpod, flutter_secure_storage (via `FallbackSecureStorage`), SharedPreferences.

**Spec:** `docs/superpowers/specs/2026-07-12-media-linking-storage-program-design.md` section 5.

## Global Constraints

- Schema version goes 106 -> 107. All DDL idempotent (`IF NOT EXISTS` / PRAGMA-guarded ALTER) + `beforeOpen` re-assert, matching the v103/v106 pattern in `lib/core/database/database.dart`.
- The NEWEST migration test holds the exact `currentSchemaVersion` tripwire; the current holder (the v106 connector-suggestions test) is loosened to `greaterThanOrEqualTo` and the new v107 test takes it over.
- Secrets never enter the database. Keychain only, via `FallbackSecureStorage`.
- No UI changes, no new user-facing strings (so no l10n work) in Phase 1.
- Every Drift schema change requires `dart run build_runner build --delete-conflicting-outputs`.
- Run `dart format .` before every commit; `flutter analyze` must be clean (never pipe through `tail`).
- Run tests per-file (`flutter test test/path/file_test.dart`), never the whole suite mid-task.
- Work in a git worktree (repo convention); after creating it run `git submodule update --init --recursive` and `flutter pub get`, then build_runner.
- Domain-vs-Drift name collisions are resolved with `as domain` import aliases (existing convention).
- Commit messages: conventional commits, no attribution lines.

---

### Task 1: AccountKind enum + ConnectedAccount domain entity

**Files:**
- Create: `lib/core/services/accounts/account_kind.dart`
- Create: `lib/core/services/accounts/connected_account.dart`
- Test: `test/core/services/accounts/connected_account_test.dart`

**Interfaces:**
- Produces: `enum AccountKind { dropbox, googledrive, icloud, s3, adobeLightroom }` with `CloudProviderType? get cloudProviderType`, `static AccountKind fromCloudProviderType(CloudProviderType)`; class `ConnectedAccount { String id; AccountKind kind; String label; String? accountIdentifier; DateTime createdAt; DateTime updatedAt; copyWith(...) }` and `String get credentialsKey => 'account_${id}_credentials'`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/accounts/connected_account_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';

void main() {
  group('AccountKind', () {
    test('maps 1:1 with CloudProviderType and back', () {
      for (final type in CloudProviderType.values) {
        final kind = AccountKind.fromCloudProviderType(type);
        expect(kind.cloudProviderType, type);
      }
    });

    test('adobeLightroom has no cloud provider type', () {
      expect(AccountKind.adobeLightroom.cloudProviderType, isNull);
    });
  });

  group('ConnectedAccount', () {
    final account = ConnectedAccount(
      id: 'abc-123',
      kind: AccountKind.s3,
      label: 'My MinIO',
      accountIdentifier: 'dive-media @ minio.local',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true),
    );

    test('credentialsKey embeds the account id', () {
      expect(account.credentialsKey, 'account_abc-123_credentials');
    });

    test('copyWith replaces only the given fields', () {
      final renamed = account.copyWith(label: 'Renamed');
      expect(renamed.label, 'Renamed');
      expect(renamed.id, account.id);
      expect(renamed.kind, AccountKind.s3);
      expect(renamed.accountIdentifier, account.accountIdentifier);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/accounts/connected_account_test.dart`
Expected: FAIL (files do not exist / compile error).

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/services/accounts/account_kind.dart
import 'package:submersion/core/data/repositories/sync_repository.dart';

/// The kinds of endpoints a ConnectedAccount can represent. The first four
/// mirror [CloudProviderType]; connector kinds (Lightroom now, Immich/SMB
/// later per the program spec) have no cloud provider equivalent.
enum AccountKind {
  dropbox,
  googledrive,
  icloud,
  s3,
  adobeLightroom;

  /// The sync/media-store provider this kind corresponds to, or null for
  /// media-source connector kinds.
  CloudProviderType? get cloudProviderType => switch (this) {
    AccountKind.dropbox => CloudProviderType.dropbox,
    AccountKind.googledrive => CloudProviderType.googledrive,
    AccountKind.icloud => CloudProviderType.icloud,
    AccountKind.s3 => CloudProviderType.s3,
    AccountKind.adobeLightroom => null,
  };

  static AccountKind fromCloudProviderType(CloudProviderType type) =>
      switch (type) {
        CloudProviderType.dropbox => AccountKind.dropbox,
        CloudProviderType.googledrive => AccountKind.googledrive,
        CloudProviderType.icloud => AccountKind.icloud,
        CloudProviderType.s3 => AccountKind.s3,
      };
}
```

```dart
// lib/core/services/accounts/connected_account.dart
import 'package:submersion/core/services/accounts/account_kind.dart';

/// A linked credentialed endpoint (secret-free). Accounts are instances,
/// not singletons: two S3 endpoints are two accounts. Secrets live in the
/// keychain under [credentialsKey], never in this object or the database.
class ConnectedAccount {
  final String id;
  final AccountKind kind;
  final String label;
  final String? accountIdentifier;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ConnectedAccount({
    required this.id,
    required this.kind,
    required this.label,
    this.accountIdentifier,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Keychain key for this account's credentials blob.
  String get credentialsKey => 'account_${id}_credentials';

  ConnectedAccount copyWith({
    String? label,
    String? accountIdentifier,
    DateTime? updatedAt,
  }) {
    return ConnectedAccount(
      id: id,
      kind: kind,
      label: label ?? this.label,
      accountIdentifier: accountIdentifier ?? this.accountIdentifier,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/accounts/connected_account_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/services/accounts/ test/core/services/accounts/
git commit -m "feat(accounts): AccountKind enum and ConnectedAccount entity"
```

---

### Task 2: Schema v107 — connected_accounts table + sync_metadata.sync_account_id

**Files:**
- Modify: `lib/core/database/database.dart` (table class near `MediaStores` ~line 1069; `currentSchemaVersion` at line 2162; `onUpgrade` tail near line 5274; `beforeOpen` near line 5285)
- Test: `test/core/database/connected_accounts_migration_test.dart`
- Modify: the current tripwire test (find with `grep -rn "currentSchemaVersion, 106\|equals(106)" test/`) — loosen to `greaterThanOrEqualTo(106)`

**Interfaces:**
- Produces: Drift table `ConnectedAccounts` (row class `ConnectedAccount` — always import the domain entity `as domain` where both appear); `SyncMetadata.syncAccountId` nullable text column; helper `_assertConnectedAccountsSchema()`.

- [ ] **Step 1: Write the failing migration test**

Mirror the structure of the v106 connector-suggestions migration test (find it: `grep -rln "connector_suggestion\|_assertConnectorSuggestionColumns" test/core/database/`). The test opens a database, asserts the table and column exist, and holds the exact-version tripwire:

```dart
// test/core/database/connected_accounts_migration_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v107 creates connected_accounts and sync_metadata.sync_account_id',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name='connected_accounts'",
        )
        .get();
    expect(tables, hasLength(1));

    final cols = await db
        .customSelect("PRAGMA table_info('sync_metadata')")
        .get();
    expect(
      cols.map((c) => c.read<String>('name')),
      contains('sync_account_id'),
    );
  });

  test('schema version tripwire (hand off to the NEXT migration when it lands)',
      () {
    expect(AppDatabase.currentSchemaVersion, 107);
  });
}
```

Note: if `AppDatabase.forTesting` does not exist, use whatever constructor the v106 migration test uses — copy its setup verbatim.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/connected_accounts_migration_test.dart`
Expected: FAIL (`currentSchemaVersion` is 106; table missing).

- [ ] **Step 3: Implement the schema change**

In `lib/core/database/database.dart`:

(a) Table class, placed directly after `MediaStores` (before the `// coverage:ignore-end` at line 1080):

```dart
/// Linked credentialed endpoints (secret-free). Synced roster: other
/// devices see which accounts exist and prompt for sign-in (program spec
/// section 5). Credentials live in the keychain under
/// `account_<id>_credentials`, never here.
class ConnectedAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // AccountKind.name
  TextColumn get label => text()();
  TextColumn get accountIdentifier => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

(b) Register `ConnectedAccounts` in the `@DriftDatabase(tables: [...])` list (search for `MediaStores,` in the annotation and add `ConnectedAccounts,` next to it).

(c) Add `syncAccountId` to the `SyncMetadata` table class (line ~1837, next to `syncProvider`):

```dart
  /// The connected account driving sync, or null pre-account-migration.
  /// syncProvider stays populated (kind name) for backward compatibility.
  TextColumn get syncAccountId => text().nullable()();
```

(d) Bump `static const int currentSchemaVersion = 106;` to `107`.

(e) Idempotent assert helper next to `_assertConnectorSuggestionColumns()` (line ~2278):

```dart
  /// v107: connected accounts roster + sync account selection. Idempotent;
  /// also run from beforeOpen as a parallel-branch collision backstop.
  Future<void> _assertConnectedAccountsSchema() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS connected_accounts ('
      'id TEXT NOT NULL PRIMARY KEY, '
      'kind TEXT NOT NULL, '
      'label TEXT NOT NULL, '
      'account_identifier TEXT, '
      'created_at INTEGER NOT NULL, '
      'updated_at INTEGER NOT NULL, '
      'hlc TEXT)',
    );
    final metaCols = await customSelect(
      "PRAGMA table_info('sync_metadata')",
    ).get();
    if (metaCols.isNotEmpty &&
        !metaCols.any((c) => c.read<String>('name') == 'sync_account_id')) {
      await customStatement(
        'ALTER TABLE sync_metadata ADD COLUMN sync_account_id TEXT',
      );
    }
  }
```

(f) `onUpgrade` step after the `if (from < 106)` block (line ~5283):

```dart
        if (from < 107) {
          // Connected accounts (program spec section 5). Idempotent DDL;
          // beforeOpen re-asserts against parallel-branch version collisions.
          await _assertConnectedAccountsSchema();
        }
        if (from < 107) await reportProgress();
```

(g) `beforeOpen` backstop, after the v106 re-assert (line ~5294):

```dart
        // v107 backstop: re-assert connected accounts schema.
        await _assertConnectedAccountsSchema();
```

(h) Loosen the old tripwire: in the v106 test found in the Files section, change `expect(AppDatabase.currentSchemaVersion, 106)` to `expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(106))`.

- [ ] **Step 4: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes without errors; `database.g.dart` gains `ConnectedAccount` row class and `connectedAccounts` accessor.

- [ ] **Step 5: Run tests**

Run: `flutter test test/core/database/connected_accounts_migration_test.dart` and the loosened v106 test file.
Expected: PASS both.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/core/database/ test/core/database/
git commit -m "feat(accounts): schema v107 connected_accounts table and sync_account_id"
```

---

### Task 3: Sync serializer registration for connectedAccounts

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` — every site that mentions `mediaStores` (fields at lines ~228/282/337/393, `_baseTables` entry ~581, export ~976, and each `case 'mediaStores':` switch arm at ~1309, 1575, 1814, 2208, 2678, 2846, 3026)
- Modify: `lib/core/services/sync/sync_service.dart` — mirror its `mediaStores` registration sites (find with `grep -n "mediaStores" lib/core/services/sync/sync_service.dart`)
- Test: `test/core/services/sync/sync_data_serializer_record_ids_test.dart` (the registration guard test)

**Interfaces:**
- Produces: sync entity key `'connectedAccounts'` registered end-to-end. HLC-bearing table: apply-side uses `.toCompanion(false)` like other HLC entities (per repo convention).

- [ ] **Step 1: Extend the guard test**

Open `test/core/services/sync/sync_data_serializer_record_ids_test.dart`, find how `mediaStores` appears (it enumerates registered tables/record-id extraction), and add `connectedAccounts` the same way. If the guard test auto-derives the table list from the serializer, no edit is needed — read it first to know which.

- [ ] **Step 2: Run guard test to verify it fails**

Run: `flutter test test/core/services/sync/sync_data_serializer_record_ids_test.dart`
Expected: FAIL (unknown entity `connectedAccounts`).

- [ ] **Step 3: Register the entity**

In `sync_data_serializer.dart`, at every `mediaStores` site listed above, add the parallel `connectedAccounts` line/arm. Key entries:

- Field: `final List<Map<String, dynamic>> connectedAccounts;` with constructor default `this.connectedAccounts = const [],`, toJson `'connectedAccounts': connectedAccounts,`, fromJson `connectedAccounts: _parseList(json['connectedAccounts']),`.
- `_baseTables` entry: `(key: 'connectedAccounts', table: _db.connectedAccounts, blob: false, full: null),`.
- Each `case 'mediaStores':` switch gets a sibling `case 'connectedAccounts':` operating on `_db.connectedAccounts` with the same shape (record id column is `_db.connectedAccounts.id`).

In `sync_service.dart`, mirror every `mediaStores` registration line with `connectedAccounts`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/services/sync/sync_data_serializer_record_ids_test.dart test/core/services/sync/sync_apply_record_test.dart test/core/services/sync/sync_serializer_fetch_record_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/services/sync/ test/core/services/sync/
git commit -m "feat(accounts): register connectedAccounts in sync engine"
```

---

### Task 4: ConnectedAccountsRepository

**Files:**
- Create: `lib/core/data/repositories/connected_accounts_repository.dart`
- Test: `test/core/data/repositories/connected_accounts_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 entity (`as domain`), Task 2 table, `SyncRepository.markRecordPending`, `SyncEventBus.notifyLocalChange()`.
- Produces:
  - `Future<domain.ConnectedAccount> create({required AccountKind kind, required String label, String? accountIdentifier, String? id})`
  - `Future<List<domain.ConnectedAccount>> getAll()`
  - `Future<domain.ConnectedAccount?> getById(String id)`
  - `Future<domain.ConnectedAccount?> getByKind(AccountKind kind)` (newest first)
  - `Future<void> updateLabels(String id, {String? label, String? accountIdentifier})`
  - `Future<void> delete(String id)`

- [ ] **Step 1: Write the failing test**

Model setup on `test/core/services/sync/checklist_sync_round_trip_test.dart`'s in-memory database pattern (or the ConnectorAccountsRepository test if one exists — check `test/features/media/data/repositories/`). Core assertions:

```dart
// test/core/data/repositories/connected_accounts_repository_test.dart
// (setup: in-memory AppDatabase + repository with injected db, mirroring
// how MediaStoresRepository accepts {AppDatabase? database}.)
test('create then getByKind round-trips secret-free fields', () async {
  final created = await repo.create(
    kind: AccountKind.s3,
    label: 'My MinIO',
    accountIdentifier: 'dive-media @ minio.local',
  );
  final loaded = await repo.getByKind(AccountKind.s3);
  expect(loaded!.id, created.id);
  expect(loaded.label, 'My MinIO');
  expect(loaded.accountIdentifier, 'dive-media @ minio.local');
});

test('create marks the record pending for sync', () async {
  final created = await repo.create(kind: AccountKind.dropbox, label: 'DB');
  // Assert via the injected SyncRepository fake/spy that
  // markRecordPending(entityType: 'connectedAccounts', recordId: created.id)
  // was called — same spy approach as media_stores_repository tests
  // (see test/features/media_store/data/media_stores_repository_test.dart).
});

test('delete removes the row', () async {
  final created = await repo.create(kind: AccountKind.s3, label: 'X');
  await repo.delete(created.id);
  expect(await repo.getById(created.id), isNull);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/data/repositories/connected_accounts_repository_test.dart`
Expected: FAIL (repository does not exist).

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/data/repositories/connected_accounts_repository.dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';

/// CRUD for the synced, secret-free `connected_accounts` roster. Writes are
/// marked pending for sync (mirrors MediaStoresRepository).
class ConnectedAccountsRepository {
  ConnectedAccountsRepository({
    AppDatabase? database,
    SyncRepository? syncRepository,
  }) : _database = database,
       _syncRepository = syncRepository ?? SyncRepository();

  final AppDatabase? _database;
  final SyncRepository _syncRepository;
  final _uuid = const Uuid();

  AppDatabase get _db => _database ?? DatabaseService.instance.database;

  Future<domain.ConnectedAccount> create({
    required AccountKind kind,
    required String label,
    String? accountIdentifier,
    String? id,
  }) async {
    final accountId = id ?? _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.connectedAccounts)
        .insert(
          ConnectedAccountsCompanion.insert(
            id: accountId,
            kind: kind.name,
            label: label,
            accountIdentifier: Value(accountIdentifier),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _markPending(accountId, now);
    return domain.ConnectedAccount(
      id: accountId,
      kind: kind,
      label: label,
      accountIdentifier: accountIdentifier,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now, isUtc: true),
    );
  }

  Future<List<domain.ConnectedAccount>> getAll() async {
    final rows =
        await (_db.select(_db.connectedAccounts)
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();
    return rows.map(_toDomain).toList();
  }

  Future<domain.ConnectedAccount?> getById(String id) async {
    final row = await (_db.select(
      _db.connectedAccounts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// Newest account of [kind], or null. Single-instance kinds (Google,
  /// iCloud) are expected to have at most one row.
  Future<domain.ConnectedAccount?> getByKind(AccountKind kind) async {
    final row =
        await (_db.select(_db.connectedAccounts)
              ..where((t) => t.kind.equals(kind.name))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<void> updateLabels(
    String id, {
    String? label,
    String? accountIdentifier,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.connectedAccounts,
    )..where((t) => t.id.equals(id))).write(
      ConnectedAccountsCompanion(
        label: label == null ? const Value.absent() : Value(label),
        accountIdentifier: accountIdentifier == null
            ? const Value.absent()
            : Value(accountIdentifier),
        updatedAt: Value(now),
      ),
    );
    await _markPending(id, now);
  }

  Future<void> delete(String id) async {
    await (_db.delete(
      _db.connectedAccounts,
    )..where((t) => t.id.equals(id))).go();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _markPending(id, now);
  }

  Future<void> _markPending(String recordId, int now) async {
    await _syncRepository.markRecordPending(
      entityType: 'connectedAccounts',
      recordId: recordId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  domain.ConnectedAccount _toDomain(ConnectedAccount row) {
    return domain.ConnectedAccount(
      id: row.id,
      kind: AccountKind.values.byName(row.kind),
      label: row.label,
      accountIdentifier: row.accountIdentifier,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
    );
  }
}
```

Note the Drift-vs-domain name collision on `ConnectedAccount`: inside this file the bare name is the Drift row class; the domain entity is `domain.ConnectedAccount`. Check whether deletion of synced rows needs a tombstone (`grep -n "deletion" lib/core/data/repositories/sync_repository.dart` for the deletion-log API used by other synced repos, e.g. how media rows record deletions) — if a `recordDeletion`/tombstone helper exists for HLC tables, call it in `delete()` the same way.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/data/repositories/connected_accounts_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/data/repositories/connected_accounts_repository.dart test/core/data/repositories/
git commit -m "feat(accounts): ConnectedAccountsRepository with sync pending marks"
```

---

### Task 5: AccountCredentialsStore (per-account keychain blobs)

**Files:**
- Create: `lib/core/services/accounts/account_credentials_store.dart`
- Test: `test/core/services/accounts/account_credentials_store_test.dart`

**Interfaces:**
- Produces: `AccountCredentialsStore({FlutterSecureStorage? storage})` with `Future<String?> read(String accountId)`, `Future<void> write(String accountId, String json)`, `Future<void> delete(String accountId)`, `Future<void> rekeyFromLegacy({required String legacyKey, required String accountId})` (copy-then-keep: legacy blob is NOT deleted, so a rollback build still works).
- Consumes: `FallbackSecureStorage` (`lib/core/services/secure_storage/fallback_secure_storage.dart`).

- [ ] **Step 1: Write the failing test**

Use the same in-memory `FlutterSecureStorage` faking approach as the existing store tests (find one: `grep -rln "FlutterSecureStorage" test/ | head -3` — reuse their mock/fake).

```dart
test('write/read/delete round-trip under the per-account key', () async {
  await store.write('acc-1', '{"a":1}');
  expect(await store.read('acc-1'), '{"a":1}');
  await store.delete('acc-1');
  expect(await store.read('acc-1'), isNull);
});

test('rekeyFromLegacy copies the blob and keeps the legacy entry', () async {
  await fakeStorage.write(key: 'sync_dropbox_auth', value: '{"t":"x"}');
  await store.rekeyFromLegacy(
    legacyKey: 'sync_dropbox_auth',
    accountId: 'acc-2',
  );
  expect(await store.read('acc-2'), '{"t":"x"}');
  expect(await fakeStorage.read(key: 'sync_dropbox_auth'), '{"t":"x"}');
});

test('rekeyFromLegacy is a no-op when legacy key is absent', () async {
  await store.rekeyFromLegacy(legacyKey: 'missing', accountId: 'acc-3');
  expect(await store.read('acc-3'), isNull);
});

test('rekeyFromLegacy never overwrites an existing per-account blob', () async {
  await store.write('acc-4', '{"new":true}');
  await fakeStorage.write(key: 'legacy', value: '{"old":true}');
  await store.rekeyFromLegacy(legacyKey: 'legacy', accountId: 'acc-4');
  expect(await store.read('acc-4'), '{"new":true}');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/accounts/account_credentials_store_test.dart`
Expected: FAIL.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/services/accounts/account_credentials_store.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// Per-account keychain blobs under `account_<id>_credentials`. The payload
/// is an opaque JSON string owned by the account's adapter (S3Config JSON,
/// Dropbox refresh-token blob, Adobe IMS tokens, ...). Mirrors the legacy
/// single-key stores (S3CredentialsStore etc.), which remain readable for
/// rollback; migration copies rather than moves.
class AccountCredentialsStore {
  AccountCredentialsStore({FlutterSecureStorage? storage})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage());

  final FallbackSecureStorage _storage;

  static String keyFor(String accountId) => 'account_${accountId}_credentials';

  Future<String?> read(String accountId) =>
      _storage.read(key: keyFor(accountId));

  Future<void> write(String accountId, String json) =>
      _storage.write(key: keyFor(accountId), value: json);

  Future<void> delete(String accountId) =>
      _storage.delete(key: keyFor(accountId));

  /// Copies a legacy single-key blob to the per-account key. Keeps the
  /// legacy entry (rollback safety) and never overwrites an existing
  /// per-account blob (idempotent across repeated startups).
  Future<void> rekeyFromLegacy({
    required String legacyKey,
    required String accountId,
  }) async {
    if (await read(accountId) != null) return;
    final legacy = await _storage.read(key: legacyKey);
    if (legacy == null) return;
    await write(accountId, legacy);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/accounts/account_credentials_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/services/accounts/account_credentials_store.dart test/core/services/accounts/
git commit -m "feat(accounts): per-account keychain credentials store"
```

---

### Task 6: Capability interfaces + AccountProviderRegistry

**Files:**
- Create: `lib/core/services/accounts/account_provider_adapter.dart`
- Create: `lib/core/services/accounts/account_provider_registry.dart`
- Test: `test/core/services/accounts/account_provider_registry_test.dart`

**Interfaces:**
- Produces:

```dart
enum AccountStatus { signedIn, needsSignIn, unavailable }

abstract class AccountProviderAdapter {
  AccountKind get kind;
  Future<AccountStatus> status(domain.ConnectedAccount account);
  Future<void> disconnect(domain.ConnectedAccount account);
}

abstract interface class SyncCapable {
  CloudStorageProvider syncProvider(domain.ConnectedAccount account);
}

abstract interface class MediaStoreCapable {
  Future<MediaObjectStore?> mediaObjectStore(domain.ConnectedAccount account);
}

/// Marker for media-source connector kinds (Lightroom; Immich/SMB later).
abstract interface class MediaSourceCapable {}

class AccountProviderRegistry {
  AccountProviderRegistry(List<AccountProviderAdapter> adapters);
  AccountProviderAdapter adapterFor(AccountKind kind); // throws StateError if unregistered
  T? capabilityFor<T>(AccountKind kind); // adapter as T, or null
}
```

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/accounts/account_provider_registry_test.dart
// Register two fake adapters (one implements MediaStoreCapable, one not);
// assert adapterFor returns by kind, throws StateError for missing kinds,
// and capabilityFor<MediaStoreCapable> returns null for the non-capable one.
```

Write actual fakes in the test file:

```dart
class _FakeS3Adapter extends AccountProviderAdapter
    implements MediaStoreCapable {
  @override
  AccountKind get kind => AccountKind.s3;
  @override
  Future<AccountStatus> status(domain.ConnectedAccount a) async =>
      AccountStatus.signedIn;
  @override
  Future<void> disconnect(domain.ConnectedAccount a) async {}
  @override
  Future<MediaObjectStore?> mediaObjectStore(domain.ConnectedAccount a) async =>
      null;
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/accounts/account_provider_registry_test.dart`
Expected: FAIL.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/services/accounts/account_provider_adapter.dart
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';

/// Sign-in state of an account on THIS device (derived, never synced).
enum AccountStatus { signedIn, needsSignIn, unavailable }

/// One adapter per [AccountKind]. Adapters expose capabilities as extra
/// interfaces; features ask the registry for the capability they need.
abstract class AccountProviderAdapter {
  AccountKind get kind;

  /// Whether this device holds working credentials for [account].
  Future<AccountStatus> status(domain.ConnectedAccount account);

  /// Removes this device's credentials for [account]. Never touches the
  /// synced roster row (the account still exists in the library).
  Future<void> disconnect(domain.ConnectedAccount account);
}

/// The account can drive data sync.
abstract interface class SyncCapable {
  CloudStorageProvider syncProvider(domain.ConnectedAccount account);
}

/// The account can back a media object store.
abstract interface class MediaStoreCapable {
  Future<MediaObjectStore?> mediaObjectStore(domain.ConnectedAccount account);
}

/// Marker: the account is a media acquisition source (Lightroom now;
/// Immich/SMB per the program spec later).
abstract interface class MediaSourceCapable {}
```

```dart
// lib/core/services/accounts/account_provider_registry.dart
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';

/// Maps [AccountKind] to its adapter. Construction-time registration keeps
/// the mapping total and testable; features query capabilities, never
/// concrete adapter types.
class AccountProviderRegistry {
  AccountProviderRegistry(List<AccountProviderAdapter> adapters)
    : _adapters = {for (final a in adapters) a.kind: a};

  final Map<AccountKind, AccountProviderAdapter> _adapters;

  AccountProviderAdapter adapterFor(AccountKind kind) {
    final adapter = _adapters[kind];
    if (adapter == null) {
      throw StateError('No account adapter registered for $kind');
    }
    return adapter;
  }

  /// The adapter for [kind] as capability [T], or null when the kind is
  /// unregistered or lacks the capability.
  T? capabilityFor<T>(AccountKind kind) {
    final adapter = _adapters[kind];
    return adapter is T ? adapter as T : null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/accounts/account_provider_registry_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/services/accounts/ test/core/services/accounts/
git commit -m "feat(accounts): capability interfaces and provider registry"
```

---

### Task 7: S3 and Dropbox adapters

**Files:**
- Create: `lib/core/services/accounts/adapters/s3_account_adapter.dart`
- Create: `lib/core/services/accounts/adapters/dropbox_account_adapter.dart`
- Modify: `lib/core/services/cloud_storage/dropbox/dropbox_auth_store.dart` (add optional `storageKey` ctor param)
- Modify: `lib/core/services/cloud_storage/s3/s3_credentials_store.dart` (same)
- Test: `test/core/services/accounts/adapters/s3_account_adapter_test.dart`
- Test: `test/core/services/accounts/adapters/dropbox_account_adapter_test.dart`

**Interfaces:**
- Consumes: Tasks 5-6; `S3Config` (`lib/core/services/cloud_storage/s3/s3_config.dart`); `S3MediaObjectStore`, `DropboxMediaObjectStore`, `DropboxApiClient`, `DropboxAuthManager`; `S3StorageProvider`, `DropboxStorageProvider` (`lib/core/services/cloud_storage/`).
- Produces: `S3AccountAdapter implements SyncCapable, MediaStoreCapable` reading `S3Config` JSON from the per-account blob; `DropboxAccountAdapter implements SyncCapable, MediaStoreCapable` building a `DropboxAuthManager` whose `DropboxAuthStore` points at the per-account key.

- [ ] **Step 1: Generalize the two legacy stores' keys**

`DropboxAuthStore` (line 44) and `S3CredentialsStore` (line 19) each hardcode `static const String storageKey`. Change to:

```dart
  DropboxAuthStore({FlutterSecureStorage? storage, String? storageKey})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage()),
      _storageKey = storageKey ?? defaultStorageKey;

  final String _storageKey;
  static const String defaultStorageKey = 'sync_dropbox_auth';
```

Replace internal uses of `storageKey` with `_storageKey`. Same edit in `S3CredentialsStore` (`defaultStorageKey = 'sync_s3_config'`). Fix any existing references to the old const name (`grep -rn "S3CredentialsStore.storageKey\|DropboxAuthStore.storageKey" lib test`).

- [ ] **Step 2: Write the failing adapter tests**

S3 (pure, no network):

```dart
test('status is signedIn when a valid S3Config blob exists', () async {
  await credStore.write(account.id, jsonEncode(validS3Config.toJson()));
  expect(await adapter.status(account), AccountStatus.signedIn);
});

test('status is needsSignIn when the blob is absent', () async {
  expect(await adapter.status(account), AccountStatus.needsSignIn);
});

test('mediaObjectStore returns null without credentials', () async {
  expect(await adapter.mediaObjectStore(account), isNull);
});

test('mediaObjectStore builds an S3 store with the config prefix', () async {
  await credStore.write(account.id, jsonEncode(validS3Config.toJson()));
  expect(await adapter.mediaObjectStore(account), isA<S3MediaObjectStore>());
});
```

Dropbox: same shape; `status` checks `DropboxAuthStore(storageKey: AccountCredentialsStore.keyFor(account.id)).load() != null`.

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/core/services/accounts/adapters/`
Expected: FAIL.

- [ ] **Step 4: Write the implementations**

```dart
// lib/core/services/accounts/adapters/s3_account_adapter.dart
import 'dart:convert';

import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/s3_media_object_store.dart';

/// S3 endpoints as accounts. The whole S3Config (secrets included) is the
/// per-account keychain payload; multiple S3 accounts are first-class.
class S3AccountAdapter extends AccountProviderAdapter
    implements SyncCapable, MediaStoreCapable {
  S3AccountAdapter({AccountCredentialsStore? credentials})
    : _credentials = credentials ?? AccountCredentialsStore();

  final AccountCredentialsStore _credentials;

  @override
  AccountKind get kind => AccountKind.s3;

  Future<S3Config?> loadConfig(domain.ConnectedAccount account) async {
    final raw = await _credentials.read(account.id);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      return S3Config.fromJson(decoded);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> saveConfig(
    domain.ConnectedAccount account,
    S3Config config,
  ) => _credentials.write(account.id, jsonEncode(config.toJson()));

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async =>
      await loadConfig(account) == null
      ? AccountStatus.needsSignIn
      : AccountStatus.signedIn;

  @override
  Future<void> disconnect(domain.ConnectedAccount account) =>
      _credentials.delete(account.id);

  @override
  CloudStorageProvider syncProvider(domain.ConnectedAccount account) =>
      // NOTE: verify S3StorageProvider's constructor/config injection before
      // wiring (Task 12 reads it); if it loads S3CredentialsStore internally,
      // give it a {S3CredentialsStore? store} seam and pass
      // S3CredentialsStore(storageKey: AccountCredentialsStore.keyFor(account.id)).
      S3StorageProvider(
        credentialsStore: S3CredentialsStore(
          storageKey: AccountCredentialsStore.keyFor(account.id),
        ),
      );

  @override
  Future<MediaObjectStore?> mediaObjectStore(
    domain.ConnectedAccount account,
  ) async {
    final config = await loadConfig(account);
    if (config == null) return null;
    return S3MediaObjectStore(
      client: S3ApiClient(config),
      keyPrefix: config.prefix,
    );
  }
}
```

(The `syncProvider` note is a directive to the implementer: open `lib/core/services/cloud_storage/s3_storage_provider.dart` first, add the injectable-store seam if absent, and keep the default behavior identical. Do the same for `DropboxStorageProvider` with `DropboxAuthStore`.)

```dart
// lib/core/services/accounts/adapters/dropbox_account_adapter.dart
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_api_client.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_manager.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';
import 'package:submersion/core/services/cloud_storage/dropbox_storage_provider.dart';
import 'package:submersion/core/services/media_store/dropbox_media_object_store.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';

/// Dropbox logins as accounts: the per-account payload is the refresh-token
/// blob (DropboxAuthData JSON), read through DropboxAuthStore pointed at the
/// per-account keychain key.
class DropboxAccountAdapter extends AccountProviderAdapter
    implements SyncCapable, MediaStoreCapable {
  DropboxAccountAdapter({
    DropboxAuthManager Function(String storageKey)? authManagerFactory,
  }) : _authManagerFactory =
           authManagerFactory ??
           ((key) => DropboxAuthManager(store: DropboxAuthStore(storageKey: key)));

  final DropboxAuthManager Function(String storageKey) _authManagerFactory;

  @override
  AccountKind get kind => AccountKind.dropbox;

  DropboxAuthManager authManagerFor(domain.ConnectedAccount account) =>
      _authManagerFactory(AccountCredentialsStore.keyFor(account.id));

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async {
    final auth = await DropboxAuthStore(
      storageKey: AccountCredentialsStore.keyFor(account.id),
    ).load();
    return auth == null ? AccountStatus.needsSignIn : AccountStatus.signedIn;
  }

  @override
  Future<void> disconnect(domain.ConnectedAccount account) => DropboxAuthStore(
    storageKey: AccountCredentialsStore.keyFor(account.id),
  ).clear();

  @override
  CloudStorageProvider syncProvider(domain.ConnectedAccount account) =>
      DropboxStorageProvider(
        authStore: DropboxAuthStore(
          storageKey: AccountCredentialsStore.keyFor(account.id),
        ),
      );

  @override
  Future<MediaObjectStore?> mediaObjectStore(
    domain.ConnectedAccount account,
  ) async {
    final auth = authManagerFor(account);
    if (await auth.loadAuth() == null) return null;
    return DropboxMediaObjectStore(
      client: DropboxApiClient(
        getAccessToken: auth.getAccessToken,
        onAccessTokenRejected: auth.invalidateAccessToken,
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/services/accounts/adapters/ test/core/services/cloud_storage/`
Expected: PASS (including any pre-existing store tests touched by the key generalization).

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/core/services/accounts/adapters/ lib/core/services/cloud_storage/ test/
git commit -m "feat(accounts): S3 and Dropbox account adapters with per-account keys"
```

---

### Task 8: Google Drive, iCloud, and Adobe Lightroom adapters

**Files:**
- Create: `lib/core/services/accounts/adapters/google_drive_account_adapter.dart`
- Create: `lib/core/services/accounts/adapters/icloud_account_adapter.dart`
- Create: `lib/core/services/accounts/adapters/lightroom_account_adapter.dart`
- Modify: `lib/core/services/lightroom/lightroom_auth_store.dart` (add optional `storageKey` ctor param, `defaultStorageKey = 'lightroom_auth'` — same edit as Task 7's stores)
- Test: `test/core/services/accounts/adapters/managed_account_adapters_test.dart`

**Interfaces:**
- Consumes: `GoogleDriveStorageProvider` + its `mediaHttpClient()` (line 157), `ICloudNativeService.getAvailability()`, `ICloudMediaObjectStore`/`NativeICloudMediaPlatform`, `AdobeImsAuthManager`, `LightroomAuthStore`, the singletons in `lib/features/settings/presentation/providers/sync_providers.dart` (`cloudProviderInstanceFor`).
- Produces: `GoogleDriveAccountAdapter implements SyncCapable, MediaStoreCapable` (session-managed: status from `isAuthenticated()`; single-instance kind); `ICloudAccountAdapter implements SyncCapable, MediaStoreCapable` (credential-less: status from availability; single-instance kind); `LightroomAccountAdapter implements MediaSourceCapable` with `AdobeImsAuthManager authManagerFor(account)`.

Key design facts for the implementer:
- Google auth is a `GoogleSignIn.instance` OS-managed session (`google_drive_storage_provider.dart:24`) — there is NO keychain blob to re-key. The adapter delegates to the existing provider singleton (`cloudProviderInstanceFor(CloudProviderType.googledrive)`); inject it via constructor for tests.
- iCloud has no credentials at all: `status()` maps `ICloudNativeService.getAvailability()` — `available` -> `signedIn`, anything else -> `unavailable`. `disconnect()` is a no-op.
- Lightroom: `AdobeImsAuthManager` currently reads the fixed-key `LightroomAuthStore`. Give `AdobeImsAuthManager` an injectable `LightroomAuthStore` if it lacks one (open `lib/core/services/lightroom/adobe_ims_auth_manager.dart` first and check its constructor), then `authManagerFor(account)` constructs one against `AccountCredentialsStore.keyFor(account.id)`.

- [ ] **Step 1: Write the failing tests**

In `managed_account_adapters_test.dart`, cover per adapter: `kind`, `status()` mapping (fake the injected provider/availability/auth store), and for Google/iCloud that `mediaObjectStore` returns null when the session/availability check fails. Use `extends Fake implements GoogleDriveStorageProvider` for the Google fake (repo convention for client doubles). For iCloud, inject the availability check as a `Future<ICloudAvailability> Function()` constructor seam rather than faking the static.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/accounts/adapters/managed_account_adapters_test.dart`
Expected: FAIL.

- [ ] **Step 3: Write the implementations**

```dart
// lib/core/services/accounts/adapters/icloud_account_adapter.dart
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/core/services/cloud_storage/icloud_storage_provider.dart';
import 'package:submersion/core/services/media_store/icloud_media_object_store.dart';
import 'package:submersion/core/services/media_store/icloud_media_platform.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';

/// The OS iCloud identity as a credential-less pseudo-account (program spec
/// open question 1, resolved: one implicit single-instance account). Status
/// is derived from container availability; disconnect is a no-op.
class ICloudAccountAdapter extends AccountProviderAdapter
    implements SyncCapable, MediaStoreCapable {
  ICloudAccountAdapter({
    Future<ICloudAvailability> Function()? availability,
    CloudStorageProvider? syncProviderInstance,
  }) : _availability = availability ?? ICloudNativeService.getAvailability,
       _syncProviderInstance = syncProviderInstance ?? ICloudStorageProvider();

  final Future<ICloudAvailability> Function() _availability;
  final CloudStorageProvider _syncProviderInstance;

  @override
  AccountKind get kind => AccountKind.icloud;

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async =>
      await _availability() == ICloudAvailability.available
      ? AccountStatus.signedIn
      : AccountStatus.unavailable;

  @override
  Future<void> disconnect(domain.ConnectedAccount account) async {}

  @override
  CloudStorageProvider syncProvider(domain.ConnectedAccount account) =>
      _syncProviderInstance;

  @override
  Future<MediaObjectStore?> mediaObjectStore(
    domain.ConnectedAccount account,
  ) async {
    if (await _availability() != ICloudAvailability.available) return null;
    return ICloudMediaObjectStore(platform: NativeICloudMediaPlatform());
  }
}
```

Google Drive adapter: same shape; constructor takes `GoogleDriveStorageProvider? provider` defaulting to `cloudProviderInstanceFor(CloudProviderType.googledrive) as GoogleDriveStorageProvider`; `status()` returns `signedIn` when `await provider.isAuthenticated()`, else `needsSignIn`; `syncProvider()` returns the provider; `mediaObjectStore()` mirrors `buildMediaObjectStore`'s googledrive arm (`media_store_service.dart:46-52`); `disconnect()` calls the provider's sign-out method (find it: `grep -n "signOut\|disconnect" lib/core/services/cloud_storage/google_drive_storage_provider.dart`).

Lightroom adapter:

```dart
// lib/core/services/accounts/adapters/lightroom_account_adapter.dart
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_auth_store.dart';

/// Adobe Lightroom logins as accounts (a media acquisition source, not a
/// sync/store backend). Auth blobs move to per-account keys; the manager
/// keeps its process-wide token cache semantics per account instance.
class LightroomAccountAdapter extends AccountProviderAdapter
    implements MediaSourceCapable {
  LightroomAccountAdapter({
    AdobeImsAuthManager Function(LightroomAuthStore store)? managerFactory,
  }) : _managerFactory =
           managerFactory ?? ((store) => AdobeImsAuthManager(store: store));

  final AdobeImsAuthManager Function(LightroomAuthStore store) _managerFactory;
  final Map<String, AdobeImsAuthManager> _managers = {};

  @override
  AccountKind get kind => AccountKind.adobeLightroom;

  /// Single-flight-refresh semantics require one manager per account for
  /// the process lifetime, so instances are cached by account id.
  AdobeImsAuthManager authManagerFor(domain.ConnectedAccount account) =>
      _managers.putIfAbsent(
        account.id,
        () => _managerFactory(
          LightroomAuthStore(
            storageKey: AccountCredentialsStore.keyFor(account.id),
          ),
        ),
      );

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async {
    final auth = await LightroomAuthStore(
      storageKey: AccountCredentialsStore.keyFor(account.id),
    ).load();
    return auth == null ? AccountStatus.needsSignIn : AccountStatus.signedIn;
  }

  @override
  Future<void> disconnect(domain.ConnectedAccount account) =>
      LightroomAuthStore(
        storageKey: AccountCredentialsStore.keyFor(account.id),
      ).clear();
}
```

(If `AdobeImsAuthManager`'s constructor has no `store:` parameter, add one — optional, defaulting to the current fixed-key store — exactly like the Task 7 store edits.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/accounts/adapters/ test/core/services/lightroom/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/services/accounts/adapters/ lib/core/services/lightroom/ test/
git commit -m "feat(accounts): Google Drive, iCloud, and Lightroom account adapters"
```

---

### Task 9: Registry provider + startup account migration

**Files:**
- Create: `lib/core/services/accounts/account_startup_migration.dart`
- Create: `lib/core/providers/account_providers.dart`
- Modify: `lib/core/presentation/pages/startup_page.dart:344` (add a `timeStartupStep` after `database`)
- Test: `test/core/services/accounts/account_startup_migration_test.dart`

**Interfaces:**
- Consumes: Tasks 4-8; `SyncRepository.getCloudProvider()` (`sync_repository.dart:306`) and `setCloudProvider`; `MediaStoreAttachState` (keys at `media_store_attach_state.dart:16-17`); legacy keychain keys `sync_s3_config`, `sync_dropbox_auth`, `media_store_s3_config`, `lightroom_auth`; `connector_accounts` rows via raw select; `EstablishedProviderStore` (`lib/core/services/sync/established_provider_store.dart`).
- Produces: `AccountStartupMigration.run()` — idempotent, guarded by SharedPreferences flag `accounts_migration_v1_done`; Riverpod providers `accountProviderRegistryProvider` (Provider<AccountProviderRegistry> assembling all five adapters) and `connectedAccountsRepositoryProvider`.

Migration rules (each skipped when the input is absent; the whole run is a no-op on second execution):

1. Sync provider: if `SyncRepository.getCloudProvider()` returns a type and no account of that kind exists, create `ConnectedAccount(kind: fromCloudProviderType(type), label: <provider display name>)`; write its id via `SyncRepository.setSyncAccountId` (added in Task 12 — for ordering, this migration writes the raw column with a Drift update here, or Task 12 lands before wiring; see Step 3 note). Re-key: s3 -> `rekeyFromLegacy(legacyKey: 'sync_s3_config', ...)`, dropbox -> `'sync_dropbox_auth'`. Google/iCloud have nothing to re-key. Carry the established flag: if `EstablishedProviderStore.contains(type.name)` then `add(accountId)`.
2. Media store: if `MediaStoreAttachState.attachedProviderType()` returns a type, ensure an account exists for it. For S3, ALWAYS create a separate account (do not reuse the sync S3 account: the configs are independent by design) with re-key from `'media_store_s3_config'`; for managed kinds reuse the kind's account from rule 1 or create one. Persist the account id under a new SharedPreferences key `media_store_account_id` (formalized in Task 10).
3. Lightroom: for each `connector_accounts` row with `connector_type = 'lightroom'`, create a ConnectedAccount with THE SAME id (preserves `LightroomConnectorState` SharedPreferences keying by account id and suggestion rows' `connectorAccountId`), `kind: adobeLightroom`, `label: displayName`, `accountIdentifier: accountIdentifier`; re-key from `'lightroom_auth'`.
4. Set the done-flag. Never delete legacy blobs or rows (rollback safety; `connector_accounts` is dropped later, in Task 13).

- [ ] **Step 1: Write the failing tests**

Cover: fresh install (nothing configured -> zero accounts, flag set); sync-S3-only; sync + separate media S3 (two distinct S3 accounts, both blobs re-keyed to different ids); Lightroom row id preservation; established-flag carry-over; and idempotence (run twice -> same account count, no duplicate rows). Use in-memory database + fake secure storage + in-memory SharedPreferences (`SharedPreferences.setMockInitialValues({})`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/accounts/account_startup_migration_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`AccountStartupMigration` takes all collaborators via constructor (repository, credentials store, attach state, sync repository, established store, prefs, and an `AppDatabase` for the raw `connector_accounts` select — query it with `customSelect('SELECT * FROM connector_accounts WHERE connector_type = ?', ...)` so this code survives Task 13's Drift-class removal). For rule 1's account-id write, use a raw Drift update on `syncMetadata.syncAccountId` here to avoid a forward dependency on Task 12:

```dart
await db.customStatement(
  'UPDATE sync_metadata SET sync_account_id = ? WHERE id = ?',
  [accountId, 'global'],
);
```

Wire into startup (`startup_page.dart`, after the `localCache` step, inside `coverage:ignore`):

```dart
    await timeStartupStep('accountMigration', () async {
      final prefs = await SharedPreferences.getInstance();
      await AccountStartupMigration(
        prefs: prefs,
        database: DatabaseService.instance.database,
      ).run();
    });
```

(Match the constructor you actually built; keep every other collaborator defaulted inside the class so the startup call stays two lines.)

`lib/core/providers/account_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/adapters/dropbox_account_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/google_drive_account_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/icloud_account_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/lightroom_account_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/s3_account_adapter.dart';

final connectedAccountsRepositoryProvider =
    Provider<ConnectedAccountsRepository>(
      (ref) => ConnectedAccountsRepository(),
    );

/// One adapter instance per kind for the process lifetime (token caches and
/// single-flight refresh live inside adapters).
final accountProviderRegistryProvider = Provider<AccountProviderRegistry>(
  (ref) => AccountProviderRegistry([
    S3AccountAdapter(),
    DropboxAccountAdapter(),
    GoogleDriveAccountAdapter(),
    ICloudAccountAdapter(),
    LightroomAccountAdapter(),
  ]),
);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/accounts/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/services/accounts/ lib/core/providers/account_providers.dart lib/core/presentation/pages/startup_page.dart test/
git commit -m "feat(accounts): startup migration seeds accounts from legacy config"
```

---

### Task 10: Media store attach state + store construction by account

**Files:**
- Modify: `lib/core/services/media_store/media_store_attach_state.dart`
- Modify: `lib/features/media_store/data/media_store_service.dart` (`buildMediaObjectStore`, lines 26-58)
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart` (the runtime provider's store construction — find with `grep -n "buildMediaObjectStore" lib/`)
- Test: extend `test/core/services/media_store/media_store_attach_state_test.dart` and the runtime-provider tests (locate: `grep -rln "attachedProviderType" test/`)

**Interfaces:**
- Produces: `MediaStoreAttachState.attachedAccountId()` / `setAttached(String storeId, {required CloudProviderType providerType, String? accountId})` with new key `static const String accountIdKey = 'media_store_account_id';` and `clear()` removing it; new top-level `Future<MediaObjectStore?> buildMediaObjectStoreForAccount(domain.ConnectedAccount account, AccountProviderRegistry registry)`.

- [ ] **Step 1: Write the failing tests**

```dart
test('setAttached persists and clear removes the account id', () async {
  await state.setAttached('store-1',
      providerType: CloudProviderType.s3, accountId: 'acc-9');
  expect(await state.attachedAccountId(), 'acc-9');
  await state.clear();
  expect(await state.attachedAccountId(), isNull);
});

test('legacy attachments read a null account id', () async {
  await state.setAttached('store-1', providerType: CloudProviderType.s3);
  expect(await state.attachedAccountId(), isNull);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/media_store/media_store_attach_state_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`MediaStoreAttachState` edit (full new members):

```dart
  static const String accountIdKey = 'media_store_account_id';

  Future<String?> attachedAccountId() async =>
      (await _resolved).getString(accountIdKey);

  Future<void> setAttached(
    String storeId, {
    required CloudProviderType providerType,
    String? accountId,
  }) async {
    final prefs = await _resolved;
    await prefs.setString(storeIdKey, storeId);
    await prefs.setString(providerTypeKey, providerType.name);
    if (accountId != null) {
      await prefs.setString(accountIdKey, accountId);
    } else {
      await prefs.remove(accountIdKey);
    }
  }
```

Add `await prefs.remove(accountIdKey);` to `clear()`.

New account-first builder in `media_store_service.dart` (keep the legacy `buildMediaObjectStore` intact — the runtime falls back to it for pre-migration attachments):

```dart
/// Account-first store construction: resolve the account's
/// MediaStoreCapable adapter. Null when the kind lacks the capability or
/// this device has no working credentials for the account.
Future<MediaObjectStore?> buildMediaObjectStoreForAccount(
  domain.ConnectedAccount account,
  AccountProviderRegistry registry,
) async {
  final capable = registry.capabilityFor<MediaStoreCapable>(account.kind);
  if (capable == null) return null;
  return capable.mediaObjectStore(account);
}
```

In the runtime provider (`media_store_providers.dart`), where the store is currently built from `attachedProviderType()` + credentials: first read `attachedAccountId()`; when non-null, load the account via `connectedAccountsRepositoryProvider` and build through `buildMediaObjectStoreForAccount(account, ref.read(accountProviderRegistryProvider))`; when null (legacy attachment), keep the existing path byte-for-byte. Preserve the existing preflight semantics (storeId match, suspend on mismatch) unchanged.

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/services/media_store/ test/features/media_store/`
Expected: PASS (legacy-path tests untouched and green).

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/services/media_store/ lib/features/media_store/ test/
git commit -m "feat(accounts): media store attach state and construction by account"
```

---

### Task 11: MediaStoreService connects through accounts

**Files:**
- Modify: `lib/features/media_store/data/media_store_service.dart` (connect flows, lines 166-235)
- Modify: the settings-page call sites (`grep -rn "connectS3\|connectDropbox\|connectGoogleDrive\|connectICloud" lib/features/media_store/presentation/`)
- Test: `test/features/media_store/data/media_store_service_test.dart` (extend the existing file)

**Interfaces:**
- Consumes: Tasks 4-10.
- Produces: `connectS3(S3Config config, {String? accountId})` and `_connectManaged(..., {String? accountId})` — every connect flow now (a) ensures a ConnectedAccount row exists (creating one via an injected `ConnectedAccountsRepository`), (b) writes credentials to the per-account key (S3: via `AccountCredentialsStore`; managed kinds: nothing to write), (c) passes `accountId:` to `setAttached`. `MediaStoreService` constructor gains `required ConnectedAccountsRepository accountsRepository, AccountCredentialsStore? accountCredentials`.

Behavior contract (assert in tests):
- `connectS3` with no `accountId` creates a fresh `AccountKind.s3` account labeled `'${config.bucket} @ ${config.displayHost}'`, saves the config JSON under the per-account key, AND still calls `_credentials.save(config)` (legacy blob) so a rollback build keeps working.
- `connectDropbox()` resolves the `AccountKind.dropbox` account (creating the row if the kind has none) and re-keys `sync_dropbox_auth` to it when the per-account blob is absent — covers a user who linked Dropbox sync before the accounts migration existed, then connects media storage.
- `disconnect()` additionally removes `media_store_account_id` (via `clear()` from Task 10) but never deletes the account row or its credentials — the account may still drive sync.

- [ ] **Step 1: Write failing tests** for the three contract bullets, extending the existing service test file's fakes (it already fakes stores and attach state — reuse; add an in-memory `ConnectedAccountsRepository` over a test database).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media_store/data/media_store_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** the constructor/flow changes described in the interface block. Settings-page call sites only add the new constructor argument (`accountsRepository: ref.read(connectedAccountsRepositoryProvider)`).

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/media_store/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/media_store/ test/features/media_store/
git commit -m "feat(accounts): media store connect flows create and use accounts"
```

---

### Task 12: Sync selection by account

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart` (next to `setCloudProvider`/`getCloudProvider`, lines 281-314)
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (`selectedCloudProviderTypeProvider` consumers at line 231, `cloudStorageProviderProvider` at line 262)
- Test: `test/core/data/repositories/sync_repository_account_test.dart`; extend the provider tests (`grep -rln "cloudStorageProviderProvider" test/ | head -3`)

**Interfaces:**
- Consumes: Tasks 4, 6-9; `syncMetadata.syncAccountId` column (Task 2).
- Produces:
  - `SyncRepository.setSyncAccount({required String accountId, required CloudProviderType providerType})` — writes BOTH `syncAccountId` and `syncProvider` (compat) in one update.
  - `SyncRepository.getSyncAccountId() -> Future<String?>`.
  - Provider `selectedSyncAccountProvider = StateProvider<domain.ConnectedAccount?>((ref) => null)` in `sync_providers.dart`.
  - `cloudStorageProviderProvider` resolves account-first: when `selectedSyncAccountProvider` holds an account whose kind has `SyncCapable`, the raw provider comes from `registry.capabilityFor<SyncCapable>(kind).syncProvider(account)`; otherwise the existing `selectedCloudProviderTypeProvider` path runs unchanged (legacy fallback). The encryption wrap (lines 273-284) applies identically in both paths.
  - A shim used by the existing settings UI: `Future<domain.ConnectedAccount> ensureAccountForProviderType(CloudProviderType type, ConnectedAccountsRepository repo)` (top-level in `sync_providers.dart`) — returns `getByKind` or creates the row; the UI's provider-selection handler calls it and sets BOTH state providers, so today's screens drive the account model without UI changes.

Startup restore: wherever `selectedCloudProviderTypeProvider` is initialized from `getCloudProvider()` at app start (find with `grep -n "selectedCloudProviderTypeProvider" lib/features/settings/presentation/providers/sync_providers.dart` — the restore block near line 437), also read `getSyncAccountId()`, load the account row, and seed `selectedSyncAccountProvider`.

Established-provider/cursor keying: account-driven syncs pass `account.id` as the providerId-like key to `EstablishedProviderStore` and `getLastSyncTime(forProvider:)` call sites ONLY where those call sites already take a variable providerId — do NOT change `CloudStorageProvider.providerId` itself in Phase 1 (the migration in Task 9 already carried the established flag to the account id; a missing per-account cursor is safe — it reads as first contact, which the existing gate handles). If inspection shows cursor call sites take `provider.providerId` directly, add an optional override parameter threaded from the sync service's active account; keep the legacy value when no account is selected.

- [ ] **Step 1: Write failing tests** — `setSyncAccount` writes both columns and `getSyncAccountId` round-trips; `cloudStorageProviderProvider` returns the adapter-built provider when an S3 account is selected (fake registry) and falls back to the legacy path when only the type is set.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/data/repositories/sync_repository_account_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** per the interface block.

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/data/repositories/sync_repository_account_test.dart test/features/settings/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/data/repositories/ lib/features/settings/ test/
git commit -m "feat(accounts): sync selects its backend through a connected account"
```

---

### Task 13: Lightroom on connected accounts; retire connector_accounts

**Files:**
- Modify: `lib/features/media/presentation/providers/lightroom_providers.dart` (lines 26-55)
- Modify: `lib/features/media/data/services/lightroom_connector_state.dart` (only if it imports the old entity)
- Modify: consumers of `domain.ConnectorAccount` (`grep -rln "connector_account.dart" lib/`) — switch to `ConnectedAccount` from Task 1 (field mapping: `displayName` -> `label`, `connectorType` -> `kind`; `baseUrl` had no non-null Lightroom use — verify with `grep -rn "baseUrl" lib/features/media/ lib/core/services/lightroom/`)
- Delete: `lib/features/media/data/repositories/connector_accounts_repository.dart`, `lib/features/media/domain/entities/connector_account.dart`
- Modify: `lib/core/database/database.dart` — remove the `ConnectorAccounts` Drift class (line 1018) from the class and the `@DriftDatabase` list; add to the v107 migration block (BEFORE the DDL assert helper's table creation is fine, order within the block: copy rows first, then drop):

```dart
        if (from < 107) {
          await _assertConnectedAccountsSchema();
          // Adopt Lightroom connector accounts (ids preserved: scan state
          // and suggestion rows key on them), then retire the table.
          await customStatement(
            "INSERT OR IGNORE INTO connected_accounts "
            "(id, kind, label, account_identifier, created_at, updated_at) "
            "SELECT id, 'adobeLightroom', display_name, account_identifier, "
            "added_at, added_at FROM connector_accounts "
            "WHERE connector_type = 'lightroom'",
          );
          await customStatement('DROP TABLE IF EXISTS connector_accounts');
        }
```

  Guard the copy for fresh installs (table absent): wrap both statements in a check that `connector_accounts` exists (`SELECT name FROM sqlite_master WHERE type='table' AND name='connector_accounts'`). Task 9's migration service must then tolerate the table being gone (its raw select already needs the same existence check — revisit it in this task and add the guard there too).
- Modify: `test/` files referencing `ConnectorAccountsRepository` (`grep -rln "ConnectorAccountsRepository\|connector_accounts" test/`)
- Test: extend `test/core/database/connected_accounts_migration_test.dart` with the adopt-and-drop case (insert a connector_accounts row in a v106-shaped database, upgrade, assert the connected_accounts row exists with the same id and the old table is gone — copy the v106 test's old-schema bootstrap technique)

**Interfaces:**
- Consumes: Tasks 1, 4, 8, 9.
- Produces: `lightroomAccountProvider` now `FutureProvider<domain.ConnectedAccount?>` backed by `ConnectedAccountsRepository.getByKind(AccountKind.adobeLightroom)`; `lightroomAuthManagerProvider` becomes `Provider.family<AdobeImsAuthManager, String>` keyed by account id, delegating to `LightroomAccountAdapter.authManagerFor` via the registry (`ref.watch(accountProviderRegistryProvider).adapterFor(AccountKind.adobeLightroom) as LightroomAccountAdapter`); connect/disconnect flows in `lightroom_settings_page.dart` create/delete roster rows through the repository and write tokens via the per-account store.

- [ ] **Step 1: Write the failing migration test** (adopt-and-drop case above).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/database/connected_accounts_migration_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** — database change first, `dart run build_runner build --delete-conflicting-outputs`, then the provider/consumer rewiring, then delete the two retired files and fix every compile error the deletions surface (the compiler is the checklist; do not leave a shim).

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/database/connected_accounts_migration_test.dart test/features/media/ test/core/services/lightroom/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A lib test
git commit -m "feat(accounts): Lightroom rides connected accounts; retire connector_accounts"
```

---

### Task 14: Full verification sweep

**Files:** none new.

- [ ] **Step 1: Format and analyze**

Run: `dart format .` then `flutter analyze`
Expected: no formatting diffs, zero analyzer issues (whole project, no output piping).

- [ ] **Step 2: Run the affected suites in batches** (per-file batching per repo convention)

```bash
flutter test test/core/services/accounts/ test/core/data/repositories/
flutter test test/core/database/ test/core/services/sync/
flutter test test/features/media_store/ test/features/media/
flutter test test/features/settings/
```

Expected: ALL PASS.

- [ ] **Step 3: Manual smoke checklist (deferred to device time, record as pending)**

- Fresh install: no accounts, everything behaves as before.
- Upgrade with existing sync-S3 + media-S3 + Lightroom: two S3 accounts + one Lightroom account appear; sync, media store, and Lightroom all work without re-authentication.
- Media storage attached through a Dropbox account while sync runs on iCloud (the decoupling this phase exists for).

- [ ] **Step 4: Final commit and wrap-up**

```bash
git status   # confirm clean or only intended changes
```

Use the finishing-a-development-branch skill (PR per repo conventions: no attribution lines, substantive summary only).

---

## Self-review notes (spec coverage)

- Spec 5 "synced secret-free table (v107)": Tasks 2-4. "Per-account keychain": Task 5. "Registry + capabilities": Task 6. "Adapter refactor of six auth surfaces": Tasks 7-8 (sync S3 + media S3 are both the S3 adapter with different account rows). "Rewire Media Storage": Tasks 10-11. "Rewire Data Sync": Task 12. "Migration, no re-auth": Task 9. "Retire connector_accounts": Task 13.
- Deliberately deferred to later phases: any UI for account management (Phase 3), device-B prompts (Phase 2), syncing Lightroom scan config (Phase 2).
- Known judgment calls encoded: legacy keychain blobs are copied, never deleted; `buildMediaObjectStore` legacy path retained for pre-migration attachments; `CloudStorageProvider.providerId` untouched in Phase 1.
