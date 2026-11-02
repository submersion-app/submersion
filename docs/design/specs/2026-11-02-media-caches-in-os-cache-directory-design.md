# Media caches in the OS cache directory on phones

Issue: #3341. Release: v1.8.4.

## Why

The media caches live in application support, which phones treat as data the
app wants to keep. Since #3337 the thumbnail pool holds a thumbnail for every
linked local photo, and its cap is a setting that goes up to 16 GB, so this is
no longer a small amount of disk.

- Android's "Clear cache" does not touch them. Only "Clear storage" does, and
  that removes everything else the app has stored on the device too.
- iOS never reclaims them when the device runs short of space.
- They go into iOS device backups, and into Android Auto Backup, which has a
  25 MB limit per app. An app over the limit is not backed up at all.

Everything in these caches can be made again or fetched again, so the operating
system should be allowed to treat them as caches.

## Goals

On iOS and Android:

1. The thumbnail, original and compressed copy pools, the video poster frames
   and the PDF page renders live under the OS cache directory.
2. Nothing regenerable is left in the old location after an upgrade, and an
   upgrade does not cost the diver their existing caches.
3. The app keeps working when the OS empties that directory, whether or not the
   app is running. Missing files are made again or fetched again on the next
   view. Index rows whose file has gone stop counting against the caps: at once
   when a whole pool has gone, and within a day when only some files have.
4. The disk cache size setting and the "Empty cache" button behave as they do
   now.

## Non-goals

- Desktop. There is no system "clear cache" there, and the current location is
  where users would look. Paths and behaviour do not change.
- Backup rules or exclusions. No Android backup rules, and no
  `NSURLIsExcludedFromBackupKey`. `staging`, `transcode` and
  `submersion_local.db` remain in application support and therefore in device
  backups. They are small or short-lived.
- Any new UI, setting or copy.
- Moving the `libCachedImageData` or map tile caches. They are already in the
  OS cache directory.

## Anti-goals

- A purge must never lose work in progress. An upload in flight or a finished
  video transcode waiting on a retry stays out of the OS's reach.
- A purge of a whole pool must never cause real files to be evicted to make room
  for files that no longer exist.
- Saving a thumbnail must not get slower as the pool grows. A pool at its cap is
  the normal state for a large library, and every `put` evicts, so nothing on
  that path may check files row by row.
- Desktop must not gain any new startup or sweep work.

## Decisions

Made by the maintainer:

- **Which caches move:** `thumbs`, `originals`, `renditions`, `video_thumbnails`
  and `pdf_thumbnails`. `staging` and `transcode` stay in application support.
- **Upgrade:** existing caches are moved to the new location with a directory
  rename rather than deleted, so a diver does not regenerate thumbnails or
  download originals again. If a rename fails, the old directory is deleted.
  This goes further than the issue, which only required deletion.

## Layout

| Directory | iOS and Android | Desktop (unchanged) |
| --- | --- | --- |
| `thumbs`, `originals`, `renditions` | `<cache>/Submersion/media_cache/` | `<support>/Submersion/media_cache/` |
| `video_thumbnails`, `pdf_thumbnails` | `<cache>/Submersion/` | `<support>/Submersion/` |
| `staging`, `transcode` | `<support>/Submersion/media_cache/` | `<support>/Submersion/media_cache/` |

`<cache>` is `getApplicationCacheDirectory()`, which the map tile cache already
uses. On these platforms path_provider maps it to `Library/Caches` and
`Context.getCacheDir()`.

`staging` and `transcode` staying behind needs no special handling for
`MediaCacheStore.put`. Application support and the cache directory share a
volume on both phones, so a staged file still moves in with a rename, and `put`
keeps its existing copy fallback.

## Design

### One source of truth for the location

A small helper in `lib/core/services/storage/` decides where regenerable caches
live. It takes the platform decision and the two directory lookups as
parameters, so tests need neither a real phone nor path_provider. Every reader
goes through it: `mediaCacheRoot()`, the video and PDF `cacheDir` closures, the
storage inventory and the scratch sweep.

