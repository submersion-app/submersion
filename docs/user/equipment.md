# Equipment

Track your gear, log its service history, and see at a glance what needs attention before your next dive.

> [!NOTE]
> **Where to find it:** Select **Equipment** in the navigation rail on the left. The page opens with two tabs: **Equipment** (individual items) and **Sets** (named collections).

<!-- screenshot: images/equipment/item-detail.png — equipment item detail showing service status -->

## Adding gear

Tap the **+** button to create a new equipment item. Every item requires a name and a type; all other fields are optional.

### Fields

| Field | Notes |
|-------|-------|
| **Name** | Your label for this item — e.g., "Primary reg" |
| **Type** | Category (see types below) |
| **Brand** | Manufacturer |
| **Model** | Product model |
| **Serial number** | Useful for warranty and service records |
| **Size** | Free text — S, M, L, XL, or a specific measurement |
| **Status** | Current state of the item (see statuses below) |
| **Purchase date** | Date you acquired the item |
| **Purchase price** | Cost and currency code (e.g., USD) |
| **Last service date** | Most recent service; used to compute the next due date |
| **Service interval** | Number of days between required services |
| **Notes** | Any additional information |

### Equipment types

Submersion recognises 18 equipment types:

Regulator, BCD, Wetsuit, Drysuit, Fins, Mask, Dive Computer, Tank, Weights, Light, Camera, SMB, Reel, Knife, Hood, Gloves, Boots, Other.

### Statuses

| Status | Meaning |
|--------|---------|
| **Active** | In use and in good condition |
| **Needs Service** | Mark items you want to service soon |
| **In Service** | Currently at the shop or being repaired |
| **Retired** | No longer in use; kept for history |
| **Loaned Out** | Lent to someone else |
| **Lost** | Cannot be located |

> [!NOTE]
> "Overdue" is not a discrete status. It is a computed property: when today's date is past `lastServiceDate + serviceIntervalDays`, the item is flagged overdue automatically. The icon turns red and a warning banner appears on the detail page, but the status field itself remains unchanged.

## Service records and maintenance reminders

<!-- screenshot: images/equipment/service-reminders.png — service reminders list on item detail -->

### Logging a service record

Open an equipment item, then tap **Add** in the **Service history** section. Each record captures:

| Field | Notes |
|-------|-------|
| **Service type** | Annual Service, Repair, Inspection, Overhaul, Part Replacement, Cleaning, Calibration, Warranty Service, Recall/Safety, Other |
| **Service date** | Date the work was done |
| **Provider** | Shop or technician name (optional) |
| **Cost** | What you paid (optional) |
| **Next service due** | If you know the next target date, set it here — this updates the item's next-due display |
| **Notes** | What was done, parts replaced, etc. |

The **Service history** section on the detail page totals all costs across records and lists every entry. Tap any record to edit it; use the overflow menu on a record to delete it.

### Service interval and due date

If you set a **service interval** on the item, Submersion calculates the next due date as `lastServiceDate + intervalDays`. The detail page shows:

- Last service date
- Next service due date
- A countdown or overdue indicator (positive = days remaining, negative = days overdue)

When service is overdue, the item's icon changes to the error colour and a banner appears at the top of its detail page.

### Maintenance reminders (iOS and Android)

On mobile, Submersion can send local push notifications before service is due. Global defaults live in **Settings → Notifications**:

| Setting | Default / Options |
|---------|------------------|
| **Service reminders** | On / Off |
| **Reminder schedule** | Select any combination of 7, 14, or 30 days before the due date |
| **Reminder time** | Time of day to deliver the notification (default 09:00 local) |

Notifications fire when the app launches and — as a backup — during background refresh. Tapping a notification opens the item's detail page directly.

**Per-item overrides** are available in the edit form under **Notifications**:

- **Use custom reminders** — override the global schedule with a different set of day intervals (7, 14, 30) for this item only.
- **Disable reminders** — suppress notifications for this item entirely, even when the global setting is on.

Leaving both switches off means the item inherits the global settings.

> [!TIP]
> The reminder system only fires when a service interval is set on the item. If you have not set an interval, no reminder is scheduled regardless of the notification settings.

## Equipment sets

