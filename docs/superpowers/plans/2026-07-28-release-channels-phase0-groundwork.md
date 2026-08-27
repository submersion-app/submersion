# Release Channels Phase 0: Groundwork & Data-Safety Guards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Phase 0 groundwork from the release-channels spec (`docs/superpowers/specs/2026-07-28-release-channels-design.md`): fix the latent `UPDATE_CHANNEL`/asset-suffix bugs and close the data-safety gaps (startup screen dead end, missing sync schema-version gate) that must hold before a beta channel exposes users to newer-schema databases.

**Architecture:** Three independent strands: (1) one-line distribution fixes in `update_providers.dart`, `release.yml`, and the iOS Fastfile; (2) a friendlier newer-database startup screen; (3) a schema-version stamp in sync manifests plus an ingest gate in `ChangesetReader`, surfaced through `SyncResult`, copying the proven library-epoch skip pattern end to end.

**Tech Stack:** Flutter/Dart, Drift/sqlite3, custom changeset-log sync engine, GitHub Actions YAML, fastlane Ruby, `flutter_test`.

## Global Constraints

- All Dart code must pass `dart format .` with no changes (format the whole project, not just edited files).
- `flutter analyze` must be clean; infos are fatal in CI. Never pipe analyze output through `tail`/`head`.
- No emojis in code, comments, or documentation. No new hardcoded secrets.
- Startup-page strings are intentionally hardcoded English (pre-l10n boot phase); match that. Sync result messages are also plain English strings today; match the existing style.
- Tests run with `flutter test <file>` per task; the executor should run the full suite once at the end (some backup tests are flaky only in the full suite; rerun once before concluding a failure is real).
- Work in a dedicated git worktree; commit after each task.
- Current schema version constant: `AppDatabase.currentSchemaVersion` = 136 (`lib/core/database/database.dart:2849`). Never bump it in this plan.

---

### Task 1: Correct the Windows update-asset suffix

The GitHub updater's Windows suffix says `Windows.zip` but releases publish `Submersion-<tag>-Windows-Setup.exe` (`release.yml:955`). Dead code today (Windows uses WinSparkle), but it becomes live if engine selection ever changes, and Plan C builds on this provider.

**Files:**
- Modify: `lib/features/auto_update/presentation/providers/update_providers.dart:25`
- Test: `test/features/auto_update/data/services/github_update_service_test.dart`

**Interfaces:**
- Consumes: `GithubUpdateService(owner:, repo:, currentVersion:, platformSuffix:, httpClient:)` (existing).
- Produces: nothing new — a corrected constant.

- [ ] **Step 1: Add a Windows-suffix test against the real asset name**

In `test/features/auto_update/data/services/github_update_service_test.dart`, the local `makeRelease` helper builds a fixture asset list that includes `'Submersion-$tagName-Windows.zip'`. First, in that helper, rename the Windows asset entry to `'Submersion-$tagName-Windows-Setup.exe'` so the fixture matches what releases actually publish. Then add this test alongside the existing service tests (same `MockClient` pattern used by its neighbors):

```dart
    test('finds the Windows installer asset by its real suffix', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode(makeRelease(tagName: 'v9.9.9.999')),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      final service = GithubUpdateService(
        owner: 'submersion-app',
        repo: 'submersion',
        currentVersion: '1.0.0',
        platformSuffix: 'Windows-Setup.exe',
        httpClient: client,
      );

      final result = await service.checkForUpdate();

      expect(result, isA<UpdateAvailable>());
      expect(
        (result as UpdateAvailable).downloadUrl,
        endsWith('Windows-Setup.exe'),
      );
    });
```

The `makeRelease` helper takes `tagName` plus optional `assets`/`body`; keep the default assets. `UpdateAvailable.downloadUrl` is the verified field name (`lib/features/auto_update/domain/entities/update_status.dart:28`).

- [ ] **Step 2: Run the test file**

