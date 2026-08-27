# Media Section (DAM Platform) Design

- **Date:** 2026-08-05
- **Status:** Approved design, pending implementation planning
- **Related specs:** `2026-07-10-s3-media-storage-design.md`,
  `2026-07-12-media-linking-storage-program-design.md`,
  `2026-07-23-media-store-orphan-prevention-design.md`

## 1. Problem and goals

Media management today is scoped per dive. There is no way to see all media
across the app, no way to find broken file links except a manual "Re-verify all"
in Settings, and no bulk repair when a media library is relocated on disk. The
"Unlink" action in the dive detail media section is actually a hard delete
(`DiveMediaSection._unlinkSelected` calls the deletion coordinator), so the
intuitive recovery workflow -- unlink everything, re-link from the new location
-- destroys enrichment data, species tags, and media-store state.

This design adds a top-level **Media** section: a digital asset management
(DAM) console for every photo and video in the app. It answers three questions
the app cannot answer today:

1. **What media do I have?** A cross-dive library with three view modes.
2. **What is broken?** Missing-file and unlinked-media views with live counts.
3. **How do I fix it in bulk?** A multi-source repair wizard, true
   unlink/reassign, and (later) a background watcher that repairs moves
   automatically.

Plus: import with automatic dive matching, and transfer-queue visibility inside
the section.

### Success criteria

After relocating a media library (for example `~/Pictures/Dives` to
`/Volumes/NAS/Dives`), the user repairs every affected row from the Media
section in one wizard pass -- no per-dive visits, no unlink/relink cycle, no
loss of dive links, enrichment, species tags, or store state.

## 2. Decisions made during brainstorming

| Question | Decision |
| --- | --- |
| Relocation kinds handled | Both whole-tree moves (prefix remap) and reorganized files (scan and match) |
| V1 capabilities | All-media gallery, library health plus re-link, bulk link management, storage/transfer status |
| Import from the Media section | Yes, with automatic dive matching via `DivePhotoMatcher` |
| Platforms for repair tools | All platforms (desktop folder pickers, Android SAF trees, iOS document picker) |
| Library browse layout | All three modes: flat grid, grouped by dive, timeline -- user-switchable |
| Section structure | Management console: desktop sidebar, phone top tabs |
| Repair UX | Guided 3-step wizard (scope, review, apply) |
| Repair sources | All media sources: local/network folders, device photo library, cloud media store |
| Store-based repair semantics | Cloud-backed only: the row becomes store-backed; no bulk downloads |
| Implementation approach | Full DAM platform (engine + query layer + watcher + audit + smart albums), built in phases |
| Dive-detail Unlink fix | Split into true Unlink (clears FK) and explicit Delete |
| Watcher default | Auto-apply exact-hash matches; suggest-only for everything else |

## 3. Navigation and section structure

### Navigation

- New `NavDestination(id: 'media', route: '/media')` in `kNavDestinations`
  (`lib/shared/widgets/nav/nav_destinations.dart`), inserted after `trips` in
  canonical order.
- New `GoRoute(path: '/media', name: 'media')` under the existing `ShellRoute`
  in `lib/core/router/app_router.dart`, using `NoTransitionPage` like its
  siblings.
- `nav_media` key added to `lib/l10n/arb/app_en.arb` and all 10 non-English
  locales, with l10n regeneration.
- Accent color entries for `'media'` in both light and dark maps of
  `lib/core/theme/feature_accent_colors.dart`.
- The desktop rail picks the destination up automatically; on phone it lands in
  the More overflow unless the user promotes it via Settings > Appearance.
  No changes to the primary-slot mechanism.
- Tests updated: `test/shared/widgets/nav/nav_destinations_test.dart` (catalog
  length and order), `test/shared/widgets/nav/rail_destination_order_test.dart`,
  `test/core/theme/feature_accent_colors_test.dart`.

### Console structure

A `MediaConsoleScaffold` widget owns the section's internal navigation,
mirroring how `MainScaffold` adapts rail versus bottom bar:

- **Desktop / wide:** a left sidebar inside the Media section with entries
  Library, Unlinked, Missing, Transfers, Import -- and, once Phase 5 lands,
  Smart Albums and Sources (per-source browsing).
- **Phone / narrow:** the sidebar collapses to top tabs with count badges on
  Unlinked and Missing.