It is memoized for the process, like `mediaCacheRoot()` today, and a failed
lookup is not cached.

### MediaCacheStore

`MediaCacheStore` gains an optional scratch root alongside `root`:

- `root` remains where the pools are, so `relativePath` values in
  `media_cache_entries` keep their current form (`thumbs/ab/abc.jpg`) and rows
  stay valid across the move.
- `stagingFile()`, `transcodeFile()` and `deleteTranscodeArtifacts()` use the
  scratch root, which defaults to `root`, so the many existing tests and desktop
  need no change.

`openMediaCacheStore` passes both. `mediaCacheRoot()` keeps its name and returns
the pools root; the scratch root gets its own resolver.

### Upgrade

Moving runs inside the memoized location lookup, so it finishes before any
caller gets a path and nothing can write to the new location first. On phones,
for each of the five directories:

1. If the old directory does not exist, nothing to do. This is the normal case
   on every launch after the first, at the cost of five stats.
2. Create the destination's parent and rename the directory.
3. If the rename fails (for example the destination already exists and is not
   empty), delete the old directory without waiting for it, since a recursive
   delete of a large pool is not fast and this path must not hold up a lookup.

A failure in any step is logged and never surfaces: caches are not worth failing
a lookup for. An old directory that survives is retried on the next launch.

If the old pool ends up deleted, its index rows are left dangling and the
cleanup below removes them.

### Purges

Existing behaviour already covers the file side. `peekThumb` and `get` treat a
missing file as a miss, `get` drops the dangling row, `put` and the video and
PDF services recreate their directories, and `_evictPool` tolerates a missing
file.

Two additions cover the index side. Eviction itself does not change: it still
walks a pool oldest first, which is why a purge of a whole pool would mostly heal
on its own, since every file written after the purge is newer than every dead
row. What it cannot do alone is report true sizes, and it would take a long time
to work through the dead rows.

**A pool whose directory has gone has no entries.** `totalBytes` is the one place
that adds up a pool, and both eviction and the Storage usage page read it. If the
pool's directory does not exist, it deletes that pool's rows in a single statement
and returns 0. That is one stat and no row-by-row work, so it is safe on the `put`
path, and it fixes Android's "Clear cache" and any purge that takes the whole
directory immediately, including while the app is in the background and on the
very next look at the Storage usage page. A device restored from a backup, where
the index came back but the caches did not, is the same case. It is correct on
every platform, so desktop gets it too, at the cost of one stat per `put`.

**Daily cleanup for partial purges.** A new device sweep in `StorageGcCoordinator`
removes rows whose file is gone, for all three pools, one by one. It runs only on
phones, so desktop gains no work. It lives there rather than in
`mediaCacheEvictionProvider` because that provider runs only when a media store
is attached, and a diver with local photos only has a full thumbnail pool too. It
follows the coordinator's existing daily cadence: this PR does not change the
coordinator, and a resume within a day of the last pass does not run it.

The sweep:

- Reads rows in pages, selecting only what it needs, and checks each file with
  an awaited async stat, so a pool of hundreds of thousands of rows does not
  block a frame. The local cache database runs on its own isolate.
- Does nothing on a dry run and returns `ScratchSweepReport.empty` in all cases.
  Removing a row reclaims no bytes, so the cleanup summary must not claim any.
- Follows the coordinator's existing failure handling: a throw is logged and
  retried.

### Inventory and scratch sweep

- `StorageInventory`: the `video_thumbnails` and `pdf_thumbnails` rows measure the
  new location. `staging` and `transcode` keep measuring application support.
- `StorageScratchSweep`: the age sweep of `video_thumbnails` and `pdf_thumbnails`
  follows them to the new location. `staging` and `transcode` stay where they are.
- `_measureTemporary` counts only `picked` and loose files at the temp root, and
  on phones that root is the cache directory. A `Submersion` subdirectory there is
  not counted, so nothing is double counted. A test pins this.

### Comments

- Correct the note on `LocalCacheDatabaseService`. Its reasoning is about iCloud
  Drive sync rather than device backup. Application support is included in device
  backups unless excluded, and no exclusion is set. It is still acceptable for
  that database, which is small.
