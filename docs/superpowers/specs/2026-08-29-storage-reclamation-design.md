# Storage reclamation: inventory, caps, and sweeps

Design for issue #1375, "Nothing reclaims on-device caches or temp files".

Date: 2026-08-29

## Problem

The app never reclaims disk space on any schedule. Several caches are uncapped
and never evicted, some temp directories are write-only, the sync tombstone log
grows forever for local-only users, and there is no surface anywhere that tells
a user how much space the app is holding or where it went.

A 40-dive development install measures 133 MB of container, of which the
database is 28 MB. A stale 73 MB Sparkle update `.dmg` in `Library/Caches` was
larger than the entire database.

Much of this is code the project already wrote and then never called: the
eviction functions exist, the cap constants exist, and neither is reached.

## What was verified in the tree

The issue is an audit. Before designing against it, each claim was checked. Most
held. Three findings changed the shape of the work.

### There is no startup-maintenance host, and one was deliberately abandoned

`lib/core/services/maintenance/` does not exist. A generic
`StartupMaintenanceRunner` was built in PR #516 and then removed, and the
decision not to revive it is recorded twice:

- `docs/superpowers/specs/2026-07-17-data-quality-assistant-design.md:85`
- `docs/superpowers/plans/2026-08-06-media-section-phase5.md:589`

`lib/features/media/presentation/providers/media_watcher_providers.dart:196`
works around its absence explicitly.

The live precedent is narrower: `MediaOrphanBacklogSweep`
(`lib/features/media_store/data/media_orphan_backlog_sweep.dart`, 42 lines) is
constructed inline and fired `unawaited` inside a swallow-and-log wrapper at
`lib/core/presentation/pages/startup_page.dart:686`. Any new sweep follows that
shape. This design does not reintroduce a task runner.

### Cadence guards exist in three unshared flavours

- Prefs done-flag: `media_origin_republish_v1`
  (`lib/features/media_store/data/media_origin_republish_sweep.dart:53`)
- Prefs version int: `builtin_species_seed_version`
  (`lib/features/marine_life/data/services/builtin_species_seed_version_store.dart:17`)
- Synced DB column with a fleet-wide 30-day cadence: `media_stores.last_sweep_at`
  (`lib/core/database/database.dart:1637`)

`MediaOrphanBacklogSweep` uses none of them. It can run unguarded on every launch
because its probe is one indexed `SELECT`
(`MediaRepository.getSweepableOrphanIds`,
`lib/features/media/data/repositories/media_repository.dart:1866`). A filesystem
walk is not that cheap, so a filesystem sweep needs a guard. A prefs timestamp is
the correct flavour: the state being tracked is per-device by nature and must not
sync.

### Tombstone GC already has its floor; what it lacks is reachability

The issue proposes giving `deletion_log` "a time-based floor for local-only
libraries". A 30-day floor already exists
(`SyncLiveness.gcFloorMillis`,
`lib/core/services/sync/changeset_log/sync_liveness.dart:15`), and
`TombstoneGcDecision` already offers an `unbounded()` constructor
(`lib/core/services/sync/changeset_log/tombstone_horizon.dart`).

The actual defect is that `SyncRepository.clearAcknowledgedDeletions`
(`lib/core/data/repositories/sync_repository.dart:1119`) is reached from exactly
one place: the tail of a successful cloud sync
(`lib/core/services/sync/sync_service.dart:744`). A device that has never
configured sync never arrives there, so its tombstones are immortal.

This reframes the per-sample tombstone concern. `TankPressureRepository`
(`lib/features/dive_log/data/repositories/tank_pressure_repository.dart:114`),
`DiveSplitService`
(`lib/features/dive_log/data/services/dive_split_service.dart:337`) and
`SafetyFindingsRepository`
(`lib/features/dive_log/data/repositories/safety_findings_repository.dart:57`)
do each mint one tombstone per row, and a tank-pressure re-import of a 60-minute
dive at 10-second sampling mints roughly 360 of them per tank. At around 100
bytes a row that is tens of KB, which a working GC reclaims on the 30-day floor.
The unbounded growth is the absence of GC, not the minting rate.

## Scope decisions

### The audit splits five ways, not seven

