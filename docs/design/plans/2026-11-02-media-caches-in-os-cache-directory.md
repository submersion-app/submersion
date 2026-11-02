# Media caches in the OS cache directory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On iOS and Android, keep the media pools, video posters and PDF renders in the OS cache directory, move what is already there on upgrade, and keep working when the OS purges them.

**Architecture:** One `CacheLocation` value says where every regenerable cache lives on this platform, and every reader takes its paths from it. Resolving it moves any old directories first, so nothing can write to the new location before the move. `MediaCacheStore` gains a scratch root, and two small additions keep the index honest after a purge.

**Tech Stack:** Flutter, Drift (`LocalCacheDatabase`), path_provider, Riverpod.

**Spec:** `docs/design/specs/2026-11-02-media-caches-in-os-cache-directory-design.md`

## Global Constraints

- iOS and Android only. On desktop, every path and behaviour stays as it is today.
- Moved: `thumbs`, `originals`, `renditions`, `video_thumbnails`, `pdf_thumbnails`. Stay in application support: `staging`, `transcode`, `submersion_local.db`.
- `relativePath` values in `media_cache_entries` keep their current form (`thumbs/ab/abc.jpg`).
- No schema change, no new UI, no new strings, no change to `StorageGcCoordinator`.
- Nothing on the `put` path may check files row by row. One stat per pool is the limit.
- The new sweep returns `ScratchSweepReport.empty`: removing a row reclaims no bytes.
- Paths are built with `p.join`, and tests use `Directory.systemTemp`.

## Review Focus

- A new location that already has files when an old directory is found (a partly finished earlier move): the old one goes, the new one is kept.
- A cache lookup that fails at boot: the old directories are untouched and the next caller retries.
- A pool purged to empty files but with its directory left behind (Android trimming): `totalBytes` cannot see it, and the daily sweep must clear it.
- One pool gone and another intact: only the gone pool's rows are removed.
- "Empty cache" or a purge while an upload is staging: `clear` and purges must not reach the scratch root.

---

### Task 1: CacheLocation and the upgrade move

**Files:**
- Create: `lib/core/services/storage/cache_location.dart`
- Test: `test/core/services/storage/cache_location_test.dart`

**Interfaces:**
- Produces:
  - `class CacheLocation` with `const CacheLocation({required Directory regenerableBase, required Directory supportBase, required bool osManagesCaches})` and getters `Directory get mediaPools`, `Directory get mediaScratch`, `Directory get videoThumbnails`, `Directory get pdfThumbnails`, `bool get osManagesCaches`. `regenerableBase` and `supportBase` are the `<...>/Submersion` directories. `mediaPools` is `<regenerableBase>/media_cache`, `mediaScratch` is `<supportBase>/media_cache`, the other two sit directly under `regenerableBase`.
  - `Future<CacheLocation> resolveCacheLocation({required bool osManagesCaches, required Future<Directory> Function() cacheDirectory, required Future<Directory> Function() supportDirectory})`. Calls `cacheDirectory` only when `osManagesCaches`.
  - `Future<List<Directory>> moveCachesToOsDirectory(CacheLocation location)`: returns the old directories it could not rename. A no-op returning `[]` when `!location.osManagesCaches`.
  - `Future<void> deleteLeftoverCaches(List<Directory> leftovers)`: best effort, never throws.
  - `Future<CacheLocation> cacheLocation()`: memoized for the process. Wires `Platform.isIOS || Platform.isAndroid`, `getApplicationCacheDirectory` and `getApplicationSupportDirectory`, awaits the move, and hands leftovers to `unawaited(deleteLeftoverCaches(...))`. A failed lookup is not memoized.
  - `@visibleForTesting void resetCacheLocationForTesting()`.

- [ ] **Step 1: Write the failing tests**

