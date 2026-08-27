# Synced Media Upload Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move photo and video upload quality out of device-local `SharedPreferences` and into the synced `settings` key-value table, so every device uploads at the same level and the library is internally consistent.

**Architecture:** Split `MediaStorePolicies` along the boundary it was blurring. It keeps the three genuinely device-local transport flags (`autoUpload`, `photosOnCellular`, `videosOnCellular`) and stays preferences-backed. A new `MediaUploadQualityPolicy` owns the two library-wide quality keys, delegating to `AppSettingsRepository`, which already writes the synced `settings` table and stages rows via `markRecordPending`. The upload pipeline swaps one collaborator for the other -- its only use of `MediaStorePolicies` is `qualityFor`.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-07-24-synced-media-upload-quality-design.md`

## Global Constraints

- **No schema migration and no `currentSchemaVersion` bump.** Two new keys go into the existing `settings` key-value table. The next free schema version remains v137. If you find yourself editing `database.dart` schema or a migration, stop -- you have gone off-plan.
- **No serializer changes.** `settings` is already registered for sync (`sync_repository.dart:76`, `pk: 'key'`) and handled generically. The device-local deny-list is `_deviceLocalSettingsKeys = {'active_diver_id'}` (`sync_data_serializer.dart:4838`); the new keys must NOT be added to it.
- **Setting keys, exact values:** `media_upload_quality_photo`, `media_upload_quality_video`. Stored value is `MediaUploadQuality.name`.
- **Read/write error asymmetry** (the documented policy of `AppSettingsRepository`, line 77): reads are non-throwing and degrade to a safe default; writes rethrow so a failed save is visible.
- **Quality reads fall back to `MediaUploadQuality.original`** on any error or unrecognized value. This fails toward full fidelity.
- **Localization:** every new ARB key must be added to all 11 locales (`en`, `ar`, `de`, `es`, `fr`, `he`, `hu`, `it`, `nl`, `pt`, `zh`) followed by `flutter gen-l10n`. `lib/l10n/arb/app_localizations*.dart` is tracked and must be committed (unlike `*.g.dart`, which is gitignored).
- **Formatting:** `dart format .` must produce no changes before any commit is pushed.
- **Working directory:** all paths are relative to the worktree `.claude/worktrees/synced-media-upload-quality` on branch `worktree-synced-media-upload-quality`. It is already initialized (submodules, `flutter pub get`, `build_runner`). Do not run commands against the main checkout.

---

### Task 1: Raw settings accessors on `AppSettingsRepository`

Foundation. Adds a generic key-value read/write pair to the repository that already owns the synced `settings` table. No consumers yet.

**Files:**
- Modify: `lib/features/settings/data/repositories/app_settings_repository.dart`
- Test: `test/features/settings/data/repositories/app_settings_repository_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `Future<String?> AppSettingsRepository.getRawSetting(String key)` and `Future<void> AppSettingsRepository.setRawSetting(String key, String value)`. Task 2 depends on both.

- [ ] **Step 1: Write the failing tests**

