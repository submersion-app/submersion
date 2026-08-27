# Sync Upgrade-Path Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make enabling multi-device sync safe for users upgrading from any released build: legacy cloud payloads merge instead of being silently rejected, stale cloud files get cleaned up instead of becoming resurrection sources, cloned ("twin") device identities are detected and auto-healed, and the first library-combining sync requires explicit confirmation.

**Architecture:** All changes live in the existing sync subsystem: `SyncDataSerializer` (payload envelope), `SyncService` (merge/upload pipeline), `SyncRepository` (reset semantics), `SyncInitializer` (identity anchors in SharedPreferences), `SyncNotifier`/`SyncState` (UI-facing state), and `CloudSyncPage`. No schema migration is needed — the new twin-detection nonce rides in the JSON envelope and SharedPreferences.

**Tech Stack:** Flutter/Dart, Drift (SQLite), Riverpod, SharedPreferences, crypto (SHA-256), uuid. Tests use the in-memory test database (`setUpTestDatabase()`), `FakeCloudStorageProvider`, and `SharedPreferences.setMockInitialValues`.

**Branch:** `fix/sync-upgrade-path` (off `origin/main`, includes PR #313 S3 backend and PR #315 fresh-identity reset).

---

## Verified context (why each task exists)

1. **Legacy payloads are silently rejected.** `validateChecksum` (`lib/core/services/sync/sync_data_serializer.dart:520-524`) re-encodes `payload.data.toJson()` with the CURRENT 39-key `SyncData`, but every released build (≤ v1.4.9.95) wrote checksums over its 32-key shape. SHA-256 never matches, so `performSync` discards every legacy file at `lib/core/services/sync/sync_service.dart:337-340` with only a log warning. The envelope's `version` field is never checked anywhere.
2. **Stale cloud files are immortal.** Nothing deletes the legacy `submersion_sync.json` after merge, nor the old `submersion_sync_<oldId>.json` after Reset Sync State adopts a fresh identity. A stale file holding a live copy of a deleted row re-inserts it once no local tombstone matches (merge short-circuits on `localUpdatedAt == null` at `sync_service.dart:1087-1090`); tombstones are pruned at 90 days and `SyncRepository.resetSyncState` (`lib/core/data/repositories/sync_repository.dart:778-803`) wipes them entirely.
3. **Twins are undetectable.** OS-level migration (iPhone transfer, Migration Assistant, iCloud device backup) clones DB + prefs together, so both installs pass `reconcileDeviceIdentity` as `unchanged` and sync as the same device id — each excludes the shared file as "its own", sees zero peers, and silently overwrites the other. The envelope carries no per-install discriminator and nothing inspects one's own cloud file.
4. **First contact merges without warning.** Sync Now / auto-sync immediately bidirectionally merges full libraries. Merge identity is row-UUID only, so independently imported libraries duplicate silently.

Uploads are **full snapshots** (`since: null` at `sync_service.dart:379`), which is what makes deleting stale cloud files safe: any live device recreates its file on its next sync.

Key prior art for tests: `test/core/services/sync/sync_per_device_files_test.dart` (craftDeviceFile/validDiveMap pattern), `test/core/services/sync/sync_initializer_reconcile_test.dart` (SharedPreferences mock + ProviderContainer pattern), `test/helpers/fake_cloud_storage_provider.dart`, `test/helpers/test_database.dart` (`setUpTestDatabase`, `createTestDiveWithBottomTime`), `test/helpers/sync_test_helpers.dart`.

Commit messages: no Co-Authored-By lines. Run `dart format lib/ test/` before each commit.

---

### Task 1: Validate checksums over the writer's encoding + future-version guard

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (SyncPayload class ~line 78-140; `validateChecksum` ~line 520)
- Modify: `lib/core/services/sync/sync_service.dart` (download loop ~line 323-358)
- Test: `test/core/services/sync/sync_legacy_payload_compat_test.dart` (new)

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/sync/sync_legacy_payload_compat_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// The exact `SyncData.toJson` key set of the last released build
/// (v1.4.9.95). Released builds computed their payload checksum over a JSON
/// document containing ONLY these 32 keys, so accepting their files means
/// validating against the writer's encoding, not this build's.
const legacySyncDataKeys = [
  'divers', 'diverSettings', 'dives', 'diveProfiles', 'diveTanks',
  'diveEquipment', 'diveWeights', 'diveSites', 'equipment', 'equipmentSets',
  'equipmentSetItems', 'media', 'buddies', 'diveBuddies', 'certifications',
  'serviceRecords', 'diveCenters', 'trips', 'liveaboardDetails',
  'itineraryDays', 'tags', 'diveTags', 'diveTypes', 'tankPresets',
  'diveComputers', 'tankPressureProfiles', 'tideRecords', 'settings',
  'species', 'sightings', 'diveProfileEvents', 'gasSwitches',
];

/// Serialize a payload exactly the way a released (pre-per-device-expansion)
/// build did: 32 data keys, checksum over that 32-key document, hand-built
/// envelope with no fields this build may have added since.
Uint8List craftLegacyFile(
  String deviceId,
  List<Map<String, dynamic>> dives, {
  int version = 2,
}) {
  final dataMap = <String, dynamic>{
    for (final key in legacySyncDataKeys) key: <Map<String, dynamic>>[],
  };
  dataMap['dives'] = dives;
  final checksum = sha256.convert(utf8.encode(jsonEncode(dataMap))).toString();
  final envelope = <String, dynamic>{
    'version': version,
    'exportedAt': 1700000000000,
    'deviceId': deviceId,
    'lastSyncTimestamp': null,
    'checksum': checksum,
    'data': dataMap,
    'deletions': <String, dynamic>{},
  };
  return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCloudStorageProvider cloud;

  setUp(() async {
    await setUpTestDatabase();
    cloud = FakeCloudStorageProvider();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  SyncService buildService() => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
  );

  /// A valid dive JSON map (as produced by export) with the given id.
  /// Mirrors sync_per_device_files_test.dart.
  Future<Map<String, dynamic>> validDiveMap(String id) async {
    final diveRepo = DiveRepository();
    await diveRepo.createDive(createTestDiveWithBottomTime(id: id));
    final exported = await SyncDataSerializer().exportData(
      deviceId: 'seed',
      deletions: const [],
    );
    final map = exported.data.dives.firstWhere((d) => d['id'] == id);
    await diveRepo.deleteDive(id);
    await SyncRepository().resetSyncState();
    return map;
  }

  group('legacy payload compatibility', () {
    test('validateChecksum accepts a 32-key legacy payload', () async {
      final dive = await validDiveMap('legacy-dive-1');
      final bytes = craftLegacyFile('legacy-device', [dive]);

      final payload = SyncDataSerializer().deserializePayload(
        utf8.decode(bytes),
      );

      expect(
        SyncDataSerializer().validateChecksum(payload),
        isTrue,
        reason:
            'the checksum must be validated against the writer\'s own '
            'encoding (32 keys), not this build\'s re-serialization (39 keys)',
      );
    });

    test('performSync merges a legacy shared file end to end', () async {
      final dive = await validDiveMap('legacy-dive-2');
      cloud.seedFile('submersion_sync.json', craftLegacyFile('old-phone', [
        dive,
      ]));

      final result = await buildService().performSync();

      expect(result.isSuccess, isTrue);
      final merged = await DiveRepository().getDiveById('legacy-dive-2');
      expect(
        merged,
        isNotNull,
        reason: 'the legacy file\'s dive must arrive in the local database',
      );
    });

    test('rejects a tampered legacy payload', () async {
      final dive = await validDiveMap('legacy-dive-3');
      final bytes = craftLegacyFile('legacy-device', [dive]);
      // Flip the dive's id after the checksum was computed.
      final doc =
          jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      ((doc['data'] as Map<String, dynamic>)['dives'] as List).first['id'] =
          'tampered';
      final payload = SyncDataSerializer().deserializePayload(
        jsonEncode(doc),
      );

      expect(SyncDataSerializer().validateChecksum(payload), isFalse);
    });

    test('skips payloads from a newer format version', () async {
      final dive = await validDiveMap('future-dive');
      cloud.seedFile(
        'submersion_sync_future-device.json',
        craftLegacyFile('future-device', [dive], version: syncFormatVersion + 1),
      );

      final result = await buildService().performSync();

      expect(result.isSuccess, isTrue);
      expect(
        await DiveRepository().getDiveById('future-dive'),
        isNull,
        reason:
            'a payload written by a NEWER format must be skipped, not '
            'half-applied with undefined semantics',
      );
    });
  });
}
```

Also add the `seedFile` helper to `test/helpers/fake_cloud_storage_provider.dart` (after `syncFileBytes()`):

```dart
  /// Seed a file as though another device had uploaded it.
  void seedFile(String name, Uint8List data) {
    _files[name] = _FakeFile(data, DateTime.now());
  }
```

Note: if `DiveRepository` has no `getDiveById`, check `dive_repository_impl.dart` for the actual single-dive getter name (`getDive`, `getDiveById`, ...) and use that; same for `createDive`/`deleteDive` which are known-good from `sync_per_device_files_test.dart`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/services/sync/sync_legacy_payload_compat_test.dart`
Expected: 'validateChecksum accepts a 32-key legacy payload', 'performSync merges a legacy shared file end to end' FAIL (checksum mismatch). 'rejects a tampered legacy payload' may pass already. 'skips payloads from a newer format version' FAILS only if the dive merges — with the current code the checksum gate rejects it for the wrong reason, so it may pass vacuously; that is fine, it locks in the behavior.

- [ ] **Step 3: Implement — carry the raw data JSON through SyncPayload**

In `lib/core/services/sync/sync_data_serializer.dart`, change the `SyncPayload` field block and constructor (fields are at ~line 80-96) to:

```dart
  final int version;
  final int exportedAt;
  final String deviceId;
  final int? lastSyncTimestamp;
  final String checksum;
  final SyncData data;
  final Map<String, List<SyncDeletion>> deletions;

  /// The `data` section exactly as it appeared in the received document,
  /// re-encoded from the decoded map (Dart maps preserve key order, and the
  /// writer used compact jsonEncode, so this reproduces the writer's bytes).
  /// Checksums must be verified against the WRITER's encoding: re-serializing
  /// through this build's [SyncData.toJson] adds entity keys older builds
  /// never wrote, which made every released build's payload "invalid".
  /// Null for locally constructed payloads (export path).
  final String? rawDataJson;

  const SyncPayload({
    required this.version,
    required this.exportedAt,
    required this.deviceId,
    this.lastSyncTimestamp,
    required this.checksum,
    required this.data,
    required this.deletions,
    this.rawDataJson,
  });
```

In `SyncPayload.fromJson` add the field to the returned object (inside the existing `return SyncPayload(...)`):

```dart
      rawDataJson: json['data'] == null ? null : jsonEncode(json['data']),
```

(`dart:convert` is already imported.) Do NOT add `rawDataJson` to `toJson()` — it is read-side state only.

Then change `validateChecksum` (~line 520):

```dart
  /// Validate checksum of payload.
  ///
  /// Verified over the data section as received ([SyncPayload.rawDataJson])
  /// so payloads written by builds with fewer/more entity keys still
  /// validate; falls back to re-serializing for locally built payloads.
  bool validateChecksum(SyncPayload payload) {
    final dataJson = payload.rawDataJson ?? jsonEncode(payload.data.toJson());
    final computed = _computeChecksum(dataJson);
    return computed == payload.checksum;
  }
```

- [ ] **Step 4: Implement — extract `_downloadAndParsePayload` with the version guard**

In `lib/core/services/sync/sync_service.dart`, replace the body of the download loop (~lines 323-358). Current code downloads/parses/validates inline; replace with:

```dart
      for (final file in remoteFiles) {
        // NOTE: we intentionally do NOT skip files by their cloud
        // modifiedTime. iCloud Drive can fail to advance that metadata after a
        // conflict-copy merge, which would silently skip a file containing new
        // records; and skipping a file whose record failed to apply once would
        // drop it forever. Re-applying is idempotent (upsert + HLC), so we
        // always download and merge every foreign file.
        final payload = await _downloadAndParsePayload(provider, file);
        if (payload == null) {
          continue;
        }

        // Skip our own data by payload identity (covers a legacy shared file
        // or an iCloud conflict-copy this device authored) -- applying it to
        // ourselves is a no-op that only inflates counts.
        if (payload.deviceId == deviceId) {
          continue;
        }

        final mergeResult = await _withStep(
          'apply remote data',
          () => _applyRemotePayload(payload, lastSyncTime),
        );
        recordsSynced += mergeResult.recordsApplied;
        conflictsFound += mergeResult.conflictsFound;
        recordsFailed += mergeResult.recordsFailed;
      }
```

And add the helper next to `_decodePayloadBytes` (~line 540):

```dart
  /// Download and parse one remote sync file. Returns null (after logging)
  /// when the file cannot be fetched, fails checksum validation, or was
  /// written by a NEWER format version than this build understands --
  /// applying a future format would have undefined semantics, so it is
  /// skipped until the app is updated.
  Future<SyncPayload?> _downloadAndParsePayload(
    CloudStorageProvider provider,
    CloudFileInfo file,
  ) async {
    try {
      final remoteData = await provider
          .downloadFile(file.id)
          .timeout(const Duration(seconds: 15));
      final remoteJson = _decodePayloadBytes(remoteData);
      final parsed = _serializer.deserializePayload(remoteJson);
      if (parsed.version > syncFormatVersion) {
        _log.warning(
          'Remote sync file ${file.name} uses format v${parsed.version} '
          '(this build understands v$syncFormatVersion); update the app on '
          'this device to merge it',
        );
        return null;
      }
      if (!_serializer.validateChecksum(parsed)) {
        _log.warning('Remote sync file ${file.name} has invalid checksum');
        return null;
      }
      return parsed;
    } on TimeoutException {
      _log.warning('Timed out downloading ${file.name}');
      return null;
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to download/parse ${file.name}: $e',
        stackTrace: stackTrace,
      );
      return null;
    }
  }
```

- [ ] **Step 5: Run the new tests + the sync suite**

Run: `flutter test test/core/services/sync/sync_legacy_payload_compat_test.dart`
Expected: all 4 PASS.
Run: `flutter test test/core/services/sync`
Expected: all pass (existing round-trip tests exercise the fallback path of `validateChecksum`).

- [ ] **Step 6: Format and commit**

```bash
dart format lib/ test/
git add -A
git commit -m "fix(sync): validate payload checksums over the writer's encoding

Released builds (<= v1.4.9.95) computed checksums over their 32-key
SyncData document; validateChecksum re-encoded with the current 39-key
shape, so every legacy cloud payload was silently rejected on every
sync. Validate against the data section as received instead, and skip
payloads from a NEWER format version explicitly."
```

---

### Task 2: Remove the legacy shared sync file after merging it

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart` (download loop from Task 1; post-upload section ~line 428-455)
- Test: `test/core/services/sync/sync_legacy_payload_compat_test.dart` (extend)

- [ ] **Step 1: Write the failing tests**

Append to the `legacy payload compatibility` group:

```dart
    test('deletes the legacy shared file after merging it', () async {
      final dive = await validDiveMap('legacy-dive-4');
      cloud.seedFile('submersion_sync.json', craftLegacyFile('old-phone', [
        dive,
      ]));

      final result = await buildService().performSync();

      expect(result.isSuccess, isTrue);
      expect(
        await cloud.fileExists('submersion_sync.json'),
        isFalse,
        reason:
            'after its data is merged (and re-exported into our per-device '
            'file) the legacy shared file must be cleaned up -- left in '
            'place it is re-merged forever and resurrects deletions once '
            'their tombstones age out. A still-active old device recreates '
            'it on its next sync (uploads are full snapshots), so nothing '
            'is lost.',
      );
    });

    test('deletes a legacy file this device itself authored', () async {
      // Single-device upgrader: the canonical file was written by THIS
      // device before the upgrade. It is skipped as own data but must
      // still be cleaned up.
      final deviceId = await SyncRepository().getDeviceId();
      cloud.seedFile('submersion_sync.json', craftLegacyFile(deviceId, []));

      final result = await buildService().performSync();

      expect(result.isSuccess, isTrue);
      expect(await cloud.fileExists('submersion_sync.json'), isFalse);
    });

    test('keeps a legacy-named file it could not parse', () async {
      cloud.seedFile(
        'submersion_sync.json',
        Uint8List.fromList(utf8.encode('not json at all')),
      );

      final result = await buildService().performSync();

      expect(result.isSuccess, isTrue);
      expect(
        await cloud.fileExists('submersion_sync.json'),
        isTrue,
        reason:
            'an unparseable file was NOT merged; deleting it would discard '
            'data sight-unseen',
      );
    });
```

- [ ] **Step 2: Run to verify the first two fail**

Run: `flutter test test/core/services/sync/sync_legacy_payload_compat_test.dart`
Expected: 'deletes the legacy shared file after merging it' and 'deletes a legacy file this device itself authored' FAIL (file still exists); 'keeps a legacy-named file it could not parse' PASSES.

- [ ] **Step 3: Implement legacy-file tracking + post-success deletion**

In `performSync` in `lib/core/services/sync/sync_service.dart`, declare alongside the merge counters (`var recordsSynced = 0;` etc.):

```dart
      CloudFileInfo? mergedLegacyFile;
```

In the download loop from Task 1, right after the null-check of `payload` (i.e. once the file parsed and validated), add:

```dart
        if (file.name == CloudStorageProviderMixin.canonicalSyncFileName) {
          // Parsed fine: its content is either our own pre-upgrade upload or
          // about to be merged below. Either way it is fully represented by
          // the per-device file we upload at the end of this sync, so it can
          // be retired afterwards.
          mergedLegacyFile = file;
        }
```

(This must come BEFORE the `payload.deviceId == deviceId` skip so an own-authored legacy file is also retired.)

After the `if (recordsFailed == 0) { ... updateLastSyncTime ... }` block (~line 428-433), add:

```dart
      // Retire the legacy shared sync file once its content is merged and
      // re-published in this device's per-device file. Only when every record
      // applied: a failed apply relies on re-pulling the same file next sync.
      // Best-effort -- a still-active pre-per-device build recreates the file
      // on its next sync (uploads are full snapshots), so deletion never
      // loses data.
      if (recordsFailed == 0 && mergedLegacyFile != null) {
        try {
          await provider
              .deleteFile(mergedLegacyFile.id)
              .timeout(const Duration(seconds: 8));
          _log.info('Retired legacy shared sync file after merging it');
        } catch (e) {
          _log.warning('Could not retire legacy sync file: $e');
        }
      }
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/core/services/sync/sync_legacy_payload_compat_test.dart`
Expected: all PASS.
Run: `flutter test test/core/services/sync`
Expected: all pass.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/ test/
git add -A
git commit -m "fix(sync): retire the legacy shared sync file after merging it

The legacy submersion_sync.json was listed, downloaded, and merged on
every sync forever; as a frozen full snapshot it re-resurrects any
record deleted after the upgrade once the deletion's tombstone ages
out (90 days) or is cleared. Uploads are full snapshots, so a
still-active old device recreates the file on its next sync and
nothing is lost."
```

---

### Task 3: Reset hardening — keep tombstones, retire the old device file, honest dialog copy

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart` (`resetSyncState` ~line 778)
- Modify: `lib/core/services/sync/sync_service.dart` (`resetSyncState` ~line 1287; new `deleteDeviceSyncFile`)
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (`SyncNotifier.resetSyncState` ~line 336)
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart` (dialog ~line 748-753)
- Test: `test/core/services/sync/sync_reset_hardening_test.dart` (new)
- Modify: `test/helpers/fake_cloud_storage_provider.dart` (add `failDeletes`)

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/sync/sync_reset_hardening_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    repository = SyncRepository();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  group('reset and the deletion log', () {
    test('user-facing reset keeps the deletion log', () async {
      await repository.logDeletion(entityType: 'dives', recordId: 'gone-1');
      final service = SyncService(
        syncRepository: repository,
        serializer: SyncDataSerializer(),
      );

      await service.resetSyncState();

      expect(
        await repository.getAllDeletions(),
        isNotEmpty,
        reason:
            'reset wipes the sync baseline, not data history: without the '
            'tombstones, the first post-reset sync re-inserts every record '
            'a stale peer file still holds live',
      );
      expect(await repository.getLastSyncTime(), isNull);
    });

    test('repository reset clears the deletion log by default', () async {
      // rebaselineAfterRestore and impersonateFreshDevice rely on the
      // historical full-wipe semantics.
      await repository.logDeletion(entityType: 'dives', recordId: 'gone-2');

      await repository.resetSyncState();

      expect(await repository.getAllDeletions(), isEmpty);
    });
  });

  group('SyncNotifier.resetSyncState cloud cleanup', () {
    test('retires the old per-device file when adopting a new identity',
        () async {
      final cloud = FakeCloudStorageProvider();
      final oldId = await repository.getDeviceId();
      final oldFile = 'submersion_sync_$oldId.json';
      cloud.seedFile(oldFile, Uint8List.fromList([1, 2, 3]));

      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          cloudStorageProviderProvider.overrideWithValue(cloud),
        ],
      );
      addTearDown(container.dispose);

      await container.read(syncStateProvider.notifier).resetSyncState();

      expect(await repository.getDeviceId(), isNot(oldId));
      expect(
        await cloud.fileExists(oldFile),
        isFalse,
        reason:
            'after the identity changes, the old file is no longer excluded '
            'as "our own" -- left in place this device would merge its own '
            'abandoned snapshot as a peer forever',
      );
    });

    test('reset succeeds even when the cloud delete fails', () async {
      final cloud = FakeCloudStorageProvider()..failDeletes = true;
      final oldId = await repository.getDeviceId();
      cloud.seedFile(
        'submersion_sync_$oldId.json',
        Uint8List.fromList([1, 2, 3]),
      );

      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          cloudStorageProviderProvider.overrideWithValue(cloud),
        ],
      );
      addTearDown(container.dispose);

      await container.read(syncStateProvider.notifier).resetSyncState();

      expect(
        await repository.getDeviceId(),
        isNot(oldId),
        reason: 'cloud cleanup is best-effort; reset must not depend on it',
      );
    });
  });
}
```

Add `dart:typed_data` import (`import 'dart:typed_data';`) at the top for `Uint8List`.

Add to `test/helpers/fake_cloud_storage_provider.dart`:

```dart
  /// When true, [deleteFile] throws, modelling an offline/denied provider.
  bool failDeletes = false;
