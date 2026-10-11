# WebDAV Sync and Media Storage Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a generic WebDAV backend (Nextcloud, ownCloud, Synology, Koofr, pCloud, Fastmail, Yandex and any other WebDAV server) for cloud sync, cloud backups and media storage.

**Architecture:** One hand-rolled `WebDavClient` over `package:http` + `xml` (PROPFIND, GET, PUT, DELETE, MKCOL, MOVE, with retry, redirect reporting, certificate pinning and Nextcloud chunking v2) backs a `WebDavStorageProvider` (`CloudStorageProvider`) and a `WebDavMediaObjectStore` (`MediaObjectStore`). A `WebDavAccountAdapter` plugs both into the Connected Accounts layer; `CloudProviderType.webdav` / `AccountKind.webdav` get an arm in every exhaustive switch. Schema 277 raises the sync floor so pre-WebDAV builds are held.

**Tech Stack:** Dart / Flutter, `package:http` (`MockClient` in tests), `package:xml`, `package:crypto`, `flutter_secure_storage` via `FallbackSecureStorage`, Riverpod, drift, go_router, ARB l10n.

**Spec:** `docs/design/specs/2026-10-10-webdav-sync-backend-design.md`

## Global Constraints

- `providerId` is `'webdav'`, equal to `CloudProviderType.webdav.name`.
- Legacy sync keychain key: `sync_webdav_config`. Per-account keys: `AccountCredentialsStore.keyFor(id)`.
- Default sync folder `Submersion`; default media folder `Submersion Media`; probe object `.submersion-probe`.
- Nextcloud chunk size and threshold: 10 MiB (`10 * 1024 * 1024`). Upload directory names start with `submersion-`.
- Retry: up to 6 attempts, jittered backoff, on transport errors, 5xx other than 507, 429 and 423.
- `currentSchemaVersion` 277 and `minimumCompatibleSchemaVersion` 277. The rung goes in `lib/core/database/migrations/ladder/rungs_v231_onward.dart`, never as logic in `database.dart`.
- Credentials never appear in logs, exception messages, SharedPreferences or the database.
- Paths in tests and code are built with `p.join` or URI segments, never by joining with a literal `/` for filesystem paths; temp files come from `resolveSyncTempDir()` in code and `Directory.systemTemp.createTemp` in tests.
- No em-dashes or en-dashes as punctuation in any code, comment, string or doc.
- Every user-visible string is an ARB key translated in all 11 locales (ar, de, en, es, fr, he, hu, it, nl, pt, zh).
- Files stay under 800 lines; `media_storage_page.dart` (906) and `sync_providers.dart` must not grow by more than the minimal wiring.
- Run `dart format .`, `flutter analyze`, the task's tests, and `flutter test test/architecture/ test/shared/` whenever a task adds files under `lib/`.

## Review Focus

1. A server that answers `href` values as full URLs with percent-encoded spaces (`Submersion%20Media`) must list and stat the same files a path-only server does. Pinned in Task 3.
2. A PUT into a folder that was deleted on the server between syncs (409) must recreate the folder and succeed, not fail the sync. Pinned in Task 5.
3. A Nextcloud user who logs in with an email address must sync into `files/<userId>/`, not `files/<email>/`. Pinned in Task 6.
4. A self-signed server whose certificate is renewed after it was trusted must show the mismatch dialog, never silently fail or silently accept. Pinned in Task 4 (matcher) and Task 11 (dialog).
5. A media `list('smv1/objects/ab/<hash>.')` on a server where `smv1/objects/ab/` does not exist yet must yield nothing, not throw. Pinned in Task 8.

## Notes on scope

The design discussion mentioned a media keychain blob `media_store_webdav_config`. It is dropped: every WebDAV media attachment is made through the accounts layer (the attach state always carries an account id), so the runtime resolves the store from the per-account credentials, and a rollback build cannot read WebDAV at all, so a legacy blob would serve nothing. Spec section 6 now says so.

Error text on the WebDAV config page and media form is localized from a `WebDavErrorCode` (Task 10); the sync status line keeps the English `displayMessage`, like every other backend.

---

## File map

| File | Task | Responsibility |
|------|------|----------------|
| `lib/core/database/migrations/ladder/rungs_v231_onward.dart` | 1 | v277 no-op rung |
| `lib/core/database/database.dart` | 1 | 277 constants, ladder entry, floor doc comment |
| `lib/core/data/repositories/connected_accounts_repository.dart` | 1 | Skip rows of unknown kind |
| `lib/core/services/cloud_storage/webdav/webdav_preset.dart` | 2 | Server presets |
| `lib/core/services/cloud_storage/webdav/webdav_config.dart` | 2 | Config entity |
| `lib/core/services/cloud_storage/webdav/webdav_multistatus.dart` | 3 | PROPFIND parser |
| `lib/core/services/cloud_storage/webdav/webdav_errors.dart` | 4 | `WebDavErrorCode`, `WebDavException`, untrusted-cert exception |
| `lib/core/services/cloud_storage/webdav/webdav_tls.dart` | 4 | Fingerprints, pin matcher, recorder, pinned HTTP client |
| `lib/core/services/cloud_storage/webdav/webdav_client.dart` | 5 | Protocol client |
| `test/helpers/fake_webdav_server.dart` | 5 | In-memory DAV server |
| `lib/core/services/cloud_storage/webdav/nextcloud_chunked_upload.dart` | 6 | Chunking v2 |
| `lib/core/services/cloud_storage/webdav/webdav_credentials_store.dart` | 7 | Legacy keychain blob |
| `lib/core/services/cloud_storage/webdav_storage_provider.dart` | 7 | `CloudStorageProvider` |
| `lib/core/services/media_store/webdav_media_object_store.dart` | 8 | `MediaObjectStore` |
| `lib/core/services/accounts/adapters/webdav_account_adapter.dart` | 9 | Accounts adapter |
| enum, identity, registry, dedup, provider wiring files | 9 | Wiring |
| `lib/l10n/arb/app_*.arb` | 10 | Strings |
| `lib/features/settings/presentation/widgets/webdav_error_text.dart` | 10 | Code to l10n mapping |
| `lib/features/settings/presentation/widgets/webdav_trust_certificate_dialog.dart` | 11 | Trust dialog |
| `lib/features/settings/presentation/widgets/webdav_server_fields.dart` | 11 | Shared form fields |
| `lib/features/settings/presentation/pages/webdav_config_page.dart` | 11 | Sync config page |
| `lib/features/settings/presentation/providers/webdav_providers.dart` | 9 | Riverpod providers for the page |
| `lib/core/router/app_router.dart` | 11 | Route |
| `lib/features/settings/presentation/pages/cloud_sync_page.dart` | 12 | Tile |
| `lib/features/setup_wizard/presentation/widgets/steps/backup_sync_step.dart` | 12 | Wizard card |
| `lib/features/media_store/data/media_store_service.dart` | 13 | `testWebDav`, `connectWebDav` |
| `lib/features/media_store/presentation/widgets/webdav_media_form.dart` | 13 | Media form |
| `lib/features/media_store/presentation/pages/media_storage_page.dart` | 13 | Segment |

---

### Task 0: Before screenshots

The feature changes the Cloud Sync page, the Media Storage page and the setup wizard's backup step, so capture them before any code changes.

- [ ] **Step 1:** Launch the app from this worktree with the `run` skill and save, to the scratchpad: `01-cloud-sync-before.png` (Settings, Cloud Sync, provider list), `04-media-storage-before.png` (Settings, Media Storage, provider chooser) and `05-wizard-backup-before.png` (Settings, setup wizard, backup step). The WebDAV settings page and trust dialog are new screens and get no before shot.

---

### Task 1: Cross-version safety (schema 277, floor 277, tolerant reads)

**Files:**
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion` at :256, floor doc comment and constant at :351, `migrationVersions` list ending at :1180)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (end of the ladder)
- Modify: `lib/core/data/repositories/connected_accounts_repository.dart` (`getAll`, `getById`, `getByKind`, `_toDomain`)
- Modify: `test/core/database/migration_v276_icd_warnings_test.dart:31-34`
- Create: `test/core/database/migration_v277_webdav_floor_test.dart`
- Test: `test/core/data/repositories/connected_accounts_repository_test.dart`

**Interfaces:**
- Produces: `AppDatabase.currentSchemaVersion == 277`, `AppDatabase.minimumCompatibleSchemaVersion == 277`; `ConnectedAccountsRepository` never throws on an unknown `kind`.

- [ ] **Step 1: Write the failing migration test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v277: no data change. It exists to carry the sync floor past every
/// build that cannot parse AccountKind.webdav (issue #2361).
void main() {
  test('v277 is in the ladder and is the current schema', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(277));
    expect(AppDatabase.migrationVersions, contains(277));
    expect(
      AppDatabase.migrationStepCount(276),
      AppDatabase.migrationStepCount(277) + 1,
    );
  });

  test('the floor holds every pre-WebDAV build', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 277);
  });
}
```

- [ ] **Step 2: Write the failing tolerant-read test**

Append to `test/core/data/repositories/connected_accounts_repository_test.dart` inside its `main()`, reusing the file's existing database setup (read the top of the file for the `db` / `repo` fixture names and use them):

```dart
  test('rows of an unknown kind are skipped instead of throwing', () async {
    final known = await repo.create(kind: AccountKind.dropbox, label: 'D');
    await db.customStatement(
      'INSERT INTO connected_accounts '
      '(id, kind, label, account_identifier, created_at, updated_at) '
      "VALUES ('future-1', 'someFutureKind', 'F', NULL, 0, 0)",
    );

    final all = await repo.getAll();
    expect(all.map((a) => a.id), [known.id]);
    expect(await repo.getById('future-1'), isNull);
    expect(await repo.getByKind(AccountKind.dropbox), isNotNull);
  });
```

If the table has additional NOT NULL columns, read `lib/core/database/tables/media_tables.dart:359-370` and add them to the INSERT.

- [ ] **Step 3: Run both and verify they fail**

Run: `flutter test test/core/database/migration_v277_webdav_floor_test.dart test/core/data/repositories/connected_accounts_repository_test.dart`
Expected: FAIL (`277` not in ladder; `ArgumentError` from `byName`).

- [ ] **Step 4: Implement**

In `database.dart`: set `currentSchemaVersion = 277`; append to `migrationVersions` after `276,`:

```dart
    // v277: no data change (issue #2361). AccountKind.webdav is a new value
    // in the synced connected_accounts.kind column, which builds before this
    // one decode with a throwing AccountKind.values.byName. Raising the
    // floor to 277 holds them until they update; see
    // minimumCompatibleSchemaVersion.
    277,
```

Set `minimumCompatibleSchemaVersion = 277` and add to its doc comment, after the 240 -> 275 paragraph:

```dart
  ///
  /// Raised 275 -> 277 by the WebDAV backend (#2361): AccountKind.webdav is
  /// a new value in the synced column connected_accounts.kind, and every
  /// build before 277 decodes that column with AccountKind.values.byName,
  /// which throws on a name it does not know. Schema 277 changes no data; it
  /// exists so the floor can rise past the 275 and 276 betas. From 277 on
  /// the accounts repository skips unknown kinds, so later kinds need no
  /// floor bump of their own.
```

In `rungs_v231_onward.dart`, after the v276 block:

```dart
    // v277: no data change (issue #2361). Carries the sync floor past the
    // builds that cannot parse AccountKind.webdav.
    if (from < 277) await reportProgress();
```

In `connected_accounts_repository.dart`, add a logger and make `_toDomain` nullable:

```dart
  static final _log = LoggerService.forClass(ConnectedAccountsRepository);

  /// Null for a row whose kind this build does not know (a newer peer's
  /// account synced here); callers skip it rather than fail the whole read.
  domain.ConnectedAccount? _toDomain(ConnectedAccount row) {
    final kind = AccountKind.values.asNameMap()[row.kind];
    if (kind == null) {
      _log.warning('Skipping connected account ${row.id}: unknown kind');
      return null;
    }
    return domain.ConnectedAccount(
      id: row.id,
      kind: kind,
      label: row.label,
      accountIdentifier: row.accountIdentifier,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
    );
  }
```

Update callers: `getAll` uses `rows.map(_toDomain).nonNulls.toList()`; `getById` and `getByKind` return `row == null ? null : _toDomain(row)`; the `ensure` / `create` paths that call `_toDomain(inserted)` on a row they just wrote with a known kind use `_toDomain(inserted)!`. Import `package:submersion/core/services/logger_service.dart` if absent.

In `migration_v276_icd_warnings_test.dart`, replace the floor test (it asserted `lessThan(276)`, which 277 breaks) with:

```dart
  test('this rung did not raise the floor to 276', () {
    // v275 raised it (#3091); v276 is additive. v277 (#2361) later raised
    // it past 276 for an unrelated reason, so assert only that 276 itself
    // was never the floor.
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(276));
  });
```

Then run `grep -rn "minimumCompatibleSchemaVersion" test` and fix any other assertion that 277 now breaks the same way.

- [ ] **Step 5: Run the database and repository tests**

Run: `flutter test test/core/database test/core/data/repositories/connected_accounts_repository_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/migrations/ladder/rungs_v231_onward.dart lib/core/data/repositories/connected_accounts_repository.dart test/core/database test/core/data/repositories/connected_accounts_repository_test.dart
git commit -m "feat(sync): raise the sync floor to 277 and skip unknown account kinds"
```

---

### Task 2: WebDAV presets and configuration

**Files:**
- Create: `lib/core/services/cloud_storage/webdav/webdav_preset.dart`
- Create: `lib/core/services/cloud_storage/webdav/webdav_config.dart`
- Test: `test/core/services/cloud_storage/webdav/webdav_config_test.dart`

**Interfaces:**
- Produces:
  - `enum WebDavPreset { nextcloud, owncloud, synology, koofr, pcloudUs, pcloudEu, fastmail, yandex, other }` with `String? get fixedRoot`, `bool get needsServerUrl`, `bool get usesNextcloudLayout`, `bool get supportsNextcloudChunking`, `bool get recommendsAppPassword`.
  - `class WebDavConfig` with fields `preset`, `serverUrl`, `username`, `password`, `folder`, `nextcloudUserId`, `pinnedCertSha256`; getters `Uri davRoot`, `Uri? nextcloudUploadsRoot`, `Uri? principalProbeUri`, `String host`, `int port`, `bool isInsecure`, `String displayLabel`; `String? validate()`; `copyWith(...)` with `clearPin` and `clearNextcloudUserId` flags; `toJson()` / `WebDavConfig.fromJson(Map<String, Object?>)`.
  - `const String kDefaultWebDavSyncFolder = 'Submersion'`, `const String kDefaultWebDavMediaFolder = 'Submersion Media'`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_preset.dart';

void main() {
  WebDavConfig make({
    WebDavPreset preset = WebDavPreset.other,
    String serverUrl = 'https://dav.example.com/dav',
    String folder = 'Submersion',
    String? userId,
  }) => WebDavConfig(
    preset: preset,
    serverUrl: serverUrl,
    username: 'alice@example.com',
    password: 'secret',
    folder: folder,
    nextcloudUserId: userId,
  );

  group('davRoot', () {
    test('Other uses the URL as entered, with a trailing slash', () {
      expect(make().davRoot.toString(), 'https://dav.example.com/dav/');
    });

    test('Nextcloud appends files/<user id>, preferring the resolved id', () {
      final c = make(
        preset: WebDavPreset.nextcloud,
        serverUrl: 'https://cloud.example.com/',
      );
      expect(
        c.davRoot.toString(),
        'https://cloud.example.com/remote.php/dav/files/alice%40example.com/',
      );
      expect(
        c.copyWith(nextcloudUserId: 'alice').davRoot.toString(),
        'https://cloud.example.com/remote.php/dav/files/alice/',
      );
      expect(
        c.copyWith(nextcloudUserId: 'alice').nextcloudUploadsRoot.toString(),
        'https://cloud.example.com/remote.php/dav/uploads/alice/',
      );
      expect(
        c.principalProbeUri.toString(),
        'https://cloud.example.com/remote.php/dav/',
      );
    });

    test('fixed-host presets ignore the server URL', () {
      expect(
        make(preset: WebDavPreset.koofr, serverUrl: '').davRoot.toString(),
        'https://app.koofr.net/dav/Koofr/',
      );
      expect(
        make(preset: WebDavPreset.pcloudEu, serverUrl: '').davRoot.host,
        'ewebdav.pcloud.com',
      );
    });

    test('only Nextcloud chunks', () {
      expect(make(preset: WebDavPreset.owncloud).nextcloudUploadsRoot, isNull);
      expect(WebDavPreset.nextcloud.supportsNextcloudChunking, isTrue);
      expect(WebDavPreset.owncloud.supportsNextcloudChunking, isFalse);
    });
  });

  group('folder normalization and validation', () {
    test('trims slashes and whitespace and collapses repeats', () {
      expect(make(folder: ' /Apps//Submersion/ ').folder, 'Apps/Submersion');
    });

    test('rejects dot segments, an empty folder and missing fields', () {
      expect(make(folder: 'Apps/../x').validate(), isNotNull);
      expect(make(folder: '  ').validate(), isNotNull);
      expect(make(serverUrl: 'ftp://x').validate(), isNotNull);
      expect(make(serverUrl: '').validate(), isNotNull);
      expect(make().copyWith(password: '').validate(), isNotNull);
      expect(make().validate(), isNull);
      expect(
        make(preset: WebDavPreset.koofr, serverUrl: '').validate(),
        isNull,
      );
    });
  });

  test('isInsecure is true only for http', () {
    expect(make(serverUrl: 'http://nas.local').isInsecure, isTrue);
    expect(make().isInsecure, isFalse);
  });

  test('JSON round-trips every field, and an unknown preset reads as other', () {
    final c = make(
      preset: WebDavPreset.nextcloud,
      userId: 'alice',
    ).copyWith(pinnedCertSha256: 'ab' * 32);
    final back = WebDavConfig.fromJson(c.toJson());
    expect(back.toJson(), c.toJson());
    expect(
      WebDavConfig.fromJson({...c.toJson(), 'preset': 'gopher'}).preset,
      WebDavPreset.other,
    );
  });

  test('copyWith can clear the pin and the user id', () {
    final c = make(userId: 'alice').copyWith(pinnedCertSha256: 'ab' * 32);
    final cleared = c.copyWith(clearPin: true, clearNextcloudUserId: true);
    expect(cleared.pinnedCertSha256, isNull);
    expect(cleared.nextcloudUserId, isNull);
  });

  test('displayLabel is user @ host and never contains the password', () {
    expect(make().displayLabel, 'alice@example.com @ dav.example.com');
    expect(make().toString(), isNot(contains('secret')));
  });
}
```

- [ ] **Step 2: Run and verify failure**

Run: `flutter test test/core/services/cloud_storage/webdav/webdav_config_test.dart`
Expected: FAIL (files do not exist).

- [ ] **Step 3: Implement `webdav_preset.dart`**

```dart
/// Server types the WebDAV settings offer. Each knows where its WebDAV
/// root lives, so the user enters a host instead of a DAV path.
enum WebDavPreset {
  nextcloud,
  owncloud,
  synology,
  koofr,
  pcloudUs,
  pcloudEu,
  fastmail,
  yandex,
  other;

  /// The DAV root of a hosted service, or null when the user supplies the
  /// server URL.
  String? get fixedRoot => switch (this) {
    koofr => 'https://app.koofr.net/dav/Koofr/',
    pcloudUs => 'https://webdav.pcloud.com/',
    pcloudEu => 'https://ewebdav.pcloud.com/',
    fastmail => 'https://myfiles.fastmail.com/',
    yandex => 'https://webdav.yandex.com/',
    nextcloud || owncloud || synology || other => null,
  };

  bool get needsServerUrl => fixedRoot == null;

  /// Files live under `remote.php/dav/files/<user>/`.
  bool get usesNextcloudLayout => this == nextcloud || this == owncloud;

  /// Nextcloud's chunked upload protocol (v2) is available.
  bool get supportsNextcloudChunking => this == nextcloud;

  /// The service issues app passwords and refuses the account password once
  /// two-factor sign-in is on.
  bool get recommendsAppPassword =>
      this == nextcloud || this == owncloud || this == koofr || this == fastmail;

  /// The preset stored under [name], or [other] for a name this build does
  /// not know.
  static WebDavPreset fromName(String? name) =>
      WebDavPreset.values.asNameMap()[name] ?? WebDavPreset.other;
}
```

- [ ] **Step 4: Implement `webdav_config.dart`**

```dart
import 'package:submersion/core/services/cloud_storage/webdav/webdav_preset.dart';

const String kDefaultWebDavSyncFolder = 'Submersion';
const String kDefaultWebDavMediaFolder = 'Submersion Media';

/// Connection settings for a WebDAV server.
///
/// Immutable. The factory normalizes its inputs: [serverUrl] trimmed with no
/// trailing slash, [folder] trimmed of surrounding and repeated slashes.
/// [toString] never prints the password.
class WebDavConfig {
  final WebDavPreset preset;
  final String serverUrl;
  final String username;
  final String password;
  final String folder;

  /// Nextcloud user id from `current-user-principal`, which can differ from
  /// the login name (an email login, LDAP). Null until resolved.
  final String? nextcloudUserId;

  /// Lowercase hex SHA-256 of a self-signed certificate the user trusted.
  final String? pinnedCertSha256;

  const WebDavConfig._({
    required this.preset,
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.folder,
    required this.nextcloudUserId,
    required this.pinnedCertSha256,
  });

  factory WebDavConfig({
    required WebDavPreset preset,
    required String serverUrl,
    required String username,
    required String password,
    String folder = kDefaultWebDavSyncFolder,
    String? nextcloudUserId,
    String? pinnedCertSha256,
  }) => WebDavConfig._(
    preset: preset,
    serverUrl: _normalizeUrl(serverUrl),
    username: username.trim(),
    password: password,
    folder: _normalizeFolder(folder),
    nextcloudUserId: _blankToNull(nextcloudUserId),
    pinnedCertSha256: _blankToNull(pinnedCertSha256)?.toLowerCase(),
  );

