# Media Grouped Flat Grid Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make By dive and Timeline build only the tiles and headers near the viewport, with no visible change.

**Architecture:** A pure `MediaGroupedGridTable` holds every cell's geometry and answers lookups by binary search; a thin `SliverGridDelegate` exposes it to a single `GridView.builder`. Headers are measured up front from one shared definition, and a place-keeping correction replaces what the old list's estimates absorbed.

**Tech Stack:** Flutter slivers (`SliverGridDelegate`, `SliverGridLayout`), `TextPainter`, Riverpod for the existing thumbnail scale.

**Spec:** `docs/design/specs/2026-10-30-media-grouped-flat-grid-design.md`

## Global Constraints

- No em dashes, and no mention of the tool that wrote this, in code, comments, commits or the PR.
- Nothing changes visually: tile rects, header heights and paging match today.
- No `ScrollController` on the list: it stays the page's primary scroll view.
- `MediaThumbnailZoomAnchor.scrollOffsetFor` keeps its signature and meaning.
- Files stay within 800 lines; `media_library_grouped_list.dart` should shrink.
- `test/features/media/presentation/tmp_group_bench_test.dart`, any `goldens/` or `failures/` directory are throwaway. Stage explicit paths only, one per argument.
- Before each commit: `dart format`, `flutter analyze`, affected tests. Run `test/architecture/` and `test/shared/` after adding files under `lib/`.
- Never edit files while a hooked push runs.

## Review Focus

1. An empty gallery, and a group with no entries: `RenderSliverGrid` asks for geometry at index 0 and at the child count, so the layout must answer out of range (Task 1).
2. A short last row: the next header starts directly after it, with no extra gap (Task 1).
3. Right-to-left: tiles mirror and headers stay full width (Task 1, Task 3).
4. Selection mode in a very long list: the place holds on the first frame (Task 4).
5. A narrow pane where a header wraps, then widens so it does not: its height and the place both follow (Task 2, Task 4).

---

### Task 1: The cell table and grid delegate

**Files:**
- Create: `lib/features/media/presentation/widgets/media_grouped_grid.dart`
- Test: `test/features/media/presentation/media_grouped_grid_test.dart`

**Interfaces:**
- Produces:
  - `class MediaGridSection { const MediaGridSection({required this.headerExtents, required this.tileCount}); final List<double> headerExtents; final int tileCount; }` with value equality.
  - `class MediaGridPlace { final int cell; final double fraction; }`
  - `class MediaGroupedGridTable` with `factory MediaGroupedGridTable.build({required List<MediaGridSection> sections, required int columns, required double paneWidth})`, `int get cellCount`, `double get totalExtent`, `double get tileExtent`, `int sectionOf(int cell)`, `int tileIndexOf(int cell)` (-1 for a header), `int headerIndexOf(int cell)` (-1 for a tile), `int minCellAt(double offset)`, `int maxCellAt(double offset)`, `SliverGridGeometry geometryOf(int cell, {required bool reverseCrossAxis})`, `MediaGridPlace placeAt(double offset)`, `double offsetOf(MediaGridPlace place)`, `bool hasSameCellsAs(MediaGroupedGridTable other)`.
  - `class MediaGroupedGridDelegate extends SliverGridDelegate { const MediaGroupedGridDelegate(this.table); }`, `shouldRelayout` when the table is not identical.

- [ ] **Step 1: Write failing tests:** offsets for two sections with a short last row, tile rects equal to `SliverGridDelegateWithFixedCrossAxisCount` at inset 8 and gap 4 for several column counts, mirroring, `minCellAt`/`maxCellAt` returning row starts and ends and clamping past the end, geometry at index 0 of an empty table and at `cellCount`, a section with no tiles, `placeAt`/`offsetOf` round trip including across a column change, `hasSameCellsAs` true across width, columns and header heights and false when a section's tile count differs.
- [ ] **Step 2: Run.** Expected: FAIL, file missing.
- [ ] **Step 3: Implement** with `Float64List` tops and heights and `Int32List` section and slot arrays.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** as `feat(media): add the grouped gallery's cell table`.

### Task 2: One header definition, drawn and measured

**Files:**
- Create: `lib/features/media/presentation/widgets/media_group_header.dart`
- Test: `test/features/media/presentation/media_group_header_test.dart`