```

and change `deleteFile`:

```dart
  @override
  Future<void> deleteFile(String fileId) async {
    if (failDeletes) {
      throw CloudStorageException('delete failed (test)');
    }
    _files.remove(fileId);
  }
```

- [ ] **Step 2: Run to verify failures**

Run: `flutter test test/core/services/sync/sync_reset_hardening_test.dart`
Expected: 'user-facing reset keeps the deletion log' FAILS (log cleared); 'retires the old per-device file' FAILS (file still there); the other two pass.

- [ ] **Step 3: Implement repository + service changes**

`lib/core/data/repositories/sync_repository.dart` — give `resetSyncState` an opt-out (~line 778):

```dart
  /// Reset sync state (useful for testing or switching accounts).
  ///
  /// [clearDeletionLog] defaults to the historical full wipe (used by
  /// [rebaselineAfterRestore], where the restored log is the backup's stale
  /// snapshot). The user-facing Reset Sync State passes false: tombstones are
  /// data history, and wiping them lets any stale peer file re-insert every
  /// record deleted since that file was written.
  Future<void> resetSyncState({bool clearDeletionLog = true}) async {
    try {
      await clearAllSyncRecords();
      if (clearDeletionLog) {
        await clearAllDeletions();
      }
      // ... (rest of the existing body unchanged)
```

`lib/core/services/sync/sync_service.dart` — user-facing reset keeps tombstones (~line 1287):

```dart
  /// Reset sync state (for debugging or account changes).
  ///
  /// Keeps the deletion log: this reset is the user-facing recovery path,
  /// and the next sync after it runs with a null baseline, where a wiped
  /// log would let stale peer files resurrect every deleted record.
  Future<void> resetSyncState() async {
    await _syncRepository.resetSyncState(clearDeletionLog: false);
    _log.info('Sync state reset');
  }
```

Add to `SyncService` (next to `signOut`):

```dart
  /// Best-effort removal of [deviceId]'s per-device sync file from the
  /// cloud. Used when this install retires an identity (Reset Sync State):
  /// once the device id changes, its old file would otherwise be merged
  /// back as a "peer" forever. Never throws; if the provider is offline the
  /// file simply lingers until a future cleanup.
  Future<void> deleteDeviceSyncFile(String deviceId) async {
    final provider = _cloudProvider;
    if (provider == null) return;
    try {
      final filename = _deviceSyncFileName(deviceId);
      final files = await provider
          .listFiles(namePattern: CloudStorageProviderMixin.syncFileStem)
          .timeout(const Duration(seconds: 8));
      for (final f in files) {
        if (f.name == filename) {
          await provider.deleteFile(f.id).timeout(const Duration(seconds: 8));
          _log.info('Retired per-device sync file $filename');
        }
      }
    } catch (e) {
      _log.warning('Could not retire sync file for $deviceId: $e');
    }
  }
```

`lib/features/settings/presentation/providers/sync_providers.dart` — `SyncNotifier.resetSyncState` (~line 336):

```dart
  /// Reset sync state
  ///
  /// Also adopts a brand-new device identity. Reset is the user-facing
  /// recovery for sync gone wrong, and the worst such state -- two installs
  /// syncing as the same device after cross-device restores -- is only
  /// fixable with a fresh identity. Restore detection deliberately preserves
  /// the anchored identity, so a clone survives everything short of this.
  /// The retired identity's cloud file is removed best-effort: after the id
  /// changes it would otherwise be merged back as a stale "peer" forever.
  Future<void> resetSyncState() async {
    final oldDeviceId = await _syncRepository.getDeviceId();
    await _syncService.resetSyncState();
    await _ref.read(syncInitializerProvider).adoptFreshIdentity();
    await _syncService.deleteDeviceSyncFile(oldDeviceId);
    await refreshState();
  }
```

- [ ] **Step 4: Update the dialog copy**

`lib/features/settings/presentation/pages/cloud_sync_page.dart` (~line 749-753), replace the content string:

```dart
        content: const Text(
          'This will clear sync history and give this device a new '
          'sync identity. Your data is not deleted, and the record of '
          'past deletions is kept so deleted items do not come back.',
        ),
```

Check `test/features/settings/presentation/pages/cloud_sync_page_test.dart` for assertions on the old dialog text (`grep -n "resolve conflicts" test/features/settings/presentation/pages/cloud_sync_page_test.dart`) and update any match to the new copy.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/core/services/sync/sync_reset_hardening_test.dart test/core/services/sync/sync_initializer_reconcile_test.dart`
Expected: all PASS (the reconcile test's rebaseline expectations still hold — repository default is unchanged).
Run: `flutter test test/core/services/sync test/features/settings/presentation/pages/cloud_sync_page_test.dart`
Expected: all pass.

- [ ] **Step 6: Format and commit**

```bash
dart format lib/ test/
git add -A
git commit -m "fix(sync): reset keeps tombstones and retires the old device file

Reset Sync State is the prescribed twin-identity recovery, which made
its two side effects dangerous: it wiped the deletion log right before
a null-baseline merge of every stale cloud file (re-inserting each
record deleted since), and adopting a fresh identity orphaned the old
per-device file, which this device would then merge back as a 'peer'
forever. Keep the log on user-facing reset, best-effort delete the
retired file, and make the confirmation dialog say what happens."
```

---

### Task 4: Twin-identity detection via per-upload nonces, with automatic fresh identity

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (SyncPayload + exportData)
- Modify: `lib/core/services/sync/sync_initializer.dart` (nonce bookkeeping)
- Modify: `lib/core/services/sync/sync_service.dart` (constructor, performSync, SyncResult)
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (`syncServiceProvider`)
- Test: `test/core/services/sync/sync_twin_identity_test.dart` (new)

**Detection model:** every upload embeds a fresh `uploadNonce` (uuid) in the envelope; the install records its own recent nonces in SharedPreferences. At sync time the service inspects its OWN cloud file: a nonce it never minted means another install is writing as this device id. A nonce-less own file means a pre-nonce build wrote it (this device, pre-upgrade) — never foreign. Prefs (not the DB) hold the recorded nonces so a database restore cannot trigger a false positive; an OS-migration clone copies prefs too, but the twins diverge at their first post-clone uploads and the second one to sync detects the first one's nonce. On detection the service adopts a fresh identity mid-sync and continues: the previously-shared file now counts as a peer and is merged in the same pass, so the twins converge immediately.

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/sync/sync_twin_identity_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCloudStorageProvider cloud;
  late SyncRepository repository;
  late SyncInitializer initializer;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    cloud = FakeCloudStorageProvider();
    repository = SyncRepository();
    initializer = SyncInitializer(
      syncRepository: repository,
      prefs: await SharedPreferences.getInstance(),
    );
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  SyncService buildService() => SyncService(
    syncRepository: repository,
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
    syncInitializer: initializer,
  );

  /// Craft a current-format payload file with an explicit upload nonce.
  Future<Uint8List> craftFile(
    String deviceId, {
    List<Map<String, dynamic>> dives = const [],
    String? uploadNonce,
  }) async {
    final data = SyncData(dives: dives);
    final checksum = sha256
        .convert(utf8.encode(jsonEncode(data.toJson())))
        .toString();
    final payload = SyncPayload(
      version: syncFormatVersion,
      exportedAt: 1700000000000,
      deviceId: deviceId,
      checksum: checksum,
      data: data,
      deletions: const {},
      uploadNonce: uploadNonce,
    );
    return Uint8List.fromList(
      utf8.encode(SyncDataSerializer().serializePayload(payload)),
    );
  }

  Future<Map<String, dynamic>> validDiveMap(String id) async {
    final diveRepo = DiveRepository();
    await diveRepo.createDive(createTestDiveWithBottomTime(id: id));
    final exported = await SyncDataSerializer().exportData(
      deviceId: 'seed',
      deletions: const [],
    );
    final map = exported.data.dives.firstWhere((d) => d['id'] == id);
    await diveRepo.deleteDive(id);
    await SyncRepository().resetSyncState();
    return map;
  }

  group('uploadNonce envelope round trip', () {
    test('serializes and parses the nonce; absent key reads as null', () {
      final serializer = SyncDataSerializer();
      final payload = SyncPayload(
        version: syncFormatVersion,
        exportedAt: 1,
        deviceId: 'd',
        checksum: 'c',
        data: const SyncData(),
        deletions: const {},
        uploadNonce: 'nonce-1',
      );

      final parsed = serializer.deserializePayload(
        serializer.serializePayload(payload),
      );
      expect(parsed.uploadNonce, 'nonce-1');

      final legacy = serializer.deserializePayload(
        jsonEncode({
          'version': 2,
          'exportedAt': 1,
          'deviceId': 'd',
          'checksum': 'c',
          'data': const SyncData().toJson(),
          'deletions': <String, dynamic>{},
        }),
      );
      expect(legacy.uploadNonce, isNull);
    });
  });

  group('twin detection', () {
    test('adopts a fresh identity when own file carries a foreign nonce',
        () async {
      final deviceId = await repository.getDeviceId();
      final twinDive = await validDiveMap('twin-dive-1');
      cloud.seedFile(
        'submersion_sync_$deviceId.json',
        await craftFile(
          deviceId,
          dives: [twinDive],
          uploadNonce: 'minted-by-the-other-twin',
        ),
      );

      final result = await buildService().performSync();

      expect(result.isSuccess, isTrue);
      expect(result.adoptedFreshIdentity, isTrue);
      final newId = await repository.getDeviceId();
      expect(newId, isNot(deviceId), reason: 'the twins must be split');
      expect(
        await DiveRepository().getDiveById('twin-dive-1'),
        isNotNull,
        reason:
            'the shared file now counts as a peer and is merged in the '
            'same pass, converging the twins immediately',
      );
      expect(
        await cloud.fileExists('submersion_sync_$newId.json'),
        isTrue,
        reason: 'the sync continues under the new identity',
      );
      expect(
        await cloud.fileExists('submersion_sync_$deviceId.json'),
        isTrue,
        reason: 'the old file is the OTHER twin\'s livelihood -- not ours '
            'to delete',
      );
    });

    test('leaves identity alone when the nonce is one we minted', () async {
      final deviceId = await repository.getDeviceId();
      await initializer.recordUploadNonce('our-own-nonce');
      cloud.seedFile(
        'submersion_sync_$deviceId.json',
        await craftFile(deviceId, uploadNonce: 'our-own-nonce'),
      );

      final result = await buildService().performSync();

      expect(result.adoptedFreshIdentity, isFalse);
      expect(await repository.getDeviceId(), deviceId);
    });

    test('treats a nonce-less own file as a pre-upgrade upload', () async {
      final deviceId = await repository.getDeviceId();
      cloud.seedFile(
        'submersion_sync_$deviceId.json',
        await craftFile(deviceId, uploadNonce: null),
      );

      final result = await buildService().performSync();

      expect(
        result.adoptedFreshIdentity,
        isFalse,
        reason:
            'a nonce-less file was written by an older build of THIS '
            'device; flagging it would false-positive every upgrader',
      );
      expect(await repository.getDeviceId(), deviceId);
    });

    test('records its own nonce after each upload', () async {
      await buildService().performSync();

      final deviceId = await repository.getDeviceId();
      final uploaded = cloud.bytesOf('submersion_sync_$deviceId.json');
      expect(uploaded, isNotNull);
      final payload = SyncDataSerializer().deserializePayload(
        utf8.decode(uploaded!),
      );
      expect(payload.uploadNonce, isNotNull);
      expect(
        initializer.isForeignUploadNonce(payload.uploadNonce),
        isFalse,
        reason: 'our own upload must never read as foreign on the next sync',
      );
    });
  });
}
```

- [ ] **Step 2: Run to verify failures**

Run: `flutter test test/core/services/sync/sync_twin_identity_test.dart`
Expected: compile errors (`uploadNonce`, `syncInitializer`, `adoptedFreshIdentity`, `recordUploadNonce` do not exist). That is the failing state for structural TDD.

- [ ] **Step 3: Implement serializer changes**

`lib/core/services/sync/sync_data_serializer.dart`, in `SyncPayload`:

- Add field + ctor param (after `rawDataJson` from Task 1):

```dart
  /// Random nonce minted for each upload. An install records its own recent
  /// nonces (SharedPreferences); finding a nonce it never minted in its OWN
  /// per-device cloud file means another install is syncing with this
  /// device's identity (a "twin", typically created by whole-container OS
  /// migration). Null in payloads written by older builds.
  final String? uploadNonce;
```

- In `toJson()` add `'uploadNonce': uploadNonce,` (older readers parse only known keys, so this is additive).
- In `fromJson` add `uploadNonce: json['uploadNonce'] as String?,`.

In `exportData` (~line 339) add an optional parameter and pass it through:

```dart
  Future<SyncPayload> exportData({
    required String deviceId,
    DateTime? since,
    int? lastSyncTimestamp,
    required List<DeletionLogData> deletions,
    String? uploadNonce,
  }) async {
```

and in the returned `SyncPayload(...)` (~line 489) add `uploadNonce: uploadNonce,`.

- [ ] **Step 4: Implement SyncInitializer nonce bookkeeping**

`lib/core/services/sync/sync_initializer.dart`, after `_dbInstanceTokenKey`:

```dart
  /// Recent nonces this install has stamped into its uploads. A small ring
  /// (not just the latest) so an eventually-consistent provider showing a
  /// slightly stale copy of our own file does not read as foreign.
  static const _uploadNoncesKey = 'sync_upload_nonces';
  static const _maxRecordedNonces = 8;
```

and the methods (after `adoptFreshIdentity`):

```dart
  List<String> get _recordedUploadNonces =>
      _prefs.getStringList(_uploadNoncesKey) ?? const [];

  /// Record a nonce this install just stamped into an upload.
  Future<void> recordUploadNonce(String nonce) async {
    final nonces = [nonce, ..._recordedUploadNonces];
    await _prefs.setStringList(
      _uploadNoncesKey,
      nonces.take(_maxRecordedNonces).toList(),
    );
  }

  /// Whether [nonce], read back from this install's OWN per-device cloud
  /// file, was minted by someone else. True means another install is
  /// uploading under this device id (a twin). A null nonce is never foreign:
  /// it was written by a pre-nonce build of this same device, and flagging
  /// it would false-positive every upgrader's first sync.
  bool isForeignUploadNonce(String? nonce) {
    if (nonce == null) return false;
    return !_recordedUploadNonces.contains(nonce);
  }
```

- [ ] **Step 5: Implement SyncService detection + recording**

`lib/core/services/sync/sync_service.dart`:

- Import: `import 'package:submersion/core/services/sync/sync_initializer.dart';`
- Field + constructor (optional, so existing direct constructions stay valid):

```dart
  final SyncInitializer? _syncInitializer;

  SyncService({
    required SyncRepository syncRepository,
    required SyncDataSerializer serializer,
    CloudStorageProvider? cloudProvider,
    SyncInitializer? syncInitializer,
  }) : _syncRepository = syncRepository,
       _serializer = serializer,
       _cloudProvider = cloudProvider,
       _syncInitializer = syncInitializer;
```

- In `performSync`, change `final deviceId = ...` to `var deviceId = ...` (~line 273), and add a flag next to the merge counters: `var adoptedFreshIdentity = false;`.
- Replace `_resolveRemoteSyncFiles` usage: keep the function but split it so the own file is visible. Replace the function (~line 557) with:

```dart
  /// List every sync file in the folder (excluding iCloud conflict copies).
  Future<List<CloudFileInfo>> _listSyncFiles(
    CloudStorageProvider provider,
  ) async {
    final files = await provider.listFiles(
      namePattern: CloudStorageProviderMixin.syncFileStem,
    );
    return files.where((f) => !_isConflictCopy(f.name)).toList();
  }
```

and in `performSync` replace the `remoteFiles` resolution block (~line 300-315) with:

```dart
      List<CloudFileInfo> allFiles;
      try {
        allFiles = await _listSyncFiles(
          provider,
        ).timeout(const Duration(seconds: 8));
      } on TimeoutException {
        _log.warning('Timed out listing remote sync files');
        allFiles = const [];
      } catch (e, stackTrace) {
        _log.warning(
          'Failed to list remote sync files: $e',
          stackTrace: stackTrace,
        );
        allFiles = const [];
      }

      var ownFileName = _deviceSyncFileName(deviceId);
      CloudFileInfo? ownFile;
      for (final f in allFiles) {
        if (f.name == ownFileName) {
          ownFile = f;
          break;
        }
      }

      // Twin-identity check: our own cloud file carrying a nonce we never
      // minted means another install is syncing as this device (a clone from
      // whole-container OS migration). The launch-time anchor reconcile is
      // structurally blind to that (both installs' anchors match their own
      // DBs), so this in-band signal is the only detection point. Recovery:
      // adopt a fresh identity NOW and keep going -- the shared file then
      // counts as a peer below and the twins converge in this same sync.
      final initializer = _syncInitializer;
      if (ownFile != null && initializer != null) {
        final ownPayload = await _downloadAndParsePayload(provider, ownFile);
        if (ownPayload != null &&
            ownPayload.deviceId == deviceId &&
            initializer.isForeignUploadNonce(ownPayload.uploadNonce)) {
          _log.warning(
            'Another install is uploading as this device id; adopting a '
            'fresh sync identity to split the twins',
          );
          deviceId = await _withStep(
            'adopt fresh identity',
            () => initializer.adoptFreshIdentity(),
          );
          ownFileName = _deviceSyncFileName(deviceId);
          adoptedFreshIdentity = true;
        }
      }

      final remoteFiles = allFiles
          .where((f) => f.name != ownFileName)
          .toList();
```

- In the export section (~line 375), mint and pass the nonce:

```dart
      final uploadNonce = _uuid.v4();
      final localPayload = await _withStep(
        'export local data',
        () => _serializer.exportData(
          deviceId: deviceId,
          since: null, // Full export for now
          lastSyncTimestamp: lastSyncTime?.millisecondsSinceEpoch,
          deletions: deletions,
          uploadNonce: uploadNonce,
        ),
      );
```

- After the successful upload (immediately after the `_log.debug('Upload complete! ...')` line):

```dart
      // Remember the nonce we just published so reading it back from our own
      // file on the next sync does not read as foreign.
      await _syncInitializer?.recordUploadNonce(uploadNonce);
```

- `SyncResult`: add the field and include it in the success result:

```dart
  final bool adoptedFreshIdentity;

  const SyncResult({
    required this.status,
    this.message,
    this.recordsSynced = 0,
    this.conflictsFound = 0,
    this.lastSyncTime,
    this.adoptedFreshIdentity = false,
  });
```

and in the end-of-`performSync` `return SyncResult(...)` add:

```dart
        adoptedFreshIdentity: adoptedFreshIdentity,
        message: recordsFailed > 0
            ? '$recordsFailed record(s) failed to apply'
            : (adoptedFreshIdentity
                  ? 'Another device was syncing with this device\'s '
                        'identity. This device adopted a new identity and '
                        'merged the cloud data.'
                  : null),
```

(replacing the existing `message:` argument).

- [ ] **Step 6: Wire the initializer into the service provider**

`lib/features/settings/presentation/providers/sync_providers.dart` (~line 130):

```dart
/// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    syncRepository: ref.watch(syncRepositoryProvider),
    serializer: ref.watch(syncDataSerializerProvider),
    cloudProvider: ref.watch(cloudStorageProviderProvider),
    syncInitializer: ref.watch(syncInitializerProvider),
  );
});
```

(`syncInitializerProvider` is defined later in the same file; that is fine.)

- [ ] **Step 7: Run the tests**

Run: `flutter test test/core/services/sync/sync_twin_identity_test.dart`
Expected: all PASS.
Run: `flutter test test/core/services/sync test/features/settings`
Expected: all pass (the constructor param is optional; `craftDeviceFile` in the per-device test builds payloads without nonces, which stay valid).

- [ ] **Step 8: Format and commit**

```bash
dart format lib/ test/
git add -A
git commit -m "feat(sync): detect twin device identities via per-upload nonces

