# Media Sync

[Multi-Device Sync](multi-device-sync.md) keeps your logbook the same on every
device: dives, sites, buddies, gear. What it does not carry is the photos and
videos themselves. A photo linked from your phone's gallery is stored as a
pointer to that gallery; a photo linked from a folder on your Mac is stored as a
path. Neither pointer means anything on another device.

**Media Sync** closes that gap. Connect a storage provider and Submersion keeps a
copy of each photo and video in cloud storage you control, then serves those
copies to your other devices on demand. It is optional, off by default, and set
up separately from Sync between devices.

> [!TIP]
> **In the app this lives under Settings > Data > Photos & videos.** The page
> covers two ideas: **Copies in the cloud**, which is this guide, and **Where
> photos come from** (your gallery, files, URLs; see
> [Marine Life & Photos](marine-life-and-photos.md)). **Guided setup:** step 4
> of [Set Up This Device](set-up-this-device.md) starts or joins the copies with
> sync and backups.

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

## Choosing an Account

Copies can live in any of these kinds of account. All your devices should use
the same one.

| Account | Where files land | Notes |
|---------|------------------|-------|
| **My own server** (S3) | A bucket you own (AWS S3, Backblaze B2, MinIO, Wasabi and others) | Most control; copies go in the `submersion-media/` folder of the bucket |
| **My own server** (WebDAV) | A folder on your server | Copies go in the server's `Submersion Media` folder |
| **Dropbox** | Your Dropbox app folder | |
| **Google Drive** | The app's private Drive space | Files are not visible in your normal Drive |
| **iCloud** | The app's iCloud container | Apple devices only; travels with your Apple Account |

Copies are set up independently of Sync between devices. You can sync your
logbook over iCloud and keep copies on your own server, or keep copies with no
database sync at all. The same account can do both: on your own server, sync and
copies each use a folder of their own.

## Setting Up

The quickest way is the **Set up this device** card on Settings > Data: its
photo step uses the account you chose for sync, and on a later device it joins
the copies your other devices keep. To set up copies on their own:

1. Go to **Settings > Data > Photos & videos**.
2. Under **Copies in the cloud**, tap **Set up**. The account list opens.
3. Choose one of your accounts, or add one under **Add an account**. An account
   that is not signed in on this device signs in first. On your own server, the
   copies folder is created with the account's keys; there is nothing else to
   fill in.

The row then reads **Copies in {account}**, with a status line underneath, and
the controls described below appear.

Your other devices learn which account holds the copies, without its
credentials. A device that is signed in to that account joins by choosing it the
same way: the copies already there are found and adopted, so there is nothing to
type. A device that is not signed in yet shows **Finish setting up this device**
on the page, and the setup card on Settings > Data and at the top of Settings
says the other devices keep copies there. The credentials themselves never leave
the device they were entered on.

### The status line

| Status | Meaning |
|--------|---------|
| **{copied} of {total} copied** | Everything this device can upload is in the cloud, or this many of it |
| **{copied} of {total} copied, {n} uploading** | Uploads are running |
| **Waiting for a connection** | Offline; uploads resume on their own |
| **{n} waiting to retry** | Uploads that failed and will try again |
| **Uploads paused: ...** | The account could not be checked, this device is no longer connected, or the account now holds different copies than this device joined (**Uploads paused: choose the account again**: tap **Copies in {account}** and choose the same account) |
| **Could not reach {account}** | The account could not be opened with this device's keys |
| **Finish setting up this device** | The library keeps copies this device has not joined yet. A device already keeping copies reports on its own copies instead, even when the library has since moved to another account; a line above **Copies in {account}** then says where the copies went, and choosing that account there follows the move |

## What Gets Uploaded

Once connected, Submersion uploads a thumbnail first, then the full-size copy.
Thumbnails are small (512 px JPEG), so a second device can fill its photo grids
long before the originals finish transferring.

Only media that belongs to your logbook is uploaded: a photo must be linked to a
**dive** or a **dive site**. Photos that are still unfiled, and photos from
network URLs or manifest feeds (already reachable by URL everywhere), are left
alone.

- **Upload new photos automatically:** on by default. New photos are queued as
  you add them.
- **Upload everything already attached** (under **Advanced**): queues everything
  already in your logbook that has not been uploaded yet, newest dives first.
  Run this once after setting up.

## Upload Quality

