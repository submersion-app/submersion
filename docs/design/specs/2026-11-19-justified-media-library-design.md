# Justified-row media library (issue #4738)

## Intent

The media library draws every photo and video as a square crop in a
fixed-column grid. Portrait shots, panoramas and 9:16 phone videos lose most of
their frame, so a diver browsing the library cannot see what a shot looks like
until they open it.

This replaces the square grid with justified rows: every thumbnail in a row
shares one height, each one's width follows its shape, and each full row ends
flush with the pane's right edge. Nothing is cropped beyond rounding.

The layout is built so the dive, species and dive site media sections can take
it next (#4739, #4740, #4741). This change covers the layout engine and the
main media library only.

## Goals

- Grid, by-dive and timeline views of the media library lay out as justified
  rows. The map view is untouched.
- Each thumbnail keeps the shape it is displayed at (EXIF rotation applied).
- The seven-step size control and Ctrl (Cmd on macOS) + wheel zoom set the row
  height. A wheel zoom keeps the thumbnail under the cursor on the cursor's
  line.
- Paging adds rows below without moving the rows above.
- Libraries with thousands of items stay smooth: only cells near the viewport
  are built.

## Non-goals

- The dive, species and site sections (follow-ups #4739 to #4741).
- Drag-select. The library has none today (`DragSelectGridView` is used only by
  the dive, site and photo picker grids), so nothing changes here; the
  follow-ups deal with it.
- A Grid / Justified setting. Decided: justified rows replace the square grid,
  with no toggle.
- Changing the stored `width` / `height` of a media item. Duplicate matching
  (`AssetResolutionService.matchByTimestampAndDimensions`) compares them for
  exact equality with dimensions recorded the same way, so they stay as the
  container declares them.

## Anti-goals

- A row that visibly jumps while the diver reads it, other than the one-time
  correction of a rotated photo described below.
- A single leftover photo blown up to the full pane width.
- A schema change to the synced database, or a sync change.

## Constraints found in the code

- `MediaItem.width` / `height` are the stored pixel size with no orientation
  applied (`image_dimensions_reader.dart`). Android gallery imports store the
  unrotated `AssetEntity.width` / `height` too. Nothing stores EXIF orientation,
  HEIC `irot` or video rotation. So a portrait camera shot imported from a
  folder reads as landscape from the database.
- The decoded thumbnail is upright: the local thumbnail cache, the OS gallery
  thumbnails and video posters all draw the photo the way it is displayed.
- The grouped views already lay out from one precomputed table of cells
  (`MediaGroupedGridTable` with `MediaGroupedGridDelegate` in
  `media_grouped_grid.dart`): headers full width, tiles in square columns, with
  a binary search by row top so only cells near the viewport are built. The
  flat grid is a plain `GridView` with a fixed-column delegate.
- The local cache database (`lib/core/database/local_cache_database.dart`,
  schema 25, unsynced) already holds derived per-device caches such as
  `DecoClassificationCache`. The file is at 787 lines, against an 800-line cap.

## Approaches considered

1. **One cell table, extending today's grouped grid (chosen).** A justified
   table gives every header and tile an exact rectangle; a custom
   `SliverGridDelegate` reads it, so Flutter builds one child per cell, only
   near the viewport. The flat grid becomes one group with no headers, so all
   three views share one engine, and the existing keep-place, tile `MetaData`
   hit-testing and load-more code carry over.
2. **One widget per row.** A `SliverVariedExtentList` whose children are whole
   rows and headers. Plainer widgets, but the zoom anchor and keep-place logic
   move from cells to rows, and a row is always built as a unit.
3. **A package.** The staggered-grid packages pack columns (Pinterest style),
   not justified rows. Dropped.

The diver chose approach 1.

## Design

### Shape of each item

Each library entry's aspect ratio (width / height) comes from, in order:

1. A **learned ratio** from this device's cache (below), when one is recorded
   for the item and the item's stored `width` / `height` still match the ones
   it was recorded against.
2. Documents (`MediaType.document`): a fixed 3:4, never learned. Their poster
   is a rendered page.
3. The stored `width` / `height`, when both are present and positive.
4. A fallback of 4:3 when either is missing. (Builder's note: 4:3 is my call
   on the issue's open question. It matches most underwater cameras and
   phones in their default mode, so the guess is right more often than 1:1,
   and the learned ratio corrects it either way.)

The result is clamped to 1:3 to 3:1, so one item cannot take a whole row or
become a sliver. The clamp applies to learned ratios too. (Decided: the part of
an image beyond the clamp is cropped, the tile filling its clamped box with
`BoxFit.cover`, as the squares crop today. Only these extreme shapes crop.)

**Minimum tile width (decided): 48 px.** No tile is laid out narrower than
48 px, a comfortable tap target. So the effective narrowest ratio depends on
the row height: `max(1/3, 48 / targetHeight)`. At the default stop and above
this changes nothing for ordinary shapes; at the smallest stops tall shapes
crop to 48 px wide. The packer takes the minimum width as an input, and its
tests cover it.

**Overlays on narrow tiles:** on a tile under 64 px wide the markers (bottom
left) and the video duration (bottom right) are hidden; the status badge and
the selection check stay.

### Learning the displayed shape (decided: learn plus a local cache)

When a library tile's thumbnail image resolves (`MediaItemView` already
reports the decoded size through `onImageSize`), the tile compares the decoded
image's ratio with the item's **unclamped** shape (learned, document fixed,
stored or fallback, before the clamp and the minimum width). If they differ by
more than 2 % (rounding in thumbnails and posters is smaller than that), it
reports the decoded ratio. That is what catches a rotated portrait, and an item
with no stored size. Comparing against the unclamped shape is what stops a
panorama from counting as a mismatch on every draw.

- Reported ratios go into an in-memory map (one provider for the app), which
  the layout reads, and are written to a new table in the **local cache
  database**: `media_aspect_cache` with the media id (primary key), the
  learned ratio, and the stored `width` / `height` it was learned against.
  Schema 25 to 26, created with `m.createTable` in `onUpgrade`, plus the
  idempotent create in the file's existing "table may be missing" backstop if
  that is the pattern for recent tables. The table class goes in its own file,
  because `local_cache_database.dart` is at the size cap.
- The map is loaded from the table once, when the library first needs it, and
  the first layout waits for it (one indexed read), so a returning diver never
  sees the rotated photos jump. Rows are small (an id and three numbers), so
  even a large library fits easily.
- An entry learned against stored dimensions the item no longer has (the item
  was relinked or re-read) is ignored and overwritten on the next decode. An
  item with no stored size is recorded with null dimensions and matches while
  the item still has none.
- Rows for media that no longer exist are pruned by the local cache sweep
  (`local_cache_sweep.dart`), as its other derived caches are.
- Reports are batched to at most one re-layout per frame.
- Ratios are only learned from the library tiles' thumbnails, never by decoding
  anything extra.
- Nothing is synced. Each device learns once per item, the first time that item
  is drawn on it.

A learned ratio changes the item's own row and can move the rest of its group
below it. When that happens above the viewport, the view keeps the cell at the
top of the viewport where it is (the same keep-place step the grouped list uses
today when the table changes). Because the scroll view builds two viewport
heights beyond the visible area (`ScrollCacheExtent.viewport(2)`), most
corrections happen offscreen before the diver reaches them.

### Packing rows

A pure function in its own file,
`lib/features/media/presentation/widgets/justified_row_packer.dart`:

```
packJustifiedRows(ratios, paneWidth, targetHeight, gap) -> List<JustifiedRow>
JustifiedRow = (start index, item count, height, list of widths)
```

- Items are taken left to right. A row is closed at the break that brings its
  scaled height closest to the target height, measured as a ratio (|log(height
  / target)|), choosing between closing before the item that crosses the pane
  edge and closing after it. Ties close after it. (My call, refining the
  issue's "add until it reaches the pane width, then scale down": with only
  scaling down, one wide item arriving last can shrink a whole row by a third.)
- A closed row is scaled so its widths plus the gaps between them equal the
  pane width exactly. Widths are rounded so the row's right edge lands on the
  pane edge to the pixel: the rounding remainder goes to the last tile.
- **Last row of a group:** kept at the target height and left-aligned, not
  stretched. If it would overflow the pane (one very wide item), it is scaled
  down to fit, like any closed row.
- A single item wider than the pane at the target height gets a row of its own,
  scaled down to the pane width.
- Groups never share rows: each group packs on its own, starting under its
  headers.
- Packing is greedy from the left, so appending items to a group can change
  only that group's last row. That is what gives paging its "rows above do not
  reflow" guarantee: a page that continues the last group fills that group's
  open last row and adds rows below.

Unit tests cover mixed ratios, a single item, a very wide item, missing
dimensions (via the shape rules), the last row, exact flush right edges, and
appending items changing only the last row.

### The layout table

`JustifiedMediaTable` replaces `MediaGroupedGridTable`, in
`lib/features/media/presentation/widgets/justified_media_grid.dart` (with the
delegate), reusable by the follow-up sections:

- Built from a list of sections, each with its header extents and its items'
  ratios, plus the pane width, target row height, gap and side inset.
- Every cell gets top, left, width and height. Headers span the full pane
  width, as now. Tiles in one row share a top.
- Keeps the current table's queries: the first and last cell of the row at an
  offset (binary search on tops), a cell's geometry with right-to-left support,
  the place at an offset and the offset of a place (for keep-place), and a
  same-cells check.
- Adds a lookup from (group, index in group) to cell, used by the zoom anchor.
- The flat grid builds one section with no headers.

`MediaLibraryGrid` and `MediaLibraryGroupedList` both lay out through this
table and its delegate. The shared tile, header, load-more and keep-place code
stays where it is; the flat grid gains the keep-place step it does not need
today, because a learned ratio can now change rows above the viewport.

### Size control

- The seven slider stops set a **target row height** instead of a column count.
  Stop *n* gives the height the square tile had at that stop: the same
  geometric scale from 64 px to half the pane width, so each stop looks like
  the same change it does today.
- What is held across a window resize becomes the row height (in place of the
  held column count): resizing re-packs rows at the same height rather than
  scaling thumbnails. The height still gives way where it would exceed half the
  pane, as the column count gives way at the minimum size today.
- `MediaThumbnailColumnsBuilder` becomes a builder that hands the views the
  target row height. `mediaThumbnailColumnsForStep`, `mediaThumbnailMaxColumns`
  and the column-only helpers in `media_thumbnail_zoom_anchor.dart`
  (`mediaThumbnailExtentAfter`, `mediaThumbnailGridHeight`) go.
- The size stays session-only, as now.

### Wheel zoom anchor

The capture side stays: on a wheel click the holder finds the tile under the
cursor (or the nearest one above it) and records its slot (group, index), the
cursor's y, and the tile's top and height.

The apply side no longer predicts a column layout. When the view builds its
new table, it looks up the anchor's cell and sets the scroll offset so that the
same fraction of the tile sits under the cursor: new offset = the tile's new
top + fraction × its new height + the cursor's distance below the tile (when it
was over a gap) − the cursor's distance from the viewport top, never below 0.
This is exact, since the table is. The tile stays on the cursor's line; it can
move sideways, since its row is re-packed.