- Update the class comment on `StorageScratchSweep`, the `MediaCacheStore`
  comments and `mediaCacheRoot()`, all of which describe a single root.

## Accepted edge cases

- **A partial purge, for up to a day.** If the OS removes some files and leaves the
  pool's directory, the dead rows keep counting until the daily cleanup. Sizes on
  the Storage usage page read high in that time, and eviction can remove a few of
  the oldest real files earlier than it needed to. They were next in line anyway,
  and the cost is regenerating them. Checking files on every over-cap `put` would
  close this gap, but at a cost paid constantly by every diver with a large library
  to fix something rare and cheap.
- **A purge while the app is open (Android).** A file can vanish between a tile
  finding it and drawing it, giving a broken-image tile until the next view. The
  window is very small, and scrolling away and back resolves it. No handling.
- **Viewing an original offline after a purge.** It cannot be fetched until the
  device is back online. The same is already true of an evicted original.
- **Downgrading.** An older build looks in application support, finds nothing,
  drops the index rows and regenerates. The moved files stay in the cache
  directory until the OS reclaims them.

## Platform claims to check

The issue asks for these to be confirmed on a device before relying on them.

| Claim | How |
| --- | --- |
| The cache paths resolve as described | Android emulator and iOS simulator |
| "Clear cache" and low-storage trimming empty the new location | Android emulator, using App Info and `pm trim-caches` |
| The app recovers after the directory is emptied, without and with the app open | Android emulator, and iOS simulator by emptying `Library/Caches` by hand |
| What each purge leaves behind: does the pool directory go, or stay empty? | Android emulator. If "Clear cache" leaves the directory, treating a missing directory as a whole purge does not fire and the design needs revisiting |
| iOS purges caches under pressure and leaves them out of device backups | Not testable on a simulator. Stays based on Apple's documentation |

If the emulator contradicts the design, that goes back to the maintainer rather
than being worked around.

Results, with a debug build of this work on an Android API 36.1 emulator and an
iOS 26.5 simulator, using files planted in the old location:

- **Paths and the upgrade move:** confirmed on both. All five directories moved
  to `cache/Submersion` on Android and `Library/Caches/Submersion` on iOS, and
  `staging` and `transcode` stayed in application support.
- **Android "Clear cache" (the App Info button) and `pm trim-caches`:** both
  remove the whole `Submersion` tree, directory included, with the app stopped or
  open, and the app stays running. So a missing directory does fire for these
  purges, which is what the design assumed.
- **Daily cleanup:** confirmed on Android. A dead row was dropped and a live row
  kept by the production wiring on launch.
- **Relaunch after emptying `Library/Caches` on iOS:** the app starts normally.
- **Not covered on a device:** regenerating real thumbnails after a purge, which
  needs a library of linked photos. Unit tests cover it, and it uses the same path
  as a first view of a photo. iOS purging and backup behaviour stays based on
  Apple's documentation.

## Left to the builder

- The helper's file and function names, and the name of the new sweep.
- The page size for the cleanup sweep.
- How tests inject the platform decision.
- Whether the new sweep's logic sits on `MediaCacheStore` or in its own class.

## Testing

- Location helper: phone and desktop paths, memoization, failed lookup not cached.
- Upgrade: move preserves files and leaves the index valid, a second run is a
  no-op, a rename failure deletes the old directory, `staging` and `transcode`
  are untouched, desktop does nothing.
- Store: pools under `root`, staging and transcode under the scratch root, `put`
  across the two roots, `clear` and "Empty cache".
- Pool directory gone: `totalBytes` returns 0 and deletes only that pool's rows,
  the other pools are untouched, a `put` afterwards starts from a true total, and
  no real file is evicted. A pool whose directory exists is left alone.
- Cleanup sweep: drops only dead rows across all pools, a dry run changes nothing,
  returns an empty report, and is not registered on desktop.
- Inventory and scratch sweep: read the new location on phones, the old on
  desktop, and the temp measurement does not include the new subtree.