| Slice | Scope | Audit items | Risk |
| --- | --- | --- | --- |
| A | Storage inventory and a read-only Storage usage page | 7 | Very low, reads only |
| B | Wire the caps that already exist | 1, 2, 4 | Low |
| C | Scratch-file sweep | 3, minus the unsafe targets | Medium, deletes files |
| D | Orphaned backup files | 5 | Medium |
| E | Tombstone GC for local-only libraries | 6a | Medium, sync semantics |

Slice A is built first, and is the only slice this worktree delivers. Measuring
before optimizing is the house rule, and a shipped measurement surface makes
B through E verifiable rather than merely assertable.

### Item 6b moves to its own issue

"Stop minting per-sample tombstones where a per-dive one would do" is a
wire-format change, not a refactor. `deletion_log` is
`(id, entityType, recordId, deletedAt, hlc)`
(`lib/core/database/database.dart:2934`) with a v114 uniqueness index on
`(entityType, recordId)` and no scope or parent column. A "delete every
`tankPressureProfiles` row for dive X" tombstone requires either a new column
plus a main-database schema bump and a matching wire change, or a synthetic
`entityType` convention that every apply-side consumer must learn to expand into
a `WHERE dive_id = ?` delete. Older peers can interpret neither, so it needs a
schema floor gate of the kind PR #1348 established.

The one existing precedent, `clearReviewForDive`
(`safety_findings_repository.dart:262`), works only because
`diveSafetyReviews` is itself keyed on `diveId`. It does not generalise.

With slice E landed, the remaining cost is write amplification rather than
storage: `logDeletion` (`sync_repository.dart:980`) issues an HLC and opens a
transaction per row. A batching `logDeletions` would fix that without touching
the wire format, and belongs with 6b.

### Two categories are never swept, in any slice

- **Documents-root exports.** `saveAndShareFile` and `saveAndShareFileBytes`
  (`lib/core/services/export/shared/file_export_utils.dart:24,49`) leave a file
  permanently in the root of `getApplicationDocumentsDirectory()`. That
  directory also holds the database
  (`lib/core/services/database_location_service.dart:133`) and, on iOS, is
  visible to the user in the Files app. Deleting a user's exported logbook
  because it looked like debris is not acceptable.
- **Backup files.** Every one is a full copy of the database. Slice D surfaces
  orphans and offers an action; it never deletes on its own.

Both are measured and shown. Neither is ever reclaimed without a user action.

### `kDiskCacheCapBytes` is deleted rather than implemented

`lib/features/media/data/network_cache_config.dart:35` declares a 500 MB disk
cap, has a unit test asserting its own value
(`test/features/media/data/network_cache_config_test.dart`), and is wired to
nothing. `flutter_cache_manager` 3.4.1 exposes `maxNrOfCacheObjects` and
`stalePeriod` but no byte cap, so honouring the constant means a custom
`BaseCacheManager` with hand-rolled eviction. A named cache manager also
relocates the cache directory, orphaning the existing `DefaultCacheManager`
folder.

Decision: in slice B, delete the constant and its self-referential test, keep
`DefaultCacheManager`, and let the Storage usage page report the directory's
real size next to the clear button that already works
(`lib/features/media/data/services/cached_network_image_diagnostics.dart:71`).
This states honestly what is enforced instead of shipping a number that is not.

## Slice A design

### Architecture

The sweep in slice C and the page in slice A need the same knowledge: for each
place bytes accumulate, where it is, how large it is, and how it can be
reclaimed. Written twice, the two drift the first time a fourteenth cache is
added.

`StorageCategory` is therefore a plain descriptor, not a task. Slice A ships the
measurement half only. Slice C extends the same descriptors with a reclaim
policy. Nothing speculative is built now.

This is deliberately not the abandoned `StartupMaintenanceRunner`. That was a
scheduler with a convergence ledger and splash progress UI. This is a list of
places bytes live, consumed by a page. The distinction is worth keeping in mind
for anyone who reads the abandonment note and wonders whether it was reversed.

### Why measurement is per-category rather than one directory walk

Measurement cost is uneven by an order of magnitude, and the existing code
already says which is which:

| Strategy | Cost |
| --- | --- |
| `MediaCacheStore.totalBytes(kind)` (`lib/features/media_store/data/media_cache_store.dart:240`) | `SUM` over an index, instant |
| `TileCacheService.getTotalCacheSize()` (`lib/features/maps/data/services/tile_cache_service.dart:387`) | FMTC-native |
| `CachedNetworkImageDiagnostics.cacheSize()` (`cached_network_image_diagnostics.dart:41`) | Recursive `dart:io` walk |
| Thumbnails, `staging/`, `transcode/`, temp, backups | Recursive walk |
| Database files | `File.length()` |

A single blocking "compute total storage" call would be paced by its slowest
member. Each category brings its own strategy, and the page renders each result
as it arrives.

### The `StorageCategory` contract

```dart
/// One place on disk where the app accumulates bytes.
class StorageCategory {
  const StorageCategory({
    required this.id,
    required this.group,
    required this.measure,
  });

  /// Stable across releases: it keys the l10n label, the size provider, and
  /// the reclaim policy slice C adds. Never derive it from a directory name.
  final String id;

  final StorageGroup group;

  /// Null means genuinely unmeasurable, which is not the same as zero.
  final Future<int?> Function() measure;
}
```

`measure` returns `Future<int?>`. The nullable return carries real information
in exactly one case today: on Android SAF the backup target is a `content://`
tree URI with no `Directory` to enumerate
(`lib/features/backup/data/services/backup_service.dart:1258`). Reporting
"0 bytes of backups" there would be a lie, and a user acting on that lie would
conclude their backups had vanished.

### Categories

| Group | id | Location | Measurement |
| --- | --- | --- | --- |
| App data | `database` | Main database plus `-wal` and `-shm` | `File.length()` |
| App data | `localCache` | `submersion_local.db` (`lib/core/services/local_cache_database_service.dart:49`) | `File.length()` |
| Media cache | `mediaCacheOriginals` | `media_cache/originals` | `totalBytes(original)` |
| Media cache | `mediaCacheThumbs` | `media_cache/thumbs` | `totalBytes(thumb)` |
| Media cache | `mediaCacheRenditions` | `media_cache/renditions` | `totalBytes(rendition)` |
| Media cache | `mediaCacheStaging` | `media_cache/staging` | Walk |
| Media cache | `mediaCacheTranscode` | `media_cache/transcode` | Walk |
| Caches | `mapTiles` | FMTC store | `getTotalCacheSize()` |
| Caches | `networkImages` | `DefaultCacheManager` directory | `cacheSize()` |
| Caches | `videoThumbnails` | `Submersion/video_thumbnails` | Walk |
| Caches | `pdfThumbnails` | `Submersion/pdf_thumbnails` | Walk |
| Backups | `backups` | Resolved backups directory | Walk, or null on SAF |
| Temporary | `temporary` | `<temp>/picked` and loose share files | Walk |
| Exports | `exports` | Loose files in the Documents root | Non-recursive listing |

Fourteen categories. `staging` and `transcode` are listed separately from the
three indexed media-cache pools on purpose: the LRU caps in `MediaCacheStore`
(2 GiB, 256 MiB, 1 GiB) are enforced only over rows in `media_cache_entries`,
and neither subdirectory is indexed. Their bytes are invisible to the 3.25 GiB
budget today, and showing them as their own rows is what makes that visible.

`exports` excludes the database files and the `Submersion/` subtree. It is a
non-recursive listing because the Documents root is the only level where the
loose export files land.

### Providers

```dart
/// The descriptor list. Plain Provider: construction is pure.
final storageCategoriesProvider = Provider<List<StorageCategory>>(...);

/// One future per category, keyed by StorageCategory.id.
final storageCategorySizeProvider =
    FutureProvider.family<int?, String>((ref, id) => ...);
```

A family keyed by id rather than a single future over the whole list is what
gives each row independent loading, and what stops one throwing category from
blanking the page. A category whose measurement fails renders an error in its
own row.

The total is computed from the categories that have resolved. A partial total is
labelled as such rather than presented as final.

### UI

A new page at
`lib/features/settings/presentation/pages/storage_usage_page.dart`, routed in
`lib/core/router/app_router.dart` and reached from a tile on the existing
Storage settings page.

It is not appended to `storage_settings_page.dart`. That file is 754 lines
against the project's 800-line ceiling, and it has a single coherent
responsibility today (where the database file lives) that a disk-usage report
does not share.

Contents: grouped rows of label and size, a total, and a refresh action. The
page is entirely read-only. Nothing on it deletes anything.