  static String _normalizeUrl(String raw) {
    var value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  static String _normalizeFolder(String raw) => raw
      .trim()
      .split('/')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join('/');

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  String get _base => preset.fixedRoot ?? '$serverUrl/';

  /// The collection every path is relative to.
  Uri get davRoot {
    if (preset.usesNextcloudLayout) {
      final id = Uri.encodeComponent(nextcloudUserId ?? username);
      return Uri.parse('$serverUrl/remote.php/dav/files/$id/');
    }
    final root = _base;
    return Uri.parse(root.endsWith('/') ? root : '$root/');
  }

  /// Nextcloud's chunked-upload collection, or null for other servers.
  Uri? get nextcloudUploadsRoot {
    if (!preset.supportsNextcloudChunking) return null;
    final id = Uri.encodeComponent(nextcloudUserId ?? username);
    return Uri.parse('$serverUrl/remote.php/dav/uploads/$id/');
  }

  /// Where `current-user-principal` is asked, or null when not needed.
  Uri? get principalProbeUri => preset.usesNextcloudLayout
      ? Uri.parse('$serverUrl/remote.php/dav/')
      : null;

  String get host => davRoot.host;
  int get port => davRoot.port;
  bool get isInsecure => davRoot.scheme == 'http';
  String get displayLabel => '$username @ $host';

  /// English description of the first problem, or null when valid. The
  /// settings forms validate field by field with localized text; this is
  /// the service-layer backstop.
  String? validate() {
    if (preset.needsServerUrl) {
      final uri = Uri.tryParse(serverUrl);
      if (serverUrl.isEmpty ||
          uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        return 'Enter the server address, starting with https://';
      }
    }
    if (username.isEmpty) return 'Enter the username';
    if (password.isEmpty) return 'Enter the password';
    if (folder.isEmpty) return 'Enter a folder name';
    if (folder.split('/').any((s) => s == '.' || s == '..')) {
      return 'The folder name cannot contain . or .. segments';
    }
    return null;
  }

  WebDavConfig copyWith({
    WebDavPreset? preset,
    String? serverUrl,
    String? username,
    String? password,
    String? folder,
    String? nextcloudUserId,
    String? pinnedCertSha256,
    bool clearNextcloudUserId = false,
    bool clearPin = false,
  }) => WebDavConfig(
    preset: preset ?? this.preset,
    serverUrl: serverUrl ?? this.serverUrl,
    username: username ?? this.username,
    password: password ?? this.password,
    folder: folder ?? this.folder,
    nextcloudUserId: clearNextcloudUserId
        ? null
        : (nextcloudUserId ?? this.nextcloudUserId),
    pinnedCertSha256: clearPin ? null : (pinnedCertSha256 ?? this.pinnedCertSha256),
  );

  Map<String, Object?> toJson() => {
    'preset': preset.name,
    'serverUrl': serverUrl,
    'username': username,
    'password': password,
    'folder': folder,
    'nextcloudUserId': nextcloudUserId,
    'pinnedCertSha256': pinnedCertSha256,
  };

  /// Throws [TypeError] on a malformed blob; callers treat that as absent.
  factory WebDavConfig.fromJson(Map<String, Object?> json) => WebDavConfig(
    preset: WebDavPreset.fromName(json['preset'] as String?),
    serverUrl: json['serverUrl'] as String? ?? '',
    username: json['username'] as String,
    password: json['password'] as String,
    folder: json['folder'] as String? ?? kDefaultWebDavSyncFolder,
    nextcloudUserId: json['nextcloudUserId'] as String?,
    pinnedCertSha256: json['pinnedCertSha256'] as String?,
  );

  @override
  String toString() =>
      'WebDavConfig(${preset.name}, $displayLabel, folder: $folder)';
}
```

- [ ] **Step 5: Run tests and verify they pass**

Run: `flutter test test/core/services/cloud_storage/webdav/webdav_config_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/cloud_storage/webdav/webdav_preset.dart lib/core/services/cloud_storage/webdav/webdav_config.dart test/core/services/cloud_storage/webdav/webdav_config_test.dart
git commit -m "feat(sync): add WebDAV server presets and configuration"
```

---

### Task 3: Multistatus parser

**Files:**
- Create: `lib/core/services/cloud_storage/webdav/webdav_multistatus.dart`
- Test: `test/core/services/cloud_storage/webdav/webdav_multistatus_test.dart`

**Interfaces:**
- Produces:
  - `class DavResource { final List<String> pathSegments; final bool isCollection; final int? contentLength; final DateTime? lastModified; }` where `pathSegments` are the decoded, non-empty segments of the absolute server path.
  - `List<DavResource> parseMultistatus(String body)` (throws `FormatException` when the body is not a `multistatus` document).
  - `String? parseCurrentUserPrincipalId(String body)`.
  - `const String kPropfindBody` (the XML request body asking for `resourcetype`, `getcontentlength`, `getlastmodified`).
  - `const String kPrincipalPropfindBody`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_multistatus.dart';

const _nextcloudStyle = '''<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns">
 <d:response>
  <d:href>/remote.php/dav/files/alice/Submersion%20Media/</d:href>
  <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype>
   <d:getlastmodified>Fri, 09 Oct 2026 10:00:00 GMT</d:getlastmodified></d:prop>
   <d:status>HTTP/1.1 200 OK</d:status></d:propstat>
  <d:propstat><d:prop><d:getcontentlength/></d:prop>
   <d:status>HTTP/1.1 404 Not Found</d:status></d:propstat>
 </d:response>
 <d:response>
  <d:href>/remote.php/dav/files/alice/Submersion%20Media/a%20b.json</d:href>
  <d:propstat><d:prop><d:resourcetype/>
   <d:getcontentlength>42</d:getcontentlength>
   <d:getlastmodified>Fri, 09 Oct 2026 10:00:05 GMT</d:getlastmodified></d:prop>
   <d:status>HTTP/1.1 200 OK</d:status></d:propstat>
 </d:response>
</d:multistatus>''';

const _defaultNamespaceAbsoluteHrefs = '''<?xml version="1.0"?>
<multistatus xmlns="DAV:">
 <response>
  <href>https://nas.local:5006/Share/Submersion</href>
  <propstat><prop><resourcetype><collection/></resourcetype></prop>
   <status>HTTP/1.1 200 OK</status></propstat>
 </response>
 <response>
  <href>https://nas.local:5006/Share/Submersion/x.json</href>
  <propstat><prop><getcontentlength>7</getcontentlength></prop>
   <status>HTTP/1.1 200 OK</status></propstat>
 </response>
</multistatus>''';

void main() {
  test('prefixed namespace, percent-encoded paths, partial 404 propstat', () {
    final items = parseMultistatus(_nextcloudStyle);
    expect(items, hasLength(2));
    expect(items[0].pathSegments.last, 'Submersion Media');
    expect(items[0].isCollection, isTrue);
    expect(items[0].contentLength, isNull);
    expect(items[1].pathSegments.last, 'a b.json');
    expect(items[1].isCollection, isFalse);
    expect(items[1].contentLength, 42);
    expect(items[1].lastModified, DateTime.utc(2026, 10, 9, 10, 0, 5));
  });

  test('default namespace, absolute URL hrefs, no trailing slash', () {
    final items = parseMultistatus(_defaultNamespaceAbsoluteHrefs);
    expect(items[0].pathSegments, ['Share', 'Submersion']);
    expect(items[0].isCollection, isTrue);
    expect(items[1].pathSegments, ['Share', 'Submersion', 'x.json']);
    expect(items[1].lastModified, isNull);
  });

  test('a non-multistatus body is a FormatException', () {
    expect(() => parseMultistatus('<html>login</html>'), throwsFormatException);
    expect(() => parseMultistatus('not xml'), throwsFormatException);
  });

  test('current-user-principal yields the last path segment', () {
    const body = '''<d:multistatus xmlns:d="DAV:"><d:response>
      <d:href>/remote.php/dav/</d:href><d:propstat><d:prop>
      <d:current-user-principal><d:href>/remote.php/dav/principals/users/alice/</d:href></d:current-user-principal>
      </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>''';
    expect(parseCurrentUserPrincipalId(body), 'alice');
    expect(parseCurrentUserPrincipalId('<d:multistatus xmlns:d="DAV:"/>'), isNull);
  });
}
```

- [ ] **Step 2: Run and verify failure**

Run: `flutter test test/core/services/cloud_storage/webdav/webdav_multistatus_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
import 'dart:io';

import 'package:xml/xml.dart';

const String kPropfindBody =
    '<?xml version="1.0" encoding="utf-8"?>'
    '<d:propfind xmlns:d="DAV:"><d:prop>'
    '<d:resourcetype/><d:getcontentlength/><d:getlastmodified/>'
    '</d:prop></d:propfind>';

const String kPrincipalPropfindBody =
    '<?xml version="1.0" encoding="utf-8"?>'
    '<d:propfind xmlns:d="DAV:"><d:prop>'
    '<d:current-user-principal/>'
    '</d:prop></d:propfind>';

/// One `<response>` of a PROPFIND reply.
class DavResource {
  /// Decoded, non-empty segments of the server path (`/a%20b/` gives
  /// `['a b']`), whatever form the server wrote the href in.
  final List<String> pathSegments;
  final bool isCollection;
  final int? contentLength;
  final DateTime? lastModified;

  const DavResource({
    required this.pathSegments,
    required this.isCollection,
    this.contentLength,
    this.lastModified,
  });
}

/// Parses a 207 Multi-Status body. Namespace prefixes differ by server
/// (`d:`, `D:`, a default namespace), so elements match by local name.
/// Only properties in a propstat whose status is 2xx are read.
List<DavResource> parseMultistatus(String body) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(body);
  } on XmlException catch (e) {
    throw FormatException('Not a WebDAV multistatus reply: ${e.message}');
  }
  if (doc.rootElement.name.local != 'multistatus') {
    throw const FormatException('Not a WebDAV multistatus reply');
  }
  return [
    for (final response in _children(doc.rootElement, 'response'))
      ?_resource(response),
  ];
}

/// The user id from a `current-user-principal` reply
/// (`.../principals/users/<id>/`), or null when absent.
String? parseCurrentUserPrincipalId(String body) {
  try {
    final doc = XmlDocument.parse(body);
    for (final principal in _descendants(doc.rootElement, 'current-user-principal')) {
      final href = _descendants(principal, 'href').firstOrNull?.innerText.trim();
      if (href == null || href.isEmpty) continue;
      final segments = Uri.parse(href).pathSegments.where((s) => s.isNotEmpty);
      if (segments.isNotEmpty) return segments.last;
    }
  } on XmlException {
    return null;
  }
  return null;
}

DavResource? _resource(XmlElement response) {
  final href = _children(response, 'href').firstOrNull?.innerText.trim();
  if (href == null || href.isEmpty) return null;
  final segments = Uri.parse(href).pathSegments.where((s) => s.isNotEmpty).toList();

  var isCollection = false;
  int? length;
  DateTime? modified;
  for (final propstat in _children(response, 'propstat')) {
    final status = _children(propstat, 'status').firstOrNull?.innerText ?? '';
    if (!RegExp(r'\s2\d\d\s').hasMatch(' $status ')) continue;
    for (final prop in _children(propstat, 'prop')) {
      if (_descendants(prop, 'collection').isNotEmpty) isCollection = true;
      final len = _children(prop, 'getcontentlength').firstOrNull?.innerText.trim();
      if (len != null && len.isNotEmpty) length = int.tryParse(len);
      final lm = _children(prop, 'getlastmodified').firstOrNull?.innerText.trim();
      if (lm != null && lm.isNotEmpty) modified = _parseDate(lm);
    }
  }
  return DavResource(
    pathSegments: segments,
    isCollection: isCollection,
    contentLength: length,
    lastModified: modified,
  );
}

DateTime? _parseDate(String value) {
  try {
    return HttpDate.parse(value);
  } on HttpException {
    return DateTime.tryParse(value)?.toUtc();
  }
}

Iterable<XmlElement> _children(XmlElement parent, String local) =>
    parent.childElements.where((e) => e.name.local == local);

Iterable<XmlElement> _descendants(XmlElement parent, String local) =>
    parent.descendantElements.where((e) => e.name.local == local);
```

Note: `?_resource(response)` is a null-aware collection element (Dart 3.8+). If `flutter analyze` rejects it on this SDK, use `.map(_resource).nonNulls.toList()` instead.

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/services/cloud_storage/webdav/webdav_multistatus_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/cloud_storage/webdav/webdav_multistatus.dart test/core/services/cloud_storage/webdav/webdav_multistatus_test.dart
git commit -m "feat(sync): parse WebDAV multistatus replies"
```

---

### Task 4: Errors and certificate pinning

**Files:**
- Create: `lib/core/services/cloud_storage/webdav/webdav_errors.dart`
- Create: `lib/core/services/cloud_storage/webdav/webdav_tls.dart`
- Test: `test/core/services/cloud_storage/webdav/webdav_errors_test.dart`
- Test: `test/core/services/cloud_storage/webdav/webdav_tls_test.dart`

**Interfaces:**
- Consumes: `CloudStorageException(String message, [Object? cause, StackTrace? stackTrace])` from `cloud_storage_provider.dart`; `WebDavConfig.host` / `.port` / `.pinnedCertSha256` (Task 2); `TimeoutHttpClient` from `http_timeouts.dart`.
- Produces:
  - `enum WebDavErrorCode { invalidConfig, unauthorized, forbidden, notFound, notWebDav, redirected, conflict, tooLarge, insufficientStorage, locked, unreachable, server, unexpected, untrustedCertificate }`
  - `class WebDavException extends CloudStorageException` with `final WebDavErrorCode code; final int? statusCode; final String? location; final int? sizeBytes;` and `factory WebDavException.fromStatus(int status, {required String method, required Uri uri, String? location, String? bodyExcerpt, int? sizeBytes, bool isRoot = false})`.
  - `class WebDavCertificateDetails { host, port, sha256, subject, issuer, startValidity, endValidity }` with `factory WebDavCertificateDetails.fromCertificate(X509Certificate cert, String host, int port)` and `String get formattedFingerprint`.
  - `class WebDavUntrustedCertificateException extends WebDavException` with `final WebDavCertificateDetails certificate; final String? pinnedSha256; bool get pinMismatch`.
  - `String certificateSha256Hex(List<int> der)`, `String formatFingerprint(String hex)`, `bool pinAccepts({...})`.
  - `class CertificateTrustRecorder` with `CertificateTrustRecorder.forConfig(WebDavConfig)`, `bool evaluate(WebDavCertificateDetails)`, `bool onBadCertificate(X509Certificate, String, int)`, `WebDavCertificateDetails? takeRejected()`.
  - `http.Client createWebDavHttpClient(CertificateTrustRecorder recorder)`.

- [ ] **Step 1: Write the failing tests**

`webdav_errors_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';

void main() {
  final uri = Uri.parse('https://dav.test/dav/Submersion/a.json');

  WebDavException from(int status, {bool isRoot = false, String? location, int? size}) =>
      WebDavException.fromStatus(
        status,
        method: 'PUT',
        uri: uri,
        location: location,
        bodyExcerpt: '<error/>',
        sizeBytes: size,
        isRoot: isRoot,
      );

  test('status codes map to codes', () {
    expect(from(401).code, WebDavErrorCode.unauthorized);
    expect(from(403).code, WebDavErrorCode.forbidden);
    expect(from(404).code, WebDavErrorCode.notFound);
    expect(from(405).code, WebDavErrorCode.unexpected);
    expect(from(301, location: 'https://x/').code, WebDavErrorCode.redirected);
    expect(from(409).code, WebDavErrorCode.conflict);
    expect(from(413).code, WebDavErrorCode.tooLarge);
    expect(from(423).code, WebDavErrorCode.locked);
    expect(from(507).code, WebDavErrorCode.insufficientStorage);
    expect(from(502).code, WebDavErrorCode.server);
    expect(from(418).code, WebDavErrorCode.unexpected);
  });

  test('messages carry the actionable detail', () {
    expect(from(401).message, contains('app password'));
    expect(from(404, isRoot: true).message, contains('Check the server type and URL'));
    expect(from(301, location: 'https://new/').message, contains('https://new/'));
    expect(from(413, size: 25 * 1024 * 1024).message, contains('25 MB'));
    expect(from(401).displayMessage, contains('HTTP 401 PUT /dav/Submersion/a.json'));
  });

  test('the cause excerpt is bounded', () {
    final e = WebDavException.fromStatus(
      500,
      method: 'GET',
      uri: uri,
      bodyExcerpt: 'x' * 5000,
    );
    expect(e.cause.toString().length, lessThan(400));
  });
}
```

`webdav_tls_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_preset.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';

void main() {
  final pin = 'ab' * 32;
  WebDavCertificateDetails cert({String sha = '', String host = 'nas.local', int port = 5006}) =>
      WebDavCertificateDetails(
        host: host,
        port: port,
        sha256: sha.isEmpty ? pin : sha,
        subject: 'CN=nas.local',
        issuer: 'CN=nas.local',
        startValidity: DateTime.utc(2026),
        endValidity: DateTime.utc(2027),
      );
  WebDavConfig config({String? pinned}) => WebDavConfig(
    preset: WebDavPreset.synology,
    serverUrl: 'https://nas.local:5006',
    username: 'u',
    password: 'p',
    pinnedCertSha256: pinned,
  );

  test('fingerprints format as colon-separated uppercase pairs', () {
    expect(formatFingerprint('0a1bff'), '0A:1B:FF');
    expect(certificateSha256Hex([1, 2, 3]).length, 64);
  });

  test('a pin accepts only the same cert on the same host and port', () {
    final recorder = CertificateTrustRecorder.forConfig(config(pinned: pin));
    expect(recorder.evaluate(cert()), isTrue);
    expect(recorder.takeRejected(), isNull);
    expect(recorder.evaluate(cert(sha: 'cd' * 32)), isFalse);
    expect(recorder.takeRejected()!.sha256, 'cd' * 32);
    expect(recorder.evaluate(cert(host: 'evil.example')), isFalse);
    expect(recorder.evaluate(cert(port: 443)), isFalse);
  });

  test('with no pin every untrusted cert is rejected and recorded once', () {
    final recorder = CertificateTrustRecorder.forConfig(config());
    expect(recorder.evaluate(cert()), isFalse);
    expect(recorder.takeRejected(), isNotNull);
    expect(recorder.takeRejected(), isNull);
  });

  test('untrusted exception flags a changed certificate', () {
    final first = WebDavUntrustedCertificateException(cert());
    final changed = WebDavUntrustedCertificateException(cert(sha: 'cd' * 32), pinnedSha256: pin);
    expect(first.pinMismatch, isFalse);
    expect(first.message, contains('nas.local'));
    expect(changed.pinMismatch, isTrue);
    expect(changed.code, WebDavErrorCode.untrustedCertificate);
  });
}
```

- [ ] **Step 2: Run and verify failure**

Run: `flutter test test/core/services/cloud_storage/webdav/webdav_errors_test.dart test/core/services/cloud_storage/webdav/webdav_tls_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `webdav_errors.dart`**

```dart
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';

/// Why a WebDAV operation failed. The settings UI localizes from this; the
/// English [CloudStorageException.message] is for the sync status line and
/// logs.
enum WebDavErrorCode {
  invalidConfig,
  unauthorized,
  forbidden,
  notFound,
  notWebDav,
  redirected,
  conflict,
  tooLarge,
  insufficientStorage,
  locked,
  unreachable,
  server,
  unexpected,
  untrustedCertificate,
}

class WebDavException extends CloudStorageException {
  WebDavException(
    String message, {
    required this.code,
    this.statusCode,
    this.location,
    this.sizeBytes,
    Object? cause,
  }) : super(message, cause);

  final WebDavErrorCode code;
  final int? statusCode;

  /// The redirect target, for [WebDavErrorCode.redirected].
  final String? location;

  /// The refused upload's size, for [WebDavErrorCode.tooLarge].
  final int? sizeBytes;

  static const int _excerptLimit = 300;

  /// Maps a non-success reply. [isRoot] marks a request for the DAV root
  /// itself, whose 404 means the address is wrong rather than a file being
  /// absent. The cause carries method, path and a bounded body excerpt;
  /// URIs never hold credentials (auth is a header), so it is safe to show.
  factory WebDavException.fromStatus(
    int status, {
    required String method,
    required Uri uri,
    String? location,
    String? bodyExcerpt,
    int? sizeBytes,
    bool isRoot = false,
  }) {
    final excerpt = (bodyExcerpt ?? '').trim();
    final bounded = excerpt.length <= _excerptLimit
        ? excerpt
        : '${excerpt.substring(0, _excerptLimit)}...';
    final cause = 'HTTP $status $method ${uri.path}'
        '${bounded.isEmpty ? '' : ': $bounded'}';
    final (code, message) = switch (status) {
      401 => (
        WebDavErrorCode.unauthorized,
        'The server rejected the username or password. If the account uses '
            'two-factor sign-in, create an app password.',
      ),
      403 => (WebDavErrorCode.forbidden, 'No permission for this folder on the WebDAV server.'),
      404 when isRoot => (
        WebDavErrorCode.notFound,
        'No WebDAV folder at this address. Check the server type and URL.',
      ),
      404 => (WebDavErrorCode.notFound, 'Not found on the WebDAV server.'),
      >= 300 && < 400 => (
        WebDavErrorCode.redirected,
        'The server redirected to ${location ?? 'another address'}. Use that address instead.',
      ),
      409 => (WebDavErrorCode.conflict, 'The parent folder does not exist on the WebDAV server.'),
      413 => (
        WebDavErrorCode.tooLarge,
        'The server refused a file of ${_megabytes(sizeBytes)} MB as too large. '
            'Raise its upload limit.',
      ),
      423 => (WebDavErrorCode.locked, 'The file is locked on the WebDAV server.'),
      507 => (WebDavErrorCode.insufficientStorage, 'The WebDAV server is out of storage.'),
      >= 500 => (WebDavErrorCode.server, 'The WebDAV server returned an error (HTTP $status).'),
      _ => (WebDavErrorCode.unexpected, 'Unexpected reply from the WebDAV server (HTTP $status).'),
    };
    return WebDavException(
      message,
      code: code,
      statusCode: status,
      location: location,
      sizeBytes: sizeBytes,
      cause: cause,
    );
  }

  static String _megabytes(int? bytes) =>
      bytes == null ? '?' : (bytes / (1024 * 1024)).round().toString();
}

/// The server presented a certificate that failed normal verification and
/// does not match the stored pin.
class WebDavUntrustedCertificateException extends WebDavException {
  WebDavUntrustedCertificateException(
    this.certificate, {
    this.pinnedSha256,
    Object? cause,
  }) : super(
         pinnedSha256 == null
             ? 'The server certificate for ${certificate.host} is not trusted.'
             : 'The server certificate for ${certificate.host} changed since you trusted it.',
         code: WebDavErrorCode.untrustedCertificate,
         cause: cause,
       );

  final WebDavCertificateDetails certificate;

  /// The pin stored when this was raised, or null when none was.
  final String? pinnedSha256;

  bool get pinMismatch => pinnedSha256 != null;
}
```

- [ ] **Step 4: Implement `webdav_tls.dart`**

```dart
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'package:submersion/core/services/cloud_storage/http_timeouts.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';

/// What the trust dialog shows about a rejected certificate.
class WebDavCertificateDetails {
  const WebDavCertificateDetails({
    required this.host,
    required this.port,
    required this.sha256,
    required this.subject,
    required this.issuer,
    required this.startValidity,
    required this.endValidity,
  });

  factory WebDavCertificateDetails.fromCertificate(
    X509Certificate cert,
    String host,
    int port,
  ) => WebDavCertificateDetails(
    host: host,
    port: port,
    sha256: certificateSha256Hex(cert.der),
    subject: cert.subject,
    issuer: cert.issuer,
    startValidity: cert.startValidity,
    endValidity: cert.endValidity,
  );

  final String host;
  final int port;

  /// Lowercase hex SHA-256 of the DER encoding.
  final String sha256;
  final String subject;
  final String issuer;
  final DateTime startValidity;
  final DateTime endValidity;

  String get formattedFingerprint => formatFingerprint(sha256);
}

String certificateSha256Hex(List<int> der) => sha256.convert(der).toString();

/// `0a1bff` as `0A:1B:FF`.
String formatFingerprint(String hex) {
  final upper = hex.toUpperCase();
  return [
    for (var i = 0; i + 1 < upper.length; i += 2) upper.substring(i, i + 2),
  ].join(':');
}

/// Whether a certificate that failed normal verification is the one the
/// user trusted, on the server the user configured.
bool pinAccepts({
  required String? pinnedSha256,
  required WebDavCertificateDetails presented,
  required String expectedHost,
  required int expectedPort,
}) =>
    pinnedSha256 != null &&
    pinnedSha256.toLowerCase() == presented.sha256.toLowerCase() &&
    presented.host.toLowerCase() == expectedHost.toLowerCase() &&
    presented.port == expectedPort;

/// The `badCertificateCallback` for one client. Dart calls it only for a
/// certificate that failed normal verification, so a CA-valid certificate
/// never reaches it and a stale pin is harmless. A rejection is recorded so
/// the client can turn the resulting handshake failure into a
/// [WebDavUntrustedCertificateException] the trust dialog can show.
class CertificateTrustRecorder {
  CertificateTrustRecorder({
    required this.expectedHost,
    required this.expectedPort,
    this.pinnedSha256,
  });

  factory CertificateTrustRecorder.forConfig(WebDavConfig config) =>
      CertificateTrustRecorder(
        expectedHost: config.host,
        expectedPort: config.port,
        pinnedSha256: config.pinnedCertSha256,
      );

  final String expectedHost;
  final int expectedPort;
  final String? pinnedSha256;

  WebDavCertificateDetails? _rejected;

  /// True to accept [presented]; false records it as the last rejection.
  bool evaluate(WebDavCertificateDetails presented) {
    if (pinAccepts(
      pinnedSha256: pinnedSha256,
      presented: presented,
      expectedHost: expectedHost,
      expectedPort: expectedPort,
    )) {
      return true;
    }
    _rejected = presented;
    return false;
  }

  bool onBadCertificate(X509Certificate cert, String host, int port) =>
      evaluate(WebDavCertificateDetails.fromCertificate(cert, host, port));

  /// The last rejected certificate, cleared on read.
  WebDavCertificateDetails? takeRejected() {
    final rejected = _rejected;
    _rejected = null;
    return rejected;
  }
}

/// A deadline-bounded transport whose TLS layer consults [recorder]. Built
/// with `HttpClient()`, so `TrustedHttpOverrides` (the Windows root store)
/// still applies.
http.Client createWebDavHttpClient(CertificateTrustRecorder recorder) {
  final inner = HttpClient()
    ..connectionTimeout = TimeoutHttpClient.defaultConnectTimeout
    ..badCertificateCallback = recorder.onBadCertificate;
  return TimeoutHttpClient(
    IOClient(inner),
    connectTimeout: TimeoutHttpClient.defaultConnectTimeout,
  );
}
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/core/services/cloud_storage/webdav/webdav_errors_test.dart test/core/services/cloud_storage/webdav/webdav_tls_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/cloud_storage/webdav/webdav_errors.dart lib/core/services/cloud_storage/webdav/webdav_tls.dart test/core/services/cloud_storage/webdav/webdav_errors_test.dart test/core/services/cloud_storage/webdav/webdav_tls_test.dart
git commit -m "feat(sync): map WebDAV errors and pin self-signed certificates"
```

---

### Task 5: Fake WebDAV server and the protocol client

**Files:**
- Create: `test/helpers/fake_webdav_server.dart`
- Create: `lib/core/services/cloud_storage/webdav/webdav_client.dart`
- Test: `test/core/services/cloud_storage/webdav/webdav_client_test.dart`

**Interfaces:**
- Consumes: Tasks 2 to 4.
- Produces:
  - `class WebDavEntry { final String path; final bool isCollection; final int? sizeBytes; final DateTime lastModified; String get name; }` where `path` is relative to the DAV root, `''` for the root, no leading or trailing slash.
  - `class WebDavClient` with constructor `WebDavClient(WebDavConfig config, {http.Client? httpClient, CertificateTrustRecorder? trustRecorder, int maxAttempts = 6, Duration Function(int attempt)? backoff})` and members:
    - `final WebDavConfig config;` and `bool chunkingUnsupported;`
    - `Uri uriFor(String path, {bool collection = false})`
    - `Future<WebDavEntry?> stat(String path)` (the root `''` throws `notFound` instead of returning null)
    - `Future<List<WebDavEntry>> listChildren(String path)`
    - `Future<Uint8List> getBytes(String path)`
    - `Future<void> getToFile(String path, File destination, {TransferProgressCallback? onProgress})`
    - `Future<void> putBytes(String path, Uint8List data, {String contentType = 'application/octet-stream'})`
    - `Future<void> putFile(String path, File source, {String contentType = 'application/octet-stream', TransferProgressCallback? onProgress})`
    - `Future<void> delete(String path)`
    - `Future<void> ensureCollection(String path)`
    - `Future<http.StreamedResponse> request(String method, Uri uri, {Map<String, String> headers = const {}, Uint8List? bytes, Set<int> accept = const {}, bool isRoot = false})`
    - `Future<List<DavResource>> propfindRaw(Uri uri, int depth)`
    - `Future<String?> resolveNextcloudUserId()`
    - `void close()`
    - `static String parentOf(String path)`
  - `FakeWebDavServer` (test helper) with `client`, `files`, `collections`, `captured`, `forcedStatuses`, `forcedHeaders`, `throwNext` / `throwCount`, `absoluteHrefs`, `maxPutBytes`, `principalUserId`, `chunkingEnabled`, `moveFailsAfterApplying`, `seedCollection`, `seedFile`, `count(method)`.

- [ ] **Step 1: Write the fake server**

```dart
import 'dart:convert';
import 'dart:io' show HttpDate;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// In-memory WebDAV server for MockClient: PROPFIND (Depth 0 and 1),
/// GET, PUT, DELETE, MKCOL and MOVE over a tree of decoded absolute paths,
/// Basic auth, Nextcloud `current-user-principal`, and Nextcloud chunking v2
/// (`MOVE <uploadDir>/.file` assembles the numbered chunks).
class FakeWebDavServer {
  FakeWebDavServer({
    this.origin = 'https://dav.test',
    this.username = 'alice',
    this.password = 'secret',
    Iterable<String> seedCollections = const ['/dav'],
  }) {
    seedCollection('/');
    seedCollections.forEach(seedCollection);
  }

  final String origin;
  final String username;
  final String password;

  /// Decoded absolute path (`/dav/Submersion/a b.json`) to bytes.
  final Map<String, Uint8List> files = {};
  final Set<String> collections = {};
  final Map<String, DateTime> modified = {};
  final List<http.Request> captured = [];

  DateTime Function() now = () => DateTime.utc(2026, 10, 9, 10);

  /// Write hrefs as full URLs instead of absolute paths.
  bool absoluteHrefs = false;

  /// Answer the next requests with these statuses, one per request.
  final List<int> forcedStatuses = [];
  Map<String, String> forcedHeaders = const {};

  /// Throw [throwNext] for the next [throwCount] requests.
  Object? throwNext;
  int throwCount = 0;

  /// PUT bodies above this many bytes answer 413.
  int? maxPutBytes;

  /// Answer `current-user-principal` with this id; null answers 404.
  String? principalUserId;

  /// False makes MKCOL under `/remote.php/dav/uploads` answer 501.
  bool chunkingEnabled = true;

  /// The next chunk-assembly MOVE applies, then fails in transit.
  bool moveFailsAfterApplying = false;

  MockClient get client => MockClient(_handle);

  int count(String method) => captured.where((r) => r.method == method).length;

  void seedCollection(String path) {
    var p = _norm(path);
    while (true) {
      collections.add(p);
      modified[p] = now();
      if (p == '/') return;
      p = _parent(p);
    }
  }

  void seedFile(String path, List<int> bytes) {
    final p = _norm(path);
    seedCollection(_parent(p));
    files[p] = Uint8List.fromList(bytes);
    modified[p] = now();
  }

  static String _norm(String path) =>
      '/${path.split('/').where((s) => s.isNotEmpty).join('/')}';

  static String _pathOf(Uri uri) =>
      '/${uri.pathSegments.where((s) => s.isNotEmpty).join('/')}';

  static String _parent(String path) {
    final i = path.lastIndexOf('/');
    return i <= 0 ? '/' : path.substring(0, i);
  }

  Future<http.Response> _handle(http.Request request) async {
    captured.add(request);
    if (throwCount > 0) {
      throwCount--;
      throw throwNext!;
    }
    if (forcedStatuses.isNotEmpty) {
      return http.Response('forced', forcedStatuses.removeAt(0), headers: forcedHeaders);
    }
    final expected = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    if (request.headers['authorization'] != expected) {
      return http.Response('', 401);
    }
    final path = _pathOf(request.url);
    return switch (request.method) {
      'PROPFIND' => _propfind(request, path),
      'GET' => files.containsKey(path)
          ? http.Response.bytes(files[path]!, 200)
          : http.Response('', 404),
      'PUT' => _put(path, request.bodyBytes),
      'DELETE' => _delete(path),
      'MKCOL' => _mkcol(path),
      'MOVE' => _move(request, path),
      _ => http.Response('', 405),
    };
  }

  http.Response _propfind(http.Request request, String path) {
    if (request.body.contains('current-user-principal')) {
      final id = principalUserId;
      if (id == null) return http.Response('', 404);
      return http.Response(
        '<d:multistatus xmlns:d="DAV:"><d:response><d:href>$path/</d:href>'
        '<d:propstat><d:prop><d:current-user-principal>'
        '<d:href>/remote.php/dav/principals/users/$id/</d:href>'
        '</d:current-user-principal></d:prop>'
        '<d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>'
        '</d:multistatus>',
        207,
      );
    }
    if (!collections.contains(path) && !files.containsKey(path)) {
      return http.Response('', 404);
    }
    final depth = request.headers['depth'];
    final entries = [
      path,
      if (depth == '1' && collections.contains(path)) ..._childrenOf(path),
    ];
    return http.Response(
      _multistatus(entries),
      207,
      headers: {'content-type': 'application/xml; charset=utf-8'},
    );
  }

  Iterable<String> _childrenOf(String path) => [
    ...collections.where((c) => c != path && c != '/' && _parent(c) == path),
    ...files.keys.where((f) => _parent(f) == path),
  ];

  String _multistatus(List<String> paths) {
    final buffer = StringBuffer('<d:multistatus xmlns:d="DAV:">');
    for (final p in paths) {
      final isCol = collections.contains(p);
      final segs = p.split('/').where((s) => s.isNotEmpty).toList();
      var href = '/${Uri(pathSegments: segs).path}';
      if (isCol && href != '/') href = '$href/';
      if (absoluteHrefs) href = '$origin$href';
      buffer
        ..write('<d:response><d:href>$href</d:href><d:propstat><d:prop>')
        ..write(isCol ? '<d:resourcetype><d:collection/></d:resourcetype>' : '<d:resourcetype/>')
        ..write(isCol ? '' : '<d:getcontentlength>${files[p]!.length}</d:getcontentlength>')
        ..write('<d:getlastmodified>${HttpDate.format(modified[p] ?? now())}</d:getlastmodified>')
        ..write('</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>');
    }
    buffer.write('</d:multistatus>');
    return buffer.toString();
  }

  http.Response _put(String path, Uint8List bytes) {
    if (collections.contains(path)) return http.Response('', 405);
    if (!collections.contains(_parent(path))) return http.Response('', 409);
    final limit = maxPutBytes;
    if (limit != null && bytes.length > limit) return http.Response('', 413);
    final existed = files.containsKey(path);
    files[path] = bytes;
    modified[path] = now();
    return http.Response('', existed ? 204 : 201);
  }

  http.Response _delete(String path) {
    if (files.remove(path) != null) return http.Response('', 204);
    if (!collections.contains(path)) return http.Response('', 404);
    _removeTree(path);
    return http.Response('', 204);
  }

  void _removeTree(String path) {
    collections.removeWhere((c) => c == path || c.startsWith('$path/'));
    files.removeWhere((f, _) => f.startsWith('$path/'));
  }

  http.Response _mkcol(String path) {
    if (!chunkingEnabled && path.startsWith('/remote.php/dav/uploads/')) {
      return http.Response('', 501);
    }
    if (collections.contains(path) || files.containsKey(path)) {
      return http.Response('', 405);
    }
    if (!collections.contains(_parent(path))) return http.Response('', 409);
    collections.add(path);
    modified[path] = now();
    return http.Response('', 201);
  }

  http.Response _move(http.Request request, String path) {
    final destination = request.headers['destination'];
    if (destination == null) return http.Response('', 400);
    final destPath = _pathOf(Uri.parse(destination));
    if (!collections.contains(_parent(destPath))) return http.Response('', 409);
    if (path.endsWith('/.file')) {
      final dir = _parent(path);
      if (!collections.contains(dir)) return http.Response('', 404);
      final chunkNames = files.keys.where((f) => _parent(f) == dir).toList()..sort();
      final builder = BytesBuilder(copy: false);
      for (final name in chunkNames) {
        builder.add(files[name]!);
      }
      files[destPath] = builder.takeBytes();
      modified[destPath] = now();
      _removeTree(dir);
      if (moveFailsAfterApplying) {
        moveFailsAfterApplying = false;
        throw http.ClientException('connection reset after MOVE');
      }
      return http.Response('', 201);
    }
    final bytes = files.remove(path);
    if (bytes == null) return http.Response('', 404);
    files[destPath] = bytes;
    modified[destPath] = now();
    return http.Response('', 201);
  }
}
```

- [ ] **Step 2: Write the failing client tests**

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_preset.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';

import '../../../../helpers/fake_webdav_server.dart';

WebDavConfig _config({String password = 'secret'}) => WebDavConfig(
  preset: WebDavPreset.other,
  serverUrl: 'https://dav.test/dav',
  username: 'alice',
  password: password,
);

class _Recording extends http.BaseClient {
  _Recording(this.inner);
  final http.Client inner;
  final seen = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    seen.add(request);
    return inner.send(request);
  }
}

