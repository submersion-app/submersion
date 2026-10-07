# Logging Dives

Every dive you record lives in the **Dives** tab. This page covers logging a dive
by hand in the redesigned dive form, every field you can fill in, and how to find,
sort, filter, and bulk-edit dives once you have a few in your log.

> [!NOTE]
> **Where to find it:** Open the **Dives** tab, then tap the **Log Dive** button
> (the **+** floating button) and choose **Log Dive Manually**. To edit an existing
> dive, open it from the list and tap **Edit**. To pull dives off a dive computer
> instead, choose **Import from Computer** &mdash; see [Dive Computers](dive-computer.md).

<!-- screenshot: images/dive-logging/entry-form.png — dive entry form -->

## The quick version

You do not have to fill in everything. A useful dive entry takes only a few
seconds:

1. In the **Dives** tab, tap **Log Dive** &rarr; **Log Dive Manually**.
2. In the first section, **The Dive**, type your **Max Depth** and **Bottom Time**
   into the two big number boxes.
3. Tap **Entry** to set the date and time you went in.
4. Tap **Site** and pick (or create) the [dive site](dive-sites.md).
5. Tap **Save**.

Everything else &mdash; gas, conditions, buddies, photos &mdash; is optional and
can be added now or later. The dive number is filled in for you automatically.

## How the dive form is organised

The form is split into collapsible **sections**, each leading with a strip of
large "hero" numbers for the values you care about most. This is the same layout
used across Submersion's editors, so once you learn one form you know them all.

The sections, in order, are:

| Section | What it holds |
|---------|---------------|
| **The Dive** | Depth, time, dive number, entry/exit, dive site, and the profile. Always open. |
| **Gas & Gear** | Dive mode, tanks and gas mixes, equipment, and weights. |
| **Conditions** | Water and air temperature, visibility, current, water type, weather. |
| **Trip** | The [trip](trips.md) and [dive center](buddies-and-dive-centers.md) for this dive. |
| **Buddies** | The people you dived with and their roles. |
| **Experience** | Star rating, marine-life sightings, notes, and tags. |
| **Training Course** | Links the dive to a [course](certifications-and-courses.md). Hidden until added. |
| **Custom Fields** | Your own named fields. Hidden until added. |

Each section behaves the same way:

- **Open** sections show every field, with a chevron to collapse them.
- **Collapsed** sections that contain data show a one-line summary (for example,
  `Salt Water · 24°C · Good`), so you can see what is inside at a glance.
- **Collapsed and empty** sections show a faint invitation such as
  *"Add conditions - water, visibility, weather"* &mdash; tap it to open and fill in.
- A section with an invalid value gets a coloured edge and an issue count, and
  re-opens automatically if you try to save.

When you start a **new** manual dive, **The Dive** and **Gas & Gear** open first.
For a dive you downloaded or imported, only **The Dive** opens, because the
computer has already filled in most of the rest.

> [!TIP]
> The **Training Course** and **Custom Fields** sections are tucked behind an
> **+ Add** row at the bottom of the form until you need them. Tap **+ Add** to
> reveal either one.

## The Dive: depth, time, and site

This section is always open and owns the core facts of the dive.

### Hero numbers

Three large boxes sit at the top:

| Box | Unit | Meaning |
|-----|------|---------|
| **Max Depth** | m / ft | The deepest point of the dive. |
| **Bottom Time** | min | Time spent **at depth**, not counting your descent and ascent. |
| **Avg Depth** | m / ft | Your average depth over the whole dive. |

Tap any box to type a value directly &mdash; there is no separate pop-up editor.

> [!NOTE]
> **Bottom Time vs. Runtime.** Submersion treats these as two different things.
> **Bottom Time** is your time at depth (it excludes the swim down and back up).
> **Runtime** is the total time from entry to exit, found in the rows below. SAC
> &mdash; your [Surface Air Consumption](glossary.md) rate &mdash; is calculated from
> runtime, so a dive's gas-use figures are most accurate when both your gas
> pressures and your entry/exit times (or runtime) are filled in.

