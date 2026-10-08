# Media Sync

[Multi-Device Sync](multi-device-sync.md) keeps your logbook the same on every
device: dives, sites, buddies, gear. What it does not carry is the photos and
videos themselves. A photo linked from your phone's gallery is stored as a
pointer to that gallery; a photo linked from a folder on your Mac is stored as a
path. Neither pointer means anything on another device.

**Media Sync** closes that gap. Connect a storage provider and Submersion keeps a
copy of each photo and video in cloud storage you control, then serves those
copies to your other devices on demand. It is optional, off by default, and set
up separately from Cloud Sync.

> [!TIP]
> **In the app this lives under Settings > Data > Photos & Media > Media Storage.** Photos & Media covers two ideas: where photos come from (your
> gallery, files, URLs; see [Marine Life & Photos](marine-life-and-photos.md))
> and where copies are kept, which is this page. **Guided setup** on the Photos &
> Media page walks through both.

## What Media Sync Solves

Without a media store, photos behave differently depending on where you linked
them from:

| Source | Visible on other devices? |
|--------|---------------------------|
| Photo library (gallery) | Only if the same photo is in that device's library and can be matched |
| Local files (desktop paths, bookmarks) | No: the file does not exist there |
| Network URLs and manifest feeds | Yes: the source is already a URL |

With a media store connected, the first two rows change: the files live in your
storage, so any device connected to the same store can show the photo, including
a device that never had the original.

Nothing about how you link photos changes. Each photo keeps its original source,
so if you later disconnect the store, every photo goes back to behaving exactly
as it did before.

## Choosing a Provider

Media Sync supports four providers. All your devices should point at the same
one.

| Provider | Where files land | Notes |
|----------|------------------|-------|
| **S3** | A bucket you own (AWS S3, Backblaze B2, MinIO, Wasabi and others) | Most control; you supply the endpoint, bucket and keys |
| **Dropbox** | Your Dropbox app folder | Reuses the Dropbox connection from Cloud Sync |
| **Google Drive** | The app's private Drive space | Signs in with Google; files are not visible in your normal Drive |
| **iCloud** | The app's iCloud container | Apple devices only; travels with your Apple Account |

The media store is set up independently of Cloud Sync. You can sync your logbook
over iCloud and keep media in S3, or use media storage with no database sync at
all.

## Connecting

1. Go to **Settings > Data > Photos & Media > Media Storage**.
2. Choose a provider with **Provider**.
3. For Dropbox, Google Drive or iCloud, tap **Connect** for that provider and
   complete the sign-in. There is nothing else to fill in.
4. For S3, enter the endpoint, bucket, access key and secret. Optional fields
   (region, key prefix, path-style addressing) are under **Advanced**; the region
   is worked out from the endpoint when you leave it blank, and the prefix
   defaults to `submersion-media/`.
5. Use **Test Connection** to check the details, then **Save**.

> [!TIP]
> **Already using S3 for Cloud Sync?** **Copy settings from Sync** on the S3 form
> fills in the endpoint, bucket and keys from your sync settings. The key prefix
> stays `submersion-media/`, so media keeps its own space even in a shared
> bucket.

Once connected, the page shows that it is connected and replaces the sign-in
form with the controls described below.

Your other devices learn that the library has a media store, without its
credentials. Each of them shows **Finish setting up this device** at the top of
Settings, with an item to connect media storage; tap it and sign in, or enter the
same keys, to join the same media library. The credentials themselves never
leave the device they were entered on.

## What Gets Uploaded

Once connected, Submersion uploads a thumbnail first, then the full-size copy.
Thumbnails are small (512 px JPEG), so a second device can fill its photo grids
long before the originals finish transferring.

Only media that belongs to your logbook is uploaded: a photo must be linked to a
**dive** or a **dive site**. Photos that are still unfiled, and photos from
network URLs or manifest feeds (already reachable by URL everywhere), are left
alone.

- **Upload photos automatically:** on by default. New photos are queued as you
  add them.
- **Upload existing library:** queues everything already in your logbook that
  has not been uploaded yet, newest dives first. Run this once after connecting.

## Upload Quality

By default Submersion uploads your original files. If you would rather trade
some quality for storage cost and bandwidth, set a level for photos and for
video separately.

| Level | Photos | Video |
|-------|--------|-------|
| **Original** | Untouched file | Untouched file |
| **High** | Long edge 3072 px, JPEG quality 90 | 1080p, about 8 Mbps |
| **Balanced** | Long edge 2048 px, JPEG quality 85 | 720p, about 4 Mbps |
| **Small** | Long edge 1280 px, JPEG quality 75 | 480p, about 1.8 Mbps |

Two rules keep this predictable:

- **A compressed level replaces the original.** At any level but Original, the
  compressed version is what gets uploaded and the full-resolution file never
  leaves the device. The settings page warns about this.
- **Files already under the limit upload untouched.** A 1600 px photo at
  Balanced is uploaded as it is rather than re-encoded, so compression never
  makes a file bigger or adds a second round of loss. Video applies the same idea
  to both resolution and bitrate.

> [!WARNING]
> **Quality is a library-wide setting, and it syncs.** Unlike the data-use
> switches, upload quality is shared across your devices, because it decides
> what your library permanently contains, not what one device may spend. Change
> it in one place and every device follows.

Video compression uses your platform's own encoder (AVFoundation on Apple
devices, Media3 on Android, Media Foundation on Windows, `ffmpeg` on Linux). A
device without a working encoder uploads originals instead and says so under the
video setting; on Linux, installing `ffmpeg` enables it.

## Transfers