Unlinked and Missing sidebar entries show live count badges backed by watched
count queries.

## 4. Data model

### Main database: schema v140

v137 is current on main; v138 is reserved for the divelogs.de sync work
(issue 603) and v139 is claimed by the equipment default-currency work
(PR 805). This design claims **v140** for a single migration containing the
`retain_in_library` column (item 2), landing in Phase 1 (the column stays
dormant until Phase 2 consumes it). The indexes (item 3) ride the
`kPerformanceIndexes` list, which is asserted on every open from beforeOpen
and therefore needs no version bump. The `mediaStore` source type (item 1)
requires no schema change. The Phase 5 tables (items 4 and 5) claim whatever
number is next free when Phase 5 starts. All claims are re-verified against
the schema version ladder at implementation time.

1. **New source type `mediaStore`** -- a new value of `MediaSourceType`
   (`lib/features/media/domain/entities/media_source_type.dart`). No column
   change; `sourceType` is TEXT. Semantics of a cloud-backed row:
   - `sourceType = 'mediaStore'`
   - `localPath`, `bookmarkRef`, `platformAssetId` are null (cleared at
     conversion)
   - `contentHash` and `remoteUploadedAt` are non-null -- this pair is the
     integrity requirement; conversion is refused without it
   - `isOrphaned = false`
   A new `MediaStoreSourceResolver` is registered in the resolver registry for
   this type, reading through the existing media cache and store machinery.
   This deliberately promotes the previously-unregistered store fallback
   (`media_store_resolver.dart`) to a first-class source: the meaning changes
   from "temporarily unavailable locally" to "the store is this row's source of
   truth". Cloud-backed rows are device-independent: they render identically on
   every synced device.

2. **New column `media.retain_in_library`** (bool, NOT NULL, default false,
   synced with the row). Set to true on explicit user unlink, on Media-section
   imports, and on inbox "keep". The orphan sweep predicate
   (`MediaRepository.getSweepableOrphanIds`) gains `AND NOT retain_in_library`.
   Rationale: this design promotes "unlinked but kept" from an error state to a
   legitimate state; without the flag, the orphan-prevention sweep would GC the
   cloud blobs of deliberately-unlinked media after the age cutoff.
   Dive-deletion unlinks leave the flag false, preserving the sweep's original
   job.

3. **Indexes** on `media(local_path)`, `media(file_path)`, and
   `media(is_orphaned)`, added via `lib/core/database/performance_indexes.dart`
   and wired into **both** `onCreate` and `onUpgrade` (the earlier performance
   work only covered `onUpgrade`; this must not repeat that).

4. **New table `media_repair_log`** (Phase 5 audit trail):
   `id`, `mediaId`, `batchId`, `occurredAt`, `action`
   (relink / cloudBacked / unlink / reassign / autoRelink), `oldValue`,
   `newValue`, `source` (folder / photoLibrary / store / watcher / manual).
   Lives in the main database but is **per-device and not synced** (paths are
   device-specific; precedent: `PendingPhotoSuggestions`). Not registered in
   `SyncRepository.entityTables`. Pruned to the newest 500 rows.

5. **New table `media_smart_albums`** (Phase 5): `id`, `name`, `filterJson`,
   `sortOrder`, `hlc`. **Synced** (user data) and registered in the sync entity
   tables. A smart album is a named, serialized `MediaLibraryFilter`.

### Local cache database: v9

Own ladder; v8 (reef) is current, v9 is next free. New table
`watched_folder_index` for the Phase 5 watcher: `rootPath`, `relativePath`,
`sizeBytes`, `mtime`, `contentHash`. Purely derivable data -- never synced,
never backed up. Rescans re-hash only files whose size or mtime changed.

### Scoping and exclusions

Applied by every library query:

- Signature rows (`fileType = 'instructor_signature'`) are always excluded.
- Dive-linked media follows the active diver via a join on `dives`.
- Unlinked and site-only media is diver-global, consistent with how the orphan
  sweep treats it today.

### Sync safety

Every repair mutation goes through `MediaRepository.updateMedia`, which already
marks rows pending with a fresh HLC. No new sync surface. Cloud-backed
conversions propagate meaningfully to other devices; path re-links propagate
harmlessly (path columns were already device-local noise on other machines,
handled by `originDeviceId` display logic).

## 5. Library

### Query layer

