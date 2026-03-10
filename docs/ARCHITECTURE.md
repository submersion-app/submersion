# Submersion - Dive Log Application Architecture

## Executive Summary

Submersion is an open-source, cross-platform dive logging application built with Flutter. It runs natively on iOS, Android, macOS, Windows, and Linux with local-first data storage and optional cloud sync. The app combines professional-grade dive logging with technical diving features including decompression calculations and dive computer integration.

**Current Version:** 1.5.0 (v1.5 Complete)

## Core Features

### Implemented Features

#### Dive Logging & Management

- ✅ Comprehensive dive log with 40+ data fields per dive
- ✅ Multi-tank support with gas mix tracking (air, nitrox, trimix)
- ✅ Dive profile visualization with interactive zoom/pan
- ✅ Entry/exit times with surface interval calculation
- ✅ Automatic dive numbering with gap detection
- ✅ Star ratings, favorites, tags, and trip organization
- ✅ Multi-diver support (multiple profiles per device)

#### Dive Computer Integration

- ✅ Support for 300+ dive computer models via libdivecomputer
- ✅ Bluetooth Classic, BLE, and USB connectivity
- ✅ Manufacturer-specific protocols (Shearwater, Suunto, Mares, Aqualung)
- ✅ Incremental downloads (new dives only)
- ✅ Duplicate detection with fuzzy matching
- ✅ Multi-computer support with profile selection

#### Decompression & Technical Diving

- ✅ Bühlmann ZH-L16C algorithm with gradient factors
- ✅ Real-time NDL, ceiling, and TTS calculations
- ✅ 16-compartment tissue loading visualization
- ✅ CNS% and OTU oxygen toxicity tracking (NOAA tables)
- ✅ ppO₂ monitoring with warning thresholds
- ✅ Ascent rate monitoring with color-coded warnings
- ✅ MOD/END/EAD calculations

#### Profile Analysis

- ✅ Interactive depth/temperature/pressure charts
- ✅ Touch markers with metrics at any point
- ✅ Profile event markers (safety stops, gas switches, alerts)
- ✅ SAC/RMV overlay for gas consumption
- ✅ Deco ceiling curve visualization

#### Location & Mapping

- ✅ GPS tracking and dive site management
- ✅ Interactive maps with marker clustering (OpenStreetMap)
- ✅ Capture location from device GPS
- ✅ Reverse geocoding for country/region
- ✅ Weather integration (OpenWeatherMap API)
- ✅ Tide integration (World Tides API)

#### Equipment Management

- ✅ Track 20+ equipment types with serial numbers
- ✅ Service reminders with visual warnings
- ✅ Service history and maintenance records
- ✅ Equipment sets ("bags") for quick selection
- ✅ Per-dive gear tracking (many-to-many)
- ✅ Tank presets (AL80, HP100, etc.)

#### People & Training

- ✅ Buddy contact list with certification tracking
- ✅ Buddy roles per dive (guide, instructor, student)
- ✅ Certification management with expiry tracking
- ✅ Dive center/operator database
- ✅ 12+ certification agencies supported

#### Import/Export

- ✅ UDDF 3.2 import/export (Universal Dive Data Format)
- ✅ CSV import/export with field mapping
- ✅ PDF export for printable logbooks
- ✅ Full SQLite database backup/restore

#### Cloud Sync (Infrastructure Complete)

- ✅ Google Drive integration
- ✅ iCloud integration
- ✅ Sync tables for conflict detection
- ✅ Multi-device synchronization

---

## Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Framework** | Flutter 3.x | Cross-platform UI |
| **Language** | Dart 3.5+ | Application code |
| **State Management** | Riverpod 2.5 | Reactive state with providers |
| **Database** | Drift 2.20 | Type-safe SQLite ORM |
| **Navigation** | go_router 14.x | Declarative routing |
| **Charts** | fl_chart 0.68 | Interactive data visualization |
| **Maps** | flutter_map 7.x | OpenStreetMap integration |
| **Bluetooth** | flutter_blue_plus | Dive computer connectivity |
| **Dive Computers** | dive_computer (libdivecomputer FFI) | 300+ device support |
| **Cloud** | googleapis, google_sign_in | Google Drive sync |

