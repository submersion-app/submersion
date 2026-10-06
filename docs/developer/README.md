# Developer Guide

Welcome to the Submersion developer documentation. This section covers architecture, patterns, and how to contribute to the codebase.

## Quick Links

- [Architecture](architecture.md): System design and layers
- [Database](database.md): Schema and Drift ORM
- [State Management](state-management.md): Riverpod patterns
- [Navigation](navigation.md): go_router setup
- [Testing](testing.md): Test organization and running
- [Local Test Performance](local-test-performance.md): Making local test runs fast
- [Building](building.md): Build and run instructions
- [Release Process](release-process.md): Beta and production releases
- [Release Secrets](release-secrets-setup.md): Store and signing credentials
- [Play Production Access](play-production-access.md): Google Play access record and Data safety declaration
- [Reference](reference/README.md): Entities, enums and file formats

## Technology Stack

| Layer | Technology |
|-------|------------|
| **Framework** | Flutter 3.x |
| **State** | Riverpod 2.5 |
| **Database** | Drift 2.20 (SQLite) |
| **Navigation** | go_router 14.x |
| **Charts** | fl_chart |
| **Maps** | flutter_map |
| **Bluetooth** | flutter_blue_plus |
| **Dive Computers** | libdivecomputer (FFI) |

## Project Structure

```text
lib/
├── main.dart              # Entry point
├── app.dart               # Root widget
├── core/                  # Shared infrastructure
│   ├── constants/         # Enums, constants
│   ├── database/          # Drift schema (43 tables)
│   ├── deco/              # Decompression algorithms
│   ├── router/            # Navigation
│   ├── services/          # Business services
│   └── theme/             # Material 3 theme
├── features/              # Feature modules (17)
│   ├── dive_log/
│   ├── dive_sites/
│   ├── equipment/
│   └── ...
└── shared/                # Reusable components
```

## Getting Started

### Prerequisites

- Flutter SDK 3.5+
- Dart SDK 3.5+
- IDE: VS Code or Android Studio

### Setup

```bash
# Clone
git clone https://github.com/submersion-app/submersion.git
cd submersion

# Install dependencies
flutter pub get

# Generate code
dart run build_runner build --delete-conflicting-outputs

# Run
flutter run -d macos
```text
### Code Generation

After changing schemas or annotations:

```bash
dart run build_runner build --delete-conflicting-outputs
```text
## Architecture Overview

### Layered Architecture

```

┌─────────────────────────────────────┐
│      Presentation Layer            │
│  Pages, Widgets, Providers          │
└────────────────┬────────────────────┘
                 │
┌────────────────▼────────────────────┐
│        Domain Layer                 │
│   Entities, Repository Interfaces   │
└────────────────┬────────────────────┘
                 │
┌────────────────▼────────────────────┐
│         Data Layer                  │
│  Repositories, Database, APIs       │
└─────────────────────────────────────┘

```text
### Feature Module Structure

Each feature follows this pattern:

```

feature_name/
├── data/
│   ├── models/
│   └── repositories/
├── domain/
│   └── entities/
└── presentation/
    ├── pages/
    ├── widgets/
    └── providers/

```dart
## Key Patterns

### Riverpod State Management

```dart
// Repository singleton
final diveRepositoryProvider = Provider<DiveRepository>((ref) {
  return DiveRepository();
});

// Async data
final divesProvider = FutureProvider<List<Dive>>((ref) async {
  return ref.watch(diveRepositoryProvider).getAllDives();
});

// Mutable state
final diveListNotifierProvider =
    StateNotifierProvider<DiveListNotifier, AsyncValue<List<Dive>>>(
  (ref) => DiveListNotifier(ref.watch(diveRepositoryProvider), ref),
);
```text
### Database Access

```dart
// Drift table
class Dives extends Table {
  TextColumn get id => text()();
  IntColumn get diveNumber => integer().nullable()();
  // ...
  @override
  Set<Column> get primaryKey => {id};
}

// Repository
class DiveRepository {
  final AppDatabase _db = DatabaseService.instance.database;

  Future<List<Dive>> getAllDives() async {
    final rows = await _db.select(_db.dives).get();
    return rows.map(_mapToDomain).toList();
  }
}
```

## Contributing

See the [Contributing Guide](../contributing/README.md) for:

- [Code Style](../contributing/code-style.md)
- [Pull Requests](../contributing/pull-requests.md)
- [Roadmap](../contributing/roadmap.md)

## Need Help?

- **GitHub Issues**: [Report bugs](https://github.com/submersion-app/submersion/issues)
- **Discussions**: [Ask questions](https://github.com/submersion-app/submersion/discussions)
- **Source Code**: Browse the [repository](https://github.com/submersion-app/submersion)