Run: `flutter test test/features/auto_update/data/services/github_update_service_test.dart`
Expected: the new test PASSES (the service is suffix-agnostic; this documents the contract). All existing tests still pass with the renamed fixture asset.

- [ ] **Step 3: Fix the provider constant**

In `lib/features/auto_update/presentation/providers/update_providers.dart`, change line 25:

```dart
  if (Platform.isWindows) return 'Windows.zip';
```

to:

```dart
  if (Platform.isWindows) return 'Windows-Setup.exe';
```

- [ ] **Step 4: Format, analyze, run the module's tests**

Run: `dart format . && flutter analyze && flutter test test/features/auto_update/`
Expected: no formatting diffs, clean analyze, all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auto_update/presentation/providers/update_providers.dart test/features/auto_update/data/services/github_update_service_test.dart
git commit -m "fix(auto-update): match the published Windows installer asset name"
```

---

### Task 2: Set the correct UPDATE_CHANNEL on store builds

Two store artifacts compile with the wrong channel: the Android App Bundle (Play) and the iOS ipa. The Mac App Store lane is already correct (`macos/fastlane/Fastfile:226` passes `UPDATE_CHANNEL=appstore`) — verify, do not change. Wrong channels are currently masked by the iOS/Android early-return in `UpdateChannelConfig.isAutoUpdateEnabled`, but the value must be right before channel-aware UI (Plan C) reads it.

**Files:**
- Modify: `.github/workflows/release.yml:529`
- Modify: `ios/fastlane/Fastfile:171`

**Interfaces:**
- Consumes: `UpdateChannelConfig` reads `String.fromEnvironment('UPDATE_CHANNEL')` (`lib/features/auto_update/domain/entities/update_channel.dart`); recognized values include `playstore` and `appstore`.
- Produces: correctly-stamped store binaries; no code interface.

- [ ] **Step 1: Fix the App Bundle build**

In `.github/workflows/release.yml`, change line 529:

```yaml
        run: flutter build appbundle --release --dart-define=HEALTH_CONNECT_ENABLED=false
```

to:

```yaml
        run: flutter build appbundle --release --dart-define=HEALTH_CONNECT_ENABLED=false --dart-define=UPDATE_CHANNEL=playstore
```

Leave line 526 (`flutter build apk ... UPDATE_CHANNEL=github`) alone — the sideloaded APK is genuinely the github channel.

- [ ] **Step 2: Fix the iOS build lane**

In `ios/fastlane/Fastfile`, inside `lane :build`, change line 171:

```ruby
    sh("cd ../.. && flutter build ios --release --no-codesign")
```

to:

```ruby
    sh("cd ../.. && flutter build ios --release --no-codesign --dart-define=UPDATE_CHANNEL=appstore")
```

- [ ] **Step 3: Verify all channel stamps across build configs**

Run: `grep -rn "UPDATE_CHANNEL" .github/workflows/release.yml ios/fastlane/Fastfile macos/fastlane/Fastfile`
Expected: dmg/exe/tar.gz/apk builds say `github`; appbundle says `playstore`; iOS lane and MAS lane (`macos/fastlane/Fastfile:226`) say `appstore`. No other build command lacks a stamp except debug/CI builds in `ci.yaml` (fine — they default to `github`).

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/release.yml ios/fastlane/Fastfile
git commit -m "fix(release): stamp store builds with their real update channel"
```

---

### Task 3: Characterization test — pre-migration backup is a no-op for newer databases

`PreMigrationBackupService.backupIfMigrationPending` early-returns when `stored >= target`. For `stored > target` (newer DB, the case the beta channel makes common) this is correct — the version guard throws before anything writes — but it is untested; pin it so a future refactor cannot start "backing up" (and thus touching) files it should leave alone.

**Files:**
- Test: `test/features/backup/data/services/pre_migration_backup_service_test.dart`

**Interfaces:**
- Consumes: the file's existing `_makeFixture()` helper and `PreMigrationBackupService` constructor seams (`livePathProvider`, `backupsDirProvider`, `preferences`, `clock`, `idGenerator`).
- Produces: nothing new — a pinned behavior.

