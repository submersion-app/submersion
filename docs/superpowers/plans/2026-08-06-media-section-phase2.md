# Media Section Phase 2 (Link Management) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship link management: true unlink (FK clear, row survives), reassign with enrichment recompute, the Unlinked inbox with auto-match suggestions, the dive-detail Unlink/Delete split, and `retainInLibrary` consumption in the orphan sweep.

**Architecture:** New sync-safe repository ops in `MediaRepository` modeled on `unlinkMediaFromDeletedDives` (media_repository.dart:1030). The inbox is a new `MediaConsoleSection` reusing `MediaLibraryRepository`'s unlinked filter, with suggestions from the existing `DivePhotoMatcher.matchTimestamp` over `getDivesInRange` candidates. Spec: `docs/superpowers/specs/2026-08-05-media-section-design.md` section 8.

**Tech Stack:** Flutter 3.x, Drift, Riverpod (barrel `package:submersion/core/providers/provider.dart`), go_router, intl.

## Global Constraints

Identical to Phase 1's (docs/superpowers/plans/2026-08-05-media-section-phase1.md): worktree-only work (`pwd` before trusting output), `dart format .` no-op before every commit, `flutter analyze` zero issues (infos fatal), no emojis, every string in `app_en.arb` plus all 10 locale ARBs (ar de es fr he hu it nl pt zh) with real translations then `flutter gen-l10n`, Riverpod via the barrel only, `MaterialApp(locale: Locale('en'))` pinned in widget tests, no Drift under FakeAsync, no Co-Authored-By. **This phase edits `dive_media_section.dart` — the full suite MUST run before that task's commit** (provider-dependency changes break consumer tests analyze cannot catch). Timestamps are epoch ms; `takenAt` hydrates wall-clock-as-UTC — dive entry/exit times must be normalized with `TripMediaScanner.toWallClockUtc` before comparing.

Key behavioral facts locked in during research:
- Today's dive-detail "Unlink" actions call `MediaListNotifier.deleteMedia/deleteMultipleMedia` — a hard delete with tombstones and store-blob deletes — while the l10n copy already promises "The original files won't be deleted". Phase 2 makes the code match the copy; the existing unlink strings are kept verbatim.
- `media_enrichment.media_id` has `onDelete: cascade`, and enrichment is an HLC-synced entity (`mediaEnrichment`) — reassign must delete enrichment rows WITH `logDeletion` tombstones, then recompute via `DiveMediaEnricher.enrichMissingForDive`.

---

### Task 1: Expose `retainInLibrary` on MediaItem

The v140 column exists (Phase 1) but the domain entity does not carry it yet.

**Files:**
- Modify: `lib/features/media/domain/entities/media_item.dart` (field, constructor, copyWith)
- Modify: `lib/features/media/data/repositories/media_row_mapper.dart` (hydrate)
- Modify: `lib/features/media/data/repositories/media_repository.dart` (`createMedia` and `updateMedia` companions)
- Test: `test/features/media/data/media_retain_in_library_test.dart`

**Interfaces:**
- Produces: `MediaItem.retainInLibrary` (`bool`, default `false`), round-tripped through create/read/update. Tasks 2, 5, 7 rely on it.

- [ ] **Step 1: Write the failing test**

Model the harness on `test/features/media/data/media_repository_recent_photos_test.dart` (setUpTestDatabase + `MediaRepository()`; `MediaItem` fixture helper):

```dart
test('retainInLibrary round-trips through create and read', () async {
  await repo.createMedia(item('keep.jpg', retainInLibrary: true));
  await repo.createMedia(item('normal.jpg'));

  final kept = await repo.getMediaById('keep.jpg');
  final normal = await repo.getMediaById('normal.jpg');
  expect(kept!.retainInLibrary, isTrue);
  expect(normal!.retainInLibrary, isFalse);
});

test('updateMedia persists a retainInLibrary change', () async {
  final created = await repo.createMedia(item('m1'));
  await repo.updateMedia(created.copyWith(retainInLibrary: true));
  expect((await repo.getMediaById(created.id))!.retainInLibrary, isTrue);
});
```

