# Media Sync Slice 9: Limited Photo Access and Origin Re-resolution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On the device that linked a photo, nothing is ever called missing because the app could not see it: limited photo access, a lost Android read grant or a failed gallery query is inconclusive, and a photo that is really in the library is found again by metadata before anything is `notFound`.

**Architecture:** `AssetResolutionService` reads permission without prompting, and under limited access reports a failed search as `accessDenied` flagged `limitedAccess`, caching nothing. It gains `findInLibrary`, the metadata search without a stored asset id, which `LocalFileResolver` runs when an Android content URI cannot be read; a lost grant that the search does not recover is `accessDenied`. The full-screen viewer and the info panel offer "Allow full access" (system settings) and "Choose photo again" (the system's limited-selection sheet).

**Tech Stack:** Flutter, Dart, `photo_manager` 3.12.0 (`getPermissionState`, `openSetting`, `presentLimited`), Riverpod, `flutter_test`, mockito, the two-device media harness.

**Spec:** `docs/superpowers/specs/2026-09-18-media-sync-program-design.md`, section 6.3. Sub-issue #2121, part of #2090. Refs #1625 (spec 10: it closes on the reporter's or the hardware pass's confirmation). Turns scenario S7 green.

## Global Constraints

- Owner decisions (2026-09-23):
  - The actions appear in the full-screen viewer and the media info panel. Grid tiles show a distinct placeholder with no buttons.
  - "Choose photo again" opens the system's limited-selection sheet (`PhotoManager.presentLimited`); the row keeps its link.
  - A lost Android content-URI grant on the linking device searches the photo library by the metadata tiers; if nothing matches it is `accessDenied`, never `notFound`.
  - Tile resolution reads photo permission without prompting. The OS prompt comes only from the picker and the "Allow full access" button.
- `notFound` is the only verdict that orphans a row, and the orphan flag syncs (spec 3.2). `accessDenied` writes nothing (`reconciledOrphanFlag`, the verifier, the sweep).
- Every background path that consults the photo library checks `supportsGalleryBrowsing` first (spec 9).
- New user-facing strings are added to all 11 ARB files, then `flutter gen-l10n`.
- Repository rules: no em-dashes; no mention of Claude, Claude Code or Anthropic in commits, PRs or comments; no emojis in code; `dart format .` before every commit; paths through `p.join`, never a literal `/tmp`.

## Facts the design rests on

- `PhotoPickerServiceMobile.checkPermission` is `PhotoManager.requestPermissionExtend`, which prompts when access was never decided. `currentPermission` (`getPermissionState`) reads without asking but is not on the `PhotoPickerService` interface. `AssetResolutionService._resolveFromGallery` calls `checkPermission` from every cold resolution, including thumbnail renders.
- `_resolveFromGallery` admits `limited` as full access. Under limited access a photo outside the selection is invisible, the search finds nothing, `unresolved` is cached, and on the linking device `PlatformGalleryResolver._missing` turns that into `notFound` (S7).
- A gallery query that throws returns `unavailable` (uncached), which on the linking device is also `notFound`.
- `checkPermission` throws are already logged under `LogCategory.media` (`AssetResolutionService._log`), but without the stack trace.
- `LocalMediaHandler.readUriBytes` (Kotlin) reports a `SecurityException` as `PlatformException(code: 'PERMISSION_DENIED')` and any other failure as `READ_FAILED`. `LocalFileResolver` ignores the code and returns `notFound` for both, behind a hard `Platform.isAndroid` gate that keeps the branch out of every test.
- `LocalFileResolver.verify` maps any unavailable kind it does not list to `VerifyResult.notFound`.
- `UnavailableMediaPlaceholder` has no actions; `MediaItemView` wraps only `stillFetching` in a tap handler. The viewer renders `MediaItemView(item: item, fit: BoxFit.contain)` (`media_viewer_page.dart`). The info panel's `_OriginSection` builds its actions from `OriginFacts.health`, which comes from the stored orphan flag.

## File Structure

- Modify `lib/features/media/data/services/photo_picker_service.dart`, `photo_picker_service_mobile.dart`, `photo_picker_service_desktop.dart`, `test/helpers/fake_photo_picker_service.dart`: `currentPermission` on the interface.
- Modify `lib/features/media/data/services/asset_resolution_service.dart`: read-only permission, limited verdict, query failure as `accessDenied`, `findInLibrary`.
- Modify `lib/features/media/domain/value_objects/media_source_data.dart`: `UnavailableData.limitedAccess`.
- Modify `lib/features/media/data/resolvers/platform_gallery_resolver.dart`: pass `limitedAccess` through.
- Modify `lib/features/media/data/resolvers/local_file_resolver.dart` and `lib/features/media/presentation/providers/media_resolver_providers.dart`: the lost-grant search.
- Create `lib/features/media/data/services/photo_access_actions.dart`, `lib/features/media/presentation/providers/photo_access_providers.dart`, `lib/features/media/presentation/widgets/limited_access_actions.dart`.
- Modify `unavailable_media_placeholder.dart`, `media_item_view.dart`, `media_viewer_page.dart`, `media_info_panel.dart`, the 11 ARB files.
- Modify `lib/features/media/presentation/providers/gallery_origin_backfill_provider.dart`: use the interface's `currentPermission`.

---

### Task 1: Resolution never prompts, and a failed query is inconclusive

**Files:** `photo_picker_service.dart`, `photo_picker_service_mobile.dart`, `photo_picker_service_desktop.dart`, `fake_photo_picker_service.dart`, `asset_resolution_service.dart`, `gallery_origin_backfill_provider.dart`; tests `test/features/media/data/services/asset_resolution_service_test.dart` and a new `test/features/media/data/services/asset_resolution_permission_test.dart`.

**Interfaces:** Produces `Future<PhotoPermissionStatus> PhotoPickerService.currentPermission()`.

- [ ] **Step 1: Failing tests.** New `asset_resolution_permission_test.dart`, over `FakePhotoPickerService` and an in-memory `LocalAssetCacheRepository`, with the fake counting `checkPermission`/`requestPermission` calls (add `int prompts` to the fake, incremented by both):
  - `resolution reads permission and never prompts`: a row whose id does not load, permission `authorized`, one matching candidate; after `resolveAssetId`, `library.prompts == 0`.
  - `a gallery query that fails is inconclusive, never unavailable`: the fake's `getAssetsInDateRange` throws (add `Object? queryError`); the result is `ResolutionStatus.accessDenied`, and no cache entry exists.
- [ ] **Step 2: Run, see them fail** (`currentPermission` missing; the query failure is `unavailable`).
- [ ] **Step 3: Implement.**
  - Interface: `/// The current photo access, read without asking. ... Future<PhotoPermissionStatus> currentPermission();` Mobile: add `@override` to the existing method. Desktop: `@override Future<PhotoPermissionStatus> currentPermission() async => PhotoPermissionStatus.authorized;` Fake: returns `permission`.
  - `_resolveFromGallery`: `permission = await _photoPickerService.currentPermission();` and the catch becomes `on Object catch (e, stackTrace)` logging `_log.error('Permission check failed for media ${item.id}', error: e, stackTrace: stackTrace)` (still `accessDenied`, still uncached). Comment: a tile render must never show the OS prompt; the picker and the "Allow full access" button are where access is asked for.
  - The query catch returns `const ResolutionResult(status: ResolutionStatus.accessDenied)` with a comment: the gallery could not be consulted, which is not evidence of absence, and on the linking device `unavailable` would orphan the row.
  - `gallery_origin_backfill_provider.dart`: `permissionStatus: photos.currentPermission` (drop the `is PhotoPickerServiceMobile` branch and its import if unused).
  - `asset_resolution_service_test.dart` (mockito): regenerate mocks, and change every `when(mockPicker.checkPermission())` to `currentPermission()`; the existing "permission check throws" test now stubs `currentPermission` to throw.
- [ ] **Step 4: Run** `flutter test test/features/media` **; expect PASS.**
- [ ] **Step 5: Commit** `fix(media): gallery resolution reads photo access without prompting`.

### Task 2: Limited access is inconclusive (S7)

**Files:** `media_source_data.dart`, `asset_resolution_service.dart`, `platform_gallery_resolver.dart`, `resolution_scenarios_test.dart`; tests in `asset_resolution_permission_test.dart` and `test/features/media/data/resolvers/platform_gallery_resolver_test.dart`.

**Interfaces:** Produces `ResolutionResult.limitedAccess` (`bool`, default false) and `UnavailableData.limitedAccess` (`bool`, default false).

- [ ] **Step 1: Failing tests.**
  - `asset_resolution_permission_test.dart`: `under limited access a photo outside the selection is inconclusive`: the asset is in the fake library but in `hiddenFromLimitedAccess`, permission `limited`; result `accessDenied` with `limitedAccess` true; `getCacheEntry` is null. `under limited access a photo in the selection still resolves`: same with the asset visible; result `resolved`.
  - `platform_gallery_resolver_test.dart`: its fake resolution service returns `ResolutionResult(status: accessDenied, limitedAccess: true)`; `resolve` returns `UnavailableData` with `kind == accessDenied` and `limitedAccess` true; so does `resolveThumbnail`.
  - Remove `skip:` from S7 in `resolution_scenarios_test.dart`, and add `expect((tile.data as UnavailableData).limitedAccess, isTrue);` after its kind assertion.
- [ ] **Step 2: Run, see them fail.**
- [ ] **Step 3: Implement.**
  - `ResolutionResult({this.localAssetId, required this.status, this.limitedAccess = false})` with a doc: the gallery was searched through a limited selection, so a miss may be a photo the user did not select.
  - `UnavailableData` gains `this.limitedAccess = false` and a doc: only with `accessDenied`; the photo may be in the library but outside what the user allowed.
  - `_resolveFromGallery`: after the permission gate, `final limited = permission == PhotoPermissionStatus.limited;`. At both "not found" exits (no candidates, and after tier 3), `if (limited) return const ResolutionResult(status: ResolutionStatus.accessDenied, limitedAccess: true);` before `_cacheUnresolved`, with a comment: a limited selection hides photos the device does have, so a miss is not evidence of absence, and caching it would back off a photo the user can make visible in a moment.
  - `PlatformGalleryResolver`: the three `accessDenied` mappings pass `limitedAccess: resolution.limitedAccess` (the thumbnail path keeps the re-derived result, not just its status).
- [ ] **Step 4: Run** `flutter test test/features/media` **; expect PASS, S7 green.**
- [ ] **Step 5: Commit** `fix(media): limited photo access is inconclusive, not missing`.

### Task 3: A lost Android read grant searches the library first

**Files:** `asset_resolution_service.dart`, `local_file_resolver.dart`, `media_resolver_providers.dart`; tests in `asset_resolution_permission_test.dart` and a new `test/features/media/data/resolvers/local_file_resolver_content_uri_test.dart`.

**Interfaces:** Produces `Future<ResolutionResult> AssetResolutionService.findInLibrary(MediaItem item)`; `LocalFileResolver({..., bool Function()? readsContentUris, Future<MediaSourceData?> Function(MediaItem item)? findInLibrary})`.

- [ ] **Step 1: Failing tests.**
  - `asset_resolution_permission_test.dart`: `findInLibrary matches a row with no asset id by metadata`: a `localFile` row (no `platformAssetId`, filename and time of an asset in the fake library); result `resolved` with that asset's id. `findInLibrary under limited access is inconclusive`.
  - `local_file_resolver_content_uri_test.dart`, with a `LocalMediaPlatform` subclass whose `readUriBytes` throws a given `PlatformException`, `readsContentUris: () => true`, a row with a `bookmarkRef` and no path, `localDeviceId: () async => 'me'`, origin `'me'`:
    - `a lost grant the library search recovers serves the photo` (`findInLibrary` returns `BytesData`).
    - `a lost grant the search cannot recover is inconclusive` (`PERMISSION_DENIED`, search returns null): `accessDenied`.
    - `a failed read the search cannot recover is notFound` (`READ_FAILED`).
    - `another device's content URI is not searched` (origin `'peer'`): `fromOtherDevice`, and the search was not called.
    - `verify reports a lost grant as accessDenied` (`VerifyResult.accessDenied`).
- [ ] **Step 2: Run, see them fail.**
- [ ] **Step 3: Implement.**
  - `AssetResolutionService`: split `_resolveFromGallery` after the original-id probe into `_searchGallery(MediaItem item)` (the permission gate, candidates and tiers). Add `findInLibrary(item)`: the no-gallery guard (`unavailable`), the cache hit and unexpired-backoff checks exactly as `resolveAssetId` has them, the same in-flight de-duplication, then `_searchGallery`. Doc: finds a row that has no usable stored asset id (a file whose read grant was lost) by the metadata tiers alone.
  - `LocalFileResolver`: `_readsContentUris = readsContentUris ?? (() => Platform.isAndroid)` replaces the `Platform.isAndroid` gate, and the `coverage:ignore` markers around the branch go. The catch classifies `final grantLost = e is PlatformException && e.code == 'PERMISSION_DENIED';` and returns `await _afterFailedUriRead(item, grantLost: grantLost)`:
    ```dart
    /// A content URI that did not read, on this device (spec 6.3). Another
    /// device's URI never had a grant here, so it is left to [resolve]'s
    /// origin rule. Otherwise the library is searched by metadata before
    /// anything is decided: a re-indexed or moved photo is usually still
    /// there. A lost grant the search cannot recover is inconclusive, since
    /// the file may be exactly where it was.
    Future<MediaSourceData> _afterFailedUriRead(
      MediaItem item, {
      required bool grantLost,
    }) async {
      if (await _importedElsewhere(item)) {
        return const UnavailableData(kind: UnavailableKind.notFound);
      }
      final search = _findInLibrary;
      if (search != null) {
        try {
          final found = await search(item);
          if (found != null) return found;
        } on Object catch (e) {
          _log.warning('Library search for ${item.id} failed', error: e);
        }
      }
      return UnavailableData(
        kind: grantLost ? UnavailableKind.accessDenied : UnavailableKind.notFound,
      );
    }
    ```
  - `verify`: `if (data.kind == UnavailableKind.accessDenied) return VerifyResult.accessDenied;` before the local-path check, with a comment.
  - `media_resolver_providers.dart`, `LocalFileResolver(...)`: `findInLibrary: (item) async { final r = await ref.read(assetResolutionServiceProvider).findInLibrary(item); final id = r.localAssetId; if (id == null) return null; final bytes = await const PhotoManagerAssetReader().originBytes(id); return bytes == null ? null : BytesData(bytes: bytes, servedFrom: ServedFrom.platformGallery); }`.
- [ ] **Step 4: Run** `flutter test test/features/media` **; expect PASS.**
- [ ] **Step 5: Commit** `fix(media): a lost Android read grant searches the library before anything is missing`.

### Task 4: "Allow full access" and "Choose photo again"

**Files:** create `photo_access_actions.dart`, `photo_access_providers.dart`, `limited_access_actions.dart`; modify `unavailable_media_placeholder.dart`, `media_item_view.dart`, `media_viewer_page.dart`, `media_info_panel.dart`, 11 ARB files; tests `test/features/media/presentation/widgets/limited_access_actions_test.dart`, `unavailable_media_placeholder_test.dart`, `media_info_panel_test.dart` (or the panel's existing test file).

**Interfaces:** `abstract interface class PhotoAccessActions { Future<void> openSettings(); Future<void> chooseMorePhotos(); }`, `PhotoManagerAccessActions` (production); `photoAccessActionsProvider`; `galleryAccessLimitedProvider` (`FutureProvider.autoDispose<bool>`, `currentPermission() == limited`, false where `supportsGalleryBrowsing` is false or on error); `LimitedAccessActions({required VoidCallback onChanged})`; `MediaItemView({..., bool showAccessActions = false})`.

- [ ] **Step 1: ARB keys** in all 11 files (English values; translate for the others):
  - `media_unavailablePlaceholder_limitedAccess`: "Not in your allowed photos"
  - `media_limitedAccess_allowFullAccess`: "Allow full access"
  - `media_limitedAccess_choosePhotoAgain`: "Choose photo again"
  Insert in `app_en.arb` alphabetically; in the other files next to `media_unavailablePlaceholder_accessDenied`. Run `flutter gen-l10n`.
- [ ] **Step 2: Failing tests.**
  - Placeholder: `accessDenied` with `limitedAccess` shows the limited message; without, the old one.
  - `LimitedAccessActions` with a fake `PhotoAccessActions` override: tapping each button calls its action once and then `onChanged`.
  - `MediaItemView` with `showAccessActions: true` and a registry answering `UnavailableData(kind: accessDenied, limitedAccess: true)` shows both buttons; with `false` (a grid tile) shows neither.
  - Info panel: a `platformGallery` row with `galleryAccessLimitedProvider` overridden to true shows both buttons; false, neither; a `localFile` row, neither.
- [ ] **Step 3: Implement.**
  - `PhotoManagerAccessActions`: `openSettings` is `PhotoManager.openSetting()`; `chooseMorePhotos` is `PhotoManager.presentLimited()`.
  - `LimitedAccessActions`: a `Wrap` of two `TextButton`s; each awaits its action in a try/catch (a platform failure is logged under media, never thrown) and calls `onChanged` if still mounted.
  - Placeholder: `accessDenied` with `limitedAccess` uses `Icons.photo_library_outlined` and the new message.
  - `MediaItemView`: a new arm before the generic `UnavailableData()`: `UnavailableData(kind: UnavailableKind.accessDenied, limitedAccess: true) when widget.showAccessActions => Column(mainAxisSize: MainAxisSize.min, children: [Expanded(child: UnavailableMediaPlaceholder(data: data)), LimitedAccessActions(onChanged: _retry)])` (check the parent gives bounded height; the viewer does).
  - Viewer: `MediaItemView(item: item, fit: BoxFit.contain, showAccessActions: true)`.
  - Info panel `_OriginSection.actions`: `if (origin.sourceType == MediaSourceType.platformGallery && ref.watch(galleryAccessLimitedProvider).value == true) ...[` the two buttons `]`, each invalidating `galleryAccessLimitedProvider` and `mediaByIdProvider(item.id)` after its action.
- [ ] **Step 4: Run** `flutter test test/features/media test/l10n` **(and the l10n staleness check); expect PASS.**
- [ ] **Step 5: Commit** `feat(media): offer full access and the photo selection where a photo is out of reach`.

### Task 5: Spec notes and verification

- [ ] Append the decisions above to spec 6.3; add "As executed" notes to this plan.
- [ ] Mutation-check each guard (limited exits, query-failure verdict, `currentPermission` in resolution, the grant-lost classification, the peer-row skip, `verify`'s mapping, the actions' `showAccessActions` gate, the info panel's source-type gate). Each mutation must compile and fail its named test.
- [ ] `dart format .`, `flutter analyze`, `flutter test`, and `test/architecture` explicitly.
- [ ] Commit `docs(spec): record slice 9's decisions in 6.3`. PR body: `Closes #2121`, `Refs #1625`, `Part of #2090`.

## Execution notes (2026-09-23)

- Task 1: adding `currentPermission` to `PhotoPickerService` meant a one-line override in ten hand-written test fakes that `implement` it (the two that extend `Fake` needed none); each returns what its `checkPermission` does, so their behaviour is unchanged. The mockito stubs in `asset_resolution_service_test.dart` moved to `currentPermission`.
- Task 2: under limited access both "not found" exits return `accessDenied` flagged `limitedAccess` (the no-candidates exit and the one after tier 3), each with its own test. The thumbnail path in `PlatformGalleryResolver` keeps the re-derived result, not just its status.
- Task 3: the Android branch of `LocalFileResolver` is now behind an injectable `readsContentUris`, so it runs in the Linux test shards instead of being `coverage:ignore`d.
- Task 4: the info panel reuses `LimitedAccessActions` inside its actions `Wrap`. The panel's `galleryAccessLimitedProvider` swallows a platform failure as false, so the existing panel tests, which do not override it, are unchanged.
- Mutation pass: 12 mutations, each compiling and failing its named test: the non-prompting read, the query-failure verdict, both limited exits (S7 and the tier-3 test), the resolver's pass-through, the grant-lost classification, the peer-row skip, serving a recovered photo, `verify`'s mapping, the viewer-only actions gate, the panel's gallery-only gate, and the limited placeholder message.

- Review round (PR #2313): a cached mapping whose asset stops reading is re-searched in `resolve` and `verify` before `_missing`, keeping an inconclusive answer; the lost-grant search maps its result through `librarySearchOutcome`, so a search that could not look stays `accessDenied` instead of collapsing to null (and then `notFound`); the site media viewer passes `showAccessActions`; and "Allow full access" refreshes when the app resumes, since opening the settings returns at once. Seven more mutations, each compiling and failing its named test.