An earlier draft of this section put trailing clear buttons on the two
categories that have working clear paths today. That was dropped during
implementation, for one concrete reason: `clearAllCache()`
(`lib/features/maps/presentation/providers/offline_map_providers.dart:285`)
resets the FMTC store **and** deletes every `cached_regions` row, so it is not
merely a cache clear. The offline maps page guards it with a confirmation
dialog; putting the same call behind a bare button on a usage page would be a
safety regression. Rather than ship one clear action with a confirmation and
one without, the slice ships neither and stays genuinely read-only.

Both actions remain reachable from the pages that own them:

- Map tiles: the "Clear cache" action on the offline maps page
- Network images: `NetworkCacheCard`
  (`lib/features/media/presentation/widgets/network_cache_card.dart`), mounted
  on the network sources page

A later slice may add reclaim actions here, with the confirmations each one
needs. That is a deliberate follow-up, not an oversight.

`_formatBytes` already exists privately at
`lib/features/settings/presentation/pages/sync_devices_page.dart:342`. It is
extracted to a shared formatter and both call sites use it, rather than a second
copy being written. Bytes are not a diver-facing unit, so the project rule about
respecting the active diver's unit settings does not apply.

### Localisation

Roughly twenty new keys: fourteen category labels, five group headings, and the
page title, plus strings for the unavailable and error states. All eleven ARB
files under `lib/l10n/arb/` get them, not only `app_en.arb`.

### Testing

Test-driven, tests before implementation.

**Measurement strategies** get plain `test()` cases against real temporary
directories, deliberately not `testWidgets`. Awaiting `dart:io` inside
`testWidgets` parks forever with no output and no timeout firing. Cases per
strategy: a populated directory, an empty directory, a directory that does not
exist, and for the SAF backup case, the null return.

**The page** gets widget tests with `storageCategorySizeProvider` overridden, so
no real I/O runs. States covered: all rows loading, all resolved, one row
unavailable, one row in error while its siblings resolve, and the partial-total
label.

Two known traps are designed against rather than discovered:

- The test font renders one em per glyph, so a `Row` of label plus size
  overflows at a 360px surface without `Flexible`. Every row is built with the
  label flexible from the start.
- The eleven-locale ARB fanout must be complete or `arb_parity_test` fails
  against every locale at once.

### Out of scope for slice A

No file is deleted that is not already deletable through existing UI. No cap is
changed. No sweep is scheduled. No startup code is touched at all.

## Slices B through E

Designed here so each can be executed without re-deriving the analysis. Each
gets its own worktree and its own PR.

### Slice B: wire the caps that already exist

1. **`TileCacheService.removeOldTiles(Duration)`**
   (`tile_cache_service.dart:373`) has zero callers in `lib/` or `test/`. Call
   it, and give the FMTC store the `maxLength` that `_store!.manage.create()`
   (`:131`) currently omits. Note that `FMTCTileProvider` also receives no
   `cachedValidDuration`, so browsed tiles have neither a cap nor a TTL.
2. **`kDiskCacheCapBytes`**: delete the constant and its test per the decision
   above.
3. **`MediaCacheStore.evictIfNeeded()`** (`media_cache_store.dart:249`) is
   public but called only from inside `put()` (`:161`). A store that is over cap
   and idle stays over cap. Call it once per launch. The natural seam is the
   media store runtime rather than `startup_page.dart`, since building
   `mediaStoreRuntimeProvider` is already the drain trigger and already awaits a
   once-per-process reclaim (`mediaTransferQueueReclaimProvider`,
   `lib/features/media_store/presentation/providers/media_store_providers.dart:107`).

Also worth fixing here, found during exploration and not in the audit: deleting
an offline region removes the `cached_regions` row but no tiles
(`offline_map_providers.dart:263`, whose doc comment claims otherwise), and the
per-region `sizeBytes` shown in the UI is a fabricated estimate,
`downloadedTiles * 20 * 1024` (`offline_map_providers.dart:143`), not a
measurement.

### Slice C: scratch-file sweep