New `media_library_repository.dart` (separate file; `MediaRepository` is
already about 1,400 lines). One job: paginated, filtered, cross-dive reads.

- **Filter object:** `MediaLibraryFilter` domain object -- media type
  (photo/video), site, trip, dive, date range, source type, health status
  (missing / unlinked / cloud-backed) -- compiled to SQL following the
  `DiveFilterSql` pattern used by Statistics. Serializable to JSON (this is
  what smart albums store).
- **Pagination:** keyset on `(takenAt DESC, id)` with `createdAt` fallback for
  rows without `takenAt`. Not offset-based; scrolling a 20k-item library stays
  flat-cost.
- **Counts:** watched count queries for the Unlinked and Missing badges,
  backed by the new indexes.

### View modes

One `MediaLibraryPage` hosts three presentations of the same paged stream; the
mode is persisted as an app setting:

- **Grid:** flat sliver grid, newest first, infinite scroll, filter chip bar.
- **By dive:** sections with dive number, site, and date headers; header tap
  navigates to the dive; a pinned "Unlinked" section at the end of the list.
  Grouping happens on the already-sorted page stream -- no second query.
- **Timeline:** month and day headers with dive chips linking to the owning
  dives; same stream, different grouper.

### Rendering and viewer

- Every tile is the existing `MediaItemView`, which already handles resolver
  dispatch, store fallback, video badges, and unavailable placeholders. The
  Library inherits correct behavior for every source type, including
  `mediaStore` rows, on day one.
- The trip-scoped viewer (`trip_photo_viewer_page.dart`) generalizes into one
  shared full-screen viewer taking `(mediaList, startIndex)`, used by dive
  detail, trips, and the Library. The three near-duplicate viewers collapse
  into one. The viewer gains a "Go to dive" action.

### Selection

Phase 1 ships multi-select infrastructure (long-press on touch, click-drag or
modifier-click on desktop, select-all-in-group) with Delete (existing deletion
coordinator, explicit confirm) and Share. Link-management bulk actions land on
the same selection bar in Phase 2; repair actions in Phase 3.

### Reactivity

A single `mediaLibraryVersionProvider` bumped by media mutations invalidates
the paged notifier. Deliberately coarse to avoid per-row invalidation storms
(see the sync invalidation-storm history).

## 6. Repair engine and wizard (Phase 3)

### Engine

`MediaRepairService` under `lib/features/media/` with a pluggable candidate
interface:

```dart
abstract class CandidateSource {
  Future<List<RepairCandidate>> findCandidates(List<MediaItem> brokenRows);
}
```

**Input:** rows whose resolver verdict is `notFound`. Volume-offline rows are
excluded -- an unmounted NAS is not broken (matches the existing
`VolumeStatus` semantics in `LocalFileResolver`).

**Sources:**

1. **`FolderCandidateSource`** -- user-picked local or network folder(s),
   recursive. Files indexed by name and size; hashing is on-demand, never
   eager. Before per-file matching it runs **prefix-move detection**: when
   broken paths and found paths share relative suffixes under a common root
   pair, it proposes the whole mapping at once. Folder access: security-scoped
   folder on macOS, SAF tree URI on Android, document-picker folder on iOS,
   plain paths on Windows and Linux.
2. **`PhotoLibraryCandidateSource`** -- `photo_manager` query in a date window
   around the row's `takenAt`, size compare, then lazy hash of finalists. An
   accepted match converts the row to `platformGallery` with the new
   `platformAssetId`.
3. **`StoreCandidateSource`** -- no scanning. A row qualifies when
   `contentHash` and `remoteUploadedAt` are present; a HEAD verify runs when
   the store is reachable and annotates "unverified" when it is not. Accepting
   converts the row to cloud-backed `mediaStore` (section 4 semantics).

**Match ladder (confidence):**

| Level | Meaning | Review default |
| --- | --- | --- |
| exact | content hash equal | pre-checked |
| probable | name and size agree, hash not yet computed | pre-checked; hash runs before apply and promotes to exact, or demotes to edited -- demoted rows are skipped, not applied, and reported in the summary as "changed on disk" |
| edited | name matches, bytes differ | unchecked (opt-in) |
| unmatched | no candidate | listed with per-row Browse escape hatch |

