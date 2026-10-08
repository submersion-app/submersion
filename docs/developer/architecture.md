# Architecture

Submersion follows a clean architecture pattern with clear separation between layers.

## High-Level Overview

```dart
┌─────────────────────────────────────────────────────────────────┐
│                       Client Applications                        │
├──────────────┬──────────────┬──────────────┬───────────────────┤
│    macOS     │   Windows    │   Android    │       iOS         │
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

## Layer Responsibilities

### Presentation Layer

Located in `lib/features/*/presentation/`

**Responsibilities:**

- UI rendering (pages, widgets)
- User interaction handling
- State subscription (watching providers)
- Navigation triggers

**Components:**

- `pages/` - Full screen views
- `widgets/` - Reusable UI components
- `providers/` - Riverpod state providers

### Domain Layer

Located in `lib/features/*/domain/`

**Responsibilities:**

- Business entities
- Business rules
- Domain calculations
- Repository interfaces

**Components:**

- `entities/` - Pure Dart classes with business logic
- Entity methods like `copyWith()`, computed properties

### Data Layer

Located in `lib/features/*/data/` and `lib/core/`

**Responsibilities:**

- Data persistence (SQLite)
- External API calls
- Data transformation
- Caching

**Components:**

- `repositories/` - Data access implementations
- `models/` - Data transfer objects
- Database tables (Drift)

## Project Structure

```dart
lib/
├── main.dart                    # Entry point
├── app.dart                     # Root ProviderScope and MaterialApp
│
├── core/                        # Shared infrastructure
│   ├── constants/               # Enums, app constants
│   │   └── enums.dart           # All enum definitions
│   ├── database/                # Drift ORM
│   │   ├── database.dart        # AppDatabase: the schema and its version
│   │   ├── database.g.dart      # Generated code
│   │   ├── migrations/          # Upgrade ladder, helpers, beforeOpen backstops
│   │   └── tables/              # Table definitions, one library per domain
│   ├── deco/                    # Decompression algorithms
│   │   ├── buhlmann_algorithm.dart
│   │   ├── o2_toxicity_calculator.dart
│   │   └── ascent_rate_calculator.dart
│   ├── errors/                  # Error handling
│   ├── models/                  # Shared models
│   ├── router/                  # go_router configuration
│   │   └── app_router.dart
│   ├── services/                # Business services
│   │   ├── database_service.dart
│   │   ├── export_service.dart
│   │   ├── location_service.dart
│   │   ├── weather_service.dart
│   │   ├── tide_service.dart
│   │   ├── cloud_storage/       # Cloud providers
│   │   └── sync/                # Sync logic
│   ├── theme/                   # Material 3 theme
│   └── utils/                   # Utility functions
│
├── features/                    # Feature modules (17 total)
│   ├── dive_log/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   └── repositories/
│   │   │       └── dive_repository.dart
│   │   ├── domain/
│   │   │   └── entities/
│   │   │       ├── dive.dart
│   │   │       └── dive_computer.dart
│   │   └── presentation/
│   │       ├── pages/
│   │       │   ├── dive_list_page.dart
│   │       │   ├── dive_detail_page.dart
│   │       │   └── dive_edit_page.dart
│   │       ├── widgets/
│   │       │   ├── dive_profile_chart.dart
│   │       │   └── deco_info_panel.dart
│   │       └── providers/
│   │           └── dive_providers.dart
│   │
│   ├── dive_sites/
│   ├── dive_computer/
│   ├── equipment/
│   ├── insights/
│   ├── import_export/
│   ├── settings/
│   ├── divers/
│   ├── buddies/
│   ├── certifications/
│   ├── dive_centers/
│   ├── trips/
│   ├── tags/
│   ├── dive_types/
│   ├── marine_life/
│   ├── tools/
│   └── setup_wizard/
│
└── shared/                      # Shared components
    ├── constants/
    ├── models/
    ├── services/
    └── widgets/
        └── main_scaffold.dart   # Navigation shell
```

## Domain/Data Separation

### Why Separate?

- Drift generates database classes
- Domain entities are clean Dart
- Avoids Drift dependencies in UI
- Enables testing without database

### Import Aliases

Resolve naming conflicts:

```dart
import '../../domain/entities/dive.dart' as domain;
import '../../../core/database/database.dart';

domain.Dive _mapToDomain(Dive dbRow) {
  return domain.Dive(
    id: dbRow.id,
    diveNumber: dbRow.diveNumber,
    // ...
  );
}
```dart
## Dependency Injection

### Riverpod Providers

```dart
// Singleton repository
final diveRepositoryProvider = Provider<DiveRepository>((ref) {
  return DiveRepository();
});

// Access in widgets
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(diveRepositoryProvider);
    // ...
  }
}
```text
### Database Service

Singleton pattern for database:

```dart
class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  late final AppDatabase database;

  Future<void> initialize() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(path.join(dbFolder.path, 'submersion.db'));
    database = AppDatabase(NativeDatabase(file));
  }
}
```text
## External Integrations

### Dive Computer (libdivecomputer)

```

Flutter App
    │
    ▼
dive_computer package (Dart FFI)
    │
    ▼
libdivecomputer (C library)
    │
    ▼
Dive Computer (Bluetooth/USB)

```text
### Cloud Sync

```

┌─────────────────┐     ┌─────────────────┐
│   SyncService   │────▶│ CloudProvider   │
└─────────────────┘     └────────┬────────┘
                                 │
                    ┌────────────┴────────────┐
                    ▼                         ▼
           ┌─────────────┐           ┌─────────────┐
           │Google Drive │           │   iCloud    │
           └─────────────┘           └─────────────┘

```text
## Error Handling

### Result Pattern

```dart
class Result<T> {
  final T? data;
  final AppError? error;

  bool get isSuccess => error == null;
}
```text
### Error Types

```dart
abstract class AppError {
  final String message;
  final dynamic originalError;
}

class DatabaseError extends AppError { }
class NetworkError extends AppError { }
class ValidationError extends AppError { }
```text
## Configuration

### Environment

App configuration in `lib/core/constants/`:

```dart
class AppConfig {
  static const String appName = 'Submersion';
  static const String databaseName = 'submersion.db';
  static const int schemaVersion = 4;
}
```

### Build Flavors

Different configurations for:

- Development
- Staging
- Production

## Performance Considerations

### Lazy Loading

- Providers are lazily evaluated
- Heavy computations deferred
- Images loaded on-demand

### Database Indexing

Key indexes in schema:

- `dive_profiles(dive_id, timestamp)`
- `dives(diver_id, dive_date_time)`

### Profile Memory

Large profile data:

- Loaded only when viewing
- Disposed after navigation
- Streamed for charts

## Decompression and Gas Calculations

The decompression and gas code lives in `lib/core/deco/`.

- **Decompression models.** `BuhlmannAlgorithm` (`buhlmann_algorithm.dart`)
  implements Buhlmann ZH-L16C with gradient factors, using the 16
  compartment coefficients in `constants/buhlmann_coefficients.dart`
  (`GradientFactorPresets` holds the presets). `VpmBAlgorithm`
  (`vpm_b_algorithm.dart`) implements VPM-B. Callers that should not care
  which model runs use the `DecoModel` interface in `deco_model.dart`
  (which also defines `DecoSchedule` and `DecoSegment`), implemented by
  `BuhlmannGf` in the same file and `VpmB` in `vpm_b.dart`.
- **Oxygen exposure.** `O2ToxicityCalculator` (`o2_toxicity_calculator.dart`)
  tracks CNS% from the NOAA exposure limits and pulmonary exposure as OTU.
  How a ppO2 between or beyond the table entries is charged is a diver
  setting, `CnsCalculationMethod` (`entities/cns_calculation_method.dart`).
- **Ascent rate.** `AscentRateCalculator` (`ascent_rate_calculator.dart`)
  flags ascents faster than 9 m/min as a warning and faster than 12 m/min
  as critical by default, over a 15-second smoothing window.
- **Related calculators.** Altitude (`altitude_calculator.dart`), gas
  density (`gas_density.dart`), maximum operating depth
  (`max_operating_depth.dart`), semi-closed rebreather loop gas
  (`scr_calculator.dart`), and ascent gas planning (`ascent/`).
- **Gas-switch analysis.** `gas_switch/` finds late and missed deco gas
  switches in a logged open-circuit dive and costs each one by replaying
  its tissue loading (`GasSwitchEfficiencyAnalyzer`).

## Sync Conflict Resolution

Most concurrent edits never become conflicts. Synced rows carry a Hybrid
Logical Clock (`hlc`; nullable, since rows written before the HLC rollout
have none). When both the local and the remote version have one, the clock
decides: a strictly newer remote HLC wins, and a tie or
a newer local HLC keeps the local row
(`lib/core/services/sync/sync_service.dart`).

A record is stored as a conflict for the diver to resolve in two cases:

- **Pre-HLC rows.** When either side lacks an HLC and both sides changed
  since the last sync, the remote version is kept in `conflictData`.
- **An edit racing a delete.** When a peer deleted a record that was
  edited here, `conflictData` holds a deletion marker (`_deleted`,
  `deletedAt`) instead of a row.

Either way the record's row in the sync records table
(`lib/core/database/tables/sync_tables.dart`) gets the status `conflict`,
and the sync reports `hasConflicts`. `SyncService.getConflicts()` turns
those records into `SyncConflict` objects carrying both versions and their
modification times. Junction rows hold nothing but ids, so
`ConflictReferenceResolver` (`conflict_reference.dart`) resolves each
foreign key to a name or date the Resolve Conflicts dialog can show. The
diver then chooses a `ConflictResolution`: keep local, keep remote, or keep
both.

## Platform Support

| Platform | Minimum |
|----------|---------|
| iOS | 15.0 |
| Android | 8.0 (API 26) |
| macOS | 12.0 |
| Windows | 10 |
| Linux | x86-64 with glibc 2.38+ and GTK 3 (Ubuntu 24.04+, Debian 13+, Fedora 39+) |

The minimums come from `IPHONEOS_DEPLOYMENT_TARGET` in
`ios/Runner.xcodeproj/project.pbxproj`, `minSdk` in
`android/app/build.gradle.kts` and `MACOSX_DEPLOYMENT_TARGET` in
`macos/Runner.xcodeproj/project.pbxproj`; the Linux requirement is the
"Linux: installing" section of the repository `README.md`.

## Testing Strategy

See [Testing Guide](testing.md) for details.

| Layer | Test Type |
|-------|-----------|
| Domain | Unit tests |
| Data | Unit tests with mocks |
| Presentation | Widget tests |
| Full app | Integration tests |