### Detail rows

Below the hero numbers:

| Row | Notes |
|-----|-------|
| **Dive #** | The dive's sequential number. Filled in automatically (see below); editable. |
| **Entry** | The date and time you entered the water. Tap to pick. |
| **Exit** | The date and time you left the water. Optional; if set, it can drive Runtime. |
| **Surface interval** | Time on the surface since your previous dive. Shown automatically when editing, calculated from the dive before this one. |
| **Runtime** | Total dive time, entry to exit, in minutes. |
| **Site** | The [dive site](dive-sites.md). Tap to pick an existing site or create a new one. |

### Automatic dive numbering

When you create a new dive, Submersion suggests the **next** dive number for you,
based on the highest number already in your log. You can overwrite it, or clear it
to have a number assigned on save. When you import a batch of dives from a
computer, they are numbered in **date order**, so dives logged out of sequence
still come out numbered correctly.

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

The bottom of this section shows the **dive profile** &mdash; the depth-over-time
graph. If the dive came from a computer it already has a profile and shows the
number of recorded points, with an **Edit Profile** button. A dive logged by hand
has no profile, but you can tap **Draw Profile** to sketch one. If Submersion spots
suspicious depth spikes, it surfaces a *"potential outlier"* chip that jumps
straight into cleanup. Profiles, decompression data, and tissue loading are
covered in depth on [Dive Profiles & Deco](dive-profiles.md).

> [!TIP]
> When a dive has a profile, the depth and time boxes show a small suggestion with
> the value calculated from the profile. Tap it to copy that value into the field
> &mdash; handy if you typed a rough number and later attached the real data.

## Gas & Gear: tanks, gas, equipment, and weights

<!-- screenshot: images/dive-logging/tanks-gas.png — tanks & gas section -->

### Dive mode

At the top, a three-way selector sets the **dive mode**, which changes how
Submersion calculates oxygen exposure and gas use:

| Mode | Full name | Meaning |
|------|-----------|---------|
| **OC** | Open Circuit | Standard scuba &mdash; you breathe from a tank and exhale into the water. |
| **CCR** | Closed Circuit Rebreather | The loop recycles your gas and holds a target oxygen pressure (setpoint). |
| **SCR** | Semi-Closed Rebreather | A partial loop that meters fresh gas in at a fixed rate. |