Whole-container OS migration (iPhone transfer, Migration Assistant,
iCloud device backup) clones the database AND SharedPreferences, so
both installs pass the launch-time anchor reconcile and sync as the
same device id -- each excludes the shared per-device file as 'its
own', sees zero peers, and silently overwrites the other forever.
Every upload now embeds a random nonce; finding a nonce we never
minted in our own file means a twin is writing as us, and the sync
adopts a fresh identity on the spot and merges the shared file as a
peer, converging the twins in the same pass."
```

---

### Task 5: First-contact merge confirmation

**Files:**
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (SyncState, SyncNotifier)
- Modify: `lib/core/services/sync/sync_initializer.dart` (publicize peer listing)
- Modify: `lib/app.dart` (auto-sync call sites ~line 142, 148)
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart` (Sync Now ~line 578-595, banner)
- Modify: `lib/l10n/arb/app_en.arb` (new keys)
- Modify: `test/features/settings/presentation/pages/cloud_sync_page_test.dart` and `test/features/settings/presentation/s3_config_page_test.dart` (fake notifiers)
- Test: `test/core/services/sync/sync_first_contact_guard_test.dart` (new)

- [ ] **Step 1: Publicize peer file listing**

In `lib/core/services/sync/sync_initializer.dart`, rename `_peerSyncFiles` to `peerSyncFiles` (it is currently private, ~line 282) and update its one internal caller in `checkSyncOnLaunch`. Keep the doc comment.

