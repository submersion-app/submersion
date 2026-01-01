# Provider Reference

Reference documentation for Riverpod providers in Submersion.

## Provider Types

| Type | Use Case |
|------|----------|
| `Provider` | Singleton services (repositories) |
| `FutureProvider` | Async data loading |
| `FutureProvider.family` | Parameterized queries |
| `StateNotifierProvider` | Mutable state with CRUD |
| `StateProvider` | Simple state (filters, toggles) |

## Dive Providers

**Location:** `lib/features/dive_log/presentation/providers/dive_providers.dart`

### diveRepositoryProvider

Repository singleton for dive data access.

```dart
final diveRepositoryProvider = Provider<DiveRepository>((ref) {
  return DiveRepository();
});
```

**Usage:**
```dart
final repository = ref.read(diveRepositoryProvider);
```

---

### divesProvider

All dives for current diver.

```dart
final divesProvider = FutureProvider<List<Dive>>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getAllDives(diverId: currentDiverId);
});
```

**Usage:**
```dart
final divesAsync = ref.watch(divesProvider);
divesAsync.when(
  data: (dives) => DiveList(dives: dives),
  loading: () => LoadingIndicator(),
  error: (e, st) => ErrorDisplay(error: e),
);
```

---

### diveProvider

Single dive by ID.

```dart
final diveProvider = FutureProvider.family<Dive?, String>((ref, id) async {
  final repository = ref.watch(diveRepositoryProvider);
  return repository.getDiveById(id);
});
```

**Usage:**
```dart
final diveAsync = ref.watch(diveProvider(diveId));
```

---

### diveListNotifierProvider

Mutable dive list with CRUD operations.

```dart
final diveListNotifierProvider =
    StateNotifierProvider<DiveListNotifier, AsyncValue<List<Dive>>>((ref) {
  final repository = ref.watch(diveRepositoryProvider);
  return DiveListNotifier(repository, ref);
});
```

**Methods:**

| Method | Parameters | Description |
|--------|------------|-------------|
| `addDive` | Dive | Create new dive |
| `updateDive` | Dive | Update existing dive |
| `deleteDive` | String id | Delete dive |
| `bulkDeleteDives` | List\<String\> ids | Delete multiple |
| `restoreDives` | List\<Dive\> | Undo delete |
| `toggleFavorite` | String id | Toggle favorite |
| `setFavorite` | String id, bool | Set favorite |
| `refresh` | - | Reload list |

**Usage:**
```dart
// Read notifier
ref.read(diveListNotifierProvider.notifier).addDive(dive);

// Watch state
final divesAsync = ref.watch(diveListNotifierProvider);
```

---

### diveFilterProvider

Filter state for dive list.

```dart
final diveFilterProvider = StateProvider<DiveFilterState>((ref) {
  return const DiveFilterState();
});
```

**DiveFilterState Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `startDate` | DateTime? | Start of date range |
| `endDate` | DateTime? | End of date range |
| `diveTypeId` | String? | Filter by dive type |
| `siteId` | String? | Filter by site |
| `minDepth` | double? | Minimum depth |
| `maxDepth` | double? | Maximum depth |
| `favoritesOnly` | bool? | Show only favorites |
| `tagIds` | List\<String\> | Filter by tags |

**Usage:**
```dart
// Update filter
ref.read(diveFilterProvider.notifier).state = filter.copyWith(
  favoritesOnly: true,
);

// Check for active filters
final hasFilters = ref.watch(diveFilterProvider).hasActiveFilters;
```

---

### filteredDivesProvider

Dives with filter applied.

```dart
final filteredDivesProvider = Provider<AsyncValue<List<Dive>>>((ref) {
  final divesAsync = ref.watch(diveListNotifierProvider);
  final filter = ref.watch(diveFilterProvider);
  return divesAsync.whenData((dives) => filter.apply(dives));
});
```

---

### diveStatisticsProvider

Aggregate statistics for current diver.

```dart
final diveStatisticsProvider = FutureProvider<DiveStatistics>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getStatistics(diverId: currentDiverId);
});
```

**DiveStatistics Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `totalDives` | int | Total dive count |
| `totalBottomTime` | Duration | Total bottom time |
| `maxDepth` | double? | Maximum depth |
| `avgDepth` | double? | Average depth |
| `avgDuration` | Duration? | Average duration |

---

### diveRecordsProvider

Personal records (superlatives).

```dart
final diveRecordsProvider = FutureProvider<DiveRecords>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getRecords(diverId: currentDiverId);
});
```

---

### surfaceIntervalProvider

Surface interval to previous dive.

```dart
final surfaceIntervalProvider = FutureProvider.family<Duration?, String>((ref, diveId) async {
  final repository = ref.watch(diveRepositoryProvider);
  return repository.getSurfaceInterval(diveId);
});
```

---

## Diver Providers

**Location:** `lib/features/divers/presentation/providers/diver_providers.dart`

### currentDiverIdProvider

Currently selected diver ID.

