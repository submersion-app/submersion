# Site Media Attachments — Design

**Date:** 2026-08-10
**Issues:** [#211](https://github.com/submersion-app/submersion/issues/211) (Images for Dive sites), [#627](https://github.com/submersion-app/submersion/issues/627) (Dive site attachments or photos)
**Branch:** `worktree-site-media-attachments`

## Problem

Users can attach photos and videos to dives, but not to dive sites. Both issues ask
for site-level attachments: entry-point photos, parking and access imagery, and
hand-drawn underwater maps (including PDFs). Today there is no way to attach any
file to a dive site.

## Decisions (confirmed with user)

1. **Scope:** photos, videos, and first-class PDF support (in-app rendering,
   generated thumbnails). Other common document formats (doc, docx, txt, gpx, ...)
   are attachable as opaque files that open externally.
2. **Site gallery contents:** two separated sub-groups — direct site attachments,
   and an aggregated read-only "photos from dives at this site" group.
3. **Documents on dives too:** the new document media type is enabled for both
   sites and dives in this work.
4. **Widget architecture:** extract a shared media grid core from
   `DiveMediaSection`; build a new `SiteMediaSection` on top of it (Approach B).
5. **Storage:** reference everything. Documents are linked in place via path +
   security-scoped bookmark, exactly like desktop-picked photos. No copies into
   app-owned storage. A configured cloud media store uploads a content-addressed
   copy at attach time and is the recovery path if the source file disappears.
6. **Sync contract:** documents behave exactly like photos — the metadata row
   syncs to all devices; file bytes transfer only via a configured cloud media
   store. Devices without the bytes show a placeholder/unavailable tile. No
   inline-BLOB storage for documents.

## Data model

No new tables and no new columns. The existing `media` table already carries a
nullable `siteId` FK (added speculatively during the underwater-photography work;
write path, sync registration, site-merge handling, and orphan sweeps already
exist — the read path and UI were never built).

- **Site linkage:** reuse `media.siteId`
  (`lib/core/database/database.dart:1200`). One row = one attachment; a row may
  carry both `diveId` and `siteId`.
- **Document type:** new `MediaType.document` member in
  `lib/features/media/domain/entities/media_item.dart`, persisted as
  `fileType = 'document'` (free-text column; no schema change). Behavior branches
  on file extension: `pdf` is renderable, everything else is opaque.
- **Display name:** basename of the linked path. `caption` remains available for
  user annotation.
- **Migration v148** (current schema version 147; append to `migrationVersions`):
  - `idx_media_site_id` on `media(site_id)` — site gallery query has no index.
  - Partial unique index on `(platform_asset_id, site_id)` where both are
    non-null — parity with the existing dive-side dedupe index
    (`idx_media_asset_dive_unique`).

## Read path and providers

- `MediaRepository.getMediaForSite(siteId)` — mirror of `getMediaForDive`
  (`lib/features/media/data/repositories/media_repository.dart:21`) without the
  enrichment join; ordered by `takenAt`.
- New providers in `lib/features/media/presentation/providers/`:
  `mediaForSiteProvider`, `mediaCountForSiteProvider`, and a site-keyed list
  notifier mirroring `mediaListNotifierProvider`.
- Aggregated dive photos: `mediaForSiteDivesProvider` fanning out over the site's
  dives, modeled on `mediaForTripProvider`
  (`lib/features/trips/presentation/providers/trip_media_providers.dart`).

## UI

### Shared grid extraction (Approach B)

Extract the reusable core of `DiveMediaSection`
(`lib/features/media/presentation/widgets/dive_media_section.dart`) into a shared
widget: tiles, `DragSelectGridView` multi-select, media-store badge, desktop
context menu. `DiveMediaSection` retains dive-only behavior (enrichment backfill,
depth badges, gallery scan, time-window import). Follows the repo rule of many
small files; the extraction is a targeted improvement to an already-large widget.

### SiteMediaSection

New card on the site detail page
(`lib/features/dive_sites/presentation/pages/site_detail_page.dart`, mounted near
`SiteMarineLifeSection` around line 211 — the established pattern for a
self-contained siteId-keyed section owned by another feature). Contents:

1. **Attachments** — media with `siteId` set: photos, videos, documents. Header
   add menu: "Add photos/videos" (platform gallery picker on mobile, file picker
   on desktop; no dive-time-window filtering) and "Add document" (file picker
   with custom extension filter). Multi-select unlink and context menus via the
   shared core.
2. **Photos from dives here** — read-only aggregation, compact/collapsed by
   default so site reference material stays prominent.

The site edit page is not changed; media management lives on the detail page,
matching the dive pattern.

### Viewers

- **Site photos/videos:** new site-scoped viewer modeled on
  `TripPhotoViewerPage`
  (`lib/features/media/presentation/pages/trip_photo_viewer_page.dart`) — no
  dive-profile overlay.
- **PDFs:** new `DocumentViewerPage` using `pdfrx` (pdfium-based; iOS, Android,
  macOS, Windows, Linux). Bytes resolved through the existing
  `MediaSourceResolverRegistry`, so viewing works from the local bookmark or the
  media-store cache. Share / open-externally actions included. Package platform
  support must be verified during planning; fallback candidates: `pdfx`.
- **Other documents:** generic file tile with extension badge; open externally
  (respect the existing desktop-save vs mobile-share duality).

### Dive side

`DiveMediaSection` add menu gains "Add document". Document tiles render in the
dive grid; enrichment, depth badges, and gallery-scan matching are skipped for
documents. PDFs open in the same `DocumentViewerPage`.

## Document pipeline

- **Attach:** `file_picker` with custom extension list. Row fields:
  `fileType: 'document'`, `sourceType: localFile`, `localPath`, `bookmarkRef`.
  Content hash computed at attach time. `MediaImportService.onMediaCreated`
  enqueues media-store upload unchanged (mediaId-keyed, entity-agnostic).
- **Per-platform reference semantics** (all within the reference-everything
  decision):
  - macOS/iOS: security-scoped bookmark to the picked file (existing desktop
    photo bookmark machinery).
  - Android: persist the SAF content URI with persistable read permission and
    store the URI as the reference (same mechanism as SAF backup locations).
  - Windows/Linux: plain absolute path.
- **Content types:** `StoreKeys.contentTypeFor` / `extensionFor`
  (`lib/core/services/media_store/store_keys.dart`) learn `application/pdf` and
  common document types (current fallback is `bin`).
- **Thumbnails:** `ThumbnailGenerator`
  (`lib/features/media_store/data/thumbnail_generator.dart`) gets a PDF branch:
  render page 1 via `pdfrx` to the standard 512 px JPEG (grids and cloud thumb
  store both benefit). Non-PDF documents produce no thumbnail.
- **Unavailable state:** when bytes cannot be resolved (source file deleted, no
  media store), tiles show the existing placeholder/unavailable treatment;
  `originDeviceId` powers "available on origin device" messaging.

## Sync and deletion correctness

- **Sync: zero new entities.** `media` is already a synced entity and `siteId`
  is already registered in the sync parent-FK registry
  (`lib/core/services/sync/sync_service.dart:1960`). Site-linked media and
  documents flow through the existing pipeline.
- **Site deletion fix (correctness-critical):** `SiteRepositoryImpl.deleteSite`
  and `bulkDeleteSites`
  (`lib/features/dive_sites/data/repositories/site_repository_impl.dart:301,334`)
  currently rely on SQLite `ON DELETE SET NULL` for `media.site_id`, which writes
  no HLC stamp and therefore cannot sync — peers diverge once site media exists.
  Mirror the dive-side fix (`partitionMediaForDiveDeletion`,
  `media_repository.dart:998`): add `partitionMediaForSiteDeletion` —
  - media also linked to a dive: keep, clear `siteId` with an HLC-stamped update
    marked pending for sync;
  - site-only media: delete through the media deletion coordinator (handles
    cloud-store orphan cleanup and the deletion log).
- Dive-side partition logic is unchanged (it already treats a non-null `siteId`
  as a keep reason).
- Site merge already repoints `media.siteId` to the survivor with HLC marking and
  undo snapshots; no changes needed.

## Error handling

- Unresolvable document bytes: placeholder tile, no crash; retry resolution on
  next view (existing resolver behavior).
- PDF render failures (corrupt file): fall back to the generic document tile;
  viewer shows an error state with the open-externally action.
- Bookmark resolution failures on macOS/iOS sandbox: same handling as existing
  desktop photo bookmarks.
- Oversized files: no hard limit imposed; media-store upload already chunks and
  retries. (Sync payloads are unaffected because bytes never enter sync.)

## Testing

- **Repository:** `getMediaForSite` ordering and filtering; site-delete
  partition (dive-linked kept and HLC-stamped, site-only deleted via
  coordinator); dedupe index behavior.
- **Unit:** PDF first-page thumbnail from a small fixture PDF; `StoreKeys`
  content-type mappings; sync serializer round-trip for a `fileType: 'document'`
  row.
- **Widget:** `SiteMediaSection` (empty state, attachments grid, dive-photos
  sub-group, add menu, document tile, unavailable placeholder);
  `DiveMediaSection` regression tests covering the grid extraction; document
  viewer smoke test.
- Follow existing widget-test gotchas (fakeAsync/Drift deadlocks, provider
  overrides) documented in project memory.

## Out of scope

- Inline-BLOB document sync (rejected: sync payload bloat; signatures remain the
  only inline-BLOB media).
- Copying attachments into app-owned storage (rejected in favor of
  reference-everything).
- Non-PDF in-app document rendering.
- Site media in the site edit form.
- OCR/auto-tagging of documents.
