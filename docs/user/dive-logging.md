# Logging Dives

Every dive you record lives in the **Dives** tab. This page covers logging a dive
by hand in the dive form, every field you can fill in, and how to find,
sort, filter, and bulk-edit dives once you have a few in your log.

> [!NOTE]
> **Where to find it:** Open the **Dives** tab, then tap the **Log Dive** button
> (the **+** floating button) and choose **Log Dive Manually**. To edit an existing
> dive, open it from the list and tap **Edit**. To pull dives off a dive computer
> instead, choose **Import from Computer** (see [Dive Computers](dive-computer.md)).

<!-- screenshot: images/dive-logging/entry-form.png: dive entry form -->

## The quick version

You do not have to fill in everything. A useful dive entry takes only a few
seconds:

1. In the **Dives** tab, tap **Log Dive** &rarr; **Log Dive Manually**.
2. In the first section, **The Dive**, fill in **Max Depth** and **Bottom Time**.
3. Tap **Entry** to set the date and time you went in.
4. Tap **Site** and pick (or create) the [dive site](dive-sites.md).
5. Tap **Save**.

Everything else (gas, conditions, buddies, photos) is optional and can be added
now or later. The dive number is filled in for you automatically.

## How the dive form is organised

The form is split into collapsible **sections** of labelled rows. This is the
same layout used across Submersion's editors, so once you learn one form you
know them all.

The sections, in order, are:

| Section | What it holds |
|---------|---------------|
| **The Dive** | Name and number, entry and exit, depth and time, dive site, dive types, and the profile. Always open. |
| **Gas & Gear** | Dive mode, tanks and gas mixes, equipment, and weights. |
| **Conditions** | Water and air temperature, visibility, current, water type, weather. |
| **Trip** | The [trip](trips.md) and [dive center](buddies-and-dive-centers.md) for this dive. |
| **Buddies** | The people you dived with and their roles. |
| **Experience** | Star rating, marine-life sightings, notes, and tags. |
| **Statistics** | Whether this dive counts in your statistics. Opens by itself when the dive is excluded. |
| **Training Course** | Links the dive to a [course](certifications-and-courses.md). Hidden until added. |
| **Custom Fields** | Your own named fields. Hidden until added. |

Each section behaves the same way:

- **Open** sections show every field, with a chevron to collapse them.
- **Collapsed** sections that contain data show a one-line summary (for example,
  `Salt Water · 24°C · Good`), so you can see what is inside at a glance.
- **Collapsed and empty** sections show a faint invitation such as
  *"Add conditions - water, visibility, weather"*; tap it to open and fill in.
- A section with an invalid value gets a coloured edge and an issue count, and
  re-opens automatically if you try to save.

When you start a **new** dive, **The Dive** and **Gas & Gear** open first. When
you edit an existing dive, only **The Dive** opens, and you expand the others as
you need them.

> [!TIP]
> The **Training Course** and **Custom Fields** sections are tucked behind an
> **+ Add** row at the bottom of the form until you need them. Tap **+ Add** to
> reveal either one.

## The Dive: depth, time, and site

This section is always open and owns the core facts of the dive.

The rows, in order:

| Row | Notes |
|-----|-------|
| **Name** | An optional name for the dive. |
| **Dive #** | The dive's sequential number. Filled in automatically (see below); editable. |
| **Entry** | The date and time you entered the water. Tap to pick. |
| **Exit** | The date and time you left the water. Optional; with both entry and exit set, Submersion fills in **Runtime**. |
| **Surface interval** | Time on the surface since your previous dive, calculated from the dive before this one. Shown when editing. |
| **Max Depth** | The deepest point of the dive, in m or ft. |
| **Avg Depth** | Your average depth over the whole dive. |
| **Bottom Time** | Time from leaving the surface to the start of your final ascent, in minutes: the descent counts, the ascent and shallow stops do not. |
| **Runtime** | Total dive time, entry to exit, in minutes. |
| **Site** | The [dive site](dive-sites.md). Tap to pick an existing site or create a new one. |
| **Dive Types** | One or more [dive types](#tags-and-dive-types). Picking a site can add types the site usually brings. |

> [!NOTE]
> **Bottom Time vs. Runtime.** Submersion treats these as two different things.
> **Bottom Time** runs from leaving the surface to the start of your final ascent
> (the descent counts; the ascent and safety stop do not).
> **Runtime** is the total time from entry to exit. Your SAC
> ([Surface Air Consumption](glossary.md)) rate is calculated from runtime, so a
> dive's gas-use figures are most accurate when both your gas pressures and your
> entry and exit times (or runtime) are filled in.

### Automatic dive numbering

When you create a new dive, Submersion suggests the **next** dive number for you,
based on the highest number already in your log. You can overwrite it, or clear it
to have a number assigned on save. When you import a batch of dives from a
computer, they are numbered in date order, so dives logged out of sequence
still come out numbered correctly.

To check or repair the numbering, open the **Dives** list's overflow menu and
choose **Dive Numbering**. It shows how many dives are numbered and any gaps,
and offers **Assign missing numbers** (numbers unnumbered dives after the last
numbered one) and **Renumber all dives** (renumbers everything by date and time,
starting from a number you choose).

### Working with the dive site

Tapping **Site** opens a picker where you can search your saved sites or create a
new one. When you start a **new** dive, Submersion reads your device's location in
the background and floats the nearest sites to the top of the picker
(*"Nearby sites first"*). If a saved site has coordinates, its location is shown
under the row.

If the dive already has **photos** with GPS tags, Submersion can offer to create a
site from that location, or add the coordinates to the site you picked. See
[Marine Life & Photos](marine-life-and-photos.md) for photo handling.

### The dive profile

The bottom of this section shows the **dive profile**, the depth-over-time
graph. If the dive came from a computer it already has a profile and shows the
number of recorded points, with an **Edit Profile** button. A dive logged by hand
has no profile, but you can tap **Draw a profile** to sketch one. If Submersion spots
suspicious depth spikes, it surfaces a *"potential outlier"* chip that jumps
straight into cleanup. Profiles, decompression data, and tissue loading are
covered in depth on [Dive Profiles & Deco](dive-profiles.md).

> [!TIP]
> When a dive has a profile, the depth and time rows show a small suggestion with
> the value calculated from the profile. Tap it to copy that value into the field,
> which is handy if you typed a rough number and later attached the real data.

## Gas & Gear: tanks, gas, equipment, and weights

<!-- screenshot: images/dive-logging/tanks-gas.png: tanks & gas section -->

### Dive mode

At the top, a four-way selector sets the **dive mode**, which changes how
Submersion calculates oxygen exposure and gas use:

| Mode | Full name | Meaning |
|------|-----------|---------|
| **OC** | Open Circuit | Standard scuba: you breathe from a tank and exhale into the water. |
| **CCR** | Closed Circuit Rebreather | The loop recycles your gas and holds a target oxygen pressure (setpoint). |
| **SCR** | Semi-Closed Rebreather | A partial loop that meters fresh gas in at a fixed rate. |
| **Gauge** | Gauge | Depth and time only; no gas or decompression tracking. The tank controls are hidden. |

Choosing **CCR** or **SCR** reveals a dedicated settings panel (see
[Technical and rebreather diving](#technical-and-rebreather-diving) below).

### Tanks

Each dive starts with one tank. Every tank rests as a compact card showing its
**Pressure** (start &rarr; end), **Mix**, and **Volume**, with its number and role
underneath. Tap **Edit** on a card to expand the full editor in place, and **Done**
to collapse it. Tap **Add Tank** to add another cylinder; remove an extra tank
with the trash icon (the last tank cannot be removed).

The expanded tank editor holds:

| Field | Notes |
|-------|-------|
| **Tank Preset** | Pick a standard cylinder (for example AL80, HP100) to fill in volume, working pressure, and material at once. Your own saved presets appear first, marked with a star. |
| **Role** | What the cylinder is for (see roles below). |
| **Volume** | Cylinder size. In metric this is water volume in litres (L); in imperial it is gas capacity in cubic feet (cuft). |
| **Material** | Aluminum, Steel, or Carbon Fiber. Optional. |
| **Working P** | The cylinder's rated working pressure. |
| **Gas Mix** | Oxygen (O2) and helium (He) percentages; nitrogen (N2) is shown automatically as the remainder. Tap a chip for a common mix, or type the numbers. |
| **MND** | For trimix only: type a target [Maximum Narcotic Depth](glossary.md) and Submersion back-calculates the helium needed. |
| **Start Pressure** / **End Pressure** | Your cylinder pressure at the start and end of the dive. These drive your SAC and gas-used figures. |

**Fill from my cylinders.** To fill a tank from a cylinder you own, open the
tank and tap **Fill from my cylinders** (the box icon next to the tag scanner),
then choose the cylinder. Submersion copies its size, working pressure, material
and latest recorded fill into the tank and adds the cylinder to the dive's
**Equipment**. Scanning a cylinder's tag does the same. The button appears when
your gear catalog has a Tank item in use; a cylinder another diver profile has
shared with you is listed with its owner's name.

When a dive computer downloads pressures from an air-integrated transmitter you
have registered, the tank is matched to that cylinder automatically.

The tank's gas name is derived from the mix you enter: 20 to 22% oxygen reads as
**Air**, anything above that as **EAN** (enriched-air nitrox, e.g. `EAN32`), any helium
content as **Tx** (trimix, e.g. `Tx 18/45`), and pure oxygen as **O2**. Below the
gas mix, Submersion shows the **MOD** ([Maximum Operating Depth](glossary.md), at
your working ppO₂ limit, 1.4 by default) and **MND** for the mix.

**Tank roles:**

| Role | Typical use |
|------|-------------|
| **Back Gas** | Your main cylinder(s). |
| **Stage** | A cylinder carried for part of the dive. |
| **Deco** | A decompression gas. |
| **Bailout** | An emergency open-circuit cylinder on a rebreather dive. |
| **Sidemount Left** / **Sidemount Right** | Cylinders worn at your sides. |
| **Pony Bottle** | A small independent reserve. |
| **Diluent** | The diluent cylinder on a closed-circuit rebreather. |
| **O₂ Supply** | The oxygen cylinder on a closed-circuit rebreather. |

> [!TIP]
> You can set a **default tank preset** in [Settings](settings.md) so every new tank
> (and, optionally, imported dives missing tank data) starts from your usual
> cylinder instead of a generic one.

### Tanks or equipment?

Gas & Gear has two lists that can both hold a cylinder. They do different jobs:

| List | What it records | What uses it |
|------|-----------------|--------------|
| **Tanks** | What you breathed from on this dive: size, gas mix, start and end pressure, role | Gas graphs on the profile, gas consumption (SAC and RMV), gas switches, deco and oxygen calculations, and gas statistics |
| **Equipment** | Which items from your gear catalog you used | Each item's dive count, service reminders, gear statistics |

A cylinder in **Equipment** adds no gas data to the dive: adding a Tank item from
your gear catalog, on its own or through a set, does not create a tank. To get
graphs and consumption for it, add it under **Tanks** as well. For a cylinder you
own, being in both lists is the normal case. The tank copies the cylinder's
details when you fill it in and does not stay linked, so later changes to the
cylinder in your catalog do not rewrite past dives.

### Equipment

Tap **+ Add** to attach individual gear from your [Equipment](equipment.md) locker, or
**Use Set** to add a saved kit in one go. Once items are listed you can save the
current selection as a new set with **Save as Set**, or **Clear All**.

### Weight

Record how much weight you wore. Each entry has an amount and a **type**: Weight
Belt, Integrated Weights, Ankle Weights, Trim Weights, Backplate Weights, or
Mixed/Combined. Tracking weight per dive helps you dial in your buoyancy across
exposure suits and water types.

Each weight row can also have an optional **name**, such as "Top pocket" or
"Light canister", typed on the line under its type and amount, to tell apart
weights of the same type. The name shows before the type on the dive's details,
is saved with weight presets, and can be searched with `weights[label ~ "pocket"]`.

## Conditions: water, visibility, current, and weather

This section holds **Water Temp**, **Air Temp** and two groups of fields.

### Environment

| Field | Options |
|-------|---------|
| **Visibility** | The distance you could see, in your depth units. Submersion describes it as excellent, good, moderate or poor using the **Visibility scale** you choose in [Settings](settings.md) (Tropical by default). |
| **Water Type** | Salt Water, Fresh Water, or Brackish. |
| **Current Direction** | A compass direction (North, North-East, East, and so on), Variable, or None. |
| **Current Strength** | None, Light, Moderate, or Strong. |
| **Swell Height** | Surface swell, in your depth units. |
| **Altitude** | Height above sea level, for altitude dives. Entering a value warns you when the site is high enough to need altitude-adjusted decompression. |
| **Entry Method** / **Exit Method** | How you got in and out: Shore Entry, Boat Entry, Back Roll, Front Roll, Giant Stride, Seated Entry, Ladder, Platform, Jetty/Dock, or Other. |

### Weather

Record surface weather, either by hand or automatically:

| Field | Notes |
|-------|-------|
| **Fetch Weather** | Pulls historical weather for the dive's date and site from the Open-Meteo service. Enabled once the dive has a site with coordinates. |
| **Humidity** | Relative humidity, as a percentage. |
| **Wind Speed** / **Wind Direction** | Surface wind, in your wind-speed units and a compass direction. |
| **Surface Pressure** | Atmospheric pressure in millibars (mbar). Standard at sea level is 1013 mbar. |
| **Cloud Cover** | Clear, Partly Cloudy, Mostly Cloudy, or Overcast. |
| **Precipitation** | None, Drizzle, Light Rain, Rain, Heavy Rain, Snow, Sleet, or Hail. |
| **Weather Description** | A free-text note. |

> [!NOTE]
> **Fetch Weather** needs the dive's **date** and a **dive site with coordinates**,
> plus an internet connection. If weather is already filled in, Submersion asks
> before replacing it with the fetched values.

## Trip and dive center

Open the **Trip** section to attach the dive to a [Trip](trips.md) and a
[dive center](buddies-and-dive-centers.md). If a trip's dates already cover this
dive's date, Submersion suggests it for you; tap **Use** to accept. The
trip's date range and the dive center's location appear as captions beneath each
row.

## Buddies

Open the **Buddies** section and add the people you dived with from your
[Buddies](buddies-and-dive-centers.md) list. Each buddy carries a **role** you can
change by tapping it:

- **Buddy**
- **Dive Guide**
- **Instructor**
- **Student**
- **Divemaster**
- **Solo**
- **Rear Guard**
- **Support Diver**
- **Safety Diver**

You can add your own roles in **Settings > Manage > Dive Roles**.

## Experience: rating, sightings, notes, and tags

| Field | Notes |
|-------|-------|
| **Rating** | A one-to-five star rating for the dive. |
| **Species** | Log species you saw, with a count and notes per sighting. Sightings link to the species catalogue (see [Marine Life & Photos](marine-life-and-photos.md)). |
| **Notes** | Free-text notes about the dive. |
| **Tags** | Free-form labels (for example `shore`, `training`, `photography`) you can later filter and search by. See [Tags and dive types](#tags-and-dive-types). |

Marking a dive as a **favorite** and managing its photos are handled from the
dive's detail view; see [Marine Life & Photos](marine-life-and-photos.md) for media.

## Statistics: leaving a dive out

The **Statistics** section controls whether a dive counts in your
[Insights](statistics.md):

- **Exclude from statistics** keeps the dive in your logbook but leaves it out of
  every statistic, including your dive count.
- **Exclude from gas statistics** leaves it out of SAC, RMV and gas mix
  statistics only. Use it when the gas reading is not representative.

When either is on, the section's summary reads **Excluded** or **Gas excluded**.

## Tags and dive types

**Tags** are your own labels. When you create or edit a tag you give it a name and
one of 20 colours, and choose whether it is used for dives, equipment, sites, or
any mix of them. Manage them in **Settings > Manage > Tags**: create, rename,
recolour, delete, or select several and merge them into one (you choose the
resulting name, and every dive and site that carried any of them carries the
merged tag).

**Dive types** describe what kind of dive it was. Submersion has 15 built-in
types (Recreational, Technical, Freedive, Training, Wreck, Cave, Ice, Night,
Drift, Deep, Altitude, Shore, Boat, Liveaboard, and Cavern), and you can add your
own in **Settings > Manage > Dive Types** with a name and an optional short name.
Built-in names cannot be changed. For each type you can choose whether its badge
shows in the dive list and in the dive's header.

## Custom fields

Need to record something Submersion does not have a field for, such as a
permit number, camera settings, or a guide's name? Tap **+ Add** at the bottom of the form,
then **Custom Fields**. Each custom field is a **name** and a **value** (for
example `Camera Settings` = `f/8 ISO400`). Add as many as you like, reorder them by
dragging, and Submersion remembers the names you have used before to suggest them
on future dives.

## Technical and rebreather diving

Submersion records the data tech divers expect. Open-circuit divers can carry
multiple **stage** and **deco** cylinders (see [Tanks](#tanks) above) and log
**trimix** mixes with helium, MOD, and MND. Choosing **CCR** or **SCR** as the
dive mode reveals a settings panel.

> [!NOTE]
> **Decompression detail lives with the profile.** Gradient factors (GF), the
> decompression algorithm, conservatism, ceilings, and oxygen-toxicity tracking
> ([CNS](glossary.md), central-nervous-system oxygen toxicity, and
> [OTU](glossary.md), oxygen tolerance units) come from your dive computer or
> dive plan and are shown on [Dive Profiles & Deco](dive-profiles.md) rather than
> typed into this form. The dive form captures the dive's facts; the profile page
> does the decompression analysis.

### CCR settings (closed-circuit rebreather)

| Field | Notes |
|-------|-------|
| **Setpoints** | Your target oxygen partial pressure in bar at three phases: **Low (Desc/Asc)** (typically ~0.7), **High (Bottom)** (about 1.2 to 1.3), and **Deco** (about 1.3 to 1.6). |
| **Diluent Gas** | The diluent mix (O2 / He), with quick chips for common diluents. |
| **Scrubber** | The carbon-dioxide scrubber **Type** (for example Sofnolime), its **Rated** life in minutes, and the **Remaining** minutes at the start of the dive. |
| **Loop Volume** | The breathing-loop volume in litres. |

### SCR settings (semi-closed rebreather)

| Field | Notes |
|-------|-------|
| **SCR Type** | **CMF** (Constant Mass Flow), **PASCR** (Passive Addition), or **ESCR** (Electronically Controlled). The fields below adapt to the type. |
| **Injection Rate** / **Assumed VO₂** | For CMF: the fresh-gas injection rate (L/min) and your assumed oxygen consumption (L/min). Submersion shows the resulting steady-state loop oxygen fraction. |
| **Addition Ratio** | For PASCR: the gas-addition ratio. |
| **Orifice Size** | For ESCR: the flow-control orifice. |
| **Supply Gas** | The injected gas mix (O2 / He), with chips for common enriched-air mixes. |
| **Measured Loop O₂** | Optional **Min**, **Max**, and **Avg** loop oxygen percentages you measured. |
| **Scrubber** | Same Type / Rated / Remaining fields as CCR. |

## Dives from a dive computer or wearable

Not every dive starts as a blank form. You can download dives from a supported
dive computer or import them from a wearable such as an Apple Watch Ultra, and they
arrive already populated with depth profile, temperature, and (where available)
heart rate and GPS.

- Use **Log Dive** &rarr; **Import from Computer**, or set things up from the
  **Dive Computers** screen. See [Dive Computers](dive-computer.md) and
  [Import / Export](import-export.md).
- An imported dive keeps a record of where it came from (for example **Apple
  Watch**), shown on its detail page.
- If a downloaded dive looks like one you already have, Submersion flags it as a
  probable or possible duplicate and lets you merge the new data (such as a
  heart-rate trace) into the existing dive instead of creating a second copy.

You can open any imported dive in this same form to correct or add details by hand.

## The dive list

<!-- screenshot: images/dive-logging/dive-list-table.png: dive list, table view -->

The **Dives** tab lists your whole log. Tap a dive to open its detail view; tap
**Edit** there to return to the form.

<!-- screenshot: images/dive-logging/dive-detail.png: dive detail page -->

### View modes

Open the list's overflow menu (**⋮**) to switch how the list is drawn:

| View | Shows |
|------|-------|
| **Detailed** | A full card per dive: number badge, site and date, two rows of stats, tags, and a mini depth-profile chart. |
| **Compact** | A two-line card with the essentials. |
| **Table** | A spreadsheet with one row per dive and columns you choose (see below). |

Your choice is remembered. **Settings > Appearance > Dives > Dives List View** sets the
default, and also offers a **Dense** layout with one line per dive.

### Sorting

Tap the **sort** control (or a column header in Table view) to order dives by
**Date**, **Site**, **Max Depth**, **Bottom Time**, **Rating**, or **Dive Number**.
Tapping a Table header cycles ascending &rarr; descending &rarr; off; dives missing
that value sort to the end.

### Filtering

The **filter** control opens a sheet that narrows the list by when (a date
range with presets such as **This year** and **Last 12 months**, and weekdays),
where (dive site, dive center, trip), what (dive type, dive computer, depth and
duration ranges, gas mix, suit thickness, gear and gear attributes), who
(buddy, or **No Buddy Assigned**), and how it went (**Favorites Only**,
minimum rating, tags), plus your custom fields.

Active filters appear as removable chips above the list. The same filter also
scopes [Insights](statistics.md), so the statistics you see match the dives you
filtered to.

### Search

Tap **Search dives** to search your log. Type words to match sites, buddies and
notes, or write a query such as `depth > 30m`; the field suggests what to try.
You can also ask a question in plain words. The search can run **Within filters**
or across **All dives**, **Refine** adds conditions to it, and your recent and
saved searches are offered when you open it again. While you type, **Jump to dive**
lists the newest dives that match across your whole log, ignoring other filters,
and a question about your diving can **Open in Insights**.

### Selecting and bulk editing

Open the list's overflow menu and choose **Select items** to enter selection
mode, then tap dives to select them (or choose a whole date range with
**Select by date range**). With dives selected you can:

| Action | What it does |
|--------|--------------|
| **Delete** | Removes the selected dives, with an **Undo** option for a few seconds. |
| **Export Selected** | Saves them as a **PDF Logbook**, **CSV** spreadsheet, or **UDDF** (Universal Dive Data Format) file. See [Import / Export](import-export.md). |
| **Edit Selected** | Opens the dive form for all of them at once, titled **Edit N dives**. Each field has a switch: turn on the ones to change, and only those are written. Lists such as tags, gear and tanks can be added to, removed from, or replaced; notes can be set or appended. **Apply** asks you to confirm. |
| **Combine** | Merges dives that are really one dive recorded by different computers. See [Dive Computers](dive-computer.md). |

### Customising the table columns

In **Table** view, open the column picker to choose which columns appear. Columns
are grouped by category (Core, Environment, Gas/Tank, Weight, Equipment, Deco,
Physiology, Rebreather, People, Location, Trip, Rating, Metadata). For each visible
column you can drag to reorder it, **pin** it to the left so it stays put while you
scroll, or remove it; drag a header's edge to resize. **Dive #** and **Site** are
pinned by default.

The columns shown out of the box are: **Dive #**, **Site**, **Date/Time**, **Dive
Type**, **Dive Mode**, **Max Depth**, **Avg Depth**, **Runtime**, **Surface
Interval**, **Primary Gas**, **Start Pressure**, **End Pressure**, **SAC Rate**,
**RMV**, **Water Temp**, **Visibility**, **Current Strength**, **Entry Method**,
**Buddy**, **Dive Master**, **Trip**, **Rating**, **Tags**, and **Notes**.

## See also

- [Your first dive](first-dive.md): a guided walk-through of logging dive one.
- [Dive Profiles & Deco](dive-profiles.md): profiles, gradient factors, and oxygen tracking.
- [Dive Computers](dive-computer.md): downloading dives from a computer or watch.
- [Import / Export](import-export.md): bringing dives in from files and exporting your log.
- [Glossary](glossary.md): SAC, MOD, MND, CNS, OTU, GF, and other terms.