```dart
test('phones keep regenerable caches under the cache directory', ...);
// mediaPools == <cache>/Submersion/media_cache
// mediaScratch == <support>/Submersion/media_cache
// videoThumbnails == <cache>/Submersion/video_thumbnails
// pdfThumbnails == <cache>/Submersion/pdf_thumbnails

test('desktop keeps everything under support and never asks for the cache directory', ...);
// cacheDirectory closure throws if called; mediaPools == mediaScratch

test('moves all five directories, keeping their contents', ...);
// thumbs/ab/abc.jpg, originals/x, renditions/y, video_thumbnails/a, pdf_thumbnails/b
// each exists at the new path with its bytes, and is gone from the old path;
// returned list is empty

test('leaves staging and transcode where they are', ...);

test('a second run is a no-op', ...);

test('does nothing on desktop', ...);

test('an old pool whose new location already has files is returned as a leftover', ...);
// new thumbs/keep.jpg exists, old thumbs/old.jpg exists.
// result == [old thumbs]; new keep.jpg still there.
// after deleteLeftoverCaches: old thumbs gone, the other four moved

test('deleteLeftoverCaches ignores a directory that has already gone', ...);

test('cacheLocation resolves once across many callers', ...);
// fake path provider with a counter, as in media_cache_root_test.dart

test('a failed lookup is not cached and moves nothing', ...);
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/services/storage/cache_location_test.dart`
Expected: FAIL, `cache_location.dart` does not exist.

- [ ] **Step 3: Implement `lib/core/services/storage/cache_location.dart`**

The old pools are `<supportBase>/media_cache/{thumbs,originals,renditions}` and `<supportBase>/{video_thumbnails,pdf_thumbnails}`. For each pair: skip when the old directory does not exist, create the destination's parent, then `Directory.rename`. A `FileSystemException` adds the old directory to the returned list and logs through `LoggerService.forClass`. One failure must not stop the others.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/services/storage/cache_location_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/storage/cache_location.dart test/core/services/storage/cache_location_test.dart
git commit -m "feat(media): add the cache location and the upgrade move"
```

### Task 2: MediaCacheStore across two roots, and an honest index

**Files:**
- Modify: `lib/features/media_store/data/media_cache_store.dart`
- Test: `test/features/media_store/media_cache_store_location_test.dart` (create)

**Interfaces:**
- Produces:
  - `MediaCacheStore({..., required Directory root, Directory? scratchRoot, ...})`. `scratchRoot` defaults to `root`.
  - `stagingFile`, `transcodeFile` and `deleteTranscodeArtifacts` use the scratch root. Everything else keeps using `root`.
  - `totalBytes(kind)`: when the pool directory does not exist, deletes that kind's rows, clears `_touches` for thumbs, and returns 0. A `FileSystemException` from the existence check counts as present, so doubt never deletes rows.
  - `Future<int> dropMissingEntries({int pageSize = 500})`: for each kind, removes rows whose file is gone and returns how many.

- [ ] **Step 1: Write the failing tests**

```dart
test('staging and transcode files live under the scratch root', ...);
test('without a scratch root they stay under root', ...);
test('put moves a staged file across the two roots and indexes it', ...);
// relativePath == p.join('thumbs', key.substring(0, 2), '$key.jpg')
test('clear leaves the scratch root alone', ...);
// a staged file and a transcode file survive clear(thumb)

test('a pool whose directory has gone reads as empty and loses its rows', ...);
test('only the gone pool loses its rows', ...);
// thumbs directory deleted, originals intact: originals total unchanged
test('a put after a purge starts from a true total and evicts nothing real', ...);
// fill to the cap, delete thumbs dir, put one: that file exists and total == its size
test('a pool whose directory exists is left alone', ...);

test('dropMissingEntries removes only rows whose file has gone, in every pool', ...);
test('dropMissingEntries clears a pool emptied with its directory left behind', ...);
test('dropMissingEntries visits every row across pages', ...);
// pageSize: 2 with five rows, of which three are dead
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/media_store/media_cache_store_location_test.dart`
Expected: FAIL, no `scratchRoot` parameter.

- [ ] **Step 3: Implement the changes in `media_cache_store.dart`**

`dropMissingEntries` pages by key, not offset, because it deletes as it goes: for each kind, select `contentHash` and `relativePath` where `contentHash > last`, ordered by `contentHash`, limited to `pageSize`. Await an async `File.exists` per row, then delete the page's dead rows with `contentHash.isIn(...)` for that kind. Update the class comment to say the pools and scratch may sit on different roots.

- [ ] **Step 4: Run the new tests and the existing store tests**

Run: `flutter test test/features/media_store/media_cache_store_location_test.dart test/features/media_store/media_cache_store_test.dart test/features/media_store/media_cache_store_rendition_test.dart test/features/media_store/media_cache_store_transcode_test.dart`
Expected: PASS. A failure that seeds rows without files for a kind whose directory does not exist is a test that assumed the old behaviour: create the directory in that test's setup rather than weakening `totalBytes`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media_store/data/media_cache_store.dart test/features/media_store/media_cache_store_location_test.dart
git commit -m "feat(media): keep the media cache index honest after a purge"
```