class _HandshakeFailingClient extends http.BaseClient {
  _HandshakeFailingClient(this.recorder, this.details);
  final CertificateTrustRecorder recorder;
  final WebDavCertificateDetails details;
  int sends = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sends++;
    recorder.evaluate(details);
    throw const HandshakeException('CERTIFICATE_VERIFY_FAILED');
  }
}

void main() {
  late FakeWebDavServer server;
  late WebDavClient client;
  late Directory tmp;

  setUp(() async {
    server = FakeWebDavServer();
    client = WebDavClient(
      _config(),
      httpClient: server.client,
      backoff: (_) => Duration.zero,
    );
    tmp = await Directory.systemTemp.createTemp('webdav_client_test');
  });

  tearDown(() async {
    client.close();
    await tmp.delete(recursive: true);
  });

  test('uriFor percent-encodes segments under the DAV root', () {
    expect(
      client.uriFor('Submersion Media/a b.json').toString(),
      'https://dav.test/dav/Submersion%20Media/a%20b.json',
    );
    expect(client.uriFor('x', collection: true).path, '/dav/x/');
  });

  test('round-trips bytes with Basic auth and creates missing parents on 409', () async {
    await client.putBytes('Submersion/deep/a b.json', utf8.encode('hello'));
    expect(server.files['/dav/Submersion/deep/a b.json'], utf8.encode('hello'));
    expect(utf8.decode(await client.getBytes('Submersion/deep/a b.json')), 'hello');
    expect(server.captured.every((r) => !r.followRedirects), isTrue);
  });

  test('stat and listChildren decode names and work with absolute hrefs', () async {
    server
      ..absoluteHrefs = true
      ..seedFile('/dav/Submersion Media/x y.json', [1, 2, 3])
      ..seedCollection('/dav/Submersion Media/sub');
    final children = await client.listChildren('Submersion Media');
    expect(children.map((e) => e.name), unorderedEquals(['x y.json', 'sub']));
    final file = children.firstWhere((e) => !e.isCollection);
    expect(file.path, 'Submersion Media/x y.json');
    expect(file.sizeBytes, 3);
    expect(await client.stat('Submersion Media/missing.json'), isNull);
    expect((await client.stat(''))!.isCollection, isTrue);
  });

  test('a missing DAV root is a notFound naming the address', () async {
    server.collections.remove('/dav');
    await expectLater(
      client.stat(''),
      throwsA(isA<WebDavException>()
          .having((e) => e.code, 'code', WebDavErrorCode.notFound)
          .having((e) => e.message, 'message', contains('server type and URL'))),
    );
  });

  test('ensureCollection creates nested levels once and caches them', () async {
    await client.ensureCollection('a/b/c');
    expect(server.collections, containsAll(['/dav/a', '/dav/a/b', '/dav/a/b/c']));
    final before = server.count('MKCOL');
    await client.ensureCollection('a/b/c');
    expect(server.count('MKCOL'), before);
  });

  test('putFile streams with Content-Length and reports progress', () async {
    // MockClient re-buffers every request, so record the ORIGINAL request
    // to see that it was streamed with an explicit length.
    final recording = _Recording(server.client);
    final streaming = WebDavClient(_config(), httpClient: recording, backoff: (_) => Duration.zero);
    addTearDown(streaming.close);
    final source = File(p.join(tmp.path, 'big.bin'));
    await source.writeAsBytes(List<int>.generate(300000, (i) => i % 251));
    int? last;
    await streaming.putFile('Submersion/big.bin', source, onProgress: (sent, total) => last = sent);
    final put = recording.seen.lastWhere((r) => r.method == 'PUT');
    expect(put, isA<http.StreamedRequest>());
    expect(put.contentLength, 300000);
    expect(server.files['/dav/Submersion/big.bin']!.length, 300000);
    expect(last, 300000);
  });

  test('getToFile writes the file and leaves nothing behind on failure', () async {
    server.seedFile('/dav/Submersion/a.bin', [9, 8, 7]);
    final dest = File(p.join(tmp.path, 'a.bin'));
    await client.getToFile('Submersion/a.bin', dest);
    expect(await dest.readAsBytes(), [9, 8, 7]);

    final missing = File(p.join(tmp.path, 'missing.bin'));
    await expectLater(client.getToFile('Submersion/nope.bin', missing), throwsA(isA<WebDavException>()));
    expect(await missing.exists(), isFalse);
  });

  test('delete of a missing path succeeds', () async {
    await client.delete('Submersion/nope.json');
  });

  test('401 asks for an app password and never prints the password', () async {
    final bad = WebDavClient(_config(password: 'wrong'), httpClient: server.client, backoff: (_) => Duration.zero);
    addTearDown(bad.close);
    try {
      await bad.getBytes('x');
      fail('expected a WebDavException');
    } on WebDavException catch (e) {
      expect(e.code, WebDavErrorCode.unauthorized);
      expect(e.displayMessage, contains('HTTP 401'));
      expect(e.toString(), isNot(contains('wrong')));
    }
  });

  test('a redirect is reported with its target, not followed', () async {
    server
      ..forcedStatuses.add(301)
      ..forcedHeaders = {'location': 'https://dav.test/dav2/'};
    await expectLater(
      client.stat(''),
      throwsA(isA<WebDavException>()
          .having((e) => e.code, 'code', WebDavErrorCode.redirected)
          .having((e) => e.message, 'message', contains('https://dav.test/dav2/'))),
    );
  });

  test('413 names the refused size', () async {
    server.maxPutBytes = 10;
    await expectLater(
      client.putBytes('Submersion/a.bin', Uint8List(2 * 1024 * 1024)),
      throwsA(isA<WebDavException>()
          .having((e) => e.code, 'code', WebDavErrorCode.tooLarge)
          .having((e) => e.message, 'message', contains('2 MB'))),
    );
  });

  test('5xx and transport errors retry; 507 does not', () async {
    server.forcedStatuses.addAll([503, 503]);
    await client.stat('');
    expect(server.count('PROPFIND'), 3);

    server.forcedStatuses.add(507);
    await expectLater(client.putBytes('x', Uint8List(1)), throwsA(isA<WebDavException>()));
    expect(server.count('PUT'), 1);

    server
      ..throwNext = const SocketException('down')
      ..throwCount = 6;
    await expectLater(
      client.stat(''),
      throwsA(isA<WebDavException>().having((e) => e.code, 'code', WebDavErrorCode.unreachable)),
    );
  });

  test('a PROPFIND answered with HTML is not a WebDAV endpoint', () async {
    final html = WebDavClient(
      _config(),
      httpClient: MockClient((_) async => http.Response('<html>login</html>', 200)),
      backoff: (_) => Duration.zero,
    );
    addTearDown(html.close);
    await expectLater(
      html.stat(''),
      throwsA(isA<WebDavException>().having((e) => e.code, 'code', WebDavErrorCode.notWebDav)),
    );
  });

  test('an untrusted certificate surfaces its details and is not retried', () async {
    final config = _config();
    final recorder = CertificateTrustRecorder.forConfig(config);
    final failing = _HandshakeFailingClient(
      recorder,
      WebDavCertificateDetails(
        host: 'dav.test',
        port: 443,
        sha256: 'ab' * 32,
        subject: 'CN=dav.test',
        issuer: 'CN=dav.test',
        startValidity: DateTime.utc(2026),
        endValidity: DateTime.utc(2027),
      ),
    );
    final pinned = WebDavClient(config, httpClient: failing, trustRecorder: recorder, backoff: (_) => Duration.zero);
    addTearDown(pinned.close);
    await expectLater(
      pinned.stat(''),
      throwsA(isA<WebDavUntrustedCertificateException>()
          .having((e) => e.certificate.sha256, 'sha', 'ab' * 32)),
    );
    expect(failing.sends, 1);
  });

  test('resolves the Nextcloud user id from current-user-principal', () async {
    final nc = FakeWebDavServer(
      username: 'alice@example.com',
      seedCollections: const ['/remote.php/dav/files/alice'],
    )..principalUserId = 'alice';
    final ncClient = WebDavClient(
      WebDavConfig(
        preset: WebDavPreset.nextcloud,
        serverUrl: 'https://dav.test',
        username: 'alice@example.com',
        password: 'secret',
      ),
      httpClient: nc.client,
      backoff: (_) => Duration.zero,
    );
    addTearDown(ncClient.close);
    expect(await ncClient.resolveNextcloudUserId(), 'alice');
  });
}
```

- [ ] **Step 3: Run and verify failure**

Run: `flutter test test/core/services/cloud_storage/webdav/webdav_client_test.dart`
Expected: FAIL (no `webdav_client.dart`).

- [ ] **Step 4: Implement `webdav_client.dart`**

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_multistatus.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart'
    show TransferProgressCallback;

/// A file or collection under the DAV root.
class WebDavEntry {
  const WebDavEntry({
    required this.path,
    required this.isCollection,
    required this.lastModified,
    this.sizeBytes,
  });

  /// Relative to the DAV root: `''` for the root, otherwise `a/b.json`.
  final String path;
  final bool isCollection;
  final int? sizeBytes;
  final DateTime lastModified;

  String get name => path.isEmpty ? '' : path.split('/').last;
}

/// Minimal WebDAV client: the verbs the sync provider and media store need,
/// with retry, redirect reporting, certificate pinning and streaming.
///
/// Paths are relative to [WebDavConfig.davRoot] and use `/` as the
/// separator; they are percent-encoded segment by segment. Every request
/// carries Basic auth in a header, never in the URL, and never follows a
/// redirect: `package:http` follows them only for GET and HEAD, so a
/// redirecting server would otherwise fail differently per verb.
class WebDavClient {
  WebDavClient(
    this.config, {
    http.Client? httpClient,
    CertificateTrustRecorder? trustRecorder,
    int maxAttempts = 6,
    Duration Function(int attempt)? backoff,
  }) : _trust = trustRecorder ?? CertificateTrustRecorder.forConfig(config),
       _maxAttempts = maxAttempts,
       _backoff = backoff ?? _defaultBackoff {
    _http = httpClient ?? createWebDavHttpClient(_trust);
  }

  final WebDavConfig config;
  final CertificateTrustRecorder _trust;
  final int _maxAttempts;
  final Duration Function(int attempt) _backoff;
  late final http.Client _http;
  final Set<String> _knownCollections = {};

  /// Set once the server refuses Nextcloud chunking; later large uploads go
  /// straight to a single PUT.
  bool chunkingUnsupported = false;

  static final Random _random = Random();

  static Duration _defaultBackoff(int attempt) {
    final base = min(250 * (1 << attempt), 8000);
    return Duration(milliseconds: base + _random.nextInt(base ~/ 2 + 1));
  }

  String get _authorization =>
      'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}';

  static List<String> _segments(String path) =>
      path.split('/').where((s) => s.isNotEmpty).toList();

  /// `a/b/c` gives `a/b`; a top-level path gives `''`.
  static String parentOf(String path) {
    final segments = _segments(path);
    return segments.isEmpty ? '' : segments.sublist(0, segments.length - 1).join('/');
  }

  /// Decoded segments of the DAV root. `Uri.pathSegments` is decoded, and
  /// `Uri.replace(pathSegments:)` encodes, so building from the raw `path`
  /// would double-encode a root like `files/alice%40example.com/`.
  List<String> get _rootSegments =>
      config.davRoot.pathSegments.where((s) => s.isNotEmpty).toList();

  Uri uriFor(String path, {bool collection = false}) {
    final segments = [..._rootSegments, ..._segments(path)];
    return config.davRoot.replace(pathSegments: [...segments, if (collection) '']);
  }

  /// Sends one request with retry. Statuses in [accept] are returned to the
  /// caller instead of raising; every other non-2xx raises a
  /// [WebDavException]. The caller must consume or drain the body.
  Future<http.StreamedResponse> request(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    Uint8List? bytes,
    Set<int> accept = const {},
    bool isRoot = false,
  }) => _send(method, uri, headers: headers, bytes: bytes, accept: accept, isRoot: isRoot);

  Future<http.StreamedResponse> _send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    Uint8List? bytes,
    Stream<List<int>> Function()? stream,
    int? streamLength,
    Set<int> accept = const {},
    bool isRoot = false,
  }) async {
    for (var attempt = 0; ; attempt++) {
      final http.BaseRequest request;
      if (stream != null) {
        final streamed = http.StreamedRequest(method, uri)..contentLength = streamLength;
        stream().listen(
          streamed.sink.add,
          onError: streamed.sink.addError,
          onDone: streamed.sink.close,
          cancelOnError: true,
        );
        request = streamed;
      } else {
        final plain = http.Request(method, uri);
        if (bytes != null) plain.bodyBytes = bytes;
        request = plain;
      }
      request
        ..followRedirects = false
        ..headers.addAll(headers)
        ..headers['authorization'] = _authorization;

      final http.StreamedResponse response;
      try {
        response = await _http.send(request);
      } on Object catch (e) {
        if (e is! IOException && e is! http.ClientException && e is! TimeoutException) {
          rethrow;
        }
        final rejected = _trust.takeRejected();
        if (rejected != null) {
          throw WebDavUntrustedCertificateException(
            rejected,
            pinnedSha256: config.pinnedCertSha256,
            cause: e,
          );
        }
        if (attempt + 1 >= _maxAttempts) {
          throw WebDavException(
            'Could not reach ${config.host}.',
            code: WebDavErrorCode.unreachable,
            cause: e,
          );
        }
        await Future<void>.delayed(_backoff(attempt));
        continue;
      }

      final status = response.statusCode;
      if ((status >= 200 && status < 300) || accept.contains(status)) {
        return response;
      }
      if (_isRetryable(status) && attempt + 1 < _maxAttempts) {
        await response.stream.drain<void>();
        await Future<void>.delayed(_backoff(attempt));
        continue;
      }
      final excerpt = await _excerpt(response);
      throw WebDavException.fromStatus(
        status,
        method: method,
        uri: uri,
        location: response.headers['location'],
        bodyExcerpt: excerpt,
        sizeBytes: bytes?.length ?? streamLength,
        isRoot: isRoot,
      );
    }
  }

  static bool _isRetryable(int status) =>
      status == 429 || status == 423 || (status >= 500 && status != 507);

  static Future<String> _excerpt(http.StreamedResponse response) async {
    try {
      final body = await response.stream.bytesToString();
      return body.length <= 1000 ? body : body.substring(0, 1000);
    } catch (_) {
      return '';
    }
  }

  Future<List<DavResource>> propfindRaw(Uri uri, int depth, {bool isRoot = false}) async {
    final response = await _send(
      'PROPFIND',
      uri,
      headers: {'depth': '$depth', 'content-type': 'application/xml; charset=utf-8'},
      bytes: utf8.encode(kPropfindBody),
      isRoot: isRoot,
    );
    final body = await response.stream.bytesToString();
    if (response.statusCode != 207) throw _notWebDav(uri);
    try {
      return parseMultistatus(body);
    } on FormatException catch (e) {
      throw _notWebDav(uri, e);
    }
  }

  WebDavException _notWebDav(Uri uri, [Object? cause]) => WebDavException(
    'This address is not a WebDAV endpoint.',
    code: WebDavErrorCode.notWebDav,
    cause: cause ?? 'PROPFIND ${uri.path} did not answer 207 Multi-Status',
  );

  WebDavEntry? _toEntry(DavResource resource) {
    final root = _rootSegments;
    final segs = resource.pathSegments;
    if (segs.length < root.length) return null;
    for (var i = 0; i < root.length; i++) {
      if (segs[i] != root[i]) return null;
    }
    return WebDavEntry(
      path: segs.sublist(root.length).join('/'),
      isCollection: resource.isCollection,
      sizeBytes: resource.contentLength,
      lastModified: resource.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  /// The entry at [path], or null when absent. The root itself (`''`)
  /// raises instead: a missing root means the address is wrong.
  Future<WebDavEntry?> stat(String path) async {
    final normalized = _segments(path).join('/');
    final isRoot = normalized.isEmpty;
    try {
      final resources = await propfindRaw(
        uriFor(normalized, collection: isRoot),
        0,
        isRoot: isRoot,
      );
      return resources.map(_toEntry).nonNulls.firstOrNull;
    } on WebDavException catch (e) {
      if (!isRoot && e.code == WebDavErrorCode.notFound) return null;
      rethrow;
    }
  }

  /// Direct children of the collection at [path]. Raises notFound when the
  /// collection is absent.
  Future<List<WebDavEntry>> listChildren(String path) async {
    final normalized = _segments(path).join('/');
    final resources = await propfindRaw(
      uriFor(normalized, collection: true),
      1,
      isRoot: normalized.isEmpty,
    );
    return resources
        .map(_toEntry)
        .nonNulls
        .where((e) => e.path != normalized)
        .toList();
  }

  Future<Uint8List> getBytes(String path) async {
    final response = await _send('GET', uriFor(path));
    return response.stream.toBytes();
  }

  /// Streams [path] into [destination]; a partial file is deleted on
  /// failure so callers never see a truncated download.
  Future<void> getToFile(
    String path,
    File destination, {
    TransferProgressCallback? onProgress,
  }) async {
    IOSink? sink;
    try {
      final response = await _send('GET', uriFor(path));
      final total = response.contentLength;
      sink = destination.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {
        // The original error is the one that matters.
      }
      try {
        if (await destination.exists()) await destination.delete();
      } catch (_) {
        // Best-effort cleanup of a partial download.
      }
      rethrow;
    }
  }

  Future<void> putBytes(
    String path,
    Uint8List data, {
    String contentType = 'application/octet-stream',
  }) => _putWithParentRetry(path, () async {
    final response = await _send(
      'PUT',
      uriFor(path),
      headers: {'content-type': contentType},
      bytes: data,
    );
    await response.stream.drain<void>();
  });

  /// Streams [source] up in one PUT with an explicit Content-Length, so the
  /// whole file is never in memory.
  Future<void> putFile(
    String path,
    File source, {
    String contentType = 'application/octet-stream',
    TransferProgressCallback? onProgress,
  }) async {
    final length = await source.length();
    Stream<List<int>> body() {
      var sent = 0;
      return source.openRead().map((chunk) {
        sent += chunk.length;
        onProgress?.call(sent, length);
        return chunk;
      });
    }

    await _putWithParentRetry(path, () async {
      final response = await _send(
        'PUT',
        uriFor(path),
        headers: {'content-type': contentType},
        stream: body,
        streamLength: length,
      );
      await response.stream.drain<void>();
    });
  }

  /// A PUT into a missing collection answers 409; create the parents and
  /// try once more.
  Future<void> _putWithParentRetry(String path, Future<void> Function() put) async {
    try {
      await put();
    } on WebDavException catch (e) {
      if (e.code != WebDavErrorCode.conflict) rethrow;
      final parent = parentOf(path);
      _knownCollections.removeWhere((c) => c == parent || parent.startsWith('$c/') || c.startsWith('$parent/'));
      await ensureCollection(parent);
      await put();
    }
  }

  /// Idempotent: an absent path counts as deleted.
  Future<void> delete(String path) async {
    final response = await _send('DELETE', uriFor(path), accept: const {404});
    await response.stream.drain<void>();
    _knownCollections.removeWhere((c) => c == path || c.startsWith('$path/'));
  }

  /// Creates every missing level of [path]. Results are cached for the
  /// client's life; 405 (already exists) counts as success.
  Future<void> ensureCollection(String path) async {
    final normalized = _segments(path).join('/');
    if (normalized.isEmpty || _knownCollections.contains(normalized)) return;
    final response = await _send(
      'MKCOL',
      uriFor(normalized, collection: true),
      accept: const {405, 409},
    );
    await response.stream.drain<void>();
    if (response.statusCode == 409) {
      await ensureCollection(parentOf(normalized));
      final retry = await _send(
        'MKCOL',
        uriFor(normalized, collection: true),
        accept: const {405},
      );
      await retry.stream.drain<void>();
    }
    _knownCollections.add(normalized);
  }

  /// The Nextcloud user id from `current-user-principal`, or null when the
  /// preset does not use the Nextcloud layout or the server does not say.
  Future<String?> resolveNextcloudUserId() async {
    final uri = config.principalProbeUri;
    if (uri == null) return null;
    final response = await _send(
      'PROPFIND',
      uri,
      headers: {'depth': '0', 'content-type': 'application/xml; charset=utf-8'},
      bytes: utf8.encode(kPrincipalPropfindBody),
      accept: const {404},
    );
    final body = await response.stream.bytesToString();
    if (response.statusCode != 207) return null;
    return parseCurrentUserPrincipalId(body);
  }

  void close() => _http.close();
}
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/core/services/cloud_storage/webdav/webdav_client_test.dart`
Expected: PASS. If the redirect test fails because `forcedHeaders` uses a capitalised `Location`, keep it lowercase: `package:http` lowercases response header names.

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/cloud_storage/webdav/webdav_client.dart test/helpers/fake_webdav_server.dart test/core/services/cloud_storage/webdav/webdav_client_test.dart
git commit -m "feat(sync): add the WebDAV protocol client"
```

---

### Task 6: Nextcloud chunking v2

**Files:**
- Create: `lib/core/services/cloud_storage/webdav/nextcloud_chunked_upload.dart`
- Test: `test/core/services/cloud_storage/webdav/nextcloud_chunked_upload_test.dart`

**Interfaces:**
- Consumes: `WebDavClient.request`, `.propfindRaw`, `.stat`, `.ensureCollection`, `.uriFor`, `.chunkingUnsupported`, `WebDavClient.parentOf`, `WebDavConfig.nextcloudUploadsRoot` (Tasks 2, 5).
- Produces:
  - `class NextcloudChunkState { transferId, chunkSize, total, dest; toJson(); static NextcloudChunkState? tryParse(String? json) }`
  - `class NextcloudChunkedUpload` with `NextcloudChunkedUpload(WebDavClient client, {String Function()? newTransferId})`, `static const int chunkBytes`, `static const int thresholdBytes`, `static bool appliesTo(WebDavClient client, int length)`, `Future<bool> upload(String destPath, File source, {String? resumeStateJson, void Function(String)? onResumeStateChanged, TransferProgressCallback? onProgress})` (false means "server has no chunking, use a single PUT"), `Future<void> abandon(String? resumeStateJson)`, `Future<int> reapStale(DateTime olderThan)`, `static String chunkName(int n)`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/cloud_storage/webdav/nextcloud_chunked_upload.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_preset.dart';

import '../../../../helpers/fake_webdav_server.dart';

void main() {
  const files = '/remote.php/dav/files/alice';
  const uploads = '/remote.php/dav/uploads/alice';
  late FakeWebDavServer server;
  late WebDavClient client;
  late Directory tmp;
  late File source;
  final size = NextcloudChunkedUpload.chunkBytes * 2 + 123;

  setUp(() async {
    server = FakeWebDavServer(seedCollections: const [files, uploads]);
    client = WebDavClient(
      WebDavConfig(
        preset: WebDavPreset.nextcloud,
        serverUrl: 'https://dav.test',
        username: 'alice',
        password: 'secret',
        nextcloudUserId: 'alice',
      ),
      httpClient: server.client,
      backoff: (_) => Duration.zero,
    );
    tmp = await Directory.systemTemp.createTemp('nc_chunk_test');
    source = File(p.join(tmp.path, 'video.mp4'));
    await source.writeAsBytes(List<int>.generate(size, (i) => i % 253));
  });

  tearDown(() async {
    client.close();
    await tmp.delete(recursive: true);
  });

  NextcloudChunkedUpload uploader() =>
      NextcloudChunkedUpload(client, newTransferId: () => 'submersion-t1');

  test('applies only to Nextcloud files above the threshold', () {
    expect(NextcloudChunkedUpload.appliesTo(client, size), isTrue);
    expect(NextcloudChunkedUpload.appliesTo(client, 1024), isFalse);
    client.chunkingUnsupported = true;
    expect(NextcloudChunkedUpload.appliesTo(client, size), isFalse);
  });

  test('uploads three chunks and assembles them at the destination', () async {
    String? state;
    expect(
      await uploader().upload('Submersion/a/video.mp4', source, onResumeStateChanged: (s) => state = s),
      isTrue,
    );
    expect(server.files['$files/Submersion/a/video.mp4'], await source.readAsBytes());
    expect(server.collections.any((c) => c.startsWith('$uploads/submersion-')), isFalse);
    expect(state, contains('submersion-t1'));
    final puts = server.captured.where((r) => r.method == 'PUT').toList();
    expect(puts.map((r) => r.url.pathSegments.last), ['00001', '00002', '00003']);
    expect(puts.first.headers['oc-total-length'], '$size');
  });

  test('resume skips chunks already on the server', () async {
    final first = NextcloudChunkedUpload.chunkBytes;
    server
      ..seedCollection('$uploads/submersion-t1')
      ..seedFile('$uploads/submersion-t1/00001', (await source.readAsBytes()).sublist(0, first));
    final state = NextcloudChunkState(
      transferId: 'submersion-t1',
      chunkSize: first,
      total: size,
      dest: client.uriFor('Submersion/video.mp4').toString(),
    );
    await uploader().upload('Submersion/video.mp4', source, resumeStateJson: state.toJsonString());
    final puts = server.captured.where((r) => r.method == 'PUT').map((r) => r.url.pathSegments.last);
    expect(puts, ['00002', '00003']);
    expect(server.files['$files/Submersion/video.mp4']!.length, size);
  });

  test('an expired upload directory restarts from the first chunk', () async {
    final state = NextcloudChunkState(
      transferId: 'submersion-gone',
      chunkSize: NextcloudChunkedUpload.chunkBytes,
      total: size,
      dest: client.uriFor('Submersion/video.mp4').toString(),
    );
    await uploader().upload('Submersion/video.mp4', source, resumeStateJson: state.toJsonString());
    expect(server.captured.where((r) => r.method == 'PUT'), hasLength(3));
  });

  test('a server without chunking falls back', () async {
    server.chunkingEnabled = false;
    expect(await uploader().upload('Submersion/video.mp4', source), isFalse);
    expect(client.chunkingUnsupported, isTrue);
  });

  test('a MOVE whose reply was lost counts as done when the file is complete', () async {
    server.moveFailsAfterApplying = true;
    expect(await uploader().upload('Submersion/video.mp4', source), isTrue);
    expect(server.files['$files/Submersion/video.mp4']!.length, size);
  });

  test('abandon deletes the upload directory and reapStale removes old ones', () async {
    server.seedCollection('$uploads/submersion-old');
    server.modified['$uploads/submersion-old'] = DateTime.utc(2026, 1, 1);
    server.seedCollection('$uploads/other-app');
    server.modified['$uploads/other-app'] = DateTime.utc(2026, 1, 1);
    server.seedCollection('$uploads/submersion-new');

    expect(await uploader().reapStale(DateTime.utc(2026, 6, 1)), 1);
    expect(server.collections, isNot(contains('$uploads/submersion-old')));
    expect(server.collections, contains('$uploads/other-app'));

    final state = NextcloudChunkState(transferId: 'submersion-new', chunkSize: 1, total: 1, dest: 'x');
    await uploader().abandon(state.toJsonString());
    expect(server.collections, isNot(contains('$uploads/submersion-new')));
    await uploader().abandon('not json');
    await uploader().abandon(null);
  });
}
```

