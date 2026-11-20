# Dive Media in Justified Rows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The dive details Media card lays its items out in justified rows (about 120 px, 4 px gaps) instead of four square columns, keeping every current behaviour.

**Architecture:** `DiveMediaSection` keeps its `DragSelectGridView`; a `LayoutBuilder` measures the card's inner width, a one-section `JustifiedMediaTable` is built from each item's shape, and `JustifiedMediaGridDelegate` replaces the fixed four-column delegate. `MediaThumbnailTile` gains an optional decode size and size callback so the card decodes at the cell's size and teaches `mediaLearnedAspectsProvider` a photo's real shape.

**Tech Stack:** Flutter, Riverpod, flutter_test.

**Spec:** `docs/design/specs/2026-11-19-dive-media-justified-rows-design.md`

## Global Constraints

- Target row height 120, gap 4, inset 0, minimum tile width the table default (48).
- Item shape: `clampMediaAspect(mediaRawAspect(item, learned: learned[item.id]))`; documents 3:4.
- No cap: every item shows.
- `MediaThumbnailTile`'s defaults stay as they are (`targetSize` 200 x 200, no size callback), so its other callers do not change.
- No em-dashes in code, comments or docs.

## Review Focus

1. The learned-shapes cache cannot be read: the card still lays out (from stored sizes) rather than spinning forever. Test in Task 2.
2. The card's width changes (window resize, phone rotation): the rows repack to the new width. Test in Task 2.
3. A learned shape for an item overrides its stored size (a photo stored sideways). Test in Task 2.
4. Unlinking an item in the open card: the remaining items repack and the hover/selection tests still pass (existing `dive_media_section_unlink_test.dart`, `dive_media_section_hover_test.dart`).
5. Drag-select across a row break selects the contiguous run in list order (existing drag-select behaviour, keyed hit-testing; covered by the existing selection tests running unchanged).

---

### Task 1: Thumbnail tile decode size and size callback

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_grid.dart` (`MediaThumbnailTile`)
- Test: `test/features/media/presentation/widgets/media_grid_test.dart` (the tile's existing tests live here)

**Interfaces:**
- Produces: `MediaThumbnailTile({..., Size targetSize = const Size(200, 200), ValueChanged<Size>? onImageSize})`, both forwarded to its `MediaItemView`.

- [ ] **Step 1: Write the failing tests**: `'forwards targetSize to MediaItemView'` (pump a tile with `targetSize: Size(400, 400)`, expect `tester.widget<MediaItemView>(...).targetSize == const Size(400, 400)`); `'defaults targetSize to 200 x 200'`; `'forwards onImageSize to MediaItemView'` (identical callback).
- [ ] **Step 2: Run** `flutter test test/features/media/presentation/widgets/media_grid_test.dart`; expect compile failure on the new parameters.
- [ ] **Step 3: Add the two parameters** and pass them to `MediaItemView`.
- [ ] **Step 4: Run** the same file; expect PASS.

### Task 2: Justified layout in the dive Media card

**Files:**
- Modify: `lib/features/media/presentation/widgets/dive_media_section.dart`
- Test: `test/features/media/presentation/widgets/dive_media_section_justified_test.dart` (create)

**Interfaces:**
- Consumes: Task 1's tile parameters; `JustifiedMediaTable.build`, `JustifiedMediaGridDelegate`, `JustifiedSection` (`justified_media_grid.dart`); `mediaRawAspect`, `clampMediaAspect` (`media_layout_aspect.dart`); `mediaLearnedAspectsProvider`, `mediaAspectCacheRepositoryProvider`; `mediaThumbnailDecodeTarget`.
- Produces: `const double kDiveMediaRowHeight = 120;` and `const double kDiveMediaGap = 4;` in `dive_media_section.dart`.

The test host overrides `mediaAspectCacheRepositoryProvider` with a fake whose `loadAll` returns a given map (or throws), `mediaForDiveProvider('dive-1')` with the items, and `settingsProvider` with `MockSettingsNotifier`. Rects come from `tester.getRect` of each `MediaHoverRegion` under the grid.

- [ ] **Step 1: Write the failing tests**:
  - `'lays each item out at its own shape'`: items 600x400 photo, 400x600 photo, a document; the three share a top and a height; width/height is 1.5 and 0.667 (within 0.02) for the photos and 0.75 for the document, unless the row closed and the last tile absorbed rounding (assert on the non-last tiles, and on the document placed first in a second variant).
  - `'a full row ends flush with the card'`: 12 photos of 600x400 in an 800-wide window; the first row's last tile's right edge equals the grid's right edge (within 0.5), gaps between neighbours are 4.
  - `'rows aim at 120 px'`: the last (open) row's height is 120.
  - `'a learned shape overrides the stored size'`: a 600x400 photo with learned `(ratio: 0.75, width: 600, height: 400)`; its tile's width/height is 0.75.
  - `'lays out when the learned shapes cannot be read'`: `loadAll` throws; after `pumpAndSettle` the tiles are there.
  - `'repacks when the card width changes'`: pump at 800 wide, then set `tester.view.physicalSize` narrower and pump; the first row holds fewer tiles.
- [ ] **Step 2: Run** `flutter test test/features/media/presentation/widgets/dive_media_section_justified_test.dart`; expect FAIL (square tiles).
- [ ] **Step 3: Implement** in `_buildCard`'s data branch, with `mediaLearnedAspectsProvider` watched in the State's own `build` and passed down; while it has no value show the existing loading spinner. Wrap the grid in a `LayoutBuilder`; ratios as in Global Constraints; keep the table in State and rebuild it only when the width or the ratio list changes (`listEquals`), so `shouldRelayout` sees the same table. Pass `JustifiedMediaGridDelegate(table)`. In `itemBuilder` the cell size is `table.rectOf(index).size`; give the tile `targetSize: mediaThumbnailDecodeTarget(size)` and `onImageSize: (s) => ref.read(mediaLearnedAspectsProvider.notifier).report(item, s)`. `DragSelectGridView.itemBuilder` passes the item, not the index: look the index up in an id-to-index map built beside the ratios (ids are unique).
- [ ] **Step 4: Run** the new file plus `dive_media_section_hover_test.dart`, `dive_media_section_unlink_test.dart`, `dive_media_section_lightroom_test.dart`, `test/features/dive_log/presentation/pages/dive_detail_media_hover_page_test.dart` and `test/features/media/presentation/pages/media_viewer_held_media_test.dart`; expect PASS.
- [ ] **Step 5:** `dart format .`, `flutter analyze`, then commit `feat(media): lay dive media out in justified rows`.