Under **Advanced**, **Upload quality** sets the level. By default Submersion uploads your original files. If you would rather trade
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

## Uploads

**Uploads** on the Photos & videos page shows the queue. Each row is one item:

| State | Meaning |
|-------|---------|
| **Waiting** | Queued and not started, or held back by a data-use setting |
| **Uploading** | In progress, with a progress bar for large files |
| **Removing from cloud** | Deleting the copy of media you removed |
| **Done** | Finished |
| **Failed** | Gave up after retries; the error is shown on the row |

Failed rows offer **Retry**. Retries also back off automatically, so a row with
an error may sit in Waiting for a while; tapping **Retry** skips the wait.
**Clear completed** tidies away finished rows. If this device and the account
no longer agree on which copies are in use, the page says **Uploads paused**,
and choosing the account again resumes them.

Photo tiles carry a small badge while a transfer is waiting, running or failed,
and a cloud-off badge for items with no cloud copy. Items that are safely backed
up show nothing.

Large files resume rather than restart: an upload interrupted by a lost
connection or a closed app picks up from the last completed chunk.

## Data Use

Two switches on the Photos & videos page control what this device spends. They
are per device: each phone, tablet and computer keeps its own setting.

- **Upload new photos automatically:** turn it off to stop queueing new uploads
  on this device. Anything already queued stays queued.
- **Use cellular data:** on by default. Turn it off to hold photo uploads until
  Wi-Fi.

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

## Verify the Copies

**Verify the copies** (under **Advanced**) compares what is in your storage with what your logbook
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
an orphan. When database sync runs through a Git repository, every orphan waits
the full seven days before it is removed: Git records each device's own clock,
so Submersion cannot be sure when other devices last synced.

**Export media report** (under **Advanced**) writes a report of your media and its storage, useful
for a bug report. The report lists file paths and device names; nothing is sent
anywhere.

## Changing the Account or Stopping

**Change** on the **Copies in {account}** row picks another account. The list
says what that does first: this device stops using the current copies and
starts or joins copies in the new account. Nothing is deleted from either.

The new account counts its own copies. Photos already copied to the old account
read as not yet copied there, and **Upload everything already attached** copies
the ones this device still has (in the gallery or on disk) across, including
any that had stopped retrying. Choosing the same account again (for example,
after it could not be reached) reconnects to the copies already there. If the
change cannot reach the new account, nothing changes and this device keeps
using the current copies.

Photos whose only copy is in the old account cannot be copied across: photos
kept only in the cloud, and gallery photos or local files removed from this
device after they were copied. After the change they show a placeholder on
this device, although the old account still holds them. When some photos are
kept only in the cloud, the list says how many before you confirm. To keep
them viewable, choose the old account again.

**Stop keeping copies on this device** (under **Advanced**) stops this device
uploading and fetching. It does not delete anything from your bucket or account,
and it does not affect your other devices.
Photos on this device go back to how they behaved before: gallery photos come
from the gallery, local files from disk, and anything that only existed in the
store shows a placeholder.

Choosing the same account again later picks the library straight back up.

## What Lands in Your Storage

For the curious (and for anyone auditing a bucket), Submersion writes one set of
folders under your chosen prefix:

| Key | Contents |
|-----|----------|
| `smv1/store.json` | The store's identity, written when copies are first set up |
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
| Nothing queues after setting up | Photos are not linked to a dive or site yet, or **Upload new photos automatically** is off. Run **Upload everything already attached**. |
| Queue stuck on Waiting | Offline, or a cellular setting is holding the work. Videos always wait for an unmetered connection. |
| Photos show cloud-off badges on a second device | That device has not joined the copies yet; on its Photos & videos page, tap **Set up** and choose the account. |
| **Uploads paused** after a bucket change | The copies' identity no longer matches; choose the account again to adopt the copies it holds now. |
| Repeated failures on one item | Open **Uploads** and read the row's error; **Retry** also clears a cached "cannot find this file" result. |
| Storage bill larger than the library | Run **Verify the copies**: it removes orphans and aborts stale partial uploads. |

## See also

- [Marine Life & Photos](marine-life-and-photos.md): linking photos to dives, and where they come from
- [Multi-Device Sync](multi-device-sync.md): syncing the logbook itself
- [Encrypted Sync](encrypted-sync.md): end-to-end encryption for sync and backups
- [Backups](backup-and-restore.md): snapshots of your database
- [Settings](settings.md): every setting