- [ ] **Step 1: Add the test**

In the `PreMigrationBackupService happy path` group, directly after the existing `skips when stored == target (no-op)` test, add:

```dart
    test('skips when stored > target (newer database, no-op)', () async {
      final f = await _makeFixture();
      addTearDown(f.dispose);
      final service = PreMigrationBackupService(
        livePathProvider: () async => f.livePath,
        backupsDirProvider: () async => f.backupsDir,
        preferences: f.prefs,
        clock: () => DateTime.utc(2026, 7, 28),
        idGenerator: () => 'x',
      );

      // A database written by a newer app version: the startup version guard
      // rejects it before Drift opens, so no backup must be taken and the
      // file must not be touched.
      await service.backupIfMigrationPending(
        stored: 137,
        target: 136,
        appVersion: '1.8.0.5601',
      );

      expect(await Directory(f.backupsDir).list().isEmpty, isTrue);
      expect(f.prefs.getHistory(), isEmpty);
    });
```

- [ ] **Step 2: Run the test file**

Run: `flutter test test/features/backup/data/services/pre_migration_backup_service_test.dart`
Expected: PASS (characterization of existing behavior).

- [ ] **Step 3: Commit**

```bash
git add test/features/backup/data/services/pre_migration_backup_service_test.dart
git commit -m "test(backup): pin pre-migration backup no-op for newer databases"
```

---

### Task 4: Give the "Update Required" startup screen an exit

Today the newer-database screen (`startup_page.dart:692-728`) offers only Close. Add a "Download Latest Version" button and a line telling the user their pre-upgrade backup still exists. This screen will be hit by real users once beta databases circulate (restored backups, iCloud-synced files, channel switchers).

**Files:**
- Modify: `lib/core/presentation/pages/startup_page.dart` (imports + the `_isVersionMismatch` branch of `_buildErrorContent`)
- Test: `test/core/presentation/pages/startup_page_test.dart` (group `Error UI - version mismatch`, helper `_buildVersionMismatchError` at line 185)

**Interfaces:**
- Consumes: `url_launcher` (`pubspec.yaml:86`, `url_launcher: ^6.3.1`) with the codebase's standard call shape `launchUrl(uri, mode: LaunchMode.externalApplication)` (as in `settings_page.dart:66`).
- Produces: no new public API. New user-visible strings listed below verbatim.

- [ ] **Step 1: Write failing widget tests**

In `test/core/presentation/pages/startup_page_test.dart`, add to the `Error UI - version mismatch` group:

```dart
    testWidgets('offers a download link for the latest version', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildVersionMismatchError(dbVersion: 137, appVersion: 136),
      );
      await tester.pumpAndSettle();

      expect(find.text('Download Latest Version'), findsOneWidget);
    });

    testWidgets('mentions the pre-upgrade backup', (tester) async {
      await tester.pumpWidget(
        _buildVersionMismatchError(dbVersion: 137, appVersion: 136),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('backup taken before the upgrade'),
        findsOneWidget,
      );
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/presentation/pages/startup_page_test.dart`
Expected: the two new tests FAIL (`Download Latest Version` not found); all others pass.

- [ ] **Step 3: Implement the screen changes**

In `lib/core/presentation/pages/startup_page.dart`:

Add the import (keep the file's import grouping: dart, flutter, packages, local):

```dart
import 'package:url_launcher/url_launcher.dart';
```

Add a private helper near `_closeApp`:

```dart
  static final Uri _latestReleaseUri = Uri.parse(
    'https://github.com/submersion-app/submersion/releases/latest',
  );

  Future<void> _openLatestRelease() async {
    try {
      await launchUrl(_latestReleaseUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Leaving the user on this screen is the only safe fallback; the URL
      // is also shown in the surrounding text.
    }
  }
```

Then in the `_isVersionMismatch` branch, replace the block from the second `Text(` (the one that begins `'Please update Submersion to the latest version. '`) through the `FilledButton` with:

```dart
            Text(
              'Please update Submersion to the latest version. '
              'Your data is safe and has not been modified. A backup taken '
              'before the upgrade is also in your Backups folder and can be '
              'restored after updating.',
              style: TextStyle(fontSize: 14, color: subtitleColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _openLatestRelease,
              child: const Text('Download Latest Version'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _closeApp, child: const Text('Close')),
```

Note the existing test `shows safe data message` asserts `textContaining('Your data is safe and has not been modified')` — the merged sentence above preserves that substring. The existing `close button is tappable` test keeps passing because Close remains, now as a `TextButton`.

- [ ] **Step 4: Run the full startup-page test file**

Run: `flutter test test/core/presentation/pages/startup_page_test.dart`
Expected: PASS, including the four pre-existing version-mismatch tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/core/presentation/pages/startup_page.dart test/core/presentation/pages/startup_page_test.dart
git commit -m "feat(startup): add download and backup guidance to the update-required screen"
```

---

### Task 5: Add schemaVersion to SyncManifest

Sync payloads carry no database schema version today (`syncFormatVersion` is a wire-format constant, stuck at 2 across schema changes). The manifest is the gate point: it is read first, per peer, before any base or changeset download. Add an optional `schemaVersion` field. Legacy manifests (absent key) parse as `null`; old apps ignore the new key (their `fromJson` reads named keys only), so this is wire-compatible both directions.

**Files:**
- Modify: `lib/core/services/sync/changeset_log/sync_manifest.dart`
- Test: `test/core/services/sync/changeset_log/sync_manifest_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `SyncManifest.schemaVersion` (`int?`, constructor named parameter, default absent/null; serialized as JSON key `'schemaVersion'`). Tasks 6-7 depend on this exact name.

- [ ] **Step 1: Write failing round-trip tests**

In `test/core/services/sync/changeset_log/sync_manifest_test.dart`, add (follow the file's existing construction style — it builds manifests with `deviceId`, `provider`, `headSeq`, `updatedAt`):

```dart
  test('round-trips schemaVersion', () {
    final manifest = SyncManifest(
      deviceId: 'dev-1',
      provider: 'icloud',
      headSeq: 3,
      updatedAt: 1234,
      schemaVersion: 136,
    );

    final back = SyncManifest.fromJson(manifest.toJson());

    expect(back.schemaVersion, 136);
  });

  test('legacy manifest without schemaVersion parses as null', () {
    final back = SyncManifest.fromJson({
      'deviceId': 'dev-1',
      'provider': 'icloud',
      'headSeq': 3,
      'updatedAt': 1234,
    });

    expect(back.schemaVersion, isNull);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/sync/changeset_log/sync_manifest_test.dart`
Expected: FAIL — `schemaVersion` is not a defined named parameter.

- [ ] **Step 3: Implement the field**

In `lib/core/services/sync/changeset_log/sync_manifest.dart`:

Constructor — add after `this.formatVersion = 1,`:

```dart
    this.schemaVersion,
```

Fields — add after `final int formatVersion;`:

```dart
  /// The database schema version of the publishing device, used by readers to
  /// hold data from newer-schema peers rather than lossily merging it.
  /// Null on manifests written before this field existed.
  final int? schemaVersion;
```

`toJson()` — add after `'formatVersion': formatVersion,`:

```dart
    'schemaVersion': schemaVersion,
```

`fromJson` — add after the `formatVersion:` line:

```dart
    schemaVersion: json['schemaVersion'] as int?,
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/changeset_log/sync_manifest_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/sync/changeset_log/sync_manifest.dart test/core/services/sync/changeset_log/sync_manifest_test.dart
git commit -m "feat(sync): carry the publisher's schema version in the manifest"
```

---

### Task 6: Stamp schemaVersion at every manifest write

`ChangesetWriter` constructs manifests at four sites (`changeset_writer.dart:112` base publish, `:170` heartbeat, `:200` changeset publish, `:348` compaction). All four stamp the running app's schema version — including the heartbeat, which rewrites the manifest wholesale and must reflect the device's current schema, not a stale copy.

**Files:**
- Modify: `lib/core/services/sync/changeset_log/changeset_writer.dart` (4 sites + 1 import)
- Test: `test/core/services/sync/changeset_log/changeset_reader_schema_gate_test.dart` (new file, shared with Task 7)

**Interfaces:**
- Consumes: `SyncManifest.schemaVersion` (Task 5); `AppDatabase.currentSchemaVersion` (`lib/core/database/database.dart:2849`, static const, value 136).
- Produces: every published manifest carries `'schemaVersion': 136`.

- [ ] **Step 1: Create the failing test file**

Create `test/core/services/sync/changeset_log/changeset_reader_schema_gate_test.dart`. Copy the setup harness of `test/core/services/sync/changeset_log/changeset_reader_epoch_test.dart` verbatim (imports, `setUp`/`tearDown`, `spyApply`, `publishPeer`, `pull` — including the manifest-rewrite mechanics in `publishPeer`), add `import 'package:submersion/core/database/database.dart';`, then add this first test:

```dart
  test('published manifests are stamped with the schema version', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publishPeer('peer-1', epochId: 'epoch-A');

    final manifestFile = (await provider.listFiles(
      folderId: folder,
      namePattern: ChangesetLogLayout.manifestName('peer-1'),
    )).single;
    final manifest = SyncManifest.fromBytes(
      await provider.downloadFile(manifestFile.id),
    );

    expect(manifest.schemaVersion, AppDatabase.currentSchemaVersion);
  });
```

(Add `import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';` alongside the copied imports.)

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/services/sync/changeset_log/changeset_reader_schema_gate_test.dart`
Expected: FAIL — `manifest.schemaVersion` is null (writer does not stamp it yet).

- [ ] **Step 3: Stamp all four writer sites**

In `lib/core/services/sync/changeset_log/changeset_writer.dart`:

Add the import:

```dart
import 'package:submersion/core/database/database.dart';
```

At each of the four `SyncManifest(` constructions (lines 112, 170, 200, 348 pre-edit), add one argument alongside `updatedAt: now,`:

```dart
          schemaVersion: AppDatabase.currentSchemaVersion,
```

All four sites get the same literal line, including the heartbeat at :170 (do not copy `ownManifest.schemaVersion` there).

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/core/services/sync/changeset_log/changeset_reader_schema_gate_test.dart`
Expected: PASS. Also run `flutter test test/core/services/sync/changeset_log/` — the writer/reader/epoch suites must still pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/sync/changeset_log/changeset_writer.dart test/core/services/sync/changeset_log/changeset_reader_schema_gate_test.dart
git commit -m "feat(sync): stamp manifests with the publishing schema version"
```

---

### Task 7: Gate ingestion of newer-schema peers in ChangesetReader

The pull loop currently applies any epoch-matching peer. A peer publishing from a newer schema must be held — merging drops its new columns and this device would republish those rows without them. The gate mirrors the stale-epoch filter directly beneath it and reports held peers in a new result set. Placement matters: after `peerManifests.add` (GC still sees the peer) and before the cursor/base/changeset logic (nothing is fetched or advanced).

**Files:**
- Modify: `lib/core/services/sync/changeset_log/changeset_reader.dart`
- Test: `test/core/services/sync/changeset_log/changeset_reader_schema_gate_test.dart` (extends Task 6's file)

**Interfaces:**
- Consumes: `SyncManifest.schemaVersion` (Task 5); `AppDatabase.currentSchemaVersion`.
- Produces: `ChangesetReadResult.newerSchemaPeerDeviceIds` (`Set<String>`, default `{}`); `ChangesetReader.pull` gains named parameter `int localSchemaVersion = AppDatabase.currentSchemaVersion`. Task 8 depends on the result-set name.

- [ ] **Step 1: Write the failing gate tests**

Append to `changeset_reader_schema_gate_test.dart`. First extend the copied `publishPeer` helper with a `schemaVersionOverride` parameter, using the same download-mutate-reupload trick the epoch test uses for `manifestUpdatedAt`:

```dart
    if (schemaVersionOverride != null) {
      final manifestFile = (await provider.listFiles(
        folderId: folder,
        namePattern: ChangesetLogLayout.manifestName(peerId),
      )).single;
      final manifest =
          jsonDecode(utf8.decode(await provider.downloadFile(manifestFile.id)))
              as Map<String, dynamic>;
      manifest['schemaVersion'] = schemaVersionOverride;
      await provider.uploadFile(
        Uint8List.fromList(utf8.encode(jsonEncode(manifest))),
        manifestFile.name,
        folderId: folder,
      );
    }
```

(declared as `int? schemaVersionOverride` in the helper signature). Then add the tests:

```dart
  test('holds a peer publishing from a newer schema', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publishPeer(
      'peer-1',
      epochId: 'epoch-A',
      schemaVersionOverride: AppDatabase.currentSchemaVersion + 1,
    );

    final result = await pull(currentEpochId: 'epoch-A');

    expect(result.peersProcessed, 0);
    expect(result.newerSchemaPeerDeviceIds, {'peer-1'});
    expect(applied, isEmpty);
  });

  test('a held peer is fully applied after this device updates', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publishPeer(
      'peer-1',
      epochId: 'epoch-A',
      schemaVersionOverride: AppDatabase.currentSchemaVersion + 1,
    );
    await pull(currentEpochId: 'epoch-A'); // held: cursor must not advance

    final result = await reader.pull(
      provider: provider,
      selfDeviceId: 'reader-x',
      folderId: folder,
      apply: spyApply,
      applyBaseFile: spyApplyBaseFile(applied),
      currentEpochId: 'epoch-A',
      localSchemaVersion: AppDatabase.currentSchemaVersion + 1,
    );

    expect(result.peersProcessed, 1);
    expect(result.newerSchemaPeerDeviceIds, isEmpty);
    expect(applied, isNotEmpty);
  });

  test('same-schema and legacy (unstamped) peers apply normally', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    // publishPeer without override stamps the current schema version.
    await publishPeer('peer-same', epochId: 'epoch-A');

    final result = await pull(currentEpochId: 'epoch-A');

    expect(result.peersProcessed, 1);
    expect(result.newerSchemaPeerDeviceIds, isEmpty);
  });
