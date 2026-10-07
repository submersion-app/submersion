# Marine Life and Photos

Record the creatures you encountered and the photos you took — all from the dive detail screen, side by side with your log data.

> [!NOTE]
> **Where to find it:** Open any dive from the [Dive Log](dive-logging.md) and scroll to the **Sightings** and **Photos** sections. You can also access the species catalog at **Settings → Species**, and media-source settings at **Settings → Data → Media Sources**.

<!-- screenshot: images/marine-life-and-photos/sighting.png — logging a sighting -->

---

## Marine life

### The species catalog

Submersion ships with a built-in catalog of more than 500 species organized into nine categories:

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

Each entry carries a common name, optional scientific name, taxonomy class, description, and an optional reference photo. Built-in entries cannot be deleted, but you can add unlimited custom species alongside them.

### Adding a custom species

1. Open **Settings → Species** and tap **+ Add Species**.
2. Enter the common name (required) and the scientific name, taxonomy class, and description (all optional).
3. Select a category from the list above.
4. Optionally attach a reference photo.
5. Save. Your new species is immediately available in the sighting picker.

If you later realize the identification was wrong, tap the species, then **Edit** to correct it.

### Logging a sighting on a dive

1. Open the dive and scroll to **Sightings**.
2. Tap **+ Add Sighting**.
3. Use the search field in the picker to find the species by common name or scientific name.
4. Confirm the selection, then set:
   - **Count** — how many individuals you observed (default 1).
   - **Notes** — optional free-text for behavior, size, depth, or anything else worth remembering.
5. Save. The sighting is linked to this dive and appears in the sightings list immediately.

You can add as many sightings as you like to a single dive. To remove a sighting, swipe it left or use the delete action.

> [!TIP]
> If you are not sure of the species, log it under **Other** and add a description in the notes field. You can come back later and update the species once you have confirmed the identification.

### Species on dive sites

Each [Dive Sites](dive-sites.md) page shows two marine-life panels:

- **Spotted here** — every species logged across all dives at the site, with a total sighting count. This list builds automatically as you log dives.
- **Expected species** — a manually curated list of species known to inhabit the site (useful before a dive). Tap the edit icon to add or remove entries.

### Sighting statistics

The **Statistics** screen shows a marine life summary that includes:

- Total unique species seen across your entire log
- Total individual sighting entries
- Most frequently encountered species
- Species seen only once
- A breakdown by category

For any individual species, open its detail page to see the total sighting count, the number of dives with that sighting, the date of first sighting, which sites you have seen it at, and the depth range across all encounters.

---

## Photos and videos

### Adding photos to a dive

The **Photos** section on each dive detail page shows all media linked to that dive.

**From your device photo library:**

1. Tap **Add Photos** (or the camera icon) in the Photos section.
2. The picker opens on the **Gallery** tab, showing photos from your device library.
3. Tap to select one photo, or long-press to enter multi-select mode and pick several at once.
4. Confirm. The photos are linked to the dive, and enrichment data is calculated automatically (see below).

**From local files (desktop, or file paths on mobile):**

1. In the picker, switch to the **Files** tab.
2. Use **Pick Files** or **Pick Folder** to navigate to your photos.
3. The app reads each file's EXIF timestamp and offers to match files to dives automatically within a ±30-minute pre-dive and ±60-minute post-dive window.
4. Review the suggested matches, reassign any file to a different dive, and confirm.

**Videos** are supported alongside photos. Videos show a camera icon in the grid and display their duration.

### Suggested photos

After logging a dive, the app may suggest photos from your library that were taken during the dive window. A suggestion banner appears on the dive detail page — accept or dismiss it.

### Underwater enrichment

When you add a photo from your device gallery or a local file, Submersion tries to match its EXIF timestamp to the dive profile. If a profile is available, the photo is **enriched** with data interpolated from the profile at the moment it was taken:

| Enrichment field | Source |
|-----------------|--------|
| Depth | Interpolated from profile sample nearest to the photo's timestamp |
| Temperature | Interpolated from profile sample nearest to the photo's timestamp |
| Elapsed time | Seconds into the dive when the photo was taken |

Enrichment data appears as an overlay when you open a photo in full-screen view. The overlay shows depth, temperature, and elapsed time. A confidence indicator tells you whether the values are an **exact** match to a profile sample, **interpolated** between two samples, or only **estimated**.

If the photo's clock was offset from the dive computer's clock, there is no automatic correction, but enrichment only applies when a profile exists and the timestamps overlap.

<!-- screenshot: images/marine-life-and-photos/photo-enrichment.png — enriched underwater photo -->

### Captions and favorites

