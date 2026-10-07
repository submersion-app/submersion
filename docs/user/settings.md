# Settings

Settings is where you tune Submersion to match how you dive: the units you read,
the decompression model defaults, how screens look, and where your data lives.

> [!NOTE]
> **Where to find it:** Open **Settings** from the navigation rail (or the **More**
> menu on a phone). The page is organized into labelled sections — Units,
> Decompression, Appearance, Notifications, Manage, Data, Diver Profile, and About.

Almost everything here is stored **per diver**. Each diver profile keeps its own
units, decompression defaults, theme, and layout, so switching the active diver
switches the whole look and feel with it. The handful of genuinely device-level
items (cloud-sync credentials, the database storage location, debug mode) are
called out where they appear.

<!-- screenshot: images/settings/settings-home.png — settings home -->

## Units & formats

Sets how every measurement and timestamp in the app is displayed. Changing a unit
is purely a display choice — your dives are stored in metric internally, so you can
switch back and forth without altering any data.

A **Quick Select** control at the top applies a whole system at once — **Metric**,
**Imperial**, or **Custom** (mix individual units freely). The individual units are:

| Setting | Options | Default |
|---------|---------|---------|
| **Depth** | Meters, Feet | Meters |
| **Temperature** | Celsius, Fahrenheit | Celsius |
| **Pressure** | Bar, PSI | Bar |
| **Volume** | Liters, Cubic Feet | Liters |
| **Weight** | Kilograms, Pounds | Kilograms |
| **Altitude** | Meters, Feet | Meters |
| **SAC rate** | Volume per minute (L/min, ft³/min), Pressure per minute (bar/min, psi/min) | Volume per minute |

Below the units, **Time & date format** sets the clock and calendar style:

| Setting | Options | Default |
|---------|---------|---------|
| **Time format** | 12-hour, 24-hour | 12-hour |
| **Date format** | Several presets (for example `Jan 5 2026`, `5 Jan 2026`, `2026-01-05`) | `Jan 5 2026` |

> [!TIP]
> Picking **Metric** or **Imperial** in Quick Select sets every unit in one tap.
> Reach for **Custom** only when you want a blend — say, depth in metres but
> pressure in psi.

<!-- screenshot: images/settings/units.png — units settings -->

## Decompression

Controls the defaults for Submersion's built-in Bühlmann ZH-L16C decompression
model and how computer-reported figures are treated. These are starting points for
new dives and for on-demand recalculation; they do not retroactively rewrite a
logged profile.

### Gradient factors

Tap **Current settings** to open the gradient-factor picker. Choose a quick preset
or set your own with the **GF Low** and **GF High** sliders (each adjustable from
15 to 100):

| Preset | GF Low / High | Character |
|--------|---------------|-----------|
| **High** | 50/75 | Most conservative — longer, deeper stops |
| **Medium** | 50/85 | Balanced |
| **Low** | 50/95 | Least conservative — shorter stops |
| **Custom** | Your values | Set both sliders by hand |

> [!NOTE]
> A lower GF is *more* conservative. New divers start on the **Medium** preset
> (**GF 50/85**), and profiles you calculate use that default until you change it
> here.

### Data source preferences

When a dive computer records its own decompression figures, you can choose whether
Submersion shows those or its own calculated values. Each metric has an independent
selector — **Calculated** or **Dive Computer**:

| Source | Applies to |
|--------|-----------|
| **NDL source** | No-decompression limit |
| **Ceiling source** | Decompression ceiling |
| **TTS source** | Time to surface |
| **CNS source** | Central-nervous-system oxygen toxicity |

When a metric is set to **Dive Computer**, Submersion uses the computer's data
where it exists and falls back to its own calculation when the computer didn't
record that figure. You can still flip any metric per dive from the profile legend
without changing this default. See [Dive Profiles](dive-profiles.md).

### Narcosis

| Setting | What it does | Default |
|---------|--------------|---------|
| **Oxygen is narcotic** | Counts oxygen alongside nitrogen when estimating narcosis (END / equivalent narcotic depth) | On |
| **END limit** | The equivalent narcotic depth you treat as your personal narcosis ceiling, adjustable from 20 to 50 m (66–164 ft) | 30 m (98 ft) |

