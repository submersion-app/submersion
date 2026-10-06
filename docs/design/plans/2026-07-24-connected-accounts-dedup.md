# Connected Accounts Deduplication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop `connected_accounts` from accumulating duplicate rows for the same endpoint, and collapse the duplicates that already exist.

**Architecture:** Give accounts a deterministic UUIDv5 id derived from `kind` plus a natural key (S3: host/bucket/prefix; managed kinds: the kind name). The primary key then becomes the uniqueness constraint, so two devices connecting the same endpoint compute the same id and sync's upsert-by-id merges them. A repository `ensure()` replaces every unguarded `create()` call site, and a startup pass migrates the rows that sync metadata and the media-store pref actually point at onto their canonical ids, then deletes the inert leftovers.

**Tech Stack:** Dart / Flutter, Drift ORM, Riverpod, `uuid` package, `flutter_secure_storage`, `shared_preferences`, `flutter_test`.

Spec: `docs/superpowers/specs/2026-07-24-connected-accounts-dedup-design.md`

## Global Constraints

- No database schema change and no schema version bump. No new column, no unique index.
- `AccountKind.adobeLightroom` is excluded from every part of this work. Lightroom ids were preserved by the v107 migration because scan state and suggestion rows key on them.
- `kConnectedAccountNamespace` is `'c622faae-974f-4310-a5e7-36c2fb773684'` and must never change.
- Never delete legacy keychain blobs. Migration copies rather than moves (rollback safety), matching `AccountStartupMigration`.
- All Dart code must pass `dart format .` with no changes.
- No emojis in code, comments, or documentation.
- Run `dart format .` and `flutter analyze` before every commit. `flutter analyze` must be run on the whole project and must not be piped through `tail` or `head`.
- Commit messages must not contain a `Co-Authored-By:` trailer.

## File Structure

| File | Responsibility |
| ---- | -------------- |
| `lib/core/services/accounts/account_identity.dart` (create) | Namespace constant, natural-key builders, deterministic id function. Pure, no I/O. |
| `lib/core/data/repositories/connected_accounts_repository.dart` (modify) | Add `ensure()`. No other behaviour change. |
| `lib/features/media_store/data/media_store_service.dart` (modify) | Route the two account-creating paths through `ensure()`. |
| `lib/features/settings/presentation/providers/sync_providers.dart` (modify) | Route `ensureAccountForProviderType` through `ensure()`. |
| `lib/core/services/accounts/account_startup_migration.dart` (modify) | Route its three `create()` calls through `ensure()`. |
| `lib/core/services/accounts/account_deduplicator.dart` (create) | One-purpose startup pass: canonicalize anchors, delete inert rows. |
| `lib/core/presentation/pages/startup_page.dart` (modify) | Run the deduplicator after the account migration. |

---

### Task 1: Deterministic account identity

**Files:**
- Create: `lib/core/services/accounts/account_identity.dart`
- Test: `test/core/services/accounts/account_identity_test.dart`

**Interfaces:**
- Consumes: `AccountKind` from `lib/core/services/accounts/account_kind.dart`, `S3Config` from `lib/core/services/cloud_storage/s3/s3_config.dart`.
- Produces:
  - `const String kConnectedAccountNamespace`
  - `String s3NaturalKey(S3Config config)`
  - `String? naturalKeyForKind(AccountKind kind)` — returns null for `s3` (needs a config) and `adobeLightroom` (excluded)
  - `String accountIdFor({required AccountKind kind, required String naturalKey})`

- [ ] **Step 1: Write the failing test**

Create `test/core/services/accounts/account_identity_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';

void main() {
  S3Config config({
    String endpoint = 'https://minio.local',
    String region = 'us-east-1',
    String bucket = 'dive-media',
    String prefix = 'submersion-sync/',
  }) => S3Config(
    endpoint: endpoint,
    region: region,
    bucket: bucket,
    prefix: prefix,
    accessKeyId: 'AK',
    secretAccessKey: 'SK',
  );

  String idFor(S3Config c) =>
      accountIdFor(kind: AccountKind.s3, naturalKey: s3NaturalKey(c));

  test('same endpoint yields the same id', () {
    expect(idFor(config()), idFor(config()));
  });

  test('id is stable across credential rotation', () {
    final rotated = S3Config(
      endpoint: 'https://minio.local',
      bucket: 'dive-media',
      prefix: 'submersion-sync/',
      accessKeyId: 'ROTATED',
      secretAccessKey: 'ROTATED',
    );
    expect(idFor(config()), idFor(rotated));
  });

  test('a different prefix is a different account', () {
    expect(idFor(config()), isNot(idFor(config(prefix: 'media/'))));
  });

  test('a different bucket is a different account', () {
    expect(idFor(config()), isNot(idFor(config(bucket: 'other'))));
  });

  test('AWS-proper and an explicit AWS endpoint agree', () {
    final implicit = config(endpoint: '', region: 'eu-west-1');
    final explicit = config(
      endpoint: 'https://s3.eu-west-1.amazonaws.com',
      region: 'eu-west-1',
    );
    expect(idFor(implicit), idFor(explicit));
  });

  test('a trailing slash on the endpoint does not change the id', () {
    expect(idFor(config()), idFor(config(endpoint: 'https://minio.local/')));
  });

  test('managed kinds are single-instance per kind', () {
    for (final kind in [
      AccountKind.icloud,
      AccountKind.dropbox,
      AccountKind.googledrive,
    ]) {
      final key = naturalKeyForKind(kind);
      expect(key, isNotNull, reason: '$kind must have a natural key');
      expect(
        accountIdFor(kind: kind, naturalKey: key!),
        accountIdFor(kind: kind, naturalKey: key),
      );
    }
  });

  test('different kinds never collide', () {
    final ids = {
      for (final kind in [
        AccountKind.icloud,
        AccountKind.dropbox,
        AccountKind.googledrive,
      ])
        accountIdFor(kind: kind, naturalKey: naturalKeyForKind(kind)!),
    };
    expect(ids.length, 3);
  });

  test('s3 and lightroom have no kind-only natural key', () {
    expect(naturalKeyForKind(AccountKind.s3), isNull);
    expect(naturalKeyForKind(AccountKind.adobeLightroom), isNull);
  });

  test('the namespace constant is frozen', () {
    expect(kConnectedAccountNamespace, 'c622faae-974f-4310-a5e7-36c2fb773684');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/services/accounts/account_identity_test.dart`
