# Site media in justified rows (issue #4741)

## Intent

A dive site's details show media in two places, and both crop every item to a
square: the dive photos card (#4502) and the site attachments section
(#1039). The media library now lays thumbnails out in justified rows that keep
each photo's shape (#4738, PR #4755). Site Details should look the same, so a
site's photos keep their aspect ratios like the rest of the app.

## Goals

- The dive photos strip, the expanded dive photos view and the attachment
  tiles are laid out in justified rows from the #4738 engine. No square
  cropping remains on Site Details.
- The collapsed strip is one row that ends flush with the card's right edge.
- Show all appears only when the card holds more photos than the strip shows.
- Selection across category groups, drag-select, bulk Set category, editing
  one checked item's details, and opening items all behave as they do now.

## Non-goals

- Large attachment cards. Whether an attachment shows as a large card or a
  tile is the diver's choice per item (`effectiveDisplaySize`), so large
  cards, group headings and their order stay as they are.
- The dive details and species media sections (#4739, #4740). The shared
  wrapper below is written so they can reuse it, but they are not changed.
- The strip's query and its cap (`kSiteDivePhotoStripLimit`, 12).

## Approaches

1. **A new inline widget made of Rows.** Pack with `packJustifiedRows` and
   draw each row as a `Row` of tiles. Simple for the dive photos card, but the
   attachment tiles rely on `DragSelectGridView` for drag-select and
   cross-group selection, so either drag-select is rebuilt on Rows or the
   attachments stay on a second layout path.
2. **Reuse `JustifiedMediaTable` and `JustifiedMediaGridDelegate` everywhere
   (chosen).** Measure the width, build a table from the items' shapes, and
   hand its delegate to the grids that exist today. Selection keeps its tested
   code; one layout path serves every site surface.

The maintainer picked approach 2.

## Design

**Shared wrapper.** A small widget in `lib/features/media/presentation/widgets/`
that takes the items' ratios and a target height, measures its width with a
`LayoutBuilder`, builds one `JustifiedMediaTable` (one section, no headers, no
inset, 4 px gap, the library's 48 px minimum tile width), and passes the table
to a builder that returns the grid. It waits for `mediaLearnedAspectsProvider`
before its first layout, as the library grid does, so a returning diver never
sees rotated photos jump into place.

**Dive photos card.**

- Collapsed: pack the strip's newest photos (up to 12) at about 100 px and
  show only the first row. A row that reaches the card's edge is justified
  flush (maintainer's decision); when every photo fits short of the edge, the
  packer's open last row keeps the target height and is not stretched.
- Show all appears when that first row holds fewer photos than the site's
  photo count, replacing today's column-count check.
- Expanded: the full chronological list in justified rows at about 100 px, in
  a non-scrolling `GridView` with the justified delegate.
- A tap opens `SiteMediaViewerPage` in the dive-photos scope, as now. The card
  stays read-only.

**Site attachments.**

- Each category group's tiles go in its existing `DragSelectGridView`, now
  given the justified delegate, packed at about 120 px with a 4 px gap.
- Selection, drag-select, bulk Set category and opening items are unchanged:
  the grid finds the item under a drag by each item's key, not by column
  arithmetic.
- Documents keep the fixed page shape (3:4) the library uses
  (`kMediaDocumentAspect`).

## Calls made by the builder

- Site tiles report their decoded thumbnail size to
  `mediaLearnedAspectsProvider`, so a photo stored sideways with an EXIF
  rotation is corrected on Site Details the same way as in the library. This
  needs `MediaThumbnailTile` to pass `onImageSize` through.
- Gap is 4 px (today's site grids use 8), matching the library.
- Each tile asks for a decode size from `mediaThumbnailDecodeTarget` for its
  laid-out size, rather than the fixed 200 x 200, as the library does.

## Left to the builder

- Names and file split of the wrapper, and how the strip reads its first row's
  count out of the table.
- Test coverage: the strip's first-row count and Show all rule at several
  widths, cross-group selection and drag-select under the new delegate, and
  that no tile is square-cropped.