- [ ] **Step 2: Run and verify failure**

Run: `flutter test test/core/services/cloud_storage/webdav/nextcloud_chunked_upload_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_multistatus.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart'
    show TransferProgressCallback;

/// Resume state for one chunked upload, persisted by the media queue and
/// replayed verbatim on retry.
class NextcloudChunkState {
  const NextcloudChunkState({
    required this.transferId,
    required this.chunkSize,
    required this.total,
    required this.dest,
  });

  final String transferId;
  final int chunkSize;
  final int total;

  /// The destination URL the chunks are assembled into.
  final String dest;

  Map<String, Object?> toJson() => {
    'v': 1,
    'transferId': transferId,
    'chunkSize': chunkSize,
    'total': total,
    'dest': dest,
  };

  String toJsonString() => jsonEncode(toJson());

  /// Null for absent, malformed or foreign state; never throws.
  static NextcloudChunkState? tryParse(String? json) {
    if (json == null) return null;
    try {
      final map = jsonDecode(json);
      if (map is! Map<String, Object?> || map['v'] != 1) return null;
      return NextcloudChunkState(
        transferId: map['transferId']! as String,
        chunkSize: map['chunkSize']! as int,
        total: map['total']! as int,
        dest: map['dest']! as String,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Nextcloud's chunked upload protocol (v2): MKCOL an upload directory
/// under `uploads/<user>/`, PUT numbered chunks into it, then MOVE its
/// `.file` onto the destination. Gets past server and proxy body-size
/// limits and lets an interrupted media upload resume.
class NextcloudChunkedUpload {
  NextcloudChunkedUpload(this._client, {String Function()? newTransferId})
    : _newTransferId = newTransferId ?? (() => '$transferPrefix${const Uuid().v4()}');

  final WebDavClient _client;
  final String Function() _newTransferId;

  static const int chunkBytes = 10 * 1024 * 1024;
  static const int thresholdBytes = chunkBytes;
  static const String transferPrefix = 'submersion-';

  static bool appliesTo(WebDavClient client, int length) =>
      client.config.preset.supportsNextcloudChunking &&
      client.config.nextcloudUploadsRoot != null &&
      !client.chunkingUnsupported &&
      length > thresholdBytes;

  static String chunkName(int n) => n.toString().padLeft(5, '0');

  Uri get _uploads => _client.config.nextcloudUploadsRoot!;

  Uri _under(Uri base, List<String> extra) => base.replace(
    pathSegments: [...base.pathSegments.where((s) => s.isNotEmpty), ...extra],
  );

  /// Uploads [source] to [destPath]. False when the server has no chunking
  /// (the caller falls back to a single PUT); the client remembers that.
  Future<bool> upload(
    String destPath,
    File source, {
    String? resumeStateJson,
    void Function(String resumeStateJson)? onResumeStateChanged,
    TransferProgressCallback? onProgress,
  }) async {
    final total = await source.length();
    final dest = _client.uriFor(destPath).toString();
    var state = NextcloudChunkState.tryParse(resumeStateJson);
    if (state != null &&
        (state.total != total || state.dest != dest || state.chunkSize != chunkBytes)) {
      state = null;
    }

    var present = <String, int>{};
    if (state != null) {
      try {
        final listing = await _client.propfindRaw(_under(_uploads, [state.transferId, '']), 1);
        present = {
          for (final r in listing)
            if (!r.isCollection && r.pathSegments.isNotEmpty)
              r.pathSegments.last: r.contentLength ?? -1,
        };
      } on WebDavException catch (e) {
        if (e.code != WebDavErrorCode.notFound) rethrow;
        state = null;
      }
    }

    await _client.ensureCollection(WebDavClient.parentOf(destPath));
    if (state == null) {
      final fresh = NextcloudChunkState(
        transferId: _newTransferId(),
        chunkSize: chunkBytes,
        total: total,
        dest: dest,
      );
      final response = await _client.request(
        'MKCOL',
        _under(_uploads, [fresh.transferId, '']),
        headers: {'destination': dest},
        accept: const {404, 405, 501},
      );
      await response.stream.drain<void>();
      if (response.statusCode != 201) {
        _client.chunkingUnsupported = true;
        return false;
      }
      state = fresh;
      onResumeStateChanged?.call(state.toJsonString());
    }

    final headers = {'destination': dest, 'oc-total-length': '$total'};
    final count = (total + chunkBytes - 1) ~/ chunkBytes;
    final raf = await source.open();
    var sent = 0;
    try {
      for (var n = 1; n <= count; n++) {
        final offset = (n - 1) * chunkBytes;
        final size = min(chunkBytes, total - offset);
        final name = chunkName(n);
        if (present[name] != size) {
          await raf.setPosition(offset);
          final bytes = await raf.read(size);
          final response = await _client.request(
            'PUT',
            _under(_uploads, [state.transferId, name]),
            headers: headers,
            bytes: bytes,
          );
          await response.stream.drain<void>();
        }
        sent += size;
        onProgress?.call(sent, total);
      }
    } finally {
      await raf.close();
    }

    try {
      final response = await _client.request(
        'MOVE',
        _under(_uploads, [state.transferId, '.file']),
        headers: {...headers, 'overwrite': 'T'},
      );
      await response.stream.drain<void>();
    } on WebDavException catch (e) {
      // A retried MOVE whose first attempt landed finds its source gone.
      if (e.code != WebDavErrorCode.notFound) rethrow;
      final info = await _client.stat(destPath);
      if (info == null || info.sizeBytes != total) rethrow;
    }
    return true;
  }

  /// Best effort; never throws on malformed state.
  Future<void> abandon(String? resumeStateJson) async {
    final state = NextcloudChunkState.tryParse(resumeStateJson);
    if (state == null || _client.config.nextcloudUploadsRoot == null) return;
    try {
      final response = await _client.request(
        'DELETE',
        _under(_uploads, [state.transferId, '']),
        accept: const {404},
      );
      await response.stream.drain<void>();
    } catch (_) {
      // Nextcloud expires abandoned upload directories on its own.
    }
  }

  /// Deletes this app's upload directories last touched before
  /// [olderThan]; returns how many.
  Future<int> reapStale(DateTime olderThan) async {
    if (_client.config.nextcloudUploadsRoot == null) return 0;
    final List<DavResource> listing;
    try {
      listing = await _client.propfindRaw(_under(_uploads, ['']), 1);
    } on WebDavException catch (e) {
      if (e.code == WebDavErrorCode.notFound) return 0;
      rethrow;
    }
    var reaped = 0;
    final ownDepth = _uploads.pathSegments.where((s) => s.isNotEmpty).length + 1;
    for (final r in listing) {
      final segs = r.pathSegments;
      final modified = r.lastModified;
      if (!r.isCollection || segs.length != ownDepth) continue;
      if (!segs.last.startsWith(transferPrefix)) continue;
      if (modified == null || !modified.isBefore(olderThan)) continue;
      final response = await _client.request(
        'DELETE',
        _under(_uploads, [segs.last, '']),
        accept: const {404},
      );
      await response.stream.drain<void>();
      reaped++;
    }
    return reaped;
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/services/cloud_storage/webdav/nextcloud_chunked_upload_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/cloud_storage/webdav/nextcloud_chunked_upload.dart test/core/services/cloud_storage/webdav/nextcloud_chunked_upload_test.dart
git commit -m "feat(sync): upload large files to Nextcloud in resumable chunks"
```

---

### Task 7: Credentials store and the sync provider

**Files:**
- Create: `lib/core/services/cloud_storage/webdav/webdav_credentials_store.dart`
- Create: `lib/core/services/cloud_storage/webdav_storage_provider.dart`
- Test: `test/core/services/cloud_storage/webdav/webdav_credentials_store_test.dart`
- Test: `test/core/services/cloud_storage/webdav_storage_provider_test.dart`