- [ ] **Step 2: Write the failing notifier tests**

Create `test/core/services/sync/sync_first_contact_guard_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCloudStorageProvider cloud;
  late ProviderContainer container;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    cloud = FakeCloudStorageProvider();
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(cloud),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  Future<void> seedLocalDive(String id) async {
    await DiveRepository().createDive(createTestDiveWithBottomTime(id: id));
  }

  void seedPeerFile() {
    cloud.seedFile(
      'submersion_sync_peer-device.json',
      Uint8List.fromList([1, 2, 3]),
    );
  }

  group('first-contact merge guard', () {
    test('firstSyncMergeInfo reports peers and local dives', () async {
      await seedLocalDive('local-1');
      seedPeerFile();

      final info = await container
          .read(syncStateProvider.notifier)
          .firstSyncMergeInfo();

      expect(info, isNotNull);
      expect(info!.peerFileCount, 1);
      expect(info.localDiveCount, 1);
    });

    test('returns null once a baseline exists', () async {
      await seedLocalDive('local-2');
      seedPeerFile();
      await SyncRepository().updateLastSyncTime(DateTime(2026, 1, 1));

      final info = await container
          .read(syncStateProvider.notifier)
          .firstSyncMergeInfo();

      expect(
        info,
        isNull,
        reason: 'the guard protects only the FIRST contact',
      );
    });

    test('returns null with no local data', () async {
      seedPeerFile();

      final info = await container
          .read(syncStateProvider.notifier)
          .firstSyncMergeInfo();

      expect(
        info,
        isNull,
        reason: 'merging into an empty library is a plain download -- '
            'no confirmation needed',
      );
    });

    test('returns null with no peers', () async {
      await seedLocalDive('local-3');

      final info = await container
          .read(syncStateProvider.notifier)
          .firstSyncMergeInfo();

      expect(info, isNull);
    });

    test('auto sync defers on first contact instead of merging', () async {
      await seedLocalDive('local-4');
      seedPeerFile();
      final filesBefore = cloud.fileCount;

      await container
          .read(syncStateProvider.notifier)
          .performSync(auto: true);

      final state = container.read(syncStateProvider);
      expect(state.firstSyncAwaitingConfirmation, isTrue);
      expect(
        cloud.fileCount,
        filesBefore,
        reason: 'no upload may happen before the user confirms the merge',
      );
    });

    test('manual sync proceeds and clears the deferred flag', () async {
      await seedLocalDive('local-5');
      seedPeerFile();
      await container
          .read(syncStateProvider.notifier)
          .performSync(auto: true);

      await container.read(syncStateProvider.notifier).performSync();

      final state = container.read(syncStateProvider);
      expect(state.firstSyncAwaitingConfirmation, isFalse);
      final deviceId = await SyncRepository().getDeviceId();
      expect(
        await cloud.fileExists('submersion_sync_$deviceId.json'),
        isTrue,
        reason: 'the manual (user-confirmed) path performs the sync',
      );
    });
  });
}
```