Expected: FAIL — `Error: Error when reading 'lib/core/services/accounts/account_identity.dart': No such file or directory`.

- [ ] **Step 3: Write the implementation**

Create `lib/core/services/accounts/account_identity.dart`:

```dart
import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';

/// Namespace for deterministic connected-account ids. Frozen: every device
/// must derive the same id from the same endpoint, so changing this would
/// fork the roster across the fleet.
const String kConnectedAccountNamespace =
    'c622faae-974f-4310-a5e7-36c2fb773684';

/// Endpoint identity for an S3 account.
///
/// Uses [S3Config.displayHost] rather than the raw endpoint so AWS-proper
/// (empty endpoint, host derived from the region) and an explicit AWS
/// endpoint for one bucket resolve to a single account. Includes the prefix
/// so the sync and media-store roles stay separate accounts when they share
/// a bucket. Credentials are deliberately excluded: rotating a key must not
/// mint a new account.
String s3NaturalKey(S3Config config) =>
    '${config.displayHost}|${config.bucket}|${config.prefix}';

/// Natural key for a kind that can only have one instance per library.
///
/// Null for [AccountKind.s3] (an instance kind: use [s3NaturalKey]) and for
/// [AccountKind.adobeLightroom], whose ids are preserved from the v107
/// migration because Lightroom scan state and suggestion rows key on them.
String? naturalKeyForKind(AccountKind kind) => switch (kind) {
  AccountKind.icloud ||
  AccountKind.dropbox ||
  AccountKind.googledrive => kind.name,
  AccountKind.s3 || AccountKind.adobeLightroom => null,
};

/// The deterministic id for an endpoint.
///
/// Two devices computing this for the same endpoint get the same primary
/// key, so sync's upsert-by-id merges them instead of unioning two rows.
/// This is why no unique index is needed: a unique constraint on a
/// replicated table would make an inbound sync insert throw rather than
/// merge.
String accountIdFor({required AccountKind kind, required String naturalKey}) =>
    const Uuid().v5(kConnectedAccountNamespace, '${kind.name}:$naturalKey');
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/services/accounts/account_identity_test.dart`
Expected: PASS, 10 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/services/accounts/account_identity.dart test/core/services/accounts/account_identity_test.dart
git commit -m "feat(accounts): add deterministic connected-account identity

Derives an account id from kind plus a natural key (S3 host/bucket/prefix,
kind name for single-instance managed kinds) via UUIDv5 under a frozen
namespace, so every device computes the same primary key for the same
endpoint. Lightroom is excluded: its ids are preserved from v107."
```

---

### Task 2: Repository `ensure()`

**Files:**
- Modify: `lib/core/data/repositories/connected_accounts_repository.dart`
- Test: `test/core/data/repositories/connected_accounts_repository_test.dart` (exists, append)

**Interfaces:**
- Consumes: `accountIdFor` from Task 1.
- Produces: `Future<ConnectedAccount> ConnectedAccountsRepository.ensure({required AccountKind kind, required String naturalKey, required String label})`.

- [ ] **Step 1: Write the failing test**

Append inside the existing `main()` in `test/core/data/repositories/connected_accounts_repository_test.dart`, after the last existing `test(...)` block:

```dart
  test('ensure is idempotent: two calls yield one row', () async {
    final first = await repo.ensure(
      kind: AccountKind.s3,
      naturalKey: 'minio.local|dive-media|media/',
      label: 'dive-media @ minio.local',
    );
    final second = await repo.ensure(
      kind: AccountKind.s3,
      naturalKey: 'minio.local|dive-media|media/',
      label: 'dive-media @ minio.local',
    );
    expect(second.id, first.id);
    expect((await repo.getAll()).length, 1);
  });

  test('ensure uses the deterministic id', () async {
    final account = await repo.ensure(
      kind: AccountKind.icloud,
      naturalKey: 'icloud',
      label: 'iCloud',
    );
    expect(
      account.id,
      accountIdFor(kind: AccountKind.icloud, naturalKey: 'icloud'),
    );
  });

  test('ensure refreshes a drifted label in place', () async {
    final first = await repo.ensure(
      kind: AccountKind.s3,
      naturalKey: 'minio.local|dive-media|media/',
      label: 'old label',
    );
    final second = await repo.ensure(
      kind: AccountKind.s3,
      naturalKey: 'minio.local|dive-media|media/',
      label: 'new label',
    );
    expect(second.id, first.id);
    expect(second.label, 'new label');
    final all = await repo.getAll();
    expect(all.length, 1);
    expect(all.single.label, 'new label');
  });

  test('ensure separates two prefixes in one bucket', () async {
    final sync = await repo.ensure(
      kind: AccountKind.s3,
      naturalKey: 'minio.local|shared|submersion-sync/',
      label: 'shared @ minio.local',
    );
    final media = await repo.ensure(
      kind: AccountKind.s3,
      naturalKey: 'minio.local|shared|media/',
      label: 'shared @ minio.local',
    );
    expect(media.id, isNot(sync.id));
    expect((await repo.getAll()).length, 2);
  });
```

Add this import to the test file's import block:

```dart
import 'package:submersion/core/services/accounts/account_identity.dart';
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/data/repositories/connected_accounts_repository_test.dart`
Expected: FAIL — `The method 'ensure' isn't defined for the class 'ConnectedAccountsRepository'`.

- [ ] **Step 3: Write the implementation**

In `lib/core/data/repositories/connected_accounts_repository.dart`, add this import next to the existing account imports:

```dart
import 'package:submersion/core/services/accounts/account_identity.dart';
```

Then insert this method immediately after `create()`:

```dart
  /// Find-or-create by deterministic id.
  ///
  /// The id IS the dedup mechanism: it collides for the same endpoint on
  /// every device, so sync's upsert-by-id merges rather than duplicating.
  /// Callers on write paths must use this instead of [create]; [getByKind]
  /// is a local-only query and cannot dedup a replicated table.
  ///
  /// A drifted [label] (renamed bucket, changed host spelling) is refreshed
  /// in place rather than minting a row.
  Future<domain.ConnectedAccount> ensure({
    required AccountKind kind,
    required String naturalKey,
    required String label,
  }) async {
    final id = accountIdFor(kind: kind, naturalKey: naturalKey);
    final existing = await getById(id);
    if (existing == null) {
      return create(kind: kind, label: label, id: id);
    }
    if (existing.label == label) return existing;
    await updateLabels(id, label: label);
    return existing.copyWith(label: label);
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/data/repositories/connected_accounts_repository_test.dart`
Expected: PASS, including the pre-existing tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/data/repositories/connected_accounts_repository.dart test/core/data/repositories/connected_accounts_repository_test.dart
git commit -m "feat(accounts): add ConnectedAccountsRepository.ensure

Find-or-create keyed on the deterministic id, refreshing a drifted label in
place. Write paths use this instead of create so the primary key does the
deduplication."
```

---

### Task 3: Route the media store through `ensure()`

**Files:**
- Modify: `lib/features/media_store/data/media_store_service.dart:206-214` (S3) and `:277-279` (managed)
- Test: `test/features/media_store/media_store_service_test.dart` (exists, modify one test and append two)

**Interfaces:**
- Consumes: `ensure()` from Task 2, `s3NaturalKey` / `naturalKeyForKind` from Task 1.
- Produces: no new public API. `connectS3` and `_connectManaged` keep their existing signatures and return types.

- [ ] **Step 1: Write the failing test**

In `test/features/media_store/media_store_service_test.dart`, replace the existing test named `connectS3 against an existing store adopts its storeId` with:

```dart
  test('connectS3 against an existing store adopts its storeId', () async {
    final first = await service.connectS3(config);
    await service.disconnect();
    final second = await service.connectS3(config);
    expect(second.createdNewStore, isFalse);
    expect(second.storeId, first.storeId);
  });

  test('connectS3 twice reuses one account row', () async {
    await service.connectS3(config);
    await service.connectS3(config);
    final accounts = await accountsRepository.getAll();
    expect(accounts.length, 1);
    expect(accounts.single.kind, AccountKind.s3);
  });

  test('connectS3 uses the deterministic account id', () async {
    await service.connectS3(config);
    final accounts = await accountsRepository.getAll();
    expect(
      accounts.single.id,
      accountIdFor(kind: AccountKind.s3, naturalKey: s3NaturalKey(config)),
    );
  });

  test('connectS3 keeps two prefixes in one bucket separate', () async {
    await service.connectS3(config);
    final otherPrefix = S3Config(
      endpoint: config.endpoint,
      region: config.region,
      bucket: config.bucket,
      prefix: 'a-different-prefix/',
      accessKeyId: config.accessKeyId,
      secretAccessKey: config.secretAccessKey,
    );
    await service.connectS3(otherPrefix);
    expect((await accountsRepository.getAll()).length, 2);
  });
```

Add these imports to the test file if not already present:

```dart
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/media_store/media_store_service_test.dart`
Expected: `connectS3 twice reuses one account row` FAILS with `Expected: <1> Actual: <2>`; `connectS3 uses the deterministic account id` FAILS on a random UUID.

- [ ] **Step 3: Write the implementation**

In `lib/features/media_store/data/media_store_service.dart`, add the import:

```dart
import 'package:submersion/core/services/accounts/account_identity.dart';
```

Replace the account resolution inside `connectS3` (currently lines 206-214) with:

```dart
      // Reuse the given account (only when it really is an S3 account:
      // attaching S3 credentials under another kind's keychain key would
      // corrupt that account), else resolve the endpoint to its
      // deterministic account. The endpoint key includes the prefix, so a
      // bare connect still never adopts the sync S3 account when sync uses
      // a different prefix in the same bucket.
      final requested = accountId == null
          ? null
          : await _accounts.getById(accountId);
      final account = (requested != null && requested.kind == AccountKind.s3)
          ? requested
          : await _accounts.ensure(
              kind: AccountKind.s3,
              naturalKey: s3NaturalKey(config),
              label: '${config.bucket} @ ${config.displayHost}',
            );
```

Replace the account resolution inside `_connectManaged` (currently lines 276-279) with:

```dart
    final kind = AccountKind.fromCloudProviderType(type);
    // Single-instance per kind, resolved to the deterministic id so two
    // devices connecting the same provider converge on one row instead of
    // each minting its own (getByKind dedups only locally).
    final account = await _accounts.ensure(
      kind: kind,
      naturalKey: naturalKeyForKind(kind)!,
      label: displayHint,
    );
```

The `!` is safe here: `_connectManaged` is only reached for `dropbox`, `googledrive` and `icloud`, all of which `naturalKeyForKind` answers non-null. S3 uses `connectS3`, and Lightroom has no `CloudProviderType`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/media_store/media_store_service_test.dart`
Expected: PASS, all tests including the pre-existing ones.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/media_store/data/media_store_service.dart test/features/media_store/media_store_service_test.dart
git commit -m "fix(media-store): stop minting a new account on every connect

connectS3 created an account row unconditionally, so every connect to the
same bucket added a duplicate; _connectManaged deduped via getByKind, which
is local-only and cannot converge a sync-replicated table. Both now resolve
the endpoint to its deterministic account id."
```

---

### Task 4: Route sync provider selection through `ensure()`

**Files:**
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart:257-280`
- Test: `test/features/settings/presentation/providers/sync_providers_account_dedup_test.dart` (create)

**Interfaces:**
- Consumes: `ensure()` from Task 2, `s3NaturalKey` / `naturalKeyForKind` from Task 1, `S3CredentialsStore` from `lib/core/services/cloud_storage/s3/s3_credentials_store.dart`.
- Produces: `ensureAccountForProviderType` gains one optional named parameter, `S3CredentialsStore? s3Credentials`. Full signature after this task:

```dart
Future<domain.ConnectedAccount> ensureAccountForProviderType(
  CloudProviderType type,
  ConnectedAccountsRepository repo, {
  SyncRepository? syncRepository,
  S3CredentialsStore? s3Credentials,
})
```

- [ ] **Step 1: Write the failing test**

Create `test/features/settings/presentation/providers/sync_providers_account_dedup_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../../../support/fake_keychain_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ConnectedAccountsRepository repo;
  late InMemoryKeychain keychain;
  late S3CredentialsStore s3Credentials;

  final config = S3Config(
    endpoint: 'https://minio.local',
    bucket: 'dive-sync',
    prefix: 'submersion-sync/',
    accessKeyId: 'AK',
    secretAccessKey: 'SK',
  );

  setUp(() async {
    db = await setUpTestDatabase();
    repo = ConnectedAccountsRepository();
    keychain = InMemoryKeychain();
    s3Credentials = S3CredentialsStore(storage: keychain);
    await SyncRepository().getOrCreateMetadata();
  });

  tearDown(() => tearDownTestDatabase());

  test('flipping S3 to iCloud and back reuses one S3 row', () async {
    await s3Credentials.save(config);

    final s3First = await ensureAccountForProviderType(
      CloudProviderType.s3,
      repo,
      s3Credentials: s3Credentials,
    );
    await SyncRepository().setSyncAccount(
      accountId: s3First.id,
      providerType: CloudProviderType.s3,
    );

    final icloud = await ensureAccountForProviderType(
      CloudProviderType.icloud,
      repo,
      s3Credentials: s3Credentials,
    );
    await SyncRepository().setSyncAccount(
      accountId: icloud.id,
      providerType: CloudProviderType.icloud,
    );

    final s3Second = await ensureAccountForProviderType(
      CloudProviderType.s3,
      repo,
      s3Credentials: s3Credentials,
    );

    expect(s3Second.id, s3First.id);
    final all = await repo.getAll();
    expect(all.where((a) => a.kind == AccountKind.s3).length, 1);
    expect(all.where((a) => a.kind == AccountKind.icloud).length, 1);
  });

  test('the S3 account uses the deterministic id', () async {
    await s3Credentials.save(config);
    final account = await ensureAccountForProviderType(
      CloudProviderType.s3,
      repo,
      s3Credentials: s3Credentials,
    );
    expect(
      account.id,
      accountIdFor(kind: AccountKind.s3, naturalKey: s3NaturalKey(config)),
    );
  });

  test('an unreadable S3 config still yields an account', () async {
    final account = await ensureAccountForProviderType(
      CloudProviderType.s3,
      repo,
      s3Credentials: s3Credentials,
    );
    expect(account.kind, AccountKind.s3);
    expect((await repo.getAll()).length, 1);
  });

  test('iCloud selected twice reuses one row', () async {
    final first = await ensureAccountForProviderType(
      CloudProviderType.icloud,
      repo,
      s3Credentials: s3Credentials,
    );
    final second = await ensureAccountForProviderType(
      CloudProviderType.icloud,
      repo,
      s3Credentials: s3Credentials,
    );
    expect(second.id, first.id);
    expect((await repo.getAll()).length, 1);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/settings/presentation/providers/sync_providers_account_dedup_test.dart`
Expected: FAIL — `No named parameter with the name 's3Credentials'`.

- [ ] **Step 3: Write the implementation**

In `lib/features/settings/presentation/providers/sync_providers.dart`, add the import:

```dart
import 'package:submersion/core/services/accounts/account_identity.dart';
```

Replace the whole of `ensureAccountForProviderType` (currently lines 257-280) with:

```dart
Future<domain.ConnectedAccount> ensureAccountForProviderType(
  CloudProviderType type,
  ConnectedAccountsRepository repo, {
  SyncRepository? syncRepository,
  S3CredentialsStore? s3Credentials,
}) async {
  final kind = AccountKind.fromCloudProviderType(type);
  final persistedId = await (syncRepository ?? SyncRepository())
      .getSyncAccountId();
  if (persistedId != null) {
    final persisted = await repo.getById(persistedId);
    if (persisted != null && persisted.kind == kind) return persisted;
  }
  if (kind == AccountKind.s3) {
    // S3 accounts are instances, so the endpoint identifies them. Read the
    // legacy config (the source of truth on this path, mirrored by
    // _mirrorLegacyCredentials) to derive that identity. Without it, fall
    // back to a fresh row: an account with no resolvable endpoint cannot be
    // matched to any other, and the deduplicator will canonicalize it once
    // the config is readable.
    final config = await (s3Credentials ?? S3CredentialsStore()).load();
    if (config == null) {
      return repo.create(
        kind: kind,
        label: cloudProviderInstanceFor(type).providerName,
      );
    }
    return repo.ensure(
      kind: kind,
      naturalKey: s3NaturalKey(config),
      label: '${config.bucket} @ ${config.displayHost}',
    );
  }
  return repo.ensure(
    kind: kind,
    naturalKey: naturalKeyForKind(kind)!,
    label: cloudProviderInstanceFor(type).providerName,
  );
}
```

Note the deliberate label change on the S3 branch: it now matches the media store's `bucket @ host` form, which is what already appears in existing rows, instead of the generic provider name.

Update the one caller inside `selectedSyncAccountProvider` (currently line 305) to pass nothing new — it keeps working unchanged because `s3Credentials` is optional and defaults to the real store.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/settings/presentation/providers/sync_providers_account_dedup_test.dart`
Expected: PASS, 4 tests.

Then run the neighbouring suites to confirm nothing regressed:

Run: `flutter test test/features/settings/presentation/providers/`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/settings/presentation/providers/sync_providers.dart test/features/settings/presentation/providers/sync_providers_account_dedup_test.dart
git commit -m "fix(sync): reuse the S3 account when the provider type flips

ensureAccountForProviderType created a fresh S3 row whenever the persisted
sync account was of another kind, so every S3 to iCloud and back round trip
added a duplicate. It now derives the endpoint identity from the legacy S3
config and resolves to the deterministic account id."
```

---

