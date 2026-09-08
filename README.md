<h1>
<img src="assets/icon/icon.png" alt="Submersion logo" width="72" align="left" hspace="14">
Submersion<br>
<sub><sub><sup><em>Own your dive log. Free and open-source, forever.</em></sup></sub></sub><br>&nbsp;
</h1>

[![License: GPL-3.0](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/submersion-app/submersion/ci.yaml?branch=main&label=CI&logo=githubactions&logoColor=white)](https://github.com/submersion-app/submersion/actions/workflows/ci.yaml)

Download your dive computer, check the deco on the profile, plan tomorrow's dive
with the gas you actually have, log who you dove with and what you saw, and keep
every bit of it on your own hardware. Rec or tech, single tank or rebreather, it
all fits in the same logbook.

Free and open source, on iOS, Android, macOS, Windows and Linux.

<img align="left" width="50%" src="docs/assets/screenshots/readme/01-dive-logging.jpg" alt="Dive list beside a dive detail pane with header statistics, the dive profile with events, deco status, oxygen exposure and tissue loading">

### Comprehensive Dive Logging

Every dive, fully detailed and in your control.

- Depth, duration, temperatures, conditions, weather and tide
- Any number of cylinders: air, nitrox, trimix, CCR and SCR
- Buddies, divemasters, trips, tags, ratings and signatures
- Cards, or a sortable table with the columns you choose

<br clear="all"><br>

<img align="right" width="50%" src="docs/assets/screenshots/readme/02-profile-deco.jpg" alt="Tissue loading panel with a bar per compartment and a heat map of on-gassing and off-gassing over the dive">

### Profile &amp; Decompression Analysis

Serious technical-diving instrumentation.

- B&uuml;hlmann ZH-L16C with your own gradient factors
- All 16 tissue compartments, nitrogen and helium
- CNS%, OTU and ppO&#8322; with daily and weekly totals
- Your computer's NDL, ceiling and TTS beside the model's

<br clear="all"><br>

<img align="left" width="50%" src="docs/assets/screenshots/readme/03-dive-computers.jpg" alt="Dive computer download review step showing a 70 percent match against an existing dive, both profiles overlaid, and four resolution actions">

### 350+ Dive Computers

Download straight from your computer.

- 30 manufacturers over Bluetooth LE and USB
- Incremental downloads: only what is new
- Duplicate review with four ways to resolve a match
- Two computers on one dive, profiles overlaid

<br clear="all"><br>

> **Confirmed working:** Shearwater Teric, Aqualung i300C, Aqualung i330R. Have a
> different dive computer? [Help us expand this list](https://github.com/submersion-app/submersion/issues).
> We are looking for testers.

<img align="right" width="50%" src="docs/assets/screenshots/readme/04-sites-maps.jpg" alt="Dive site list beside an interactive map with clustered markers and a dive heat map">

### Sites, Maps &amp; Marine Life

Where you dove, and what lives there.

- 3,600 dive sites and 3,600 dive centers built in
- Clustering, a dive heat map, and offline map regions
- Bathymetry overlays and 3D seafloor terrain
- 685 species, recorded per dive and per site

<br clear="all"><br>

<img align="left" width="50%" src="docs/assets/screenshots/readme/05-planning.jpg" alt="Dive planner with a multi-segment profile, gas list and decompression schedule">

### Dive Planning &amp; Gas

Plan with the gas, gear and tissues you will actually have.

- Multi-segment plans for OC, CCR, SCR and PSCR
- Bailout checked against the worst moment of the profile
- Contingencies, range tables and repetitive-dive seeding
- MOD, best mix, rock bottom, and a real-gas blender

<br clear="all"><br>

<img align="right" width="50%" src="docs/assets/screenshots/readme/06-photos-gear.jpg" alt="A dive video shown full screen with a dive computer face overlay reading depth, NDL, time, gas and tank pressure, and a small dive profile marking the moment it was taken">

### Photos, Gear &amp; Certifications

The rest of what a dive leaves behind.

- Photos and video matched to a dive by capture time
- Each shot marked at its depth on the profile
- Equipment with service schedules, reminders and costs
- A wallet of certification cards, plus courses and checklists

<br clear="all"><br>

<img align="left" width="50%" src="docs/assets/screenshots/readme/07-statistics.jpg" alt="Dive statistics overview in dark mode with totals, personal records and most visited sites">

### Statistics &amp; Records

See your diving life at a glance.

- Ten pages: totals, progression, conditions, gas and more
- Personal records: deepest, longest, coldest, warmest
- Breakdowns by year, country, site and dive type
- SAC trends, depth distribution and ascent-rate analysis

<br clear="all"><br>

<img align="right" width="50%" src="docs/assets/screenshots/readme/08-your-data.jpg" alt="Data settings with backup and restore, database cloud sync, photo and media sources, database storage, offline maps and data quality">

### Your Data, Encrypted

No server. No account. No lock-in.

- SQLite encrypted at rest, opened with Face ID, Touch ID or a passphrase
- End-to-end encrypted sync through your own iCloud, Google Drive, Dropbox or S3
- Encrypted backups, one taken automatically before every upgrade
- Export to UDDF 3.2, CSV, Excel, KML, GPX and printable PDF

<br clear="all"><br>

<p align="center">
  <img width="32%" src="docs/assets/screenshots/readme/09-profile-player.jpg" alt="Full-screen dive profile playback with depth, temperature, NDL, ppO2 and tank pressure over time">
  <img width="32%" src="docs/assets/screenshots/readme/10-tissue-3d.jpg" alt="Three-dimensional landscape of the 16 tissue compartments over the course of a dive">
  <img width="32%" src="docs/assets/screenshots/readme/11-site-terrain.jpg" alt="Three-dimensional seafloor terrain of a dive site with the dive's estimated path drawn on it">
</p>

<p align="center"><sub>Full-screen profile playback &middot; The 16 tissue compartments as a landscape &middot; A site's 3D seafloor with the dive's path</sub></p>

<p align="center">
  <img width="32%" src="docs/assets/screenshots/readme/12-marine-life.jpg" alt="Marine life statistics with species sightings">
  <img width="32%" src="docs/assets/screenshots/readme/13-gas-blender.jpg" alt="Trimix blender showing the partial-pressure fill procedure and fill cost">
  <img width="32%" src="docs/assets/screenshots/readme/14-themes.jpg" alt="Theme gallery showing the five app themes">
</p>

<p align="center"><sub>Species sightings across the log &middot; The blender's fill procedure and cost &middot; Five themes, each in light and dark</sub></p>

## Why Submersion?

Most dive logging software falls into two categories: desktop applications stuck in the past, or mobile apps that lock your data in proprietary clouds. Submersion is different:

- **You control your data:** an SQLite database on your own hardware, encrypted at rest. No account, no server, no cloud dependency. Export everything, anytime.
- **Truly cross-platform:** one app for iOS, Android, macOS, Windows and Linux, with the same details and analytics everywhere. Available in 11 languages.
- **Open standards:** full UDDF 3.2 import and export, plus CSV, Excel, KML and GPX. No proprietary format trapping your dive history.
- **350+ dive computers:** Bluetooth LE and USB, across 30 manufacturers, powered by [libdivecomputer](https://www.libdivecomputer.org/).
- **Technical diving ready:** Bühlmann ZH-L16C with gradient factors, multi-gas and CCR/SCR support, CNS and OTU tracking, bailout planning and trimix blending.
- **Sync on your terms:** end-to-end encrypted sync between your devices through your own iCloud, Google Drive, Dropbox or S3-compatible storage.
- **Free forever:** open source under GPL-3.0. No ads, no subscription, no in-app purchases.

## Download

- **macOS / Windows / Linux / Android:** [GitHub Releases](https://github.com/submersion-app/submersion/releases)
- **iOS:** [App Store](https://apps.apple.com/us/app/submersion-dive-log/id6757456915)

### Beta channel

Want fixes and features weeks early? Every change merged into Submersion is
published as a beta build. Betas may upgrade your dive log's database ahead
of the stable release; downgrading is not supported, and devices that sync
together should all use the same channel. A backup is taken automatically
before any database upgrade.

- **Desktop:** Settings > About > Update channel > Beta (updates then arrive
  through the normal auto-updater), or download directly from
  [beta-builds](https://github.com/submersion-app/beta-builds/releases)
- **Android:** [join the open test](https://play.google.com/apps/testing/app.submersion),
  then Play delivers beta updates automatically
- **iOS / Mac App Store:** [join via TestFlight](https://testflight.apple.com/join/aMD393sB)

## Data Philosophy

Submersion is built on these principles:

1. **Local-First:** your data lives on your device. The app works offline, always.
2. **No Lock-In:** export your entire logbook to UDDF or CSV at any time. Switch apps without losing history.
3. **No Account Required:** use the app immediately. No sign-up, no email, no tracking.
4. **Open Source:** audit the code. Fork it. Improve it. Your dive log software should be transparent.

## Features

Beyond what the screens above show.

### Import from Elsewhere

- **File import:** Subsurface, MacDive, Shearwater Cloud, Garmin FIT, DAN DL7, Ratio and UDDF.
- **CSV import:** presets for MySSI, Diving Log, DiveMate, Garmin Connect and Shearwater Cloud, or map the columns yourself.
- **Apple Health:** underwater workouts recorded by an Apple Watch, with depth, temperature and heart rate.
- **Paper logbooks:** scan the pages and OCR reads the entries for you to check and import.

### In the Log

- **Conditions:** visibility, current, swell, entry and exit method, altitude. Weather is fetched for the date and place; tides come from a bundled global model and work offline.
- **People:** your role on the dive, dive center, operator and boat. A buddy or instructor can sign the dive on your screen.
- **Gas detail:** oxygen and helium fractions per cylinder, start and end pressure, and the pressure trace from an air-integrated transmitter.
- **Weights:** what you carried, where you put it, and whether it felt right.
- **Your own fields:** colored tags, dive types you define, and custom fields for whatever your agency or your habits call for.
- **Bulk edit:** fix a whole trip's entries at once.
- **Safety review:** each profile is checked for fast ascents, sawtooth patterns and missed safety stops.
- **Several divers:** separate profiles per diver, each with emergency contacts, medical notes and insurance details.

### Sites & Trips

- **Site records:** depth range, difficulty, water type, hazards, access notes, mooring and parking, with reverse-geocoded country and region.
- **Reef data:** protection status, habitat, bleaching alerts and reef health for the sites you visit.
- **Trips:** dates, resort or liveaboard, a day-by-day itinerary, preparation checklists, and a gallery for the whole trip.

### Profile Analysis

- **Playback:** play or scrub the profile, overlaying temperature, tank pressure, heart rate, SAC, ppO₂, ppN₂, ppHe, gas density, gradient factor, TTS, ceiling, NDL and deco stops.
- **Ascent rate:** drawn on the profile and colored where it exceeds the limits.
- **3D:** move through the dive in three dimensions, or view the 16 tissue compartments as a surface.
- **Edit:** trim a profile that started on the boat, with undo if you get it wrong.

### Planning & Calculators

- **Weighting:** a buoyancy model built from your logged dives predicts what to carry for a new suit, cylinder or water type.
- **Gas calculators:** MOD, best mix, maximum narcotic depth, consumption and rock bottom.
- **Blender:** partial-pressure fills worked out with a real-gas equation, and the fill invoice.
- **On the slate:** export the plan as a PDF for your wet notes.

### Equipment & Training

- **Equipment sets:** build a configuration once and apply it to a dive; a set can select itself by location.
- **Service log:** what was done, when, and what it cost.
- **Courses:** track a course's requirements and link each one to the dive that satisfied it.
- **Checklists:** run a pre-dive checklist from a template and attach the session to the log.

### Data & Preferences

- **Data quality:** an assistant that finds duplicates and anomalies across the log and walks you through fixing them.
- **PDF logbooks:** Simple, Detailed, Professional, PADI and NAUI layouts.
- **Your units:** independent settings for depth, temperature, pressure, volume, weight, altitude and SAC.
- **Your language:** 11 languages, five themes in light and dark, and keyboard shortcuts on the desktop.

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.47.0 or newer (CI pins the exact version in [.github/flutter-version.txt](.github/flutter-version.txt))

### Quick Start

```bash
# Clone the repository
git clone https://github.com/submersion-app/submersion.git
cd submersion

# Initialize submodules (required for libdivecomputer)
git submodule update --init --recursive

# Install dependencies
flutter pub get

# Generate database and serialization code
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run -d macos    # or: windows, linux, ios, android
```

## Building from Source

<details>
<summary><b>Build for release (iOS, Android, macOS, Windows, Linux)</b></summary>

```bash
# iOS
flutter build ios

# Android
flutter build apk

# macOS
flutter build macos

# Windows
flutter build windows

# Linux
flutter build linux
```

</details>

<details>
<summary><b>macOS: building without a developer certificate</b></summary>

If you don't have an Apple Developer certificate, you can still build and run the app locally using ad-hoc signing. This creates a non-sandboxed build that works on any Mac.

```bash
# Run the no-sandbox build script
./scripts/release/build_nosandbox_macos.sh
```

This script:

1. Builds the macOS app with Flutter
2. Re-signs it with an ad-hoc signature (no Apple certificate required)
3. Applies no-sandbox entitlements for full file system access

The built app will be at `build/macos/Build/Products/Release/submersion.app`.

**Running the app:** macOS Gatekeeper will block unsigned apps by default. To run:

1. Right-click (or Control-click) on `submersion.app`
2. Select "Open" from the context menu
3. Click "Open" in the dialog that appears

You only need to do this once; subsequent launches will work normally.

> **Note:** This build cannot be distributed via the Mac App Store (which requires sandboxing). It's intended for local testing and direct distribution.

</details>

<details>
<summary><b>Windows: building from source</b></summary>

Windows builds require no code signing for local use. You need [Visual Studio](https://visualstudio.microsoft.com/) with the **Desktop development with C++** workload installed (the free Community edition works).

```bash
# Build the app
flutter build windows --release
```

The built app will be at `build\windows\x64\runner\Release\`.

> **Note:** Windows SmartScreen may show an "unrecognized app" warning for unsigned executables. Click "More info" then "Run anyway" to proceed.

</details>

<details>
<summary><b>Linux: installing</b></summary>

> **Distro requirement:** Submersion needs glibc 2.38 or newer, which means
> Ubuntu 24.04+, Debian 13+, Fedora 39+, Linux Mint 22+, Arch, or openSUSE
> Tumbleweed. Debian 12, Ubuntu 22.04, and RHEL 9 cannot run any current
> Submersion build. The packages install but the app will not start, and the
> tarball fails the same way, because three bundled libraries require
> GLIBC_2.38. Upgrading the distribution is the only path.

> **Where the packages are today:** the `.deb` and `.rpm` ship with every beta
> build at
> [submersion-app/beta-builds](https://github.com/submersion-app/beta-builds/releases).
> They reach the stable
> [Releases page](https://github.com/submersion-app/submersion/releases) with
> the next stable release; that page currently carries the tarball only.

**Debian, Ubuntu, Mint, and derivatives**

Download `Submersion-v<version>-Linux-amd64.deb` from
[beta releases](https://github.com/submersion-app/beta-builds/releases), then:

```bash
sudo apt install ./Submersion-*-Linux-amd64.deb
```

**Fedora and RHEL**

Download `Submersion-v<version>-Linux-x86_64.rpm` from the
[beta releases](https://github.com/submersion-app/beta-builds/releases), then:

```bash
sudo dnf install ./Submersion-*-Linux-x86_64.rpm
```

**openSUSE**

The same `.rpm`, installed with zypper, which openSUSE ships instead of dnf:

```bash
sudo zypper install ./Submersion-*-Linux-x86_64.rpm
```

Both packages install a desktop entry, icons, and udev rules that let dive
computers connected by USB be reached without any group membership or
`usermod` step. Video compression is optional and needs `ffmpeg`, which the
packages recommend but do not require.

**Everything else (Arch, NixOS, and anyone who prefers not to install packages)**

Download `Submersion-v<version>-Linux.tar.gz`, unpack it, and run the included
installer:

```bash
tar xzf Submersion-*-Linux.tar.gz
./install.sh
```

`install.sh` checks for missing shared libraries and prints the exact command
to install them for your package manager, installs a desktop entry and icon
into `~/.local/share`, and links the binary into `~/.local/bin`. It also
prints the command to install the udev rules, which needs root.
`./uninstall.sh` reverses all of it and never touches your dive log data.

</details>

<details>
<summary><b>Linux: building from source (distro dependencies)</b></summary>

Linux builds require GTK3 and several native development libraries. Install them first:

**Debian/Ubuntu:**

```bash
sudo apt-get update
sudo apt-get install -y \
  clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev libstdc++-12-dev \
  libsqlite3-dev libsecret-1-dev
```

**Fedora:**

```bash
sudo dnf install -y \
  clang cmake ninja-build pkg-config \
  gtk3-devel xz-devel libstdc++-devel \
  sqlite-devel libsecret-devel
```

**Arch Linux:**

```bash
sudo pacman -S --needed \
  clang cmake ninja pkg-config \
  gtk3 xz sqlite libsecret
```

Then build:

```bash
flutter build linux --release
```

The built app will be at `build/linux/x64/release/bundle/`.

</details>

<details>
<summary><b>Architecture &amp; tech stack</b></summary>

Submersion follows clean architecture principles with clear separation of concerns:

```
lib/
├── core/                 # Shared infrastructure
│   ├── database/         # Drift ORM schema and migrations
│   ├── deco/             # Decompression algorithms
│   ├── router/           # Navigation (go_router)
│   ├── services/         # Location, weather, database services
│   └── theme/            # Material 3 theming
├── features/             # Feature modules
│   ├── dive_log/         # Core dive logging
│   ├── dive_sites/       # Site management & maps
│   ├── dive_computer/    # Device connectivity
│   ├── equipment/        # Gear tracking
│   ├── statistics/       # Analytics & records
│   └── ...               # Additional features
└── shared/               # Reusable widgets
```

**Tech Stack:**

- **Flutter:** cross-platform UI framework
- **Riverpod:** reactive state management
- **Drift:** type-safe SQLite ORM with migrations
- **go_router:** declarative navigation
- **fl_chart:** interactive charts for profiles and statistics
- **flutter_map:** OpenStreetMap integration
- **libdivecomputer:** FFI bindings for dive computer communication

See [ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed documentation.

</details>

## Roadmap

See [FEATURE_ROADMAP.md](docs/FEATURE_ROADMAP.md) for what is built, what is in progress, and what is planned.

## Contributing

Contributions are welcome! Submersion is built by divers, for divers.

1. Fork the repository
2. Clone and initialize submodules: `git clone --recurse-submodules <your-fork-url>`
3. Create a feature branch: `git checkout -b feature/your-feature`
4. Make your changes with tests
5. Submit a pull request

Please run `flutter analyze` and `flutter test` before submitting.

## License

Submersion is free software, released under the **GNU General Public License v3.0**.

You are free to use, modify, and distribute this software. If you distribute modified versions, you must also release the source code under GPL-3.0.

See [LICENSE](LICENSE) for the full text.

## Acknowledgments

Submersion builds on the work of the dive logging community:

- **[libdivecomputer](https://www.libdivecomputer.org/):** the open-source library powering dive computer communication
- **[Subsurface](https://subsurface-divelog.org/):** inspiration and the UDDF format
- **[Flutter](https://flutter.dev/):** cross-platform framework making this possible

---

*Dive safe. Log everything. Own your data.*