```

The second test is the critical one: it proves the held peer's cursor did not advance, so its data is not lost — merely deferred until the device updates.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/core/services/sync/changeset_log/changeset_reader_schema_gate_test.dart`
Expected: the new tests FAIL (`newerSchemaPeerDeviceIds`/`localSchemaVersion` undefined).

- [ ] **Step 3: Implement the gate**

In `lib/core/services/sync/changeset_log/changeset_reader.dart`:

Add the import:

```dart
import 'package:submersion/core/database/database.dart';
```

Extend `ChangesetReadResult` — constructor gains `this.newerSchemaPeerDeviceIds = const {},` and, after the `skippedPeerDeviceIds` field, add:

```dart
  /// Peers held because their manifests were published from a newer database
  /// schema than this build understands. Merging them would silently drop the
  /// fields this build does not know and republish the rows without them.
  /// Their cursors are not advanced; the data applies after this device
  /// updates.
  final Set<String> newerSchemaPeerDeviceIds;
```

`pull(...)` signature — add after `String? currentEpochId,`:

```dart
    int localSchemaVersion = AppDatabase.currentSchemaVersion,
```

Local state — alongside `final skippedPeerDeviceIds = <String>{};` add:

```dart
    final newerSchemaPeerDeviceIds = <String>{};
```