```dart
final currentDiverIdProvider = StateNotifierProvider<CurrentDiverIdNotifier, String?>(...);
```

---

### validatedCurrentDiverIdProvider

Validated diver ID (ensures diver exists).

```dart
final validatedCurrentDiverIdProvider = FutureProvider<String?>((ref) async {
  final currentId = ref.watch(currentDiverIdProvider);
  if (currentId == null) return null;
  final diver = await ref.watch(diverProvider(currentId).future);
  return diver != null ? currentId : null;
});
```

---

### diverProvider

Single diver by ID.

```dart
final diverProvider = FutureProvider.family<Diver?, String>((ref, id) async {
  return ref.watch(diverRepositoryProvider).getDiverById(id);
});
```

---

## Site Providers

**Location:** `lib/features/dive_sites/presentation/providers/site_providers.dart`

### siteRepositoryProvider

```dart
final siteRepositoryProvider = Provider<SiteRepository>((ref) {
  return SiteRepository();
});
```

### sitesProvider

All dive sites.

```dart
final sitesProvider = FutureProvider<List<DiveSite>>((ref) async {
  return ref.watch(siteRepositoryProvider).getAllSites();
});
```

### siteProvider

Single site by ID.

```dart
final siteProvider = FutureProvider.family<DiveSite?, String>((ref, id) async {
  return ref.watch(siteRepositoryProvider).getSiteById(id);
});
```

### siteDiveCountProvider

Number of dives at a site.

```dart
final siteDiveCountProvider = FutureProvider.family<int, String>((ref, siteId) async {
  return ref.watch(siteRepositoryProvider).getDiveCount(siteId);
});
```

---

## Equipment Providers

**Location:** `lib/features/equipment/presentation/providers/equipment_providers.dart`

### equipmentRepositoryProvider

```dart
final equipmentRepositoryProvider = Provider<EquipmentRepository>((ref) {
  return EquipmentRepository();
});
```

### equipmentProvider

All equipment items.

```dart
final equipmentProvider = FutureProvider<List<EquipmentItem>>((ref) async {
  return ref.watch(equipmentRepositoryProvider).getAllEquipment();
});
```

### equipmentItemProvider

Single equipment item by ID.

```dart
final equipmentItemProvider = FutureProvider.family<EquipmentItem?, String>((ref, id) async {
  return ref.watch(equipmentRepositoryProvider).getEquipmentById(id);
});
```

---

## Trip Providers

**Location:** `lib/features/trips/presentation/providers/trip_providers.dart`

### tripRepositoryProvider

```dart
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository();
});
```

### tripsProvider

All trips.

```dart
final tripsProvider = FutureProvider<List<Trip>>((ref) async {
  return ref.watch(tripRepositoryProvider).getAllTrips();
});
```

### tripWithStatsProvider

Trip with dive statistics.

```dart
final tripWithStatsProvider = FutureProvider.family<TripWithStats, String>((ref, tripId) async {
  return ref.watch(tripRepositoryProvider).getTripWithStats(tripId);
});
```

---

## Settings Providers

**Location:** `lib/features/settings/presentation/providers/settings_providers.dart`

### settingsProvider

Application settings.

```dart
final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>((ref) {
  return SettingsNotifier(ref.watch(sharedPreferencesProvider));
});
```

**Settings Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `depthUnit` | DepthUnit | Meters/Feet |
| `temperatureUnit` | TemperatureUnit | Celsius/Fahrenheit |
| `pressureUnit` | PressureUnit | Bar/PSI |
| `themeMode` | ThemeMode | Light/Dark/System |
| `gradientFactorLow` | int | GF Low (default: 30) |
| `gradientFactorHigh` | int | GF High (default: 70) |

---

## Convenience Selectors

Use `select` to watch specific state:

```dart
// Only rebuild when depth unit changes
final depthUnit = ref.watch(
  settingsProvider.select((s) => s.depthUnit),
);
```

---

## Provider Invalidation

Force providers to reload:

```dart
// Invalidate single provider
ref.invalidate(divesProvider);

// Invalidate family provider
ref.invalidate(diveProvider(diveId));

// Refresh and get new value
final dives = await ref.refresh(divesProvider.future);
```

---

## Common Patterns

### Reading vs Watching

```dart
// Watch: Rebuilds widget on change
final dives = ref.watch(divesProvider);

// Read: One-time access (use in callbacks)
final repository = ref.read(diveRepositoryProvider);
```

### Async Operations

```dart
// In widget
onPressed: () async {
  await ref.read(diveListNotifierProvider.notifier).addDive(dive);
  if (mounted) {
    context.go('/dives');
  }
}
```

### Provider Dependencies

```dart
// Provider that depends on another
final filteredDivesProvider = Provider<AsyncValue<List<Dive>>>((ref) {
  final divesAsync = ref.watch(diveListNotifierProvider);
  final filter = ref.watch(diveFilterProvider);
  return divesAsync.whenData((dives) => filter.apply(dives));
});
```

### Testing with Overrides

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