## Appearance

Controls the app's look and the layout of every list and detail screen. Appearance
is a lightweight hub: a few **General** choices, then a tile for each major section
that opens that section's own appearance options.

<!-- screenshot: images/settings/appearance.png — appearance settings -->

### General

| Setting | What it does |
|---------|--------------|
| **Current theme** | Opens the theme gallery (see below) |
| **Theme mode** | **System** (follow the device), **Light**, or **Dark** |
| **Language** | App language, or **System** to follow the device locale |
| **Map style** | Basemap for maps: **OpenStreetMap**, **OpenTopoMap**, or **ESRI Satellite** |
| **Navigation** | Customize the phone bottom bar (see [Navigation & layout](#navigation--layout)) |

The **theme gallery** is a grid of selectable visual themes — **Submersion**,
**Console**, **Tropical**, **Minimalist**, and **Deep** — each pairing a colour
palette and typography. Tap one to apply it; theme mode (light/dark/system) still
applies on top of your choice.

### Section appearance

Under **Sections**, each major area — **Dives**, **Sites**, **Buddies**, **Trips**,
**Equipment**, **Dive Centers**, **Certifications**, and **Courses** — has its own
appearance page. What you can set depends on the section, but typically includes:

- **List view** — the default layout for that section's list: **Detailed**,
  **Compact**, or **Table** (Certifications and Courses offer Detailed and Table).
- **List fields** — which columns or card fields appear, and in what order (opens
  the column editor described in [Navigation & layout](#navigation--layout)).
- **Card colouring** *(Dives)* — tint dive cards by a numeric attribute: **None**,
  **Depth**, **Duration**, or **Temperature**, using a gradient preset (**Ocean**,
  **Thermal**, **Sunset**, or **Forest**) or a custom two-colour gradient.
- **Map background** *(Dives, Sites)* — show a faint site map behind cards.
- **Table mode** — toggle the details pane, and for dives the inline **profile
  panel** and **data-source badges**.
- **Dive profile** *(Dives)* — the chart's right-hand axis metric, and markers for
  max depth, tank-pressure thresholds, gas switches, and the gas timeline. A
  **Default visible metrics** tile sets which overlays (depth, temperature,
  pressure, SAC, events, ceiling, ascent-rate colouring, NDL, TTS, CNS, OTU,
  ppO₂/ppN₂/ppHe, gas density, GF, surface GF, mean depth) are switched on for new
  profiles. See [Dive Profiles](dive-profiles.md).
- **Dive details** *(Dives)* — reorder and hide the sections on the dive detail
  screen.

> [!TIP]
> Card colouring turns a long dive list into a quick visual scan — colour by depth
> to spot your deeper dives at a glance, or by temperature to find the cold ones.

## Navigation & layout

Customizes where things sit on screen.

- **Navigation customization** (Settings → Appearance → Navigation) controls the
  phone **bottom bar**. **Home** (first slot) and **More** (last slot) are pinned;
  you choose which destinations fill the slots between them and drag them into
  order. A **Reset** button restores the defaults. On wide screens the side
  navigation rail shows every destination and is unaffected.
- **Column / field configuration** (reached from a section's **List fields** tile)
  controls each list. In **Table** view you choose which columns are visible,
  reorder them, pin columns, and save named presets. In **card** views you assign
  fields to the title, subtitle, and stat slots. A **Reset to default** option is
  always available.
- **Dive detail sections** (Settings → Appearance → Dives → Dive details) reorders
  and hides the sections of the dive detail screen. A short list of core sections
  is always shown.

## Notifications

Optional reminders for upcoming equipment service. Submersion checks your gear's
service schedule and certification dates and can notify you before something comes
due. See [Equipment](equipment.md) and [Certifications & Courses](certifications-and-courses.md).

| Setting | What it does | Default |
|---------|--------------|---------|
| **Enable service reminders** | Turns on local notifications (prompts for permission the first time) | On |
| **Remind before due** | How many days ahead to alert — pick any of **7**, **14**, **30** days | 7, 14, 30 |
| **Reminder time** | The time of day reminders are delivered | 09:00 |

> [!NOTE]
> Reminders are delivered by your device, so they need notification permission
> granted to Submersion. If reminders never arrive, check your system notification
> settings for the app.

## Manage

Curators for the reusable lists Submersion offers when you log a dive. Editing them
here keeps your pick-lists tidy everywhere they appear.

| Item | What it manages |
|------|-----------------|
| **Dive types** | The dive-type categories (recreational, training, technical, and any you add) |
| **Tank presets** | Saved tank configurations — size and working pressure — for quick reuse |
| **Species** | The marine-life library used when recording sightings — see [Marine Life & Photos](marine-life-and-photos.md) |
| **Tags** | Custom tags for organizing and filtering dives |

When you keep more than one diver profile, a **Shared data** section also appears,
letting you share sites and trips across profiles and bulk-share everything you
already have.

## Data

Backup, sync, storage, and data-repair tools.

| Item | What it does |
|------|--------------|
| **Site match sensitivity** | How eagerly Submersion suggests an existing site when you log a dive: **Strict**, **Balanced**, or **Relaxed** |
| **Backup** | Create and restore full backups — see [Backup & Restore](backup-and-restore.md) |
| **Cloud Sync** | Keep devices in sync through your own cloud storage — see [Multi-Device Sync](multi-device-sync.md) |
| **Database storage** | Where the database file lives (app default, or a folder you choose) |
| **Offline maps** | Download map regions for use without a connection |
| **Fix dive times** | Bulk-adjust the timestamps of imported dives (see below) |
| **Media sources** | Where photos and files come from — photo library, files, URLs, and services |

> [!NOTE]
> **Cloud Sync now appears on every platform.** The page itself shows the backends
> your platform supports — iCloud on Apple devices, S3-compatible storage
> everywhere (iOS, Android, macOS, Windows, Linux). Sync credentials are stored in
> the device keychain, not in your dive database. See [Multi-Device Sync](multi-device-sync.md).

## Tools

A few of the **Data** entries are repair and utility tools rather than preferences:

- **Fix dive times** corrects timestamps on imported dives — handy when a batch
  came in shifted by a time-zone offset. Submersion stores dive times as their
  wall-clock value, so a dive logged at 14:00 local reads 14:00 everywhere; this
  tool fixes older imports that landed offset.
- **Data source preferences** (under [Decompression](#decompression)) switch each
  decompression metric between the dive computer's figures and Submersion's own
  calculations.
- **Offline maps** and **Media sources** (under [Data](#data)) manage downloaded
  map regions and where imported photos and files come from.
- **Debug logs** — when debug mode is on, a **Debug** section appears with a log
  viewer for troubleshooting and bug reports. See [Debug Mode](debug-mode.md).

## Diver profile

Opens your diver profile, where you switch the active diver, add or remove profiles,
and edit personal, emergency-contact, medical, insurance, and certification details.
Because almost every setting on this page is per-diver, the active diver chosen here
determines which set of preferences is in effect. Full details are in
[Diver Profile](diver-profile.md).

## About

App information and housekeeping.

| Item | What it does |
|------|--------------|
| **About Submersion** | App name, version, and description |
| **Open-source licenses** | Licenses for the libraries Submersion uses |
| **Report issue** | Opens the project's issue tracker |
| **Check for updates** | On non-store builds, checks for and installs new versions |

> [!TIP]
> Tapping the version number five times enables **debug mode**, which adds a
> **Debug** section with detailed logs. See [Debug Mode](debug-mode.md).

## See also

- [Diver Profile](diver-profile.md) — manage divers and the per-diver data behind these settings
- [Dive Profiles](dive-profiles.md) — how the decompression and overlay settings shape the chart
- [Backup & Restore](backup-and-restore.md) — protect your dive log
- [Multi-Device Sync](multi-device-sync.md) — keep every device in step