The gate — insert between the stale-epoch filter's closing `}` (line 124 pre-edit) and `peersProcessed++;`:

```dart
        // Newer-schema filter: hold peers publishing from a newer database
        // schema. Applying them would silently drop the columns and tables
        // this build does not know, then republish those rows without them.
        // The cursor stays put, so the data applies once this device updates.
        final peerSchema = manifest.schemaVersion;
        if (peerSchema != null && peerSchema > localSchemaVersion) {
          newerSchemaPeerDeviceIds.add(peerId);
          continue;
        }
```

Return statement — add `newerSchemaPeerDeviceIds: newerSchemaPeerDeviceIds,` alongside `skippedPeerDeviceIds:`.

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/core/services/sync/changeset_log/changeset_reader_schema_gate_test.dart && flutter test test/core/services/sync/changeset_log/`
Expected: all PASS, including the epoch and verify suites.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/sync/changeset_log/changeset_reader.dart test/core/services/sync/changeset_log/changeset_reader_schema_gate_test.dart
git commit -m "feat(sync): hold peers publishing from a newer schema version"
```

---

### Task 8: Surface held peers through SyncResult and the sync message

Copy the `skippedPeerDeviceIds` plumbing one field over: `SyncResult` gains the set, and the user-facing message assembly in `performSync` explains it. To make the message unit-testable, the message-list assembly is extracted into a `@visibleForTesting` static.

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart` (SyncResult class ~line 55-82; message assembly ~line 607-643)
- Test: `test/core/services/sync/sync_result_messages_test.dart` (new)

**Interfaces:**
- Consumes: `ChangesetReadResult.newerSchemaPeerDeviceIds` (Task 7).
- Produces: `SyncResult.newerSchemaPeerDeviceIds` (`Set<String>`, default `{}`); `SyncService.pullResultMessages({required int recordsFailed, required Set<String> skippedPeerDeviceIds, required Set<String> newerSchemaPeerDeviceIds, required bool adoptedFreshIdentity}) -> List<String>` (static).

- [ ] **Step 1: Write the failing message tests**

Create `test/core/services/sync/sync_result_messages_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

