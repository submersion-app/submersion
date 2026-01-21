# Submersion Architecture Codemap

> Freshness: 2026-01-21 | Files: 303 | LOC: ~163k

## Overview

Flutter dive logging application using feature-first architecture with clean separation between domain, data, and presentation layers.

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI Framework | Flutter 3.x, Material 3 |
| State Management | Riverpod (Provider, FutureProvider, StateNotifier) |
| Database | Drift ORM (SQLite) |
| Navigation | go_router with ShellRoute |
| Platforms | iOS, Android, macOS, Windows, Linux |

## Directory Structure

```
lib/
├── main.dart                 # App entry, DB init, provider scope
├── app.dart                  # SubmersionApp widget, theme config
├── core/                     # Shared infrastructure
│   ├── database/             # Drift schema (32 tables)
│   ├── constants/            # Enums, units, gas/tank presets
│   ├── providers/            # Riverpod re-exports
│   ├── services/             # DB, export, sync, location
│   ├── deco/                 # Buhlmann algorithm, O2 toxicity
│   ├── tide/                 # Harmonic tide calculator
│   ├── theme/                # Colors, typography
│   ├── router/               # go_router config
│   └── utils/                # Unit formatter, weight calc
├── features/                 # Feature modules (26 modules)
│   └── <feature>/
│       ├── data/             # Repositories, services
│       ├── domain/           # Entities (clean Dart classes)
│       └── presentation/     # Pages, widgets, providers
└── shared/                   # Cross-feature widgets
    ├── widgets/              # MainScaffold, MasterDetail
    └── providers/            # Selection state providers
```

## Core Services

| Service | Path | Purpose |
|---------|------|---------|
| DatabaseService | `core/services/database_service.dart` | Drift DB singleton |
| ExportService | `core/services/export_service.dart` | UDDF/CSV/JSON export |
| SyncService | `core/services/sync/sync_service.dart` | iCloud/Cloud sync |
| LocationService | `core/services/location_service.dart` | GPS positioning |
| DatabaseLocationService | `core/services/database_location_service.dart` | Custom DB path |

## Feature Modules (26)

| Module | Entities | Primary Use |
|--------|----------|-------------|
| dive_log | Dive, DiveTank, DiveProfilePoint | Core dive entries |
| dive_sites | DiveSite | Location management |
| dive_planner | Plan segments | Decompression planning |
| equipment | EquipmentItem, ServiceRecord | Gear tracking |
| buddies | Buddy | Dive partner contacts |
| certifications | Certification | Diver credentials |
| dive_centers | DiveCenter | Operator info |
| trips | Trip | Dive trip grouping |
| statistics | Stats models | Analytics & records |
| divers | Diver, DiverSettings | Multi-profile support |
| tags | Tag | Dive organization |
| dive_types | DiveTypeEntity | Custom dive categories |
| tank_presets | TankPresetEntity | Reusable tank configs |
| marine_life | Species, Sighting | Wildlife tracking |
| tides | TideRecord | Tide data per dive |
| dive_computer | DiveComputer | Device management |
| deco_calculator | - | Real-time deco calc |
| gas_calculators | - | MOD/END/EAD tools |
| surface_interval_tool | - | SI desaturation |
| import_export | - | UDDF import/export |
| settings | - | App configuration |
| dashboard | - | Home screen |
| planning | - | Planning hub shell |
| tools | - | Weight calculator |
| transfer | - | Data transfer hub |
| onboarding | - | First-run welcome |

## State Management Patterns

```dart
// Repository singleton
final diveRepositoryProvider = Provider((ref) => DiveRepositoryImpl());

// Async data fetch
final divesProvider = FutureProvider.autoDispose((ref) async {
  return ref.watch(diveRepositoryProvider).getAllDives();
});

// Parameterized query
final diveByIdProvider = FutureProvider.autoDispose.family<Dive?, String>(
  (ref, id) => ref.watch(diveRepositoryProvider).getDiveById(id),
);

// Mutable state
final diveEditNotifierProvider = StateNotifierProvider.autoDispose<...>(...);
```

## Navigation Structure

```
/dashboard              # Home
/planning/*             # Planning hub (ShellRoute)
  /dive-planner         # Deco planner
  /deco-calculator      # Real-time calc
  /gas-calculators      # MOD/END tools
/dives/*                # Dive log
/sites/*                # Dive sites
/equipment/*            # Gear management
/buddies/*              # Buddy contacts
/statistics/*           # Analytics (10 sub-pages)
/settings/*             # Configuration
/transfer               # Import/Export hub
```

## Key Dependencies

- `drift` - SQLite ORM with type-safe queries
- `flutter_riverpod` - State management
- `go_router` - Declarative routing
- `fl_chart` - Dive profile visualization
- `equatable` - Value equality for entities
- `uuid` - Record ID generation