---

## System Architecture

### High-Level Architecture

```dart
┌─────────────────────────────────────────────────────────────────┐
│                       Client Applications                        │
├──────────────┬──────────────┬──────────────┬───────────────────┤
│    macOS     │   Windows    │   Android    │       iOS         │
│   Desktop    │   Desktop    │    Mobile    │      Mobile       │
└──────┬───────┴──────┬───────┴──────┬───────┴────────┬──────────┘
       │              │              │                │
       └──────────────┴──────────────┴────────────────┘
                              │
              ┌───────────────┴───────────────┐
              │      Presentation Layer       │
              │   (Flutter Widgets/Pages)     │
              └───────────────┬───────────────┘
                              │
              ┌───────────────┴───────────────┐
              │       State Management        │
              │    (Riverpod Providers)       │
              └───────────────┬───────────────┘
                              │
              ┌───────────────┴───────────────┐
              │         Domain Layer          │
              │   (Entities, Repositories)    │
              └───────────────┬───────────────┘
                              │
       ┌──────────────────────┼──────────────────────┐
       │                      │                      │
       ▼                      ▼                      ▼
┌─────────────┐      ┌─────────────┐      ┌─────────────────┐
│   SQLite    │      │  Cloud Sync │      │  Dive Computer  │
│  (Drift)    │      │ (GDrive/iC) │      │ (libdivecomputer)│
└─────────────┘      └─────────────┘      └─────────────────┘
```

### Layered Architecture

```dart
┌──────────────────────────────────────────┐
│         Presentation Layer               │
│  - Pages (50+ screens)                   │
│  - Widgets (reusable UI components)      │
│  - Providers (Riverpod state)            │
└──────────────┬───────────────────────────┘
               │
┌──────────────▼───────────────────────────┐
│         Domain Layer                     │
│  - Entities (Dive, Site, Gear, etc.)     │
│  - Repository Interfaces                 │
│  - Business Rules & Calculations         │
└──────────────┬───────────────────────────┘
               │
┌──────────────▼───────────────────────────┐
│          Data Layer                      │
│  - Repository Implementations            │
│  - Drift Database & Tables               │
│  - API Clients (Weather, Tide)           │
│  - Cloud Storage Providers               │
└──────────────┬───────────────────────────┘
               │
       ┌───────┴────────┐
       ▼                ▼
┌─────────────┐  ┌─────────────┐
│   SQLite    │  │  External   │
│   (Local)   │  │   APIs      │
└─────────────┘  └─────────────┘
```

---

## Project Structure