### Tiles

- `MediaLibraryTile` keeps its overlays and corners: status badge top left,
  markers bottom left, selection check top right.
- New: a video shows its duration bottom right, as `m:ss` (or `h:mm:ss` from an
  hour), from `durationSeconds`, hidden when that is null.
- Thumbnails keep `BoxFit.cover`. Once the ratio is right this crops only
  rounding; before a rotated photo's ratio is learned it crops the way it does
  now, for one frame.
- Decode size follows the tile's real size: the tile's longest side picks the
  200, 400 or 800 bucket, capped as `mediaThumbnailDecodeTarget` caps it now.
  The function takes a tile size instead of (pane width, columns).

### Spacing

- Gap between tiles, across and down: 4 px, or 2 px when the pane is narrower
  than 600 px (the phone mockup). (My call on the threshold.)
- Side inset: the grouped list's 8 px per side on wider panes, and the gap on
  narrow ones, in all three views. (My call; today the flat grid uses 4 px and
  the grouped list 8 px.)
- Square corners, as now.

### Selection, menus, info

Tap, the Select button, select-all, the context menu and the info sheet do not
depend on layout and keep working as they do now. Widget tests confirm it.

## Acceptance (from the issue, adjusted to the decisions)

- No library thumbnail is cropped to a square; each keeps its displayed aspect
  ratio within rounding, once its thumbnail has been drawn on the device,
  except shapes beyond 3:1 or 1:3 and tiles held at the 48 px minimum width,
  which crop to fit.
- Every row except the last of each group ends flush with the pane edge.
- Items with no dimensions use the 4:3 fallback; rotated photos lay out in their
  displayed orientation (from the first draw on a device onward).
- The size control and wheel zoom change the row height; the item under the
  cursor stays on the cursor's line.
- Selection, the context menu and the info sheet work as before.
- Paging adds rows without reflowing the rows above.
- The packing function has the unit tests listed above.
- Phone and desktop widths, light and dark mode, checked in screenshots.

## Settled by the builder check (builder's calls)

- Right-to-left: rows pack in reading order and are mirrored by the delegate,
  as the grouped table mirrors columns now.
- The zoom anchor's capture walks sideways by the current gap plus one, so it
  works at both the 2 px and 4 px gap.
- Decode buckets are per tile (above).

## Left to the builder

- File and class names beyond the two named above.
- Whether the old grouped table is edited in place or replaced by a new file.
- The exact batching mechanism for learned ratios (a post-frame flush is
  enough).