Append these two groups to `test/features/settings/data/repositories/app_settings_repository_test.dart`, inside the existing top-level `main()` (after the `AppSettingsRepository sync notifications` group's closing brace, before the final `}`). The file's existing `setUp` already calls `setUpTestDatabase()` and builds `repository`.

```dart
  group('AppSettingsRepository raw settings', () {
    test('returns null for an absent key', () async {
      expect(await repository.getRawSetting('nope'), isNull);
    });

    test('round-trips a value', () async {
      await repository.setRawSetting('k', 'v');
      expect(await repository.getRawSetting('k'), 'v');
    });

    test('overwrites an existing value', () async {
      await repository.setRawSetting('k', 'v1');
      await repository.setRawSetting('k', 'v2');
      expect(await repository.getRawSetting('k'), 'v2');
    });

    test('keys are independent', () async {
      await repository.setRawSetting('a', '1');
      await repository.setRawSetting('b', '2');
      expect(await repository.getRawSetting('a'), '1');
      expect(await repository.getRawSetting('b'), '2');
    });

    // This is the assertion that proves the value actually syncs: staging the
    // row under entityType 'settings' with the key as recordId is what puts it
    // into the next changeset.
    test('setRawSetting stages the row for sync under its key', () async {
      await repository.setRawSetting('k', 'v');

      final pending = await SyncRepository().getPendingRecords();
      expect(
        pending.any((r) => r.entityType == 'settings' && r.recordId == 'k'),
        isTrue,
      );
    });

    test('setRawSetting notifies the sync change bus', () async {
      var fired = false;
      final sub = SyncEventBus.changes.listen((_) => fired = true);
      addTearDown(sub.cancel);

      await repository.setRawSetting('k', 'v');
      await pumpEventQueue();

      expect(fired, isTrue);
    });
  });
```

Add this import at the top of the file, keeping the existing import grouping (packages before relative):

```dart
import 'package:submersion/core/data/repositories/sync_repository.dart';
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
flutter test test/features/settings/data/repositories/app_settings_repository_test.dart
```

Expected: compile failure -- `getRawSetting`/`setRawSetting` are not defined on `AppSettingsRepository`.

(`SyncRepository.getPendingRecords()` is defined at `lib/core/data/repositories/sync_repository.dart:674` and returns `Future<List<SyncRecord>>`.)

- [ ] **Step 3: Implement the accessors**

Add to `AppSettingsRepository`, after `setShareByDefault`. The bodies deliberately mirror the existing methods exactly -- same insert-on-conflict, same staging call, same logging.

```dart
  /// Returns the raw stored value for [key], or `null` if unset or on a read
  /// error.
  ///
  /// Generic because the backing table is a key-value store; callers own the
  /// key name and any parsing (same idiom as [getNavPrimaryIdsRaw]). Reads are
  /// non-throwing so a caller can degrade to its own safe default rather than
  /// block on a transient DB error.
  Future<String?> getRawSetting(String key) async {
    try {
      final row = await (_db.select(
        _db.settings,
      )..where((t) => t.key.equals(key))).getSingleOrNull();
      return row?.value;
    } catch (e, stackTrace) {
      _log.error('Failed to read $key', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Writes [value] under [key] and stages the row for sync.
  ///
  /// Writes rethrow (unlike reads) so a caller can tell the user their change
  /// did not take.
  Future<void> setRawSetting(String key, String value) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db
          .into(_db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion(
              key: Value(key),
              value: Value(value),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'settings',
        recordId: key,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error('Failed to write $key', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
flutter test test/features/settings/data/repositories/app_settings_repository_test.dart
```

Expected: PASS, including the pre-existing `getShareByDefault` and nav groups.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/settings/data/repositories/app_settings_repository.dart test/features/settings/data/repositories/app_settings_repository_test.dart
git commit -m "feat(settings): add raw key-value accessors to AppSettingsRepository

Generic getRawSetting/setRawSetting over the synced settings table, mirroring
the existing typed methods: insert-on-conflict, markRecordPending under
entityType 'settings' with the key as recordId, then notify the change bus.

Reads degrade to null on error; writes rethrow."
```

---

### Task 2: `MediaUploadQualityPolicy` and its shared test fake

The new home for library-wide quality. Still no consumers -- Task 3 wires it in.

**Files:**
- Create: `lib/core/services/media_store/media_upload_quality_policy.dart`
- Create: `test/support/fake_app_settings_repository.dart`
- Test: `test/core/services/media_store/media_upload_quality_policy_test.dart`

**Interfaces:**
- Consumes: `AppSettingsRepository.getRawSetting(String)` / `setRawSetting(String, String)` from Task 1.
- Produces:
  - `MediaUploadQualityPolicy({AppSettingsRepository? settings})`
  - `Future<MediaUploadQuality> photoUploadQuality()`
  - `Future<void> setPhotoUploadQuality(MediaUploadQuality value)`
  - `Future<MediaUploadQuality> videoUploadQuality()`
  - `Future<void> setVideoUploadQuality(MediaUploadQuality value)`
  - `Future<MediaUploadQuality> qualityFor(MediaType type)`
  - `static const String MediaUploadQualityPolicy.photoQualityKey` = `'media_upload_quality_photo'`
  - `static const String MediaUploadQualityPolicy.videoQualityKey` = `'media_upload_quality_video'`
  - `FakeAppSettingsRepository` with a public `Map<String, String> values`, and settable `Object? throwOnRead` / `Object? throwOnWrite`.
  - Tasks 3, 5, and 6 all use `FakeAppSettingsRepository`.

- [ ] **Step 1: Write the shared fake**

Create `test/support/fake_app_settings_repository.dart`. Every member of `AppSettingsRepository` is implemented explicitly -- Dart's `noSuchMethod` forwarding would also work, but explicit stubs keep the analyzer quiet and make it obvious which methods the fake actually supports.

```dart
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';

/// In-memory stand-in for [AppSettingsRepository] so tests can exercise
/// settings-backed policies without a database.
///
/// Dart's implicit interfaces let us `implements` the concrete repository, so
/// no production-side abstraction is needed.
class FakeAppSettingsRepository implements AppSettingsRepository {
  final Map<String, String> values = {};

  /// When set, [getRawSetting] throws it.
  Object? throwOnRead;

  /// When set, [setRawSetting] throws it.
  Object? throwOnWrite;

  @override
  Future<String?> getRawSetting(String key) async {
    if (throwOnRead != null) throw throwOnRead!;
    return values[key];
  }

  @override
  Future<void> setRawSetting(String key, String value) async {
    if (throwOnWrite != null) throw throwOnWrite!;
    values[key] = value;
  }

  @override
  Future<bool> getShareByDefault() async =>
      throw UnimplementedError('not used by these tests');

  @override
  Future<void> setShareByDefault(bool value) async =>
      throw UnimplementedError('not used by these tests');

  @override
  Future<List<String>?> getNavPrimaryIdsRaw() async =>
      throw UnimplementedError('not used by these tests');

  @override
  Future<void> setNavPrimaryIds(List<String> ids) async =>
      throw UnimplementedError('not used by these tests');
}
```

If `flutter analyze` later reports unimplemented members, add stubs for them in the same style -- the class must satisfy whatever public surface `AppSettingsRepository` has at implementation time.

- [ ] **Step 2: Write the failing tests**

Create `test/core/services/media_store/media_upload_quality_policy_test.dart`. These port the cases from `media_store_policies_quality_test.dart` and add the error-path cases the preferences-backed version could not express.

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/media_store/media_upload_quality_policy.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

import '../../../support/fake_app_settings_repository.dart';

void main() {
  late FakeAppSettingsRepository settings;
  late MediaUploadQualityPolicy policy;

  setUp(() {
    settings = FakeAppSettingsRepository();
    policy = MediaUploadQualityPolicy(settings: settings);
  });

  test('defaults to original for both media types', () async {
    expect(await policy.photoUploadQuality(), MediaUploadQuality.original);
    expect(await policy.videoUploadQuality(), MediaUploadQuality.original);
    expect(await policy.qualityFor(MediaType.photo), MediaUploadQuality.original);
    expect(await policy.qualityFor(MediaType.video), MediaUploadQuality.original);
  });

  test('round-trips every photo level', () async {
    for (final level in MediaUploadQuality.values) {
      await policy.setPhotoUploadQuality(level);
      expect(await policy.photoUploadQuality(), level);
      expect(await policy.qualityFor(MediaType.photo), level);
    }
  });

  test('round-trips every video level', () async {
    for (final level in MediaUploadQuality.values) {
      await policy.setVideoUploadQuality(level);
      expect(await policy.videoUploadQuality(), level);
      expect(await policy.qualityFor(MediaType.video), level);
    }
  });

  test('video level is independent of photo level', () async {
    await policy.setPhotoUploadQuality(MediaUploadQuality.high);
    await policy.setVideoUploadQuality(MediaUploadQuality.small);
    expect(await policy.qualityFor(MediaType.photo), MediaUploadQuality.high);
    expect(await policy.qualityFor(MediaType.video), MediaUploadQuality.small);
  });

  test('writes land under the documented synced keys', () async {
    await policy.setPhotoUploadQuality(MediaUploadQuality.balanced);
    await policy.setVideoUploadQuality(MediaUploadQuality.small);
    expect(settings.values[MediaUploadQualityPolicy.photoQualityKey], 'balanced');
    expect(settings.values[MediaUploadQualityPolicy.videoQualityKey], 'small');
  });

  test('an unknown stored value falls back to original', () async {
    settings.values[MediaUploadQualityPolicy.photoQualityKey] = 'bogus';
    expect(await policy.photoUploadQuality(), MediaUploadQuality.original);
  });

  // The pipeline reads this on a background upload path, and the database can
  // be absent mid-restore. Falling back to original fails toward full
  // fidelity: never make a degraded rendition the only copy of a photo.
  test('a throwing read falls back to original', () async {
    settings.values[MediaUploadQualityPolicy.photoQualityKey] = 'small';
    settings.throwOnRead = StateError('db gone');
    expect(await policy.photoUploadQuality(), MediaUploadQuality.original);
  });

  test('a throwing write is rethrown', () async {
    settings.throwOnWrite = StateError('disk full');
    expect(
      () => policy.setPhotoUploadQuality(MediaUploadQuality.small),
      throwsStateError,
    );
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

```bash
flutter test test/core/services/media_store/media_upload_quality_policy_test.dart
```

Expected: compile failure -- `media_upload_quality_policy.dart` does not exist.

- [ ] **Step 4: Implement the policy**

Create `lib/core/services/media_store/media_upload_quality_policy.dart`:

```dart
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';

/// Library-wide media upload quality, stored in the synced `settings`
/// key-value table.
///
/// Deliberately separate from [MediaStorePolicies]: those flags answer "may
/// this device spend bandwidth right now", which is a per-device question.
/// Quality answers "what bytes should the library permanently contain", which
/// is not. A non-Original level uploads a compressed rendition *instead of*
/// the original, and the original then never leaves the device -- so the
/// choice decides the library's archival fidelity, and every device must agree
/// on it. Storing it per-device let whichever device happened to hold a file
/// decide that file's fidelity.
class MediaUploadQualityPolicy {
  MediaUploadQualityPolicy({AppSettingsRepository? settings})
    : _settings = settings ?? AppSettingsRepository();

  final AppSettingsRepository _settings;

  static const String photoQualityKey = 'media_upload_quality_photo';
  static const String videoQualityKey = 'media_upload_quality_video';

  Future<MediaUploadQuality> photoUploadQuality() => _read(photoQualityKey);

  Future<void> setPhotoUploadQuality(MediaUploadQuality value) =>
      _settings.setRawSetting(photoQualityKey, value.name);

  Future<MediaUploadQuality> videoUploadQuality() => _read(videoQualityKey);

  Future<void> setVideoUploadQuality(MediaUploadQuality value) =>
      _settings.setRawSetting(videoQualityKey, value.name);

  /// The level for [type]'s media (photos vs video).
  Future<MediaUploadQuality> qualityFor(MediaType type) =>
      type == MediaType.video ? videoUploadQuality() : photoUploadQuality();

  /// Reads never throw. [AppSettingsRepository.getRawSetting] already degrades
  /// to null on a DB error, but the collaborator is injected and this class
  /// does not control every implementation, so the guard stays at the seam.
  /// An unrecognized value (a level written by a future build) is treated the
  /// same way, mirroring the pipeline's tolerant override parse.
  Future<MediaUploadQuality> _read(String key) async {
    final String? raw;
    try {
      raw = await _settings.getRawSetting(key);
    } catch (_) {
      return MediaUploadQuality.original;
    }
    if (raw == null) return MediaUploadQuality.original;
    try {
      return MediaUploadQuality.values.byName(raw);
    } on ArgumentError {
      return MediaUploadQuality.original;
    }
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
flutter test test/core/services/media_store/media_upload_quality_policy_test.dart
```

Expected: PASS, 9 tests.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/services/media_store/media_upload_quality_policy.dart test/core/services/media_store/media_upload_quality_policy_test.dart test/support/fake_app_settings_repository.dart
git commit -m "feat(media-store): add MediaUploadQualityPolicy over synced settings

Library-wide photo/video upload quality backed by the synced settings table
rather than device-local preferences, so every device uploads at the same
level. Reads fall back to Original on error or an unrecognized value, which
fails toward full fidelity; writes rethrow.

Not yet wired to the pipeline."
```

---

### Task 3: Swap the upload pipeline onto the new policy

The pipeline's only use of `MediaStorePolicies` is `qualityFor`, so this replaces one collaborator with another rather than adding a dependency. It also drops the pipeline's hidden `SharedPreferences` dependency.

**Files:**
- Modify: `lib/features/media_store/data/media_upload_pipeline.dart` (constructor at 33-55, field at 63, read site at 172, import at 6)
- Modify: `test/features/media_store/media_upload_pipeline_quality_test.dart`
- Modify: `test/features/media_store/media_upload_pipeline_video_test.dart`
- Modify: `test/features/media_store/media_upload_pipeline_override_test.dart`
- Modify: `test/features/media_store/media_store_quality_end_to_end_test.dart`

**Interfaces:**
- Consumes: `MediaUploadQualityPolicy` and `FakeAppSettingsRepository` from Task 2.
- Produces: `MediaUploadPipeline({..., MediaUploadQualityPolicy? quality, ...})`. The `policies` parameter no longer exists. Task 5 constructs the pipeline through providers.

- [ ] **Step 1: Update the four test files to the new constructor**

These are the failing tests for this task -- existing behavioral coverage stays identical, only the collaborator changes. That is exactly the regression signal we want.

In each of the four files, replace the `MediaStorePolicies` import:

```dart
import 'package:submersion/core/services/media_store/media_store_policies.dart';
```

with:

```dart
import 'package:submersion/core/services/media_store/media_upload_quality_policy.dart';
```

and add the fake import, matching each file's existing relative-import depth (all four live in `test/features/media_store/`, so):

```dart
import '../../support/fake_app_settings_repository.dart';
```

Then apply these mechanical substitutions:

`media_upload_pipeline_quality_test.dart` (two sites, near lines 78 and 114):

```dart
    final quality = MediaUploadQualityPolicy(
      settings: FakeAppSettingsRepository(),
    );
    await quality.setPhotoUploadQuality(MediaUploadQuality.balanced);
```

and in both `MediaUploadPipeline(...)` calls change `policies: policies,` to `quality: quality,`.

`media_store_quality_end_to_end_test.dart` (near line 71): identical substitution, one site.

`media_upload_pipeline_video_test.dart`: the field at line 51 becomes

```dart
  late MediaUploadQualityPolicy quality;
```

the `setUp` at lines 67-68 becomes

```dart
    quality = MediaUploadQualityPolicy(settings: FakeAppSettingsRepository());
    await quality.setVideoUploadQuality(MediaUploadQuality.balanced);
```

the pipeline construction at line 83 becomes `quality: quality,`, and the two later mutations at lines 163 and 217 become `await quality.setVideoUploadQuality(...)` and `await quality.setPhotoUploadQuality(...)` respectively.

`media_upload_pipeline_override_test.dart`: the helper parameter at line 72 becomes

```dart
    MediaUploadQualityPolicy? quality,
```

its forwarding at line 79 becomes `quality: quality,`, and the two call sites (near lines 130 and 163) build `MediaUploadQualityPolicy(settings: FakeAppSettingsRepository())` and pass `quality: quality`.

Leave every `SharedPreferences.setMockInitialValues` call in place for now -- attach state also uses preferences, and Step 5 determines empirically which are still needed.

- [ ] **Step 2: Run the tests to verify they fail**

```bash
flutter test test/features/media_store/media_upload_pipeline_quality_test.dart test/features/media_store/media_upload_pipeline_video_test.dart test/features/media_store/media_upload_pipeline_override_test.dart test/features/media_store/media_store_quality_end_to_end_test.dart
```

Expected: compile failure -- `MediaUploadPipeline` has no named parameter `quality`.

- [ ] **Step 3: Swap the pipeline's collaborator**

In `lib/features/media_store/data/media_upload_pipeline.dart`:

Replace the import at line 6:

```dart
import 'package:submersion/core/services/media_store/media_upload_quality_policy.dart';
```

In the constructor parameter list, replace `MediaStorePolicies? policies,` with:

```dart
    MediaUploadQualityPolicy? quality,
```

In the initializer list, replace `_policies = policies ?? MediaStorePolicies(),` with:

```dart
       _quality = quality ?? MediaUploadQualityPolicy(),
```

Replace the field at line 63:

```dart
  final MediaUploadQualityPolicy _quality;
```

Replace the read at line 172:

```dart
          await _quality.qualityFor(item.mediaType);
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
flutter test test/features/media_store/media_upload_pipeline_quality_test.dart test/features/media_store/media_upload_pipeline_video_test.dart test/features/media_store/media_upload_pipeline_override_test.dart test/features/media_store/media_store_quality_end_to_end_test.dart
```

Expected: PASS, with the same test names and counts as before the swap.

- [ ] **Step 5: Run the whole media_store suite to catch collateral damage**

```bash
flutter test test/features/media_store/
```

Expected: PASS. If a test that builds a pipeline without an explicit `quality:` now fails trying to reach a real database, give it `quality: MediaUploadQualityPolicy(settings: FakeAppSettingsRepository())`.

Optionally, in the four files touched above only, delete a `SharedPreferences.setMockInitialValues({})` line, re-run that file, and keep the deletion only if it still passes. Do not sweep other files.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/media_store/data/media_upload_pipeline.dart test/features/media_store/
git commit -m "refactor(media-store): read upload quality from the synced policy

The pipeline's only use of MediaStorePolicies was qualityFor, so this swaps
one collaborator for another rather than adding a dependency. Every device now
resolves the same level, which makes first-writer-wins on renditions harmless:
whoever uploads first writes what any other device would have written.

Also drops the pipeline's hidden SharedPreferences dependency."
```

---

### Task 4: Strip quality from `MediaStorePolicies`

With the pipeline moved, the old accessors have no callers except the settings page (Task 5 handles that). Remove them so the class documentation is true again.

**Files:**
- Modify: `lib/core/services/media_store/media_store_policies.dart`
- Delete: `test/core/services/media_store/media_store_policies_quality_test.dart`
- Modify: `lib/features/media_store/presentation/pages/media_storage_page.dart` (temporarily, to keep the build green)

**Interfaces:**
- Consumes: nothing new.
- Produces: `MediaStorePolicies` reduced to `autoUpload`/`setAutoUpload`, `photosOnCellular`/`setPhotosOnCellular`, `videosOnCellular`/`setVideosOnCellular`. `photoQualityKey`, `videoQualityKey`, the four quality accessors, `qualityFor`, and `_readQuality` no longer exist.

- [ ] **Step 1: Delete the superseded test file**

Its cases were ported to `media_upload_quality_policy_test.dart` in Task 2, with the storage-key and error-path cases added.

```bash
git rm test/core/services/media_store/media_store_policies_quality_test.dart
```

- [ ] **Step 2: Remove the quality surface from `MediaStorePolicies`**

Delete from `lib/core/services/media_store/media_store_policies.dart`: the `photoQualityKey` and `videoQualityKey` constants, `photoUploadQuality`, `setPhotoUploadQuality`, `videoUploadQuality`, `setVideoUploadQuality`, `qualityFor`, and `_readQuality`. Also delete the now-unused imports:

```dart
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
```

Replace the class doc comment with one that is now accurate:

```dart
/// Device-local transfer policies (design spec section 9). Stored in
/// SharedPreferences like the attach state: these are per-device choices about
/// when this device may spend bandwidth, and must not ride a database restore.
///
/// Upload *quality* deliberately does not live here. It decides what bytes the
/// library permanently contains, not what this device may spend, so it is a
/// synced setting -- see [MediaUploadQualityPolicy].
```

- [ ] **Step 3: Keep the settings page compiling**

`media_storage_page.dart` still calls the deleted accessors at lines 71-72, 670-672, and 686-688. Task 5 rewrites this section properly; for now make the smallest change that compiles by pointing those five call sites at a `MediaUploadQualityPolicy()`. At the top of the file add:

```dart
import 'package:submersion/core/services/media_store/media_upload_quality_policy.dart';
```

In `_loadPolicies`, replace the two quality reads with:

```dart
    final qualityPolicy = MediaUploadQualityPolicy();
    final photoQuality = await qualityPolicy.photoUploadQuality();
    final videoQuality = await qualityPolicy.videoUploadQuality();
```

and in the two `onChanged` handlers replace `ref.read(mediaStorePoliciesProvider).setPhotoUploadQuality(value)` with `MediaUploadQualityPolicy().setPhotoUploadQuality(value)`, and likewise for video.

This is deliberately a stopgap; Task 5 replaces it with providers.

- [ ] **Step 4: Run the affected suites**

```bash
flutter test test/core/services/media_store/ test/features/media_store/
```

Expected: PASS. `media_storage_page_test.dart` will still fail its two quality assertions (they assert on preference keys) -- that is expected and Task 5 fixes them. If it fails only in `the quality section renders both dropdowns` and `changing the photo quality dropdown writes through`, proceed; any other failure must be resolved here.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "refactor(media-store): remove quality from device-local policies

MediaStorePolicies now holds only the three transport flags, so its
'per-device, must not ride a database restore' contract is true for everything
it still owns. Quality moved to MediaUploadQualityPolicy in the prior commits.

The settings page is pointed at the new policy directly as a stopgap; the next
commit moves it onto providers."
```

---

### Task 5: Providers and settings page wiring

Move the dropdowns onto watched providers with invalidate-on-write, matching `shareByDefaultProvider` and its consumer at `settings_page.dart:2193`. Add error surfacing the current handlers lack.

**Files:**
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart`
- Modify: `lib/features/media_store/presentation/pages/media_storage_page.dart`
- Modify: `lib/l10n/arb/app_en.arb` and the 10 other locale ARBs
- Modify: `test/features/media_store/media_storage_page_test.dart`

**Interfaces:**
- Consumes: `MediaUploadQualityPolicy` from Task 2.
- Produces:
  - `mediaUploadQualityPolicyProvider` (`Provider<MediaUploadQualityPolicy>`)
  - `photoUploadQualityProvider` (`FutureProvider<MediaUploadQuality>`)
  - `videoUploadQualityProvider` (`FutureProvider<MediaUploadQuality>`)
  - ARB key `settings_mediaStorage_quality_saveFailed`
  - Task 6 reuses `videoUploadQualityProvider`.

- [ ] **Step 1: Write the failing widget tests**

In `test/features/media_store/media_storage_page_test.dart`, replace the two existing quality tests (near lines 476 and 491) with these.

The file's harness is a `Widget app({bool apple, String? statusHint, int activeCount, List<dynamic> extraOverrides})` helper defined at line 125, used as `await tester.pumpWidget(app(...))`. Its `extraOverrides` spread is deliberately last so callers can override any default.

```dart
  testWidgets('the quality section renders the synced levels', (tester) async {
    final settings = FakeAppSettingsRepository();
    final policy = MediaUploadQualityPolicy(settings: settings);
    await policy.setPhotoUploadQuality(MediaUploadQuality.small);
    await policy.setVideoUploadQuality(MediaUploadQuality.high);

    await tester.pumpWidget(
      app(
        extraOverrides: [
          mediaUploadQualityPolicyProvider.overrideWithValue(policy),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media-quality-photos')), findsOneWidget);
    expect(find.byKey(const Key('media-quality-video')), findsOneWidget);

    final photo = tester.widget<DropdownButton<MediaUploadQuality>>(
      find.byKey(const Key('media-quality-photos')),
    );
    final video = tester.widget<DropdownButton<MediaUploadQuality>>(
      find.byKey(const Key('media-quality-video')),
    );
    expect(photo.value, MediaUploadQuality.small);
    expect(video.value, MediaUploadQuality.high);
  });

  testWidgets('changing the photo quality writes to the synced setting', (
    tester,
  ) async {
    final settings = FakeAppSettingsRepository();
    final policy = MediaUploadQualityPolicy(settings: settings);

    await tester.pumpWidget(
      app(
        extraOverrides: [
          mediaUploadQualityPolicyProvider.overrideWithValue(policy),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('media-quality-photos')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Small').last);
    await tester.pumpAndSettle();

    expect(
      settings.values[MediaUploadQualityPolicy.photoQualityKey],
      'small',
    );
  });
```

Also update the preference-seeding test near line 962: it currently seeds `'media_store_video_quality': 'small'` into mock preferences to drive the ffmpeg hint. Replace that seeding with a `mediaUploadQualityPolicyProvider` override whose video level is `MediaUploadQuality.small`, built the same way as above.

Add these imports to the test file:

```dart
import 'package:submersion/core/services/media_store/media_upload_quality_policy.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

import '../../support/fake_app_settings_repository.dart';
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
flutter test test/features/media_store/media_storage_page_test.dart
```

Expected: compile failure -- `mediaUploadQualityPolicyProvider` is not defined.

- [ ] **Step 3: Add the providers**

In `lib/features/media_store/presentation/providers/media_store_providers.dart`, add next to `mediaStorePoliciesProvider` (line 64):

```dart
final mediaUploadQualityPolicyProvider = Provider<MediaUploadQualityPolicy>(
  (ref) => MediaUploadQualityPolicy(),
);

/// Library-wide photo upload level. Watched by the settings page and
/// invalidated on write, mirroring `shareByDefaultProvider`.
final photoUploadQualityProvider = FutureProvider<MediaUploadQuality>(
  (ref) => ref.watch(mediaUploadQualityPolicyProvider).photoUploadQuality(),
);

final videoUploadQualityProvider = FutureProvider<MediaUploadQuality>(
  (ref) => ref.watch(mediaUploadQualityPolicyProvider).videoUploadQuality(),
);
```

Add the import:

```dart
import 'package:submersion/core/services/media_store/media_upload_quality_policy.dart';
```

Wire the pipeline construction (near line 341, where `videoTranscoder: PlatformVideoTranscoder()` is passed) to use the same policy instance:

```dart
        quality: ref.read(mediaUploadQualityPolicyProvider),
```

- [ ] **Step 4: Add the save-failure string to all 11 locales**

Append to `lib/l10n/arb/app_en.arb` (before the closing brace, after `settings_mediaStorage_quality_linuxFfmpegHint`; remember to add a comma to the preceding line):

```json
  "settings_mediaStorage_quality_saveFailed": "Could not save the upload quality. Try again."
```

Add the same key to each other locale:

- `app_ar.arb`: `"تعذّر حفظ جودة الرفع. حاول مرة أخرى."`
- `app_de.arb`: `"Die Upload-Qualität konnte nicht gespeichert werden. Bitte erneut versuchen."`
- `app_es.arb`: `"No se pudo guardar la calidad de subida. Inténtalo de nuevo."`
- `app_fr.arb`: `"Impossible d'enregistrer la qualité de téléversement. Réessayez."`
- `app_he.arb`: `"לא ניתן היה לשמור את איכות ההעלאה. נסה שוב."`
- `app_hu.arb`: `"A feltöltési minőség mentése nem sikerült. Próbáld újra."`
- `app_it.arb`: `"Impossibile salvare la qualità di caricamento. Riprova."`
- `app_nl.arb`: `"Kan de uploadkwaliteit niet opslaan. Probeer het opnieuw."`
- `app_pt.arb`: `"Não foi possível guardar a qualidade de envio. Tente novamente."`
- `app_zh.arb`: `"无法保存上传质量。请重试。"`

Then regenerate:

```bash
flutter gen-l10n
```

- [ ] **Step 5: Rewrite the page's quality section**

In `lib/features/media_store/presentation/pages/media_storage_page.dart`:

Remove the stopgap from Task 4: delete the two quality reads from `_loadPolicies` and the `_photoQuality` / `_videoQuality` state fields (lines 54-55), and drop them from the `setState` in `_loadPolicies`.

In `build`, before the widget list, read the providers. Use `.value` rather than `.when` so an in-flight refresh does not blank the section (the project's AsyncValue convention):

```dart
    final photoQuality = ref.watch(photoUploadQualityProvider).value;
    final videoQuality = ref.watch(videoUploadQualityProvider).value;
```

Change the section gate at line 652 to `if (photoQuality != null && videoQuality != null) ...[`, and change both dropdowns' `value:` to `photoQuality` and `videoQuality`.

Replace the photo dropdown's `onChanged` with:

```dart
                    onChanged: (value) async {
                      if (value == null) return;
                      try {
                        await ref
                            .read(mediaUploadQualityPolicyProvider)
                            .setPhotoUploadQuality(value);
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.settings_mediaStorage_quality_saveFailed,
                            ),
                          ),
                        );
                      }
                      ref.invalidate(photoUploadQualityProvider);
                    },
```

and the video dropdown's identically, calling `setVideoUploadQuality` and invalidating `videoUploadQualityProvider`.

Invalidating after both success and failure is intentional: on success it re-reads the new truth, and on failure it discards the optimistic value for free.

Update the capability-note condition at line 693-696 to use the local `videoQuality` instead of `_videoQuality` (the `isLinuxPlatformProvider` gate stays for now -- Task 6 removes it).

- [ ] **Step 6: Run the tests to verify they pass**

```bash
flutter test test/features/media_store/media_storage_page_test.dart
```

Expected: PASS, including the pre-existing non-quality tests in that file.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(media-store): drive quality dropdowns from synced providers

Watched FutureProviders with invalidate-on-write, matching
shareByDefaultProvider. Uses AsyncValue.value so an in-flight refresh does not
blank the section, and surfaces a snackbar when a write fails -- the previous
handlers awaited the write and ignored errors entirely."
```

---

### Task 6: Show the capability note on every platform that cannot transcode

A library-wide setting means a device can be told to compress video it has no engine for. The hint already exists but is gated to Linux, which was correct only while the setting was per-device.

**Files:**
- Modify: `lib/features/media_store/presentation/pages/media_storage_page.dart` (lines 693-706)
- Modify: `lib/l10n/arb/app_en.arb` and the 10 other locale ARBs
- Modify: `test/features/media_store/media_storage_page_test.dart`

**Interfaces:**
- Consumes: `videoUploadQualityProvider` from Task 5; the existing `videoTranscodeAvailableProvider` (`media_store_providers.dart:495`) and `isLinuxPlatformProvider`.
- Produces: ARB key `settings_mediaStorage_quality_noTranscoderHint`; widget key `media-quality-transcoder-hint` (renamed from `media-quality-linux-ffmpeg-hint`).

- [ ] **Step 1: Write the failing tests**

In `test/features/media_store/media_storage_page_test.dart`, update the existing ffmpeg-hint tests (near line 1000) to the renamed key, and add a non-Linux case. Build the level via a `mediaUploadQualityPolicyProvider` override, as in Task 5.

```dart
  testWidgets('a non-Linux device without an engine shows the generic hint', (
    tester,
  ) async {
    final policy = MediaUploadQualityPolicy(
      settings: FakeAppSettingsRepository(),
    );
    await policy.setVideoUploadQuality(MediaUploadQuality.small);

    await tester.pumpWidget(
      app(
        extraOverrides: [
          mediaUploadQualityPolicyProvider.overrideWithValue(policy),
          isLinuxPlatformProvider.overrideWithValue(false),
          videoTranscodeAvailableProvider.overrideWith((ref) async => false),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('media-quality-transcoder-hint')),
      findsOneWidget,
    );
  });

  testWidgets('a device with a working engine shows no hint', (tester) async {
    final policy = MediaUploadQualityPolicy(
      settings: FakeAppSettingsRepository(),
    );
    await policy.setVideoUploadQuality(MediaUploadQuality.small);

    await tester.pumpWidget(
      app(
        extraOverrides: [
          mediaUploadQualityPolicyProvider.overrideWithValue(policy),
          isLinuxPlatformProvider.overrideWithValue(false),
          videoTranscodeAvailableProvider.overrideWith((ref) async => true),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media-quality-transcoder-hint')), findsNothing);
  });
```

Rename the key in the two pre-existing Linux hint assertions (near lines 1000 and 1003) from `media-quality-linux-ffmpeg-hint` to `media-quality-transcoder-hint`, and leave their Linux overrides as they are -- they now assert the Linux-specific copy still renders under the generalized condition.

`videoTranscodeAvailableProvider` is `FutureProvider.autoDispose<bool>`; if `overrideWith` does not typecheck against the autoDispose form, use the override style already used elsewhere in this test file for autoDispose providers.

- [ ] **Step 2: Run the tests to verify they fail**

```bash
flutter test test/features/media_store/media_storage_page_test.dart
```

Expected: the two new tests fail (no widget with key `media-quality-transcoder-hint`), and the two renamed Linux tests fail for the same reason.

- [ ] **Step 3: Add the generic string to all 11 locales**

Append to `lib/l10n/arb/app_en.arb`:

```json
  "settings_mediaStorage_quality_noTranscoderHint": "This device cannot compress video. Originals are uploaded from it."
```

And to each other locale:

- `app_ar.arb`: `"لا يمكن لهذا الجهاز ضغط الفيديو. يتم رفع الملفات الأصلية منه."`
- `app_de.arb`: `"Dieses Gerät kann keine Videos komprimieren. Von ihm werden Originale hochgeladen."`
- `app_es.arb`: `"Este dispositivo no puede comprimir vídeo. Desde él se suben los originales."`
- `app_fr.arb`: `"Cet appareil ne peut pas compresser la vidéo. Les originaux sont téléversés depuis celui-ci."`
- `app_he.arb`: `"מכשיר זה אינו יכול לדחוס וידאו. ממנו מועלים הקבצים המקוריים."`
- `app_hu.arb`: `"Ez az eszköz nem tud videót tömöríteni. Róla az eredetik töltődnek fel."`
- `app_it.arb`: `"Questo dispositivo non può comprimere i video. Da esso vengono caricati gli originali."`
- `app_nl.arb`: `"Dit apparaat kan geen video comprimeren. Vanaf dit apparaat worden originelen geüpload."`
- `app_pt.arb`: `"Este dispositivo não consegue comprimir vídeo. A partir dele são enviados os originais."`
- `app_zh.arb`: `"此设备无法压缩视频。将从此设备上传原始文件。"`

Then:

```bash
flutter gen-l10n
```

- [ ] **Step 4: Generalize the condition**

Replace lines 693-706 of `media_storage_page.dart` with:

```dart
                // A library-wide level can be set from a device that cannot
                // honour it, so this note is not Linux-specific: any device
                // without a working engine uploads originals. Only the remedy
                // differs, which is why the copy branches but the condition
                // does not.
                if (videoQuality != null &&
                    videoQuality != MediaUploadQuality.original &&
                    !(ref.watch(videoTranscodeAvailableProvider).value ?? true))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      ref.watch(isLinuxPlatformProvider)
                          ? l10n.settings_mediaStorage_quality_linuxFfmpegHint
                          : l10n
                                .settings_mediaStorage_quality_noTranscoderHint,
                      key: const Key('media-quality-transcoder-hint'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
```

The `?? true` default is deliberate: while availability is still resolving, assume the device is capable and show nothing, rather than flashing a warning that then disappears.

- [ ] **Step 5: Run the tests to verify they pass**

```bash
flutter test test/features/media_store/media_storage_page_test.dart
```

Expected: PASS, including both renamed Linux hint tests.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(media-store): show the transcode hint on any incapable device

The Linux gate was correct while quality was per-device: only a Linux user
could pick a level their own machine could not honour. A library-wide setting
breaks that, so the condition is now platform-agnostic and only the remedy
copy branches."
```

---

### Task 7: Prove the keys actually sync

The whole feature rests on the two keys not being filtered as device-local. One assertion guards it against a future addition to `_deviceLocalSettingsKeys`.

**Files:**
- Modify: `test/core/services/sync/sync_device_local_settings_test.dart`

**Interfaces:**
- Consumes: `MediaUploadQualityPolicy.photoQualityKey` / `videoQualityKey` from Task 2.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write the test**

Add to `test/core/services/sync/sync_device_local_settings_test.dart`, inside the existing `Sync excludes device-local settings keys` group. This mirrors the neighbouring `active_diver_id` test exactly: perform a real sync, then read the uploaded payload back out of the fake cloud provider via the `cloudBasePayload` helper.

```dart
    // The upload-quality keys are library-wide, not device-local: if a future
    // change adds them to _deviceLocalSettingsKeys, every device silently goes
    // back to deciding fidelity on its own and the library becomes
    // inconsistent again. This is the tripwire for that.
    test('media upload quality keys ARE present in the synced payload', () async {
      await AppSettingsRepository().setRawSetting(
        MediaUploadQualityPolicy.photoQualityKey,
        'balanced',
      );
      await AppSettingsRepository().setRawSetting(
        MediaUploadQualityPolicy.videoQualityKey,
        'small',
      );

      final deviceId = await SyncRepository().getDeviceId();
      await buildService().performSync();

      final payload = await cloudBasePayload(cloud, deviceId);
      final exportedKeys = payload!.data.settings.map((s) => s['key']).toSet();

      expect(
        exportedKeys,
        contains(MediaUploadQualityPolicy.photoQualityKey),
        reason: 'upload quality is library-wide and must sync',
      );
      expect(
        exportedKeys,
        contains(MediaUploadQualityPolicy.videoQualityKey),
        reason: 'upload quality is library-wide and must sync',
      );
    });
```

`cloud` and `buildService()` are already in scope from the group's `setUp` and its local helper. Add these imports:

```dart
import 'package:submersion/core/services/media_store/media_upload_quality_policy.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
```

- [ ] **Step 2: Run the test**

```bash
flutter test test/core/services/sync/sync_device_local_settings_test.dart
```

Expected: PASS immediately. This test documents existing correct behaviour rather than driving new code -- `_deviceLocalSettingsKeys` contains only `active_diver_id`, so the keys already export. If it FAILS, stop: something filters the keys and the design assumption is wrong.

- [ ] **Step 3: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add test/core/services/sync/sync_device_local_settings_test.dart
git commit -m "test(sync): assert upload quality keys are not device-local

Tripwire for the assumption the whole feature rests on: if these keys are ever
added to _deviceLocalSettingsKeys, devices silently go back to deciding
fidelity independently."
```

---

### Task 8: Full verification and pull request

**Files:** none modified except any formatting churn.

- [ ] **Step 1: Format the whole project**

```bash
dart format .
```

Expected: `0 changed`. If files change, commit them before continuing.

- [ ] **Step 2: Analyze the whole project**

```bash
flutter analyze
```

Expected: `No issues found!`. Do not pipe this through `tail` or `head` -- doing so masks the exit code and has hidden real failures before.

- [ ] **Step 3: Run the full test suite**

```bash
flutter test
```

Expected: PASS. Known order-dependent flakes exist in the backup suite (`backup_service_replace_test`, `setup_apply_service`) that pass in isolation. If one fails, re-run that file alone to confirm it is pre-existing and unrelated before proceeding; do not "fix" it as part of this work.

- [ ] **Step 4: Confirm no schema change slipped in**

```bash
git diff main --stat -- lib/core/database/
```

Expected: empty. Any output here means a migration or version bump was added, which this plan explicitly forbids.

- [ ] **Step 5: Push and open the pull request**

```bash
git push -u origin worktree-synced-media-upload-quality
```

Open the PR against `main` with a description covering: the problem (device-local input, synced outcome), the fidelity-loss scenario, the device-local vs library-wide split, and that there is no schema migration. Do not include Claude Code attribution or a session link.

## Notes for the implementer

- **`_tryParseQuality` is unchanged.** The pipeline's tolerant parse of per-item override levels stays exactly as it is; it now falls back to the library level rather than the device level, which requires no code change.
- **Do not add a per-device override.** The per-item `override_level` column in `media_transfer_queue` already covers "upload this one differently" and is the reason a device-level override was rejected.
- **Do not write preference-migration code.** Phase A has not shipped, so no user holds a stored value. Orphaned `media_store_photo_quality` / `media_store_video_quality` preference keys on development machines are harmless.
- **The consumer sweep is already scoped.** Adding provider dependencies to a widget silently breaks other tests that pump it without overrides, and `flutter analyze` will not catch it. `grep -rln "MediaStoragePage" test/` returns exactly one file (`test/features/media_store/media_storage_page_test.dart`), which Tasks 5 and 6 update. Re-run that grep before Task 5 in case a new consumer landed on `main` in the meantime.
- **An open settings page will not live-update on incoming sync.** This is a deliberate, documented limitation matching `shareByDefaultProvider`; the page refreshes on re-entry and the pipeline always reads fresh at upload time. Do not add a `SyncEventBus` listener.
