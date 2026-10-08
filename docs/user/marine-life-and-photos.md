# Marine Life and Photos

Record the creatures you encountered and the photos you took, side by side with your log data.

> [!NOTE]
> **Where to find it:** A dive's page has **Species** and **Photos** sections. **Species** and **Media** in the navigation list every species you have seen and every photo and video you have linked. The species catalog is under **Settings > Manage > Species**, and media settings under **Settings > Data > Photos & Media**.

<!-- screenshot: images/marine-life-and-photos/sighting.png: logging a sighting -->

---

## Marine life

### The species catalog

Submersion ships with a built-in catalog of 685 species, from reef fish to freshwater species for lake and river divers, organized into nine categories:

| Category | Examples |
|----------|----------|
| Fish | Grouper, angelfish, clownfish |
| Shark | Reef sharks, whale shark |
| Ray | Manta ray, eagle ray, stingray |
| Mammal | Dolphins, whales, sea lions |
| Turtle | Green, hawksbill, loggerhead |
| Invertebrate | Octopus, lobster, nudibranch |
| Coral | Hard coral, soft coral |
| Plant/Algae | Seagrass, kelp, algae |
| Other | Anything else |

Each entry carries a common name, optional scientific name, taxonomy class, description, and an optional reference photo. When an app update brings catalog changes, they are applied the next time you open Submersion. Built-in entries cannot be deleted, but you can add as many custom species as you like; **Reset to Defaults** restores the built-in entries if you have edited them.

### Adding a custom species

1. Open the catalog (**Settings > Manage > Species**, or **Manage catalog** on the Species page) and add a species.
2. **Look up online** searches iNaturalist by common or scientific name and fills in the details and a photo from the result. **Create without lookup** starts from a blank form.
3. Enter or correct the common name (required), scientific name, taxonomy class, description and category.
4. Save. The species is immediately available when you log a sighting.

If you later realize the identification was wrong, open the species and edit it. If a species you logged should be in the built-in catalog for everyone, **Suggest for the catalog** on its page sends the suggestion to the project.

### Logging a sighting on a dive

1. Edit the dive and open its **Experience** section.
2. Under **Marine Life**, tap **Add** and pick the species (**Select Species**); search by common or scientific name.
3. Set the **Count** (how many you saw, default 1) and any **Notes** (behavior, size, depth).
4. Save. The sighting appears in the dive's **Species** section.

You can add as many sightings as you like to a single dive.

> [!TIP]
> If you are not sure of the species, log it under **Other** and add a description in the notes. You can come back and update the species once you have confirmed the identification.

### The Species page

**Species** in the navigation lists every species you have seen. Search it, and sort by **Most sightings**, **Recently seen**, **First seen**, or **Name**. Open a species to see its **Sighting Statistics** (sightings, dives, first and last seen), **Top Sites**, **Sighting Period**, **Depth Range**, and every sighting.

A species page also gathers its **Photos**: **Tag photos** picks photos from that species' dives to tag with it, and **Add photos** links new ones.

### Species on dive sites

Each [Dive Sites](dive-sites.md) page has a **Species** section listing every species logged across all dives at the site, with a sighting count, plus the **Expected Species** you added to the site (useful before a dive).

### Sighting statistics

[Insights](statistics.md) summarizes your marine life: unique species, total sightings, the species you see most and those seen only once, and a breakdown by category.

---

## Photos and videos

### Adding photos to a dive

The **Photos** section on each dive's page shows all media linked to that dive. Adding photos opens **Select Photos**, with three tabs:

**Gallery**, your device's photo library:

1. The picker shows photos from your library taken around the dive.
2. Tap to select photos (or **Select All**).
3. Tap **Done**. The photos are linked to the dive, and enrichment data is calculated automatically (see below).

**Files**, photos and videos on disk:

1. **Pick files…** or **Pick a folder…**.
2. With **Auto-match photos and videos to dives by date** on, Submersion groups the files under the dives they belong to (see [How photos are matched](#how-photos-are-matched)); files that fit no dive land under **Unmatched**, with the reason.
3. Each file shows where its time came from (from EXIF, from file metadata, from file date, or no date found). If a camera clock was set wrong, **Shift capture times by** moves every file at once.
4. Move a file with **Choose a dive**, then link them (**Link N items**).

**URL**: paste one or more HTTP or HTTPS links to photos (see [Network URLs and manifest feeds](#network-urls-and-manifest-feeds)).

**Videos** are supported alongside photos. Videos show a camera icon in the grid and display their duration.

### How photos are matched

Submersion reads the time each photo or video was taken and links it to the dive whose window contains it: from **30 minutes before entry** to **60 minutes after exit**. Times are compared as local clock times, the digits your dive computer showed where you dived.

A photo is dated from its EXIF data, first match wins: **DateTimeOriginal** (when the shutter fired), then **DateTimeDigitized**, then **DateTime**, and only if there is no EXIF date, the file's modified date.

MP4, MOV and M4V videos are dated, in order, from the QuickTime creation date (iPhone and recent Apple software), the content-created date some cameras write, the movie header creation time, and finally the file's modified date. A creation date written in UTC carries no local clock, so it is skipped.

The movie header time is meant to be UTC, but GoPro and some other cameras write their local clock there. Submersion compares it with the file's modified date to tell which: if they agree as UTC, it is converted to this computer's local time (so import while you are in the timezone where you dived, or use **Shift capture times by**); otherwise it is read as the camera's local clock.

AVI, MKV and WEBM videos, PNG screenshots, and files whose metadata was stripped have no capture date, so they fall back to the modified date, which is often when they were copied. The review says so (**No capture date found**), and **Choose dive** puts the file on the right dive by hand.

### Suggested photos

After logging a dive, the app may suggest photos from your library that were taken during the dive window. A suggestion banner appears on the dive's page; accept or dismiss it.

### Underwater enrichment

When you add a photo from your device gallery or a local file, Submersion tries to match its EXIF timestamp to the dive profile. If a profile is available, the photo is **enriched** with data interpolated from the profile at the moment it was taken:

| Enrichment field | Source |
|-----------------|--------|
| Depth | Interpolated from profile sample nearest to the photo's timestamp |
| Temperature | Interpolated from profile sample nearest to the photo's timestamp |
| Elapsed time | Seconds into the dive when the photo was taken |

Enrichment data appears as an overlay when you open a photo in full-screen view. The overlay shows depth, temperature, and elapsed time. A confidence indicator tells you whether the values are an **exact** match to a profile sample, **interpolated** between two samples, or only **estimated**.

Enrichment only applies when the dive has a profile and the photo's time falls within it. If your camera's clock was off, correct it with **Shift capture times by** when you link the files.

<!-- screenshot: images/marine-life-and-photos/photo-enrichment.png: enriched underwater photo -->

### Captions and favorites

In the full-screen photo viewer, tap the info panel (or swipe up on mobile) to:

- Add or edit a **caption**: free text stored with the photo.
- Toggle **Favorite**: favorite photos are flagged in the grid with a heart icon.

### Tagging species in photos

You can link a species sighting directly to a photo by tagging it in the image. Tags store a bounding box on the photo so the species region is marked. Tap the tag icon in the photo viewer and draw a box around the creature, then select the species from the picker. The tag is linked to the corresponding sighting if one exists for that dive.

---

## Media sources

Submersion can resolve photos from several sources. Which sources are available is configured in **Settings > Data > Photos & Media**: **Photo library & sources**, **Network sources**, and **Media Storage** (see [Media Sync](media-sync.md)).

<!-- screenshot: images/marine-life-and-photos/media-sources.png: media source config -->

### Photo library (platform gallery)

The default source. On iOS and macOS this is your Apple Photos library (including iCloud-synced albums). On Android it is your device photo library (Google Photos). You grant photo-library permission once; Submersion reads thumbnails and full-resolution images on demand.

### Local files

On desktop (macOS, Windows, Linux) you can link photos directly from the filesystem, which suits photos already organized in folders on your computer. On iOS and Android, files linked this way use a platform security-scoped reference so they remain accessible even when the file is moved within the same app sandbox.

The **Photo library & sources** page shows a count of linked local-file photos, broken down by availability status. A **Re-verify all local files** action checks each linked path or reference and marks any that can no longer be resolved.

> [!NOTE]
> On Android, the system caps the number of persistable URI permissions at 128 per app. The same page shows current usage against that limit (**Android URI permissions**). If you need to link more files, unlinking previously added files frees those slots.

### Network URLs and manifest feeds

You can add photos by pasting one or more HTTP/HTTPS URLs directly into the picker's **URL** tab. The app fetches the image, reads its EXIF metadata, and stores the URL as the source reference. Photos sourced from URLs are displayed via a caching layer and do not consume local storage beyond the disk cache.

**Manifest subscriptions** let you subscribe to a feed of photo URLs (in Atom/RSS, JSON, or CSV format). The app polls the feed on a schedule you control and automatically adds new entries as media items. Existing entries are deduplicated using the subscription ID and the entry's unique key, so re-polls never create duplicates.

Per-host **credentials** can be saved under **Network sources**: enter a hostname and authentication details once, and the app attaches those credentials to every request to that host.

> [!TIP]
> **Settings > Data > Photos & Media > Network sources** lists all saved hosts, active manifest subscriptions, a cache-size indicator with a clear-cache action, and a **Scan all network media** button that re-verifies every URL-sourced photo in your library.

---

## The Media library

**Media** in the navigation shows every photo and video you have linked, grouped by dive. Filter it (**Filter media**) by **Photos** or **Videos**, **Site**, **Species**, **Trip**, **Dates**, or **Missing files** (media whose file can no longer be found), and sort it (**Sort media**).

To work on several items at once, use the grid's selection control, then tap items or drag across them to select a range (**Select All** selects everything shown). **Unlink** removes the selected items from your Submersion library, along with their thumbnails and any [Media Sync](media-sync.md) cloud copies; items a dive site still uses are kept. The original files in your photo library or on disk are not touched.

---

## How photos resolve across devices

Photos linked from your device gallery are stored as a platform asset ID, not a copy of the image. When your database is synced to a second device (see [Multi-Device Sync](multi-device-sync.md)), the second device must be able to locate the same photo in its own library.

Submersion resolves cross-device gallery photos using a tiered matching strategy: it first tries to match by filename and timestamp, then falls back to image dimensions. A local-device cache stores confirmed mappings so each photo only needs to be resolved once per device.

Photos from **local files** (linked by path or security-scoped bookmark) stay per-device: a photo linked on your Mac will not be visible on your phone because the file does not exist there. The thumbnail grid shows a placeholder for photos that cannot be resolved on the current device.

Photos from **network URLs** and **manifest feeds** are accessible on every device with a network connection, because the source is a URL rather than a device-local pointer.

> [!TIP]
> All of the above describes the app with no media store connected. If you turn on [Media Sync](media-sync.md), Submersion keeps a copy of each photo and video in cloud storage you control, and gallery and local-file photos become visible on every connected device, including devices that never had the original.

---

## See also

- [Dive Logging](dive-logging.md): recording the rest of your dive data
- [Dive Sites](dive-sites.md): site-level species lists and site details
- [Insights](statistics.md): marine life summaries and sighting trends
- [Multi-Device Sync](multi-device-sync.md): how media resolves when syncing across devices
- [Media Sync](media-sync.md): keeping photo and video copies in your own cloud storage