void main() {
  test('reports peers running a newer version', () {
    final messages = SyncService.pullResultMessages(
      recordsFailed: 0,
      skippedPeerDeviceIds: const {},
      newerSchemaPeerDeviceIds: const {'peer-1', 'peer-2'},
      adoptedFreshIdentity: false,
    );

    expect(messages, hasLength(1));
    expect(messages.single, contains('2 devices run a newer version'));
    expect(messages.single, contains('Update this device'));
  });

  test('singular phrasing for one newer peer', () {
    final messages = SyncService.pullResultMessages(
      recordsFailed: 0,
      skippedPeerDeviceIds: const {},
      newerSchemaPeerDeviceIds: const {'peer-1'},
      adoptedFreshIdentity: false,
    );

    expect(messages.single, contains('1 device runs a newer version'));
  });

  test('failed records suppress peer messages (existing precedence)', () {
    final messages = SyncService.pullResultMessages(
      recordsFailed: 3,
      skippedPeerDeviceIds: const {'peer-1'},
      newerSchemaPeerDeviceIds: const {'peer-2'},
      adoptedFreshIdentity: false,
    );

    expect(messages.single, '3 records failed to apply');
  });

  test('stale-epoch and newer-schema peers both reported', () {
    final messages = SyncService.pullResultMessages(
      recordsFailed: 0,
      skippedPeerDeviceIds: const {'peer-1'},
      newerSchemaPeerDeviceIds: const {'peer-2'},
      adoptedFreshIdentity: false,
    );

    expect(messages, hasLength(2));
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/core/services/sync/sync_result_messages_test.dart`
Expected: FAIL — `pullResultMessages` undefined.

- [ ] **Step 3: Implement**

In `lib/core/services/sync/sync_service.dart`:

`SyncResult` — after the `skippedPeerDeviceIds` field's doc comment and declaration, add:

```dart
  /// Peers held because they publish from a newer database schema than this
  /// build understands. Their data applies after this device updates.
  final Set<String> newerSchemaPeerDeviceIds;
```

and in the constructor, after `this.skippedPeerDeviceIds = const {},`:

```dart
    this.newerSchemaPeerDeviceIds = const {},
```

Add the static message builder to `SyncService` (near `performSync`; the file already imports `package:flutter/foundation.dart` — if not, add it for `@visibleForTesting`):

```dart
  /// Builds the user-facing result messages for a completed pull. Extracted
  /// so the phrasing and precedence (failures suppress peer notices) are
  /// unit-testable without a full sync.
  @visibleForTesting
  static List<String> pullResultMessages({
    required int recordsFailed,
    required Set<String> skippedPeerDeviceIds,
    required Set<String> newerSchemaPeerDeviceIds,
    required bool adoptedFreshIdentity,
  }) {
    final resultMessages = <String>[];
    if (recordsFailed > 0) {
      final recordWord = recordsFailed == 1 ? 'record' : 'records';
      resultMessages.add('$recordsFailed $recordWord failed to apply');
      return resultMessages;
    }
    final skippedCount = skippedPeerDeviceIds.length;
    if (skippedCount > 0) {
      final deviceWord = skippedCount == 1 ? 'device' : 'devices';
      final verb = skippedCount == 1 ? 'has' : 'have';
      resultMessages.add(
        '$skippedCount $deviceWord still $verb an older or unknown '
        'library version and were not merged. Those devices must adopt '
        'the current library.',
      );
    }
    final newerCount = newerSchemaPeerDeviceIds.length;
    if (newerCount > 0) {
      final phrase = newerCount == 1 ? 'device runs' : 'devices run';
      resultMessages.add(
        '$newerCount $phrase a newer version of Submersion; their latest '
        'changes were not merged. Update this device to receive them.',
      );
    }
    if (adoptedFreshIdentity) {
      resultMessages.add(
        'Another device was syncing with this device\'s identity. '
        'This device adopted a new identity and merged the cloud data.',
      );
    }
    return resultMessages;
  }
```

Replace the inline assembly in `performSync` (the block from `final resultMessages = <String>[];` through the `if (adoptedFreshIdentity) { ... }` closing brace, currently lines 607-628) with:

```dart
      final resultMessages = pullResultMessages(
        recordsFailed: recordsFailed,
        skippedPeerDeviceIds: pullResult.skippedPeerDeviceIds,
        newerSchemaPeerDeviceIds: pullResult.newerSchemaPeerDeviceIds,
        adoptedFreshIdentity: adoptedFreshIdentity,
      );
```

and in the `SyncResult(` construction that follows (line ~632), add:

```dart
        newerSchemaPeerDeviceIds: pullResult.newerSchemaPeerDeviceIds,
```

- [ ] **Step 4: Run to verify**

Run: `flutter test test/core/services/sync/sync_result_messages_test.dart && flutter test test/core/services/sync/`
Expected: all PASS (the broader sync suite guards the refactored inline block).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/core/services/sync/sync_service.dart test/core/services/sync/sync_result_messages_test.dart
git commit -m "feat(sync): report peers held on a newer schema in sync results"
```

---

### Task 9: Full-suite verification

**Files:** none (verification only)

- [ ] **Step 1: Run the complete checks**

Run: `dart format . && flutter analyze && flutter test`
Expected: no formatting changes, zero analyze issues, full suite green. Known trap: a handful of backup tests are flaky only under the full suite — rerun the specific failing file in isolation once before treating a failure as caused by this work.

- [ ] **Step 2: Commit any stragglers**

If `dart format .` touched files, commit them:

```bash
git add -A && git commit -m "style: format"
```

---

## Deferred (deliberately out of scope for Phase 0)

- A `SyncState` flag + settings banner for "peer requires update" — rides with Plan C (channel UI), where the sync-settings surface is already being modified. The message string reaches the UI today via the existing `result.message` pipeline.
- Version gates on restore/adopt flows outside the changeset pull loop (wizard restore, `exportData` payloads). The manifest gate covers both bases and changesets inside the pull loop, which is the cross-channel path the beta channel creates.
- Localizing startup-page strings (whole page is pre-l10n English today).
