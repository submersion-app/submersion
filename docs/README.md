# Submersion

> **Open-source dive logging for everyone.** Track your dives, manage your gear, analyze your profiles, and own your data.

<div class="screenshot-placeholder">
  <strong>App Screenshot</strong><br>
  <em>Replace with: Main dive list view showing recent dives</em>
</div>

## Why Submersion?

**Your data, your control.** Submersion stores everything locally on your device. No cloud lock-in, no subscriptions, no data mining. Export anytime in industry-standard formats.

**Professional-grade features.** From recreational divers to technical explorers, Submersion grows with you. Decompression calculations, multi-gas support, and dive computer integration - all in one app.

**Truly cross-platform.** One app for iOS, Android, macOS, Windows, and Linux. Your dive log travels with you.

---

## Key Features

### Dive Logging
Log every detail of your dives with 40+ data fields. Track depth, duration, temperature, visibility, conditions, and more. Rate your dives, mark favorites, and organize with tags and trips.

[Learn more about dive logging &rarr;](guide/dive-logging.md)

### Dive Computer Integration
Download dives directly from 300+ dive computer models. Supports Shearwater, Suunto, Mares, Aqualung, and many more via Bluetooth and USB.

[Connect your dive computer &rarr;](guide/dive-computer.md)

### Profile Analysis
Interactive depth profiles with zoom, pan, and touch markers. Visualize temperature, pressure, and heart rate overlays. Color-coded ascent rate warnings keep you safe.

[Explore profile analysis &rarr;](features/profile-analysis.md)

### Decompression Planning
Full Buhlmann ZH-L16C algorithm with gradient factor support. Real-time NDL, ceiling, and tissue loading calculations. CNS% and OTU oxygen toxicity tracking.

[Learn about deco features &rarr;](features/decompression.md)

### Equipment Management
Track all your gear with service reminders and maintenance history. Create equipment sets for quick selection. Never miss a regulator service again.

[Manage your gear &rarr;](guide/equipment.md)

### Statistics & Analytics
Eleven specialized dashboards for deep insights into your diving. Track personal records, gas consumption, dive patterns, buddy stats, and more.

[View statistics features &rarr;](guide/statistics.md)

### Sites & Maps
Build your personal dive site database with GPS coordinates and interactive maps. Weather and tide integration helps you plan the perfect dive.

[Explore dive sites &rarr;](guide/dive-sites.md)

### Import & Export
Full support for UDDF, CSV, and PDF export. Import from other dive log apps. Complete database backup and restore.

[Import & export data &rarr;](guide/import-export.md)

---

## Quick Start

### Installation

<!-- tabs:start -->

#### **macOS**

```bash
# Clone the repository
git clone https://github.com/submersion-app/submersion.git
cd submersion

# Install dependencies
flutter pub get

# Generate code
dart run build_runner build --delete-conflicting-outputs

# Run
flutter run -d macos
```

#### **iOS**

```bash
# Clone and setup
git clone https://github.com/submersion-app/submersion.git
cd submersion
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Open in Xcode
open ios/Runner.xcworkspace

# Or run directly
flutter run -d ios
```

#### **Android**

```bash
# Clone and setup
git clone https://github.com/submersion-app/submersion.git
cd submersion
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Run
flutter run -d android
```

#### **Windows**

```bash
# Clone and setup
git clone https://github.com/submersion-app/submersion.git
cd submersion
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Run
flutter run -d windows
```

#### **Linux**

```bash
# Clone and setup
git clone https://github.com/submersion-app/submersion.git
cd submersion
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Run
flutter run -d linux
```

<!-- tabs:end -->

[Full installation guide &rarr;](guide/installation.md)

---

## Technology

| Component | Technology |
|-----------|------------|
| **Framework** | Flutter 3.x |
| **State Management** | Riverpod |
| **Database** | Drift (SQLite) |
| **Navigation** | go_router |
| **Charts** | fl_chart |
| **Maps** | flutter_map (OpenStreetMap) |
| **Dive Computers** | libdivecomputer FFI |

---

## Version Status

| Version | Status | Highlights |
|---------|--------|------------|
| **v1.0** | Complete | Core logging, sites, gear, statistics |
| **v1.1** | Complete | GPS, maps, tags, profile zoom/pan |
| **v1.5** | Complete | Dive computers, deco algorithms, O2 tracking |
| **v2.0** | Planned | Cloud sync UI, photos, multi-language |

[View full roadmap &rarr;](contributing/roadmap.md)

---

## Contributing

Submersion is open source under the GPL-3.0 license. We welcome contributions!

- [How to contribute](contributing/)
- [Code style guide](contributing/code-style.md)
- [Pull request guidelines](contributing/pull-requests.md)

---

## Links

- **GitHub**: [submersion-app/submersion](https://github.com/submersion-app/submersion)
- **Issues**: [Report bugs or request features](https://github.com/submersion-app/submersion/issues)
- **License**: [GPL-3.0](https://github.com/submersion-app/submersion/blob/main/LICENSE)

---

<div style="text-align: center; color: #666; margin-top: 40px;">
  <p>Made with love for the diving community</p>
  <p>Local-first. Open source. Forever free.</p>
</div>
