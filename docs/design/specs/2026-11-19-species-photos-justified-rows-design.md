# Species photos in justified rows (issue #4740)

## Intent

A species page's Photos section crops every tagged photo to a square, three
across. Once the justified-row layout from #4738 (PR #4755) exists, this
section uses it too, so each photo keeps its shape. A species' photos come
from many dives, so each tile also says which dive it is from.

## Goals

- Species photos laid out in justified rows: target row height 150 px, 4 px
  gap, no square cropping. Shapes come from the same learned and stored
  aspects as the library, so a sideways-stored photo is drawn upright here
  too, and documents keep their fixed page shape.
- A caption bar on each tile with the dive's date (in the diver's date
  format) and site name, joined by " · ", cut off with an ellipsis. A photo
  with no dive has no caption. A photo whose dive has no site shows the date
  alone.
- At most 3 rows. When photos are left over, the last visible tile is dimmed
  and shows "+N" (the number not shown). Tapping it opens the species photo
  viewer at the first hidden photo; the viewer already pages through them
  all.
- Tapping any other tile opens the species photo viewer at that photo, as
  today. Tag photos and Add photos stay as they are.
- Phone and desktop widths, light and dark mode.

## Non-goals

- The dive (#4739) and site (#4741) sections. They are separate issues; the
  new block is written so they can reuse it.
- Any change to the species photo viewer, the tag picker or the import flow.
- Zoom (size slider, Ctrl + wheel) in this section: the row height is fixed.

## Approaches

- **A. A shared, non-scrolling `JustifiedMediaBlock` (chosen).** Measures its
  width, builds one `JustifiedMediaTable` (from #4755) of a single section,
  trims it to a maximum number of rows, and places each tile in a box of the
  table's height. The caller supplies the tile builder. Fits inside a details
  page's own scroll, and #4739 and #4741 can reuse it.
- **B. A shrink-wrapped `GridView` with `JustifiedMediaGridDelegate`.** Least
  new code, but the row cap still needs a trimmed table, a shrink-wrapped
  grid builds every child anyway, and it is harder to reuse cleanly.
- **C. Rework the species page into slivers and reuse
  `JustifiedMediaScrollView`.** Rewrites a page the unified-editing work just
  changed, far beyond this issue.

The diver picked A.

## Design

- **`JustifiedMediaBlock`** (`lib/features/media/presentation/widgets/`):
  takes the ratios, a row height, a gap, an optional `maxRows`, and a cell
  builder that gets the tile index, its laid-out size, and how many items
  were cut (non-zero only for the last visible tile). With no width yet, or
  no items, it draws nothing.
- **Row cap:** the table is built for all items; the block keeps the cells
  whose row is among the first `maxRows`, so the visible rows are exactly
  where they would be uncapped.
- **Data:** the species media query also returns each photo's dive date and
  site name (it already joins `dives`). The section receives entries
  carrying the item, the dive date and the site name; the photo viewer keeps
  working from the same list.
- **Photos waiting in an editing session** (unified editing, #4527 phase 3)
  are passed to the section as media items plus an overlay builder for their
  remove button, in place of finished widgets, so their shapes are known.
  They are laid out ahead of the stored photos, as today.
- **Learning shapes:** species tiles report their decoded thumbnail size to
  the shared learned-aspects store, as library tiles do.

## Builder's calls (marked so the diver can check them)

- Pending photos in an editing session show no caption: they are not yet in
  the query that carries the dive data, and they already carry a remove
  button.
- The cap never hides a pending photo: while pending photos are held, the
  block shows at least as many rows as they need.
- The caption bar is hidden on tiles narrower than 64 px
  (`kMediaTileDetailWidth`, the library's threshold for dropping tile
  details), and ellipsized on every wider tile.
- A tile's screen reader label adds its caption to the existing "species
  photo" label; the "+N" tile is announced as showing N more photos.