Accepting an **edited** match re-hashes, calls `stampContentIdentity`, clears
the remote-upload stamps (`clearRemoteUploaded`, `clearRemoteThumbUploaded`,
`clearRemoteCompressed`), and enqueues a re-upload -- the store never serves
stale bytes. This ladder also fixes the latent bug in the existing single-item
"Replace link" (`DiveMediaSection._replaceLink` rewrites the path without
verifying content identity); that flow is rewired through this engine so
single-item and bulk repair cannot drift apart.

**Apply (staged for partial failure):**

- **Stage A (per row, fallible I/O):** hash verification via the full sandbox
  ladder (the read-probe from `LocalFileResolver`, not bare `exists()`), and
  macOS/iOS bookmark regeneration under the existing `bookmarkRef` key.
  Failures drop the row into the summary; the batch continues.
- **Stage B (one DB transaction, all survivors):** `localPath` rewrite (and
  normalization of legacy rows whose path lives in `filePath`), `isOrphaned`
  cleared, `lastVerifiedAt` stamped, one `media_repair_log` row per action --
  all through `updateMedia` so HLC marking happens per row.
- **Stage C:** store upload enqueues (already idempotent per media id).

**Ambiguity rules:** one row with two same-hash candidates prefers the
prefix-map location, otherwise surfaces as a chooser in review. Many rows
matching one file is legal -- duplicate rows legitimately share a content
hash; refcounts are hash-based.

### Wizard

Launched from the Missing view (or its banner) as a 3-step flow:

1. **Scope and sources** -- which broken rows (all missing, or current
   selection) and which sources to search: folder picker(s), photo library
   toggle, cloud store toggle.
2. **Review** -- prefix-move callout ("Folder move detected: X to Y covers
   9 of 12 files"), matches grouped by confidence with checkboxes per the
   ladder defaults, ambiguity choosers, and the unmatched list with per-row
   Browse.
3. **Apply** -- progress, then a summary: n re-linked, n cloud-backed,
   n re-uploads queued, n failed, n still missing.

The Missing view itself shows two informational buckets that are not repair
targets: rows on offline volumes (counted, visible, excluded from the wizard)
and rows already queued for repair actions.

## 7. Watcher (Phase 5)

The same engine on a timer instead of a wizard:

- The user registers watched roots (typically the new library location).
- A throttled background scan maintains `watched_folder_index`, re-hashing
  only changed files. Triggers: app start (at most once per day) and a manual
  "Scan now" action on the watched-roots settings surface.
- When a missing row's hash appears in the index, **exact matches auto-apply**
  (bytes are identical, so this is safe), logged with `source: watcher`. A
  setting demotes the watcher to suggest-only. Non-exact matches only ever
  become suggestions surfaced in the Missing view.

## 8. Link management (Phase 2)

- **True unlink:** new repository op `unlinkFromDive(ids)` -- sets
  `diveId = NULL` in a transaction with per-row HLC marking, the same
  sync-safe shape as `unlinkMediaFromDeletedDives`. A matching
  `unlinkFromSite(ids)` exists for rows with a site link; it is exposed only
  in the Library selection bar and inbox, on rows that actually have one
  (site links are currently created only by site merges).
- **Dive-detail fix:** the selection bar splits today's destructive "Unlink"
  into **Unlink** (clears the FK, sets `retainInLibrary = true`, row appears
  in the inbox) and **Delete** (current behavior, explicit confirm).
- **Reassign ("Move to dive"):** unlink's sibling with a dive picker (search
  by number, date, site). Reassigning **invalidates and recomputes the row's
  `MediaEnrichment`** -- enrichment is a join product of media and the old
  dive's profile and is stale on the new dive.
- **Unlinked inbox:** rows with no dive and no site, excluding library-level
  source types (`networkUrl`, `manifestEntry` are unlinked by design). Each
  item gets `DivePhotoMatcher` suggestions from `takenAt`: confident matches
  render as one-tap "Link to dive N" chips, ambiguous matches open a chooser,
  and manual dive/site pickers cover the rest. Inbox "keep" sets
  `retainInLibrary = true`.

## 9. Import with auto-match (Phase 4)

- The sidebar's Import opens the existing three-tab picker (Gallery / Files /
  URL) with no dive context. Imports land with `retainInLibrary = true`.
