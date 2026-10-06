# Media: Attached or Absent. Design

**Status:** approved 2026-08-23, implemented on this branch
**Branch:** `worktree-media-attached-or-absent`
**Supersedes:** the "Unlinked inbox" and `retainInLibrary` decisions of the
2026-08-05 Media section design (Phase 2), and the library-level source-type
exemption of the 2026-07-23 media store orphan-prevention design (section 3).
**Complements:** PR #1230 (unlink from dive is a delete unless site-linked).

## 1. Problem

The Media section has two sidebar destinations, "Unlinked" and "Missing",
that read as places but are really states of a row. A user opening the
section cannot tell what they are for or why they exist. Underneath, the
Library's filter model already carries both as a `health` facet
(`MediaHealthFilter.missing` / `.unlinked`), compiled to SQL and even
serialized into smart albums, but the filter bar never exposes it. The two
sections exist because each state came with a workflow: a triage inbox with
auto-match suggestions for Unlinked, and the repair wizard for Missing.

The product principle behind this design, stated by the owner:

> If a piece of media is neither attached to a dive nor a site, it should not
> be in the media library.

Today that principle is half true. PR #1230 made "Unlink from dive" delete
the row unless a site still references it. Everything else still produces or
preserves unlinked rows:

- **Library import** (`importPhotosToLibrary`) inserts every picked asset as
  retained-and-unlinked, then a follow-up page links only confident
  auto-matches. The rest stay unlinked, waiting in the inbox.
- **Network sources** (`NetworkFetchPipeline`) must insert a row before a
  URL's timestamp is known, so every `networkUrl` and `manifestEntry` row is
  born unlinked and auto-match is "additive". The orphan-prevention audit then
  exempted those two source types from the dive-deletion cascade, from
  unlink, and from the orphan sweep (`MediaRepository.libraryLevelSourceTypes`).
- **Unlink from site** (Library selection bar) clears the site link and latches
  `retainInLibrary = true`, leaving an unlinked row that the sweep can never
  reclaim.
- The inbox's **Keep in library** action exists specifically to hold unlinked
  rows forever.
- The **site detail page's Unlink** is a hard delete through the deletion
  coordinator, even for rows a dive still references.

Every one of these traces to one pattern: insert first, resolve the link
later. This design removes the pattern rather than the symptom.

## 2. Locked decisions

Made during brainstorming on 2026-08-23, in this order:

1. Unlinked and Missing leave the sidebar. Missing becomes a Library health
   filter with its tools shown contextually. Unlinked disappears entirely.
2. Every library row is attached to a dive or a site. No unlinked state,
   transient or permanent.
3. Library import never creates unlinked rows: the match happens before the
   insert, and unresolved assets are not imported.
4. The rule applies to network sources too. The `libraryLevelSourceTypes`
   exemption is removed.
5. Existing unlinked rows are removed by a cleanup at launch, through the
   same path Unlink uses. Original files on disk or in Photos are never
   touched.
6. Enforcement mechanism: **resolve the link before the insert** (chosen over
   "insert then delete on no-match" and "staged rows with a pending flag").
   No row exists until its dive or site is known, so nothing transient ever
   syncs, uploads, or leaves a tombstone.

## 3. The invariant and the data layer

**Rule.** Every row in `media` has `dive_id` or `site_id` non-null, for every
source type, at every moment after its insert commits. Signature rows
(`fileType` instructor or buddy signature) already always carry a dive and
are untouched.

### 3.1 `MediaRepository`

- `libraryLevelSourceTypes` is deleted. Its three consumers change:
  - `partitionMediaForDiveDeletion` keeps a row only when `siteId` is set;
    `partitionMediaForSiteDeletion` keeps a row only when `diveId` is set.
    Dive-only rows die with the dive, site-only rows die with the site,
    dual-linked rows lose one link.
  - `partitionForDiveUnlink` returns `siteLinked` (keep, clear dive) and
    `deletable` (everything else), with no source-type escape hatch.
- New `partitionForSiteUnlink(ids)` returns `diveLinked` (keep, clear site)
  and `deletable` (no dive link).
- `unlinkFromDive` and `unlinkFromSite` stop writing `retainInLibrary`.
  `markRetainedInLibrary` and `countUnlinked` are removed.
