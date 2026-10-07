# Trips

Trips group a set of related dives: a holiday, a resort week, a liveaboard expedition, or a single morning at your local site. Before you go, a trip helps you plan and pack; while you are away and afterwards, it tells the story of the trip day by day.

> [!NOTE]
> **Where to find it:** **Trips** in the navigation rail (desktop) or the bottom bar (phone, one of the default slots).

<!-- screenshot: images/trips/trip-detail.png: trip detail -->

## Creating a trip

Tap the **+** button at the bottom right of the Trips list (**Add Trip**). Every trip needs:

- **Trip Name**: a short label for the trip (for example, "Red Sea 2026").
- **Start Date** and **End Date**: the calendar dates bounding the trip. The form shows the duration in days as you pick dates.
- **Trip type**, chosen at the top of the form:

| Type | Use when |
|------|----------|
| **Shore** | Shore dives over one or more days |
| **Liveaboard** | Living aboard a dive boat, with vessel and itinerary details |
| **Resort** | A stay at a dive resort |
| **Day Trip** | A single day out, such as one local dive |

> [!TIP]
> A trip does not have to mean travel. If you dive one weekend morning at a local site, a **Day Trip** is the place to put it. Choosing **Day Trip** locks the end date to the start date: moving the start date moves the end date with it, and choosing another type makes the end date editable again.

Optional fields:

- **Location**: the destination (for example, "Dahab, Egypt"), with **Resort Name** and **Liveaboard Name**.
- **Return Flight**: when you fly home. Submersion uses it to count down to the flight and to tell you how long you can still dive before flying (see [Safety](safety.md)).
- **Planning**: **Dives per day**, **Expected dives**, **Expected runtime per dive**, and **Divers sharing cylinders** (including you; blank means one). These feed the trip's gas and cylinder planning.
- **Notes**: anything else about the trip.

When more than one diver profile exists, **Share with all dive profiles** makes the trip visible to every profile, and **Settings > Shared data** has **Share all my trips** to share them all at once, and **Share new sites and trips by default**.

> [!TIP]
> You can edit any of these later by opening the trip and tapping the edit (pencil) icon in the top-right corner.

## Liveaboard details

When you choose **Liveaboard**, the form adds **Vessel Details**:

| Field | Notes |
|-------|-------|
| **Vessel Name** | Required for liveaboard trips |
| **Operator / Charter** | The dive operator or charter company |
| **Vessel Type** | Catamaran, Motor Yacht, Sailing Yacht, or Other |
| **Cabin Type** | Free text, for example "Twin en-suite" |
| **Passenger Capacity** | Number of guest berths |
| **Embark Port** / **Disembark Port** | Where you boarded and left the boat |

## The trip's tabs

Every trip, whatever its type, has six tabs: **Overview**, **Itinerary**, **Gear**, **Checklist**, **Dives**, and **Photos**.

### Overview

Before the first day, the Overview is a preparation page: a countdown to the trip, one summary card whose rows (itinerary, plan, gear, checklist) open the other tabs, and your notes.

From the first day on, it becomes the trip's story: a header with the trip's numbers, then one chapter per day, each with its own map of that day's dives and a strip showing when you dived. Days with no dives show as surface days, and planned dives appear on the days they are planned for. While the trip is under way and you have entered a return flight, a card counts down to it.

### Itinerary

The itinerary has one entry per day. If a trip has none yet, **Generate itinerary** builds it from the trip dates, and **Fill in missing days** adds any days that are missing after you change the dates. Tap a day to edit it (**Edit Day**):

- **Day Type**: **Dive Day**, **Travel**, **Rest**, **Sea Day**, **Port Day**, **Embark**, or **Disembark**.
- **Planned dives**: how many dives you plan that day.
- **Location** or **Port / Anchorage**, and **Notes**.

### Gear

The **Gear** tab is what you will dive with. **Add** offers **From my equipment**, **An equipment set**, or **Rental cylinders**. Packed items are listed under **Packed**, and cylinders get slots on the trip's board under **Cylinders**; a cylinder you pack can be put on the board or left off it. Equipment due for service shows a service alert here.

### Checklist

The trip's checklists, with how many items are done, due this week, or overdue.

### Dives

Every dive in the trip, in chronological order. Tap any dive to open it.

### Photos

All photos from the trip's dives, grouped by dive in chronological order (**Trip Photos**). Tap any thumbnail to open the full-screen viewer.

<!-- screenshot: images/trips/trip-gallery.png: trip photo gallery -->

To link more photos, tap the camera icon in the gallery's app bar. Submersion scans your device's photo library for images taken during the trip's dates, matches them to the dives they most likely belong to, shows you the results to review, and links the ones you confirm. Photos that are already linked are left out of the scan.

> [!TIP]
> Photos attach to individual dives, not to the trip directly. If the trip has no dives yet, the scan asks you to add dives first.

## Adding dives to a trip

### Scanning by date

When you save a new trip, or change its dates, Submersion looks for dives within those dates and offers them in **Add Dives to Trip**, in two groups:

- **Unassigned**: dives not on any trip yet (selected by default).
- **On other trips**: dives already on another trip (not selected, but you can move them).

Check or uncheck dives, then tap **Add**. **Find matching dives** runs the same scan again any time from the trip's dives.

### From the dive

You can also put a dive on a trip from the dive's own form, in its **Trip** section. When a trip's dates cover the dive, Submersion suggests it. To move many dives at once, select them in the dive list and use **Edit Selected**. See [Dive Logging](dive-logging.md).

Imported dives that have no trip of their own join the trip whose dates cover them (see [Import & Export](import-export.md)).

## Trip statistics and map

To see the trip's dive sites on a map, tap the map icon in the trip's app bar. Submersion switches to the dive map filtered to this trip's dives.

> [!NOTE]
> Exporting a whole trip (to CSV or PDF) is not available yet; the trip's **Export** menu says so. To export a trip's dives today, select them in the dive list and use **Export Selected** (see [Dive Logging](dive-logging.md)).

## See also

- [Dive Logging](dive-logging.md)
- [Dive Sites](dive-sites.md)
- [Marine Life and Photos](marine-life-and-photos.md)
- [Equipment](equipment.md)
- [Safety](safety.md)