```dart
submersion/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── app.dart                     # Root widget with providers
│   │
│   ├── core/                        # Shared infrastructure
│   │   ├── constants/               # App-wide constants, enums
│   │   ├── database/                # Drift ORM schema (30 tables)
│   │   ├── deco/                    # Decompression algorithms
│   │   │   ├── constants/           # Bühlmann coefficients
│   │   │   ├── entities/            # Tissue loading, GF
│   │   │   ├── buhlmann_algorithm.dart
│   │   │   ├── o2_toxicity_calculator.dart
│   │   │   └── ascent_rate_calculator.dart
│   │   ├── errors/                  # Error handling
│   │   ├── models/                  # Shared data models
│   │   ├── router/                  # go_router navigation
│   │   ├── services/
│   │   │   ├── cloud_storage/       # Google Drive, iCloud
│   │   │   ├── sync/                # Multi-device sync
│   │   │   ├── database_service.dart
│   │   │   ├── export_service.dart
│   │   │   ├── location_service.dart
│   │   │   ├── weather_service.dart
│   │   │   └── tide_service.dart
│   │   ├── theme/                   # Material 3 theming
│   │   └── utils/                   # Utilities
│   │
│   ├── features/                    # Feature modules (17 total)
│   │   ├── dive_log/                # Core dive logging
│   │   │   ├── data/
│   │   │   │   ├── models/
│   │   │   │   └── repositories/
│   │   │   ├── domain/
│   │   │   │   └── entities/        # Dive, DiveProfilePoint, etc.
│   │   │   └── presentation/
│   │   │       ├── pages/           # DiveListPage, DiveDetailPage
│   │   │       ├── widgets/         # DiveProfileChart, DecoInfoPanel
│   │   │       └── providers/       # Riverpod providers
│   │   │
│   │   ├── dive_sites/              # Site management & maps
│   │   ├── dive_computer/           # Device connectivity
│   │   ├── equipment/               # Gear & service tracking
│   │   ├── statistics/              # Analytics (11 dashboard pages)
│   │   ├── import_export/           # UDDF, CSV, PDF
│   │   ├── settings/                # App configuration
│   │   ├── divers/                  # Multi-account support
│   │   ├── buddies/                 # Buddy management
│   │   ├── certifications/          # Diver certifications
│   │   ├── dive_centers/            # Dive operators
│   │   ├── trips/                   # Trip organization
│   │   ├── tags/                    # Tagging system
│   │   ├── dive_types/              # Custom dive types
│   │   ├── marine_life/             # Species sightings
│   │   ├── tools/                   # Calculators
│   │   └── onboarding/              # First-run experience
│   │
│   └── shared/                      # Reusable components
│       ├── constants/
│       ├── models/
│       ├── services/
│       └── widgets/                 # MainScaffold, etc.
│
├── test/                            # 200+ tests
├── assets/
│   ├── data/                        # Seed data (species, etc.)
│   └── icon/                        # App icons
└── platform/                        # Platform-specific code
    ├── ios/
    ├── android/
    ├── macos/
    ├── windows/
    └── linux/
```

---

## Database Schema

Submersion uses **Drift ORM** with a SQLite database containing **30 tables** organized into logical groups.

### Schema Version: 4

### Table Overview

| Category | Tables | Description |
|----------|--------|-------------|
| **Core** | `Divers`, `Dives`, `DiveProfiles`, `DiveTanks` | Primary dive data |
| **Location** | `DiveSites`, `DiveCenters`, `Trips` | Places and trips |
| **Equipment** | `Equipment`, `DiveEquipment`, `DiveWeights`, `EquipmentSets`, `EquipmentSetItems`, `ServiceRecords` | Gear tracking |
| **People** | `Buddies`, `DiveBuddies`, `Certifications` | Social & training |
| **Organization** | `Tags`, `DiveTags`, `DiveTypes` | Classification |
| **Profile** | `DiveComputers`, `DiveProfileEvents`, `GasSwitches` | Dive analysis |
| **Marine Life** | `Species`, `Sightings` | Wildlife tracking |
| **Media** | `Media` | Photos/videos |
| **Settings** | `Settings`, `DiverSettings` | Configuration |
| **Sync** | `SyncMetadata`, `SyncRecords`, `DeletionLog` | Cloud sync |

### Core Tables

#### Divers (Multi-Account Support)

```sql
CREATE TABLE divers (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  photo_path TEXT,
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  emergency_contact_relation TEXT,
  medical_notes TEXT DEFAULT '',
  blood_type TEXT,
  allergies TEXT,
  insurance_provider TEXT,
  insurance_policy_number TEXT,
  insurance_expiry_date INTEGER,
  notes TEXT DEFAULT '',
  is_default INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```text
#### Dives (Primary Dive Log)

```sql
CREATE TABLE dives (
  id TEXT PRIMARY KEY,
  diver_id TEXT REFERENCES divers(id),
  dive_number INTEGER,
  dive_date_time INTEGER NOT NULL,
  entry_time INTEGER,
  exit_time INTEGER,
  duration INTEGER,
  runtime INTEGER,
  max_depth REAL,
  avg_depth REAL,
  water_temp REAL,
  air_temp REAL,
  visibility TEXT,
  site_id TEXT REFERENCES dive_sites(id),
  dive_center_id TEXT REFERENCES dive_centers(id),
  trip_id TEXT REFERENCES trips(id),
  computer_id TEXT REFERENCES dive_computers(id),
  -- Conditions
  current_direction TEXT,
  current_strength TEXT,
  swell_height REAL,
  entry_method TEXT,
  exit_method TEXT,
  water_type TEXT,
  -- Technical
  altitude REAL,
  surface_pressure REAL,
  surface_interval_seconds INTEGER,
  gradient_factor_low INTEGER,
  gradient_factor_high INTEGER,
  dive_mode TEXT DEFAULT 'oc',
  dive_computer_model TEXT,
  dive_computer_serial TEXT,
  -- O2 Toxicity
  cns_start REAL DEFAULT 0,
  cns_end REAL,
  otu REAL,
  -- Weight
  weight_amount REAL,
  weight_type TEXT,
  -- Metadata
  dive_type TEXT DEFAULT 'recreational',
  buddy TEXT,
  dive_master TEXT,
  rating INTEGER,
  notes TEXT DEFAULT '',
  is_favorite INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```text
