# Media Section Phase 4 (Import with Auto-Match) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the console Import section: the existing three-tab picker opens with no dive context, imports land retained-in-library, and one batch confirmation screen links them to dives via the existing matcher.

**Architecture:** A new dive-less `importPhotosToLibrary` path on `MediaImportService` (rows get `retainInLibrary = true`, library-wide dedupe, no enrichment), a `MediaImportLinkPage` that reuses the Phase 2 `inboxSuggestionProvider` per imported id with confident matches pre-checked and applies via `reassignMediaToDive`, and a `MediaConsoleSection.importMedia` launcher pane. Spec: `docs/superpowers/specs/2026-08-05-media-section-design.md` section 9.

**Tech Stack:** Flutter 3.x, Drift, Riverpod (barrel), the existing `showPhotoPicker` / `MediaImportService` / `computeInboxSuggestion` machinery.

## Global Constraints

Identical to the Phase 1-3 plans (worktree-only + `pwd`, format no-op before commits, analyze zero issues, no emojis, l10n in en + ar de es fr he hu it nl pt zh + gen-l10n, Riverpod via barrel, `MaterialApp(locale: Locale('en'))` in widget tests, no Co-Authored-By). Phase 4 does NOT touch `dive_media_section.dart`, so the full suite runs once, in the final task. Facts locked in during research:

- `showPhotoPicker({context, diveStartTime, diveEndTime, buffer, alreadyLinkedIds, diveId}) → Future<List<AssetInfo>?>` already supports `diveId: null` ("opened outside a dive context", photo_picker_page.dart:35).
- `MediaImportService._createMediaItemFromAsset(asset, diveId)` builds localFile rows for path-bearing assets (desktop) and platformGallery rows otherwise; enrichment is dive-derived and must be SKIPPED for library imports.
- Dive-scoped dedupe uses `getLinkedAssetIdsForDive` / `getLinkedLocalPathsForDive`; the library path needs library-WIDE equivalents.
- Suggestions: `inboxSuggestionProvider` (family by media id) and `reassignMediaToDive(List<String>, String)` exist from Phase 2.

---

### Task 1: Library-wide import path on MediaImportService

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart` (two dedupe queries)
- Modify: `lib/features/media/data/services/media_import_service.dart`
- Test: `test/features/media/data/media_import_library_test.dart`

**Interfaces:**
- Produces:

```dart
// MediaRepository:
Future<Set<String>> getAllPlatformAssetIds();  // distinct non-null
Future<Set<String>> getAllLocalPaths();        // distinct non-null

// MediaImportService:
Future<ImportResult> importPhotosToLibrary({
  required List<AssetInfo> selectedAssets,
});
// Rows: diveId null, retainInLibrary true, NO enrichment. Dedupe against
// the library-wide sets. Same ImportResult contract as the dive path.
```

- [ ] **Step 1: Write the failing tests** (harness: `setUpTestDatabase` + `MediaRepository()` + the service constructed the way `test/features/media/data/services/media_import_service_test.dart` builds it — copy that file's constructor invocation):

```dart
test('library import creates unlinked retained rows without enrichment',
    () async {
  final result = await service.importPhotosToLibrary(
    selectedAssets: [assetInfo('a1', filePath: '/tmp/a.jpg')],
  );
  expect(result.imported, hasLength(1));
  final row = await repo.getMediaById(result.imported.single.id);
  expect(row!.diveId, isNull);
  expect(row.retainInLibrary, isTrue);
  expect(row.enrichment, isNull);
  expect(row.sourceType, MediaSourceType.localFile);
});

test('library import dedupes against every existing row', () async {
  await service.importPhotosToLibrary(
      selectedAssets: [assetInfo('a1', filePath: '/tmp/a.jpg')]);
  final second = await service.importPhotosToLibrary(
      selectedAssets: [assetInfo('a1', filePath: '/tmp/a.jpg')]);
  expect(second.imported, isEmpty);
  expect(second.skippedDuplicates, 1);
});