<!-- screenshot: images/equipment/equipment-sets.png — equipment sets tab showing named sets -->

An equipment set is a named collection of items — for example, "Tropical" or "Cold water drysuit". Sets let you select a full configuration in one step when logging a dive.

### Creating a set

1. Open **Equipment** and tap the **Sets** tab.
2. Tap **+** to create a new set.
3. Give the set a name and an optional description.
4. Select the items to include by tapping them in the list of active equipment.
5. Save.

You can edit a set at any time to add or remove items or rename it.

### Using a set on a dive

When logging or editing a dive, find the equipment section and tap **Apply set**. Select a set from the list to attach all of its items to that dive at once. You can still add or remove individual items after applying a set.

> [!TIP]
> Sets reference items, not copies of them. If you later retire an item that belongs to a set, the set remains intact but that item will appear as retired when the set is applied.

## Tank presets

Submersion includes built-in presets for common scuba cylinder configurations. Presets record the physical attributes of a tank (water volume, working pressure, and material) so you do not have to type them each time you add a tank to a dive.

### Built-in presets

| Preset | Volume | Working pressure | Material | Rated capacity |
|--------|--------|-----------------|----------|----------------|
| **AL80** | 11.1 L | 207 bar (3 000 psi) | Aluminum | 77.4 cu ft |
| **AL63** | 9.0 L | 207 bar (3 000 psi) | Aluminum | 63 cu ft |
| **AL40** | 5.7 L | 207 bar (3 000 psi) | Aluminum | 40 cu ft |
| **HP120** | 15.3 L | 237 bar (3 442 psi) | Steel | 120 cu ft |
| **HP100** | 12.9 L | 237 bar (3 442 psi) | Steel | 100 cu ft |
| **HP80** | 10.2 L | 237 bar (3 442 psi) | Steel | 80 cu ft |
| **LP85** | 13.0 L | 182 bar (2 640 psi) | Steel | 85 cu ft |
| **Steel 15L** | 15.0 L | 200 bar | Steel | — |
| **Steel 12L** | 12.0 L | 200 bar | Steel | — |
| **Steel 10L** | 10.0 L | 200 bar | Steel | — |
| **AL40 Stage** | 5.7 L | 207 bar (3 000 psi) | Aluminum | 40 cu ft |
| **AL30 Stage** | 4.3 L | 207 bar (3 000 psi) | Aluminum | 30 cu ft |

> [!NOTE]
> Pressures for aluminum and high-pressure steel tanks are derived from exact PSI-to-bar conversions (1 psi = 1/14.5038 bar), so they display correctly in both bar and PSI. The rounded values in the table above are for readability.

### Custom presets

Go to **Settings → Tank Presets** to create custom presets for cylinders not in the built-in list, or to add local variants.

### Default tank preset

In **Settings → Tank Presets**, you can mark one preset as your **default**. The default preset is:

- **Applied automatically** when you add a tank to a new dive — the volume, working pressure, and material fields are pre-filled from the preset.
- **Optionally applied to imports** — enable **Apply default tank to imports** to fill in missing tank fields (volume, working pressure, material) on imported dives that do not include complete tank data. Fields that already have values are never overwritten.

The system default is **AL80**. Deleting the preset marked as default resets the default back to AL80.

> [!TIP]
> The default preset sets the physical tank attributes only — volume, working pressure, and material. The start pressure for a dive comes from **Settings → Default start pressure**, which is a separate field.

## Equipment usage stats

On the detail page for any item, Submersion shows how many dives and trips that item has been linked to. These counts are live: tapping the dive count filters the dive list to show only dives where that item was used; tapping the trip count filters the trip list similarly.

The equipment summary (visible when no item is selected on wider screens) shows a quick overview:

- Total items in your catalog
- Active items
- Items with service overdue (if any), with a shortcut to each
- Total purchase value of all items where a price is recorded

## See also

- [Dive Logging](dive-logging.md) — link equipment to individual dives
- [Trips](trips.md) — see which gear you brought on a trip
- [Settings](settings.md) — configure notification defaults, default tank preset, and start pressure
- [Import/Export](import-export.md) — import dives with tank data that can be matched to presets
- [Weight Planner](weight-planner.md) — how equipment buoyancy attributes feed weight prediction
