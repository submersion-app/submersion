# Site attachment categories and large view

Issue: #1039 (Dive Site: Media / PDF Attachment: Display Large)

## Problem

Divers attach site reference material to a dive site: hand-drawn or annotated
site maps (often PDFs with points of interest), parking and access photos,
anchorage notes. Today every site attachment renders as a small tile in one
4-column grid, so a map PDF is a thumbnail the size of a fingernail and must be
opened to be read, and attachments cannot be grouped.

## Goals

1. Show selected attachments large, spanning the full card width, with PDFs
   showing a sharp render of page 1.
2. Let the user assign each attachment a category from a fixed list, and show
   the site's attachments grouped under category headings.

## Non-goals

- Renaming an attachment. The issue asks for it, but the stored filename is a
  resolution key: cross-device gallery matching (filename plus timestamp) and
  the repair wizard's moved-file search both look files up by it, so editing
  it can leave a photo unresolvable on other devices. Decided against during
  review (2026-10-05).
- Categories or sizes on dive or equipment media (the columns are
  generic so those surfaces can adopt them later).
- User-defined categories.
- Manual reordering within a group.
- Asking for a category at add time.
- Rendering PDF pages other than page 1 inline.

## Data model

### Columns

Two nullable text columns on `media`, added by the next free schema rung
(shipped as v266: main took v261 and v263 while this was open, and 262,
264 and 265 are claimed by other branches):

| Column | Values | Null means |
| --- | --- | --- |
| `site_category` | `siteMap`, `parking`, `access`, `anchorage`, `underwater`, `general` | Uncategorized |
| `display_size` | `large`, `tile` | Follow the category default |

The rung adds both columns; a `beforeOpen` backstop adds any that are missing,
so a device that never enters the rung still heals. Existing rows stay null,
which keeps every existing attachment rendering exactly as today.

The values travel with the `media` row in the sync payload. They are user
edits, so they belong to the row clock, not to the upload or verification fact
groups.

### Domain

- `SiteAttachmentCategory` enum in the fixed display order: `siteMap`,
  `parking`, `access`, `anchorage`, `underwater`, `general`. Each value has a
  stable storage key, a localized label, and a default display size:
  `underwater` defaults to tile, every other category to large.
- `AttachmentDisplaySize` enum: `large`, `tile`.
- `MediaItem` gains `siteCategory` (`SiteAttachmentCategory?`) and
  `displaySizeOverride` (`AttachmentDisplaySize?`), both carried by `copyWith`,
  plus an `effectiveDisplaySize` getter:
  1. the override, when set;
  2. otherwise the category default, when categorized;
  3. otherwise tile.
- Parsing is lenient and explicit: an unknown key (for example, a category
  added by a newer app version and synced in) parses as null. There is no
  `default:` arm that maps an unknown value onto a real category.

## Site card layout

The Media card on the site detail page keeps its header row (title, checklist
button, add menu). Its body changes from one grid to a list of groups.

### Grouping

- Groups appear in the fixed category order, then Uncategorized last. Empty
  groups do not render.
- Each group has a heading (`titleSmall`): the category label and a count.
- When every attachment is uncategorized, no heading is drawn, so a site nobody
  has categorized looks the same as before this change.
- Within a group, large items come first, stacked one per row at full width, in
  `takenAt` order. The group's tile items follow in the existing 4-column grid,
  also in `takenAt` order.
- The collapsed "Photos from dives at this site" group stays at the bottom,
  unchanged. It does not take part in categories.

### Large item rendering

| Kind | Large rendering | Tap |
| --- | --- | --- |
| Image | Full width at the image's aspect ratio from `width`/`height`, 4:3 when unknown, height capped at about 70% of the screen height; resolved at display size, not as a thumbnail | Existing site photo viewer |
| PDF | Page 1 rendered at card width times device pixel ratio; filename and an "N pages" badge | Existing full-screen PDF viewer |
| Video | Poster frame at full width with a play overlay | Existing site photo viewer |
| Other document | Full-width row: file-type icon, name, extension | Opens as today |