Note: the seeded peer file is intentionally garbage bytes — the guard counts peer FILES (cheap listing); parsing happens only during the real merge. The manual-sync test tolerates the unparseable peer (it is skipped with a warning, sync still succeeds).

- [ ] **Step 3: Run to verify failures**

Run: `flutter test test/core/services/sync/sync_first_contact_guard_test.dart`
Expected: compile errors (`firstSyncMergeInfo`, `firstSyncAwaitingConfirmation`, `performSync(auto:)` missing).

- [ ] **Step 4: Implement state + notifier changes**

`lib/features/settings/presentation/providers/sync_providers.dart`:

- `SyncState`: add field `final bool firstSyncAwaitingConfirmation;`, ctor param `this.firstSyncAwaitingConfirmation = false,`, copyWith param `bool? firstSyncAwaitingConfirmation,` and assignment `firstSyncAwaitingConfirmation: firstSyncAwaitingConfirmation ?? this.firstSyncAwaitingConfirmation,`.
- Add an info class (above `SyncNotifier`):

```dart
/// What the first sync would combine: shown to the user before the first
/// library-merging sync is allowed to run.
class FirstSyncMergeInfo {
  final int peerFileCount;
  final int localDiveCount;

  const FirstSyncMergeInfo({
    required this.peerFileCount,
    required this.localDiveCount,
  });
}
```

