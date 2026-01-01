# Architecture

Submersion follows a clean architecture pattern with clear separation between layers.

## High-Level Overview

```
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

```
lib/
├── main.dart                    # Entry point
├── app.dart                     # Root ProviderScope and MaterialApp
│
├── core/                        # Shared infrastructure
│   ├── constants/               # Enums, app constants
│   │   └── enums.dart           # All enum definitions
│   ├── database/                # Drift ORM
│   │   ├── database.dart        # Table definitions
│   │   └── database.g.dart      # Generated code
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
│   ├── statistics/
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
│   └── onboarding/
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
```

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
```

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
```

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
```

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
```

## Error Handling

### Result Pattern

```dart
class Result<T> {
  final T? data;
  final AppError? error;

  bool get isSuccess => error == null;
}
```

### Error Types

```dart
abstract class AppError {
  final String message;
  final dynamic originalError;
}

class DatabaseError extends AppError { }
class NetworkError extends AppError { }
class ValidationError extends AppError { }
```

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

## Testing Strategy

See [Testing Guide](developer/testing.md) for details.

| Layer | Test Type |
|-------|-----------|
| Domain | Unit tests |
| Data | Unit tests with mocks |
| Presentation | Widget tests |
| Full app | Integration tests |