#### DiveProfiles (Time-Series Data)

```sql
CREATE TABLE dive_profiles (
  id TEXT PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  computer_id TEXT REFERENCES dive_computers(id),
  is_primary INTEGER DEFAULT 1,
  timestamp INTEGER NOT NULL,  -- seconds from dive start
  depth REAL NOT NULL,
  pressure REAL,               -- bar
  temperature REAL,
  heart_rate INTEGER,
  ascent_rate REAL,            -- m/min (computed)
  ceiling REAL,                -- deco ceiling (computed)
  ndl INTEGER                  -- no-deco limit (computed)
);
CREATE INDEX idx_profile_dive ON dive_profiles(dive_id, timestamp);
```text
#### DiveTanks (Gas Configuration)

```sql
CREATE TABLE dive_tanks (
  id TEXT PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  equipment_id TEXT REFERENCES equipment(id),
  volume REAL,
  working_pressure INTEGER,
  start_pressure INTEGER,
  end_pressure INTEGER,
  o2_percent REAL DEFAULT 21.0,
  he_percent REAL DEFAULT 0.0,
  tank_order INTEGER DEFAULT 0,
  tank_role TEXT DEFAULT 'backGas',
  tank_material TEXT,
  tank_name TEXT,
  preset_name TEXT
);
```text
### Equipment Tables

#### Equipment (Gear Catalog)

```sql
CREATE TABLE equipment (
  id TEXT PRIMARY KEY,
  diver_id TEXT REFERENCES divers(id),
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  brand TEXT,
  model TEXT,
  serial_number TEXT,
  size TEXT,
  status TEXT DEFAULT 'active',
  purchase_date INTEGER,
  purchase_price REAL,
  purchase_currency TEXT DEFAULT 'USD',
  last_service_date INTEGER,
  service_interval_days INTEGER,
  notes TEXT DEFAULT '',
  is_active INTEGER DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```text
### People Tables

#### Buddies

```sql
CREATE TABLE buddies (
  id TEXT PRIMARY KEY,
  diver_id TEXT REFERENCES divers(id),
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  certification_level TEXT,
  certification_agency TEXT,
  photo_path TEXT,
  notes TEXT DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```text
#### DiveBuddies (Junction with Role)

```sql
CREATE TABLE dive_buddies (
  id TEXT PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  buddy_id TEXT NOT NULL REFERENCES buddies(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'buddy',  -- buddy, guide, instructor, student
  created_at INTEGER NOT NULL
);
```text
### Profile Analysis Tables

#### DiveComputers

```sql
CREATE TABLE dive_computers (
  id TEXT PRIMARY KEY,
  diver_id TEXT REFERENCES divers(id),
  name TEXT NOT NULL,
  manufacturer TEXT,
  model TEXT,
  serial_number TEXT,
  connection_type TEXT,
  bluetooth_address TEXT,
  last_download_timestamp INTEGER,
  dive_count INTEGER DEFAULT 0,
  is_favorite INTEGER DEFAULT 0,
  notes TEXT DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```text
#### DiveProfileEvents

```sql
CREATE TABLE dive_profile_events (
  id TEXT PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  timestamp INTEGER NOT NULL,
  event_type TEXT NOT NULL,
  severity TEXT DEFAULT 'info',
  description TEXT,
  depth REAL,
  value REAL,
  tank_id TEXT,
  created_at INTEGER NOT NULL
);
```text
### Sync Tables