test('gallery assets dedupe on platform asset id', () async {
  // assetInfo with no filePath -> platformGallery row keyed on asset id.
});
```

(`assetInfo(...)` is a local fixture over `AssetInfo(id:, type: AssetType.image, createDateTime:, width:, height:, filename:, filePath:)`.)

- [ ] **Step 2: FAIL run** — `flutter test test/features/media/data/media_import_library_test.dart --timeout 120s`
- [ ] **Step 3: Implement**

Repository queries (selectOnly + distinct, mirroring `getAllContentHashes`):

```dart
  /// Every distinct platform asset id in the library (import dedupe).
  Future<Set<String>> getAllPlatformAssetIds() async {
    final column = _db.media.platformAssetId;
    final query = _db.selectOnly(_db.media, distinct: true)
      ..addColumns([column])
      ..where(column.isNotNull());
    final rows = await query.get();
    return rows.map((r) => r.read(column)!).toSet();
  }

  /// Every distinct local path in the library (import dedupe).
  Future<Set<String>> getAllLocalPaths() async {
    final column = _db.media.localPath;
    final query = _db.selectOnly(_db.media, distinct: true)
      ..addColumns([column])
      ..where(column.isNotNull());
    final rows = await query.get();
    return rows.map((r) => r.read(column)!).toSet();
  }
```

Service: refactor `_createMediaItemFromAsset(asset, diveId)` to `_createMediaItemFromAsset(asset, {String? diveId, bool retainInLibrary = false})` (the dive path passes `diveId: dive.id`; the item gains `retainInLibrary: retainInLibrary`), then:

```dart
  /// Library import (Media section Phase 4): no dive context, rows are
  /// retained so the orphan sweep never GCs deliberately imported media,
  /// and enrichment is skipped (it is a join product of media x a dive
  /// profile; there is no dive yet). Linking happens on the batch confirm
  /// screen or later in the Unlinked inbox.
  Future<ImportResult> importPhotosToLibrary({
    required List<AssetInfo> selectedAssets,
  }) async {
    final List<MediaItem> imported = [];
    final Map<String, String> failures = {};

    bool hasPath(AssetInfo a) => a.filePath != null && a.filePath!.isNotEmpty;
    final existingAssetIds = selectedAssets.any((a) => !hasPath(a))
        ? await _mediaRepository.getAllPlatformAssetIds()
        : const <String>{};
    final existingPaths = selectedAssets.any(hasPath)
        ? await _mediaRepository.getAllLocalPaths()
        : const <String>{};

    final newAssets = selectedAssets.where((a) {
      if (hasPath(a)) return !existingPaths.contains(a.filePath);
      return !existingAssetIds.contains(a.id);
    }).toList();
    final skipped = selectedAssets.length - newAssets.length;

    for (final asset in newAssets) {
      try {
        final item = _createMediaItemFromAsset(asset, retainInLibrary: true);
        imported.add(await _mediaRepository.createMedia(item));
      } catch (e) {
        failures[asset.id] = e.toString();
      }
    }
    return ImportResult(
      imported: imported,
      failures: failures,
      skippedDuplicates: skipped,
    );
  }