### Task 3: Wire the media store and the thumbnail services

**Files:**
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart:106-161`
- Modify: `lib/features/media/presentation/providers/media_resolver_providers.dart:97-117`
- Test: `test/features/media_store/media_cache_root_test.dart`, `test/features/media/presentation/providers/media_cache_wiring_test.dart`

**Interfaces:**
- Consumes: `cacheLocation()`, `resetCacheLocationForTesting()`, `CacheLocation`, `MediaCacheStore.scratchRoot` from Tasks 1 and 2.
- Produces: `mediaCacheRoot()` returns `(await cacheLocation()).mediaPools`. `openMediaCacheStore` passes `root: location.mediaPools, scratchRoot: location.mediaScratch`. `resetMediaCacheRootForTesting()` stays and calls `resetCacheLocationForTesting()`.

- [ ] **Step 1: Write the failing test**

In `media_cache_wiring_test.dart`:

```dart
test('a store from openMediaCacheStore stages under the scratch root', ...);
// stagingFile().path is within <support>/Submersion/media_cache/staging
```

The test host is desktop, so this pins the desktop path only. Task 6's device check is what proves the phone paths.

- [ ] **Step 2: Implement the wiring**

Remove `_mediaCacheRootFuture` and `_resolveMediaCacheRoot`, since `cacheLocation()` now owns the memo and the failed-lookup rule; keep the reasoning in its doc comment. The `videoThumbnailServiceProvider` and `pdfThumbnailServiceProvider` `cacheDir` closures return `(await cacheLocation()).videoThumbnails` and `.pdfThumbnails`. Update the `_resolveCacheDir` comment in `video_thumbnail_service.dart`, which names `getApplicationSupportDirectory()`.

- [ ] **Step 3: Run the tests**

Run: `flutter test test/features/media_store/media_cache_root_test.dart test/features/media/presentation/providers/media_cache_wiring_test.dart test/features/media_store/media_cache_eviction_provider_test.dart`
Expected: PASS, with no change to `media_cache_root_test.dart`'s expectations.

- [ ] **Step 4: Commit**

```bash
git add lib/features/media_store/presentation/providers/media_store_providers.dart lib/features/media/presentation/providers/media_resolver_providers.dart lib/features/media/data/services/video_thumbnail_service.dart test/features/media/presentation/providers/media_cache_wiring_test.dart
git commit -m "feat(media): keep media caches in the OS cache directory on phones"
```

### Task 4: Storage inventory and scratch sweep follow the caches

**Files:**
- Modify: `lib/core/services/storage/storage_inventory.dart`, `lib/core/services/storage/scratch_sweep.dart`
- Modify: `lib/features/settings/presentation/providers/storage_usage_providers.dart`, `lib/features/settings/presentation/providers/storage_gc_providers.dart`
- Test: `test/core/services/storage/storage_inventory_test.dart`, `test/core/services/storage/scratch_sweep_test.dart`

**Interfaces:**
- Consumes: `CacheLocation` from Task 1.
- Produces:
  - `StorageInventory` gains `required Future<CacheLocation> Function() cacheLocation`. `supportDirectory` stays for the local cache database.
  - `StorageScratchSweep` replaces `supportDirectory` with `required Future<CacheLocation> Function() cacheLocation`.

- [ ] **Step 1: Update the two test helpers and add the failing tests**

Both `build()` helpers pass a desktop location over the existing `support` directory, so existing tests keep their meaning. Then add, with a phone location (`regenerableBase` under a separate `cache` directory):

```dart
test('measures video and PDF thumbnails in the OS cache directory', ...);
test('measures staging and transcode in application support', ...);
test('the temporary row does not count the caches under the temp root', ...);
// location with regenerableBase = <temporary>/Submersion, files under it,
// temporary category measures only picked + loose

test('sweeps old video and PDF thumbnails in the OS cache directory', ...);
test('sweeps staging and transcode in application support', ...);
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/services/storage/storage_inventory_test.dart test/core/services/storage/scratch_sweep_test.dart`
Expected: FAIL, no `cacheLocation` parameter.

- [ ] **Step 3: Implement**

Measure and sweep from `location.mediaScratch` (`staging`, `transcode`), `location.videoThumbnails` and `location.pdfThumbnails`. Replace `_measureSupportSubdirectory` with a helper that takes the directory. Pass `cacheLocation: cacheLocation` at both production call sites. Update the `StorageScratchSweep` class comment so it no longer implies one root.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/core/services/storage/ test/features/settings/presentation/providers/storage_usage_wiring_test.dart test/features/settings/presentation/providers/storage_gc_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/storage/storage_inventory.dart lib/core/services/storage/scratch_sweep.dart lib/features/settings/presentation/providers/storage_usage_providers.dart lib/features/settings/presentation/providers/storage_gc_providers.dart test/core/services/storage/storage_inventory_test.dart test/core/services/storage/scratch_sweep_test.dart
git commit -m "feat(storage): measure and sweep media caches where they now live"
```

