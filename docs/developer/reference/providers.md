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
```text
**Usage:**

```dart
final repository = ref.read(diveRepositoryProvider);
```diff
---

### divesProvider

All dives for current diver.

```dart
final divesProvider = FutureProvider<List<Dive>>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getAllDives(diverId: currentDiverId);
});
```text
**Usage:**

```dart
final divesAsync = ref.watch(divesProvider);
divesAsync.when(
  data: (dives) => DiveList(dives: dives),
  loading: () => LoadingIndicator(),
  error: (e, st) => ErrorDisplay(error: e),
);
```diff
---

### diveProvider

Single dive by ID.

```dart
final diveProvider = FutureProvider.family<Dive?, String>((ref, id) async {
  final repository = ref.watch(diveRepositoryProvider);
  return repository.getDiveById(id);
});
```text
**Usage:**

```dart
final diveAsync = ref.watch(diveProvider(diveId));
```diff
---

### diveListNotifierProvider

Mutable dive list with CRUD operations.

```dart
final diveListNotifierProvider =
    StateNotifierProvider<DiveListNotifier, AsyncValue<List<Dive>>>((ref) {
  final repository = ref.watch(diveRepositoryProvider);
  return DiveListNotifier(repository, ref);
});
```text
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
```diff
---

### diveFilterProvider

Filter state for dive list.

```dart
final diveFilterProvider = StateProvider<DiveFilterState>((ref) {
  return const DiveFilterState();
});
```typescript
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
```diff
---

### filteredDivesProvider

Dives with filter applied.

```dart
final filteredDivesProvider = Provider<AsyncValue<List<Dive>>>((ref) {
  final divesAsync = ref.watch(diveListNotifierProvider);
  final filter = ref.watch(diveFilterProvider);
  return divesAsync.whenData((dives) => filter.apply(dives));
});
```diff
---

### diveStatisticsProvider

Aggregate statistics for current diver.

```dart
final diveStatisticsProvider = FutureProvider<DiveStatistics>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getStatistics(diverId: currentDiverId);
});
```text
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
```diff
---

### surfaceIntervalProvider

Surface interval to previous dive.

```dart
final surfaceIntervalProvider = FutureProvider.family<Duration?, String>((ref, diveId) async {
  final repository = ref.watch(diveRepositoryProvider);
  return repository.getSurfaceInterval(diveId);
});
```dart
---

## Diver Providers

**Location:** `lib/features/divers/presentation/providers/diver_providers.dart`

### currentDiverIdProvider

Currently selected diver ID.

```dart
final currentDiverIdProvider = StateNotifierProvider<CurrentDiverIdNotifier, String?>(...);
```diff
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
```diff
---

### diverProvider

Single diver by ID.

```dart
final diverProvider = FutureProvider.family<Diver?, String>((ref, id) async {
  return ref.watch(diverRepositoryProvider).getDiverById(id);
});
```dart
---

## Site Providers

**Location:** `lib/features/dive_sites/presentation/providers/site_providers.dart`

### siteRepositoryProvider

```dart
final siteRepositoryProvider = Provider<SiteRepository>((ref) {
  return SiteRepository();
});
```text
### sitesProvider

All dive sites.

```dart
final sitesProvider = FutureProvider<List<DiveSite>>((ref) async {
  return ref.watch(siteRepositoryProvider).getAllSites();
});
```text
### siteProvider

Single site by ID.

```dart
final siteProvider = FutureProvider.family<DiveSite?, String>((ref, id) async {
  return ref.watch(siteRepositoryProvider).getSiteById(id);
});
```text
### siteDiveCountProvider

Number of dives at a site.

```dart
final siteDiveCountProvider = FutureProvider.family<int, String>((ref, siteId) async {
  return ref.watch(siteRepositoryProvider).getDiveCount(siteId);
});
```dart
---

## Equipment Providers

**Location:** `lib/features/equipment/presentation/providers/equipment_providers.dart`

### equipmentRepositoryProvider

```dart
final equipmentRepositoryProvider = Provider<EquipmentRepository>((ref) {
  return EquipmentRepository();
});
```text
### equipmentProvider

All equipment items.

```dart
final equipmentProvider = FutureProvider<List<EquipmentItem>>((ref) async {
  return ref.watch(equipmentRepositoryProvider).getAllEquipment();
});
```text
### equipmentItemProvider

Single equipment item by ID.

```dart
final equipmentItemProvider = FutureProvider.family<EquipmentItem?, String>((ref, id) async {
  return ref.watch(equipmentRepositoryProvider).getEquipmentById(id);
});
```dart
---

## Trip Providers

**Location:** `lib/features/trips/presentation/providers/trip_providers.dart`

### tripRepositoryProvider

```dart
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository();
});
```text
### tripsProvider

All trips.

```dart
final tripsProvider = FutureProvider<List<Trip>>((ref) async {
  return ref.watch(tripRepositoryProvider).getAllTrips();
});
```text
### tripWithStatsProvider

Trip with dive statistics.

```dart
final tripWithStatsProvider = FutureProvider.family<TripWithStats, String>((ref, tripId) async {
  return ref.watch(tripRepositoryProvider).getTripWithStats(tripId);
});
```dart
---

## Settings Providers

**Location:** `lib/features/settings/presentation/providers/settings_providers.dart`

### settingsProvider

Application settings.

```dart
final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>((ref) {
  return SettingsNotifier(ref.watch(sharedPreferencesProvider));
});
```sql
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
```dart
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
```diff
---

## Common Patterns

### Reading vs Watching

```dart
// Watch: Rebuilds widget on change
final dives = ref.watch(divesProvider);

