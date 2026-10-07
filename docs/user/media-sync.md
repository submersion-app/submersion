# Media Sync

[Multi-Device Sync](multi-device-sync.md) keeps your *logbook* the same on every
device &mdash; dives, sites, buddies, gear. What it does not carry is the
photos and videos themselves. A photo linked from your phone's gallery is
stored as a pointer to that gallery; a photo linked from a folder on your Mac
is stored as a path. Neither pointer means anything on another device.

**Media Sync** closes that gap. Connect a storage backend and Submersion keeps
a copy of each photo and video in cloud storage *you* control, then serves
those copies to your other devices on demand. It is entirely optional, off by
default, and configured separately from Cloud Sync.

> [!TIP]
> <strong>In the app this lives under Settings &rarr; Data &rarr; Photos &amp;
> Media &rarr; Media Storage.</strong> "Photos &amp; Media" splits into two ideas: <em>where
> photos come from</em> (your gallery, files, URLs &mdash; see
> [Marine Life &amp; Photos](marine-life-and-photos.md)) and <em>where
> copies are kept</em>, which is this page.

## What Media Sync Solves

Without a media store, photos behave differently depending on where you linked
them from:

| Source | Visible on other devices? |
|--------|---------------------------|
| Photo library (gallery) | Only if the same photo exists in that device's library and can be matched |
| Local files (desktop paths, bookmarks) | No &mdash; the file does not exist there |
| Network URLs and manifest feeds | Yes &mdash; the source is already a URL |

With a media store connected, the first two rows change: the bytes live in your
storage, so any device signed in to the same store can show the photo &mdash;
including a device that never had the original.

Nothing about how you link photos changes. Rows keep their original source
type, so if you later disconnect the store, every photo simply goes back to
behaving exactly as it did before.

## Choosing a Provider

Media Sync supports four backends. Pick one per device library; all your
devices should point at the same one.

| Provider | Where files land | Notes |
|----------|------------------|-------|
| **S3-compatible** | A bucket you own (AWS S3, Backblaze B2, MinIO, Wasabi, …) | Most control; you supply endpoint, bucket and keys |
| **Dropbox** | Your Dropbox app folder | Reuses the Dropbox connection from Cloud Sync |
| **Google Drive** | This app's private Drive space | Signs in with Google; files are not visible in your normal Drive |
| **iCloud** | This app's iCloud container | Apple platforms only; travels with your Apple ID |

The media store is configured **independently of Cloud Sync**. You can sync
your logbook over iCloud and store media in S3, or run media storage with no
database sync at all.

## Connecting

1. Go to **Settings &rarr; Data &rarr; Photos & Media &rarr; Media Storage**.
2. Pick a provider with the **Provider** selector.
3. For **Dropbox**, **Google Drive** or **iCloud**, tap **Connect &lt;provider&gt;**
   and complete the sign-in. There is nothing else to fill in.
4. For **S3**, fill in the endpoint, bucket, access key and secret. Optional
   fields (region, key prefix, path-style addressing) live under **Advanced**;
   the region is derived from the endpoint when you leave it blank, and the
   prefix defaults to `submersion-media/`.
5. Use **Test connection** to check credentials before saving, then **Save**.

> [!TIP]
> <strong>Already using S3 for Cloud Sync?</strong> A <strong>Copy settings from
> Sync</strong> button appears on the S3 form and fills in the endpoint, bucket
> and keys from your sync configuration. The key prefix stays
> <code>submersion-media/</code> so media keeps its own namespace even inside a
> shared bucket.

When the store is connected the page shows **Connected to &lt;store&gt;** and
swaps the credential form for the controls described below. Repeat the connect
step on each of your devices &mdash; pointing them at the same bucket or account
makes them one media library.

> [!WARNING]
> <strong>Media storage is per-device, on purpose.</strong> The connection is not
> part of your synced database and is not carried by a backup restore, so a new
> device always asks you to connect it explicitly.

## What Gets Uploaded

