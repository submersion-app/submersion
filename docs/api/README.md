# API Reference

This section documents the core data models, enums, and providers used in Submersion.

## Overview

Submersion follows a layered architecture with clear separation:

| Layer | Contents |
|-------|----------|
| **Domain** | Business entities (pure Dart classes) |
| **Data** | Repositories, database models, mappers |
| **Presentation** | Riverpod providers, widgets |

## Key Concepts

### Domain Entities

Located in `lib/features/*/domain/entities/`

Domain entities are:
- Pure Dart classes with no external dependencies
- Immutable with `copyWith` methods
- Extend `Equatable` for value equality
- Contain business logic and calculated properties

### Repositories

Located in `lib/features/*/data/repositories/`

Repositories:
- Abstract data access
- Map between database and domain models
- Handle CRUD operations
- Manage relationships

### Providers

Located in `lib/features/*/presentation/providers/`

Riverpod providers:
- Manage state and reactivity
- Handle async data loading
- Provide dependency injection
- Support caching and invalidation

## Quick Links

- [Entities](api/entities.md) - Domain entity reference
- [Enums](api/enums.md) - Enum values reference
- [Providers](api/providers.md) - Riverpod provider reference

## Import Patterns

### Domain vs Database

Use aliases to resolve naming conflicts:

```dart
import '../../domain/entities/dive.dart' as domain;
import '../../../core/database/database.dart';

// Use domain.Dive for business logic
domain.Dive createDive() { ... }

// Use Dive (database) for data access
Future<Dive> queryDive() { ... }
```

### Provider Access

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/dive_providers.dart';

class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dives = ref.watch(divesProvider);
    // ...
  }
}
```

## Entity Categories

| Category | Entities |
|----------|----------|
| **Core** | Dive, DiveTank, DiveProfilePoint, GasMix |
| **Location** | DiveSite, DiveCenter, Trip |
| **People** | Diver, Buddy, Certification |
| **Equipment** | EquipmentItem, EquipmentSet, ServiceRecord |
| **Organization** | Tag, DiveType |
| **Profile** | DiveComputer, ProfileEvent, GasSwitch |
| **Wildlife** | Species, MarineSighting |

## Common Patterns

### Entity with Relationships

```dart
class Dive extends Equatable {
  final String id;
  final DiveSite? site;        // Optional reference
  final List<DiveTank> tanks;  // One-to-many
  final List<Tag> tags;        // Many-to-many

  // Calculated property
  double? get sac { ... }

  // Copy with modifications
  Dive copyWith({...}) { ... }
}
```

### Repository Pattern

```dart
class DiveRepository {
  final AppDatabase _db = DatabaseService.instance.database;

  Future<List<Dive>> getAllDives({String? diverId}) async { ... }
  Future<Dive?> getDiveById(String id) async { ... }
  Future<Dive> createDive(Dive dive) async { ... }
  Future<void> updateDive(Dive dive) async { ... }
  Future<void> deleteDive(String id) async { ... }
}
```

### Provider Hierarchy

```dart
// Repository singleton
final diveRepositoryProvider = Provider<DiveRepository>((ref) {
  return DiveRepository();
});

// Async data
final divesProvider = FutureProvider<List<Dive>>((ref) async {
  return ref.watch(diveRepositoryProvider).getAllDives();
});

// Parameterized query
final diveProvider = FutureProvider.family<Dive?, String>((ref, id) async {
  return ref.watch(diveRepositoryProvider).getDiveById(id);
});

// Mutable state
final diveListNotifierProvider =
    StateNotifierProvider<DiveListNotifier, AsyncValue<List<Dive>>>(
  (ref) => DiveListNotifier(ref.watch(diveRepositoryProvider), ref),
);
```

## Database Schema

For database details, see:
- [Database Documentation](developer/database.md)
- Source: `lib/core/database/database.dart`

## Further Reading

- [Architecture](developer/architecture.md)
- [State Management](developer/state-management.md)
- [Code Style](contributing/code-style.md)

