# Logging Dives

Every dive you record lives in the **Dives** tab. This page covers logging a dive
by hand, every field you can fill in on the dive's page, and how to find, sort,
filter, and bulk-edit dives once you have a few in your log.

> [!NOTE]
> **Where to find it:** Open the **Dives** tab, then tap the **Log Dive** button
> (the **+** floating button) and choose **Log Dive Manually**. To edit an existing
> dive, open it from the list and tap the lock (**Unlock to edit**). To pull dives
> off a dive computer instead, choose **Import from Computer** (see
> [Dive Computers](dive-computer.md)).

<!-- screenshot: images/dive-logging/entry-form.png: a new dive's page, ready to edit -->

## The quick version

You do not have to fill in everything. A useful dive entry takes only a few
seconds:

1. In the **Dives** tab, tap **Log Dive** &rarr; **Log Dive Manually**. The dive's
   page opens ready to edit, under the title **Log Dive**.
2. Tap the pencil on the **Dive** card at the top and fill in **Max Depth** and
   **Bottom Time**.
3. Tap **Entry** to set the date and time you went in.
4. Tap **Site** and pick (or create) the [dive site](dive-sites.md).
5. Tap **Save**.

Everything else (gas, conditions, buddies, photos) is optional and can be added
now or later. The dive number is filled in for you automatically.

## Editing a dive

A dive's page is where you read the dive and where you change it. It opens
**locked**, so nothing changes by accident.

1. Tap the lock (**Unlock to edit**) in the bar, or press Cmd+L (Ctrl+L on
   Windows and Linux). The bar now holds **Cancel**, a title such as
   *Editing Punta Venado*, and **Save**.
2. Every card you can change gains a pencil. Tap a card's title row, or its
   pencil, to open its editor in place; tap **Done** to close it again. On the
   **Dive** card at the top, use the pencil.
3. Change as many cards as you like. A dot beside a card's title marks changes
   not yet saved.
4. Tap **Save** (or press Cmd+S / Ctrl+S) to write everything at once. **Save**
   stays greyed out until something has changed.

To leave without saving, tap **Cancel** (or press Esc). If you changed
something, Submersion asks first (**Discard changes?**), with **Keep editing**
and **Discard**. It asks the same when you go back, pick another dive in the
list, switch tabs or quit with changes unsaved. After a save or a cancel the
dive is locked again. While it is unlocked, the arrows to the previous and next
dive do nothing.

Cards that Submersion works out or imports, such as **Deco Status**, **Tissue
Loading** and **Tide**, have no editor. While the dive is unlocked they fade and
say **Calculated** or **Imported**.

### Cards that are not on the page yet

A card with nothing in it, or one you hid, is not shown. While the dive is
unlocked, the **Add** strip under the bar offers each of them as a chip: tap one
to put its card on the page. A card you hid has a dashed outline. A few chips
use a shorter or longer name than their card: **Weights** adds the **Weight**
card, **Species Sightings** the **Species** card, **Media** the
**Photos & Video** card, and **Altitude** the **Altitude Dive** card.

A new dive starts with the **Dive**, **Cylinders**, **Buddies** and **Notes**
cards on the page; the rest wait in the **Add** strip.

### Actions on the whole dive

Some actions change the dive as a whole rather than one card: **Edit profile**
and the profile's outliers button on the **Dive Profile** card, and **Delete**,
**Re-parse raw data**, **Draw a profile** and the like in the dive's menu. They
work only while the dive is unlocked and has nothing unsaved. On a locked dive
they are greyed out under **Unlock to use these**; with changes pending, under
**Save or cancel your changes first**.

## The Dive card: depth, time, and site

The card at the top of the page holds the core facts of the dive. Its editor
has these rows:

| Row | Notes |
|-----|-------|
| **Dive #** | The dive's sequential number. Filled in automatically (see below); editable. |
| **Name** | An optional name for the dive. |
| **Site** | The [dive site](dive-sites.md). Tap to pick an existing site or create a new one. |
| **Entry** | The date and time you entered the water. Tap to pick. |
| **Exit** | The date and time you left the water. Optional; with both entry and exit set, Submersion fills in **Runtime**. |
| **Rating** | A one-to-five star rating for the dive. |
| **Max Depth** | The deepest point of the dive, in m or ft. |
| **Avg Depth** | Your average depth over the whole dive. |
| **Runtime** | Total dive time, entry to exit, in minutes. |
| **Bottom Time** | Time from leaving the surface to the start of your final ascent, in minutes: the descent counts, the ascent and shallow stops do not. |
| **Water Temp** | The water temperature. |
| **Favorite** | Marks the dive as one of your favorites. |
| **Planned dive** | Marks the dive as one you plan to make. A planned dive has no number until it is logged. |

