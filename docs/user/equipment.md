# Equipment

Track your gear, log its service history, and see at a glance what needs
attention before your next dive.

> [!NOTE]
> **Where to find it:** select **Equipment** in the navigation. A toggle at the
> top switches between **Equipment** (individual items) and **Sets** (named
> collections).

<!-- screenshot: images/equipment/item-detail.png: equipment item detail showing service clocks -->

## Adding gear

Tap **Add Equipment** to create an item. Only **Type** and **Name** are
required.

| Field | Notes |
|-------|-------|
| **Type** | The kind of item (see the list below). The type decides which other fields and service clocks the item gets. |
| **Status** | Where the item stands (see the statuses below) |
| **Installed in** | For an O2 cell or a battery, the item it is fitted to |
| **Name** | Your label, for example "My Primary Regulator" |
| **Brand** / **Model** | Manufacturer and product |
| Type-specific fields | For example a tank's volume, working pressure and material, or a suit's thickness. Some types also have a colour, used when the gear is drawn on the diver figure. |
| **Serial Number** | For warranty and service records |
| **Purchase Information** | **Purchase Date**, **Purchase Price** and **Currency** |
| **Notes** | Anything else |
| **Tags** | Your own labels, for filtering the list |
| **Location** | Where the item is kept (new items only; an existing item changes place with **Move**) |
| **Advanced** | **Custom fields**: any key and value you want to keep with the item |
| **Notifications (Optional)** | Per-item reminder settings (see [Service reminders](#service-reminders)) |

### Equipment types

Submersion has 48 equipment types:

- **Breathing:** Regulator, First Stage, Second Stage, Hose, Tank, Rebreather,
  O2 cell
- **Buoyancy and rig:** BCD, Backplate, Wing, Harness, Tank Band, Weight
  Pocket, Gear Pocket, Weights
- **Exposure protection:** Wetsuit, Drysuit, Undersuit, Base Layer, Rash Guard,
  Hood, Gloves, Boots
- **Basics:** Fins, Mask, Snorkel
- **Instruments:** Dive Computer, Transmitter, Instrument / Gauge, Compass
- **Lights and camera:** Light, Camera, Lens, Port, Housing, Tray / Handle,
  Arm / Clamp, Strobe, Video Light, Float Arm / Float
- **Safety and tools:** SMB, Reel, Knife, Tool
- **Other:** DPV, Bag, Battery, Other

### Statuses

| Status | Meaning |
|--------|---------|
| **Active** | In use |
| **Spare** | Usable but on the shelf, such as a spare hose. Serviced and reminded like active gear, but left out of the pickers when you add gear to a dive. |
| **Needs Service** | Marked by you as due for service |
| **In Service** | At the shop or being repaired |
| **Retired** | No longer in use; kept for its history |
| **Sold** | No longer yours; kept for its history |
| **Loaned Out** | Lent to someone |
| **Lost** | Cannot be found |
| **Wanted** | Gear you plan to buy. It has an **Expected Price** instead of a purchase price, and no serial number, service clocks or reminders. **Mark as purchased** turns it into active gear. |

Retired, sold and wanted items stay out of the dive pickers, sets and
statistics.

## The item page

Open an item to see everything about it. The page shows only the cards that
apply to the item's type.

- **Details:** status, the number of **Dives** and **Trips** the item was used
  on (tap either to see them), purchase details and how long you have owned it.
- **Location:** where the item is now. **Move** sends it somewhere else.
- **Cylinder passport:** for a Tank. See [Cylinder Passports](cylinder-passports.md).
- **Service clocks:** what maintenance is due, and when.
- **Exposure:** how hard the item has been used.
- **Condition findings:** trends worth a look, when there are any.
- **Check-ins:** notes on how the item behaved.
- **Components** and **Installed parts:** what the item is assembled from.
- **Documents:** invoices, receipts and warranty paperwork.
- **History:** who used and shared the item (with more than one diver profile).
- **Service History:** every service record.

## Service clocks

A service clock tracks one kind of maintenance on one item, such as a
regulator's annual service or a cylinder's hydrostatic test. New gear gets the
clocks its type needs automatically, and you can add more with **Add clock**.

A clock can count calendar days, dives, or hours underwater, and some also
count exposure: cold dives, salt-water hours or high-O2 hours. Whichever limit
comes first makes the clock due. A clock reads as due soon inside your reminder
window (see [Service reminders](#service-reminders)) or in the last 10% of any
other limit (dives, hours, or an exposure such as cold dives), and as overdue
once a limit is passed. The item's icon in
the list turns red when any clock is overdue.

A clock counts from the last service you logged for it. Until then it counts
from its **Baseline date**, which you can set in **Edit intervals**. From a
clock's menu you can **Log service**, **Edit intervals** for this item only,
**Pause** it, or **Remove** it.

### Service types

Clocks come from service types. These are built in:

| Service type | Applies to | Interval |
|--------------|-----------|----------|
| Hydrostatic test | Tank | 5 years |
| Visual inspection (VIP) | Tank | 1 year |
| O2 clean | Tank, Regulator, First Stage, Second Stage (added by hand) | 1 year or 50 high-O2 hours |
| Regulator service | Regulator, First Stage, Second Stage | 1 year, 100 dives or 50 cold dives |
| Computer battery | Dive Computer, Battery | 2 years |
| Transmitter battery | Transmitter, Battery | 1 year or 250 hours |
| BCD/wing inspection | BCD | 1 year |
| Drysuit seals | Drysuit (added by hand) | 2 years or 200 salt-water hours |
| Scrubber repack | Rebreather | 3 hours |
| O2 cell replacement | Rebreather, O2 cell | 1 year |
| Rebreather annual service | Rebreather | 1 year |
| General service | Any type (added by hand) | None set |

These intervals are starting points, not manufacturer figures; set your own per
item with **Edit intervals**. To create your own service types, or change the
defaults, go to **Settings > Manage > Service types**. A service type can have
day, dive and hour intervals, a default price and category, the equipment types
it **Applies to**, and whether to **Attach automatically to new gear**.

### Logging a service

Tap **Log service** on a clock, or **Add** in **Service History**. A service
record holds:

| Field | Notes |
|-------|-------|
| **Service type** | The clock this service resets |
| **Category** | Annual Service, Repair, Inspection, Overhaul, Part Replacement, Cleaning, Calibration, Warranty Service, Recall/Safety or Other; used for filtering and export |
| **Service Date** | When the work was done |
| **Provider/Shop** | Who did it |
| **Cost** and **Currency** | What you paid |
| **Next Service Due** | A specific next date, when you know one |
| **Notes** | What was done, parts replaced |

**Service History** lists every record with filters for task, category and
year. **Export maintenance log** exports the records.

### Service reminders

On iOS and Android, Submersion can notify you before service is due. The
defaults are in **Settings > Notifications**:

| Setting | Default |
|---------|---------|
| **Enable Service Reminders** | On |
| **Reminder Schedule** | 7, 14 and 30 days before service is due; choose any of the three |
| **Reminder Time** | 09:00 |
| **Trip service lead time** | 14 days: warns this long before a trip about gear that falls due before the trip ends |

The longest day in the reminder schedule is also how early a date-based clock
reads as due soon.

To change reminders for one item, open its edit form and use
**Notifications (Optional)**: **Use Custom Reminders** sets different days for this item, and
**Disable Reminders** turns its reminders off.

## Exposure and condition

The **Exposure** card totals how the item has been used: dives, hours
underwater, salt-water hours, cold dives, high-O2 hours, deep dives and, for
batteries, battery cycles. A dive counts as cold below 10 °C, as deep at or
beyond 30 m, and as high-O2 above 40% oxygen. Change these lines in
**Settings > Safety > Equipment condition**.

**Condition findings** point out trends, with the dives behind them: declining
or uneven rebreather cell output, rising transmitter dropouts, an issue that
keeps recurring, or issues that cluster on cold or deep dives. Dismiss a
finding you have dealt with, and **Restore** it later from the dismissed list.
**Condition findings**, and each rule, can be switched off in the same
**Equipment condition** settings.

**Check-ins** are your own notes on how an item behaved, on a dive or on the
bench. Tap **Add check-in**, tag what happened, and add a note. Check-ins feed
the recurring-issue findings.

## Parts and assemblies

Gear can be built from other gear. A regulator can list its first stage, second
stages and hoses under **Components**, and a rebreather or a light can list its
cells or batteries under **Installed parts**. Each part is an item of its own
with its own service clocks. A component's page shows what it is **Part of**,
and an installed cell or battery shows what it is **Installed in**. **Replace**
retires an installed part and puts a new one in the same slot.

## Locations

Record where your gear is: in storage, at a service shop, or with a person you
lent it to. Add places in **Settings > Manage > Locations**, then tap **Move**
on an item's **Location** card. A move can take the item's parts with it, and
offers to update its status: **In Service** at a shop, **Loaned Out** with a
person, and back to **Active** when it returns to storage. Every move is kept,
so **Show all** lists where the item has been.

## Equipment sets

<!-- screenshot: images/equipment/equipment-sets.png: equipment sets showing named sets -->

A set is a named collection of items, such as "Tropical" or "Cold water
drysuit", that you can add to a dive in one step.

### Creating a set

1. In **Equipment**, switch to **Sets** and tap **Add Set**.
2. Enter a **Set Name** and an optional **Description**.
3. Under **Select Equipment**, tap the items to include.
4. Tap **Create Set**.

Optional settings on a set:

- **Default set:** added automatically to new dives that have no equipment
  yet. You can also choose **Set as default** from a set's page.
- **Apply when this set's computer is imported:** if the set includes a dive
  computer, the whole set is added to dives downloaded or imported from it.
- **Geofences:** suggest the set for dives near chosen places. Center a
  geofence on a dive site or a dropped pin and set its radius.
- **Show diver figure:** draw the set's gear on a diver.

### Using a set on a dive

In the dive form, under **Equipment**, tap **Use Set** and choose a set. All of
its items are added to the dive, and you can still add or remove items after.
**Save as Set** turns a dive's current equipment into a new set. See
[Logging Dives](dive-logging.md).

> [!NOTE]
> A Tank item in a set is added to the dive's equipment only; it does not add a
> tank to the dive's **Tanks** list, so it brings no gas data. For a cylinder
> you own, open a tank on the dive and tap **Fill from my cylinders**: the tank
> takes the cylinder's size and latest fill, and the cylinder joins the dive's
> equipment.

## Tank presets

Presets hold a cylinder's water volume, working pressure and material, so you
do not type them for every tank.

| Preset | Volume | Working pressure | Material | Rated capacity |
|--------|--------|-----------------|----------|----------------|
| **AL100** | 13.1 L | 228 bar (3300 psi) | Aluminum | 100 cu ft |
| **AL80** | 11.1 L | 207 bar (3000 psi) | Aluminum | 77.4 cu ft |
| **AL63** | 9.0 L | 207 bar (3000 psi) | Aluminum | 63 cu ft |
| **AL40** | 5.7 L | 207 bar (3000 psi) | Aluminum | 40 cu ft |
| **HP120** | 15.3 L | 237 bar (3442 psi) | Steel | 120 cu ft |
| **HP100** | 12.9 L | 237 bar (3442 psi) | Steel | 100 cu ft |
| **HP80** | 10.2 L | 237 bar (3442 psi) | Steel | 80 cu ft |
| **LP85** | 13.0 L | 182 bar (2640 psi) | Steel | 85 cu ft |
| **Steel 15L** | 15.0 L | 200 bar | Steel | |
| **Steel 12L** | 12.0 L | 200 bar | Steel | |
| **Steel 10L** | 10.0 L | 200 bar | Steel | |
| **AL40 Stage** | 5.7 L | 207 bar (3000 psi) | Aluminum | 40 cu ft |
| **AL30 Stage** | 4.3 L | 207 bar (3000 psi) | Aluminum | 30 cu ft |

Manage presets in **Settings > Manage > Tank Presets**:

- **Default Tank:** star a preset to use it for every new tank you log. The
  default is AL80, and deleting the starred preset resets it to AL80.
- **Also apply to imported dives:** fill in missing tank data on imported dives
  from the default preset. Values a dive already has are kept.
- **Show in tank pickers:** switch off the built-in presets you never use. The
  default preset is always shown.
- **Add tank preset:** create your own.

## Finding and organising gear

The Equipment list can be searched by name, brand, model or serial number,
filtered by status, type, tags, location and owner, and sorted. On a wide screen, the
panel beside the list shows an overview while no item is selected: total items,
active items, items with service due, the total value of your gear and of your
wanted gear, and your most recent items.

Select several items to act on them together: **Retire Equipment** or
**Reactivate**, **Edit tags**, **Move to location**, **Print labels** (passport
labels for cylinders), or **Delete**.

### Sharing gear between diver profiles

With more than one diver profile, **Share with...** lets other profiles add an
item to their dives and log its servicing, while only the owner can delete it.
**Transfer to...** makes another profile the owner; past dives keep the gear.
See [Diver Profile & Multi-Diver](diver-profile.md).

## See also

- [Cylinder Passports](cylinder-passports.md): spec, fills and tags for your cylinders
- [Logging Dives](dive-logging.md): tanks and equipment on a dive
- [Trips](trips.md): the gear you pack for a trip
- [Weight Planner](weight-planner.md): how your gear feeds the weight estimate
- [Settings](settings.md): notifications and the rest of the settings
