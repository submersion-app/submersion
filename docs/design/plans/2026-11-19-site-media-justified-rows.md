# Site Media in Justified Rows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lay out Site Details' dive photos card and attachment tiles in the
#4738 justified rows, so no site media is cropped square (issue #4741).

**Architecture:** One shared wrapper, `JustifiedMediaBlock`, measures its
width and builds a `JustifiedMediaTable` for a list of `MediaItem`s; callers
hand its `JustifiedMediaGridDelegate` to the grids they already use (a plain
`GridView` for expanded dive photos, `DragSelectGridView` for attachment
tiles). The collapsed strip packs with `packJustifiedRows` directly and draws
only the first row. Tiles report decoded shapes to
`mediaLearnedAspectsProvider`, as library tiles do.

**Tech Stack:** Flutter, Riverpod 3, flutter_test.

**Spec:** `docs/design/specs/2026-11-19-site-media-justified-rows-design.md`

## Global Constraints

- Gap between tiles: 4 px. Inset: 0 (the card's padding is the margin).
- Minimum tile width: `kMediaThumbnailMinTileWidth` (48).
- Target heights: 100 px for dive photos (strip and expanded), 120 px for
  attachment tiles.
- Strip reads at most `kSiteDivePhotoStripLimit` (12); unchanged.
- Documents lay out at `kMediaDocumentAspect` (3:4) via `mediaRawAspect`.
- Large attachment cards, headings and group order unchanged.
- No new user-visible strings.
- Run only the test files named here, by path (pre-push runs the rest).

## Amendment (2026-11-20): share the dive and species work

PRs #4792 (dive media, #4739) and #4793 (species, #4740) landed in review
while this plan ran, and #4793 adds its own `JustifiedMediaBlock` at the path
Task 1 planned. To keep one way of doing this and let the three PRs merge in
any order, Task 1 is replaced:

- `mediaLayoutRatios`, `MediaThumbnailTile`'s `targetSize` / `onImageSize` and
  `mediaLibraryRatios` are taken verbatim from #4792.
- `JustifiedMediaBlock` (Stack-based, `maxRows`) and its test, and
  `FakeAspectCacheRepository` in the media test harness, are taken verbatim
  from #4793.
- Task 2 draws the strip with `JustifiedMediaBlock(maxRows: 1)` and the
  expanded view with no cap; Show all appears when the block hides any or the
  site holds more than the strip read. Both wait for the learned shapes.
- Task 3 follows #4792's dive card: each group caches its table while width
  and shapes hold, waits for the learned shapes, and a tile decodes at its
  table cell's size.

## Review Focus

1. A grid with `padding: null` in a scroll view picks up MediaQuery padding
   (notched phone in landscape), so its cross extent is narrower than the
   measured width and the last tile overflows. Every justified grid passes
   `padding: EdgeInsets.zero`; pinned in Task 1.
2. A selection change rebuilds every group; a fresh table each build would
   relayout every grid. The block reuses its table while inputs are equal;
   pinned in Task 1.
3. Show all must not appear while the strip is still loading, and must
   appear when all 12 capped photos fit one row but the site has more;
   pinned in Task 2.
4. A strip whose photos do not reach the edge stays at target height and is
   not stretched (one photo is not blown up); pinned in Task 2.
5. Drag-select under the new delegate still maps a pointer to the tile under
   it, because tiles are now different widths; pinned in Task 3.

---

### Task 1: Shared justified block and tile

**Files:**
- Modify: `lib/features/media/presentation/helpers/media_layout_aspect.dart`
- Modify: `lib/features/media/presentation/widgets/media_library_grid.dart`
  (`mediaLibraryRatios` delegates to the new helper)
- Modify: `lib/features/media/presentation/widgets/media_grid.dart`
  (`MediaThumbnailTile`)
- Create: `lib/features/media/presentation/widgets/justified_media_block.dart`
- Create: `test/features/media/presentation/support/fake_media_aspect_cache.dart`
- Test: `test/features/media/presentation/widgets/justified_media_block_test.dart`

**Interfaces:**
- Produces:
  - `List<double> mediaItemRatios(List<MediaItem> items, Map<String, LearnedAspect> learned)`
    in `media_layout_aspect.dart`: `clampMediaAspect(mediaRawAspect(...))`
    per item.
  - `MediaThumbnailTile` gains `Size targetSize = const Size(200, 200)` and
    `ValueChanged<Size>? onImageSize`, both passed to its `MediaItemView`.
  - `class JustifiedMediaBlock extends ConsumerStatefulWidget` with
    `items` (`List<MediaItem>`), `targetHeight` (`double`),
    `gap` (`double`, default 4), and
    `builder` (`Widget Function(BuildContext context, JustifiedMediaTable table)`).
    Renders `SizedBox.shrink()` until `mediaLearnedAspectsProvider` has a
    value; then a `LayoutBuilder` builds the table with one header-less
    `JustifiedSection`, `inset: 0`, `minTileWidth: kMediaThumbnailMinTileWidth`.
    Keeps the last table and returns it when section, width, target height
    and gap are all equal.
  - `class JustifiedMediaTile extends ConsumerWidget`: the same fields as
    `MediaThumbnailTile`; a `LayoutBuilder` passes
    `mediaThumbnailDecodeTarget(constraints.biggest)` as `targetSize` and
    reports `onImageSize` to `mediaLearnedAspectsProvider.notifier.report`.
  - `class FakeMediaAspectCache implements MediaAspectCacheRepository`
    (test support): in-memory `loadAll` / `putAll`, seedable map.

- [ ] **Step 1: Write the failing tests** in `justified_media_block_test.dart`
  (host: `mediaTestApp` with `mediaAspectCacheRepositoryProvider` overridden by
  `FakeMediaAspectCache`; items via `testMediaItem(...).copyWith(width:, height:)`):
  - `'tiles keep each item's shape'`: 400x300 and 300x400 items, block 400
    wide, target 100, builder returns
    `GridView.builder(shrinkWrap: true, padding: EdgeInsets.zero, gridDelegate: JustifiedMediaGridDelegate(table), ...)`.
    Expect each `JustifiedMediaTile` rect's width/height within 0.01 of
    4/3 and 3/4.
  - `'a learned shape wins over the stored size'`: seed the fake with
    `(ratio: 0.75, width: 400, height: 300)` for the 400x300 item; expect its
    tile ratio 0.75.
  - `'a document lays out at a page's shape'`: `mediaType: MediaType.document`
    tile ratio 0.75.
  - `'an unchanged rebuild keeps the same table'`: capture the table from two
    builds around a `setState` in the host; `identical(first, second)` is true;
    after a width change it is false.
  - `'the last tile ends at the block's right edge under MediaQuery padding'`:
    wrap in `MediaQuery(data: ...copyWith(padding: EdgeInsets.symmetric(horizontal: 40)))`
    with enough items to close a row; the first row's last tile `right`
    equals the block's `right` within 0.5.
  - `'a tile reports its decoded size'`: after settle,
    `container.read(mediaLearnedAspectsProvider)` holds the item whose
    decoded 1x1 PNG differs from its stored 400x300.

- [ ] **Step 2: Run, expect FAIL** (compile errors: missing symbols).
  `flutter test test/features/media/presentation/widgets/justified_media_block_test.dart`

- [ ] **Step 3: Implement** the interfaces above; point `mediaLibraryRatios`
  at `mediaItemRatios([for (final e in entries) e.item], learned)`.

- [ ] **Step 4: Run, expect PASS**, plus
  `test/features/media/presentation/media_library_grid_test.dart` and
  `test/features/media/presentation/media_library_justified_test.dart`
  (unchanged behaviour after the ratios refactor).

- [ ] **Step 5: Commit** `feat(media): justified block for inline media grids`
  (stage explicit paths; never `test/_pr_shots`).

### Task 2: Dive photos card

**Files:**
- Modify: `lib/features/media/presentation/widgets/site_dive_photos_card.dart`
- Test: `test/features/media/presentation/widgets/site_dive_photos_card_test.dart`

**Interfaces:**
- Consumes: `JustifiedMediaBlock`, `JustifiedMediaTile`, `mediaItemRatios`,
  `packJustifiedRows`, `FakeMediaAspectCache`.
- Behaviour: when collapsed, the card state watches
  `recentMediaFromDivesAtSiteProvider` and `mediaLearnedAspectsProvider`,
  packs the recent ratios at the strip width (target 100, gap 4,
  `kMediaThumbnailMinTileWidth`) and keeps `rows.first`. `hasMore` is
  `count > rows.first.count`, false while loading or on error. The strip
  draws `rows.first` as a `Row` of `SizedBox(width: widths[k], height: row.height)`
  tiles separated by 4 px. Expanded uses `JustifiedMediaBlock` (target 100)
  with a non-scrolling shrink-wrapped `GridView.builder`,
  `padding: EdgeInsets.zero`. `_kStripTileMinSize` and the column count go.

- [ ] **Step 1: Rewrite the width-dependent tests** for justified rows
  (host overrides `mediaAspectCacheRepositoryProvider` with
  `FakeMediaAspectCache`; photos given stored sizes):
  - replace `'strip shows as many of the newest photos as fit'`: 400 strip,
    ten 400x300 photos at target 100 (4/3 x 100 = 133 + gap): expect the ids
    of `rows.first` from `packJustifiedRows` with the same inputs, and every
    tile the same height.
  - keep `'the strip tiles fill the row edge to edge'`: last tile right =
    strip right within 0.5.
  - `'a strip that does not reach the edge is not stretched'`: one 400x300
    photo, count 1: tile height 100, width 133.3, Show all absent.
  - `'strip never exceeds the query cap'`: unchanged assertion (at most 12
    shown).
  - `'Show all is offered when every capped photo fits but more exist'`:
    1200-wide card, twelve 1:3 portraits (all fit), count 30: Show all shown.
  - `'Show all is hidden while the strip loads'`: pending recent future: no
    Show all.
  - replace `'a card under two tiles wide...'`: 60-wide strip, one tile a row,
    as wide as the strip.
  - `'expanded tiles keep their shapes'`: Show all, 300x400 photo's tile
    ratio 0.75 within 0.01.
  - the open, viewer, read-only, loading and error tests stay as they are.

- [ ] **Step 2: Run, expect FAIL.**
  `flutter test test/features/media/presentation/widgets/site_dive_photos_card_test.dart`

- [ ] **Step 3: Implement** the behaviour above.

- [ ] **Step 4: Run, expect PASS.**

- [ ] **Step 5: Commit** `feat(media): dive photos card in justified rows`.

### Task 3: Attachment tiles

**Files:**
- Modify: `lib/features/media/presentation/widgets/site_attachment_groups.dart`
- Test: `test/features/media/presentation/widgets/site_attachment_groups_test.dart`
- Test: `test/features/media/presentation/widgets/site_media_section_test.dart`
  (add the `FakeMediaAspectCache` override to its host only if it needs one
  to settle)

**Interfaces:**
- Consumes: `JustifiedMediaBlock`, `JustifiedMediaTile`.
- `_tileGrid` returns `JustifiedMediaBlock(key: ValueKey('tiles-...'), items: tiles, targetHeight: 120, builder: ...)`
  whose builder is the existing `DragSelectGridView` with
  `gridDelegate: JustifiedMediaGridDelegate(table)`,
  `padding: EdgeInsets.zero`, and `JustifiedMediaTile` as the item. The key
  moves from the grid to the block (the Column's direct child).

- [ ] **Step 1: Write the failing tests** in `site_attachment_groups_test.dart`:
  - `'tiles keep each attachment's shape'`: underwater 400x300 and 300x400
    tiles, ratios 4/3 and 3/4 within 0.01.
  - `'a document tile lays out at a page's shape'`: ratio 0.75.
  - `'drag-select covers the tiles between the anchor and the pointer'`: in
    selection mode, four tiles of mixed shapes in one row; long-press the
    first, move to the centre of the third, release; the controller holds the
    first three ids only.
  - existing selection, open and edit tests unchanged.

- [ ] **Step 2: Run, expect FAIL.**
  `flutter test test/features/media/presentation/widgets/site_attachment_groups_test.dart`

- [ ] **Step 3: Implement.**

- [ ] **Step 4: Run, expect PASS**, plus
  `test/features/media/presentation/widgets/site_media_section_test.dart`.

- [ ] **Step 5: Commit** `feat(media): site attachment tiles in justified rows`.

### Task 4: Checks and after screenshots

- [ ] `dart format .`, `flutter analyze` (no issues).
- [ ] Re-run the five test files above, by path.
- [ ] After screenshots with the throwaway golden
  (`--dart-define=STAGE=after`), copy to the scratchpad, delete
  `test/_pr_shots/` before pushing.
