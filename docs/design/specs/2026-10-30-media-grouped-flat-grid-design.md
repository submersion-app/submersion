# Media: one lazy grid for the grouped gallery

Issue: #3826. Target release: v1.8.4.

## Why

Media's By dive and Timeline views put each group's thumbnails in a shrink-wrapped
`GridView` inside an outer `ListView.builder`. The outer list is lazy about groups,
but a group that comes into range builds every tile it holds, because a
shrink-wrapped grid has to lay out all of its children to know its own height. A
day of hundreds of photos, or a large Unlinked group, builds and lays out all of
them when it opens, on every thumbnail resize and on every selection toggle.

The issue suggests one sliver grid per group. A throwaway probe compared that with
today's nesting and with one flat grid, on an 800 x 600 viewport with 4 columns and
plain tiles:

| Scenario | Tiles built: today | Per-group slivers | One flat grid |
| --- | --- | --- | --- |
| 1 group of 180 | 180 | 20 | 20 |
| 1 group of 1,000 | 1,000 | 20 | 20 |
| 500 groups of 3 | 12 | 508 | 12 |
| 3,000 groups of 3 | 12 | 3,008 | 12 |

At 3,000 groups, per-group slivers took 590 ms for the first frame and 523 ms for 60
scroll frames, against 9 ms and 27 ms for the flat grid. A viewport lays out every
sliver on every pass, and `RenderSliverGrid` calls `addInitialChild` unconditionally,
so each off-screen grid keeps one real tile alive. Many small groups is the normal
shape of a By dive library, so per-group slivers would fix the rare case by slowing
down the common one.

## Decided by the maintainer

- One flat grid, with headers as full-width cells in the same index sequence as the
  tiles.
- Long dive headers keep wrapping. Nothing about the view changes visually.

## Goals

- Built tiles scale with the viewport and cache extent, not with the size of the
  largest group or the number of groups.
- Group headers are lazy too.
- By dive and Timeline look and behave as they do now.

## Non-goals

- Sticky headers, or any other new behaviour.
- Changing the flat Gallery grid, except a comment that no longer holds.
- Changing paging, grouping (`groupByDive`, `groupByTimeline`) or the tile.

## Anti-goals

- A header clipped or leaving a gap because its measured height is wrong.
- A thumbnail that jumps out from under the cursor on a wheel zoom.
- The view jumping when selection starts or ends, or when the size or width changes.
- Losing the page's primary scroll view by giving the list a `ScrollController`.

## The grid

`MediaLibraryGroupedList` builds one `GridView.builder` with a custom
`SliverGridDelegate`. Its cells, in order, are each group's headers followed by its
tiles. A cell is a month header, a day header, a dive header or a tile.

The delegate's `SliverGridLayout` holds a prefix table of every cell's scroll offset,
and answers `getMinChildIndexForScrollOffset` and `getMaxChildIndexForScrollOffset`
by binary search. All tiles in a row share an offset, so the minimum steps back to
the start of its row and the maximum forward to the end of it. The table is built
once per delegate and pane width, not per layout.

The geometry reproduces today's exactly:

- Tile extent, from a usable width of the pane minus `kMediaThumbnailMaxInset`:
  `(usable - (columns - 1) * kMediaThumbnailGap) / columns`, square.
- Tiles inset `kMediaThumbnailMaxInset / 2` each side, and `kMediaThumbnailGap` apart
  across and down, with no gap after a group's last row.
- A header cell takes the full pane width and keeps its own padding.
- 8 logical pixels of padding after the last cell, as now.
- Right-to-left: tile cross offsets mirror when
  `axisDirectionIsReversed(constraints.crossAxisDirection)`, as
  `SliverGridRegularTileLayout` does.

Because a cell's index does not depend on the column count, a tile keeps its element
across a zoom, as it does today, and does not reload.

## Header heights

The grid needs every header's height before building it, including headers that are
never built, so they are measured. Text wrapping is kept by measuring with the same
inputs the header is drawn with:

| Header | Style | Padding (L, T, R, B) | Floor |
| --- | --- | --- | --- |
| Month | `titleMedium` | 12, 16, 12, 4 | none |
| Day | `labelLarge` | 12, 8, 12, 4 | none |
| Dive, navigable | `titleMedium` | 12, 12, 12, 4 | 48 |
| Dive, inert | `titleMedium` | 12, 12, 12, 4 | none |

A dive header is navigable when it has a dive id and no selection is in progress, so
entering selection mode changes heights. That is today's behaviour and it stays; see
Keeping the diver's place for what that needs from an exact table.

Measuring uses a `TextPainter` with the label, the resolved style, the ambient
`TextScaler` and `TextDirection`, at the pane width minus the 24 of horizontal padding.
Each distinct label's max intrinsic width is cached, because it does not depend on the
pane: a label narrower than the available width takes the cached single-line height
for its style, and only a label that wraps needs a layout at that width. So dragging a
desktop pane wider or narrower re-measures only what wraps.

