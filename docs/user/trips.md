# Trips

Trips group a set of related dives — a holiday, a resort week, or a liveaboard expedition — so you can browse, relive, and share statistics for the whole experience in one place.

> [!NOTE]
> **Where to find it:** **Trips** in the navigation rail (desktop, screen width 800 px or wider) or the bottom bar (mobile, default middle slot).

<!-- screenshot: images/trips/trip-detail.png — trip detail -->

## Creating a trip

Tap the **+** button at the bottom right of the Trips list. Every trip requires:

- **Name** — a short label for the trip (for example, "Red Sea 2026").
- **Start date** and **End date** — the calendar dates bounding the trip. The form shows the duration in days as you pick dates.
- **Trip type** — one of four options selected from a segmented control at the top of the form:

| Type | Use when |
|------|----------|
| **Shore** | Diving from shore or a day boat without a resort base |
| **Day Trip** | A single-day boat trip |
| **Resort** | A shore-based stay at a dive resort or hotel |
| **Liveaboard** | Living and diving aboard a vessel for multiple nights |

Optional fields available for all trip types:

- **Location** — free-text destination (for example, "Dahab, Egypt").
- **Resort name** — the dive resort or accommodation.
- **Liveaboard name** — the vessel name as it appears in marketing material.
- **Notes** — any freeform text about the trip.

When multiple diver profiles exist on the device, a **Share with all profiles** toggle lets you make the trip visible to every profile.

> [!TIP]
> You can edit any of these fields later by opening the trip and tapping the edit (pencil) icon in the top-right corner.

## Adding dives to a trip

### Scanning by date

When you save a new trip — or change its date range — Submersion automatically scans your dive log for dives that fall within those dates. If any are found, a **Find dives** sheet appears listing them in two groups:

- **Unassigned dives** — dives not yet attached to any trip (pre-selected by default).
- **Dives on other trips** — dives already assigned elsewhere (deselected by default, but available to move).

Check or uncheck individual dives, then tap **Add** to attach the selection to the trip. Tap **Cancel** to skip — you can repeat the scan any time from the Dives section inside the trip using the playlist-add icon.

### Moving dives manually

You can also assign a dive to a trip from the dive's own edit form by selecting **Trip** in the dive detail. See [Dive Logging](dive-logging.md) for details.

## Liveaboard details

When you choose the **Liveaboard** trip type, a **Vessel** section appears in the edit form with these additional fields:

| Field | Notes |
|-------|-------|
| **Vessel name** | Required for liveaboard trips |
| **Operator** | The dive operator or charter company |
| **Vessel type** | Catamaran, motor yacht, sailing yacht, or other |
| **Cabin type** | Free text — for example, "Twin en-suite" |
| **Capacity** | Number of guest berths |
| **Embark port** | The port where you boarded |
| **Disembark port** | The port where you disembarked |

### Itinerary

Saving a new liveaboard trip auto-generates a day-by-day itinerary spanning the trip dates. The first day is marked **Embark**, the last **Disembark**, and every day in between is **Dive Day**. Open the **Itinerary** tab on the trip detail to see the timeline and tap any day to change its type (**Dive Day**, **Sea Day**, **Port Day**, **Embark**, or **Disembark**), add a port name, or add notes for that day.

The **Overview** tab for a liveaboard trip also shows:

- Vessel details (operator, vessel type, cabin, capacity, embark and disembark ports).
- Enhanced statistics — sea days, dive days, dives per day, and unique sites visited.
- A daily breakdown of dives by date.
- A voyage map plotting the route across itinerary days.

## Trip photo gallery

Every trip has a **Photos** section that aggregates photos from all dives in the trip. A row of up to five thumbnails appears on the Overview tab; tap **View all** (or the **Photos** tab on a liveaboard trip) to open the full gallery.

<!-- screenshot: images/trips/trip-gallery.png — trip photo gallery -->

The gallery groups photos by dive in chronological order, with each dive shown as an expandable section. Tap any thumbnail to open the full-screen viewer.

To link more photos to a trip, tap the camera icon in the gallery app bar. Submersion scans your device's photo library for images taken during the trip's date range, matches them to the dives they most likely belong to, shows you the results to review, and links the ones you confirm. Photos that are already linked are excluded from the scan automatically.

> [!TIP]
> Photos must be attached to individual dives, not to the trip directly. If the trip has no dives yet, the scan button will prompt you to add dives first.

## Trip statistics and summary

The **Statistics** card on every trip's Overview tab shows:

- Total dives in the trip
- Total bottom time
- Maximum depth
- Average depth

Tapping **View all dives** (or switching to the **Dives** tab on a liveaboard trip) shows every dive in the trip in chronological order. You can tap any dive to open its full detail.

To view the trip's dive sites on a map, tap the map icon in the trip detail app bar. Submersion switches to the dive map filtered to this trip's dives.

> [!TIP]
> To export a trip's dive log, open the trip detail, tap the overflow menu (**...**), and choose **Export**. CSV and PDF export options are available.

## See also

- [Dive Logging](dive-logging.md)
- [Dive Sites](dive-sites.md)
- [Marine Life and Photos](marine-life-and-photos.md)
- [Statistics](statistics.md)