Bytes that cannot be resolved show the existing placeholder and orphan states
at the same footprint; a large card never collapses to zero height.

The PDF render comes from a new `PdfThumbnailService.largeRenderFor(item,
maxDimension:)`. It shares the existing service's cache-first behaviour and
source read, caches per size, and returns the page count with the image. The
renderer is an injectable seam so widget and service tests stay hermetic
(pdfium cannot load under `flutter test`).

### Selection

- Large cards take part in checklist selection: a checkbox overlay, and tap
  toggles while selection is active. Every group grid and every large card
  reports to the one id-based `SelectionController`, so a selection can span
  groups.
- The selection bar keeps Unlink and gains:
  - **Set category**, for any number of checked items;
  - **Edit details**, when exactly one item is checked.

### Entry points to Edit details

- The overflow menu on each large card.
- The app bar of the site photo viewer and of the PDF viewer, when the item is
  a site attachment.
- The selection bar with one item checked. This is the path for a tile, and
  for a non-PDF document, which has no viewer.

## Edit details sheet

A modal bottom sheet at every width, the app's convention for transient
panels (see `showMediaSpeciesSheet`).

- The attachment's name, read-only, so the diver knows which file this is.
- **Category:** a dropdown with Uncategorized and the six categories.
- **Size:** a three-way dropdown. The first entry reads "Default (Large)" or
  "Default (Tile)" and follows the chosen category live; the other two are
  "Large" and "Tile". (A segmented control could not hold the longer
  translations at phone width.)
- **Save** writes only the fields that changed. On failure it shows an error
  snackbar and keeps the sheet open. **Cancel** discards.

## Bulk Set category

A picker with Uncategorized and the six categories. It applies the chosen
category to every checked id in one transaction, leaves each item's size
override and name unchanged, exits selection, and reports with the same
success and failure snackbars as the existing Unlink action.

## Repository writes

Following the narrow-writer convention (`setManualElapsedSeconds`), in a new
`SiteAttachmentRepository` (`media_repository.dart` is already far past the
800-line ceiling):

- `setAttachmentDetails(id, edit)` writes only the category and size fields
  the `AttachmentDetailsEdit` carries (never the filename), plus `updatedAt`, in one transaction with
  `markRecordPending`, then notifies the sync event bus. A row that no longer
  exists (unlinked while the sheet was open) throws instead of queueing a sync
  record for a missing row.
- `setSiteCategory(ids, category)` writes `site_category` and `updatedAt` for
  every id in one transaction and marks each row pending.

`updateMedia` and the insert paths carry both new columns, so a whole-row write
from a snapshot cannot drop them, and the row mapper reads them back.

## Localization

New English ARB keys for the six category labels, Uncategorized, the group
heading with count, the sheet (title, field labels, size choices), Set
category, Edit details, and "N pages". All 11 catalogs receive
translations so key parity holds.

## Testing

Written first, per TDD.

- **Domain unit tests:** effective size for every combination of override and
  category, including uncategorized; unknown keys parse to null.
- **Row mapper:** both columns round-trip.
- **Repository:** `setAttachmentDetails` touches only the passed columns and
  marks the row pending; `setSiteCategory` is atomic over many ids and leaves
  overrides and names alone; `updateMedia` and insert preserve the columns.
- **Migration:** upgrading from v265 to v266 adds both columns; the backstop
  heals a database already at v266 that is missing them. The test pins
  `migrationStepCount(265) == 1`, so it holds whether or not the open claims
  below it land first.
- **Sync:** a serializer export and import round-trips `site_category` and
  `display_size`.
- **PDF service:** `largeRenderFor` caches per size and returns the page count,
  through the injected renderer.
- **Widgets** (media widget harness): group order and headings; no headings when
  all are uncategorized; large and tile placement, including both override
  directions; each large kind renders and taps through; a selection spanning a
  large card and a tile; the edit sheet's live default label, save, and phone
  width fit; bulk Set category; Edit details offered only for a single
  selection.