The dive's types and mode show on this card too; change them on the
[Details](#details-dive-types-trip-visibility-and-statistics) and
[Cylinders](#cylinders-dive-mode-tanks-and-gas) cards.

> [!NOTE]
> **Bottom Time vs. Runtime.** Submersion treats these as two different things.
> **Bottom Time** runs from leaving the surface to the start of your final ascent
> (the descent counts; the ascent and safety stop do not).
> **Runtime** is the total time from entry to exit. Your SAC
> ([Surface Air Consumption](glossary.md)) rate is calculated from runtime, so a
> dive's gas-use figures are most accurate when both your gas pressures and your
> entry and exit times (or runtime) are filled in. A dive with only a bottom time
> has no runtime, so it shows no SAC or RMV and adds nothing to your total time or
> longest dive. Fill in its runtime, or its entry and exit times, to count it.
>
> If your computer keeps logging at the surface (some do while the transmitter
> is still pressurised), or starts logging before you descend, that surface time
> is left out of the dive's SAC and RMV. Anything at 1 m or shallower at the very
> start or end of the profile counts as surface time; your runtime and profile
> stay exactly as recorded.
>
> Surface time you spent breathing a cylinder still counts, at the surface: a
> gas switch logged after you surfaced (oxygen on the boat), or a cylinder whose
> pressure keeps falling by 5 bar or more on the surface (a surface swim on the
> regulator). For time after your computer stopped logging, enter the minutes in
> the cylinder's **Breathed at the surface** field, with the end pressure you read
> off its gauge afterwards. The field shows only on a cylinder without a
> transmitter, since a transmitter's last reading was taken before your computer
> stopped and so does not include that gas.

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

> [!TIP]
> When a dive has a profile, the depth and time rows show a small suggestion with
> the value calculated from the profile. Tap it to copy that value into the field,
> which is handy if you typed a rough number and later attached the real data.

## The Dive Profile card

The **Dive Profile** card shows the depth-over-time graph. A dive from a
computer arrives with a profile. A dive logged by hand has none, but you can
choose **Draw a profile** in the dive's menu to sketch one. **Edit profile** on
the card's toolbar opens the profile editor. If Submersion spots suspicious
depth spikes, a warning button with their count appears beside it and opens the
editor straight into outlier cleanup. On a narrow screen, **3D View** and
**3D Seascape** move into the toolbar's **More** menu. Profiles, decompression
data, and tissue loading are covered in depth on
[Dive Profiles & Deco](dive-profiles.md).

## Cylinders: dive mode, tanks, and gas

<!-- screenshot: images/dive-logging/tanks-gas.png: the Cylinders card open -->

### Dive mode

At the top of the card's editor, a four-way selector sets the **dive mode**,
which changes how Submersion calculates oxygen exposure and gas use:

| Mode | Full name | Meaning |
|------|-----------|---------|
| **OC** | Open Circuit | Standard scuba: you breathe from a tank and exhale into the water. |
| **CCR** | Closed Circuit Rebreather | The loop recycles your gas and holds a target oxygen pressure (setpoint). |
| **SCR** | Semi-Closed Rebreather | A partial loop that meters fresh gas in at a fixed rate. |
| **Gauge** | Gauge | Depth and time only; no gas or decompression tracking. The tank controls are hidden. |

Choosing **CCR** or **SCR** reveals a dedicated settings panel (see
[Technical and rebreather diving](#technical-and-rebreather-diving) below).

### Tanks

Each dive starts with one tank. Under **Tanks**, each one rests as a compact row
showing its number and role over its mix, volume and pressures (start &rarr;
end). Tap a tank's row to open its editor in place, and **Done** to close it.
Tap **Add Tank** to add another cylinder; remove an extra tank with the trash
icon (the last tank cannot be removed).

The tank editor holds:

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
| **Twin Set** | A manifolded pair worn on the back, logged as one cylinder with the combined volume. |
| **Stage** | A cylinder carried for part of the dive. |
| **Deco** | A decompression gas. |
| **Bailout** | An emergency open-circuit cylinder on a rebreather dive. |
| **Sidemount Left** / **Sidemount Right** | Cylinders worn at your sides. |
| **Pony Bottle** | A small independent reserve. |
| **Diluent** | The diluent cylinder on a closed-circuit rebreather. |
| **O₂ Supply** | The oxygen cylinder on a closed-circuit rebreather. |
| **Hydrotank** | The Avelo Dive System's cylinder, which takes in water for buoyancy. Its pressure rises with the water, so it shows no gas used or SAC. |

On a dive logged by a Shearwater computer in Avelo mode, the Hydrotank also
shows an **Avelo** summary of what the computer recorded: gas remaining from
start to end, the buoyancy range and average, the computer's own RMV, and the
highest Hydrotank pressure, counting only time below the surface as Shearwater
Cloud does. Its figure is drawn as the tank's contents instead of a pressure
fill: estimated water in blue at the bottom, then the gas left, then the share
of the gas already breathed, with the water's volume beneath it. The estimate
assumes the tank held no water at the start of the dive. Move the cursor along
the profile and the figure follows it, so you can watch the water rise as you
pumped in and fall as you purged.

> [!TIP]
> You can set a **default tank preset** in [Settings](settings.md) so every new tank
> (and, optionally, imported dives missing tank data) starts from your usual
> cylinder instead of a generic one.

### Tanks or equipment?

The **Cylinders** and **Equipment** cards can both hold a cylinder. They do
different jobs:

| List | What it records | What uses it |
|------|-----------------|--------------|
| **Tanks** | What you breathed from on this dive: size, gas mix, start and end pressure, role | Gas graphs on the profile, gas consumption (SAC and RMV), gas switches, deco and oxygen calculations, and gas statistics |
| **Equipment** | Which items from your gear catalog you used | Each item's dive count, service reminders, gear statistics |

A cylinder in **Equipment** adds no gas data to the dive: adding a Tank item from
your gear catalog, on its own or through a set, does not create a tank. To get
graphs and consumption for it, add it on the **Cylinders** card as well. For a cylinder you
own, being in both lists is the normal case. The tank copies the cylinder's
details when you fill it in and does not stay linked, so later changes to the
cylinder in your catalog do not rewrite past dives.

## Equipment

On the **Equipment** card, tap **Add** to attach individual gear from your
[Equipment](equipment.md) locker, or **Use Set** to add a saved kit in one go.
Once items are listed you can save the current selection as a new set with
**Save as Set**, or **Clear All**.

## Weight

On the **Weight** card, tap **Add Weight Entry** to record how much weight you
wore, or **Use preset** to start from a saved set of weights. Each entry has an amount and a **type**: Weight
Belt, Integrated Weights, Ankle Weights, Trim Weights, Backplate Weights, or
Mixed/Combined. Tracking weight per dive helps you dial in your buoyancy across
exposure suits and water types.

Each weight row can also have an optional **name**, such as "Top pocket" or
"Light canister", typed on the line under its type and amount, to tell apart
weights of the same type. The name shows before the type on the dive's details,
is saved with weight presets, and can be searched with `weights[label ~ "pocket"]`.

## Details: dive types, trip, visibility, and statistics

The **Details** card holds the rest of the dive's facts:

| Field | Notes |
|-------|-------|
| **Dive Types** | One or more [dive types](#tags-and-dive-types). Picking a site can add types the site usually brings. |
| **Trip** | The [trip](trips.md) this dive belongs to. If a trip's dates already cover the dive, Submersion suggests it; tap **Use** to accept. |
| **Dive center** | The [dive center](buddies-and-dive-centers.md) you dived with. |
| **Operator** / **Boat** / **Captain** | Who ran the dive, the boat you dived from and its skipper, in your own words. As you type, Submersion suggests the names you have used on earlier dives, newest first. Dives imported from MacDive or a UDDF file arrive with these filled in when the source recorded them. |
| **Training Courses** | Links the dive to a [course](certifications-and-courses.md). |
| **Visibility** | The distance you could see, in your depth units, as one value or a range. Submersion describes it as excellent, good, moderate or poor using the **Visibility scale** you choose in [Settings](settings.md) (Tropical by default). |
| **Water Type** | Salt Water, Fresh Water, or Brackish. |
| **Surface Interval** | Time on the surface since your previous dive, calculated from the dive before this one. Read only. |

Under **Statistics**, two switches control whether the dive counts in your
[Insights](statistics.md):

- **Exclude from statistics** keeps the dive in your logbook but leaves it out of
  every statistic, including your dive count.
- **Exclude from gas statistics** leaves it out of SAC, RMV and gas mix
  statistics only. Use it when the gas reading is not representative.

## Environment: weather and conditions

The **Environment** card records the surface weather and the conditions you met.

### Weather

Record surface weather, either by hand or automatically:

| Field | Notes |
|-------|-------|
| **Fetch Weather** | Pulls historical weather for the dive's date and site from the Open-Meteo service. Enabled once the dive has a site with coordinates. |
| **Air Temp** | The air temperature. |
| **Humidity** | Relative humidity, as a percentage. |
| **Wind Speed** / **Wind Direction** | Surface wind, in your wind-speed units and a compass direction. |
| **Surface Pressure** | Atmospheric pressure in millibars (mbar). Standard at sea level is 1013 mbar. It is kept on the **Altitude Dive** card, and this row takes you there. |
| **Cloud Cover** | Clear, Partly Cloudy, Mostly Cloudy, or Overcast. |
| **Precipitation** | None, Drizzle, Light Rain, Rain, Heavy Rain, Snow, Sleet, or Hail. |
| **Weather Description** | A free-text note. |

> [!NOTE]
> **Fetch Weather** needs the dive's **date** and a **dive site with coordinates**,
> plus an internet connection. If weather is already filled in, Submersion asks
> before replacing it with the fetched values.

### Dive conditions

| Field | Options |
|-------|---------|
| **Current Direction** | A compass direction (North, North-East, East, and so on), Variable, or None. |
| **Current Strength** | None, Light, Moderate, or Strong. |
| **Swell Height** | Surface swell, in your depth units. |
| **Surface Conditions** | The sea state in your own words, such as Calm or Choppy. Values you have used before are suggested as you type. |
| **Entry Method** / **Exit Method** | How you got in and out: Shore Entry, Boat Entry, Back Roll, Front Roll, Giant Stride, Seated Entry, Ladder, Platform, Jetty/Dock, or Other. |

## Altitude Dive

For a dive above sea level, tap **Altitude** in the **Add** strip to add the
**Altitude Dive** card. It records the **Altitude** (height above sea level) and the
**Surface Pressure**. Entering an altitude warns you when the site is high
enough to need altitude-adjusted decompression.

## Buddies

On the **Buddies** card, tap **Add** to pick the people you dived with from your
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

You can add your own roles in **Settings > Manage > Dive Roles**. Use **Set my
role** to record your own role on the dive.

## Species, notes, and tags

| Card | What it holds |
|------|---------------|
| **Species** | The species you saw, with a count and notes per sighting. Tap **Add** to record one. Sightings link to the species catalogue (see [Marine Life & Photos](marine-life-and-photos.md)). |
| **Notes** | Free-text notes about the dive. |
| **Tags** | Free-form labels (for example `shore`, `training`, `photography`) you can later filter and search by. See [Tags and dive types](#tags-and-dive-types). |

Photos and videos are linked on the **Photos & Video** card; see
[Marine Life & Photos](marine-life-and-photos.md).

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

Tap the star next to a type to make it a **favorite**. Favorites come first,
under their own heading, in the dive types checklist, and first in the dive type
filter and the connections search. You can star a type on the Dive Types page or
right in the checklist; a type starred in the open checklist moves up the next
time you open it. Each diver profile keeps its own favorites. Hiding a built-in
type wins over its star: a hidden type stays out of the checklist and keeps its
usual place in the filter and the search. The one exception is a dive that
already has a hidden type: its checklist still offers that type, and lists it
with your favorites if you starred it.

## Custom fields

Need to record something Submersion does not have a field for, such as a
permit number, camera settings, or a guide's name? Add the **Custom Fields**
card from the **Add** strip. Each custom field is a **name** and a **value** (for
example `Camera Settings` = `f/8 ISO400`); tap **Add Field** for each. Add as many
as you like, reorder them by dragging, and Submersion remembers the names you have
used before to suggest them on future dives.

## Technical and rebreather diving

Submersion records the data tech divers expect. Open-circuit divers can carry
multiple **stage** and **deco** cylinders (see [Tanks](#tanks) above) and log
**trimix** mixes with helium, MOD, and MND. Choosing **CCR** or **SCR** as the
dive mode on the **Cylinders** card reveals a settings panel.

> [!NOTE]
> **Decompression detail lives with the profile.** Gradient factors (GF), the
> decompression algorithm, conservatism, ceilings, and oxygen-toxicity tracking
> ([CNS](glossary.md), central-nervous-system oxygen toxicity, and
> [OTU](glossary.md), oxygen tolerance units) come from your dive computer or
> dive plan and are shown on [Dive Profiles & Deco](dive-profiles.md) rather than
> typed in by hand. The cards you edit capture the dive's facts; the profile
> does the decompression analysis.

### CCR settings (closed-circuit rebreather)

| Field | Notes |
|-------|-------|
| **Setpoints** | Your target oxygen partial pressure in bar at three phases: **Low (Desc/Asc)** (typically ~0.7), **High (Bottom)** (about 1.2 to 1.3), and **Deco** (about 1.3 to 1.6). |
| **Diluent Gas** | The diluent mix (O2 / He), with quick chips for common diluents. |
| **Scrubber** | The carbon-dioxide scrubber **Type** (for example Sofnolime), its **Rated** life in minutes, and the **Remaining** minutes at the start of the dive. |
| **Loop Volume** | The breathing-loop volume in litres. |

On a CCR dive the **Cylinders** card shows **Loop use** for gas that left a
cylinder while you were on the loop: plain litres per minute of loop time, with
no depth correction, since oxygen and diluent use do not scale with depth the
way open-circuit breathing does. Gas used after a recorded bailout shows as
SAC and RMV over the bailout instead, and a transmitter lets one cylinder show
both. A cylinder not marked **Diluent** or **O₂ Supply** needs to lose more than
20 bar on the loop to count, because an untouched bailout can lose nearly that
just cooling down in the water.

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

You can open any imported dive and unlock it to correct or add details by hand.

## The dive list

<!-- screenshot: images/dive-logging/dive-list-table.png: dive list, table view -->

The **Dives** tab lists your whole log. Tap a dive to open its page; tap the
lock there (**Unlock to edit**) to change it.

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

Tap **Search dives** to search your log. Type what you remember about a dive,
in any order, for example `ressel in october 2018 with mike` or
`shearwater nitrox shore`. Words reach sites, countries, buddies, boats, operators,
notes, tags, dive types, gear, trips, species, courses and dive computers.

Dates work as you would say them: `14 october 2018`, `october 14, 2018`,
`october 2018`, `oct 2018`, `last year`, `since 2020`, `2018 to 2020`. Month
names also read in the language the app is set to, as you would write them
there, such as `14 de octubre de 2018` or `14. Oktober 2018`. A date shows as a
chip with a calendar icon. A lone year or month, such as `2018` or `october`,
also finds it written in your notes.
Words such as `ccr`, `nitrox`, `ean32`, `shore`, `salt water` and `favourite` find
dives by that setting. Put words in quotes to search for exactly those words.

You can also write a query such as `depth > 30m`; the field suggests what to try.
A number compares with the value as the app shows it: a dive listed at 27.1 ft
is found by `depth = 27.1`, `depth <= 27.1` and `depth >= 27.1`, but not by
`depth < 27.1` or `depth > 27.1`. Type more decimals than the list shows, such
as `depth > 27.15`, to compare with the exact recorded value. A question in
plain words reads numbers the same way: "deeper than 27.1 ft" leaves out a dive
listed at 27.1 ft, and "at least 27.1 ft" includes it.
To find dives missing something, write `trip:none` or `trip is blank`, and `trip is set` for the
opposite. In the rule builder, choose a field such as Trip, then **Trip is not set** at the top of the list.
You can also ask a question in plain words. The search can run **Within filters**
or across **All dives**, **Refine** adds conditions to it, and your recent and
saved searches are offered when you open it again. While you type, **Jump to dive**
lists the newest dives that match across your whole log, ignoring other filters,
and a question about your diving can **Open in Insights**.

Every list searches the same way: tap its search icon and the same field opens
under the app bar, with that list's own query language. Equipment reads
`serialNumber = "SN-9931"`, documents read `type = insurance`, and so on.

To search everything rather than one list, choose **Search** in the navigation
(just above **Settings**; on a phone it starts under **More**, and you can move
it to the bottom bar), press Cmd/Ctrl+K, or tap **Search everything for ...**
under any list's search field to take what you typed there to every record
type. The field reads the same words and queries, with
the same suggestions as you type, and the results are grouped by type: dives,
sites, trips, equipment and sets, buddies, dive centers, certifications, courses,
species, documents, saved plans, GPS tracks and underwater routes. Each result
looks like its row in that type's own list.

A query shows only the types it makes sense for: `depth > 30m` finds dives, sites,
saved plans and underwater routes, and `expires < 2027` finds certifications and
documents. **See all** opens that type's list with the search applied.

### Selecting and bulk editing

Open the list's overflow menu and choose **Select items** to enter selection
mode, then tap dives to select them (or choose a whole date range with
**Select by date range**). With dives selected you can:

| Action | What it does |
|--------|--------------|
| **Delete** | Removes the selected dives, with an **Undo** option for a few seconds. |
| **Export Selected** | Saves them as a **PDF Logbook**, **CSV** spreadsheet, or **UDDF** (Universal Dive Data Format) file. See [Import / Export](import-export.md). |
| **Edit Selected** | Opens one page for all of them at once, titled **Edit N dives**. Each field has a switch: turn on the ones to change, and only those are written. Lists such as tags, gear and tanks can be added to, removed from, or replaced; notes can be set or appended. **Save** asks you to confirm. |
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