Choosing **CCR** or **SCR** reveals a dedicated settings panel (see
[Technical and rebreather diving](#technical-and-rebreather-diving) below).

### Tanks

Each dive starts with one tank. Every tank rests as a compact card showing its
**Pressure** (start &rarr; end), **Mix**, and **Volume**, with its number and role
underneath. Tap **Edit** on a card to expand the full editor in place, and **Done**
to collapse it. Tap **+ Add Tank** to add another cylinder; remove an extra tank
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

The tank's gas name is derived from the mix you enter: 21% oxygen reads as **Air**,
anything above that as **EAN** (enriched-air nitrox, e.g. `EAN32`), any helium
content as **Tx** (trimix, e.g. `Tx 18/45`), and pure oxygen as **O2**. Below the
gas mix, Submersion shows the **MOD** ([Maximum Operating Depth](glossary.md), at a
partial pressure of oxygen of 1.4) and **MND** for the mix.

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
| **O2 Supply** | The oxygen cylinder on a closed-circuit rebreather. |

> [!TIP]
> You can set a **default tank preset** in [Settings](settings.md) so every new tank
> (and, optionally, imported dives missing tank data) starts from your usual
> cylinder instead of a generic one.

### Equipment

Tap **+ Add** to attach individual gear from your [Equipment](equipment.md) locker, or
**Use Set** to add a saved kit in one go. Once items are listed you can save the
current selection as a new set with **Save as Set**, or **Clear All**.

### Weight

Record how much weight you wore. Each entry has an amount and a **type** &mdash;
Weight Belt, Integrated Weights, Ankle Weights, Trim Weights, Backplate Weights, or
Mixed. Tracking weight per dive helps you dial in your buoyancy across exposure
suits and water types.

## Conditions: water, visibility, current, and weather

This section leads with three hero boxes: **Water Temp**, **Visibility** (a summary
of the dropdown below), and **Air Temp**. Below them are two groups of fields.

### Environment

| Field | Options |
|-------|---------|
| **Dive Type** | Your dive category (Recreational, Wreck, Cave, Night, Drift, and so on). The list is customisable. |
| **Visibility** | Excellent (>30 m / >100 ft), Good (15&ndash;30 m / 50&ndash;100 ft), Moderate (5&ndash;15 m / 15&ndash;50 ft), Poor (<5 m / <15 ft), or Unknown. |
| **Water Type** | Salt Water, Fresh Water, or Brackish. |
| **Current Direction** | A compass direction (N, NE, E, …), Variable, or None. |
| **Current Strength** | None, Light, Moderate, or Strong. |
| **Swell Height** | Surface swell, in your depth units. |
| **Altitude** | Height above sea level, for altitude dives. Entering a value warns you when the site is high enough to need altitude-adjusted decompression. |
| **Entry Method** / **Exit Method** | How you got in and out: Shore Entry, Boat Entry, Back Roll, Giant Stride, Seated Entry, Ladder, Platform, Jetty/Dock, or Other. |

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
dive's date, Submersion suggests it for you &mdash; tap **Use** to accept. The
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

## Experience: rating, sightings, notes, and tags

| Field | Notes |
|-------|-------|
| **Rating** | A one-to-five star rating for the dive. |
| **Marine Life** | Log species you saw, with a count and notes per sighting. Sightings link to the species catalogue &mdash; see [Marine Life & Photos](marine-life-and-photos.md). |
| **Notes** | Free-text notes about the dive. |
| **Tags** | Free-form labels (for example `shore`, `training`, `photography`) you can later filter and search by. |

Marking a dive as a **favorite** and managing its photos are handled from the
dive's detail view; see [Marine Life & Photos](marine-life-and-photos.md) for media.

## Custom fields

Need to record something Submersion does not have a field for &mdash; a permit
number, camera settings, a guide's name? Tap **+ Add** at the bottom of the form,
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
> &mdash; [CNS](glossary.md) (central-nervous-system oxygen toxicity) and
> [OTU](glossary.md) (oxygen tolerance units) &mdash; come from your dive computer or
> dive plan and are shown on [Dive Profiles & Deco](dive-profiles.md) rather than
> typed into this form. The dive form captures the dive's facts; the profile page
> does the decompression analysis.

### CCR settings (closed-circuit rebreather)

| Field | Notes |
|-------|-------|
| **Setpoints** | Your target oxygen partial pressure in bar at three phases: **Low (Desc/Asc)** (typically ~0.7), **High (Bottom)** (~1.2&ndash;1.3), and **Deco** (~1.3&ndash;1.6). |
| **Diluent Gas** | The diluent mix (O2 / He), with quick chips for common diluents. |
| **Scrubber** | The carbon-dioxide scrubber **Type** (for example Sofnolime), its **Rated** life in minutes, and the **Remaining** minutes at the start of the dive. |
| **Loop Volume** | The breathing-loop volume in litres. |

### SCR settings (semi-closed rebreather)

| Field | Notes |
|-------|-------|
| **SCR Type** | **CMF** (Constant Mass Flow), **PASCR** (Passive Addition), or **ESCR** (Electronically Controlled). The fields below adapt to the type. |
| **Injection Rate** / **Assumed VO2** | For CMF: the fresh-gas injection rate (L/min) and your assumed oxygen consumption (L/min). Submersion shows the resulting steady-state loop oxygen fraction. |
| **Addition Ratio** | For PASCR: the gas-addition ratio. |
| **Orifice Size** | For ESCR: the flow-control orifice. |
| **Supply Gas** | The injected gas mix (O2 / He), with chips for common enriched-air mixes. |
| **Measured Loop O2** | Optional **Min**, **Max**, and **Avg** loop oxygen percentages you measured. |
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

<!-- screenshot: images/dive-logging/dive-list-table.png — dive list, table view -->

The **Dives** tab lists your whole log. Tap a dive to open its detail view; tap
**Edit** there to return to the form.

<!-- screenshot: images/dive-logging/dive-detail.png — dive detail page -->

### View modes

Open the **⋮** (more) menu to switch how the list is drawn:

| View | Shows |
|------|-------|
| **Detailed** | A full card per dive: number badge, site and date, two rows of stats, tags, and a mini depth-profile chart. |
| **Compact** | A two-line card with the essentials. |
| **Table** | A spreadsheet with one row per dive and columns you choose (see below). |

Your choice is remembered.

### Sorting

Tap the **sort** control (or a column header in Table view) to order dives by
**Date**, **Site**, **Max Depth**, **Bottom Time**, **Rating**, or **Dive Number**.
Tapping a Table header cycles ascending &rarr; descending &rarr; off; dives missing
that value sort to the end.

### Filtering

The **filter** control opens a sheet covering:

- **Date range** (start and end)
- **Dive type**
- **Dive site**
- **Dive computer**
- **Depth range** (min / max)
- **Bottom Time range** (min / max)
- **Gas mix** &mdash; All, Air (21%), or Nitrox (>21%)
- **Favorites only**
- **Minimum rating** (stars)
- **Buddy name**
- **Tags** (pick any number; a dive matches if it carries any selected tag)

Active filters appear as removable chips above the list. **Apply Filters** runs
them; **Clear All** resets them.

### Search

The **search** control searches your dives by **site**, **buddy**, and **notes**.
For a finer search, the **⋮** menu offers **Advanced Search**, which adds grouped
filters including location, conditions, gas and equipment, rating and tags, and
your own custom fields.

### Selecting and bulk editing

Long-press any dive to enter **selection mode**, then tap to select more (or use
**Select All**). With dives selected you can:

| Action | What it does |
|--------|--------------|
| **Delete** | Removes the selected dives, with an **Undo** option for a few seconds. |
| **Export** | Saves them as a **PDF Logbook**, **CSV** spreadsheet, or **UDDF** (Universal Dive Data Format) file. See [Import / Export](import-export.md). |
| **Edit** | **Change Trip** (move the dives onto a trip), **Add Tags**, or **Remove Tags** in bulk. |

### Customising the table columns

In **Table** view, open the column picker to choose which columns appear. Columns
are grouped by category (Core, Environment, Gas/Tank, Weight, Equipment, Deco,
Physiology, Rebreather, People, Location, Trip, Rating, Metadata). For each visible
column you can drag to reorder it, **pin** it to the left so it stays put while you
scroll, or remove it; drag a header's edge to resize. **Dive #** and **Site** are
pinned by default.

The columns shown out of the box are: **Dive #**, **Site**, **Date/Time**, **Dive
Type**, **Max Depth**, **Avg Depth**, **Runtime**, **Surface Interval**, **Primary
Gas**, **Start Pressure**, **End Pressure**, **SAC Rate**, **Water Temp**,
**Visibility**, **Current Strength**, **Entry Method**, **Buddy**, **Dive Master**,
**Trip**, **Rating**, **Tags**, and **Notes**.

## See also

- [Your first dive](first-dive.md) &mdash; a guided walk-through of logging dive one.
- [Dive Profiles & Deco](dive-profiles.md) &mdash; profiles, gradient factors, and oxygen tracking.
- [Dive Computers](dive-computer.md) &mdash; downloading dives from a computer or watch.
- [Import / Export](import-export.md) &mdash; bringing dives in from files and exporting your log.
- [Glossary](glossary.md) &mdash; SAC, MOD, MND, CNS, OTU, GF, and other terms.