**Interfaces:**
- Consumes: Tasks 2, 5, 6; `CloudStorageProviderMixin`, `CloudFileInfo`, `UploadResult`; `FallbackSecureStorage`; `InMemoryKeychain` from `test/support/fake_keychain_storage.dart` (read it for its constructor).
- Produces:
  - `class WebDavCredentialsStore({FlutterSecureStorage? storage, String? storageKey})` with `static const String storageKey = 'sync_webdav_config'`, `load()`, `save(WebDavConfig)`, `clear()`.
  - `typedef WebDavClientFactory = WebDavClient Function(WebDavConfig config);`
  - `class WebDavStorageProvider with CloudStorageProviderMixin implements CloudStorageProvider` with `WebDavStorageProvider({WebDavCredentialsStore? store, WebDavClientFactory? clientFactory})`, `static const String probeObjectName = '.submersion-probe'`, `Future<WebDavConfig?> loadConfig()`, `Future<void> saveConfig(WebDavConfig)`, `Future<WebDavConfig> testConnection(WebDavConfig config)` (returns the config with the resolved Nextcloud user id), `static Future<void> probe(WebDavClient client, String folder)`.

- [ ] **Step 1: Write the failing tests**

`webdav_credentials_store_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_preset.dart';

import '../../../../support/fake_keychain_storage.dart';

void main() {
  test('round-trips, survives a corrupt blob as null, and clears', () async {
    final keychain = InMemoryKeychain();
    final store = WebDavCredentialsStore(storage: keychain);
    expect(await store.load(), isNull);

    final config = WebDavConfig(
      preset: WebDavPreset.koofr,
      serverUrl: '',
      username: 'u',
      password: 'p',
    );
    await store.save(config);
    expect((await store.load())!.toJson(), config.toJson());

    await keychain.write(key: WebDavCredentialsStore.storageKey, value: '{bad');
    expect(await store.load(), isNull);

    await store.clear();
    expect(await keychain.read(key: WebDavCredentialsStore.storageKey), isNull);
  });

  test('a per-account key keeps accounts apart', () async {
    final keychain = InMemoryKeychain();
    final store = WebDavCredentialsStore(storage: keychain, storageKey: 'account_x_credentials');
    await store.save(WebDavConfig(preset: WebDavPreset.yandex, serverUrl: '', username: 'u', password: 'p'));
    expect(await keychain.read(key: 'account_x_credentials'), isNotNull);
    expect(await keychain.read(key: WebDavCredentialsStore.storageKey), isNull);
  });
}
```

If `InMemoryKeychain` is not a `FlutterSecureStorage`, follow how `test/core/services/cloud_storage/s3/s3_credentials_store_test.dart` builds its storage and do the same.

`webdav_storage_provider_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/nextcloud_chunked_upload.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_preset.dart';
import 'package:submersion/core/services/cloud_storage/webdav_storage_provider.dart';

import '../../../helpers/fake_webdav_server.dart';
import '../../../support/fake_keychain_storage.dart';

void main() {
  late FakeWebDavServer server;
  late WebDavCredentialsStore store;
  late WebDavStorageProvider provider;
  late Directory tmp;

  final config = WebDavConfig(
    preset: WebDavPreset.other,
    serverUrl: 'https://dav.test/dav',
    username: 'alice',
    password: 'secret',
  );

  WebDavClient factory(WebDavConfig c) =>
      WebDavClient(c, httpClient: server.client, backoff: (_) => Duration.zero);

  setUp(() async {
    server = FakeWebDavServer();
    store = WebDavCredentialsStore(storage: InMemoryKeychain());
    provider = WebDavStorageProvider(store: store, clientFactory: factory);
    tmp = await Directory.systemTemp.createTemp('webdav_provider_test');
  });

  tearDown(() => tmp.delete(recursive: true));

  test('identity and presence-only authentication state', () async {
    expect(provider.providerId, 'webdav');
    expect(await provider.isAuthenticated(), isFalse);
    await provider.saveConfig(config);
    expect(await provider.isAuthenticated(), isTrue);
    expect(await provider.getUserEmail(), 'alice @ dav.test');
    await provider.signOut();
    expect(await provider.isAuthenticated(), isFalse);
  });

  test('testConnection creates the folder and cleans up the probe', () async {
    final result = await provider.testConnection(config);
    expect(server.collections, contains('/dav/Submersion'));
    expect(server.files.keys.where((k) => k.contains('.submersion-probe')), isEmpty);
    expect(result.toJson(), config.toJson());
    expect(await store.load(), isNull, reason: 'testConnection never saves');
  });

  test('testConnection resolves and returns the Nextcloud user id', () async {
    server = FakeWebDavServer(
      username: 'alice@example.com',
      seedCollections: const ['/remote.php/dav/files/alice'],
    )..principalUserId = 'alice';
    final nc = WebDavConfig(
      preset: WebDavPreset.nextcloud,
      serverUrl: 'https://dav.test',
      username: 'alice@example.com',
      password: 'secret',
    );
    final result = await provider.testConnection(nc);
    expect(result.nextcloudUserId, 'alice');
    expect(server.collections, contains('/remote.php/dav/files/alice/Submersion'));
  });

  test('an invalid config fails before any request', () async {
    await expectLater(
      provider.testConnection(config.copyWith(password: '')),
      throwsA(isA<WebDavException>().having((e) => e.code, 'code', WebDavErrorCode.invalidConfig)),
    );
    expect(server.captured, isEmpty);
  });

  test('upload, list, info, download, delete under the sync folder', () async {
    await provider.saveConfig(config);
    final folder = await provider.getOrCreateSyncFolder();
    expect(folder, 'Submersion');
    final up = await provider.uploadFile(Uint8List.fromList(utf8.encode('x')), 'submersion_sync_a.json', folderId: folder);
    expect(up.fileId, 'Submersion/submersion_sync_a.json');
    final list = await provider.listFiles(folderId: folder, namePattern: 'sync_');
    expect(list.single.name, 'submersion_sync_a.json');
    expect((await provider.getFileInfo(up.fileId))!.sizeBytes, 1);
    expect(utf8.decode(await provider.downloadFile(up.fileId)), 'x');
    await provider.deleteFile(up.fileId);
    expect(await provider.fileExists(up.fileId), isFalse);
  });

  test('listFiles on a folder deleted on the server is empty', () async {
    await provider.saveConfig(config);
    expect(await provider.listFiles(), isEmpty);
  });

  test('createFolder nests under the sync folder', () async {
    await provider.saveConfig(config);
    expect(await provider.createFolder('Backups'), 'Submersion/Backups');
    expect(server.collections, contains('/dav/Submersion/Backups'));
  });

  test('uploadFileFromPath and downloadToFile stream through disk', () async {
    await provider.saveConfig(config);
    final src = File(p.join(tmp.path, 'backup.db'));
    await src.writeAsBytes(List<int>.generate(200000, (i) => i % 7));
    final up = await provider.uploadFileFromPath(src.path, 'b.db', folderId: 'Submersion/Backups');
    final dest = p.join(tmp.path, 'back.db');
    await provider.downloadToFile(up.fileId, dest);
    expect(await File(dest).readAsBytes(), await src.readAsBytes());
  });

  test('a large Nextcloud backup is chunked', () async {
    server = FakeWebDavServer(seedCollections: const [
      '/remote.php/dav/files/alice',
      '/remote.php/dav/uploads/alice',
    ]);
    await provider.saveConfig(WebDavConfig(
      preset: WebDavPreset.nextcloud,
      serverUrl: 'https://dav.test',
      username: 'alice',
      password: 'secret',
      nextcloudUserId: 'alice',
    ));
    final src = File(p.join(tmp.path, 'big.db'));
    await src.writeAsBytes(Uint8List(NextcloudChunkedUpload.chunkBytes + 5));
    await provider.uploadFileFromPath(src.path, 'big.db');
    expect(server.count('MOVE'), 1);
    expect(server.files['/remote.php/dav/files/alice/Submersion/big.db']!.length, NextcloudChunkedUpload.chunkBytes + 5);
  });

  test('authenticate without a config explains what to do', () async {
    await expectLater(provider.authenticate(), throwsA(isA<CloudStorageException>()));
  });
}
```

- [ ] **Step 2: Run and verify failure**

Run: `flutter test test/core/services/cloud_storage/webdav/webdav_credentials_store_test.dart test/core/services/cloud_storage/webdav_storage_provider_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `webdav_credentials_store.dart`**

```dart
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// Persists a WebDAV configuration, password included, as one JSON blob in
/// the platform keychain (the S3CredentialsStore pattern). A corrupt blob
/// reads as null and is left for save() to overwrite.
class WebDavCredentialsStore {
  /// [storageKey] overrides the legacy sync key; the accounts layer passes
  /// per-account keys (`account_<id>_credentials`).
  WebDavCredentialsStore({FlutterSecureStorage? storage, String? storageKey})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage()),
      _storageKey = storageKey ?? WebDavCredentialsStore.storageKey;

  final FallbackSecureStorage _storage;
  final String _storageKey;

  static const String storageKey = 'sync_webdav_config';

  Future<WebDavConfig?> load() async {
    final raw = await _storage.read(key: _storageKey);
    return decodeWebDavConfig(raw);
  }

  Future<void> save(WebDavConfig config) =>
      _storage.write(key: _storageKey, value: jsonEncode(config.toJson()));

  Future<void> clear() => _storage.delete(key: _storageKey);
}

/// Null for an absent or malformed blob; never throws.
WebDavConfig? decodeWebDavConfig(String? raw) {
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) return null;
    return WebDavConfig.fromJson(decoded);
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}
```

- [ ] **Step 4: Implement `webdav_storage_provider.dart`**

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/nextcloud_chunked_upload.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/logger_service.dart';

typedef WebDavClientFactory = WebDavClient Function(WebDavConfig config);

/// WebDAV implementation of [CloudStorageProvider] (Nextcloud, ownCloud,
/// Synology, Koofr, pCloud, Fastmail, Yandex and any other WebDAV server).
///
/// - fileId is the path relative to the DAV root (`Submersion/x.json`); the
///   sync folder is the configured folder.
/// - authenticate() is a live read and write probe of the stored config.
/// - getUserEmail() returns the account label `<user> @ <host>`.
class WebDavStorageProvider
    with CloudStorageProviderMixin
    implements CloudStorageProvider {
  static final _log = LoggerService.forClass(WebDavStorageProvider);

  static const String probeObjectName = '.submersion-probe';

  WebDavStorageProvider({
    WebDavCredentialsStore? store,
    WebDavClientFactory? clientFactory,
  }) : _store = store ?? WebDavCredentialsStore(),
       _clientFactory = clientFactory ?? WebDavClient.new;

  final WebDavCredentialsStore _store;
  final WebDavClientFactory _clientFactory;

  WebDavConfig? _cachedConfig;
  WebDavClient? _client;
  int _generation = 0;

  @override
  String get providerName => 'WebDAV';

  @override
  String get providerId => 'webdav';

  @override
  Future<bool> isAvailable() async => true;

  /// Presence only, no network (UI rebuild paths call this). Keychain
  /// failures propagate, as for S3: a locked keychain is not "unset".
  @override
  Future<bool> isAuthenticated() async => (await _loadConfig()) != null;

  Future<WebDavConfig?> loadConfig() => _loadConfig();

  Future<void> saveConfig(WebDavConfig config) async {
    await _store.save(config);
    _invalidate();
  }

  @override
  Future<void> authenticate() async {
    final config = await _loadConfig();
    if (config == null) {
      throw WebDavException(
        'WebDAV is not configured. Open the WebDAV settings and enter your server details.',
        code: WebDavErrorCode.invalidConfig,
      );
    }
    final client = _clientFactory(config);
    try {
      await probe(client, config.folder);
    } finally {
      client.close();
    }
    _log.info('WebDAV probe succeeded for ${config.host}');
  }

  /// Validates unsaved [config] with the same probe as [authenticate] and
  /// returns it with the Nextcloud user id resolved. Saves nothing.
  Future<WebDavConfig> testConnection(WebDavConfig config) async {
    final error = config.validate();
    if (error != null) {
      throw WebDavException(error, code: WebDavErrorCode.invalidConfig);
    }
    var resolved = config;
    if (config.preset.usesNextcloudLayout) {
      final lookup = _clientFactory(config);
      try {
        final id = await lookup.resolveNextcloudUserId();
        if (id != null && id != config.nextcloudUserId) {
          resolved = config.copyWith(nextcloudUserId: id);
        }
      } on WebDavException catch (e) {
        if (e.code == WebDavErrorCode.unauthorized ||
            e.code == WebDavErrorCode.untrustedCertificate ||
            e.code == WebDavErrorCode.unreachable) {
          rethrow;
        }
        // No principal support: the login name is the user id.
      } finally {
        lookup.close();
      }
    }
    final client = _clientFactory(resolved);
    try {
      await probe(client, resolved.folder);
    } finally {
      client.close();
    }
    return resolved;
  }

  /// The DAV root exists and is a collection; the folder can be created;
  /// a small file round-trips and is removed.
  static Future<void> probe(WebDavClient client, String folder) async {
    final root = await client.stat('');
    if (root == null || !root.isCollection) {
      throw WebDavException(
        'No WebDAV folder at this address. Check the server type and URL.',
        code: WebDavErrorCode.notFound,
      );
    }
    await client.ensureCollection(folder);
    final probePath = '$folder/$probeObjectName';
    await client.putBytes(probePath, Uint8List.fromList(utf8.encode('probe')));
    final back = await client.getBytes(probePath);
    if (utf8.decode(back, allowMalformed: true) != 'probe') {
      throw WebDavException(
        'The server returned different bytes for the test file.',
        code: WebDavErrorCode.unexpected,
      );
    }
    await client.delete(probePath);
  }

  @override
  Future<void> signOut() async {
    await _store.clear();
    _invalidate();
  }

  @override
  Future<String?> getUserEmail() async => (await _loadConfig())?.displayLabel;

  String _pathIn(String? folderId, WebDavConfig config, String filename) =>
      '${folderId ?? config.folder}/$filename';

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async {
    final session = await _requireSession();
    final path = _pathIn(folderId, session.config, filename);
    await session.client.putBytes(path, data);
    return UploadResult(fileId: path, uploadTime: DateTime.now().toUtc());
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    final session = await _requireSession();
    return session.client.getBytes(fileId);
  }

  @override
  Future<UploadResult> uploadFileFromPath(
    String sourcePath,
    String filename, {
    String? folderId,
  }) async {
    final session = await _requireSession();
    final path = _pathIn(folderId, session.config, filename);
    final source = File(sourcePath);
    final length = await source.length();
    var done = false;
    if (NextcloudChunkedUpload.appliesTo(session.client, length)) {
      done = await NextcloudChunkedUpload(session.client).upload(path, source);
    }
    if (!done) await session.client.putFile(path, source);
    return UploadResult(fileId: path, uploadTime: DateTime.now().toUtc());
  }

  @override
  Future<void> downloadToFile(String fileId, String destinationPath) async {
    final session = await _requireSession();
    await session.client.getToFile(fileId, File(destinationPath));
  }

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async {
    final session = await _requireSession();
    final entry = await session.client.stat(fileId);
    if (entry == null || entry.isCollection) return null;
    return _toInfo(entry);
  }

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) async {
    final session = await _requireSession();
    final List<WebDavEntry> children;
    try {
      children = await session.client.listChildren(folderId ?? session.config.folder);
    } on WebDavException catch (e) {
      if (e.code == WebDavErrorCode.notFound) return const [];
      rethrow;
    }
    return children
        .where((e) => !e.isCollection)
        .where((e) => namePattern == null || e.name.contains(namePattern))
        .map(_toInfo)
        .toList();
  }

  @override
  Future<void> deleteFile(String fileId) async {
    final session = await _requireSession();
    await session.client.delete(fileId);
  }

  @override
  Future<bool> fileExists(String fileId) async => (await getFileInfo(fileId)) != null;

  @override
  Future<String> createFolder(String folderName, {String? parentFolderId}) async {
    final session = await _requireSession();
    final path = '${parentFolderId ?? session.config.folder}/$folderName';
    await session.client.ensureCollection(path);
    return path;
  }

  @override
  Future<String> getOrCreateSyncFolder() async {
    final session = await _requireSession();
    await session.client.ensureCollection(session.config.folder);
    return session.config.folder;
  }

  CloudFileInfo _toInfo(WebDavEntry e) => CloudFileInfo(
    id: e.path,
    name: e.name,
    modifiedTime: e.lastModified,
    sizeBytes: e.sizeBytes,
  );

  Future<WebDavConfig?> _loadConfig() async {
    final cached = _cachedConfig;
    if (cached != null) return cached;
    final generation = _generation;
    final loaded = await _store.load();
    if (generation != _generation) return _cachedConfig;
    return _cachedConfig = loaded;
  }

  Future<({WebDavConfig config, WebDavClient client})> _requireSession() async {
    while (true) {
      final generation = _generation;
      final config = await _loadConfig();
      if (config == null) {
        throw WebDavException('WebDAV is not configured', code: WebDavErrorCode.invalidConfig);
      }
      if (generation != _generation) continue;
      return (config: config, client: _client ??= _clientFactory(config));
    }
  }

  void _invalidate() {
    _generation++;
    _client?.close();
    _client = null;
    _cachedConfig = null;
  }
}
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/core/services/cloud_storage/webdav/webdav_credentials_store_test.dart test/core/services/cloud_storage/webdav_storage_provider_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/cloud_storage/webdav/webdav_credentials_store.dart lib/core/services/cloud_storage/webdav_storage_provider.dart test/core/services/cloud_storage/webdav/webdav_credentials_store_test.dart test/core/services/cloud_storage/webdav_storage_provider_test.dart
git commit -m "feat(sync): add the WebDAV cloud storage provider"
```

---

### Task 8: Media object store

**Files:**
- Create: `lib/core/services/media_store/webdav_media_object_store.dart`
- Test: `test/core/services/media_store/webdav_media_object_store_test.dart`

**Interfaces:**
- Consumes: `MediaObjectStore`, `MediaStoreException`, `MediaStoreErrorKind`, `StoreObjectInfo`, `TransferProgressCallback`; Tasks 5 and 6.
- Produces:
  - `class WebDavMediaObjectStore implements MediaObjectStore` with `WebDavMediaObjectStore({required WebDavClient client})`; keys live under `client.config.folder`.
  - `MediaStoreErrorKind mediaStoreKindFor(WebDavErrorCode code)`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/cloud_storage/webdav/nextcloud_chunked_upload.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_preset.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/webdav_media_object_store.dart';

import '../../../helpers/fake_webdav_server.dart';

void main() {
  late FakeWebDavServer server;
  late WebDavMediaObjectStore store;
  late Directory tmp;

  WebDavMediaObjectStore build({WebDavPreset preset = WebDavPreset.other, String serverUrl = 'https://dav.test/dav'}) =>
      WebDavMediaObjectStore(
        client: WebDavClient(
          WebDavConfig(
            preset: preset,
            serverUrl: serverUrl,
            username: 'alice',
            password: 'secret',
            folder: kDefaultWebDavMediaFolder,
            nextcloudUserId: 'alice',
          ),
          httpClient: server.client,
          backoff: (_) => Duration.zero,
        ),
      );

  setUp(() async {
    server = FakeWebDavServer();
    store = build();
    tmp = await Directory.systemTemp.createTemp('webdav_media_test');
  });

  tearDown(() => tmp.delete(recursive: true));

  Future<File> fileWith(List<int> bytes) async {
    final f = File(p.join(tmp.path, 'src_${bytes.length}'));
    await f.writeAsBytes(bytes);
    return f;
  }

  test('putFile creates nested collections and head reports the object', () async {
    await store.putFile('smv1/objects/ab/abcd.jpg', await fileWith([1, 2, 3]), contentType: 'image/jpeg');
    expect(server.files['/dav/Submersion Media/smv1/objects/ab/abcd.jpg'], [1, 2, 3]);
    final info = await store.head('smv1/objects/ab/abcd.jpg');
    expect(info!.key, 'smv1/objects/ab/abcd.jpg');
    expect(info.sizeBytes, 3);
    expect(await store.head('smv1/objects/ab/none.jpg'), isNull);
  });

  test('getFile of a missing key is notFound', () async {
    await expectLater(
      store.getFile('smv1/objects/zz/none.jpg', File(p.join(tmp.path, 'out'))),
      throwsA(isA<MediaStoreException>().having((e) => e.kind, 'kind', MediaStoreErrorKind.notFound)),
    );
  });

  test('list filters by name prefix in a directory and recurses for a slash prefix', () async {
    server
      ..seedFile('/dav/Submersion Media/smv1/objects/ab/abcd.jpg', [1])
      ..seedFile('/dav/Submersion Media/smv1/objects/ab/abcd.png', [2])
      ..seedFile('/dav/Submersion Media/smv1/objects/ab/abzz.jpg', [3])
      ..seedFile('/dav/Submersion Media/smv1/thumbs/ab/abcd.jpg', [4]);
    final variants = await store.list('smv1/objects/ab/abcd.').map((o) => o.key).toList();
    expect(variants, unorderedEquals(['smv1/objects/ab/abcd.jpg', 'smv1/objects/ab/abcd.png']));
    final all = await store.list('smv1/').map((o) => o.key).toList();
    expect(all, hasLength(4));
  });

  test('list under a directory that does not exist yields nothing', () async {
    expect(await store.list('smv1/objects/cd/cdef.').toList(), isEmpty);
  });

  test('delete is idempotent', () async {
    await store.delete('smv1/objects/ab/none.jpg');
  });

  test('errors map to media kinds', () {
    expect(mediaStoreKindFor(WebDavErrorCode.unauthorized), MediaStoreErrorKind.auth);
    expect(mediaStoreKindFor(WebDavErrorCode.untrustedCertificate), MediaStoreErrorKind.auth);
    expect(mediaStoreKindFor(WebDavErrorCode.notFound), MediaStoreErrorKind.notFound);
    expect(mediaStoreKindFor(WebDavErrorCode.unreachable), MediaStoreErrorKind.transient);
    expect(mediaStoreKindFor(WebDavErrorCode.server), MediaStoreErrorKind.transient);
    expect(mediaStoreKindFor(WebDavErrorCode.tooLarge), MediaStoreErrorKind.fatal);
  });

  test('a large Nextcloud upload is chunked and reports resume state', () async {
    server = FakeWebDavServer(seedCollections: const [
      '/remote.php/dav/files/alice',
      '/remote.php/dav/uploads/alice',
    ]);
    store = build(preset: WebDavPreset.nextcloud, serverUrl: 'https://dav.test');
    final big = await fileWith(Uint8List(NextcloudChunkedUpload.chunkBytes + 1));
    String? state;
    await store.putFile('smv1/objects/ab/big.mp4', big, contentType: 'video/mp4', onResumeStateChanged: (s) => state = s);
    expect(state, isNotNull);
    expect(server.files['/remote.php/dav/files/alice/Submersion Media/smv1/objects/ab/big.mp4']!.length, NextcloudChunkedUpload.chunkBytes + 1);
    expect(await store.reapStaleUploadSessions(olderThan: DateTime.utc(2030)), 0);
  });

  test('non-Nextcloud stores have no sessions to reap', () async {
    expect(await store.reapStaleUploadSessions(olderThan: DateTime.utc(2030)), 0);
    await store.abandonResume('k', 'garbage');
  });
}
```

- [ ] **Step 2: Run and verify failure**

Run: `flutter test test/core/services/media_store/webdav_media_object_store_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
import 'dart:io';

import 'package:submersion/core/services/cloud_storage/webdav/nextcloud_chunked_upload.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';

