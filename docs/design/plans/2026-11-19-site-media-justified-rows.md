# Site Media in Justified Rows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lay out Site Details' dive photos card and attachment tiles in the
#4738 justified rows, so no site media is cropped square (issue #4741).

**Architecture (as landed, see the amendment):** the dive photos card draws
its strip and its expanded view with #4793's `JustifiedMediaBlock`, capped
at one row while collapsed. Each attachment group hands a
`JustifiedMediaGridDelegate` to its existing `DragSelectGridView`, keeping
the table between rebuilds as #4792's dive card does. Tiles report decoded
shapes to `mediaLearnedAspectsProvider`, as library tiles do.

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

1. A grid with `padding: null` in a vertical scroll view adds the
   MediaQuery's top and bottom insets inside itself, so every group would
   carry the home indicator's gap. Each tile grid passes
   `padding: EdgeInsets.zero`; pinned in Task 3.
2. A selection change rebuilds every group; a fresh table each build would
   relayout every grid. Each group reuses its table while width and shapes
   are equal; pinned in Task 3.
3. Show all must not appear while the strip is still loading, and must
   appear when all 12 capped photos fit one row but the site has more;
   pinned in Task 2.
4. A strip whose photos do not reach the edge stays at target height and is
   not stretched (one photo is not blown up); pinned in Task 2.
5. Drag-select under the new delegate still maps a pointer to the tile under
   it, because tiles are now different widths; pinned in Task 3.

---

### Task 1: Shared pieces (as landed, per the amendment)

**Files:**
- Modify: `lib/features/media/presentation/helpers/media_layout_aspect.dart`
- Modify: `lib/features/media/presentation/widgets/media_library_grid.dart`
- Modify: `lib/features/media/presentation/widgets/media_grid.dart`
- Create: `lib/features/media/presentation/widgets/justified_media_block.dart`
- Modify: `test/features/media/presentation/support/media_widget_harness.dart`
- Test: `test/features/media/presentation/widgets/justified_media_block_test.dart`

**Interfaces (taken verbatim from #4792 and #4793):**
- `List<double> mediaLayoutRatios(Iterable<MediaItem> items, Map<String, LearnedAspect> learned)`
  in `media_layout_aspect.dart`; `mediaLibraryRatios` calls it.
- `MediaThumbnailTile` takes `Size targetSize = const Size(200, 200)` and
  `ValueChanged<Size>? onImageSize`, both passed to its `MediaItemView`.
- `class JustifiedMediaBlock extends StatelessWidget` with `ratios`,
  `rowHeight`, `gap`, `maxRows` (null for all rows), `keepAtLeast` and
  `cellBuilder` (`Widget Function(BuildContext, JustifiedBlockCell)`, where
  the cell carries `index`, `size` and `hiddenCount`). It lays tiles out in a
  `Stack` and builds every tile it shows.
- `FakeAspectCacheRepository` in the media widget harness: seedable `shapes`,
  and the ids `putAll` wrote, in `written`.

- [x] Copy the pieces, then run `justified_media_block_test.dart`,
  `media_library_grid_test.dart` and `media_library_justified_test.dart`.
- [x] Commit `feat(media): share the justified block and tile sizing with the dive and species work`.

### Task 2: Dive photos card

**Files:**
- Modify: `lib/features/media/presentation/widgets/site_dive_photos_card.dart`
- Test: `test/features/media/presentation/widgets/site_dive_photos_card_test.dart`

**Behaviour:**
- The card watches `mediaLearnedAspectsProvider` and, collapsed,
  `recentMediaFromDivesAtSiteProvider` (expanded,
  `flatMediaFromDivesAtSiteProvider`); it shows the spinner until both have
  a value.
- Collapsed: `JustifiedMediaBlock(maxRows: 1)` at `kSiteDivePhotoRowHeight`
  (100) and `kSiteDivePhotoGap` (4). Expanded: the same block with no cap.
- `hasMore` is `count > first row's count`, from `packJustifiedRows` over the
  strip's ratios at the card's width; false while loading or expanded.
- Each tile decodes at `mediaThumbnailDecodeTarget(cell.size)` and reports its
  decoded size to `mediaLearnedAspectsProvider`.

- [x] Rewrite the width-dependent tests (one row of the newest sharing a
  height, flush with the card, a lone photo not stretched, the query cap, a
  card narrower than one photo, Show all when the cap limits, hidden while
  loading or when everything fits, expanded shapes, waiting for the learned
  shapes, decode size and the shape report); watch them fail.
- [x] Implement; run the file; commit `feat(media): dive photos card in justified rows`.

### Task 3: Attachment tiles

**Files:**
- Modify: `lib/features/media/presentation/widgets/site_attachment_groups.dart`
- Test: `test/features/media/presentation/widgets/site_attachment_groups_test.dart`
- Test: `test/features/media/presentation/widgets/site_media_section_test.dart`
  (its host overrides the learned-shape store with `FakeAspectCacheRepository`)

**Behaviour (as the dive card in #4792):**
- `SiteAttachmentGroups` watches `mediaLearnedAspectsProvider` when any group
  has tiles and leaves the tile grids out until it has a value; headings and
  large cards are unchanged.
- Each group's tiles are a `_TileGrid` keyed `tiles-<category>`: the existing
  `DragSelectGridView` with `JustifiedMediaGridDelegate`, `padding:
  EdgeInsets.zero`, at `kSiteAttachmentRowHeight` (120) and
  `kSiteAttachmentGap` (4). It keeps its table while width and ratios are
  equal, decodes each tile at its table cell's size and reports decoded sizes.

- [x] Write the failing tests (shapes kept, a document at 3:4, waiting for
  the learned shapes, a selection change keeping the table, decode size,
  drag-select across uneven tiles, no safe-area padding, the shape report).
- [x] Implement; run both files; commit `feat(media): site attachment tiles in justified rows`.

### Task 4: Checks and after screenshots

- [ ] `dart format .`, `flutter analyze` (no issues).
- [ ] Re-run the five test files above, by path.
- [ ] After screenshots with the throwaway golden
  (`--dart-define=STAGE=after`), copy to the scratchpad, delete
  `test/_pr_shots/` before pushing.