#### SyncMetadata

```sql
CREATE TABLE sync_metadata (
  id TEXT PRIMARY KEY,  -- Always 'global'
  last_sync_timestamp INTEGER,
  device_id TEXT NOT NULL,
  sync_provider TEXT,   -- 'icloud' or 'googledrive'
  remote_file_id TEXT,
  sync_version INTEGER DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```text
#### SyncRecords

```sql
CREATE TABLE sync_records (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  record_id TEXT NOT NULL,
  local_updated_at INTEGER NOT NULL,
  synced_at INTEGER,
  sync_status TEXT DEFAULT 'synced',
  conflict_data TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```dart
---

## State Management

Submersion uses **Riverpod** for reactive state management with clear patterns:

### Provider Types

| Provider Type | Use Case | Example |
|--------------|----------|---------|
| `Provider` | Singletons, repositories | `diveRepositoryProvider` |
| `FutureProvider` | Async data fetching | `divesProvider` |
| `FutureProvider.family` | Parameterized queries | `diveProvider(diveId)` |
| `StateNotifierProvider` | Mutable CRUD state | `diveListNotifierProvider` |
| `StateProvider` | Simple mutable state | `diveFilterProvider` |

### StateNotifier Pattern

All CRUD operations follow a consistent pattern:

```dart
class DiveListNotifier extends StateNotifier<AsyncValue<List<domain.Dive>>> {
  final DiveRepository _repository;
  final Ref _ref;

  DiveListNotifier(this._repository, this._ref) : super(const AsyncLoading()) {
    _loadDives();
    // Listen for diver changes and reload
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) _loadDives();
    });
  }

  Future<void> _loadDives() async {
    state = const AsyncLoading();
    try {
      final dives = await _repository.getAllDives(diverId: _currentDiverId);
      state = AsyncData(dives);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<domain.Dive> addDive(domain.Dive dive) async {
    final created = await _repository.createDive(dive);
    _ref.invalidate(diveStatisticsProvider);
    await _loadDives();
    return created;
  }

  Future<void> updateDive(domain.Dive dive) async {
    await _repository.updateDive(dive);
    _ref.invalidate(diveProvider(dive.id));
    await _loadDives();
  }

  Future<void> deleteDive(String id) async {
    await _repository.deleteDive(id);
    await _loadDives();
  }
}
```text
### Multi-Diver Isolation

All data queries are scoped to the current diver:

```dart
final divesProvider = FutureProvider<List<domain.Dive>>((ref) async {
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final repository = ref.watch(diveRepositoryProvider);
  return repository.getAllDives(diverId: diverId);
});
```dart
### Provider Invalidation

Providers are invalidated strategically to avoid unnecessary rebuilds:

```dart
Future<void> updateDive(domain.Dive dive) async {
  await _repository.updateDive(dive);
  _ref.invalidate(diveStatisticsProvider);     // Stats changed
  _ref.invalidate(diveProvider(dive.id));      // Specific dive changed
  if (dive.tripId != null) {
    _ref.invalidate(tripWithStatsProvider(dive.tripId));
  }
}
```diff
---

## Decompression Algorithms

The `lib/core/deco/` module implements professional-grade decompression calculations.

### Bühlmann ZH-L16C

The primary decompression algorithm with 16 tissue compartments:

```dart
class BuhlmannAlgorithm {
  final GradientFactors gf;  // GF Low/High (e.g., 30/70)

  // 16-compartment half-times and M-values
  static const compartments = [
    Compartment(halfTimeN2: 4.0, halfTimeHe: 1.51, ...),
    Compartment(halfTimeN2: 8.0, halfTimeHe: 3.02, ...),
    // ... 14 more compartments
  ];

  /// Calculate tissue loading for a profile segment
  TissueLoading calculateLoading(depth, duration, gasMix, ambient);

  /// Calculate deco ceiling (first stop depth)
  double calculateCeiling(TissueLoading loading);

  /// Calculate NDL (no-decompression limit)
  Duration calculateNDL(depth, gasMix, currentLoading);

  /// Generate deco schedule
  List<DecoStop> calculateDecoSchedule(loading, gf);
}
```text
### O₂ Toxicity Tracking

