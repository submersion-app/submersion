# Code Style

Consistent code style makes the codebase easier to read and maintain.

## Dart Style

Follow the [Dart style guide](https://dart.dev/guides/language/effective-dart/style) with these additions:

### Imports

Group imports in this order, separated by blank lines:

```dart
// Dart core libraries
import 'dart:async';
import 'dart:math';

// Flutter framework
import 'package:flutter/material.dart';

// Third-party packages
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

// Local imports (relative)
import '../domain/entities/dive.dart';
import '../widgets/dive_card.dart';
```

### File Naming

| Type | Convention | Example |
|------|------------|---------|
| Files | snake_case | `dive_repository.dart` |
| Classes | PascalCase | `DiveRepository` |
| Variables | camelCase | `diveList` |
| Constants | camelCase | `defaultDepthUnit` |
| Enums | PascalCase | `DepthUnit.meters` |

### File Organization

```dart
// 1. Imports

// 2. Part directives (for generated code)
part 'dive.g.dart';
part 'dive.freezed.dart';

// 3. Type aliases

// 4. Enums

// 5. Classes/Widgets
```

## Provider Naming

| Type | Convention | Example |
|------|------------|---------|
| Data provider | `<noun>Provider` | `divesProvider` |
| Notifier | `<noun>NotifierProvider` | `diveListNotifierProvider` |
| Family | `<noun>Provider` | `diveProvider(id)` |
| Repository | `<noun>RepositoryProvider` | `diveRepositoryProvider` |

### Examples

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

## Entity Patterns

### Domain Entities

All domain entities should have `copyWith`:

```dart
class Dive {
  final String id;
  final DateTime dateTime;
  final double? maxDepth;
  final int? duration;

  const Dive({
    required this.id,
    required this.dateTime,
    this.maxDepth,
    this.duration,
  });

  Dive copyWith({
    String? id,
    DateTime? dateTime,
    double? maxDepth,
    int? duration,
  }) {
    return Dive(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      maxDepth: maxDepth ?? this.maxDepth,
      duration: duration ?? this.duration,
    );
  }
}
```

### Import Aliases

Use aliases to resolve naming conflicts:

```dart
import '../../domain/entities/dive.dart' as domain;
import '../../../core/database/database.dart';

domain.Dive _mapToDomain(Dive dbRow) {
  return domain.Dive(
    id: dbRow.id,
    dateTime: DateTime.fromMillisecondsSinceEpoch(dbRow.diveDateTime),
    // ...
  );
}
```

## Widget Patterns

### ConsumerWidget

Use `ConsumerWidget` for widgets that need providers:

```dart
class DiveListPage extends ConsumerWidget {
  const DiveListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final divesAsync = ref.watch(diveListNotifierProvider);

    return divesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => ErrorWidget(error.toString()),
      data: (dives) => ListView.builder(
        itemCount: dives.length,
        itemBuilder: (context, index) => DiveCard(dive: dives[index]),
      ),
    );
  }
}
```

### Stateful with Consumer

For stateful widgets:

```dart
class DiveEditPage extends ConsumerStatefulWidget {
  final String? diveId;

  const DiveEditPage({super.key, this.diveId});

  @override
  ConsumerState<DiveEditPage> createState() => _DiveEditPageState();
}

class _DiveEditPageState extends ConsumerState<DiveEditPage> {
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ...
  }
}
```

### Widget Keys

Use `super.key` pattern:

```dart
class DiveCard extends StatelessWidget {
  final Dive dive;

  const DiveCard({super.key, required this.dive});

  // ...
}
```

## Documentation

### When to Document

- Complex algorithms
- Non-obvious business logic
- Public APIs
- Workarounds or hacks

### Documentation Style

```dart
/// Calculates the maximum operating depth for a given gas mix.
///
/// Uses the formula: MOD = ((ppO2 limit / O2 fraction) - 1) * 10
///
/// [ppO2Limit] defaults to 1.4 bar for recreational diving.
/// Returns depth in meters.
double calculateMOD({double ppO2Limit = 1.4}) {
  // ...
}
```

### Inline Comments

Use for non-obvious code:

```dart
// Drift uses milliseconds, not seconds
final timestamp = dateTime.millisecondsSinceEpoch;

// Skip if no profiles (prevents division by zero)
if (profiles.isEmpty) return null;
```

## Navigation

### Named Routes

Prefer named routes:

```dart
// Good
context.goNamed('diveDetail', pathParameters: {'diveId': dive.id});

// Avoid
context.go('/dives/${dive.id}');
```

### Passing Data

```dart
// Via path parameters
context.goNamed('diveDetail', pathParameters: {'diveId': '123'});

// Via extra for complex data
context.goNamed('newBuddy', extra: {'name': 'John', 'email': 'john@example.com'});
```

## Error Handling

### AsyncValue Pattern

```dart
divesAsync.when(
  loading: () => const LoadingIndicator(),
  error: (error, stack) => ErrorDisplay(error: error),
  data: (dives) => DiveList(dives: dives),
);
```

### Try-Catch

Use specific error handling:

```dart
try {
  await repository.saveDive(dive);
} on DatabaseException catch (e) {
  // Handle database error
} on NetworkException catch (e) {
  // Handle network error
}
```

## Performance

### Avoid Rebuilds

Use `select` to watch specific state:

```dart
final depthUnit = ref.watch(
  settingsProvider.select((s) => s.depthUnit),
);
```

### Lazy Loading

Load expensive data on demand:

```dart
// Load profiles only when needed
final profilesAsync = ref.watch(diveProfilesProvider(diveId));
```

## Formatting

### Line Length

Maximum 80 characters per line.

### Trailing Commas

Use trailing commas for multi-line:

```dart
const Dive(
  id: '123',
  dateTime: DateTime(2024, 1, 15),
  maxDepth: 18.5,
);
```

### Run Formatter

Always format before committing:

```bash
dart format lib/
```

## Analysis

### Enable Strict Analysis

The project uses strict analysis rules. Fix all warnings:

```bash
flutter analyze
```

### Common Issues

| Warning | Fix |
|---------|-----|
| Unused import | Remove the import |
| Unused variable | Remove or prefix with `_` |
| Missing return type | Add explicit type |
| Nullable issues | Add null checks |

## Testing

### Test Naming

Use descriptive names:

```dart
test('creates dive with auto-incremented number', () async {
  // ...
});

test('returns null when dive not found', () async {
  // ...
});
```

### Test Organization

```dart
group('DiveRepository', () {
  group('createDive', () {
    test('assigns next dive number', () async { });
    test('sets created timestamp', () async { });
  });

  group('getAllDives', () {
    test('returns dives sorted by date', () async { });
    test('filters by diver ID', () async { });
  });
});
```