In the full-screen photo viewer, tap the info panel (or swipe up on mobile) to:

- Add or edit a **caption** — free text stored with the photo.
- Toggle **Favorite** — favorite photos are flagged in the grid with a heart icon and can be filtered separately.

### Tagging species in photos

You can link a species sighting directly to a photo by tagging it in the image. Tags store a bounding box on the photo so the species region is marked. Tap the tag icon in the photo viewer and draw a box around the creature, then select the species from the picker. The tag is linked to the corresponding sighting if one exists for that dive.

---

## Media sources

Submersion can resolve photos from several sources. Which sources are available is configured in **Settings → Data → Media Sources**.

<!-- screenshot: images/marine-life-and-photos/media-sources.png — media source config -->

### Photo library (platform gallery)

The default source. On iOS and macOS this is your Apple Photos library (including iCloud-synced albums). On Android it is your device photo library (Google Photos). You grant photo-library permission once; Submersion reads thumbnails and full-resolution images on demand.

### Local files

On desktop (macOS, Windows, Linux) you can link photos directly from the filesystem — useful for photos already organized in folders on your computer. On iOS and Android, files linked this way use a platform security-scoped reference so they remain accessible even when the file is moved within the same app sandbox.

The Media Sources settings page shows a count of linked local-file photos, broken down by availability status. A **Re-verify all local files** action checks each linked path or reference and marks any that can no longer be resolved.

> [!NOTE]
> On Android, the system caps the number of persistable URI permissions at 128 per app. The Media Sources page shows current usage against that limit. If you need to link more files, unlinking previously added files frees those slots.

### Network URLs and manifest feeds

You can add photos by pasting one or more HTTP/HTTPS URLs directly into the picker's **URL** tab. The app fetches the image, reads its EXIF metadata, and stores the URL as the source reference. Photos sourced from URLs are displayed via a caching layer and do not consume local storage beyond the disk cache.

**Manifest subscriptions** let you subscribe to a feed of photo URLs (in Atom/RSS, JSON, or CSV format). The app polls the feed on a schedule you control and automatically adds new entries as media items. Existing entries are deduplicated using the subscription ID and the entry's unique key, so re-polls never create duplicates.

Per-host **credentials** can be saved under **Network Sources** in Media Sources settings: enter a hostname and authentication details once, and the app attaches those credentials to every request to that host.

> [!TIP]
> The **Network Sources** sub-page (Settings → Data → Media Sources → Network Sources) lists all saved hosts, active manifest subscriptions, a cache-size indicator with a clear-cache action, and a **Scan all network media** button that re-verifies every URL-sourced photo in your library.

### Connected services

The `serviceConnector` source type is reserved in the schema for future third-party service integrations. No service connectors are enabled in the current release; the infrastructure (connector accounts table, credentials registry) is in place and connectors will appear here in a future update.

---

## Bulk selection

In the Photos grid, long-press any photo to enter selection mode. In selection mode:

- Tap additional photos to add them to the selection.
- Drag across photos to select a range.
- Use **Select All** in the header to select every photo in the dive.
- Tap **Unlink** to remove all selected photos from the dive at once (this does not delete the originals from your library or filesystem).

---

## How photos resolve across devices

Photos linked from your device gallery are stored as a platform asset ID, not a copy of the image. When your database is synced to a second device (see [Multi-Device Sync](multi-device-sync.md)), the second device must be able to locate the same photo in its own library.

Submersion resolves cross-device gallery photos using a tiered matching strategy: it first tries to match by filename and timestamp, then falls back to image dimensions. A local-device cache stores confirmed mappings so each photo only needs to be resolved once per device.

Photos from **local files** (linked by path or security-scoped bookmark) stay per-device — a photo linked on your Mac will not be visible on your phone because the file does not exist there. The thumbnail grid shows a placeholder for photos that cannot be resolved on the current device.

Photos from **network URLs** and **manifest feeds** are accessible on every device with a network connection, because the source is a URL rather than a device-local pointer.

> [!TIP]
> All of the above describes the app with no media store connected. If you turn on [Media Sync](media-sync.md), Submersion keeps a copy of each photo and video in cloud storage you control, and gallery and local-file photos become visible on every connected device — including devices that never had the original.

---

## See also

- [Dive Logging](dive-logging.md) — recording the rest of your dive data
- [Dive Sites](dive-sites.md) — site-level species lists and site details
- [Statistics](statistics.md) — marine life summaries and sighting trends
- [Multi-Device Sync](multi-device-sync.md) — how media resolves when syncing across devices
- [Media Sync](media-sync.md) — keeping photo and video copies in your own cloud storage