- Add the import for the dive repository provider at the top:

```dart
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
```

- In `SyncNotifier`, add:

```dart
  /// Non-null when the NEXT sync would be this device's first contact with
  /// existing cloud data while this device already holds dives -- the case
  /// where a sync irreversibly combines two libraries (and duplicates any
  /// dives that were imported separately on each device). The UI must
  /// confirm before running that sync; auto-sync defers it entirely.
  Future<FirstSyncMergeInfo?> firstSyncMergeInfo() async {
    try {
      final provider = _ref.read(cloudStorageProviderProvider);
      if (provider == null) return null;
      final lastSync = await _syncRepository.getLastSyncTime();
      if (lastSync != null) return null;
      final localDives = await _ref
          .read(diveRepositoryProvider)
          .getDiveCount();
      if (localDives == 0) return null;
      final peers = await _ref
          .read(syncInitializerProvider)
          .peerSyncFiles(provider);
      if (peers.isEmpty) return null;
      return FirstSyncMergeInfo(
        peerFileCount: peers.length,
        localDiveCount: localDives,
      );
    } catch (e) {
      // The guard must never block sync outright; on failure fall through
      // to normal behavior.
      _log.warning('First-contact check failed: $e');
      return null;
    }
  }
```

- Change `performSync` signature and head:

```dart
  /// Perform a sync operation.
  ///
  /// [auto] marks unattended triggers (launch, resume, post-write debounce).
  /// An auto sync defers this device's FIRST library-combining contact to a
  /// manual, user-confirmed Sync Now instead of merging unannounced.
  Future<void> performSync({bool auto = false}) async {
    _log.debug('performSync() called');
    if (state.status == SyncStatus.syncing) {
      _log.debug('Already syncing, returning early');
      return;
    }

    if (auto) {
      final info = await firstSyncMergeInfo();
      if (info != null) {
        _log.info(
          'Deferring auto sync: first contact with existing cloud data '
          'needs user confirmation',
        );
        state = state.copyWith(
          firstSyncAwaitingConfirmation: true,
          message:
              'First sync needs confirmation. Open Cloud Sync and tap '
              'Sync Now.',
        );
        return;
      }
    }

    state = state.copyWith(
      status: SyncStatus.syncing,
      message: 'Starting sync...',
      progress: 0.0,
      firstSyncAwaitingConfirmation: false,
    );
    // ... rest unchanged
```

- In `_scheduleAutoSync` (~line 218), change the timer body to `performSync(auto: true);`.

`lib/app.dart`: in `_maybeSyncOnLaunch` (~line 142) and `_maybeSyncOnResume` (~line 148), change `performSync()` to `performSync(auto: true)`.

