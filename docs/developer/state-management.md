# State Management

Submersion uses Riverpod for reactive state management with consistent patterns.

## Provider Types

| Provider | Use Case | Example |
|----------|----------|---------|
| `Provider` | Singletons | Repositories |
| `FutureProvider` | Async data | Fetching lists |
| `FutureProvider.family` | Parameterized | Get by ID |
| `StateNotifierProvider` | Mutable CRUD | List with mutations |
| `StateProvider` | Simple state | Filters, toggles |

## Repository Providers

Singletons for data access:

```dart
final diveRepositoryProvider = Provider<DiveRepository>((ref) {
  return DiveRepository();
});

final siteRepositoryProvider = Provider<SiteRepository>((ref) {
  return SiteRepository();
});
```

## FutureProvider

### Simple List

```dart
final divesProvider = FutureProvider<List<domain.Dive>>((ref) async {
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final repository = ref.watch(diveRepositoryProvider);
  return repository.getAllDives(diverId: diverId);
});
```

### Family Provider

Parameterized queries:

```dart
final diveProvider = FutureProvider.family<domain.Dive?, String>(
  (ref, id) async {
    final repository = ref.watch(diveRepositoryProvider);
    return repository.getDiveById(id);
  },
);

// Usage
final dive = ref.watch(diveProvider('dive-123'));
```

## StateNotifier Pattern

### Full Implementation

```dart
class DiveListNotifier extends StateNotifier<AsyncValue<List<domain.Dive>>> {
  final DiveRepository _repository;
  final Ref _ref;
  String? _currentDiverId;

  DiveListNotifier(this._repository, this._ref)
      : super(const AsyncLoading()) {
    _loadDives();

    // Listen for diver changes
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        _currentDiverId = next;
        _loadDives();
      }
    });
  }

  Future<void> _loadDives() async {
    state = const AsyncLoading();
    try {
      final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
      final dives = await _repository.getAllDives(diverId: diverId);
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
    _ref.invalidate(diveStatisticsProvider);
    _invalidateRelatedProviders(dive);
    await _loadDives();
  }

  Future<void> deleteDive(String id) async {
    await _repository.deleteDive(id);
    _ref.invalidate(diveStatisticsProvider);
    await _loadDives();
  }

  void _invalidateRelatedProviders(domain.Dive dive) {
    if (dive.tripId != null) {
      _ref.invalidate(tripWithStatsProvider(dive.tripId!));
    }
    if (dive.diveCenter != null) {
      _ref.invalidate(diveCenterDiveCountProvider(dive.diveCenter!.id));
    }
  }
}

// Provider
final diveListNotifierProvider =
    StateNotifierProvider<DiveListNotifier, AsyncValue<List<domain.Dive>>>(
  (ref) => DiveListNotifier(
    ref.watch(diveRepositoryProvider),
    ref,
  ),
);
```

## Multi-Diver Support

### Current Diver Provider

```dart
// Persisted diver ID
final currentDiverIdProvider = StateNotifierProvider<CurrentDiverIdNotifier, String?>(
  (ref) => CurrentDiverIdNotifier(ref.watch(sharedPreferencesProvider)),
);

// Validated (ensures diver exists)
final validatedCurrentDiverIdProvider = FutureProvider<String?>((ref) async {
  final currentId = ref.watch(currentDiverIdProvider);
  if (currentId == null) return null;

  final diver = await ref.watch(diverProvider(currentId).future);
  return diver != null ? currentId : null;
});
```

### Diver-Scoped Data

All data providers filter by diver:

```dart
final divesProvider = FutureProvider<List<domain.Dive>>((ref) async {
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  if (diverId == null) return [];

  final repository = ref.watch(diveRepositoryProvider);
  return repository.getAllDives(diverId: diverId);
});
```

## Provider Invalidation

### Strategic Invalidation

Only invalidate what changed:

```dart
Future<void> updateDive(domain.Dive dive) async {
  await _repository.updateDive(dive);

  // Specific dive
  _ref.invalidate(diveProvider(dive.id));

  // Aggregate stats
  _ref.invalidate(diveStatisticsProvider);

  // Related entities
  if (dive.tripId != null) {
    _ref.invalidate(tripWithStatsProvider(dive.tripId!));
  }
}
```

### Refresh Pattern

Force reload:

```dart
ref.invalidate(divesProvider);
// or
ref.refresh(divesProvider);
```

## Consuming Providers

### In Widgets

```dart
class DiveListPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final divesAsync = ref.watch(diveListNotifierProvider);

    return divesAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
      data: (dives) => ListView.builder(
        itemCount: dives.length,
        itemBuilder: (context, index) => DiveCard(dive: dives[index]),
      ),
    );
  }
}
```

### Reading vs Watching

```dart
// Watch: Rebuilds on change
final dives = ref.watch(divesProvider);

// Read: One-time read
final repository = ref.read(diveRepositoryProvider);
```

## Filter Providers

### StateProvider for Filters

```dart
final diveFilterProvider = StateProvider<DiveFilterState>((ref) {
  return DiveFilterState.initial();
});

class DiveFilterState {
  final DateRange? dateRange;
  final String? diveType;
  final List<String> tagIds;

  // ...
}
```

### Computed/Derived Provider

```dart
final filteredDivesProvider = Provider<AsyncValue<List<domain.Dive>>>((ref) {
  final divesAsync = ref.watch(diveListNotifierProvider);
  final filter = ref.watch(diveFilterProvider);

  return divesAsync.whenData((dives) {
    return dives.where((dive) {
      if (filter.dateRange != null) {
        if (!filter.dateRange!.contains(dive.dateTime)) return false;
      }
      if (filter.diveType != null) {
        if (dive.diveTypeId != filter.diveType) return false;
      }
      // More filters...
      return true;
    }).toList();
  });
});
```

## Convenience Selectors

### Select Specific State

```dart
final depthUnitProvider = Provider<DepthUnit>((ref) {
  return ref.watch(settingsProvider.select((s) => s.depthUnit));
});
```

Avoids rebuilds when other settings change.

## Async Operations

### In StateNotifier

```dart
Future<void> saveAndNavigate(domain.Dive dive) async {
  state = const AsyncLoading();
  try {
    await _repository.createDive(dive);
    state = AsyncData(dive);
    // Navigation handled in UI
  } catch (e, st) {
    state = AsyncError(e, st);
  }
}
```

### In UI

```dart
onPressed: () async {
  await ref.read(diveListNotifierProvider.notifier).addDive(dive);
  if (mounted) {
    context.go('/dives');
  }
}
```

## Testing Providers

### Override in Tests

```dart
testWidgets('shows dives', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        diveRepositoryProvider.overrideWithValue(MockDiveRepository()),
        divesProvider.overrideWith((ref) async => [testDive]),
      ],
      child: const MyApp(),
    ),
  );
});
```

## Best Practices

1. **Use family for IDs** - `diveProvider(id)` not `diveProvider`
2. **Invalidate strategically** - Don't invalidate everything
3. **Listen for diver changes** - Data is diver-scoped
4. **AsyncValue.when** - Handle all states
5. **Select for performance** - Avoid unnecessary rebuilds
6. **Read vs Watch** - Read for actions, watch for UI