```

(Match `ImportResult`'s actual constructor at media_import_service.dart:15.)

- [ ] **Step 4: PASS run** — `flutter test test/features/media/data/ --timeout 120s`.
- [ ] **Step 5: Commit** — "Add library import path with retain flag and dedupe".

---

### Task 2: Batch link-confirm page

**Files:**
- Create: `lib/features/media/presentation/pages/media_import_link_page.dart`
- Modify: l10n arbs + gen-l10n — `media_import_linkTitle` "Link imported media", `media_import_linkConfirm` "Link {count} items", `media_import_staysUnlinked` "Stays in Unlinked", `media_import_linkedResult` "{count} items linked"
- Test: `test/features/media/presentation/media_import_link_test.dart`

**Interfaces:**
- Consumes: `inboxSuggestionProvider(mediaId)` (Phase 2), `mediaByIdProvider`, `reassignMediaToDive`, `media_inbox_linkChip`-style labels.
- Produces: `MediaImportLinkPage({required List<String> mediaIds})` — one checkbox row per id whose suggestion is confident (pre-checked, label "filename" + subtitle "Link to #N"); non-confident ids listed disabled with `media_import_staysUnlinked`; the confirm button groups checked ids by suggested dive and calls `reassignMediaToDive(ids, diveId)` once per dive, then pops with a snackbar.

- [ ] **Step 1: Failing widget tests** (override the suggestion family per id, `mediaByIdProvider` per id, and `mediaRepositoryProvider` with the Phase 2 recording fake):

```dart
testWidgets('confident suggestions are pre-checked and link on confirm '
    'grouped by dive', (tester) async {
  // ids m1(confident d7 #7), m2(confident d7 #7), m3(none)
  // expect two checked rows + one 'Stays in Unlinked' row
  // tap 'Link 2 items' -> fake repo saw reassign(['m1','m2'], 'd7')
});
testWidgets('unchecking a row excludes it from the confirm', (tester) async {
  ...
});
```

- [ ] **Step 2: FAIL run**, **Step 3: Implement**, **Step 4: PASS run** — `flutter test test/features/media/presentation/media_import_link_test.dart --timeout 120s`.
- [ ] **Step 5: Commit** — "Add batch link-confirm page for imports".

---

### Task 3: Import console section

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_console_scaffold.dart` (`MediaConsoleSection.importMedia` LAST in the enum, icon `Icons.add_photo_alternate_outlined`, label `media_console_import`)
- Create: `lib/features/media/presentation/pages/media_import_view.dart`
- Modify: `lib/features/media/presentation/pages/media_section_page.dart`
- Modify: l10n arbs + gen-l10n — `media_console_import` "Import", `media_import_launch` "Import media...", `media_import_intro` "Imported media is kept in your library and can be linked to dives automatically."
- Test: extend `test/features/media/presentation/media_section_page_test.dart` with the new section; new `test/features/media/presentation/media_import_view_test.dart`

**Interfaces:**
- Produces: `MediaImportView` — an intro pane with one `FilledButton.icon` (`media_import_launch`). On press: `showPhotoPicker(context: ..., diveStartTime: DateTime(2000), diveEndTime: DateTime.now().add(const Duration(days: 1)), buffer: Duration.zero, diveId: null)`; a non-empty selection runs `importPhotosToLibrary` and pushes `MediaImportLinkPage(mediaIds: result.imported.map((m) => m.id).toList())`. The picker+import launch closure is injected (`@visibleForTesting` constructor parameter `Future<List<String>> Function(BuildContext)? launchOverride`) so the widget test asserts the link page push without the platform picker.

- [ ] **Step 1: Failing widget tests** (launcher renders intro + button; with `launchOverride` returning two ids, tapping pushes `MediaImportLinkPage` with those ids; the console section switch test gains the Import arm).
- [ ] **Step 2: FAIL run**, **Step 3: Implement**, **Step 4: PASS run** — `flutter test test/features/media/presentation/ --timeout 120s` (the console scaffold enum grows again; its tests derive from the enum so only hardcoded expectations need touching).
- [ ] **Step 5: Commit** — "Add Import console section".

---

### Task 4: Final sweep

- [ ] `dart format .` (no-op), `flutter analyze` (zero), `flutter test --timeout 120s` full suite (rerun known flaky files in isolation before concluding regression: backup encryption suite, OCR scan page, upload drain, recovery-code yoyo); commit stragglers.

---

## Plan self-review notes (already applied)

- Spec section 9 coverage: picker with no dive context (T3 launcher passing `diveId: null`), `retainInLibrary = true` on imports (T1), batch auto-match confirmation with confident pre-checked (T2), leftovers stay in the inbox (non-confident rows untouched — they are unlinked and retained, so the inbox lists them and the sweep skips them; no extra work needed).
- Type consistency: `importPhotosToLibrary`, `getAllPlatformAssetIds`/`getAllLocalPaths`, `MediaImportLinkPage(mediaIds:)`, `MediaConsoleSection.importMedia` used consistently.
- Deliberate simplification: the Gallery tab's date window for dive-less imports is 2000-tomorrow (photo pickers filter by date; with no dive there is no meaningful window — desktop file dialogs ignore it entirely).
