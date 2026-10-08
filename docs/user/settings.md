# Settings

Settings is where you tune Submersion to how you dive: the units you read, the
decompression defaults, how screens look, and where your data lives.

> [!NOTE]
> **Where to find it:** **Settings** in the navigation. The page is a list of
> sections; on a tablet or computer the selected section opens beside the list.

Most settings belong to the active diver profile: each profile keeps its own
units, decompression defaults, and Home screen and section layouts, and they sync
with the profile to your other devices. A few stay with each device, such as the
light or dark mode, the navigation layout, and service reminders.

<!-- screenshot: images/settings/settings-home.png: settings home -->

| Section | What it covers |
|---------|----------------|
| **Diver Profile** | The active diver and profiles; see [Diver Profile](diver-profile.md) |
| **Units** | Units, gas consumption, date and time formats |
| **Decompression** | Gradient factors, oxygen limits, data sources, narcosis |
| **Appearance** | Theme, language, maps, navigation, Home screen and section layouts |
| **Notifications** | Service reminders; see [Equipment](equipment.md#service-reminders) |
| **Manage** | Dive types, presets, catalogs and other reusable lists |
| **Data** | Backup, sync, storage, import preferences and data tools |
| **Safety** | The post-dive review, flying after diving and equipment condition; see [Safety](safety.md) |
| **App Security** | App lock and database encryption |
| **Shared data** | Sharing sites, trips and gear between profiles (with two or more profiles) |
| **Apple HealthKit** | Importing dives from Apple Health (iPhone and iPad only) |
| **Debug** | Logs and diagnostics (when debug mode is on); see [Debug Mode](debug-mode.md) |
| **About** | Version, updates, licences and diagnostics |

## Units

Changing a unit only changes how things are shown: dives are stored in metric,
so you can switch back and forth without altering any data.

**Quick Select** sets every unit at once to **Metric** or **Imperial**, or choose
**Custom** and set each one:

| Setting | Options | Default |
|---------|---------|---------|
| **Depth** | Meters, Feet | Meters |
| **Temperature** | Celsius, Fahrenheit | Celsius |
| **Pressure** | Bar, PSI | Bar |
| **Volume** | Liters, Cubic Feet | Liters |
| **Weight** | Kilograms, Pounds | Kilograms |
| **Altitude** | Meters, Feet | Meters |
| **Distance** | Kilometers, Miles | Kilometers |

More settings in this section:

| Setting | What it does | Default |
|---------|--------------|---------|
| **Gas consumption** | Show **SAC** (pressure drop per minute, works with any logged pressures), **RMV** (volume per minute at the surface, needs a tank volume), or **Both** | Both |
| **Gas calculations** | **Real gas** accounts for compressibility (a 12 L cylinder at 200 bar holds about 2317 L); **Ideal gas** matches hand calculation and dive tables (2400 L). Affects RMV, gas statistics, the planner and the gas calculators. | Real gas |
| **Water type** | The default water type for the planner | Salt water |
| **Default Currency** | For prices and costs | USD |
| **Visibility scale** | How visibility you measured is described: **Tropical**, **Temperate**, **Cold water / Inland**, or **Custom** | Tropical |
| **Coordinate format** | **Decimal degrees**, **Degrees and decimal minutes**, **Degrees, minutes, seconds**, **UTM** or **MGRS** | Decimal degrees |
| **Place name language** | The language used when a site's country, region and town are looked up from its coordinates. Existing sites are not changed. | |
| **Time Format** | 12-hour or 24-hour | 12-hour |
| **Date Format** | MMM D, YYYY, D MMM YYYY, MM/DD/YYYY, DD/MM/YYYY, DD.MM.YYYY or YYYY-MM-DD | MMM D, YYYY |

<!-- screenshot: images/settings/units.png: units settings -->

## Decompression

The defaults for Submersion's Bühlmann ZH-L16C decompression model and how
figures from your dive computer are treated.

### Gradient Factors

Tap **Current Settings** to choose a preset or set **GF Low** and **GF High**
yourself (each 15 to 100):

| Preset | GF Low / High | Character |
|--------|---------------|-----------|
| **High** | 50/75 | Most conservative, longer deco stops |
| **Medium** | 50/85 | Balanced approach |
| **Low** | 50/95 | Least conservative, shorter deco |
| **Custom** | Your values | Set your own values |

A lower gradient factor is more conservative. New profiles start on **Medium**
(50/85). The [planner](planning.md), deco calculator, profile analysis and safety
review all use these values.

### Oxygen Toxicity

| Setting | What it does | Default |
|---------|--------------|---------|
| **ppO2 limits OC** | The working and maximum partial pressure of oxygen for open circuit, used for MOD, gas warnings and planning | Working 1.4 bar, max 1.6 bar |
| **CNS calculation** | How CNS oxygen toxicity is counted: **NOAA table, stepped (classic)**, **Linear interpolation (Shearwater-style)** or **Exponential fit (as Subsurface)**. All three are built on the NOAA oxygen exposure limits. | |

### Data Source Preferences

When a dive computer records its own figures, choose whether Submersion shows
those or its own calculation. Each has its own **Calculated** or
**Dive Computer** choice: **NDL Source**, **Deco Stop Source**, **TTS Source**,
**GTR Source** and **CNS Source**. With **Dive Computer**, Submersion uses the
computer's figure where there is one and calculates it where there is not. You
can still switch a single dive from its profile legend; see
[Dive Profiles & Deco](dive-profiles.md).

**GTR reserve pressure** sets the tank pressure the calculated gas time
remaining counts down to.

### Ascent planning

**Plan ascent with** decides which cylinders the simulated ascent (TTS, ceiling
and stops) may switch to: **All carried cylinders**, or only
**Deco/stage + back gas**.

### Narcosis

| Setting | What it does | Default |
|---------|--------------|---------|
| **O2 is narcotic** | Counts oxygen as well as nitrogen when working out narcosis (more conservative) | On |
| **END Limit** | The deepest equivalent narcotic depth you accept, from 20 to 50 m | 30 m |

## Appearance

<!-- screenshot: images/settings/appearance.png: appearance settings -->

### General

| Setting | What it does |
|---------|--------------|
| **Color Theme** | Opens the theme gallery: **Submersion**, **Console**, **Tropical**, **Minimalist** or **Deep**, each a colour palette and typography |
| Light and dark | **System default**, **Light** or **Dark** |
| **App Language** | The app's language, or **System Default** (the tile is called **Language** on a tablet or computer) |
| **Map Style** | **Street Map**, **Topographic** or **Satellite** |
| **Navigation layout** | Which destinations appear where (see below) |
| **Color accents** | **Colored navigation icons**, **Colored section headers** and **Colored list icons** |
| **Gear arrangement** | How equipment is grouped and sorted on a dive (on a phone) |

**Navigation layout** has a **Phone** and a **Desktop** tab. On a phone, drag
destinations to reorder them: the ones at the top appear in the bottom bar, as
many as your screen width allows. On a desktop, drag to reorder the
sidebar; Home always stays at the top. **Always hide labels** shows icons only.

### Home

**Home** under **Sections** sets up the Dashboard: which **Status chips** show at
the top, and which **Home cards** appear and in what order (drag to reorder).
**Reset to default** restores the original layout. See
[The Dashboard](dashboard.md).

### Sections

Each main area (**Dives**, **Sites**, **Buddies**, **Trips**, **Equipment**,
**Dive Centers**, **Certifications** and **Courses**) has its own appearance
page. What you can set depends on the area:

- **List View:** the default layout for that list: **Detailed**, **Compact** or **Table** (**Detailed** or **Table** for Certifications and Courses).
- **List Fields:** which fields or columns appear and in what order. In table
  view you can also pin columns and save named presets.
- **Color cards by** (Dives): tint dive cards by depth, duration or temperature
  with a choice of gradients.
- **Map background** (Dives, Sites): a faint map behind each card.
- **Table Mode:** **Show Details Pane** beside the table, and for dives
  **Show Profile Panel in Table View** and **Show data source badges**.
- **Dive Profile** (Dives): the chart's right-hand axis and markers, and which
  overlays are on for new profiles. See [Dive Profiles & Deco](dive-profiles.md).
- **Dive Details** and **Site Details:** reorder and hide the sections of those
  pages.

## Notifications

Service reminders for your gear, on iOS and Android: whether they are on, how
many days before service is due, the time of day, and how long before a trip to
warn about gear that falls due. See
[Equipment](equipment.md#service-reminders).

## Manage

The reusable lists and rules Submersion offers throughout the app:

| Item | What it manages |
|------|-----------------|
| **Dive Types** | Your own dive types |
| **Site Types** | Built-in and custom dive site types |
| **Dive Roles** | Your own roles for buddies on a dive |
| **Certification Agencies** | Your own agencies and certifications; see [Certifications and Courses](certifications-and-courses.md) |
| **Tank Presets** | Tank configurations and the default tank; see [Equipment](equipment.md#tank-presets) |
| **Transmitters** | Air-integration transmitters linked to cylinders |
| **Weight Presets** | Reusable sets of weights for a dive |
| **Trimix Mixer** | Fill gases, conditions and billing defaults for the trimix blender |
| **Service types** | The maintenance your gear needs, and how often |
| **Certification currency** | Refresher and renewal rules |
| **Locations** | Where your gear is kept, serviced or lent |
| **Setup assistant** | Revisit the first-run choices for units, appearance and backup |
| **Trip Checklist Templates** | Reusable to-do lists for trip planning |
| **Pre-Dive Checklists** | Buddy checks, CCR build lists, gear packing |
| **Near-miss log** | Private, non-punitive incident notes; see [Safety](safety.md#near-miss-log) |
| **Species** | The species catalog; see [Marine Life & Photos](marine-life-and-photos.md) |
| **Tags** | Manage, merge and delete tags |
| **Saved Queries** | Rename, reorder and delete saved dive searches |

## Data

### Backup & Sync

| Item | What it does |
|------|--------------|
| **Backup & Restore** | Back up and restore your whole log; see [Backup & Restore](backup-and-restore.md) |
| **Database Cloud Sync** | Keep your devices in step through cloud storage; see [Multi-Device Sync](multi-device-sync.md) |
| **Photos & Media** | Where photos come from, and media accounts; see [Media Sync](media-sync.md) |

### Storage

| Item | What it does |
|------|--------------|
| **Database Storage** | Where the database file lives: the app's default location or a folder you choose |
| **Offline Maps** | Map tiles and 3D terrain data for use without a connection |

### Import

| Setting | What it does |
|---------|--------------|
| **Auto site matching** | How readily downloaded dives are matched to your existing sites: **Strict**, **Balanced** or **Relaxed** |
| **Tank pressure at surfacing** | Read the end pressure from when you reached the surface, not from when the computer stopped recording |

### Data Tools

| Tool | What it does |
|------|--------------|
| **Fix Dive Times** | Shift the times of imported dives, for example a batch that came in an hour out because the computer's clock was wrong |
| **Link buddy names** | Turn buddy names on imported dives into buddy records |
| **Retype gear marked Other** | Give imported gear the type its name states |
| **Data quality** | Choose which checks the [Data Quality Assistant](data-quality-assistant.md) runs |

## App Security

| Setting | What it does |
|---------|--------------|
| **App Lock** | Require your password or biometrics to open the app. Setting it up gives you a recovery code: write it down, because it is the only way in if you forget your password. |
| **Unlock with biometrics** | Use Face ID, Touch ID or your fingerprint |
| **Auto-lock** | Lock **Immediately**, after a number of minutes, or **Never** |
| **Change password** / **New recovery code** | Manage the password and recovery code |
| **Encrypt database** | Encrypt your dive log file on disk. A safety backup is made first, then the file is re-encrypted in place, which can take a while for a large log. Encryption may affect performance. |

## Shared data

With two or more diver profiles on the device, choose
**Share new sites and trips by default**, or share everything you already have with
**Share all my sites**, **Share all my trips** and **Share all my equipment...**. See
[Diver Profile & Multi-Diver](diver-profile.md).

## Apple HealthKit

On iPhone and iPad, Submersion can import dives that an Apple Watch recorded in Apple
Health, with **Import from Apple Watch** under **Transfer**. This section shows
whether HealthKit access is granted and what is read; access itself is managed
in the Health app. See [Dive Computers](dive-computer.md).

## About

| Item | What it does |
|------|--------------|
| **About Submersion** | The app's version and description |
| **Open Source Licenses** | Licences for the libraries Submersion uses |
| **Report an Issue** | Opens the project's issue tracker |
| **Join the Beta** | On App Store and Google Play builds: get new features early through the beta program |
| **Updates** | On builds that update themselves: **Check for Updates**, **Automatic updates**, and the **Update channel**; see [Update Channels](update-channels.md) |
| **Diagnostics** | **View log**, **Copy diagnostics** (version, device and recent log lines for a bug report) and **Open log folder** |

> [!TIP]
> Tapping the version number five times turns on debug mode, which adds a
> **Debug** section to Settings. See [Debug Mode](debug-mode.md).

## See also

- [Diver Profile & Multi-Diver](diver-profile.md): the profiles these settings belong to
- [Dive Profiles & Deco](dive-profiles.md): how the decompression and overlay settings shape the chart
- [Backup & Restore](backup-and-restore.md): protect your dive log
- [Multi-Device Sync](multi-device-sync.md): keep every device in step
