# Species Photos in Justified Rows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The species page's Photos section lays photos out in justified rows (no square crops), captions each with its dive's date and site, and stops at 3 rows with a "+N" tile that opens the viewer.

**Architecture:** A new non-scrolling `JustifiedMediaBlock` reuses #4755's `JustifiedMediaTable` for one headerless section and trims it to whole rows. The species media query gains the dive date and site name, as `MediaLibraryEntry` values. `SpeciesPhotosSection` builds its tiles from those entries and from pending media items.

**Tech Stack:** Flutter, Riverpod 3, Drift.

**Spec:** `docs/design/specs/2026-11-19-species-photos-justified-rows-design.md`

## Global Constraints

- Row target height 150 px, gap 4 px, inset 0, minimum tile width `kMediaThumbnailMinTileWidth` (48).
- At most 3 rows of tiles, except that pending photos are never hidden.
- Caption: `units.formatDate(diveDateTime)`, then ` · <site name>` when the site name is non-empty; none when the photo has no dive. Ellipsized, one line, hidden on tiles narrower than `kMediaTileDetailWidth` (64).
- Pending photos show no caption.
- Shapes come from `mediaRawAspect` + `clampMediaAspect` with the learned aspects from `mediaLearnedAspectsProvider`; species tiles report decoded sizes to it.
- `dive_date_time` is wall-clock-as-UTC: read with `isUtc: true` (see `media_library_repository.dart:465`).
- Every ARB locale gets the new string, translated; plural with `one{}`/`other{}`, never `=1{}` with a literal digit.
- No emojis, no em-dashes, imports grouped dart / flutter / packages / local.

## Review Focus