A `StorageScratchSweep` class following the `MediaOrphanBacklogSweep` shape
exactly: small, self-contained, constructed inline, fired `unawaited` in a
swallow-and-log wrapper next to the existing sweep at `startup_page.dart:686`.
Guarded by a prefs timestamp, because a filesystem walk is not a cheap indexed
`SELECT`. A daily cadence, following `shouldAutoScan`
(`lib/features/media/data/services/repair/watched_folder_scanner.dart:16`),
which is the closest existing analogue: a filesystem traversal gated by a
per-device stamp. Copy its future-clock defence as well, so a device whose clock
jumps forward does not stop sweeping until the clock catches up.

Targets, all of which are debris with no user value:

- `<temp>/picked/*` (`lib/core/services/files/picked_file_materializer.dart`):
  full copies of SAF-picked files including large ZIP archives. The only
  reference to `'picked'` in the tree is the write site.
- `media_cache/staging/*` older than a safety age: any staged file whose `put()`
  never completed.
- `media_cache/transcode/*.tmp`, and `.mp4` renditions with no live queue row.
  `deleteTranscodeArtifacts()` runs only on video uploads that reach `markDone`
  (`lib/features/media_store/data/media_upload_pipeline.dart:239,293`), so an
  abandoned upload leaves a full-size video forever.
- Orphaned video and PDF thumbnails whose source file no longer exists. Both
  services key on content plus mtime
  (`video_thumbnail_service.dart:139`, `pdf_thumbnail_service.dart:139`), so
  editing or moving a file orphans its old thumbnail permanently, and the only
  existing `delete()` is a corrupt-entry self-heal.
- Loose share temp files (`media_share_temp_file.dart:17` writes flat into the
  temp root and nothing removes it; `certification_share_sheet.dart:113,155`
  likewise, though its deterministic filenames make it bounded).

Not targeted: Documents-root exports and backup files, per the scope decision.

The age guard matters more here than in the media sweep, because a file being
written concurrently must never be swept mid-flight.

### Slice D: orphaned backup files

`pruneOldBackups` (`backup_service.dart:1076`) and the pre-migration
`_retainN = 3` prune (`pre_migration_backup_service.dart:250`) are both driven
off the SharedPreferences history list.
`getValidatedBackupHistory()` (`:986`) drops records whose file has vanished,
but nothing removes a file whose record vanished. Prefs reset, reinstall over a
preserved Documents directory, or a crash between write and `addRecord` all
produce a `.db` or `.sbe` that is invisible to every prune path and permanent,
each one a full copy of the database.

The only directory listing in the whole feature is `_sweepTempFiles`
(`pre_migration_backup_service.dart:265`), which matches hidden `.db.tmp` files
only.

Slice D adds a listing that cross-references the directory against the history
list and surfaces orphans in the Storage usage page with an explicit prune
action. It does not delete on its own. Two platform cases need care: Android SAF
has no `Directory` to list, and custom locations on Apple platforms need the
security-scoped bookmark lease (`resolveBackupsDirectoryLeased`, `:1166`).

Backup retention counts are out of scope here; they belong to issue #1376.

### Slice E: tombstone GC for local-only libraries

Reach `clearAcknowledgedDeletions` when sync is not configured, using the
existing `SyncLiveness.gcFloorMillis` 30-day floor and the existing
`TombstoneGcDecision.unbounded()`.

The gate must be precise. A device that has never synced can safely purge
tombstones, because a peer joining later adopts a full base publish rather than
replaying our log. A device that *has* synced and then went local-only must not
purge, because peers still need its tombstones to converge. So the condition is
"no provider configured and no prior sync has ever occurred", evidenced by the
absence of peer cursors, not merely "sync is currently off".

This is the whole of item 6. Item 6b is a separate issue.

## Rejected

- **Reviving `StartupMaintenanceRunner`.** Abandoned twice on record. This
  problem needs a description of where bytes live, not a scheduler with a
  convergence ledger.
- **Periodic `VACUUM` of the main database.** Measured on the development
  database: `freelist_count` is 0 and `VACUUM INTO` recovers 1.21 MB, 4.3%. Not
  worth an exclusive lock contended by the UI isolate and the Workmanager
  headless one. The real database cost is the profile sample schema, tracked
  separately.
- **A custom `BaseCacheManager` for the network image byte cap.** See the
  `kDiskCacheCapBytes` decision above.
- **Sweeping Documents-root exports or backup files.** See the scope decision.

## Related

- #1376: backup retention counts and raw dive computer data discard.
- Profile sample storage, the majority of database bytes, is a separate schema
  change tracked on its own.
