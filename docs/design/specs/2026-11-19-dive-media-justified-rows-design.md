# Dive media in justified rows (issue #4739)

## Intent

The Media card on a dive's details draws its photos, videos and documents as
square crops, four across. The media library now lays media out in justified
rows that keep each item's shape (#4738, PR #4755). The dive card should use
the same layout, so a dive's media keeps its aspect ratios and looks like the
library.

## Goals

- Dive media is laid out in justified rows: about 120 px target row height,
  4 px gaps, every closed row flush with the card's inner width. No square
  cropping remains.
- Everything the card does today keeps working: Select mode and its selection
  bar, drag-select inside Select mode, hover (which drives the profile
  marker), the right-click context menu, and tapping to open the photo viewer
  or a document.
- Documents keep the library's fixed page shape (3:4).
- Phone and desktop widths, light and dark mode.

## Non-goals

- No cap. The card keeps showing every item, as it does today (decided in
  design: no "+N" tile, no "View all").
- The site, species and other media cards are not changed here; they have
  their own issues (#4741, #4740). Two-row "Large" tiles (#4786) are out of
  scope.
- No change to the library itself or to the row packer.

## Approaches

1. **Chosen: the library's layout delegate inside the card's existing grid.**
   `DragSelectGridView` already accepts any `SliverGridDelegate`, and it finds
   the tile under a drag by each tile's own key, not by column maths. The card
   measures its width, builds a one-section `JustifiedMediaTable` from the
   items' shapes, and passes `JustifiedMediaGridDelegate`. Selection, drag,
   hover, the context menu and tap-to-open stay in the code they live in now.
2. Rejected: the library's `JustifiedMediaScrollView`. It is a page-level lazy
   scroller with load-more; inside a card on a scrolling page it nests one
   scroll in another, and it has no drag-select.
3. Rejected: a plain column of rows. It would mean rewriting selection,
   drag-select and hit-testing for no gain.

## Design

- **Shapes:** each item's ratio is `clampMediaAspect(mediaRawAspect(item,
  learned: ...))`, the library's rule: fixed 3:4 for a document, else a
  learned shape that still applies, else the stored size, else 4:3.
- **Learned shapes:** once the card has media to lay out, it watches
  `mediaLearnedAspectsProvider` and lays out once that has loaded (the card's
  spinner shows meanwhile; a cache that cannot be read yields an empty map, so
  the card never waits forever). A dive with no media reads no shapes. Each
  tile reports its decoded thumbnail size to the provider, as library tiles
  do, so a photo stored sideways corrects itself here and in the library.
- **Layout:** a `LayoutBuilder` gives the card's inner width;
  `JustifiedMediaTable.build` takes one section with no headers, target height
  120, gap 4, inset 0. The table is kept while the width and ratios are
  unchanged, so the delegate's identity check does not force a relayout on
  every rebuild. The grid stays `shrinkWrap` with no scrolling of its own.
- **Tiles:** the card keeps `MediaThumbnailTile` and its overlays (transfer
  badge, video icon, document extension, depth, the selection tint and
  check). The tile gains optional `targetSize` (default unchanged, 200 x 200)
  and `onImageSize`, so the card decodes at `mediaThumbnailDecodeTarget` of
  the cell size and learns shapes; every other caller is unaffected.

## Calls made by the builder (not decided with the maintainer)

- Waiting for learned shapes before the first layout, as the library does,
  rather than laying out from stored sizes and jumping later.
- Keeping the dive tile's overlays (depth matters on a dive page) rather than
  switching to the library tile.
- No narrow-tile rule for the depth badge: the packer's 48 px minimum width
  leaves room for it at 120 px rows.

## Testing

- Widget tests on `DiveMediaSection`: a wide photo, a tall photo and a
  document lay out at their shapes (widths differ, heights equal within a
  row), a closed row ends flush with the card's inner width, and a document is
  3:4.
- The existing selection, drag-select, hover, unlink and tap tests keep
  passing unchanged.