// Read: One-time access (use in callbacks)
final repository = ref.read(diveRepositoryProvider);
```text
### Async Operations

```dart
// In widget
onPressed: () async {
  await ref.read(diveListNotifierProvider.notifier).addDive(dive);
  if (mounted) {
    context.go('/dives');
  }
}
```dart
### Provider Dependencies

```dart
// Provider that depends on another
final filteredDivesProvider = Provider<AsyncValue<List<Dive>>>((ref) {
  final divesAsync = ref.watch(diveListNotifierProvider);
  final filter = ref.watch(diveFilterProvider);
  return divesAsync.whenData((dives) => filter.apply(dives));
});
```text
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

---

## Additional Provider Categories

The following feature areas have their own provider files. Each follows the same Riverpod patterns documented above.

### Course Providers

**Location:** `lib/features/courses/presentation/providers/course_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `courseRepositoryProvider` | Provider | Course repository singleton |
| `coursesProvider` | FutureProvider | All courses for current diver |
| `courseProvider` | FutureProvider.family | Single course by ID |

### Buddy Providers

**Location:** `lib/features/buddies/presentation/providers/buddy_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `buddyRepositoryProvider` | Provider | Buddy repository singleton |
| `buddiesProvider` | FutureProvider | All buddies for current diver |
| `buddyProvider` | FutureProvider.family | Single buddy by ID |

### Certification Providers

**Location:** `lib/features/certifications/presentation/providers/certification_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `certificationRepositoryProvider` | Provider | Certification repository singleton |
| `certificationsProvider` | FutureProvider | All certifications for current diver |

### Dive Center Providers

**Location:** `lib/features/dive_centers/presentation/providers/dive_center_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `diveCenterRepositoryProvider` | Provider | Dive center repository singleton |
| `diveCentersProvider` | FutureProvider | All dive centers |

### Marine Life Providers

**Location:** `lib/features/marine_life/presentation/providers/species_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `speciesRepositoryProvider` | Provider | Species repository singleton |
| `speciesListProvider` | FutureProvider | All species |

### Tag Providers

**Location:** `lib/features/tags/presentation/providers/tag_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `tagRepositoryProvider` | Provider | Tag repository singleton |
| `tagsProvider` | FutureProvider | All tags for current diver |

### Dive Type Providers

**Location:** `lib/features/dive_types/presentation/providers/dive_type_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `diveTypeRepositoryProvider` | Provider | Dive type repository singleton |
| `diveTypesProvider` | FutureProvider | All dive types |

### Tank Preset Providers

**Location:** `lib/features/tank_presets/presentation/providers/tank_preset_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `tankPresetRepositoryProvider` | Provider | Tank preset repository singleton |
| `tankPresetsProvider` | FutureProvider | All tank presets for current diver |

### Media Providers

**Location:** `lib/features/media/presentation/providers/media_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `mediaRepositoryProvider` | Provider | Media repository singleton |
| `diveMediaProvider` | FutureProvider.family | Media for a specific dive |

### Dive Computer Providers

**Location:** `lib/features/dive_log/presentation/providers/dive_computer_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `diveComputerRepositoryProvider` | Provider | Dive computer repository singleton |
| `diveComputersProvider` | FutureProvider | All dive computers |

### Dive Import Providers

**Location:** `lib/features/dive_import/presentation/providers/dive_import_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `fitImportProvider` | StateNotifierProvider | FIT file import state |

### Universal Import Providers

**Location:** `lib/features/universal_import/presentation/providers/universal_import_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `universalImportProvider` | StateNotifierProvider | Universal import wizard state |

### Tide Providers

**Location:** `lib/features/tides/presentation/providers/tide_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `tideRepositoryProvider` | Provider | Tide repository singleton |
| `diveTideProvider` | FutureProvider.family | Tide record for a dive |

### Offline Maps Providers

**Location:** `lib/features/maps/presentation/providers/offline_map_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `offlineMapRepositoryProvider` | Provider | Offline map repository singleton |
| `cachedRegionsProvider` | FutureProvider | All cached map regions |

### Sync Providers

**Location:** `lib/features/settings/presentation/providers/sync_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `syncServiceProvider` | Provider | Sync service singleton |
| `syncStatusProvider` | FutureProvider | Current sync status |

### Notification Providers

**Location:** `lib/features/notifications/presentation/providers/notification_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `notificationServiceProvider` | Provider | Notification service singleton |

### Dashboard Providers

**Location:** `lib/features/dashboard/presentation/providers/dashboard_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `dashboardDataProvider` | FutureProvider | Aggregated dashboard data |

### Dive Planner Providers

**Location:** `lib/features/dive_planner/presentation/providers/dive_planner_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `divePlannerProvider` | StateNotifierProvider | Dive planner state |

### Backup Providers

**Location:** `lib/features/backup/presentation/providers/backup_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `backupServiceProvider` | Provider | Backup service singleton |

### Signature Providers

**Location:** `lib/features/signatures/presentation/providers/signature_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `signatureProvider` | FutureProvider.family | Signatures for a dive |

### Liveaboard Providers

**Location:** `lib/features/trips/presentation/providers/liveaboard_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `liveaboardDetailsProvider` | FutureProvider.family | Liveaboard details for a trip |

### Gas Calculator Providers

**Location:** `lib/features/gas_calculators/presentation/providers/gas_calculators_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `gasCalculatorsProvider` | StateNotifierProvider | Gas calculator state |

### Deco Calculator Providers

**Location:** `lib/features/deco_calculator/presentation/providers/deco_calculator_providers.dart`

| Provider | Type | Description |
|----------|------|-------------|
| `decoCalculatorProvider` | StateNotifierProvider | Deco calculator state |