/// Retry classification for WebDAV failures in the media queue.
MediaStoreErrorKind mediaStoreKindFor(WebDavErrorCode code) => switch (code) {
  WebDavErrorCode.unauthorized ||
  WebDavErrorCode.forbidden ||
  WebDavErrorCode.untrustedCertificate => MediaStoreErrorKind.auth,
  WebDavErrorCode.notFound => MediaStoreErrorKind.notFound,
  WebDavErrorCode.unreachable ||
  WebDavErrorCode.server ||
  WebDavErrorCode.locked => MediaStoreErrorKind.transient,
  WebDavErrorCode.invalidConfig ||
  WebDavErrorCode.notWebDav ||
  WebDavErrorCode.redirected ||
  WebDavErrorCode.conflict ||
  WebDavErrorCode.tooLarge ||
  WebDavErrorCode.insufficientStorage ||
  WebDavErrorCode.unexpected => MediaStoreErrorKind.fatal,
};

/// Media store on a WebDAV server. Store keys (`smv1/objects/ab/<hash>.jpg`)
/// live under the configured folder. WebDAV needs real collections, so
/// parents are created on demand (the client caches them), and listing
/// walks with Depth 1 because `Depth: infinity` is often disabled.
class WebDavMediaObjectStore implements MediaObjectStore {
  WebDavMediaObjectStore({required WebDavClient client}) : _client = client;

  final WebDavClient _client;