### Task 5: Route the startup migration through `ensure()`

**Files:**
- Modify: `lib/core/services/accounts/account_startup_migration.dart:87`, `:137-140`, `:147-148`
- Test: `test/core/services/accounts/account_startup_migration_test.dart` (exists, append)

**Interfaces:**
- Consumes: `ensure()` from Task 2, `s3NaturalKey` / `naturalKeyForKind` from Task 1.
- Produces: no signature change. `AccountStartupMigration({required SharedPreferences prefs, AppDatabase? database, ConnectedAccountsRepository? accounts, AccountCredentialsStore? credentials, SyncRepository? syncRepository, EstablishedProviderStore? established})` is unchanged.

- [ ] **Step 1: Write the failing test**

Append inside the existing `main()` in `test/core/services/accounts/account_startup_migration_test.dart`:

```dart
  test('migrated iCloud sync account lands on the deterministic id', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await SyncRepository().setCloudProvider(CloudProviderType.icloud);

    await (await migration(prefs)).run();

    final accounts = await ConnectedAccountsRepository().getAll();
    expect(accounts.length, 1);
    expect(
      accounts.single.id,
      accountIdFor(kind: AccountKind.icloud, naturalKey: 'icloud'),
    );
  });

  test('a fresh connect after migration reuses the migrated row', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await SyncRepository().setCloudProvider(CloudProviderType.icloud);
    await (await migration(prefs)).run();

    await accounts.ensure(
      kind: AccountKind.icloud,
      naturalKey: 'icloud',
      label: 'iCloud',
    );

    expect((await ConnectedAccountsRepository().getAll()).length, 1);
  });
```

Add these imports to the test file if not already present:

```dart
import 'package:submersion/core/services/accounts/account_identity.dart';
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/services/accounts/account_startup_migration_test.dart`
Expected: `migrated iCloud sync account lands on the deterministic id` FAILS — the id is a random UUIDv4.

- [ ] **Step 3: Write the implementation**

In `lib/core/services/accounts/account_startup_migration.dart`, add the imports:

```dart
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
```

Add this private helper to the class, immediately above `_labelFor`:

```dart
  /// Create-or-reuse an account at its deterministic id. Falls back to the
  /// legacy random-id create only when the endpoint is not resolvable (an S3
  /// config this device cannot read); the deduplicator canonicalizes those
  /// later.
  Future<domain.ConnectedAccount> _ensure({
    required AccountKind kind,
    required String label,
    S3Config? s3,
  }) async {
    final naturalKey = kind == AccountKind.s3
        ? (s3 == null ? null : s3NaturalKey(s3))
        : naturalKeyForKind(kind);
    if (naturalKey == null) {
      return _accounts.create(kind: kind, label: label);
    }
    return _accounts.ensure(kind: kind, naturalKey: naturalKey, label: label);
  }
```

In `_migrateSyncProvider`, replace line 87:

```dart
    account ??= await _accounts.create(kind: kind, label: _labelFor(kind));
```

with:

```dart
    final syncS3 = kind == AccountKind.s3
        ? await S3CredentialsStore(storageKey: 'sync_s3_config').load()
        : null;
    account ??= await _ensure(kind: kind, label: _labelFor(kind), s3: syncS3);
```

In `_migrateMediaStoreAttachment`, replace the S3 branch (currently lines 136-140):

```dart
      final account = await _accounts.create(
        kind: AccountKind.s3,
        label: 'S3 media storage',
      );
```

with:

```dart
      final mediaS3 = await S3CredentialsStore(
        storageKey: 'media_store_s3_config',
      ).load();
      final account = await _ensure(
        kind: AccountKind.s3,
        label: mediaS3 == null
            ? 'S3 media storage'
            : '${mediaS3.bucket} @ ${mediaS3.displayHost}',
        s3: mediaS3,
      );
```

and replace the managed branch (currently lines 147-148):

```dart
      var account = await _accounts.getByKind(kind);
      account ??= await _accounts.create(kind: kind, label: _labelFor(kind));
      accountId = account.id;
```

with:

```dart
      final account = await _ensure(kind: kind, label: _labelFor(kind));
      accountId = account.id;
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/services/accounts/account_startup_migration_test.dart`
Expected: PASS, including all pre-existing tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/services/accounts/account_startup_migration.dart test/core/services/accounts/account_startup_migration_test.dart
git commit -m "refactor(accounts): seed the migration at deterministic ids

Routes the migration's three create calls through ensure so an upgrading
install and a fresh install land on identical account ids, instead of the
upgrade keeping a random id that a peer would later duplicate."
```

---

### Task 6: Startup deduplicator

**Files:**
- Create: `lib/core/services/accounts/account_deduplicator.dart`
- Test: `test/core/services/accounts/account_deduplicator_test.dart`

**Interfaces:**
- Consumes: `accountIdFor` / `s3NaturalKey` / `naturalKeyForKind` (Task 1), `ensure` (Task 2), `ConnectedAccountsRepository`, `AccountCredentialsStore`, `SyncRepository`, `EstablishedProviderStore`, `MediaStoreAttachState` pref key `media_store_account_id`, `S3CredentialsStore`.
- Produces:

```dart
class AccountDeduplicator {
  AccountDeduplicator({
    required SharedPreferences prefs,
    AppDatabase? database,
    ConnectedAccountsRepository? accounts,
    AccountCredentialsStore? credentials,
    SyncRepository? syncRepository,
    EstablishedProviderStore? established,
    S3CredentialsStore? syncS3,
    S3CredentialsStore? mediaS3,
  });

  Future<void> run();
}
```

- [ ] **Step 1: Write the failing test**

Create `test/core/services/accounts/account_deduplicator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_deduplicator.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/sync/established_provider_store.dart';