**View transfers** on the Media Storage page (or **Transfers** on the Photos &
Media page) shows the queue. Each row is one item:

| State | Meaning |
|-------|---------|
| **Waiting** | Queued and not started, or held back by a data-use setting |
| **Uploading** | In progress, with a progress bar for large files |
| **Removing from cloud** | Deleting the copy of media you removed |
| **Done** | Finished |
| **Failed** | Gave up after retries; the error is shown on the row |

Failed rows offer **Retry**. Retries also back off automatically, so a row with
an error may sit in Waiting for a while; tapping **Retry** skips the wait.
**Clear completed** tidies away finished rows. If this device and the store no
longer agree on which store is in use, the page says **Transfers paused**, and
reconnecting media storage resumes them.

Photo tiles carry a small badge while a transfer is waiting, running or failed,
and a cloud-off badge for items with no cloud copy. Items that are safely backed
up show nothing.

Large files resume rather than restart: an upload interrupted by a lost
connection or a closed app picks up from the last completed chunk.

## Data Use

Two switches on the Media Storage page control what this device spends. They
are per device: each phone, tablet and computer keeps its own setting.

- **Upload photos automatically:** turn it off to stop queueing new uploads on
  this device. Anything already queued stays queued.
- **Upload photos on cellular:** on by default. Turn it off to hold photo uploads
  until Wi-Fi.

Videos are never uploaded over a cellular connection; they wait for an unmetered
network. Going offline pauses the queue, and it resumes on its own when the
connection returns.

## On Your Other Devices

Nothing is downloaded in bulk. A device fetches from the store only when it
needs to show something it cannot find locally, and it takes the cheapest copy
that will do: the thumbnail for grids, then the original, then the compressed
version.

Fetched files are cached on the device with generous limits (about 2 GB of
originals, 1 GB of compressed versions and 256 MB of thumbnails), and the
least recently used files are dropped when a cache fills. Downloaded originals
are checked against their content hash, so a truncated or damaged transfer is
discarded rather than shown.

## Deleting Photos and Dives

Cloud copies follow your logbook:

- **Unlink or delete a photo** and its stored copy is queued for removal.
- **Delete a dive** and the photos that belonged only to that dive go with it.
  Photos also linked to a dive site stay, and media imported from URLs or
  manifests is never removed by deleting a dive.
- Because files are stored by their content, a copy is deleted only when no
  remaining photo in your library uses those same bytes.

Deletions go through the same transfer queue as uploads (they show as Removing
from cloud), and the cellular rules do not hold them back, since they carry no
file.

## Verify Library

**Verify library** compares what is in your storage with what your logbook
expects, and reports what it did:

- **Orphans removed:** stored files nothing in your library points at any more
  (most often left over from before deletions were tracked).
- **Repairs queued:** photos your logbook believes are uploaded but which are
  missing from storage; if this device still has the file, it is queued again.
- **Stale uploads aborted:** abandoned partial uploads. On S3 these do not show
  in a normal bucket listing but are still billed, so this is worth running at
  least once.

Submersion also runs this quietly in the background when no device has verified
in the last 30 days and this device is on an unmetered connection. Recent files
are given a grace period, so an upload still in progress is never mistaken for
an orphan.

**Export media report** writes a report of your media and its storage, useful
for a bug report. The report lists file paths and device names; nothing is sent
anywhere.

## Disconnecting

**Disconnect** stops this device uploading and fetching. It does not delete
anything from your bucket or account, and it does not affect your other devices.
Photos on this device go back to how they behaved before: gallery photos come
from the gallery, local files from disk, and anything that only existed in the
store shows a placeholder.

Reconnecting the same storage later picks the library straight back up.

## What Lands in Your Storage

For the curious (and for anyone auditing a bucket), Submersion writes one set of
folders under your chosen prefix:

| Key | Contents |
|-----|----------|
| `smv1/store.json` | The store's identity, written when you first connect |
| `smv1/objects/<aa>/<hash>.<ext>` | Full-size originals |
| `smv1/renditions/<aa>/<hash>.<ext>` | Compressed versions, when a quality level is set |
| `smv1/thumbs/<aa>/<hash>.jpg` | 512 px thumbnails |

`<hash>` is the file's SHA-256 and `<aa>` its first two characters, used to
spread files across folders. Identical files therefore share one copy, however
many dives or devices use them.

> [!TIP]
> **Want this encrypted too?** End-to-end encryption covers sync and backups (see
> [Encrypted Sync](encrypted-sync.md)), not media. For media, keep the bucket
> private and the credentials tightly scoped.

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| Nothing queues after connecting | Photos are not linked to a dive or site yet, or **Upload photos automatically** is off. Run **Upload existing library**. |
| Queue stuck on Waiting | Offline, or a cellular setting is holding the work. Videos always wait for an unmetered connection. |
| Photos show cloud-off badges on a second device | That device has not been connected to the media store yet; see **Finish setting up this device** in its Settings. |
| **Transfers paused** after a bucket change | The store's identity no longer matches; reconnect to adopt the new store. |
| Repeated failures on one item | Open **Transfers** and read the row's error; **Retry** also clears a cached "cannot find this file" result. |
| Storage bill larger than the library | Run **Verify library**: it removes orphans and aborts stale partial uploads. |

## See also

- [Marine Life & Photos](marine-life-and-photos.md): linking photos to dives, and where they come from
- [Multi-Device Sync](multi-device-sync.md): syncing the logbook itself
- [Encrypted Sync](encrypted-sync.md): end-to-end encryption for sync and backups
- [Backup & Restore](backup-and-restore.md): snapshots of your database
- [Settings](settings.md): every setting