  String get _root => _client.config.folder;
  String _path(String key) => key.isEmpty ? _root : '$_root/$key';
  String _keyOf(String path) => path.substring(_root.length + 1);

  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on WebDavException catch (e) {
      throw MediaStoreException(e.message, kind: mediaStoreKindFor(e.code), cause: e);
    } on FileSystemException catch (e) {
      throw MediaStoreException('Could not access the local file', kind: MediaStoreErrorKind.fatal, cause: e);
    }
  }

  bool get _chunks => _client.config.preset.supportsNextcloudChunking;

  @override
  Future<StoreObjectInfo?> head(String key) => _guard(() async {
    final entry = await _client.stat(_path(key));
    if (entry == null || entry.isCollection) return null;
    return StoreObjectInfo(key: key, sizeBytes: entry.sizeBytes, lastModified: entry.lastModified);
  });

  @override
  Future<void> putFile(
    String key,
    File source, {
    required String contentType,
    TransferProgressCallback? onProgress,
    String? resumeStateJson,
    void Function(String resumeStateJson)? onResumeStateChanged,
  }) => _guard(() async {
    final path = _path(key);
    final length = await source.length();
    if (NextcloudChunkedUpload.appliesTo(_client, length)) {
      final done = await NextcloudChunkedUpload(_client).upload(
        path,
        source,
        resumeStateJson: resumeStateJson,
        onResumeStateChanged: onResumeStateChanged,
        onProgress: onProgress,
      );
      if (done) return;
    }
    await _client.putFile(path, source, contentType: contentType, onProgress: onProgress);
  });

  @override
  Future<void> getFile(String key, File destination, {TransferProgressCallback? onProgress}) =>
      _guard(() => _client.getToFile(_path(key), destination, onProgress: onProgress));

  @override
  Future<void> delete(String key) => _guard(() => _client.delete(_path(key)));

  @override
  Future<void> abandonResume(String key, String? resumeStateJson) async {
    if (!_chunks) return;
    await NextcloudChunkedUpload(_client).abandon(resumeStateJson);
  }

  @override
  Stream<StoreObjectInfo> list(String keyPrefix) async* {
    final slash = keyPrefix.lastIndexOf('/');
    final dir = slash < 0 ? '' : keyPrefix.substring(0, slash);
    final namePrefix = keyPrefix.substring(slash + 1);
    yield* _walk(dir, namePrefix, recursive: namePrefix.isEmpty);
  }

  Stream<StoreObjectInfo> _walk(String dir, String namePrefix, {required bool recursive}) async* {
    final List<WebDavEntry> children;
    try {
      children = await _guard(() => _client.listChildren(_path(dir)));
    } on MediaStoreException catch (e) {
      if (e.kind == MediaStoreErrorKind.notFound) return;
      rethrow;
    }
    for (final entry in children) {
      if (entry.isCollection) {
        if (recursive) yield* _walk(_keyOf(entry.path), '', recursive: true);
      } else if (entry.name.startsWith(namePrefix)) {
        yield StoreObjectInfo(
          key: _keyOf(entry.path),
          sizeBytes: entry.sizeBytes,
          lastModified: entry.lastModified,
        );
      }
    }
  }

  @override
  Future<int> reapStaleUploadSessions({required DateTime olderThan}) async {
    if (!_chunks) return 0;
    return _guard(() => NextcloudChunkedUpload(_client).reapStale(olderThan));
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/services/media_store/webdav_media_object_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/media_store/webdav_media_object_store.dart test/core/services/media_store/webdav_media_object_store_test.dart
git commit -m "feat(media-store): add the WebDAV media object store"
```

---

### Task 9: Strings and localized error text

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the ten other `lib/l10n/arb/app_*.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart` via `flutter gen-l10n`
- Create: `lib/features/settings/presentation/widgets/webdav_error_text.dart`
- Test: `test/features/settings/presentation/widgets/webdav_error_text_test.dart`

**Interfaces:**
- Consumes: `WebDavException`, `WebDavErrorCode` (Task 4).
- Produces: the ARB keys below, and `String webDavErrorText(AppLocalizations l10n, WebDavException e)`.

ARB files are grouped by feature, not globally sorted. Insert each group directly after its anchor key in every locale, editing lines (never re-dumping the JSON) so each file keeps its own layout. Anchors: `settings_cloudSync_provider_s3_title` for `settings_cloudSync_provider_webdav_*`; the last `settings_s3Config_*` key for `settings_webdavConfig_*`; `settings_mediaStorage_provider_label` for `settings_mediaStorage_provider_webdav` and `settings_mediaStorage_webdav_useSyncServer`.

English values (`app_en.arb`), with `@` metadata for every key that has a placeholder:

| Key | English |
|-----|---------|
| `settings_cloudSync_provider_webdav_title` | WebDAV |
| `settings_cloudSync_provider_webdav_subtitle` | Nextcloud, ownCloud, Synology, Koofr and other WebDAV servers |
| `settings_cloudSync_provider_webdav_edit` | Edit WebDAV configuration |
| `settings_webdavConfig_appBar_title` | WebDAV |
| `settings_webdavConfig_field_preset_label` | Server type |
| `settings_webdavConfig_preset_nextcloud` | Nextcloud |
| `settings_webdavConfig_preset_owncloud` | ownCloud |
| `settings_webdavConfig_preset_synology` | Synology NAS |
| `settings_webdavConfig_preset_koofr` | Koofr |
| `settings_webdavConfig_preset_pcloudUs` | pCloud (US) |
| `settings_webdavConfig_preset_pcloudEu` | pCloud (EU) |
| `settings_webdavConfig_preset_fastmail` | Fastmail Files |
| `settings_webdavConfig_preset_yandex` | Yandex Disk |
| `settings_webdavConfig_preset_other` | Other WebDAV server |
| `settings_webdavConfig_field_serverUrl_label` | Server address |
| `settings_webdavConfig_field_serverUrl_hintHost` | https://cloud.example.com |
| `settings_webdavConfig_field_serverUrl_hintSynology` | https://nas.local:5006 |
| `settings_webdavConfig_field_serverUrl_hintDav` | https://example.com/dav |
| `settings_webdavConfig_synology_helper` | Turn on WebDAV Server in Package Center. Its HTTPS port is usually 5006. |
| `settings_webdavConfig_field_username_label` | Username |
| `settings_webdavConfig_field_password_label` | Password |
| `settings_webdavConfig_field_password_appPasswordHelper` | Use an app password if the account has two-factor sign-in |
| `settings_webdavConfig_field_folder_label` | Folder |
| `settings_webdavConfig_field_folder_helper` | Created on the server if it does not exist |
| `settings_webdavConfig_davRoot_label` | WebDAV address |
| `settings_webdavConfig_warning_http` | This server uses http://, so your password and dive data travel unencrypted. Use it only on a network you trust. |
| `settings_webdavConfig_trustedCertificate` | Trusted certificate: {fingerprint} |
| `settings_webdavConfig_action_forgetCertificate` | Forget |
| `settings_webdavConfig_action_testConnection` | Test connection |
| `settings_webdavConfig_action_remove` | Remove configuration |
| `settings_webdavConfig_remove_confirm_title` | Remove WebDAV configuration? |
| `settings_webdavConfig_remove_confirm_body` | The server details and password are removed from this device. Files on the server are kept. |
| `settings_webdavConfig_remove_confirm_action` | Remove |
| `settings_webdavConfig_removed` | WebDAV configuration removed |
| `settings_webdavConfig_saved` | WebDAV configuration saved |
| `settings_webdavConfig_test_success` | Connection successful |
| `settings_webdavConfig_error_secureStorage` | Could not access secure storage |
| `settings_webdavConfig_validation_required` | Required |
| `settings_webdavConfig_validation_url` | Enter an address starting with https:// or http:// |
| `settings_webdavConfig_validation_folder` | Folder names cannot contain . or .. segments |
| `settings_webdavConfig_trust_title` | Untrusted certificate |
| `settings_webdavConfig_trust_body` | {host} presented a certificate that no trusted authority signed. Home servers with a self-signed certificate do this. Trust it only if the fingerprint matches the one your server shows. |
| `settings_webdavConfig_trust_changedBody` | The certificate for {host} changed since you trusted it. A renewed certificate does this, but so does someone intercepting the connection. Trust the new one only if its fingerprint matches the one your server shows. |
| `settings_webdavConfig_trust_fingerprint` | SHA-256 fingerprint |
| `settings_webdavConfig_trust_previousFingerprint` | Previously trusted |
| `settings_webdavConfig_trust_subject` | Issued to |
| `settings_webdavConfig_trust_issuer` | Issued by |
| `settings_webdavConfig_trust_expires` | Expires |
| `settings_webdavConfig_trust_action` | Trust this certificate |
| `settings_webdavConfig_error_invalidConfig` | Check the server details |
| `settings_webdavConfig_error_unauthorized` | The server rejected the username or password. If the account uses two-factor sign-in, create an app password. |
| `settings_webdavConfig_error_forbidden` | You do not have permission to use this folder on the server. |
| `settings_webdavConfig_error_notFound` | No WebDAV folder at this address. Check the server type and address. |
| `settings_webdavConfig_error_notWebDav` | This address is not a WebDAV server. |
| `settings_webdavConfig_error_redirected` | The server redirected to {location}. Use that address instead. |
| `settings_webdavConfig_error_conflict` | The folder could not be created on the server. |
| `settings_webdavConfig_error_tooLarge` | The server refused a {size} MB file as too large. Raise its upload limit. |
| `settings_webdavConfig_error_insufficientStorage` | The server is out of storage. |
| `settings_webdavConfig_error_locked` | The file is locked on the server. Try again shortly. |
| `settings_webdavConfig_error_unreachable` | Could not reach {host}. |
| `settings_webdavConfig_error_server` | The server reported an error. Try again later. |
| `settings_webdavConfig_error_unexpected` | The server gave an unexpected reply. |
| `settings_webdavConfig_error_untrusted` | The server certificate is not trusted. |
| `settings_mediaStorage_provider_webdav` | WebDAV |
| `settings_mediaStorage_webdav_useSyncServer` | Use my sync server |

Placeholders: `fingerprint`, `host`, `location` and `size` are all `String`.

- [ ] **Step 1: Write the failing mapper test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_error_text.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('every code has localized text', () {
    for (final code in WebDavErrorCode.values) {
      final text = webDavErrorText(l10n, WebDavException('x', code: code));
      expect(text, isNotEmpty, reason: code.name);
    }
  });

  test('placeholders and the server detail are carried', () {
    final redirect = WebDavException('x', code: WebDavErrorCode.redirected, location: 'https://new/', cause: 'HTTP 301 PROPFIND /dav/');
    expect(webDavErrorText(l10n, redirect), contains('https://new/'));
    expect(webDavErrorText(l10n, redirect), contains('HTTP 301'));
    final big = WebDavException('x', code: WebDavErrorCode.tooLarge, sizeBytes: 3 * 1024 * 1024);
    expect(webDavErrorText(l10n, big), contains('3 MB'));
  });
}
```

- [ ] **Step 2: Add the ARB keys**

Write a throwaway script in the scratchpad (not the repo) that, for each locale file, inserts the group's lines after the anchor key's line (and after that key's `@` block when it has one), with a two-space indent and a trailing comma, and adds the `@key` placeholder blocks in `app_en.arb` only. Every non-English value is a real translation into that locale, keeping placeholders verbatim and keeping brand names (WebDAV, Nextcloud, ownCloud, Synology, Koofr, pCloud, Fastmail, Yandex, SHA-256, https://, http://) untranslated. Run it with `python3.14`. Then:

Run: `flutter gen-l10n && python3.14 -c "import json,glob;[json.load(open(f)) for f in glob.glob('lib/l10n/arb/*.arb')]"`
Expected: no output (every file is valid JSON and generation succeeds).

- [ ] **Step 3: Implement `webdav_error_text.dart`**

```dart
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized text for a WebDAV failure on the settings screens, followed by
/// the server's own detail when there is one (the same cause
/// `displayMessage` appends).
String webDavErrorText(AppLocalizations l10n, WebDavException e) {
  final text = switch (e.code) {
    WebDavErrorCode.invalidConfig => l10n.settings_webdavConfig_error_invalidConfig,
    WebDavErrorCode.unauthorized => l10n.settings_webdavConfig_error_unauthorized,
    WebDavErrorCode.forbidden => l10n.settings_webdavConfig_error_forbidden,
    WebDavErrorCode.notFound => l10n.settings_webdavConfig_error_notFound,
    WebDavErrorCode.notWebDav => l10n.settings_webdavConfig_error_notWebDav,
    WebDavErrorCode.redirected => l10n.settings_webdavConfig_error_redirected(e.location ?? '?'),
    WebDavErrorCode.conflict => l10n.settings_webdavConfig_error_conflict,
    WebDavErrorCode.tooLarge => l10n.settings_webdavConfig_error_tooLarge(
      e.sizeBytes == null ? '?' : (e.sizeBytes! / (1024 * 1024)).round().toString(),
    ),
    WebDavErrorCode.insufficientStorage => l10n.settings_webdavConfig_error_insufficientStorage,
    WebDavErrorCode.locked => l10n.settings_webdavConfig_error_locked,
    WebDavErrorCode.unreachable => l10n.settings_webdavConfig_error_unreachable(_hostOf(e)),
    WebDavErrorCode.server => l10n.settings_webdavConfig_error_server,
    WebDavErrorCode.unexpected => l10n.settings_webdavConfig_error_unexpected,
    WebDavErrorCode.untrustedCertificate => l10n.settings_webdavConfig_error_untrusted,
  };
  final cause = e.cause;
  return cause == null ? text : '$text ($cause)';
}

/// The host named in the English message `Could not reach <host>.`
String _hostOf(WebDavException e) {
  final match = RegExp(r'Could not reach (.+)\.$').firstMatch(e.message);
  return match?.group(1) ?? '?';
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/settings/presentation/widgets/webdav_error_text_test.dart test/l10n`
Expected: PASS (the `test/l10n` suite checks placeholder parity and plural branches across locales).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n lib/features/settings/presentation/widgets/webdav_error_text.dart test/features/settings/presentation/widgets/webdav_error_text_test.dart
git commit -m "feat(sync): add WebDAV strings in every locale"
```

---

### Task 10: Enum values, accounts adapter and provider wiring

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart:20` (`CloudProviderType`)
- Modify: `lib/core/services/accounts/account_kind.dart`
- Modify: `lib/core/services/accounts/account_identity.dart`
- Create: `lib/core/services/accounts/adapters/webdav_account_adapter.dart`
- Modify: `lib/core/providers/account_providers.dart` (credential store provider and registry list)
- Modify: `lib/core/services/accounts/account_startup_migration.dart` (rekey switch, `_labelFor`)
- Modify: `lib/core/services/accounts/account_deduplicator.dart` (`_canonicalIdFor`)
- Modify: `lib/core/services/cloud_storage/cloud_provider_instances.dart`
- Create: `lib/features/settings/presentation/providers/webdav_providers.dart`
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (`ensureAccountForProviderType`, `selectedSyncAccountProvider`, `_mirrorLegacyCredentials`, `signOut`)
- Modify: `lib/features/media_store/data/media_store_service.dart` (`buildMediaObjectStore`)
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart` (`_providerDisplayName`)
- Modify: `lib/features/settings/presentation/pages/connected_accounts_page.dart` (`_icon`)
- Modify: `lib/features/setup_wizard/presentation/widgets/steps/backup_sync_step.dart` (`_providerName`)
- Modify: `lib/core/database/tables/sync_tables.dart:19` (comment listing provider names)
- Test: `test/core/services/accounts/adapters/webdav_account_adapter_test.dart`
- Test: `test/core/services/accounts/account_identity_test.dart`
- Test: `test/core/services/cloud_storage/cloud_provider_instances_test.dart` (create if absent)
- Test: `test/features/settings/presentation/providers/sync_providers_account_dedup_test.dart`

**Interfaces:**
- Consumes: Tasks 2, 5, 7, 8, 9.
- Produces:
  - `CloudProviderType.webdav`, `AccountKind.webdav`.
  - `String webdavNaturalKey(WebDavConfig config)`.
  - `class WebDavAccountAdapter extends AccountProviderAdapter implements SyncCapable, MediaStoreCapable` with `loadConfig(account)` and `saveConfig(account, config)`.
  - `final webdavCredentialsStoreProvider = Provider<WebDavCredentialsStore>`.
  - `WebDavStorageProvider get webdavProviderInstance`.
  - `final webdavStorageProviderInstanceProvider = Provider<WebDavStorageProvider>` and `final webdavConfigProvider = FutureProvider<WebDavConfig?>` in `webdav_providers.dart`.

- [ ] **Step 1: Write the failing tests**

`webdav_account_adapter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/webdav_account_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_preset.dart';
import 'package:submersion/core/services/cloud_storage/webdav_storage_provider.dart';
import 'package:submersion/core/services/media_store/webdav_media_object_store.dart';

import '../../../../support/fake_keychain_storage.dart';

void main() {
  final account = ConnectedAccount(
    id: 'acc-1',
    kind: AccountKind.webdav,
    label: 'alice @ dav.test',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  final config = WebDavConfig(
    preset: WebDavPreset.other,
    serverUrl: 'https://dav.test/dav',
    username: 'alice',
    password: 'secret',
  );

  test('status follows the per-account blob and disconnect removes it', () async {
    final adapter = WebDavAccountAdapter(credentials: AccountCredentialsStore(storage: InMemoryKeychain()));
    expect(adapter.kind, AccountKind.webdav);
    expect(await adapter.status(account), AccountStatus.needsSignIn);
    expect(await adapter.mediaObjectStore(account), isNull);
    await adapter.saveConfig(account, config);
    expect(await adapter.status(account), AccountStatus.signedIn);
    expect((await adapter.loadConfig(account))!.toJson(), config.toJson());
    expect(await adapter.mediaObjectStore(account), isA<WebDavMediaObjectStore>());
    expect(adapter.syncProvider(account), isA<WebDavStorageProvider>());
    await adapter.disconnect(account);
    expect(await adapter.status(account), AccountStatus.needsSignIn);
  });
}
```

Read `connected_account.dart` for the exact constructor and adjust the `ConnectedAccount(...)` call if it differs.

Append to `account_identity_test.dart`:

```dart
  test('webdavNaturalKey ignores credentials and separates folders', () {
    final a = WebDavConfig(preset: WebDavPreset.other, serverUrl: 'https://dav.test/dav', username: 'alice', password: 'one');
    expect(webdavNaturalKey(a), webdavNaturalKey(a.copyWith(password: 'two')));
    expect(webdavNaturalKey(a), isNot(webdavNaturalKey(a.copyWith(folder: kDefaultWebDavMediaFolder))));
    expect(webdavNaturalKey(a), isNot(contains('one')));
    expect(naturalKeyForKind(AccountKind.webdav), isNull);
  });
```

`cloud_provider_instances_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/cloud_provider_instances.dart';

void main() {
  test('every provider id equals its enum name', () {
    // LibraryMovedMarker, EstablishedProviderStore and the cleanup offer map
    // ids back with CloudProviderType.values by name.
    for (final type in CloudProviderType.values) {
      expect(cloudProviderInstanceFor(type).providerId, type.name);
    }
  });
}
```

Append to `sync_providers_account_dedup_test.dart`, reusing that file's repository fixture (read its `setUp` for the names):

```dart
  test('WebDAV resolves to the deterministic account for its endpoint', () async {
    final keychain = InMemoryKeychain();
    final legacy = WebDavCredentialsStore(storage: keychain);
    final config = WebDavConfig(preset: WebDavPreset.other, serverUrl: 'https://dav.test/dav', username: 'alice', password: 'secret');
    await legacy.save(config);

    final account = await ensureAccountForProviderType(
      CloudProviderType.webdav,
      repo,
      syncRepository: syncRepository,
      webdavCredentials: legacy,
    );
    expect(account.kind, AccountKind.webdav);
    expect(account.id, accountIdFor(kind: AccountKind.webdav, naturalKey: webdavNaturalKey(config)));
    expect(account.label, 'alice @ dav.test');
  });
```

- [ ] **Step 2: Run and verify failure**

Run: `flutter test test/core/services/accounts test/core/services/cloud_storage/cloud_provider_instances_test.dart test/features/settings/presentation/providers/sync_providers_account_dedup_test.dart`
Expected: FAIL (missing enum values and files).

- [ ] **Step 3: Add the enum values and every exhaustive arm**

`sync_repository.dart:20`:

```dart
enum CloudProviderType { icloud, googledrive, s3, dropbox, webdav }
```

`account_kind.dart`: add `webdav` before `adobeLightroom`, `AccountKind.webdav => CloudProviderType.webdav` in `cloudProviderType`, and `CloudProviderType.webdav => AccountKind.webdav` in `fromCloudProviderType`. Update the doc comment ("The first five mirror [CloudProviderType]").

`account_identity.dart`:

```dart
/// Endpoint identity for a WebDAV account: the DAV root (which carries the
/// Nextcloud user id where there is one) plus the folder, so sync and media
/// on one server stay separate accounts. Credentials are excluded, so a
/// new app password does not mint a new account.
String webdavNaturalKey(WebDavConfig config) => '${config.davRoot}|${config.folder}';
```

and in `naturalKeyForKind` add `AccountKind.webdav` to the `null` arm; update its doc comment to name WebDAV as an instance kind.

`webdav_account_adapter.dart`:

```dart
import 'dart:convert';

import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/webdav_storage_provider.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/webdav_media_object_store.dart';

/// WebDAV servers as accounts. The whole WebDavConfig, password included,
/// is the per-account keychain payload; sync and media storage can point at
/// different servers or folders.
class WebDavAccountAdapter extends AccountProviderAdapter
    implements SyncCapable, MediaStoreCapable {
  WebDavAccountAdapter({AccountCredentialsStore? credentials})
    : _credentials = credentials ?? AccountCredentialsStore();

  final AccountCredentialsStore _credentials;

  @override
  AccountKind get kind => AccountKind.webdav;

  Future<WebDavConfig?> loadConfig(domain.ConnectedAccount account) async =>
      decodeWebDavConfig(await _credentials.read(account.id));

  Future<void> saveConfig(domain.ConnectedAccount account, WebDavConfig config) =>
      _credentials.write(account.id, jsonEncode(config.toJson()));

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
      WebDavStorageProvider(
        store: WebDavCredentialsStore(
          storageKey: AccountCredentialsStore.keyFor(account.id),
        ),
      );

  @override
  Future<MediaObjectStore?> mediaObjectStore(domain.ConnectedAccount account) async {
    final config = await loadConfig(account);
    if (config == null) return null;
    return WebDavMediaObjectStore(client: WebDavClient(config));
  }
}
```

`syncProvider` builds a `WebDavCredentialsStore` over the real keychain, like `S3AccountAdapter`; the adapter test checks only its type, so it never reads from it.

`account_providers.dart`: add

```dart
/// The legacy WebDAV sync blob (`sync_webdav_config`) the WebDAV settings
/// page writes; overridable for tests like [s3CredentialsStoreProvider].
final webdavCredentialsStoreProvider = Provider<WebDavCredentialsStore>(
  (ref) => WebDavCredentialsStore(),
);
```

and `WebDavAccountAdapter(credentials: ref.watch(accountCredentialsStoreProvider)),` after the S3 adapter in the registry list.

`account_startup_migration.dart`: add `case AccountKind.webdav:` to the `googledrive / icloud / adobeLightroom` group that `break`s (WebDAV postdates the pre-account era, so there is no legacy key to re-key), and `AccountKind.webdav => 'WebDAV',` in `_labelFor`.

`account_deduplicator.dart` `_canonicalIdFor`, before the generic tail:

```dart
    if (row.kind == AccountKind.webdav) {
      // Always written by the accounts layer, so the per-account blob is
      // the endpoint's identity on both the sync and the media path.
      final config = decodeWebDavConfig(await _credentials.read(row.id));
      if (config == null) return null;
      return accountIdFor(
        kind: AccountKind.webdav,
        naturalKey: webdavNaturalKey(config),
      );
    }
```

`cloud_provider_instances.dart`:

```dart
final _webdavProvider = WebDavStorageProvider();

/// Concrete-typed access to the WebDAV singleton for the configuration UI.
WebDavStorageProvider get webdavProviderInstance => _webdavProvider;
```

and `case CloudProviderType.webdav: return _webdavProvider;`.

`webdav_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/cloud_provider_instances.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav_storage_provider.dart';

/// The WebDAV provider singleton, for the settings page (load, save, test).
final webdavStorageProviderInstanceProvider = Provider<WebDavStorageProvider>(
  (ref) => webdavProviderInstance,
);

/// The stored WebDAV sync configuration, or null when unset. Invalidate
/// after saving or removing it.
final webdavConfigProvider = FutureProvider<WebDavConfig?>((ref) async {
  return ref.watch(webdavStorageProviderInstanceProvider).loadConfig();
});
```

Check `lib/core/providers/provider.dart` exports the Riverpod symbols used here (the S3 page imports it the same way).

`sync_providers.dart`:
- `ensureAccountForProviderType` gains `WebDavCredentialsStore? webdavCredentials` and, after the S3 branch:

```dart
  if (kind == AccountKind.webdav) {
    // An instance kind like S3: the endpoint in the legacy blob identifies
    // the account, and without it a fresh row waits for the deduplicator.
    final config = await (webdavCredentials ?? WebDavCredentialsStore()).load();
    if (config == null) {
      return repo.create(kind: kind, label: cloudProviderInstanceFor(type).providerName);
    }
    return repo.ensure(
      kind: kind,
      naturalKey: webdavNaturalKey(config),
      label: config.displayLabel,
    );
  }
```

- `selectedSyncAccountProvider` passes `webdavCredentials: ref.read(webdavCredentialsStoreProvider)`.
- `_mirrorLegacyCredentials` adds `AccountKind.webdav => WebDavCredentialsStore.storageKey,`.
- `signOut()` keeps hand-entered WebDAV settings like S3: change the condition to `if (selected != CloudProviderType.s3 && selected != CloudProviderType.webdav)`, update its doc comment to say "For S3 and WebDAV", and add `_ref.invalidate(webdavConfigProvider);` beside `_ref.invalidate(s3ConfigProvider);`.

`media_store_service.dart` `buildMediaObjectStore`:

```dart
    case CloudProviderType.webdav:
      // WebDAV media is always attached through an account, so the runtime
      // resolves it with buildMediaObjectStoreForAccount; there is no
      // pre-account WebDAV attachment to rebuild here.
      return null;
```

`cloud_sync_page.dart` `_providerDisplayName`: `case CloudProviderType.webdav: return l10n.settings_cloudSync_provider_webdav_title;`.

`connected_accounts_page.dart` `_icon`: `AccountKind.webdav => Icons.folder_shared_outlined,`.

`backup_sync_step.dart` `_providerName`: `case CloudProviderType.webdav: return 'WebDAV';` (the wizard names providers unlocalized, as it does for the others).

`sync_tables.dart:19`: add `'dropbox','webdav'` to the comment listing provider names if the comment lists them.

- [ ] **Step 4: Run analyze and the tests**

Run: `flutter analyze lib test` then `flutter test test/core/services/accounts test/core/services/cloud_storage test/core/services/sync/sync_provider_type_test.dart test/features/settings/presentation/providers test/features/media_store test/features/settings/presentation/pages/cloud_sync_page_test.dart test/features/setup_wizard`
Expected: analyze clean; tests PASS. `flutter analyze` is how to find any exhaustive switch this list missed: fix each reported one with the same pattern.

- [ ] **Step 5: Run the architecture guards**

Run: `flutter test test/architecture/ test/shared/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib test
git commit -m "feat(sync): wire WebDAV into accounts, provider resolution and media storage"
```

---

### Task 11: Trust dialog, shared form fields and the WebDAV settings page

**Files:**
- Create: `lib/features/settings/presentation/widgets/webdav_trust_certificate_dialog.dart`
- Create: `lib/features/settings/presentation/widgets/webdav_server_fields.dart`
- Create: `lib/features/settings/presentation/pages/webdav_config_page.dart`
- Modify: `lib/core/router/app_router.dart` (import beside `S3ConfigPage`; route beside `s3-config`)
- Test: `test/features/settings/presentation/widgets/webdav_trust_certificate_dialog_test.dart`
- Test: `test/features/settings/presentation/webdav_config_page_test.dart`

**Interfaces:**
- Consumes: Tasks 2, 4, 7, 9, 10; `syncStateProvider`, `selectedCloudProviderTypeProvider`, `syncInitializerProvider`, `selectedSyncAccountProvider`, `backupSettingsProvider` (as the S3 page uses them).
- Produces:
  - `Future<bool> showWebDavTrustDialog(BuildContext context, WebDavUntrustedCertificateException e)`.
  - `class WebDavFormController extends ChangeNotifier` with `TextEditingController serverUrl, username, password, folder`, `WebDavPreset preset`, `String? pinnedCertSha256`, `String? nextcloudUserId`, `bool passwordVisible`, `void setPreset(WebDavPreset)`, `void trust(String sha256)`, `void forgetPin()`, `void load(WebDavConfig)`, `void copyServerFrom(WebDavConfig source, {required String keepFolder})`, `WebDavConfig build()`, `dispose()`.
  - `class WebDavServerFields extends StatelessWidget` (`controller`, `keyPrefix`).
  - `Future<T> runWithCertificateTrust<T>(BuildContext context, WebDavFormController form, Future<T> Function(WebDavConfig config) op)`: runs `op(form.build())`; on a `WebDavUntrustedCertificateException` (directly, or as the `cause` of a `MediaStoreException`) shows the dialog, and when trusted calls `form.trust(...)` and runs `op` once more.
  - `class WebDavConfigPage extends ConsumerStatefulWidget`, route `/settings/cloud-sync/webdav-config` named `webdavConfig`.

Widget keys: `webdav-preset`, `webdav-server-url`, `webdav-username`, `webdav-password`, `webdav-folder`, `webdav-dav-root`, `webdav-http-warning`, `webdav-pin-row`, `webdav-forget-pin`, `webdav-test`, `webdav-save`, `webdav-remove`, `webdav-remove-confirm`, `webdav-trust`. The media form uses the prefix `webdav-media-` for the same fields.

- [ ] **Step 1: Write the failing dialog test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_trust_certificate_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final details = WebDavCertificateDetails(
    host: 'nas.local',
    port: 5006,
    sha256: 'ab' * 32,
    subject: 'CN=nas.local',
    issuer: 'CN=Synology',
    startValidity: DateTime.utc(2026),
    endValidity: DateTime.utc(2027, 3, 1),
  );

  Future<bool?> open(WidgetTester tester, WebDavUntrustedCertificateException e) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) => TextButton(
        onPressed: () async => result = await showWebDavTrustDialog(context, e),
        child: const Text('open'),
      )),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('shows host, fingerprint, subject and issuer; trust returns true', (tester) async {
    await open(tester, WebDavUntrustedCertificateException(details));
    expect(find.textContaining('nas.local'), findsWidgets);
    expect(find.text(formatFingerprint('ab' * 32)), findsOneWidget);
    expect(find.text('CN=Synology'), findsOneWidget);
    await tester.tap(find.byKey(const Key('webdav-trust')));
    await tester.pumpAndSettle();
  });

  testWidgets('a changed certificate shows the previous fingerprint', (tester) async {
    await open(tester, WebDavUntrustedCertificateException(details, pinnedSha256: 'cd' * 32));
    expect(find.text(formatFingerprint('cd' * 32)), findsOneWidget);
    expect(find.textContaining('changed since you trusted it'), findsOneWidget);
  });
}
```

To assert the returned value, capture `result` in a variable declared outside `open` and expect it after the tap: `true` after Trust, `false` after Cancel. Add one test for each.

- [ ] **Step 2: Write the failing page test**

Copy `_FakeSyncNotifier` and the `pumpPage` harness from `test/features/settings/presentation/s3_config_page_test.dart:110-240` into the new test file, replacing `s3StorageProviderInstanceProvider.overrideWithValue(provider)` with `webdavStorageProviderInstanceProvider.overrideWithValue(provider)`, `home: S3ConfigPage()` with `home: WebDavConfigPage()`, and the provider with:

```dart
  late FakeWebDavServer server;
  late WebDavStorageProvider provider;

  setUp(() {
    server = FakeWebDavServer();
    provider = WebDavStorageProvider(
      store: WebDavCredentialsStore(storage: InMemoryKeychain()),
      clientFactory: (c) => WebDavClient(c, httpClient: server.client, backoff: (_) => Duration.zero),
    );
  });
```

Tests:

```dart
  testWidgets('fixed-host presets hide the URL field and show the DAV root', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('webdav-preset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Koofr').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('webdav-server-url')), findsNothing);
    expect(find.text('https://app.koofr.net/dav/Koofr/'), findsOneWidget);
  });

  testWidgets('http shows the warning', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byKey(const Key('webdav-server-url')), 'http://nas.local/dav');
    await tester.pump();
    expect(find.byKey(const Key('webdav-http-warning')), findsOneWidget);
  });

  testWidgets('Test connection probes the server and reports success', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester); // server https://dav.test/dav, alice, secret
    await tester.tap(find.byKey(const Key('webdav-test')));
    await tester.pumpAndSettle();
    expect(find.text('Connection successful'), findsOneWidget);
    expect(server.collections, contains('/dav/Submersion'));
  });

  testWidgets('a wrong password shows the localized 401 text', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester, password: 'nope');
    await tester.tap(find.byKey(const Key('webdav-test')));
    await tester.pumpAndSettle();
    expect(find.textContaining('app password'), findsOneWidget);
  });

  testWidgets('Save stores the config and selects WebDAV', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.tap(find.byKey(const Key('webdav-save')));
    await tester.pumpAndSettle();
    expect(await provider.loadConfig(), isNotNull);
    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    expect(container.read(selectedCloudProviderTypeProvider), CloudProviderType.webdav);
  });

  testWidgets('a stored pin shows and can be forgotten', (tester) async {
    await provider.saveConfig(WebDavConfig(
      preset: WebDavPreset.synology,
      serverUrl: 'https://dav.test/dav',
      username: 'alice',
      password: 'secret',
      pinnedCertSha256: 'ab' * 32,
    ));
    await pumpPage(tester);
    expect(find.byKey(const Key('webdav-pin-row')), findsOneWidget);
    await tester.tap(find.byKey(const Key('webdav-forget-pin')));
    await tester.pump();
    expect(find.byKey(const Key('webdav-pin-row')), findsNothing);
  });
```

Write `fillValidForm(tester, {String password = 'secret'})` entering `https://dav.test/dav`, `alice` and the password into the three fields. For the "Remove" path, add a test mirroring the S3 page's remove test (`s3_config_page_test.dart`, search for `s3-remove`) with WebDAV keys.

- [ ] **Step 3: Run and verify failure**

Run: `flutter test test/features/settings/presentation/widgets/webdav_trust_certificate_dialog_test.dart test/features/settings/presentation/webdav_config_page_test.dart`
Expected: FAIL.

- [ ] **Step 4: Implement the dialog**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks whether to trust a certificate that failed verification. True only
/// when the user chose Trust.
Future<bool> showWebDavTrustDialog(
  BuildContext context,
  WebDavUntrustedCertificateException e,
) async {
  final l10n = context.l10n;
  final cert = e.certificate;
  final previous = e.pinnedSha256;
  final materialL10n = MaterialLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.gpp_maybe_outlined),
      title: Text(l10n.settings_webdavConfig_trust_title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              previous == null
                  ? l10n.settings_webdavConfig_trust_body(cert.host)
                  : l10n.settings_webdavConfig_trust_changedBody(cert.host),
            ),
            const SizedBox(height: 16),
            _Field(label: l10n.settings_webdavConfig_trust_fingerprint, value: cert.formattedFingerprint, monospace: true),
            if (previous != null)
              _Field(label: l10n.settings_webdavConfig_trust_previousFingerprint, value: formatFingerprint(previous), monospace: true),
            _Field(label: l10n.settings_webdavConfig_trust_subject, value: cert.subject),
            _Field(label: l10n.settings_webdavConfig_trust_issuer, value: cert.issuer),
            _Field(label: l10n.settings_webdavConfig_trust_expires, value: materialL10n.formatMediumDate(cert.endValidity)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          key: const Key('webdav-trust'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.settings_webdavConfig_trust_action),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.monospace = false});

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          SelectableText(
            value,
            style: monospace
                ? theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Implement `webdav_server_fields.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_preset.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_trust_certificate_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Form state shared by the sync settings page and the media form.
class WebDavFormController extends ChangeNotifier {
  WebDavFormController({String defaultFolder = kDefaultWebDavSyncFolder})
    : folder = TextEditingController(text: defaultFolder) {
    for (final c in [serverUrl, username, password, folder]) {
      c.addListener(notifyListeners);
    }
  }

  final serverUrl = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();
  final TextEditingController folder;

  WebDavPreset preset = WebDavPreset.nextcloud;
  String? pinnedCertSha256;
  String? nextcloudUserId;
  bool passwordVisible = false;

  void setPreset(WebDavPreset value) {
    preset = value;
    nextcloudUserId = null;
    notifyListeners();
  }

  void togglePasswordVisible() {
    passwordVisible = !passwordVisible;
    notifyListeners();
  }

  void trust(String sha256) {
    pinnedCertSha256 = sha256;
    notifyListeners();
  }

  void forgetPin() {
    pinnedCertSha256 = null;
    notifyListeners();
  }

  void load(WebDavConfig config) {
    preset = config.preset;
    serverUrl.text = config.serverUrl;
    username.text = config.username;
    password.text = config.password;
    folder.text = config.folder;
    pinnedCertSha256 = config.pinnedCertSha256;
    nextcloudUserId = config.nextcloudUserId;
    notifyListeners();
  }

  /// Server, login and pin from [source]; the folder stays [keepFolder] so
  /// media never lands in the sync folder.
  void copyServerFrom(WebDavConfig source, {required String keepFolder}) {
    load(source.copyWith(folder: keepFolder));
  }

  WebDavConfig build() => WebDavConfig(
    preset: preset,
    serverUrl: preset.needsServerUrl ? serverUrl.text : '',
    username: username.text,
    password: password.text,
    folder: folder.text,
    nextcloudUserId: nextcloudUserId,
    pinnedCertSha256: pinnedCertSha256,
  );

  /// The resolved DAV root for display, or null while the URL is unusable.
  String? get davRootPreview {
    if (preset.needsServerUrl && Uri.tryParse(serverUrl.text.trim())?.host.isEmpty != false) {
      return null;
    }
    return build().davRoot.toString();
  }

  bool get isInsecure =>
      preset.needsServerUrl && serverUrl.text.trim().toLowerCase().startsWith('http://');

  @override
  void dispose() {
    for (final c in [serverUrl, username, password, folder]) {
      c.dispose();
    }
    super.dispose();
  }
}

/// Runs [op] with the form's config; on an untrusted certificate asks the
/// user, and when they trust it pins it and runs [op] once more.
Future<T> runWithCertificateTrust<T>(
  BuildContext context,
  WebDavFormController form,
  Future<T> Function(WebDavConfig config) op,
) async {
  try {
    return await op(form.build());
  } catch (e) {
    final untrusted = switch (e) {
      WebDavUntrustedCertificateException() => e,
      MediaStoreException(cause: final WebDavUntrustedCertificateException c) => c,
      _ => null,
    };
    if (untrusted == null || !context.mounted) rethrow;
    final trusted = await showWebDavTrustDialog(context, untrusted);
    if (!trusted) rethrow;
    form.trust(untrusted.certificate.sha256);
    return op(form.build());
  }
}

String presetLabel(AppLocalizations l10n, WebDavPreset preset) => switch (preset) {
  WebDavPreset.nextcloud => l10n.settings_webdavConfig_preset_nextcloud,
  WebDavPreset.owncloud => l10n.settings_webdavConfig_preset_owncloud,
  WebDavPreset.synology => l10n.settings_webdavConfig_preset_synology,
  WebDavPreset.koofr => l10n.settings_webdavConfig_preset_koofr,
  WebDavPreset.pcloudUs => l10n.settings_webdavConfig_preset_pcloudUs,
  WebDavPreset.pcloudEu => l10n.settings_webdavConfig_preset_pcloudEu,
  WebDavPreset.fastmail => l10n.settings_webdavConfig_preset_fastmail,
  WebDavPreset.yandex => l10n.settings_webdavConfig_preset_yandex,
  WebDavPreset.other => l10n.settings_webdavConfig_preset_other,
};

/// Server type, address, login, folder, DAV root preview, http warning and
/// trusted-certificate row. Lives inside the caller's [Form].
class WebDavServerFields extends StatelessWidget {
  const WebDavServerFields({super.key, required this.controller, this.keyPrefix = 'webdav'});

  final WebDavFormController controller;
  final String keyPrefix;

  Key _k(String name) => Key('$keyPrefix-$name');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final preset = controller.preset;
        final root = controller.davRootPreview;
        final pin = controller.pinnedCertSha256;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.isInsecure)
              Card(
                key: _k('http-warning'),
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Icon(Icons.lock_open, color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l10n.settings_webdavConfig_warning_http)),
                  ]),
                ),
              ),
            DropdownButtonFormField<WebDavPreset>(
              key: _k('preset'),
              initialValue: preset,
              decoration: InputDecoration(labelText: l10n.settings_webdavConfig_field_preset_label),
              items: [
                for (final p in WebDavPreset.values)
                  DropdownMenuItem(value: p, child: Text(presetLabel(l10n, p))),
              ],
              onChanged: (value) {
                if (value != null) controller.setPreset(value);
              },
            ),
            if (preset.needsServerUrl) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: _k('server-url'),
                controller: controller.serverUrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.settings_webdavConfig_field_serverUrl_label,
                  hintText: switch (preset) {
                    WebDavPreset.synology => l10n.settings_webdavConfig_field_serverUrl_hintSynology,
                    WebDavPreset.other => l10n.settings_webdavConfig_field_serverUrl_hintDav,
                    _ => l10n.settings_webdavConfig_field_serverUrl_hintHost,
                  },
                  helperText: preset == WebDavPreset.synology ? l10n.settings_webdavConfig_synology_helper : null,
                  helperMaxLines: 3,
                ),
                validator: (value) {
                  final trimmed = (value ?? '').trim();
                  if (trimmed.isEmpty) return l10n.settings_webdavConfig_validation_required;
                  final uri = Uri.tryParse(trimmed);
                  final ok = uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
                  return ok ? null : l10n.settings_webdavConfig_validation_url;
                },
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              key: _k('username'),
              controller: controller.username,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: l10n.settings_webdavConfig_field_username_label),
              validator: (v) => (v ?? '').trim().isEmpty ? l10n.settings_webdavConfig_validation_required : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: _k('password'),
              controller: controller.password,
              obscureText: !controller.passwordVisible,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.settings_webdavConfig_field_password_label,
                helperText: preset.recommendsAppPassword ? l10n.settings_webdavConfig_field_password_appPasswordHelper : null,
                suffixIcon: IconButton(
                  icon: Icon(controller.passwordVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: controller.togglePasswordVisible,
                ),
              ),
              validator: (v) => (v ?? '').isEmpty ? l10n.settings_webdavConfig_validation_required : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: _k('folder'),
              controller: controller.folder,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.settings_webdavConfig_field_folder_label,
                helperText: l10n.settings_webdavConfig_field_folder_helper,
              ),
              validator: (v) {
                final segments = (v ?? '').split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                if (segments.isEmpty) return l10n.settings_webdavConfig_validation_required;
                if (segments.any((s) => s == '.' || s == '..')) return l10n.settings_webdavConfig_validation_folder;
                return null;
              },
            ),
            if (root != null)
              ListTile(
                key: _k('dav-root'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.settings_webdavConfig_davRoot_label, style: theme.textTheme.labelMedium),
                subtitle: SelectableText(root),
              ),
            if (pin != null)
              ListTile(
                key: _k('pin-row'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(l10n.settings_webdavConfig_trustedCertificate(formatFingerprint(pin))),
                trailing: TextButton(
                  key: _k('forget-pin'),
                  onPressed: controller.forgetPin,
                  child: Text(l10n.settings_webdavConfig_action_forgetCertificate),
                ),
              ),
          ],
        );
      },
    );
  }
}
```

If `DropdownButtonFormField` on this Flutter version names the parameter `value` instead of `initialValue`, use whichever `flutter analyze` accepts without a deprecation warning.

- [ ] **Step 6: Implement `webdav_config_page.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/providers/webdav_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_error_text.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_server_fields.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Configuration for the WebDAV sync backend. Test connection and Save both
/// run the live probe (Save needs it to resolve the Nextcloud user id) and
/// both offer to trust a self-signed certificate.
class WebDavConfigPage extends ConsumerStatefulWidget {
  const WebDavConfigPage({super.key});

  @override
  ConsumerState<WebDavConfigPage> createState() => _WebDavConfigPageState();
}

class _WebDavConfigPageState extends ConsumerState<WebDavConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _form = WebDavFormController();
  bool _busy = false;
  bool _hasExistingConfig = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final existing = await ref.read(webdavStorageProviderInstanceProvider).loadConfig();
      if (!mounted || existing == null) return;
      // A slow keychain read must not overwrite typing.
      if (_form.username.text.isNotEmpty || _form.password.text.isNotEmpty) return;
      _form.load(existing);
      setState(() => _hasExistingConfig = true);
    } catch (_) {
      _showSnack(context.l10n.settings_webdavConfig_error_secureStorage, isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
      duration: isError ? const Duration(seconds: 10) : const Duration(seconds: 4),
    ));
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final resolved = await runWithCertificateTrust(
        context,
        _form,
        ref.read(webdavStorageProviderInstanceProvider).testConnection,
      );
      _form.nextcloudUserId = resolved.nextcloudUserId;
      _showSnack(l10n.settings_webdavConfig_test_success);
    } on WebDavException catch (e) {
      _showSnack(webDavErrorText(l10n, e), isError: true);
    } catch (e) {
      _showSnack('${l10n.settings_webdavConfig_error_secureStorage}: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    // The app-level container outlives this page, so the writes below finish
    // even if the page is popped mid-save (the S3 page does the same).
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _busy = true);
    try {
      final provider = container.read(webdavStorageProviderInstanceProvider);
      final resolved = await runWithCertificateTrust(context, _form, provider.testConnection);
      await provider.saveConfig(resolved);
      container.read(selectedCloudProviderTypeProvider.notifier).state = CloudProviderType.webdav;
      await container.read(syncInitializerProvider).saveProvider(CloudProviderType.webdav);
      container.read(syncStateProvider.notifier).refreshState();
      container.invalidate(webdavConfigProvider);
      container.invalidate(selectedSyncAccountProvider);
      await container.read(selectedSyncAccountProvider.future);
      if (!mounted) return;
      _showSnack(l10n.settings_webdavConfig_saved);
      await Navigator.maybePop(context);
    } on WebDavException catch (e) {
      _showSnack(webDavErrorText(l10n, e), isError: true);
    } catch (e) {
      _showSnack('${l10n.settings_webdavConfig_error_secureStorage}: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final l10n = context.l10n;
    final warnBackup =
        ref.read(selectedCloudProviderTypeProvider) == CloudProviderType.webdav &&
        ref.read(backupSettingsProvider).cloudBackupEnabled;
    final body = warnBackup
        ? '${l10n.settings_webdavConfig_remove_confirm_body}\n\n${l10n.settings_cloudSync_signOut_backupWarning}'
        : l10n.settings_webdavConfig_remove_confirm_body;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_webdavConfig_remove_confirm_title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.common_action_cancel)),
          TextButton(
            key: const Key('webdav-remove-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.settings_webdavConfig_remove_confirm_action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(webdavStorageProviderInstanceProvider).signOut();
      if (ref.read(selectedCloudProviderTypeProvider) == CloudProviderType.webdav) {
        await ref.read(syncStateProvider.notifier).signOut();
        await ref.read(backupSettingsProvider.notifier).disableCloudBackup();
      }
      ref.invalidate(webdavConfigProvider);
      if (!mounted) return;
      _showSnack(context.l10n.settings_webdavConfig_removed);
      await Navigator.maybePop(context);
    } catch (e) {
      _showSnack('${l10n.settings_webdavConfig_error_secureStorage}: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_webdavConfig_appBar_title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            WebDavServerFields(controller: _form),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('webdav-test'),
                  onPressed: _busy ? null : _testConnection,
                  child: Text(l10n.settings_webdavConfig_action_testConnection),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('webdav-save'),
                  onPressed: _busy ? null : _save,
                  child: Text(l10n.common_action_save),
                ),
              ),
            ]),
            if (_hasExistingConfig) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const Key('webdav-remove'),
                onPressed: _busy ? null : _remove,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(l10n.settings_webdavConfig_action_remove),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

Router (`app_router.dart`), inside the `cloud-sync` route's `routes:` after `s3-config`:

```dart
                  GoRoute(
                    path: 'webdav-config',
                    name: 'webdavConfig',
                    builder: (context, state) => const WebDavConfigPage(),
                  ),
```

- [ ] **Step 7: Run tests**

Run: `flutter test test/features/settings/presentation/widgets/webdav_trust_certificate_dialog_test.dart test/features/settings/presentation/webdav_config_page_test.dart test/core/router`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/settings/presentation/widgets/webdav_trust_certificate_dialog.dart lib/features/settings/presentation/widgets/webdav_server_fields.dart lib/features/settings/presentation/pages/webdav_config_page.dart lib/core/router/app_router.dart test/features/settings/presentation
git commit -m "feat(sync): add the WebDAV settings page and certificate trust dialog"
```

---

### Task 12: Cloud Sync tile and setup wizard card

**Files:**
- Create: `lib/features/settings/presentation/widgets/webdav_provider_tile.dart`
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart` (`_buildProviderSection`, after the S3 tile)
- Modify: `lib/features/setup_wizard/presentation/widgets/steps/backup_sync_step.dart` (`_openWebDavConfig`, a card after S3)
- Test: `test/features/settings/presentation/widgets/webdav_provider_tile_test.dart`
- Test: `test/features/setup_wizard/presentation/widgets/steps/backup_sync_step_test.dart`

**Interfaces:**
- Consumes: `webdavConfigProvider` (Task 10), `WebDavConfigPage` (Task 11).
- Produces: `class WebDavProviderTile extends ConsumerWidget` with `isSelected`, `onSelect`, `onEdit`.

The tile is its own file because `cloud_sync_page.dart` is already 1516 lines.

- [ ] **Step 1: Write the failing tile test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_preset.dart';
import 'package:submersion/features/settings/presentation/providers/webdav_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_provider_tile.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<({List<String> calls})> pump(WidgetTester tester, WebDavConfig? config) async {
    final calls = <String>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [webdavConfigProvider.overrideWith((ref) async => config)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: WebDavProviderTile(
          isSelected: false,
          onSelect: () => calls.add('select'),
          onEdit: () => calls.add('edit'),
        )),
      ),
    ));
    await tester.pumpAndSettle();
    return (calls: calls);
  }

  testWidgets('unconfigured: generic subtitle, tap opens the editor', (tester) async {
    final r = await pump(tester, null);
    expect(find.text('Nextcloud, ownCloud, Synology, Koofr and other WebDAV servers'), findsOneWidget);
    await tester.tap(find.text('WebDAV'));
    expect(r.calls, ['edit']);
  });

  testWidgets('configured: account label, tap selects', (tester) async {
    final r = await pump(tester, WebDavConfig(
      preset: WebDavPreset.other,
      serverUrl: 'https://dav.test/dav',
      username: 'alice',
      password: 'secret',
    ));
    expect(find.text('alice @ dav.test'), findsOneWidget);
    await tester.tap(find.text('WebDAV'));
    expect(r.calls, ['select']);
  });
}
```

- [ ] **Step 2: Run and verify failure**

Run: `flutter test test/features/settings/presentation/widgets/webdav_provider_tile_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the tile and add it to the page**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/webdav_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The WebDAV row in Cloud Sync's provider list. Tapping selects WebDAV once
/// it is configured, otherwise opens its settings; the gear always edits.
class WebDavProviderTile extends ConsumerWidget {
  const WebDavProviderTile({
    super.key,
    required this.isSelected,
    required this.onSelect,
    required this.onEdit,
  });

  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final config = ref.watch(webdavConfigProvider).valueOrNull;
    return Semantics(
      selected: isSelected,
      child: ListTile(
        key: const Key('webdav-provider-tile'),
        leading: const Icon(Icons.folder_shared),
        title: Text(l10n.settings_cloudSync_provider_webdav_title),
        subtitle: Text(config?.displayLabel ?? l10n.settings_cloudSync_provider_webdav_subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.green, semanticLabel: l10n.settings_cloudSync_provider_connected),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: l10n.settings_cloudSync_provider_webdav_edit,
              onPressed: onEdit,
            ),
          ],
        ),
        onTap: config != null ? onSelect : onEdit,
      ),
    );
  }
}
```

In `cloud_sync_page.dart` `_buildProviderSection`, after `_buildS3ProviderTile(context, ref, selectedProvider),`:

```dart
        WebDavProviderTile(
          isSelected: selectedProvider == CloudProviderType.webdav,
          onSelect: () => _selectProvider(context, ref, CloudProviderType.webdav),
          onEdit: () => context.push('/settings/cloud-sync/webdav-config'),
        ),
```

- [ ] **Step 4: Add the wizard card**

In `backup_sync_step.dart`, beside `_openS3Config`:

```dart
  Future<void> _openWebDavConfig() async {
    // Root navigator for the same reason as _openS3Config: the onboarding
    // redirect would bounce a go_router push back to /welcome.
    await Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute<void>(builder: (_) => const WebDavConfigPage()));
    if (!mounted) return;
    final sel = ref.read(selectedCloudProviderTypeProvider);
    if (sel == CloudProviderType.webdav) {
      ref.read(setupWizardProvider(widget.mode).notifier).setConnectedProvider(sel);
    }
  }
```

and after the S3 card:

```dart
            _providerCard(
              theme: theme,
              icon: Icons.folder_shared,
              name: 'WebDAV',
              onTap: _connecting ? null : _openWebDavConfig,
            ),
```

Add a test to `backup_sync_step_test.dart` that finds the `WebDAV` card and, on tap, pushes `WebDavConfigPage` (mirror that file's existing S3-card test; search it for `'S3'`).

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/settings/presentation test/features/setup_wizard`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/presentation/widgets/webdav_provider_tile.dart lib/features/settings/presentation/pages/cloud_sync_page.dart lib/features/setup_wizard/presentation/widgets/steps/backup_sync_step.dart test/features/settings/presentation/widgets/webdav_provider_tile_test.dart test/features/setup_wizard
git commit -m "feat(sync): offer WebDAV on the Cloud Sync page and in the setup wizard"
```

---

### Task 13: WebDAV media storage connect flow and form

**Files:**
- Modify: `lib/features/media_store/data/media_store_service.dart` (extract the probe, add `testWebDav` and `connectWebDav`, constructor seam `webdavClientFactory`)
- Create: `lib/features/media_store/presentation/widgets/webdav_media_form.dart`
- Modify: `lib/features/media_store/presentation/pages/media_storage_page.dart` (chooser segment, form slot, managed-panel condition)
- Test: `test/features/media_store/media_store_service_webdav_test.dart`
- Test: `test/features/media_store/presentation/widgets/webdav_media_form_test.dart`

**Interfaces:**
- Consumes: Tasks 5, 7, 8, 10, 11; `mediaStoreServiceProvider`, `invalidateMediaStoreAttachment(ref)`.
- Produces:
  - `MediaStoreService({..., WebDavClient Function(WebDavConfig config)? webdavClientFactory})`.
  - `Future<WebDavConfig> MediaStoreService.testWebDav(WebDavConfig config)` and `Future<MediaStoreConnectResult> MediaStoreService.connectWebDav(WebDavConfig config)`; both return or use the config with the Nextcloud user id resolved, and both throw `MediaStoreException` (an untrusted certificate arrives as its `cause`).
  - `class WebDavMediaForm extends ConsumerStatefulWidget`.

- [ ] **Step 1: Write the failing service test**

Read `test/features/media_store/media_store_service_test.dart` for how it builds `MediaStoreService` (credentials store, attach state over mocked SharedPreferences, stores repository over an in-memory database, accounts repository) and reuse that setUp, adding `webdavClientFactory: (c) => WebDavClient(c, httpClient: server.client, backoff: (_) => Duration.zero)`. Then:

```dart
  test('testWebDav probes and leaves nothing behind', () async {
    await service.testWebDav(config);
    expect(server.files.keys.where((k) => k.contains('probe')), isEmpty);
  });

  test('connectWebDav writes the marker, account, credentials and attach state', () async {
    final result = await service.connectWebDav(config);
    expect(server.files.keys, contains('/dav/Submersion Media/smv1/store.json'));
    expect(await attachState.attachedStoreId(), result.storeId);
    expect(await attachState.attachedProviderType(), CloudProviderType.webdav);
    final accountId = await attachState.attachedAccountId();
    final account = await accounts.getById(accountId!);
    expect(account!.kind, AccountKind.webdav);
    expect(account.id, accountIdFor(kind: AccountKind.webdav, naturalKey: webdavNaturalKey(config)));
    expect(await accountCredentials.read(account.id), contains('"folder":"Submersion Media"'));
  });

  test('a second device adopts the existing store', () async {
    final first = await service.connectWebDav(config);
    await attachState.clear();
    final second = await service.connectWebDav(config);
    expect(second.storeId, first.storeId);
    expect(second.createdNewStore, isFalse);
  });

  test('a wrong password is an auth MediaStoreException', () async {
    await expectLater(
      service.connectWebDav(config.copyWith(password: 'nope')),
      throwsA(isA<MediaStoreException>().having((e) => e.kind, 'kind', MediaStoreErrorKind.auth)),
    );
  });
```

with `config = WebDavConfig(preset: WebDavPreset.other, serverUrl: 'https://dav.test/dav', username: 'alice', password: 'secret', folder: kDefaultWebDavMediaFolder)` and `server = FakeWebDavServer()`.

- [ ] **Step 2: Write the failing form test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_preset.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/widgets/webdav_media_form.dart';
import 'package:submersion/features/settings/presentation/providers/webdav_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeService extends Fake implements MediaStoreService {
  final connected = <WebDavConfig>[];
  bool untrustedOnce = false;

  @override
  Future<MediaStoreConnectResult> connectWebDav(WebDavConfig config) async {
    if (untrustedOnce) {
      untrustedOnce = false;
      throw MediaStoreException(
        'untrusted',
        kind: MediaStoreErrorKind.auth,
        cause: WebDavUntrustedCertificateException(WebDavCertificateDetails(
          host: 'nas.local', port: 5006, sha256: 'ab' * 32,
          subject: 'CN=nas', issuer: 'CN=nas',
          startValidity: DateTime.utc(2026), endValidity: DateTime.utc(2027),
        )),
      );
    }
    connected.add(config);
    return const MediaStoreConnectResult(storeId: 's1', createdNewStore: true);
  }
}

void main() {
  late _FakeService service;
  final sync = WebDavConfig(
    preset: WebDavPreset.synology,
    serverUrl: 'https://nas.local:5006',
    username: 'alice',
    password: 'secret',
    pinnedCertSha256: 'cd' * 32,
  );

  Future<void> pump(WidgetTester tester, {WebDavConfig? syncConfig}) async {
    service = _FakeService();
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        mediaStoreServiceProvider.overrideWithValue(service),
        webdavConfigProvider.overrideWith((ref) async => syncConfig),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: WebDavMediaForm())),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Use my sync server copies everything but the folder', (tester) async {
    await pump(tester, syncConfig: sync);
    await tester.tap(find.byKey(const Key('webdav-media-use-sync')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('webdav-media-connect')));
    await tester.pumpAndSettle();
    final sent = service.connected.single;
    expect(sent.serverUrl, sync.serverUrl);
    expect(sent.pinnedCertSha256, sync.pinnedCertSha256);
    expect(sent.folder, kDefaultWebDavMediaFolder);
  });

  testWidgets('no sync config, no prefill button', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('webdav-media-use-sync')), findsNothing);
  });

  testWidgets('an untrusted certificate is offered, trusted and retried', (tester) async {
    await pump(tester, syncConfig: sync.copyWith(clearPin: true));
    service.untrustedOnce = true;
    await tester.tap(find.byKey(const Key('webdav-media-use-sync')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('webdav-media-connect')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('webdav-trust')));
    await tester.pumpAndSettle();
    expect(service.connected.single.pinnedCertSha256, 'ab' * 32);
  });
}
```

If `mediaStoreServiceProvider` is not a plain `Provider` that supports `overrideWithValue`, use `overrideWith((ref) => service)`. If `tester.view.reset` does not exist on this Flutter version, reset `physicalSize` and `devicePixelRatio` as the S3 page test does.

- [ ] **Step 3: Run and verify failure**

Run: `flutter test test/features/media_store/media_store_service_webdav_test.dart test/features/media_store/presentation/widgets/webdav_media_form_test.dart`
Expected: FAIL.

- [ ] **Step 4: Implement the service methods**

In `media_store_service.dart`:
- Add the constructor parameter `WebDavClient Function(WebDavConfig config)? webdavClientFactory` stored as `_webdavClientFactory = webdavClientFactory ?? WebDavClient.new`.
- Move the body of `testConnection(S3Config)` after `_validate(config)` and the store build into `Future<void> _probeStore(MediaObjectStore store)` (the write, head, read-back, delete and temp-file cleanup), leaving `testConnection` as validate, build, `_probeStore(built.store)`, close the owned client.
- Add:

```dart
  /// Validates [config] and resolves the Nextcloud user id, mapping WebDAV
  /// failures to media errors (an untrusted certificate stays the cause, so
  /// the form can offer to trust it).
  Future<WebDavConfig> _resolveWebDav(WebDavConfig config) async {
    final error = config.validate();
    if (error != null) {
      throw MediaStoreException(error, kind: MediaStoreErrorKind.fatal);
    }
    if (!config.preset.usesNextcloudLayout) return config;
    final client = _webdavClientFactory(config);
    try {
      final id = await client.resolveNextcloudUserId();
      return (id == null || id == config.nextcloudUserId)
          ? config
          : config.copyWith(nextcloudUserId: id);
    } on WebDavException catch (e) {
      if (e.code == WebDavErrorCode.notFound || e.code == WebDavErrorCode.notWebDav) {
        return config;
      }
      throw MediaStoreException(e.message, kind: mediaStoreKindFor(e.code), cause: e);
    } finally {
      client.close();
    }
  }

  /// Live write, read-back and delete probe against unsaved [config].
  Future<WebDavConfig> testWebDav(WebDavConfig config) async {
    final resolved = await _resolveWebDav(config);
    final client = _webdavClientFactory(resolved);
    try {
      await _probeStore(WebDavMediaObjectStore(client: client));
    } finally {
      client.close();
    }
    return resolved;
  }

  /// Adopts or creates the store marker in the folder, then records the
  /// account (deterministic id from the endpoint), its credentials, the
  /// attach state and the synced store descriptor.
  Future<MediaStoreConnectResult> connectWebDav(WebDavConfig config) async {
    final resolved = await _resolveWebDav(config);
    final client = _webdavClientFactory(resolved);
    try {
      final ensured = await _ensureMarker(WebDavMediaObjectStore(client: client));
      final account = await _accounts.ensure(
        kind: AccountKind.webdav,
        naturalKey: webdavNaturalKey(resolved),
        label: resolved.displayLabel,
      );
      await _accountCredentials.write(account.id, jsonEncode(resolved.toJson()));
      await _attachState.setAttached(
        ensured.marker.storeId,
        providerType: CloudProviderType.webdav,
        accountId: account.id,
      );
      await _storesRepository.upsertActive(
        storeId: ensured.marker.storeId,
        providerType: CloudProviderType.webdav.name,
        displayHint: resolved.displayLabel,
      );
      return MediaStoreConnectResult(
        storeId: ensured.marker.storeId,
        createdNewStore: ensured.created,
      );
    } finally {
      client.close();
    }
  }