- `getSweepableOrphanIds` drops the `retain_in_library = false` and the
  source-type clauses. Its predicate becomes: `NOT isLinkedToDiveOrSite` AND
  `created_at` older than the caller's cutoff. The age guard survives purely
  as a safety margin.
- The `retain_in_library` column stays in the schema. Nothing reads it after
  this change; a later schema bump may drop it. No migration in this design.
- `MediaHealthFilter.unlinked` is removed from the enum. Smart albums that
  serialized it decode leniently to "no health constraint", which
  `MediaLibraryFilter.fromJson` already does for unknown names.

### 3.2 `MediaUnlinkService`

Gains `unlinkFromSite(ids)` with the same shape as `unlinkFromDive`: the
keep-half first (clear the site link on dive-linked rows), then delete the
rest through the injected coordinator path, returning an `UnlinkOutcome` with
`deleted` and `keptAsDiveMedia`. `idsWithUserMetadataAtRisk` gets a
site-scoped twin so the metadata warning dialog counts only rows the site
unlink would actually delete.

### 3.3 Callers

- Library selection bar "Unlink from site" routes through the service instead
  of calling `repository.unlinkFromSite` directly.
- Site detail page unlink (`site_media_section.dart`) routes through the
  service instead of `siteMediaListNotifierProvider.deleteMultipleMedia`.
  Its dialog copy names the dive-linked exception, mirroring the dive-side
  copy from PR #1230.
- Dive-side callers are already on the service and do not change.

With this, the cascade, unlink, and sweep predicates collapse to one
definition (`isLinkedToDiveOrSite`), which the orphan-prevention design
wanted before its audit forced the exemption.

## 4. Library import: a pre-import review

**Today.** The Import console section opens the picker with no target, calls
`importPhotosToLibrary` (rows inserted as retained-and-unlinked), then pushes
`MediaImportLinkPage` with the new ids. That page links only pre-checked
confident matches and leaves the rest unlinked.

**New flow.** The picker returns its `List<AssetInfo>`; nothing is written.
`MediaImportLinkPage` is reworked to take assets rather than ids. It computes
one suggestion per asset from `asset.createDateTime` converted with
`TripMediaScanner.toWallClockUtc`, which is the exact value
`_createMediaItemFromAsset` persists as `takenAt`, so the match the user sees
is the match the row would have received. Matching reuses
`computeInboxSuggestion(takenAt:, candidateDives:)`, already a pure
function. The provider feeding it changes from "load the row by id" to "take
the asset's timestamp", loading candidate dives in the same one-day window the
current `inboxSuggestionProvider` uses. Both move next to the review page
they now serve.

Each asset renders in one of three states:

| State | Default | Affordance |
| --- | --- | --- |
| Confident | checked, labeled with the dive | uncheck means "do not import" |
| Ambiguous | unchecked | "Choose dive" listing the candidates (the inbox's `_AmbiguousDiveTile` sheet moves here) |
| No match | unchecked | "Choose dive" (`showDivePickerSheet`) and "Choose site" (the inbox's inline site sheet, extracted as `showSitePickerSheet`) |

Confirm groups resolved assets by target and calls `importPhotosForDive`
once per dive and `importPhotosForSite` once per site. The dive path runs
enrichment at import, which the library import skipped and
`reassignMediaToDive` later had to recompute; that recompute path is no
longer needed here. Unresolved assets are not imported. The result snackbar
reports "N linked, M skipped". Back or cancel imports nothing. Dedupe stays
per the called method (dive-scoped or site-scoped), matching the dive and
site pages.

**Removed:** `importPhotosToLibrary`, the `retainInLibrary` parameter on
`_createMediaItemFromAsset`, this page's `reassignMediaToDive` path, and
`media_import_library_test.dart`. The `launchOverride` test seam on
`MediaImportView` returns assets instead of ids.

## 5. Network sources

### 5.1 Pipeline split

`NetworkFetchPipeline` separates the two things it interleaves today.

- `resolve(uris)` runs the existing worker pool, per-host throttle, and
  `UrlMetadataExtractor`, and returns one `ResolvedNetworkMedia` per URL:
  final URL, `takenAt`, dimensions, GPS, or a failure message. It writes
  nothing.
- `insertResolved(items)` takes resolved items paired with a target (exactly
  one of `diveId` or `siteId`; enforced, not documented) and inserts
  fully-formed rows: linked, `lastVerifiedAt` stamped, or `isOrphaned = true`
  plus a `media_fetch_diagnostics` row when the fetch had failed.
- `_tryAutoMatch` and its post-insert rollback are deleted. Matching runs on
  the resolved metadata, before the insert, in the caller.
- Manifest entries follow the same path with the same rule: extraction is
  skipped when the manifest prefilled `takenAt`, dimensions, and GPS, so a
  fully described feed still never touches the network.

### 5.2 URL tab

Add becomes a two-step action: resolve the draft lines (with a progress
indicator; this fetch used to run in the background), then decide targets by
context.

- **Opened from a dive:** every URL attaches to that dive, as the Gallery and
  Files tabs already treat the dive target. Today the dive target is dropped
  (`url_tab_providers.dart` maps `DiveAttachTarget` to null) and only date
  matching decides.
- **Opened from a site:** every URL attaches to that site (unchanged).
- **Opened from the Media section's Import (no target):** the section 4
  review, fed by each resolved `takenAt`. A URL whose fetch failed has no
  timestamp; it shows the error inline and needs an explicit pick to be
  imported (as a linked, orphaned row with diagnostics) or is skipped.

The `autoMatchByDate` checkbox is removed: in dive and site context it no
longer applies, and with no target the review always shows the match and
lets the user override it. Undo keeps deleting the committed ids.

### 5.3 Manifest one-shot import

The panel's Import button resolves the entries and runs the same review
before inserting. The subscription row is still created first (the pipeline
needs its id) and the existing Undo path still removes both.

### 5.4 Subscription polling

Polling runs with no user present, so it inserts only entries with a
confident match to a dive, linked at insert. Ambiguous and unmatched entries
are not inserted. Because `SubscriptionPoller` defines "new" as "no media
row with this `entryKey`", a skipped entry is re-evaluated on every later
poll with no extra state: log the dive later and the next poll pulls the
photo in. The poll log line reports the skipped count. Entries that vanish
from the feed still flip their rows to orphaned.

### 5.5 Explicitly unchanged

Bytes still live only in the image cache (no S3 upload, no `contentHash`).
Rows and subscriptions sync as before. Deleting a subscription still leaves
its media rows in place; they are dive-linked now and no longer violate the
invariant, but the dangling `subscription_id` remains a separate wart, out of
scope here.

## 6. The Media console

### 6.1 Navigation

`MediaConsoleSection` shrinks to Library, Sources, Transfers, Import. The
`unlinked` and `missing` values, their `media_console_*` labels, and
`unlinkedCountProvider` are removed. `missingCountProvider` survives and
drives a badge on the Library entry through the scaffold's existing
`badgeCounts` map.

### 6.2 Missing as a health chip

`MediaLibraryFilterBar` gains one `FilterChip`, "Missing files", toggling
`MediaLibraryFilter.health` between `missing` and null. Its label carries the
count when non-zero ("Missing files (3)") and it participates in Clear like
every other chip. `health` is already compiled to SQL by
`MediaLibraryRepository` and already serialized into smart albums, so this is
a chip, not a new query path. The three view modes (grid, by dive, timeline)
work on the filtered set unchanged.

### 6.3 Contextual repair tools

When the health filter is active, `MediaLibraryView` inserts a
`MediaMissingBanner` between the filter bar row and the body, carrying what
`MediaMissingView`'s header carries today:

- the offline-volumes count (informational; those rows are unmounted, not
  broken, and the wizard skips them);
- the Repair button opening `MediaRepairWizardPage`, hidden when the filtered
  list is empty;
- the repair-history icon opening `MediaRepairHistoryView`, always shown,
  since an empty list is exactly when the user wants to check what the last
  repair did.

`missingOfflineCountProvider` reads the Library notifier's entries instead of
the deleted `missingViewProvider`. Tile taps keep the Library's behavior
(open the viewer, which already renders an unavailable placeholder); the info
sheet stays one tap away from the viewer.

### 6.4 Removed

`MediaUnlinkedInboxView`, `MediaMissingView`, `media_inbox_providers.dart`
(except `computeInboxSuggestion` and the candidate-dive loading, which move
beside the import review), the six `media_inbox_*` keys and
`media_console_unlinked` / `media_console_missing` across all eleven ARB
catalogs, and the tests `media_inbox_test.dart` and
`media_missing_view_test.dart` (replaced by chip and banner tests). The
`media_missing_*` strings are kept and reused by the banner.

### 6.5 Deliberately not added

An "Unlinked" chip. With sections 3 to 5 in place the set is empty by
construction; a chip that can never match would be the same confusing
signpost this design starts from.

## 7. Upgrade cleanup

`MediaOrphanBacklogSweep`, run from `startup_page.dart`, is the host. Its
predicate already becomes "unlinked and older than 24 hours" in section 3.
The gate changes: the one-shot `media_orphan_backlog_swept_v1` preference
flag is replaced by a run on every launch.

Reasoning: the query is one indexed `SELECT` and is empty on a healthy
library. A mixed-version fleet can still sync an unlinked row into an
upgraded device from a device that has not upgraded yet; a one-time flag
would leave that row forever, a per-launch pass removes it the next day.
Deletion goes through `MediaDeletionCoordinator` as today: cloud blobs get
their delete intent, tombstones propagate, every device converges. Original
files on disk or in Photos are never touched, the same guarantee Unlink
makes. The log line reports the swept count so the first post-upgrade launch
is auditable.

## 8. Sync

No new synced entity and no schema version bump. `retain_in_library` stays a
column and serializes whatever it holds. Rows created by the new import paths
carry their link from their first synced version, so peers never observe an
intermediate unlinked state. Smart albums referencing `health: unlinked`
decode to "no constraint" on every version.

## 9. Error handling

- **Import review confirm:** per-dive and per-site imports run independently;
  each `ImportResult.failures` map is aggregated into the result snackbar and
  a failure in one group never blocks another. An asset that failed has no
  row, consistent with the invariant.
- **URL resolve:** a fetch failure is shown inline on that line. In dive or
  site context the row is still inserted linked and orphaned with
  diagnostics (today's behavior); with no target it needs an explicit pick or
  is skipped. A throw from the extractor is caught per URL, never per batch.
- **Poller:** unchanged wrapping. A match-loader failure for one entry skips
  that entry and logs; the entry is re-evaluated next poll.
- **Site unlink:** keep-half first, then delete, mirroring the dive service,
  so a delete failure leaves dive-linked rows correctly detached.

## 10. Testing

TDD, per test file the code touches.

- **Repository:** cascade partition tests updated for the removed exemption;
  `partitionForSiteUnlink`; sweep predicate proves `networkUrl` and
  `manifestEntry` rows are sweepable and `retain_in_library` is ignored.
- **Unlink service:** `unlinkFromSite` outcome and ordering; the site-scoped
  metadata-at-risk twin.
- **Import review:** widget tests for the three states, grouping on confirm,
  "unresolved assets create no rows", cancel writes nothing.
- **Pipeline:** `resolve` returns metadata without inserting;
  `insertResolved` requires exactly one target; poller inserts only confident
  matches and re-evaluates skipped keys on the next poll.
- **URL tab:** dive context attaches to the dive; site context attaches to
  the site; no target opens the review; a failed fetch needs a pick.
- **Console:** chip toggles the health filter and shows the count; banner
  renders repair and history controls; Library badge reflects
  `missingCountProvider`; the `provider_change_tick_test` contract for any
  new media provider.
- **Sweep:** runs every launch, deletes only rows older than the guard,
  idempotent across two runs.
- One full-suite run before the PR; a lone failure in an untouched file is checked against the known-flake list and rerun alone.

## 11. Out of scope

- Dropping the `retain_in_library` column (needs a schema bump; nothing reads
  it after this design).
- Cascading manifest media when a subscription is deleted.
- Repairing `networkUrl` rows through the Missing wizard (its candidate
  sources are folders, the photo library, and the cloud store).
- A single-item Unlink action in the media viewer. The multi-select unlink on
  the dive page, site page, and Library remains the entry point.