CNS% and OTU calculations using NOAA exposure tables:

```dart
class O2ToxicityCalculator {
  /// Calculate CNS% accumulation for a dive segment
  double calculateCNS(ppO2, durationMinutes);

  /// Calculate OTU (Oxygen Tolerance Units)
  double calculateOTU(ppO2, durationMinutes);

  /// NOAA exposure limits by ppO2
  static const noaaExposureLimits = {
    1.6: 45,   // minutes at ppO2 1.6
    1.5: 120,
    1.4: 150,
    // ...
  };
}
```text
### Ascent Rate Monitoring

Color-coded ascent rate warnings:

| Rate | Category | Color |
|------|----------|-------|
| ≤9 m/min | Safe | Green |
| 9-12 m/min | Warning | Yellow |
| >12 m/min | Danger | Red |

---

## Cloud Sync Architecture

The sync system enables multi-device synchronization via Google Drive or iCloud.

### Sync Flow

```

┌─────────────────────────────────────────────────────────────────┐
│                        Local Device                              │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐  │
│  │  SQLite DB  │───▶│ Sync Service│───▶│ Cloud Storage       │  │
│  │  (30 tables)│◀───│             │◀───│ Provider            │  │
│  └─────────────┘    └─────────────┘    └─────────────────────┘  │
│         │                  │                      │              │
│         ▼                  ▼                      ▼              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐  │
│  │SyncRecords  │    │DeletionLog  │    │ Google Drive API    │  │
│  │(per-record) │    │(soft delete)│    │ or iCloud           │  │
│  └─────────────┘    └─────────────┘    └─────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   Cloud File    │
                    │  (JSON export)  │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  Other Devices  │
                    └─────────────────┘

```text
### Sync Tables

- **SyncMetadata**: Global sync state (last sync time, device ID, provider)
- **SyncRecords**: Per-record sync tracking with conflict detection
- **DeletionLog**: Tracks deleted records for propagation

### Conflict Resolution

When conflicts are detected:

1. Compare `localUpdatedAt` vs remote timestamp
2. Store conflicting data in `conflict_data` JSON field
3. Mark record status as `conflict`
4. Present resolution UI to user

---

## Navigation

Submersion uses **go_router** with a `ShellRoute` for persistent navigation.

### Route Structure

```

/welcome (outside shell - no nav)
│
├── /dives (with bottom nav)
│   ├── /dives/new
│   ├── /dives/:id
│   └── /dives/:id/edit
│
├── /sites
│   ├── /sites/new
│   ├── /sites/:id
│   ├── /sites/:id/edit
│   └── /sites/map
│
├── /equipment
│   ├── /equipment/new
│   ├── /equipment/:id
│   └── /equipment/sets
│
├── /statistics
│   ├── /statistics/records
│   ├── /statistics/gas
│   ├── /statistics/progression
│   └── ... (11 sub-pages)
│
├── /settings
│   ├── /settings/divers
│   ├── /settings/sync
│   └── /settings/about
│
└── /dive-computers
    ├── /dive-computers/discover
    └── /dive-computers/:id

```text
### MainScaffold

Handles responsive navigation:

- **Mobile**: Bottom navigation bar (5 tabs)
- **Tablet**: Bottom navigation bar
- **Desktop**: Side navigation rail (expandable)

---

## Dependencies

### Core Dependencies

```yaml
dependencies:
  flutter: sdk
  flutter_riverpod: ^2.5.1         # State management
  riverpod_annotation: ^2.3.5       # Provider codegen
  drift: ^2.20.0                    # SQLite ORM
  sqlite3_flutter_libs: ^0.5.24     # SQLite native libs
  go_router: ^14.3.0                # Navigation

  # UI Components
  fl_chart: ^0.68.0                 # Charts
  flutter_map: ^7.0.2               # Maps
  flutter_map_marker_cluster: ^1.3.6

  # Cloud & Platform
  google_sign_in: ^6.2.2
  googleapis: ^13.2.0
  flutter_blue_plus: ^1.32.12       # Bluetooth
  dive_computer: ^0.1.0-dev.2       # libdivecomputer FFI
  geolocator: ^13.0.2
  geocoding: ^3.0.0

  # Export/Import
  pdf: ^3.11.1
  csv: ^6.0.0
  xml: ^6.5.0

  # Utilities
  intl: ^0.19.0
  uuid: ^4.5.0
  equatable: ^2.0.5
```text
### Dev Dependencies