```

`WebDavMediaObjectStore` already maps WebDAV errors to `MediaStoreException` inside `_probeStore` and `_ensureMarker`.

- [ ] **Step 5: Implement `webdav_media_form.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/features/media_store/presentation/pages/media_storage_page.dart'
    show mediaStoreErrorMessage;
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/webdav_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_error_text.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_server_fields.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Media Storage page's WebDAV form: the same server fields as the sync
/// settings, its own folder, and a shortcut that copies the sync server.
class WebDavMediaForm extends ConsumerStatefulWidget {
  const WebDavMediaForm({super.key});

  @override
  ConsumerState<WebDavMediaForm> createState() => _WebDavMediaFormState();
}

class _WebDavMediaFormState extends ConsumerState<WebDavMediaForm> {
  final _formKey = GlobalKey<FormState>();
  final _form = WebDavFormController(defaultFolder: kDefaultWebDavMediaFolder);
  bool _busy = false;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
      duration: isError ? const Duration(seconds: 10) : const Duration(seconds: 4),
    ));
  }

  String _errorText(MediaStoreException e) {
    final l10n = context.l10n;
    final cause = e.cause;
    return cause is WebDavException ? webDavErrorText(l10n, cause) : mediaStoreErrorMessage(l10n, e);
  }

  Future<void> _run(Future<void> Function() body) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await body();
    } on MediaStoreException catch (e) {
      _snack(_errorText(e), isError: true);
    } catch (e) {
      _snack('${context.l10n.settings_webdavConfig_error_secureStorage}: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() => _run(() async {
    final service = ref.read(mediaStoreServiceProvider);
    final resolved = await runWithCertificateTrust(context, _form, service.testWebDav);
    _form.nextcloudUserId = resolved.nextcloudUserId;
    _snack(context.l10n.settings_mediaStorage_test_success);
  });

  Future<void> _connect() => _run(() async {
    final service = ref.read(mediaStoreServiceProvider);
    await runWithCertificateTrust(context, _form, service.connectWebDav);
    invalidateMediaStoreAttachment(ref);
    if (!mounted) return;
    _snack(context.l10n.settings_mediaStorage_saved);
    await Navigator.maybePop(context);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final syncConfig = ref.watch(webdavConfigProvider).valueOrNull;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (syncConfig != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('webdav-media-use-sync'),
                icon: const Icon(Icons.copy_outlined),
                label: Text(l10n.settings_mediaStorage_webdav_useSyncServer),
                onPressed: _busy
                    ? null
                    : () => _form.copyServerFrom(syncConfig, keepFolder: kDefaultWebDavMediaFolder),
              ),
            ),
          WebDavServerFields(controller: _form, keyPrefix: 'webdav-media'),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('webdav-media-test'),
                onPressed: _busy ? null : _test,
                child: Text(l10n.settings_webdavConfig_action_testConnection),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('webdav-media-connect'),
                onPressed: _busy ? null : _connect,
                child: Text(l10n.common_action_save),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
```

`copyServerFrom` keeps the media folder the user typed if they changed it from the default: pass `keepFolder: _form.folder.text.trim().isEmpty ? kDefaultWebDavMediaFolder : _form.folder.text` instead of the constant.

The import of `mediaStoreErrorMessage` from the page creates a page-to-widget-to-page cycle; if `test/architecture/` flags it, move `mediaStoreErrorMessage` into `lib/features/media_store/presentation/widgets/media_store_error_message.dart`, re-export it from the page (`export ... show mediaStoreErrorMessage;`), and import that file here.

- [ ] **Step 6: Add the segment to the Media Storage page**

In `media_storage_page.dart`, add after the S3 segment:

```dart
                  ButtonSegment(
                    value: CloudProviderType.webdav,
                    label: Text(l10n.settings_mediaStorage_provider_webdav),
                  ),
```

(make the `segments:` list non-const if needed), change `if (_selectedProvider != CloudProviderType.s3)` before `..._managedConnectPanel(l10n)` to `if (_selectedProvider != CloudProviderType.s3 && _selectedProvider != CloudProviderType.webdav)`, and add after it:

```dart
              if (_selectedProvider == CloudProviderType.webdav)
                const WebDavMediaForm(),
```

Check the page's line count stays within a few lines of 906.

- [ ] **Step 7: Run tests**

Run: `flutter test test/features/media_store test/core/services/media_store`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/media_store test/features/media_store
git commit -m "feat(media-store): connect media storage to a WebDAV server"
```

---

### Task 14: Full verification

**Files:** none new.

- [ ] **Step 1: Format and analyze**

Run: `dart format . && flutter analyze`
Expected: no changes left unformatted; "No issues found!".

- [ ] **Step 2: Guards and every touched area**

Run: `flutter test test/architecture/ test/shared/ test/core/database test/core/services test/core/data test/features/settings test/features/media_store test/features/setup_wizard test/l10n`
Expected: PASS. Log long runs to the scratchpad, not the repo.

- [ ] **Step 3: Dash and attribution scan of the diff**

Run: `git diff origin/main -- . ':(exclude)lib/l10n' | grep -n -P '\x{2014}|\x{2013}' ; echo exit=$?`
Expected: `exit=1` (no matches). Then confirm no commit message mentions an AI tool: `git log origin/main..HEAD --format=%B | grep -i -E 'claude|anthropic|co-authored' ; echo exit=$?` gives `exit=1`.

- [ ] **Step 4: After screenshots**

Launch the app with the `run` skill and capture, into the scratchpad, the screens listed in the build-feature skill's Screenshots section: Cloud Sync page with the WebDAV tile (`01-cloud-sync-after.png`), the WebDAV settings page in light and dark (`02-webdav-config-after.png`, `02-webdav-config-after-dark.png`) and at phone width (`02-webdav-config-after-phone.png`), the trust dialog (`03-trust-dialog-after.png`, using a Synology preset pointed at any host with a self-signed certificate, or a widget-test golden if no such host is reachable), the Media Storage page with the WebDAV segment (`04-media-storage-after.png`), and the setup wizard backup step (`05-wizard-backup-after.png`).