### Task 5: Daily index cleanup and the backup comment

**Files:**
- Create: `lib/features/media_store/data/media_cache_index_sweep.dart`
- Modify: `lib/features/settings/presentation/providers/storage_gc_providers.dart:47-55`
- Modify: `lib/core/services/local_cache_database_service.dart:91-96`
- Test: `test/features/media_store/media_cache_index_sweep_test.dart`

**Interfaces:**
- Consumes: `MediaCacheStore.dropMissingEntries` (Task 2), `openMediaCacheStore`, `cacheLocation()`, `ScratchSweepReport`.
- Produces: `class MediaCacheIndexSweep` with `MediaCacheIndexSweep({required Future<bool> Function() osManagesCaches, required Future<MediaCacheStore> Function() store})` and `Future<ScratchSweepReport> run({required bool dryRun})`.

- [ ] **Step 1: Write the failing tests**

```dart
test('drops dead rows and reports nothing reclaimed', ...);
test('a dry run changes nothing', ...);
test('does nothing where the OS does not manage the caches', ...);
// store closure throws if called
test('a failure reaches the caller so the coordinator retries', ...);
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/media_store/media_cache_index_sweep_test.dart`
Expected: FAIL, the file does not exist.

- [ ] **Step 3: Implement the sweep and register it**

Add it to `deviceSweeps` after the two existing entries, with `osManagesCaches: () async => (await cacheLocation()).osManagesCaches` and `store: () => openMediaCacheStore(ref.read(sharedPreferencesProvider))`. `store` must be lazy so a dry run on the Storage page opens nothing.

Rewrite the `LocalCacheDatabaseService` note: application support is included in iOS device backups unless excluded, no exclusion is set, and that is acceptable for this small database. The caches that were large have moved out on phones.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/media_store/media_cache_index_sweep_test.dart test/features/settings/presentation/providers/storage_gc_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media_store/data/media_cache_index_sweep.dart lib/features/settings/presentation/providers/storage_gc_providers.dart lib/core/services/local_cache_database_service.dart test/features/media_store/media_cache_index_sweep_test.dart
git commit -m "feat(media): clear dead media cache rows in the daily cleanup"
```

### Task 6: Whole-branch checks and device verification

**Files:**
- Modify: the spec's "Platform claims to check" table only if a result differs from it.

- [ ] **Step 1: Run the whole-repo checks**

Run: `dart format lib test`, then `flutter analyze`, then `flutter test test/architecture/ test/features/media_store/ test/features/media/ test/core/services/storage/ test/features/settings/presentation/providers/`
Expected: no format changes left, `No issues found!`, all tests pass.

- [ ] **Step 2: Android emulator**

Boot `Medium_Phone_API_36.1`, build a debug APK from `main` for the upgrade and install it, link photos so the pools fill, then install this branch over it. Using `adb shell run-as app.submersion`, confirm:
- The old directories are gone and `cache/Submersion/media_cache/thumbs` holds the files.
- Tiles still draw and no thumbnails regenerate.

Then run `pm trim-caches 999G` and App Info "Clear cache", each with the app stopped and with it open, and record:
- Whether `thumbs` itself goes or stays empty. This decides whether `totalBytes`'s check fires, and the spec says a different result goes back to the maintainer.
- That tiles regenerate and the Storage usage page reads true.

- [ ] **Step 3: iOS simulator**

Install on the booted iPhone 17 Pro. Confirm the same paths under the app container, delete `Library/Caches/Submersion` with the app stopped, relaunch, and confirm recovery.

- [ ] **Step 4: macOS**

Confirm the live paths are unchanged, by the unit tests' desktop cases, without launching a debug build over the live database.

- [ ] **Step 5: Commit anything format or the checks changed**

```bash
git add lib test docs/design
git commit -m "chore(media): record device verification of the cache move"
```

Skip this step if nothing changed.