**Interfaces:**
- Produces:
  - `enum MediaGroupHeaderKind { month, day, dive }`
  - `class MediaGroupHeaderSpec { kind, label, diveId? , hint? }`, with `bool get navigable => diveId != null`.
  - `class MediaGroupHeader extends StatelessWidget { const MediaGroupHeader({required this.spec, this.onTap}); }`, the widgets from `media_library_grouped_list.dart` moved here.
  - `class MediaGroupHeaderMeasurer { double extentOf(MediaGroupHeaderSpec spec, double paneWidth); }`, built from a `BuildContext` for style, `TextScaler`, direction, locale, bold text and height behaviour, with `factory MediaGroupHeaderMeasurer.of(BuildContext context)` and `bool matches(MediaGroupHeaderMeasurer other)` so the cache survives a rebuild.

- [ ] **Step 1: Write failing tests** comparing `extentOf` with the real laid-out `MediaGroupHeader` height for: each kind fitting on a line, a label wrapping to two and three lines, `TextScaler.linear(2)`, right-to-left, 320 wide, navigable floor and inert. Add one that a width change only re-lays wrapped labels, by counting through a test seam on the measurer.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** Style is `DefaultTextStyle.of(context).style.merge(themeStyle)`, plus bold text from `MediaQuery.boldTextOf`.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** as `feat(media): measure grouped gallery headers from what draws them`.

### Task 3: Switch the list to the grid

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_library_grouped_list.dart`
- Modify: `lib/features/media/presentation/widgets/media_thumbnail_zoom_anchor.dart`
- Modify: `lib/features/media/presentation/widgets/media_library_grid.dart` (comment only)
- Test: `test/features/media/presentation/media_library_grouped_list_test.dart`
- Test: `test/features/media/presentation/media_library_grid_test.dart`

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces: `MediaThumbnailSlot.row` is the tile's group index. `MediaThumbnailZoomAnchor` has no `leadingRow`.

- [ ] **Step 1: Write failing tests:** tile builds bounded for 60, 180 and 1,000 in one group and 500 and 3,000 small groups, scrolled and not; header builds bounded; total extent equals a hand sum; right-to-left tile positions; and `the grouped views prepare two pane heights too`, replacing the exemption in `media_library_grid_test.dart`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** A `LayoutBuilder` gives the width. Sections are recomputed each build and the table reused when the sections, columns and width are equal, so a selection toggle with no height change keeps it. Wheel zoom sums every group above the anchor's using the kept group counts. Remove `leadingRow` and the walk in `_anchorFor`.
- [ ] **Step 4: Run** `flutter test test/features/media`. The "zooming in and out" tests must pass unchanged. Expected: PASS.
- [ ] **Step 5: Commit** as `feat(media): build the grouped gallery as one lazy grid`.

### Task 4: Keep the diver's place

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_library_grouped_list.dart`
- Test: `test/features/media/presentation/media_library_grouped_list_place_test.dart`

**Interfaces:**
- Consumes: `placeAt`, `offsetOf`, `hasSameCellsAs` from Task 1.

- [ ] **Step 1: Write failing tests,** each asserting the top visible tile's screen top on the first frame after the change: entering and leaving selection in By dive with 300 dives above, the columns changing with no wheel anchor, a width change, ten width changes in a row, and a header that stops wrapping as the pane widens. Add `paging moves nothing on screen`.
- [ ] **Step 2: Run.** Expected: FAIL, the content jumps.
- [ ] **Step 3: Implement** one private method called from the `LayoutBuilder` when the table changes: the wheel anchor when there is one, otherwise `correctPixels` to `next.offsetOf(previous.placeAt(pixels))` if `hasSameCellsAs`.
- [ ] **Step 4: Run** `flutter test test/features/media test/architecture test/shared`. Expected: PASS.
- [ ] **Step 5: Commit** as `feat(media): keep the place when gallery heights change`.

### Task 5: Measure

**Files:** none committed.

- [ ] **Step 1: Run** `tmp_group_bench_test.dart` and record against the baseline: 1,000 in a group built 1,000 tiles, first frame 2,224 ms, toggle 492 ms, 60 scroll frames 415 ms. 3,000 small groups built 12 tiles, 57 ms, 20 ms, 76 ms.
- [ ] **Step 2: Delete** the benchmark, and confirm `git status --porcelain` is clean.