- [ ] **Step 5: Run the notifier tests**

Run: `flutter test test/core/services/sync/sync_first_contact_guard_test.dart`
Expected: all PASS.

- [ ] **Step 6: Add the l10n strings (English)**

In `lib/l10n/arb/app_en.arb`, next to the other `settings_cloudSync_` keys (search `settings_cloudSync_disabledBanner_title`), add:

```json
  "settings_cloudSync_firstSync_dialogTitle": "Combine Libraries?",
  "settings_cloudSync_firstSync_dialogContent": "Sync data from {deviceCount} other device(s) was found in the cloud. Your first sync will combine that data with the {diveCount} dive(s) on this device, on every synced device.\n\nIf the same dives were added separately on each device, they will appear twice.",
  "@settings_cloudSync_firstSync_dialogContent": {
    "placeholders": {
      "deviceCount": {"type": "int"},
      "diveCount": {"type": "int"}
    }
  },
  "settings_cloudSync_firstSync_dialogConfirm": "Merge and Sync",
  "settings_cloudSync_firstSync_banner": "First sync is waiting for confirmation. Tap Sync Now to review what will be combined.",
```

Then run `flutter gen-l10n` (missing translations in other locales fall back to English until Task 6).

- [ ] **Step 7: Wire the page**

`lib/features/settings/presentation/pages/cloud_sync_page.dart`:

- Change the Sync Now button (~line 578-581):

```dart
          FilledButton.icon(
            onPressed: isSyncing || !hasProvider
                ? null
                : () => _onSyncNowPressed(context, ref),
```

- Add the handler (next to `_confirmResetSyncState`):

```dart
  /// Run a sync, first confirming the merge when this would be the device's
  /// first contact with existing cloud data while it already holds dives.
  Future<void> _onSyncNowPressed(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(syncStateProvider.notifier);
    final info = await notifier.firstSyncMergeInfo();
    if (info == null) {
      await notifier.performSync();
      return;
    }
    if (!context.mounted) return;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settings_cloudSync_firstSync_dialogTitle),
        content: Text(
          l10n.settings_cloudSync_firstSync_dialogContent(
            info.peerFileCount,
            info.localDiveCount,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.settings_cloudSync_firstSync_dialogConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await notifier.performSync();
    }
  }
```

(Check the generated getter signature in `lib/l10n/app_localizations.dart` after `flutter gen-l10n` — positional params follow placeholder order.)

- Add the deferred banner in `_buildSyncActions`, right above the `FilledButton.icon` inside the `children:` list:

```dart
          if (syncState.firstSyncAwaitingConfirmation)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(
                          context,
                        ).colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.settings_cloudSync_firstSync_banner,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
```

- [ ] **Step 8: Update the fake notifiers**

In `test/features/settings/presentation/pages/cloud_sync_page_test.dart` and `test/features/settings/presentation/s3_config_page_test.dart`, the `_FakeSyncNotifier implements SyncNotifier` classes must match the new interface:

```dart
  @override
  Future<void> performSync({bool auto = false}) async => performSyncCalls++;

  @override
  Future<FirstSyncMergeInfo?> firstSyncMergeInfo() async => null;
```

- [ ] **Step 9: Run the affected suites**

Run: `flutter test test/core/services/sync test/features/settings`
Expected: all pass.

- [ ] **Step 10: Format and commit**

```bash
dart format lib/ test/
git add -A
git commit -m "feat(sync): confirm first-contact library merges before syncing

The first sync on a device that already holds dives irreversibly
combines its library with existing cloud data on every synced device,
duplicating any dives imported separately on each. Sync Now now shows
what will be combined and asks first; unattended auto-sync (launch,
resume, post-write) defers that first contact to a manual sync and
surfaces a banner."
```

---

### Task 6: Translate the new strings into all 10 locales

**Files:**
- Modify: `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`

- [ ] **Step 1: Add translations**

For each locale file, add the four keys from Task 5 Step 6 (`settings_cloudSync_firstSync_dialogTitle`, `settings_cloudSync_firstSync_dialogContent` with the same `@`-metadata placeholders block, `settings_cloudSync_firstSync_dialogConfirm`, `settings_cloudSync_firstSync_banner`) translated into the file's language, adjacent to the existing `settings_cloudSync_` keys. Translate naturally (these are user-facing dialog strings about combining dive libraries); keep `{deviceCount}`/`{diveCount}` placeholders verbatim.

- [ ] **Step 2: Regenerate and verify**

Run: `flutter gen-l10n`
Expected: completes; the untranslated-messages report no longer lists the four new keys.
Run: `flutter analyze lib/l10n`
Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/l10n
git commit -m "chore(l10n): translate first-sync merge strings into all locales"
```

---

### Task 7: Full verification gates

- [ ] **Step 1: Format check**

Run: `dart format lib/ test/`
Expected: no files changed (everything formatted at commit time).

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: `No issues found!` — run on the WHOLE project (do not pipe through filters that mask the exit code).

- [ ] **Step 3: Run the affected test suites**

Run: `flutter test test/core/services/sync`
Run: `flutter test test/core/data/repositories`
Run: `flutter test test/features/settings`
Run: `flutter test test/features/backup`
Expected: all pass.

- [ ] **Step 4: Fix anything found, re-run, commit fixes**

Any failures: fix, re-run the failing suite, then re-run `flutter analyze`. Commit as `fix(sync): address verification gate findings` only if changes were needed.

---

## Out of scope (deliberately)

- Content-based dive dedup during merge (`sourceUuid` matching) — feature-sized; the first-contact dialog discloses the duplication risk instead.
- Detecting twins for installs that BOTH still run pre-nonce builds — undetectable until one upgrades and uploads a nonce.
- A "merge preview" diff UI — the confirmation dialog reports counts only.
- Cleanup of orphaned per-device files from devices retired without Reset (no reliable liveness signal exists).

## Self-review notes

- Task 1's raw-JSON checksum relies on Dart maps preserving insertion order and `jsonEncode(decode(x)) == x` for compact Dart-written JSON — both hold for files written by Dart's `jsonEncode` (all writers are this app).
- Task 4's `adoptFreshIdentity` mid-sync resets the in-memory `SyncClock`; it lazily re-seeds under the new node id on the next stamped write (`ensureSyncClockConfigured`), and `persistSyncClock()` tolerates an unseeded clock — verify that during implementation (`lib/core/data/repositories/sync_repository.dart`, `persistSyncClock`).
- Task 3 changes no behavior for `rebaselineAfterRestore` (default `clearDeletionLog: true`), so `sync_initializer_reconcile_test.dart`'s "stale tombstones must be cleared" expectations stay valid.
- The two fake `SyncNotifier`s and the optional `SyncService` constructor param are the only API-shape changes; `flutter analyze` catches any missed override.