import '../../../helpers/test_database.dart';
import '../../../support/fake_keychain_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ConnectedAccountsRepository accounts;
  late InMemoryKeychain keychain;
  late AccountCredentialsStore credentials;
  late S3CredentialsStore syncS3;
  late S3CredentialsStore mediaS3;

  final syncConfig = S3Config(
    endpoint: 'https://149b84f6.r2.cloudflarestorage.com',
    bucket: 'submersion-sync',
    prefix: 'submersion-sync/',
    accessKeyId: 'AK',
    secretAccessKey: 'SK',
  );

  String syncCanonicalId() => accountIdFor(
    kind: AccountKind.s3,
    naturalKey: s3NaturalKey(syncConfig),
  );

  Future<AccountDeduplicator> dedup(SharedPreferences prefs) async =>
      AccountDeduplicator(
        prefs: prefs,
        database: db,
        accounts: accounts,
        credentials: credentials,
        syncRepository: SyncRepository(),
        established: EstablishedProviderStore(prefs),
        syncS3: syncS3,
        mediaS3: mediaS3,
      );

  Future<int> deletionCount() async {
    final rows = await db
        .customSelect(
          "SELECT COUNT(*) AS c FROM deletion_log "
          "WHERE entity_type = 'connectedAccounts'",
        )
        .getSingle();
    return rows.data['c'] as int;
  }

  setUp(() async {
    db = await setUpTestDatabase();
    accounts = ConnectedAccountsRepository();
    keychain = InMemoryKeychain();
    credentials = AccountCredentialsStore(storage: keychain);
    syncS3 = S3CredentialsStore(storage: keychain, storageKey: 'sync_s3_config');
    mediaS3 = S3CredentialsStore(
      storage: keychain,
      storageKey: 'media_store_s3_config',
    );
    await SyncRepository().getOrCreateMetadata();
  });

  tearDown(() => tearDownTestDatabase());

  test('collapses the observed duplicate roster', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await syncS3.save(syncConfig);

    const label = 'submersion-sync @ 149b84f6.r2.cloudflarestorage.com';
    final s3Ids = <String>[];
    for (var i = 0; i < 9; i++) {
      final a = await accounts.create(kind: AccountKind.s3, label: label);
      s3Ids.add(a.id);
    }
    for (var i = 0; i < 2; i++) {
      await accounts.create(kind: AccountKind.icloud, label: 'iCloud');
    }
    await credentials.write(s3Ids.first, '{"blob":"sync"}');
    await SyncRepository().setSyncAccount(
      accountId: s3Ids.first,
      providerType: CloudProviderType.s3,
    );

    await (await dedup(prefs)).run();

    final remaining = await accounts.getAll();
    expect(remaining.length, 1);
    expect(remaining.single.id, syncCanonicalId());
    expect(remaining.single.label, label);
    expect(await SyncRepository().getSyncAccountId(), syncCanonicalId());
    expect(await credentials.read(syncCanonicalId()), '{"blob":"sync"}');
    expect(await deletionCount(), 10);
  });

  test('is a no-op on a second run', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await syncS3.save(syncConfig);
    final a = await accounts.create(kind: AccountKind.s3, label: 'x');
    await SyncRepository().setSyncAccount(
      accountId: a.id,
      providerType: CloudProviderType.s3,
    );

    await (await dedup(prefs)).run();
    final afterFirst = await deletionCount();
    await (await dedup(prefs)).run();

    expect(await deletionCount(), afterFirst);
    expect((await accounts.getAll()).length, 1);
  });

  test('keeps a sync and a media anchor that differ by prefix', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await syncS3.save(syncConfig);
    final mediaConfig = S3Config(
      endpoint: syncConfig.endpoint,
      bucket: syncConfig.bucket,
      prefix: 'media/',
      accessKeyId: 'AK',
      secretAccessKey: 'SK',
    );
    await mediaS3.save(mediaConfig);

    const label = 'submersion-sync @ 149b84f6.r2.cloudflarestorage.com';
    final syncRow = await accounts.create(kind: AccountKind.s3, label: label);
    final mediaRow = await accounts.create(kind: AccountKind.s3, label: label);
    await SyncRepository().setSyncAccount(
      accountId: syncRow.id,
      providerType: CloudProviderType.s3,
    );
    await prefs.setString('media_store_account_id', mediaRow.id);

    await (await dedup(prefs)).run();

    final remaining = await accounts.getAll();
    expect(remaining.length, 2);
    expect(
      remaining.map((a) => a.id).toSet(),
      {
        syncCanonicalId(),
        accountIdFor(
          kind: AccountKind.s3,
          naturalKey: s3NaturalKey(mediaConfig),
        ),
      },
    );
    expect(prefs.getString('media_store_account_id'), isNot(mediaRow.id));
  });

  test('leaves Lightroom rows untouched', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final lr = await accounts.create(
      kind: AccountKind.adobeLightroom,
      label: 'Lightroom',
      accountIdentifier: 'catalog-1',
      id: 'preserved-lightroom-id',
    );
    final lr2 = await accounts.create(
      kind: AccountKind.adobeLightroom,
      label: 'Lightroom',
      accountIdentifier: 'catalog-2',
    );

    await (await dedup(prefs)).run();

    final ids = (await accounts.getAll()).map((a) => a.id).toSet();
    expect(ids, containsAll([lr.id, lr2.id]));
    expect(await deletionCount(), 0);
  });

  test('keeps an anchor whose S3 config is unreadable, drops inert rows',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const label = 'submersion-sync @ 149b84f6.r2.cloudflarestorage.com';
    final anchor = await accounts.create(kind: AccountKind.s3, label: label);
    await accounts.create(kind: AccountKind.s3, label: label);
    await accounts.create(kind: AccountKind.s3, label: label);
    await SyncRepository().setSyncAccount(
      accountId: anchor.id,
      providerType: CloudProviderType.s3,
    );

    await (await dedup(prefs)).run();

    final remaining = await accounts.getAll();
    expect(remaining.length, 1);
    expect(remaining.single.id, anchor.id);
    expect(await SyncRepository().getSyncAccountId(), anchor.id);
    expect(await deletionCount(), 2);
  });

  test('carries an established marker onto the canonical id', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await syncS3.save(syncConfig);
    final anchor = await accounts.create(kind: AccountKind.s3, label: 'x');
    await SyncRepository().setSyncAccount(
      accountId: anchor.id,
      providerType: CloudProviderType.s3,
    );
    final established = EstablishedProviderStore(prefs);
    await established.add(anchor.id);

    await (await dedup(prefs)).run();

    expect(established.contains(syncCanonicalId()), isTrue);
  });

  test('does nothing when there is nothing to collapse', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await (await dedup(prefs)).run();
    expect(await accounts.getAll(), isEmpty);
    expect(await deletionCount(), 0);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/services/accounts/account_deduplicator_test.dart`
Expected: FAIL — `Error when reading 'lib/core/services/accounts/account_deduplicator.dart': No such file or directory`.

- [ ] **Step 3: Write the implementation**

Create `lib/core/services/accounts/account_deduplicator.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/established_provider_store.dart';

/// Collapses duplicate `connected_accounts` rows onto their deterministic
/// ids.
///
/// Rows created before deterministic ids existed carry random UUIDv4s, so
/// the same endpoint appears once per connect and once per device. This pass
/// is anchor-based rather than group-and-elect: legacy labels carry only
/// `bucket @ host` with no prefix, so grouping on the label would merge a
/// sync-S3 and a media-S3 account that share a bucket - two accounts the
/// identity scheme deliberately keeps apart.
///
/// An anchor is a row something actually points at. There are at most two:
/// the sync account (`sync_metadata.sync_account_id`) and the media store
/// account (`media_store_account_id`). Each is migrated to the canonical id
/// derived from its own config. Every other non-Lightroom row is referenced
/// by nothing and its keychain blob is a copy, so it is deleted.
///
/// Runs on every launch rather than behind a done flag, so it also heals
/// rows that arrive later from a device still on an older build. It performs
/// no writes when there is nothing to collapse.
class AccountDeduplicator {
  AccountDeduplicator({
    required SharedPreferences prefs,
    AppDatabase? database,
    ConnectedAccountsRepository? accounts,
    AccountCredentialsStore? credentials,
    SyncRepository? syncRepository,
    EstablishedProviderStore? established,
    S3CredentialsStore? syncS3,
    S3CredentialsStore? mediaS3,
  }) : _prefs = prefs,
       _database = database,
       _accounts = accounts ?? ConnectedAccountsRepository(),
       _credentials = credentials ?? AccountCredentialsStore(),
       _syncRepository = syncRepository ?? SyncRepository(),
       _established = established ?? EstablishedProviderStore(prefs),
       _syncS3 =
           syncS3 ?? S3CredentialsStore(storageKey: _syncS3Key),
       _mediaS3 =
           mediaS3 ?? S3CredentialsStore(storageKey: _mediaS3Key);

  static final _log = LoggerService.forClass(AccountDeduplicator);

  static const String _syncS3Key = 'sync_s3_config';
  static const String _mediaS3Key = 'media_store_s3_config';
  static const String _mediaAccountIdKey = 'media_store_account_id';

  final SharedPreferences _prefs;
  final AppDatabase? _database;
  final ConnectedAccountsRepository _accounts;
  final AccountCredentialsStore _credentials;
  final SyncRepository _syncRepository;
  final EstablishedProviderStore _established;
  final S3CredentialsStore _syncS3;
  final S3CredentialsStore _mediaS3;

  AppDatabase get _db => _database ?? DatabaseService.instance.database;

  Future<void> run() async {
    try {
      await _run();
    } catch (e, stackTrace) {
      // A dedup failure must never block startup: the duplicates are a
      // cosmetic and hygiene problem, and the next launch retries.
      _log.error(
        'Account deduplication failed; will retry next launch',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _run() async {
    final all = await _accounts.getAll();
    final candidates = all
        .where((a) => a.kind != AccountKind.adobeLightroom)
        .toList();
    if (candidates.isEmpty) return;

    // Anchors first, so references are repointed before anything is deleted.
    final keep = <String>{};

    final syncCanonical = await _canonicalizeSyncAnchor();
    if (syncCanonical != null) keep.add(syncCanonical);

    final mediaCanonical = await _canonicalizeMediaAnchor();
    if (mediaCanonical != null) keep.add(mediaCanonical);

    // Everything else is inert: nothing points at it, and its credentials
    // blob is a copy of an anchor's.
    for (final account in candidates) {
      if (keep.contains(account.id)) continue;
      // The established marker gates sync's first-contact check, so it
      // carries only onto the SYNC canonical id. The media anchor plays no
      // part in that gate and must not inherit the marker.
      if (syncCanonical != null && _established.contains(account.id)) {
        await _established.add(syncCanonical);
      }
      await _accounts.delete(account.id);
    }
  }

  /// Migrates the sync account onto its canonical id and repoints
  /// `sync_metadata`. Returns the id to keep, or null when there is no sync
  /// anchor.
  Future<String?> _canonicalizeSyncAnchor() async {
    final id = await _syncRepository.getSyncAccountId();
    if (id == null) return null;
    final row = await _accounts.getById(id);
    if (row == null || row.kind == AccountKind.adobeLightroom) return null;

    final canonical = await _canonicalIdFor(row, _syncS3);
    if (canonical == null || canonical == row.id) return row.id;

    await _adopt(row, canonical);
    final providerType = row.kind.cloudProviderType;
    if (providerType != null) {
      await _syncRepository.setSyncAccount(
        accountId: canonical,
        providerType: providerType,
      );
    }
    return canonical;
  }

  /// Migrates the media store account onto its canonical id and repoints the
  /// attach pref. Returns the id to keep, or null when nothing is attached.
  Future<String?> _canonicalizeMediaAnchor() async {
    final id = _prefs.getString(_mediaAccountIdKey);
    if (id == null) return null;
    final row = await _accounts.getById(id);
    if (row == null || row.kind == AccountKind.adobeLightroom) return null;

    final canonical = await _canonicalIdFor(row, _mediaS3);
    if (canonical == null || canonical == row.id) return row.id;

    await _adopt(row, canonical);
    await _prefs.setString(_mediaAccountIdKey, canonical);
    return canonical;
  }

  /// The deterministic id for [row], or null when this device cannot resolve
  /// the endpoint (an S3 config it cannot read). Null means "leave it alone":
  /// a device that can read the config finishes the migration, and the
  /// deterministic id makes both devices agree afterwards.
  Future<String?> _canonicalIdFor(
    domain.ConnectedAccount row,
    S3CredentialsStore s3Store,
  ) async {
    if (row.kind == AccountKind.s3) {
      final config = await s3Store.load();
      if (config == null) return null;
      return accountIdFor(
        kind: AccountKind.s3,
        naturalKey: s3NaturalKey(config),
      );
    }
    final key = naturalKeyForKind(row.kind);
    return key == null
        ? null
        : accountIdFor(kind: row.kind, naturalKey: key);
  }

  /// Copies [row] onto [canonicalId]: credentials first, then the row.
  ///
  /// The legacy row is left for the inert sweep to delete, so a crash
  /// between here and the sweep leaves a harmless extra row rather than a
  /// reference pointing at a tombstone.
  Future<void> _adopt(domain.ConnectedAccount row, String canonicalId) async {
    final blob = await _credentials.read(row.id);
    if (blob != null) await _credentials.write(canonicalId, blob);
    if (await _accounts.getById(canonicalId) == null) {
      await _accounts.create(
        kind: row.kind,
        label: row.label,
        accountIdentifier: row.accountIdentifier,
        id: canonicalId,
      );
    }
    if (_established.contains(row.id)) {
      await _established.add(canonicalId);
    }
  }
}
```

Note: `_db` is retained for symmetry with `AccountStartupMigration` and is used by nothing in this pass. If `flutter analyze` reports it as unused, delete the `_db` getter, the `_database` field and the `database` constructor parameter, and drop the `AppDatabase` and `DatabaseService` imports along with the `database: db` argument in the test helper.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/services/accounts/account_deduplicator_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/services/accounts/account_deduplicator.dart test/core/services/accounts/account_deduplicator_test.dart
git commit -m "feat(accounts): add the startup account deduplicator

Migrates the sync and media-store anchors onto their deterministic ids,
repointing sync metadata, the attach pref, the established marker and the
keychain blob before deleting the inert duplicate rows via tombstones.
Lightroom is untouched."
```

---

### Task 7: Run the deduplicator at startup

**Files:**
- Modify: `lib/core/presentation/pages/startup_page.dart:353-356`

**Interfaces:**
- Consumes: `AccountDeduplicator` from Task 6.
- Produces: no new API.

- [ ] **Step 1: Write the implementation**

There is no unit test for `startup_page.dart`'s step sequence; this task is a wiring change verified by the full suite and a manual run.

In `lib/core/presentation/pages/startup_page.dart`, add the import next to the existing `AccountStartupMigration` import:

```dart
import 'package:submersion/core/services/accounts/account_deduplicator.dart';
```

Replace the existing `accountMigration` step:

```dart
    await timeStartupStep('accountMigration', () async {
      final prefs = await SharedPreferences.getInstance();
      await AccountStartupMigration(prefs: prefs).run();
    });
```

with:

```dart
    await timeStartupStep('accountMigration', () async {
      final prefs = await SharedPreferences.getInstance();
      await AccountStartupMigration(prefs: prefs).run();
      // After the migration, so rows it seeds are already at their
      // deterministic ids and the pass finds nothing to do on a fresh
      // install. Both swallow their own errors: neither can block startup.
      await AccountDeduplicator(prefs: prefs).run();
    });
```

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 3: Format, analyze**

```bash
dart format .
flutter analyze
```

Expected: no changes from `dart format`, no issues from `flutter analyze`.

- [ ] **Step 4: Verify against the real database**

Back up the development database first, since this pass deletes rows:

```bash
cp "$HOME/Library/Containers/app.submersion/Data/Documents/Submersion/submersion.db" \
   "$HOME/Desktop/submersion-before-dedup.db"
sqlite3 "$HOME/Library/Containers/app.submersion/Data/Documents/Submersion/submersion.db" \
  "select kind, count(*) from connected_accounts group by kind;"
```

Expected before: `icloud|2`, `s3|9`.

Run the app: `flutter run -d macos`, open Settings, then Connected Accounts.

Expected after: at most one row per distinct endpoint. Re-run the same `sqlite3` query and confirm the counts dropped, and that `sync_metadata.sync_account_id` names a row that still exists:

```bash
sqlite3 "$HOME/Library/Containers/app.submersion/Data/Documents/Submersion/submersion.db" \
  "select count(*) from connected_accounts c
     join sync_metadata m on m.sync_account_id = c.id;"
```

Expected: `1`.

Confirm sync still works: open Settings, Cloud Sync, and run a manual sync.

- [ ] **Step 5: Commit**

```bash
git add lib/core/presentation/pages/startup_page.dart
git commit -m "feat(startup): run the account deduplicator after the migration

Collapses pre-existing duplicate connected_accounts rows on launch, after
the migration has seeded any rows it owns."
```

---

### Task 8: Full verification

**Files:** none modified.

- [ ] **Step 1: Run the whole suite**

Run: `flutter test`
Expected: PASS with no skipped or failing tests. Record the totals.

- [ ] **Step 2: Format and analyze the whole project**

```bash
dart format .
flutter analyze
```

Expected: `dart format` reports 0 changed files; `flutter analyze` reports `No issues found!`. Do not pipe either command through `head` or `tail` - that masks the exit status.

- [ ] **Step 3: Confirm no schema change slipped in**

```bash
git diff main --stat -- lib/core/database/
```

Expected: empty output. Any change under `lib/core/database/` means the no-schema-change constraint was violated.

- [ ] **Step 4: Confirm every unguarded create is gone**

```bash
grep -rn "_accounts.create\|repo.create" lib --include="*.dart"
```

Expected: only the two documented fallbacks remain - `sync_providers.dart` (unreadable S3 config) and `account_startup_migration.dart`'s `_ensure` helper. Any other hit is a missed call site.

- [ ] **Step 5: Push**

```bash
git push -u origin worktree-connected-accounts-duplicates
```

The pre-push hook runs `dart format --set-exit-if-changed`, `flutter analyze` and `flutter test`. If it rejects the push, fix the cause rather than bypassing with `--no-verify`.