Once connected, Submersion uploads a **thumbnail first**, then the full-size
copy. Thumbnails are small (512 px, JPEG) so a second device can populate its
photo grids long before the originals finish transferring.

Only media that belongs to your logbook is uploaded &mdash; a photo must be
linked to a **dive** or a **dive site**. Photos that are still unfiled, and
photos that came from network URLs or manifest feeds (already reachable by URL
everywhere), are left alone.

- **Upload photos automatically** &mdash; on by default. New photos are queued as
  you add them.
- **Upload existing library** &mdash; queues everything already in your logbook
  that has not been uploaded yet, newest dives first. Run this once after
  connecting.

## Upload Quality

By default Submersion uploads your **original** files. If you would rather trade
some fidelity for storage cost and bandwidth, set a compression level for photos
and video separately.

| Level | Photos | Video |
|-------|--------|-------|
| **Original** | Untouched file | Untouched file |
| **High** | Long edge 3072 px, JPEG q90 | 1080p, ~8 Mbps |
| **Balanced** | Long edge 2048 px, JPEG q85 | 720p, ~4 Mbps |
| **Small** | Long edge 1280 px, JPEG q75 | 480p, ~1.8 Mbps |

Two rules keep this predictable:

- **A compressed level replaces the original.** At any level other than
  Original, the compressed version is what gets uploaded and the full-resolution
  file never leaves the device. This is exactly what the app warns about on the
  settings page.
- **Files already under the ceiling upload untouched.** A 1600 px photo at the
  *Balanced* level is uploaded as-is rather than re-encoded, so compression can
  never make a file bigger or add a second generation of loss. Video applies the
  same idea to both resolution and bitrate.

> [!WARNING]
> <strong>Quality is a library-wide setting and it syncs.</strong> Unlike the
> bandwidth switches, upload quality is shared across your devices &mdash; because
> it decides what your library permanently contains, not what one device may
> spend. Change it in one place and every device follows.

Video compression uses your platform's native encoder (AVFoundation on Apple
devices, Media3 on Android, Media Foundation on Windows, `ffmpeg` on Linux). A
device without a working encoder uploads originals instead and says so under the
Video dropdown; on Linux, installing `ffmpeg` enables it.

## Transfers

**Media Storage &rarr; View transfers** shows the queue. Each row is one item:

| State | Meaning |
|-------|---------|
| **Waiting** | Queued, not started &mdash; or deferred by a network policy |
| **Uploading** | In flight, with a progress bar for large files |
| **Removing from cloud** | Deleting a copy for media you removed |
| **Done** | Finished |
| **Failed** | Gave up after retries; the error is shown on the row |

Failed rows offer **Retry**. Retries also back off automatically, so a row
carrying an error may sit in *Waiting* for a while &mdash; tapping Retry skips
the wait. **Clear completed** (the toolbar icon) tidies finished rows.

Photo tiles carry a small badge while a transfer is pending, running, or failed,
and a cloud-off badge for items with no cloud copy. Items that are safely backed
up show nothing at all.

Large files resume rather than restart: an upload interrupted by a lost
connection or a closed app picks up from the last completed chunk.

## Data Use

Two switches on the Media Storage page control what this device spends. They are
**per-device** &mdash; each phone, tablet and computer keeps its own answer.

- **Upload photos automatically** &mdash; turn off to stop queueing new work on
  this device. Anything already queued stays queued.
- **Upload photos on cellular** &mdash; on by default. Turn it off to hold photo
  uploads until Wi-Fi.

Videos are never uploaded over a cellular connection; they wait for an unmetered
network. Going offline pauses the queue entirely and it resumes on its own when
the connection returns.

## On Your Other Devices

Nothing is bulk-downloaded. A device fetches from the store only when it needs
to display something it cannot resolve locally, and it prefers the cheapest
option available: the **thumbnail** for grids, then the **original**, then the
**compressed rendition**.