- After a batch, an auto-match pass runs `DivePhotoMatcher` over everything
  imported and presents one confirmation screen ("Link 34 items across 5
  dives") with confident matches pre-checked. Leftovers stay in the inbox.

## 10. Transfers (Phase 1)

The sidebar's Transfers view reuses the existing transfer-queue page content
(summary row, per-item progress, retry actions) from
`lib/features/media_store/presentation/`. Store configuration stays in
Settings -- the Media section shows state; Settings changes it.

## 11. Error handling

- **Partial failure:** staged apply (section 6). A bookmark failure on one
  file never poisons the batch; Stage B is all-or-nothing for the DB.
- **Sandbox correctness:** all candidate verification uses the read-probe
  ladder, so macOS cannot hand the wizard a file it will not be able to open.
- **Cloud-backed guards:** conversion requires the stamp pair; HEAD verify is
  best-effort with an "unverified" annotation when the store is unreachable.
- **Volume-offline:** informational bucket in the Missing view; never a
  repair target.
- **Concurrency:** repairs are safe against in-flight uploads (the pipeline
  re-resolves bytes at upload time; edited-file acceptance goes through the
  idempotent re-upload path). The engine never touches the delete path --
  `MediaDeletionCoordinator` remains the single enqueuer of blob deletes.
- **Multi-device:** repairs sync via HLC as ordinary row updates. Path
  rewrites are meaningless-but-harmless on other devices (existing
  `originDeviceId` behavior); cloud-backed conversions are meaningful
  everywhere.
- **Localization:** all new UI strings land in English plus the 10 other
  locales at introduction, with l10n regeneration.

## 12. Testing

TDD throughout; 80 percent minimum coverage per project rules.

- **Engine unit tests (core investment):** match ladder, prefix-move
  detection (hand-computed vectors, not implementation-derived), edited-file
  promotion/demotion, cloud-backed guards, sweep predicate with
  `retainInLibrary`, enrichment invalidation on reassign. `CandidateSource`
  is faked. `FolderCandidateSource` additionally gets integration tests
  against real temp directory trees with real hashing.
- **Repository tests** on in-memory Drift: keyset pagination, filter-to-SQL
  compilation, unlink/reassign HLC marking, migration tests for the v140
  column and cache v8 to v9.
- **Widget tests:** console adaptivity (sidebar versus tabs), the three view
  modes over fake pages, wizard steps over a mocked engine, inbox suggestion
  chips. Known repo traps respected: pinned `MaterialApp` locale, no Drift
  under `FakeAsync`, provider-dependency changes breaking consumer tests --
  the full suite runs after `DiveMediaSection` edits.
- **Platform channels** (bookmarks, SAF, document picker) sit behind
  interfaces that tests fake; each platform gets a short manual verification
  checklist since CI cannot exercise them.
- **Navigation tests** updated for the new destination (catalog, rail order,
  accent colors).

## 13. Phasing

| Phase | Contents | Ships |
| --- | --- | --- |
| 1 | Nav entry, console scaffold, library query layer, three view modes, shared viewer, selection with Delete/Share, Transfers view | Independently usable browse experience |
| 2 | True unlink, reassign with enrichment recompute, unlinked inbox with matcher chips, dive-detail Unlink/Delete split, `retainInLibrary` | Fixes the unlink-is-delete trap |
| 3 | Repair engine, three candidate sources, wizard, cloud-backed conversion, Missing view, single-item Replace link rewired | The motivating scenario |
| 4 | Import from Media with batch auto-match | Library as the entry point for new media |
| 5 | Watcher with auto-apply, `media_repair_log` audit view, smart albums, per-source browsing | DAM extras |

Phases ship independently with no feature flag; each is additive and the
sidebar simply grows. Schema timing (details in section 4): the v140 migration
(dormant `retain_in_library`) and the beforeOpen-asserted indexes land in
Phase 1; the `mediaStore` source type needs no migration and arrives with
Phase 3; the audit and smart-album tables and cache v9 arrive with Phase 5
under whatever version numbers are then free.

## 14. Out of scope

- Bulk download/rematerialization from the cloud store (explicitly decided
  against: store repair is cloud-backed only). Single-item download remains
  available via the existing viewer actions.
- Media editing (crop, rotate, color).
- Equipment-linked media (no `media.equipment_id` exists; not added here).
- Changes to avatar handling (`photoPath` scalar columns are not media rows).
- Lightroom connector UI changes (remains behind `kLightroomUiEnabled`).