(the `item` helper passes `id:` = the name so `getMediaById` can use it, plus the usual required MediaItem fields and a `bool retainInLibrary = false` parameter.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/data/media_retain_in_library_test.dart --timeout 120s`
Expected: FAIL — no `retainInLibrary` named parameter.

- [ ] **Step 3: Implement**

`media_item.dart`: add `final bool retainInLibrary;` with `this.retainInLibrary = false` in the constructor and a plain `bool? retainInLibrary` arm in `copyWith` (`retainInLibrary: retainInLibrary ?? this.retainInLibrary` — non-nullable, so the `_undefined` sentinel is not needed for this field).
`media_row_mapper.dart`: `retainInLibrary: row.retainInLibrary,` in `mediaItemFromRow`.
`media_repository.dart`: `retainInLibrary: Value(item.retainInLibrary),` in BOTH the `createMedia` insert companion and the `updateMedia` write companion (find the two `MediaCompanion(` literals that already list `isFavorite`).

- [ ] **Step 4: Run to verify pass, then run the media data suite**

Run: `flutter test test/features/media/data/ --timeout 120s`
Expected: ALL PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/ test/features/media/data/media_retain_in_library_test.dart
git commit -m "Expose retainInLibrary on MediaItem"
```

---

### Task 2: True unlink ops and the sweep exclusion

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart` (new ops next to `unlinkMediaFromDeletedDives` at :1030; predicate change in `getSweepableOrphanIds` at :1052)
- Test: `test/features/media/data/media_unlink_ops_test.dart`

**Interfaces:**
- Consumes: Task 1's `retainInLibrary`.
- Produces (Tasks 5-7 rely on these exact names):

```dart
/// User-initiated unlink: clears the dive link, keeps the row, and marks it
/// retained so the orphan sweep never GCs its blobs.
Future<void> unlinkFromDive(List<String> mediaIds);

/// Same mechanic for the site link.
Future<void> unlinkFromSite(List<String> mediaIds);

/// Inbox "keep": marks rows retained without touching links.
Future<void> markRetainedInLibrary(List<String> mediaIds);
```

- [ ] **Step 1: Write the failing tests**

Same harness as Task 1 (dives need a `divers` row only if you set `diverId` — skip it; insert dives/sites with companions as in `test/features/media/data/media_library_repository_test.dart`):

```dart
test('unlinkFromDive clears the FK, keeps the row, sets retainInLibrary',
    () async {
  await insertDive('d1');
  await repo.createMedia(item('m1', diveId: 'd1'));

  await repo.unlinkFromDive(['m1']);

  final m = await repo.getMediaById('m1');
  expect(m, isNotNull);
  expect(m!.diveId, isNull);
  expect(m.retainInLibrary, isTrue);
});

test('unlinkFromSite clears only the site link', () async {
  await insertDive('d1');
  await insertSite('s1');
  await repo.createMedia(item('m1', diveId: 'd1', siteId: 's1'));

  await repo.unlinkFromSite(['m1']);

  final m = await repo.getMediaById('m1');
  expect(m!.siteId, isNull);
  expect(m.diveId, 'd1');
  expect(m.retainInLibrary, isTrue);
});

test('empty id lists are no-ops', () async {
  await repo.unlinkFromDive(const []);
  await repo.unlinkFromSite(const []);
  await repo.markRetainedInLibrary(const []);
});

test('getSweepableOrphanIds excludes retained rows', () async {
  // Both unlinked localFile rows older than the cutoff; only the
  // non-retained one is sweepable.
  await repo.createMedia(item('sweep-me'));
  await repo.createMedia(item('keep-me'));
  await repo.markRetainedInLibrary(['keep-me']);
  // Age both rows past the cutoff.
  await db.customStatement(
    'UPDATE media SET created_at = 0 WHERE id IN (?, ?)',
    ['sweep-me', 'keep-me'],
  );

  final ids = await repo.getSweepableOrphanIds(
    olderThan: DateTime(2026, 1, 1),
  );
  expect(ids, contains('sweep-me'));
  expect(ids, isNot(contains('keep-me')));
});
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/data/media_unlink_ops_test.dart --timeout 120s`
Expected: FAIL — methods undefined.

- [ ] **Step 3: Implement**

All three ops copy `unlinkMediaFromDeletedDives`'s shape exactly (transaction, per-row `markRecordPending`, `SyncEventBus.notifyLocalChange()`); place them directly below it:

```dart
  /// User-initiated unlink (Media section Phase 2): clears the dive link,
  /// keeps the row, and sets retain_in_library so the orphan sweep never
  /// GCs the blobs of media the user deliberately kept. Same sync-safe
  /// shape as [unlinkMediaFromDeletedDives], which deliberately does NOT
  /// set the flag (dive-deletion leftovers stay sweepable).
  Future<void> unlinkFromDive(List<String> mediaIds) => _unlinkColumns(
    mediaIds,
    const MediaCompanion(diveId: Value(null), retainInLibrary: Value(true)),
  );

  /// Same mechanic for the site link.
  Future<void> unlinkFromSite(List<String> mediaIds) => _unlinkColumns(
    mediaIds,
    const MediaCompanion(siteId: Value(null), retainInLibrary: Value(true)),
  );

  /// Inbox "keep": marks rows retained without touching links.
  Future<void> markRetainedInLibrary(List<String> mediaIds) =>
      _unlinkColumns(
        mediaIds,
        const MediaCompanion(retainInLibrary: Value(true)),
      );

  Future<void> _unlinkColumns(
    List<String> mediaIds,
    MediaCompanion changes,
  ) async {
    if (mediaIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await (_db.update(_db.media)..where((t) => t.id.isIn(mediaIds))).write(
        changes.copyWith(updatedAt: Value(now)),
      );
      for (final id in mediaIds) {
        await _syncRepository.markRecordPending(
          entityType: 'media',
          recordId: id,
          localUpdatedAt: now,
        );
      }
    });
    SyncEventBus.notifyLocalChange();
  }
```

Sweep predicate — in `getSweepableOrphanIds`, extend the `..where(` expression:

```dart
        isLinkedToDiveOrSite(_db.media).not() &
            _db.media.retainInLibrary.equals(false) &
            _db.media.sourceType.isNotIn(libraryLevelSourceTypes) &
            _db.media.createdAt.isSmallerThanValue(
              olderThan.millisecondsSinceEpoch,
            ),
```

- [ ] **Step 4: Run the tests plus the existing sweep/orphan tests**

Run: `flutter test test/features/media/data/ test/features/media_store/ --timeout 120s`
Expected: ALL PASS (the sweep predicate change must not break the orphan-backlog-sweep tests; if one seeded an unlinked row and expects it swept, the default `retainInLibrary = false` keeps it sweepable).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/data/ test/features/media/data/media_unlink_ops_test.dart
git commit -m "Add true unlink ops and retain-in-library sweep exclusion"
```

---

### Task 3: Reassign op with enrichment reset

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart`
- Test: `test/features/media/data/media_reassign_test.dart`

**Interfaces:**
- Produces (Tasks 6-7 rely on this):

```dart
/// Moves media to [newDiveId] (also used to link previously-unlinked rows).
/// Deletes stale enrichment rows WITH sync tombstones — enrichment is a
/// join product of media x the old dive's profile; the enricher recomputes
/// it against the new dive on next view.
Future<void> reassignMediaToDive(List<String> mediaIds, String newDiveId);
```

- [ ] **Step 1: Write the failing tests**

```dart
test('reassign moves the FK and deletes stale enrichment with a tombstone',
    () async {
  await insertDive('d1');
  await insertDive('d2');
  final m = await repo.createMedia(item('m1', diveId: 'd1'));
  await repo.saveEnrichment(MediaEnrichment(
    id: 'e1',
    mediaId: m.id,
    diveId: 'd1',
    depthMeters: 10,
    matchConfidence: MatchConfidence.exact,
    createdAt: DateTime(2026, 6, 1),
  ));

  await repo.reassignMediaToDive([m.id], 'd2');

  final moved = await repo.getMediaById(m.id);
  expect(moved!.diveId, 'd2');
  expect(moved.enrichment, isNull); // stale enrichment gone

  final tombstones = await db
      .customSelect(
        "SELECT record_id FROM deletion_log "
        "WHERE entity_type = 'mediaEnrichment'",
      )
      .get();
  expect(tombstones.map((r) => r.read<String>('record_id')), contains('e1'));
});

test('reassign of an unlinked row is a plain link', () async {
  await insertDive('d2');
  final m = await repo.createMedia(item('m1'));
  await repo.reassignMediaToDive([m.id], 'd2');
  expect((await repo.getMediaById(m.id))!.diveId, 'd2');
});
```

Adjust the `MediaEnrichment` constructor arguments to the entity's actual required fields (`media_item.dart:391`) and `MatchConfidence` values if `exact` is not one; the deletion_log table/column names come from the sync repository — if the raw SELECT does not match the schema, assert through `SyncRepository` the way `test/features/media/data/media_repository_cascade_test.dart` checks media tombstones, copying its idiom.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/data/media_reassign_test.dart --timeout 120s`
Expected: FAIL — method undefined.

- [ ] **Step 3: Implement**

```dart
  /// Moves media to [newDiveId] (also the link path for unlinked rows).
  /// Enrichment rows are join products of media x the OLD dive's profile:
  /// stale after the move, so they are deleted with tombstones (enrichment
  /// is an HLC-synced entity) and recomputed lazily by DiveMediaEnricher
  /// the next time the new dive's media renders.
  Future<void> reassignMediaToDive(
    List<String> mediaIds,
    String newDiveId,
  ) async {
    if (mediaIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      final stale = await (_db.select(
        _db.mediaEnrichment,
      )..where((t) => t.mediaId.isIn(mediaIds))).get();
      for (final row in stale) {
        await (_db.delete(
          _db.mediaEnrichment,
        )..where((t) => t.id.equals(row.id))).go();
        await _syncRepository.logDeletion(
          entityType: 'mediaEnrichment',
          recordId: row.id,
        );
      }
      await (_db.update(_db.media)..where((t) => t.id.isIn(mediaIds))).write(
        MediaCompanion(diveId: Value(newDiveId), updatedAt: Value(now)),
      );
      for (final id in mediaIds) {
        await _syncRepository.markRecordPending(
          entityType: 'media',
          recordId: id,
          localUpdatedAt: now,
        );
      }
    });
    SyncEventBus.notifyLocalChange();
  }
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/media/data/ --timeout 120s`
Expected: ALL PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/data/ test/features/media/data/media_reassign_test.dart
git commit -m "Add reassignMediaToDive with enrichment reset"
```

---

### Task 4: Shared dive picker sheet

**Files:**
- Create: `lib/features/media/presentation/widgets/dive_picker_sheet.dart`
- Modify: l10n arbs (`media_divePicker_title` "Move to dive", `media_divePicker_search` "Search dives") + gen-l10n
- Test: `test/features/media/presentation/dive_picker_sheet_test.dart`

**Interfaces:**
- Consumes: `diveRepositoryProvider` (from `package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart`) and its `getAllDives({String? diverId})`; `currentDiverIdProvider`.
- Produces: `Future<String?> showDivePickerSheet(BuildContext context)` — resolves to the chosen dive id, or null on dismiss. Tasks 6-7 consume it.

- [ ] **Step 1: Write the failing widget test**

Override `diveRepositoryProvider` with a fake whose `getAllDives` returns two `Dive` fixtures (numbers 1 and 2, names/sites optional — copy a minimal `Dive(...)` construction from an existing dive_log test such as `test/features/media/data/media_library_repository_test.dart`'s neighbors, or build with only the entity's required fields):

```dart
testWidgets('lists dives, filters by search, returns the tapped dive id',
    (tester) async {
  String? picked;
  await tester.pumpWidget(host(onPressed: (context) async {
    picked = await showDivePickerSheet(context);
  }));
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();

  expect(find.textContaining('#1'), findsOneWidget);
  expect(find.textContaining('#2'), findsOneWidget);

  await tester.enterText(find.byType(TextField), '2');
  await tester.pumpAndSettle();
  expect(find.textContaining('#1'), findsNothing);

  await tester.tap(find.textContaining('#2'));
  await tester.pumpAndSettle();
  expect(picked, 'dive-2');
});
```

(`host` pumps a MaterialApp+ProviderScope with a button labeled OPEN that invokes the callback with its own context.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/presentation/dive_picker_sheet_test.dart --timeout 120s`
Expected: FAIL.

- [ ] **Step 3: Implement**

A `showModalBottomSheet` wrapper: a `ConsumerStatefulWidget` body with a search `TextField` and a `ListView` of dives loaded once via `ref.read(diveRepositoryProvider).getAllDives(diverId: ref.read(currentDiverIdProvider))`, newest first (the repo returns most-recent-first). Row label: `'#${dive.diveNumber ?? ''} ${dive.name ?? dive.site?.name ?? ''}'.trim()` plus a `DateFormat.yMMMd` subtitle. In-memory filter: query matches dive number string, name, or site name (case-insensitive). Tap pops with the id: `Navigator.of(sheetContext).pop(dive.id)`. `showDivePickerSheet` returns `showModalBottomSheet<String>(isScrollControlled: true, ...)`.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/media/presentation/dive_picker_sheet_test.dart --timeout 120s`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/widgets/dive_picker_sheet.dart \
        lib/l10n/ test/features/media/presentation/dive_picker_sheet_test.dart
git commit -m "Add shared dive picker sheet"
```

---

### Task 5: Dive-detail Unlink/Delete split

**Files:**
- Modify: `lib/features/media/presentation/providers/media_providers.dart` (`MediaListNotifier` gains unlink)
- Modify: `lib/features/media/presentation/widgets/dive_media_section.dart` (`_unlinkSelected` rewires; new `_deleteSelected`; selection bar gains Delete; the single-item unlink context path rewires the same way)
- Modify: l10n arbs (`media_diveMediaSection_deleteSelectedTitle` "Delete {count} items?", `media_diveMediaSection_deleteSelectedContent` "This removes them from the app and any media store. This cannot be undone.", `media_diveMediaSection_deleteButton` "Delete", `media_diveMediaSection_deleteSelectedSuccess` "Deleted {count} items") + gen-l10n
- Test: `test/features/media/presentation/widgets/dive_media_section_unlink_test.dart`

**Interfaces:**
- Consumes: `unlinkFromDive` (Task 2).
- Produces: `MediaListNotifier.unlinkMultipleMedia(List<String> ids)` — clears FKs via the repository, then `refresh()`.

- [ ] **Step 1: Read the current wiring**

Open `dive_media_section.dart` and locate: `_unlinkSelected` (:134), the selection-bar widget invocation passing `onUnlinkSelected` (:326), the selection-bar widget class it names (search `onUnlinkSelected` for its definition), and any single-item unlink menu action using `media_diveMediaSection_unlinkDialogTitle`. These are the exact edit sites.

- [ ] **Step 2: Write the failing widget test**

Model the ProviderScope harness on `test/features/media/presentation/widgets/dive_media_section_test.dart` (it already fakes the media list and resolver registry). Two cases:

```dart
testWidgets('Unlink action clears links without deleting rows',
    (tester) async {
  // fake MediaListNotifier or real one over the in-memory DB per the
  // existing dive_media_section_test harness; enter selection mode,
  // select one item, tap the Unlink action, confirm the dialog.
  // Assert the repository still returns the row via getMediaById and its
  // diveId is null (real-DB harness), or the recording fake saw
  // unlinkMultipleMedia and NOT deleteMultipleMedia (fake harness) —
  // follow whichever style dive_media_section_test.dart already uses.
});

testWidgets('Delete action routes to the deletion coordinator after its own
    confirm', (tester) async {
  // select one item, tap Delete, confirm the delete dialog
  // (find.text('Delete 1 items?') per the new key), assert the recording
  // deletion coordinator received the id.
});
```

- [ ] **Step 3: Run to verify failure, implement, verify pass**

Run: `flutter test test/features/media/presentation/widgets/ --timeout 120s` (FAIL first).

Implementation:

(a) `media_providers.dart` — inside `MediaListNotifier`, below `deleteMultipleMedia`:

```dart
  /// True unlink (Media section Phase 2): clears the dive link and keeps
  /// the rows in the library. The destructive path is [deleteMultipleMedia].
  Future<void> unlinkMultipleMedia(List<String> ids) async {
    await _repository.unlinkFromDive(ids);
    await refresh();
  }
```

(b) `dive_media_section.dart`:
- `_unlinkSelected` keeps its existing confirm dialog and strings verbatim (the copy already describes true unlink) but the action call becomes `unlinkMultipleMedia(selectedIds)`.
- Add `_deleteSelected(BuildContext context, List<MediaItem> media)` — a structural copy of `_unlinkSelected` using the four new `deleteSelected*` keys and calling `deleteMultipleMedia(selectedIds)` (the coordinator-routed path), then the existing exit-selection/refresh flow.
- The selection bar: add an `onDeleteSelected` callback parameter to the bar widget mirroring `onUnlinkSelected`, rendered as a delete icon/labelled action next to Unlink, wired at the :326 call site to `_deleteSelected`.
- The single-item unlink path (the `unlinkDialogTitle` dialog): switch its action from `deleteMedia(id)` to `_repositoryish` unlink — call `ref.read(mediaListNotifierProvider(widget.diveId).notifier).unlinkMultipleMedia([item.id])`.

- [ ] **Step 4: Run the FULL suite**

Run: `flutter test --timeout 120s`
Expected: ALL PASS. `dive_media_section.dart` edits are the known full-suite trap; dive-detail section-count tests and lightroom/media tests are the likely consumers. Fix forward in this task.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/ lib/l10n/ test/features/media/
git commit -m "Split dive-detail Unlink into true unlink and explicit Delete"
```

---

### Task 6: Library selection bar — Move to dive, Unlink, Unlink from site

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_selection_bar.dart`
- Modify: l10n arbs (`media_library_unlinkSelected` "Unlink", `media_library_moveToDive` "Move to dive", `media_library_unlinkFromSite` "Unlink from site") + gen-l10n
- Test: extend `test/features/media/presentation/media_selection_test.dart`

**Interfaces:**
- Consumes: `unlinkFromDive`, `unlinkFromSite` (Task 2), `reassignMediaToDive` (Task 3), `showDivePickerSheet` (Task 4), `mediaRepositoryProvider`.
- Produces: three new actions on `MediaSelectionBar`; selection clears after each.

- [ ] **Step 1: Write the failing widget tests**

Extend the existing `media_selection_test.dart` harness (it already overrides the library notifier, resolver registry, and deletion coordinator; add a `mediaRepositoryProvider` override with a recording fake implementing `unlinkFromDive`/`unlinkFromSite`/`reassignMediaToDive` via `noSuchMethod` passthrough):

```dart
testWidgets('Unlink action calls unlinkFromDive and clears selection',
    (tester) async {
  // select two linked entries (give the fixtures diveId: 'd1'),
  // tap 'Unlink'; expect fakeMediaRepo.unlinkedFromDive == ['a', 'b']
  // and selection empty.
});

testWidgets('Unlink from site appears only when a selected item has a site',
    (tester) async {
  // selection of entries without siteId -> find.text('Unlink from site')
  // findsNothing; with one siteId -> findsOneWidget; tap -> recorded ids.
});

testWidgets('Move to dive opens the picker and reassigns', (tester) async {
  // override diveRepositoryProvider with the Task 4 fake (two dives);
  // tap 'Move to dive', tap dive #2 in the sheet;
  // expect fakeMediaRepo.reassigned == (['a'], 'dive-2').
});
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/presentation/media_selection_test.dart --timeout 120s`
Expected: FAIL.

- [ ] **Step 3: Implement**

In `MediaSelectionBar` add three `TextButton.icon`s between the count and Share:
- Unlink (`Icons.link_off`): shown when any selected item has `diveId != null`; calls `ref.read(mediaRepositoryProvider).unlinkFromDive(ids)` then `clear()`.
- Unlink from site (`Icons.location_off`): shown when any selected item has `siteId != null`; `unlinkFromSite(ids)` then `clear()`.
- Move to dive (`Icons.drive_file_move_outline`): always shown; `final diveId = await showDivePickerSheet(context); if (diveId != null) { await ref.read(mediaRepositoryProvider).reassignMediaToDive(ids, diveId); clear(); }`.

No manual refresh needed — the library's `watchMediaChanges` stream reloads page one on every media write.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/media/presentation/ --timeout 120s`
Expected: ALL PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/ lib/l10n/ test/features/media/
git commit -m "Add unlink, site-unlink, and move-to-dive to library selection"
```

---

### Task 7: Unlinked inbox with auto-match suggestions

**Files:**
- Create: `lib/features/media/presentation/providers/media_inbox_providers.dart`
- Create: `lib/features/media/presentation/pages/media_unlinked_inbox_view.dart`
- Modify: `lib/features/media/presentation/widgets/media_console_scaffold.dart` (`MediaConsoleSection.unlinked` between library and transfers, icon `Icons.link_off`, label `media_console_unlinked`)
- Modify: `lib/features/media/presentation/pages/media_section_page.dart` (section body + badge wiring)
- Modify: l10n arbs (`media_console_unlinked` "Unlinked", `media_inbox_empty` "No unlinked media", `media_inbox_linkChip` "Link to #{number}", `media_inbox_chooseDive` "Choose dive", `media_inbox_keep` "Keep", `media_inbox_linkToDive` "Link to dive", `media_inbox_linkToSite` "Link to site") + gen-l10n
- Test: `test/features/media/presentation/media_inbox_test.dart`

**Interfaces:**
- Consumes: `MediaLibraryRepository.getPage(filter: MediaLibraryFilter(health: MediaHealthFilter.unlinked))`, `DivePhotoMatcher.matchTimestamp`, `diveRepositoryProvider.getDivesInRange(start, end, {diverId})`, `TripMediaScanner.toWallClockUtc`, `reassignMediaToDive`, `markRetainedInLibrary`, `unlinkedCountProvider` (Phase 1), `showDivePickerSheet` (Task 4), `sitesProvider` for the site picker sheet (Task 6's pattern from the filter bar).
- Produces:

```dart
/// Suggestion for one unlinked item: the matcher verdict plus display
/// context for confident hits.
class InboxSuggestion {
  const InboxSuggestion({required this.match, this.diveNumber});
  final TimestampMatch match;
  final int? diveNumber; // for the confident chip label
}

final inboxSuggestionProvider =
    FutureProvider.family<InboxSuggestion, String>; // by media id
final unlinkedInboxProvider = ...; // paged unlinked entries, Phase 1 notifier pattern
```

- [ ] **Step 1: Write the failing tests**

Unit-test the suggestion computation as a pure function first — put it in the providers file as a visible-for-testing function:

```dart
/// Computes the matcher verdict for [takenAt] against dives within a
/// +/- 1 day window (bounds via entryTime ?? dateTime and exitTime ??
/// dateTime + effectiveRuntime ?? 60min, normalized to wall-clock UTC).
Future<InboxSuggestion> computeInboxSuggestion({
  required DateTime takenAt,
  required List<Dive> candidateDives,
});
```

```dart
test('a takenAt inside exactly one dive window is confident', () async {
  final dive = diveFixture('d1', number: 7,
      entry: DateTime(2026, 6, 12, 10), exit: DateTime(2026, 6, 12, 11));
  final s = await computeInboxSuggestion(
    takenAt: DateTime.utc(2026, 6, 12, 10, 30),
    candidateDives: [dive],
  );
  expect(s.match.kind, TimestampMatchKind.confident);
  expect(s.match.diveId, 'd1');
  expect(s.diveNumber, 7);
});

test('overlapping extended windows with no core hit are ambiguous',
    () async { ... two dives whose post/pre buffers overlap ... });

test('no dive in range is none', () async { ... });
```

Widget tests for the inbox view (Phase 1 harness style: seeded providers, stub resolver registry):

```dart
testWidgets('confident suggestion renders a one-tap link chip that calls '
    'reassignMediaToDive', (tester) async { ... });
testWidgets('Keep calls markRetainedInLibrary', (tester) async { ... });
testWidgets('empty inbox shows the localized empty state', (tester) async {
  ...
});
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/presentation/media_inbox_test.dart --timeout 120s`
Expected: FAIL.

- [ ] **Step 3: Implement**

Providers file:
- `computeInboxSuggestion` builds `DiveBounds` per candidate using the scanner's fallback rules (`entryTime ?? dive.dateTime`; `exitTime ?? dateTime + (effectiveRuntime ?? 60min)`), normalizes both bounds AND takenAt through `TripMediaScanner.toWallClockUtc`, runs `const DivePhotoMatcher().matchTimestamp(...)`, and resolves `diveNumber` from the confident dive's fixture.
- `inboxSuggestionProvider` family: reads the media item (`mediaByIdProvider`), queries `getDivesInRange(takenAt - 1 day, takenAt + 1 day, diverId: currentDiverId)`, delegates to `computeInboxSuggestion`.
- `unlinkedInboxProvider`: a `StateNotifierProvider` reusing the Phase 1 `MediaLibraryNotifier` class with a fixed `MediaLibraryFilter(health: MediaHealthFilter.unlinked)` (instantiate the same class with that filter; do not subclass).

Inbox view: `ListView` of rows — `MediaLibraryTile` thumbnail (72px) + title (`originalFilename` or takenAt date) + a trailing actions wrap:
- confident: `ActionChip(label: media_inbox_linkChip(number))` calling `reassignMediaToDive([id], match.diveId!)`;
- ambiguous: `ActionChip(label: media_inbox_chooseDive)` opening a bottom sheet listing `candidateDiveIds` (rows labelled via `diveProvider` lookups) and reassigning on tap;
- overflow `PopupMenuButton` with: Link to dive (`showDivePickerSheet` + reassign), Link to site (bottom-sheet over `sitesProvider`, then `MediaRepository.updateMedia` is NOT used — add nothing new: write via `_unlinkColumns`-style? No: **use `reassignMediaToSite`? Not in scope** — link-to-site writes `MediaCompanion(siteId: Value(id))` through a small Task 7 repo op `linkMediaToSite(List<String> mediaIds, String siteId)` implemented as `_unlinkColumns(mediaIds, MediaCompanion(siteId: Value(siteId)))` — add it beside Task 2's ops with one repository test), Keep (`markRetainedInLibrary`).

Console wiring: add the enum value; scaffold `switch`es gain the label/icon arms; `media_section_page.dart` renders `MediaUnlinkedInboxView` for it and passes `badgeCounts: {MediaConsoleSection.unlinked: ref.watch(unlinkedCountProvider).value ?? 0}` (make `MediaSectionPage` a `ConsumerStatefulWidget` for the watch).

- [ ] **Step 4: Run to verify pass, plus console tests**

Run: `flutter test test/features/media/presentation/ test/features/media/data/ --timeout 120s`
Expected: ALL PASS (the console scaffold test asserts sections render from the enum — the new value appears automatically; update its expected tab/entry count if it hardcodes 2).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/ lib/l10n/ test/features/media/
git commit -m "Add unlinked inbox with auto-match suggestions"
```

---

### Task 8: Final sweep

- [ ] **Step 1: Full verification**

```bash
dart format .            # must be a no-op
flutter analyze          # zero issues, infos included
flutter test --timeout 120s
```

Expected: analyzer clean; full suite green (pre-existing flaky files: backup suite, upload drain, recovery-code yoyo — rerun a suspect file in isolation before concluding regression).

- [ ] **Step 2: Commit any stragglers**

```bash
git status --short   # should be clean; commit anything intentional
```

---

## Plan self-review notes (already applied)

- Spec section 8 coverage: true unlink (T2), dive-detail split (T5), reassign + enrichment recompute (T3, recompute is lazy via the existing enricher backfill on dive view), inbox + matcher chips + manual pickers + keep (T7), site unlink exposure rules (T6: selection bar conditional; T7: inbox menu), `retainInLibrary` set on explicit unlink and inbox keep (T2) — Media-section imports set it in Phase 4 as specced. Sweep exclusion (T2). Unlinked badge (T7).
- Type consistency: `unlinkFromDive/unlinkFromSite/markRetainedInLibrary/linkMediaToSite` (repo), `reassignMediaToDive`, `showDivePickerSheet`, `InboxSuggestion`, `MediaConsoleSection.unlinked` used consistently across tasks.
- Deliberate scope note: enrichment recompute after reassign is lazy (existing `_runEnrichmentBackfill` fires when the new dive's media section renders) rather than eager in the repo op — keeps the op DB-only and testable; the spec requires invalidation plus recompute, and invalidation-with-lazy-recompute satisfies it through existing machinery.