A header is drawn in a cell of its measured height. Whatever draws it and whatever
measures it must take their style, padding and floor from one definition, so they
cannot drift.

## Zoom

`MediaThumbnailSlot.row` becomes the tile's group index. `index` stays its position
within the group, so `scrollOffsetFor` is unchanged.

With exact geometry, `heightChangeAbove` is the sum over every group above the
anchor's, not only the built rows, so `leadingRow` and the walk that finds it in
`_anchorFor` are removed. Headers do not change height with the column count, so only
grids count, which the `scrollOffsetFor` doc comment already assumes. The comment that
explains `leadingRow` goes with it. The cost is one pass over the groups per wheel
click.

The cache of grid counts stays as a list by group index.

## Keeping the diver's place

Today's list knows only the rows it has built, and holds its first built row where it
is, so height changes above the viewport are absorbed. An exact table does not absorb
them: with `pixels` unchanged, every change above the viewport moves what is on screen
by the full amount. Three things change heights with no wheel anchor to correct them:

- Entering or leaving selection in By dive. Every linked dive header changes by 8, so
  300 dives above the viewport would move the content about 2,400 px.
- The size slider, the only way to resize on a touch device.
- A width change: dragging a desktop pane, resizing the window, rotating a phone. This
  also rescales tiles, because the column count is held and the width is not.

Each must keep the place, so one mechanism covers them. Whenever the table changes and
there is no wheel anchor, the cell at the top edge of the viewport stays there: take its
index and how far down it the edge falls, as a fraction of its height, from the old
table, and set the offset from the new table with `position.correctPixels`, so the
first frame at the new layout is already in place. A tile's row counts as the cell. The
offset is corrected before the viewport lays out, as the wheel path does now; a width
change arrives during layout through a `LayoutBuilder`, which is still before the
viewport's own layout. The end of the list stays the physics' to clamp.

This applies only when the same cells are in both tables. Paging normally appends after
the viewport, so it moves nothing above it. The exception is By dive, where the Unlinked
group stays last: a page can insert dive groups above it, so a diver reading Unlinked
near the end sees the view move when a page lands. Today's list is disturbed at the same
moment, because the row index it holds starts to mean a different row, so that stays as
it is. Any table change that alters which cells exist above the top edge leaves the
offset alone.

The wheel path keeps its own anchor, because it holds the thumbnail under the cursor
rather than the top edge.

## Cache extent

The grouped view takes the flat grid's `scrollCacheExtent:
ScrollCacheExtent.viewport(2)`. It was held back only because a group built all its
thumbnails at once, which is what this removes. The comment in `MediaLibraryGrid`
explaining that exemption is removed, and the test pinning it changes to expect the
same extent in both views.

## What stays

- `NotificationListener` near-end paging, with the same 400 threshold. It reads a
  `maxScrollExtent` that is now exact rather than estimated.
- `MediaThumbnailWheelZoomPhysics`.
- Picking the scroll position up from a cell's context, with no `ScrollController`.
- Header tap navigation, its semantics and its inert state during selection.
- `MediaLibraryTile`, and the `MetaData` wrapper the zoom's hit walk depends on.

## Validation

Automated:

- Tile builds stay bounded for 60, 180 and 1,000 entries in one group, and for 500 and
  3,000 small groups, scrolled and unscrolled. Tiles far outside the cache extent are
  never built, so no image is resolved for them.
- Header builds stay bounded with many groups.
- A measured header height equals the real rendered height for: a label that fits, one
  that wraps to two and three lines, a large `TextScaler`, right-to-left, a phone width,
  and both dive header forms. These compare against a real laid-out header.
- The grid's total extent equals today's: the sum of headers and grids.
- Tile rects match the old layout, left to right and right to left, at several column
  counts, including a short last row.
- The existing "zooming in and out" tests, which compare the prediction with the real
  layout, pass unchanged in both views.
- Near-end paging, header navigation and selection tests pass unchanged.
- The top visible cell stays at the top edge, on the first frame, for: entering and
  leaving selection in By dive with many dives above, the size slider, a pane width
  change, and a run of width changes as a drag sends them.
- Paging while scrolled moves nothing on screen.

Measured and reported in the PR: tile and header build counts and frame durations
before and after, from a benchmark run through the real widget. A profile build of a
real scroll, if the environment allows one. If it does not, the PR says so plainly.
Memory is not measured separately: built tiles are the proxy, and the PR says so.

The PR ticks "No visible UI change" and says why in its Summary.

## Left to the builder

- File layout. `media_library_grouped_list.dart` should end up smaller, with the
  delegate and the header measurement in their own files.
- The cell model's shape.
- How the delegate receives measured heights and when it is rebuilt, so long as a
  selection toggle does not rebuild the prefix table when no header changes height.