- A species with fewer photos than fill one row: the lone row keeps 150 px height and is not stretched; no "+N".
- Exactly 3 full rows of photos: no "+N" tile (hidden count 0).
- Many pending photos (more than 3 rows' worth): every pending tile visible, "+N" counts only the stored photos cut.
- A dive with no site: caption is the date alone, with no trailing " · ".
- A photo with no dive (site attachment tagged with the species): no caption, no crash.

---

### Task 1: Species media entries carry dive date and site

**Files:**
- Modify: `lib/features/media/data/repositories/media_species_repository.dart:259-298`
- Modify: `lib/features/media/presentation/providers/species_media_providers.dart:37-48`
- Test: `test/features/media/data/repositories/media_species_repository_test.dart`
- Test: `test/features/media/presentation/providers/species_media_providers_test.dart`

**Interfaces:**
- Produces: `Future<List<MediaLibraryEntry>> MediaSpeciesRepository.getMediaEntriesForSpecies(String speciesId, {String? diverId, String? diveId})`, same filter and order as `getMediaForSpecies`, with `diveDateTime` and `siteName` filled from the dive and its site.
- Produces: `mediaEntriesForSpeciesProvider = FutureProvider.family<List<MediaLibraryEntry>, String>`, invalidated on the same two streams as `mediaForSpeciesProvider`.
- `getMediaForSpecies` becomes `getMediaEntriesForSpecies(...)` mapped to `.item` (one query to maintain).

- [ ] **Step 1: Write the failing tests**

In the repository test, add a site `s1` "Blue Hole" (`insertTestSite`), a dive `d2` at `DateTime.utc(2024, 3, 12, 9, 30)` on `s1`, a photo `m3` on `d2`, and tag `m1` and `m3` with `c1`:

```dart
test('getMediaEntriesForSpecies carries the dive date and site', () async {
  final entries = await repository.getMediaEntriesForSpecies('c1');
  final byId = {for (final e in entries) e.item.id: e};
  expect(byId['m3']!.diveDateTime, DateTime.utc(2024, 3, 12, 9, 30));
  expect(byId['m3']!.siteName, 'Blue Hole');
  expect(byId['m1']!.siteName, isNull); // d1 has no site
  expect(
    (await repository.getMediaForSpecies('c1')).map((m) => m.id),
    entries.map((e) => e.item.id),
  );
});
```

Check `insertTestDive`'s `at` is stored as wall clock (read the fixture); assert whatever wall clock it stores, read back with `isUtc: true`.

In the provider test, `mediaEntriesForSpeciesProvider refreshes when a tag is added`, mirroring the existing `mediaForSpeciesProvider` test.

- [ ] **Step 2: Run them, expect compile failure** (`getMediaEntriesForSpecies` undefined)

Run: `flutter test test/features/media/data/repositories/media_species_repository_test.dart test/features/media/presentation/providers/species_media_providers_test.dart`

- [ ] **Step 3: Implement** the method: replace the `useColumns: false` dives join with a full left join on `dives`, left join `diveSites` on `dives.siteId`, map each row to `MediaLibraryEntry(item:, diveNumber:, diveDateTime: fromMillisecondsSinceEpoch(..., isUtc: true), siteName:)`. Add the provider beside `mediaForSpeciesProvider`.

- [ ] **Step 4: Run the tests, expect PASS**, plus `test/features/media/data/repositories/media_species_queries_test.dart` (an unchanged caller).

- [ ] **Step 5: Commit** `feat(media): species media entries carry the dive date and site`

### Task 2: `JustifiedMediaBlock`

**Files:**
- Create: `lib/features/media/presentation/widgets/justified_media_block.dart`
- Test: `test/features/media/presentation/widgets/justified_media_block_test.dart`

**Interfaces:**
- Consumes: `JustifiedMediaTable.build`, `JustifiedSection`, `kMediaThumbnailMinTileWidth`.
- Produces:
  - `int justifiedVisibleCount(JustifiedMediaTable table, {int? maxRows, int keepAtLeast = 0})`: how many leading cells to show, whole rows only. With `maxRows` null, all. Otherwise the cells of the first `maxRows` rows, raised to the end of the row holding cell `keepAtLeast - 1`.
  - `class JustifiedBlockCell { final int index; final Size size; final int hiddenCount; }`. `hiddenCount` is non-zero only on the last visible cell, and equals `ratios.length - visible`.
  - `class JustifiedMediaBlock extends StatelessWidget` with `required List<double> ratios, required double rowHeight, required double gap, int? maxRows, int keepAtLeast = 0, required Widget Function(BuildContext, JustifiedBlockCell) cellBuilder`. A `LayoutBuilder` builds the table at `constraints.maxWidth` (inset 0). The result is a `SizedBox(width, height: bottom of the last visible cell)` holding a `Stack` of `Positioned.fromRect` cells. Empty ratios, or an unbounded or zero width, build `SizedBox.shrink()`.

- [ ] **Step 1: Write the failing tests**
  - `justifiedVisibleCount` on a table of 12 ratios of 1.0 at width 316, height 100, gap 4 (3 per row): `maxRows: 3` gives 9, `maxRows: null` gives 12, `maxRows: 3, keepAtLeast: 11` gives 12, `maxRows: 5` gives 12.
  - Widget at width 316 with ratios `[1.5, 1.5, 1.0]`, rowHeight 150, gap 4: tile 0 and tile 1 are equal width, tile 2 narrower, all share one height, and the last right edge is 316 (`tester.getRect` on keyed cells).
  - 12 ratios of 1.0, `maxRows: 3`: 9 cells built, cell 8 gets `hiddenCount: 3`, the others 0, and the block height is the bottom of row 3.
  - A lone photo (`[1.5]`): height 150, width 225, `hiddenCount` 0.
  - Empty ratios: no cells, zero height.

- [ ] **Step 2: Run, expect compile failure.** `flutter test test/features/media/presentation/widgets/justified_media_block_test.dart`

- [ ] **Step 3: Implement** in the new file. Rows are runs of equal `rectOf(cell).top`.

- [ ] **Step 4: Run, expect PASS.**

- [ ] **Step 5: Commit** `feat(media): a non-scrolling justified block for details pages`

### Task 3: Species section in justified rows, with captions and "+N"

**Files:**
- Modify: `lib/features/media/presentation/widgets/species_photos_section.dart`
- Modify: `lib/features/media/presentation/widgets/media_grid.dart:66-103` (`MediaThumbnailTile` gains `Size targetSize = const Size(200, 200)` and `ValueChanged<Size>? onImageSize`, passed to `MediaItemView`)
- Modify: every `lib/l10n/arb/app_*.arb` (11 files), next to `marineLife_speciesPhotos_thumbnailLabel`
- Test: `test/features/media/presentation/widgets/species_photos_section_test.dart`

**Interfaces:**
- Consumes: `mediaEntriesForSpeciesProvider` (Task 1), `JustifiedMediaBlock` / `JustifiedBlockCell` (Task 2).
- Produces: `SpeciesPhotosSection({required String speciesId, VoidCallback? onTagPhotos, VoidCallback? onAddPhotos, List<MediaItem> pendingItems = const [], Widget Function(MediaItem item)? pendingOverlay, Widget? changedMark})`. `pendingTiles` is removed. Public constants: `kSpeciesPhotoRowHeight = 150`, `kSpeciesPhotoGap = 4`, `kSpeciesPhotoMaxRows = 3`.
- New ARB key `marineLife_speciesPhotos_moreLabel`: `"{count, plural, one{{count} more photo} other{{count} more photos}}"` with an `int count` placeholder.

- [ ] **Step 1: Write the failing tests** (override `mediaEntriesForSpeciesProvider('sp_x')` in `_pump`; give items `width`/`height` through `copyWith`):
  - `lays photos out at their own shapes`: a 3:2 and a 2:3 photo get the same height and widths in a 9:4 proportion (±1 px).
  - `captions each photo with its dive date and site`: an entry with `diveDateTime: DateTime.utc(2025, 3, 12)` and `siteName: 'Blue Hole'` shows `'<formatDate> · Blue Hole'`. Build the expected text with the test's `UnitFormatter`, not a literal.
  - `a dive with no site captions the date alone`, and `a photo with no dive has no caption`.
  - `caps at three rows and opens the viewer at the first hidden photo from +N`: 20 square photos at a 390-wide surface show `'+N'` on the last visible tile. Tapping it pushes `SpeciesPhotoViewerPage` with `initialMediaId` of the first hidden entry.
  - `+N is announced as more photos`: the semantics label of the "+N" tile contains `'N more photos'`.
  - `pending photos come first, uncaptioned, and are never hidden by the cap`: 12 pending plus 20 stored. Every pending item's overlay key is found, and no caption shows on them.
  - Keep the existing tests (title count, empty state, actions, browser, tap opens viewer) passing against the entries provider.

- [ ] **Step 2: Run, expect failures.** `flutter test test/features/media/presentation/widgets/species_photos_section_test.dart`

- [ ] **Step 3: Implement.**
  - Watch `mediaEntriesForSpeciesProvider` and `mediaLearnedAspectsProvider`. Treat a null learned value like loading, as the library does.
  - Ratios: pending first, then stored.
  - `JustifiedMediaBlock(maxRows: kSpeciesPhotoMaxRows, keepAtLeast: pendingItems.length, ...)`.
  - A stored tile is a `GestureDetector` around a `Stack`: `MediaThumbnailTile` with `targetSize: mediaThumbnailDecodeTarget(cell.size)` and `onImageSize` reporting to the learned store, plus a private `_CaptionBar`. The bar is a bottom-aligned gradient to black at 0.6 alpha, white `labelSmall`, `maxLines: 1`, `TextOverflow.ellipsis`, and absent below width 64.
  - When `hiddenCount > 0`, overlay black at 0.5 alpha with a centred `'+$hiddenCount'` in white `titleLarge`. Wrap it in `Semantics(label: moreLabel(hiddenCount), button: true)`, and make the tap open the viewer at `entries[visibleStoredCount].item.id` instead.
  - A stored tile's label is the thumbnail label plus `', <caption>'` when there is one.
  - A pending tile is `MediaThumbnailTile` plus `pendingOverlay?.call(item)` in a `Stack`.
  - Run `flutter gen-l10n` after the ARB edits.

- [ ] **Step 4: Run, expect PASS.** Also run `test/features/media/presentation/pages/species_photo_viewer_page_test.dart`.

- [ ] **Step 5: Do not commit yet.** Removing `pendingTiles` breaks the editing page until Task 4, so Tasks 3 and 4 land in one commit: `feat(media): species photos in justified rows with captions and a row cap`.

### Task 4: Editing page passes pending photos as data

**Files:**
- Modify: `lib/features/marine_life/presentation/pages/species_detail_page_editing.dart:128-180`
- Modify: `test/features/marine_life/presentation/pages/species_detail_page_unlock_harness.dart:190` (override `mediaEntriesForSpeciesProvider` too)
- Test: `test/features/marine_life/presentation/pages/species_detail_page_unlock_test.dart`

**Interfaces:**
- Consumes: `SpeciesPhotosSection.pendingItems` / `pendingOverlay` (Task 3).

- [ ] **Step 1:** Run `species_detail_page_unlock_test.dart`. Expect compile failure on `pendingTiles` once Task 3 has landed.
- [ ] **Step 2:** Pass `pendingItems: held` and `pendingOverlay: (item) => Align(... the existing IconButton keyed species_pending_remove_<id> ...)`.
- [ ] **Step 3:** Run the unlock test and `species_photos_section_test.dart`. Expect PASS, including the existing pending-remove tests.
- [ ] **Step 4:** `dart format .`, `flutter analyze`, then commit Tasks 3 and 4 together with the Task 3 message.