```yaml
dev_dependencies:
  flutter_test: sdk
  flutter_lints: ^4.0.0
  build_runner: ^2.4.12
  drift_dev: ^2.20.1
  freezed: ^2.5.7
  riverpod_generator: ^2.4.3
  mockito: ^5.4.4
```dart
---

## Testing

Submersion has 200+ tests with good coverage:

| Test Type | Count | Coverage |
| --------- | ----- | ---------- |
| Unit Tests | 150+ | Business logic, algorithms |
| Widget Tests | 50+ | UI components |
| Integration Tests | 10+ | E2E flows |

### Key Test Areas

- **Decompression**: 141 tests for Bühlmann algorithm
- **O₂ Toxicity**: 68 tests for CNS/OTU calculations
- **Repositories**: CRUD operations for all entities
- **Providers**: State management logic

Run tests:

```bash
flutter test                    # All tests
flutter test test/core/deco/    # Deco algorithm tests only
```text
---

## Platform Support

| Platform | Status | Requirements |
|----------|--------|--------------|
| iOS | ✅ Ready | iOS 13+ |
| Android | ✅ Ready | Android 7+ (API 24) |
| macOS | ✅ Ready | macOS 11+ |
| Windows | ✅ Ready | Windows 10+ |
| Linux | ✅ Ready | Modern desktop Linux |
| Web | 📋 Planned | v2.0 (requires cloud sync) |

---

## Build & Run

### Prerequisites

- Flutter SDK 3.5.0+
- Dart SDK 3.5.0+
- Xcode (for iOS/macOS)
- Android Studio (for Android)

### Quick Start

```bash
# Clone
git clone https://github.com/submersion-app/submersion.git
cd submersion

# Install dependencies
flutter pub get

# Generate code (Drift, Freezed, Riverpod)
dart run build_runner build --delete-conflicting-outputs

# Run
flutter run -d macos   # or: ios, android, windows, linux
```text
### Code Generation

After changing database schema or entities:

```bash
dart run build_runner build --delete-conflicting-outputs

# Or watch mode during development
dart run build_runner watch
```text
### Build for Release

```bash
flutter build ios --release
flutter build apk --release
flutter build macos --release
flutter build windows --release
flutter build linux --release
```text
---

## Development Roadmap

| Phase | Status | Highlights |
|-------|--------|------------|
| **v1.0** | ✅ Complete | Core logging, sites, gear, statistics |
| **v1.1** | ✅ Complete | GPS, maps, tags, profile zoom/pan |
| **v1.5** | ✅ Complete | Dive computers, deco algorithms, O₂ tracking |
| **v2.0** | 📋 Planned | Cloud sync UI, photos, multi-language |
| **v3.0** | 🔮 Future | Community features, AI species ID |

See [FEATURE_ROADMAP.md](FEATURE_ROADMAP.md) for detailed planning.

---

## Open Source

### License

GPL-3.0 - Ensures derivative works remain open source.

### Repository Structure

```text

submersion/
├── README.md
├── ARCHITECTURE.md (this file)
├── FEATURE_ROADMAP.md
├── CLAUDE.md
├── LICENSE
├── lib/
├── test/
└── docs/
    ├── UI_WIREFRAMES.md
    └── MIGRATION_STRATEGY.md

```

### Contributing

See [README.md](README.md) for contribution guidelines.

---

## References

- **libdivecomputer**: <https://www.libdivecomputer.org/>
- **Subsurface**: <https://subsurface-divelog.org/>
- **UDDF Specification**: <http://www.uddf.org/>
- **Bühlmann Algorithm**: Tauchmedizin, Prof. A.A. Bühlmann
- **NOAA O₂ Exposure Limits**: NOAA Diving Manual