Fetched files are cached on the device with generous limits &mdash; roughly 2 GB
of originals, 1 GB of renditions and 256 MB of thumbnails &mdash; and the
least-recently-used files are evicted when a pool fills. Downloaded originals are
verified against their content hash, so a truncated or corrupted transfer is
discarded rather than shown.

## Deleting Photos and Dives

Cloud copies follow your logbook:

- **Unlink or delete a photo** and its stored copy is queued for removal.
- **Delete a dive** and the photos that belonged only to that dive go with it.
  Photos also linked to a dive site survive, and library-level media (URL and
  manifest imports) is never removed by a dive deletion.
- Because storage is content-addressed, a copy is only deleted when **no
  remaining photo** in your library references those same bytes.

Deletions ride the same transfer queue as uploads &mdash; they show as *Removing
from cloud* &mdash; and are exempt from the cellular rules, since they are tiny
API calls with no payload.

## Verify Library

**Verify library** reconciles what is in your storage against what your logbook
expects, and reports what it did:

- **Orphans removed** &mdash; stored files nothing in your library points at any
  more (most often left over from before deletion tracking existed).
- **Repairs queued** &mdash; photos your logbook believes are uploaded but which
  are missing from storage; if the device still holds the file, it is re-queued.
- **Stale uploads aborted** &mdash; abandoned partial uploads. On S3 these are
  invisible in a normal bucket listing but still billable, so this is worth
  running at least once.

Submersion also runs this quietly in the background when no device has verified
in the last 30 days and the current device is on an unmetered connection. Recent
files are given a grace period so an upload still in flight is never mistaken for
an orphan.

## Disconnecting

**Disconnect** stops this device uploading and fetching. It does **not** delete
anything from your bucket or account, and it does not affect your other devices.
Photos on this device fall back to their original behavior &mdash; gallery photos
resolve from the gallery, local files from disk, and anything that only existed
in the store shows a placeholder.

Reconnecting the same storage later picks the library straight back up.

## What Lands in Your Storage

For the curious (and for anyone auditing a bucket), Submersion writes a single
namespace under your configured prefix:

| Key | Contents |
|-----|----------|
| `smv1/store.json` | Store identity marker, written when you first connect |
| `smv1/objects/<aa>/<hash>.<ext>` | Full-size originals |
| `smv1/renditions/<aa>/<hash>.<ext>` | Compressed versions, when a quality level is set |
| `smv1/thumbs/<aa>/<hash>.jpg` | 512 px thumbnails |

`<hash>` is the file's SHA-256 and `<aa>` its first two characters, used to
spread objects across prefixes. Identical files therefore share one object, no
matter how many dives or devices reference them.

> [!TIP]
> <strong>Want this encrypted too?</strong> End-to-end encryption currently covers
> the sync and backup channel &mdash; see [Encrypted Sync](encrypted-sync.md). For media, keep the bucket private and the credentials tightly scoped.

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| Nothing queues after connecting | Photos are not yet linked to a dive or site, or **Upload photos automatically** is off. Run **Upload existing library** |
| Queue stuck on *Waiting* | Offline, or a cellular policy is deferring the work. Videos always wait for an unmetered connection |
| Photos show cloud-off badges on a second device | That device has not been connected to the media store yet |
| Transfers stop after a bucket change | The store identity marker no longer matches; reconnect to adopt the new store |
| Repeated failures on one item | Open **Transfers** and read the row's error; **Retry** also clears the cached "cannot resolve this file" result |
| Storage bill larger than the library | Run **Verify library** &mdash; it removes orphans and aborts stale multipart uploads |

## See also

- [Marine Life & Photos](marine-life-and-photos.md) &mdash; linking photos to dives and where they come from
- [Multi-Device Sync](multi-device-sync.md) &mdash; syncing the logbook itself
- [Encrypted Sync](encrypted-sync.md) &mdash; end-to-end encryption for sync and backups
- [Backup & Restore](backup-and-restore.md) &mdash; snapshots of your database
- [Settings](settings.md) &mdash; the full settings reference
