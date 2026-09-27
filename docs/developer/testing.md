# Testing Guide

Submersion has comprehensive test coverage including unit, widget, integration, and performance tests.

## Overview

| Test Type | Count | Coverage |
|-----------|-------|----------|
| **Unit Tests** | 165+ | 80%+ |
| **Widget Tests** | 48+ | Critical paths |
| **Integration Tests** | 2+ | Full workflows |
| **Performance Tests** | 6+ | Large datasets |

## Test Structure

```dart
test/
├── unit/                          # Unit tests
├── widget/                        # Widget tests
├── integration/                   # Integration tests
│   ├── dive_logging_integration_test.dart
│   └── trip_management_integration_test.dart
├── performance/                   # Performance tests
│   └── large_dataset_performance_test.dart
├── helpers/                       # Test utilities
│   └── test_database.dart
└── features/                      # Feature-specific tests
    ├── dive_log/
    ├── dive_sites/
    ├── equipment/
    ├── trips/
    ├── buddies/
    ├── certifications/
    └── settings/
```

## Running Tests

Local runs are limited by disk throughput rather than CPU. See
[Local Test Performance](local-test-performance.md) for the machine setup that
speeds them up by 1.3x to 2x, with the larger gains when several worktrees run
tests at once.

### All Tests

```bash
flutter test
```text
### Specific Test Suite

```bash
# Unit tests only
flutter test test/features/

# Widget tests only
flutter test test/widget/

# Integration tests
flutter test test/integration/

# Performance tests
flutter test test/performance/
```text
### With Coverage

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```text
### Performance Tests

```bash
# Performance tests have extended timeouts
flutter test test/performance/ --reporter expanded
```text
## Unit Tests

### Repository Tests

Each repository has comprehensive tests:

**Dive Repository** (`dive_repository_test.dart`)

- CRUD operations for dives
- Query filtering and sorting
- Dive numbering logic
- Surface interval calculations

**Site Repository** (`site_repository_test.dart`)

- Site management
- GPS coordinate handling
- Dive count aggregation

**Equipment Repository** (`equipment_repository_test.dart`)

- Equipment CRUD operations
- Service tracking
- Status management

**Trip Repository** (`trip_repository_test.dart`)

- Trip creation and management
- Date range validation
- Dive associations

**Buddy Repository** (`buddy_repository_test.dart`)

- Buddy management
- Contact information handling

**Dive Center Repository** (`dive_center_repository_test.dart`)

- Dive center CRUD operations
- Location data management

**Certification Repository** (`certification_repository_test.dart`)

- Certification tracking
- Expiration date handling

### Example Unit Test

```dart
group('DiveRepository', () {
  late TestDatabase testDb;
  late DiveRepository diveRepo;

  setUp(() async {
    testDb = await TestDatabase.create();
    diveRepo = DiveRepository();
  });

  tearDown(() async {
    await testDb.dispose();
  });

  test('creates dive with correct number', () async {
    final dive = Dive(
      id: 'test-dive',
      dateTime: DateTime.now(),
      maxDepth: 18.5,
      duration: 45,
    );

    final created = await diveRepo.createDive(dive);

    expect(created.diveNumber, 1);
  });

  test('retrieves dives sorted by date', () async {
    await diveRepo.createDive(dive1);
    await diveRepo.createDive(dive2);

    final dives = await diveRepo.getAllDives();

    expect(dives.first.dateTime.isAfter(dives.last.dateTime), true);
  });
});
```dart
## Widget Tests

### UI Component Tests

**Settings Page** (`settings_page_test.dart`)

- Unit selection and conversion
- Theme switching
- Data management options

**Records Page** (`records_page_test.dart`)

- Deepest dive display
- Longest dive display
- Temperature extremes
- Provider mocking

**Trip Pages** (`trip_list_page_test.dart`, etc.)

- Trip list rendering
- Trip detail display
- Trip creation and editing forms
- Navigation flows

### Example Widget Test

```dart
testWidgets('displays dive statistics', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        diveStatisticsProvider.overrideWith(
          (ref) async => DiveStatistics(
            totalDives: 100,
            totalTime: Duration(hours: 75),
            maxDepth: 40.0,
          ),
        ),
      ],
      child: const MaterialApp(home: InsightsPage()),
    ),
  );

  await tester.pumpAndSettle();

  expect(find.text('100'), findsOneWidget);
  expect(find.text('75h'), findsOneWidget);
  expect(find.text('40.0m'), findsOneWidget);
});
```text
## Integration Tests

Integration tests verify complete user workflows:

### Dive Logging Workflow

Tests the complete process of logging a dive:

1. Create prerequisite data (sites, centers, buddies, equipment)
2. Log a dive with all associated data
3. Verify data relationships
4. Test updates and deletions
5. Verify cascading effects

**Key Scenarios:**

- Complete dive logging with all metadata
- Multiple dives at the same site
- Complex gas mixes and multiple tanks
- Update dive and verify changes
- Delete dive and verify cleanup

### Trip Management Workflow

Tests trip creation and dive associations:

1. Create trips with date ranges
2. Log multiple dives for a trip
3. Verify dive-trip relationships
4. Calculate trip statistics
5. Handle trip updates and deletions

**Key Scenarios:**

- Trip with 10+ dives across multiple sites
- Trip statistics aggregation
- Update trip while maintaining dive associations
- Delete trip and handle orphaned dives
- Multiple trips in chronological order

## Performance Tests

Performance tests ensure the app scales with large datasets.

### Performance Targets

| Operation | Target |
|-----------|--------|
| Create 1000 dives | <30s |
| Retrieve 1000 dives | <2s |
| Find specific dive | <100ms |
| Site dive counts | <500ms |
| Recent dives (50) | <200ms |
| Statistics calc | <1000ms |
| Pagination (50/page) | <200ms |
| Equipment queries | <500ms |
| Complex stats (1500 dives) | <2s |

### Test Scenarios

**1. Large Dataset Creation**

- Create 50 sites
- Create 1000 dives with varying attributes
- Measure creation time
- Measure retrieval time

**2. Query Performance**

- Search by dive number
- Site dive count aggregation
- Recent dives retrieval
- Statistics calculation

**3. Pagination Performance**

- Create 2000 dives
- Test paginated retrieval (50 items per page)
- Verify consistent performance across pages

**4. Equipment Usage Tracking**

- Create 20 equipment items
- Log 500 dives with equipment associations
- Measure equipment query performance

**5. Complex Statistics**

- Create 1500 dives with diverse attributes
- Calculate comprehensive statistics
- Test multiple aggregations simultaneously

**6. Concurrent Operations Stress Test**

- Perform multiple operations simultaneously
- Verify data integrity
- Measure total operation time

### Current Benchmarks

| Operation | Target | Actual | Status |
|-----------|--------|--------|--------|
| Create 1000 dives | <30s | ~25s | Pass |
| Retrieve 1000 dives | <2s | ~1.5s | Pass |
| Find specific dive | <100ms | ~50ms | Pass |
| Site dive counts | <500ms | ~300ms | Pass |
| Recent dives (50) | <200ms | ~100ms | Pass |
| Statistics calc | <1000ms | ~800ms | Pass |
| Pagination (50/page) | <200ms | ~150ms | Pass |
| Equipment queries | <500ms | ~350ms | Pass |
| Complex stats (1500 dives) | <2s | ~1.6s | Pass |

## Test Database Helper

All tests use the `TestDatabase` helper:

```dart
class TestDatabase {
  late AppDatabase database;

  static Future<TestDatabase> create() async {
    final db = TestDatabase();
    db.database = AppDatabase(NativeDatabase.memory());
    return db;
  }

  Future<void> dispose() async {
    await database.close();
  }
}
```text
### Usage

```dart
late TestDatabase testDb;
late DiveRepository diveRepo;

setUp(() async {
  testDb = await TestDatabase.create();
  diveRepo = DiveRepository();
});

tearDown(() async {
  await testDb.dispose();
});
```dart
Features:

- Creates an in-memory Drift database
- Automatically tears down after tests
- Provides isolated test environments
- No persistent data between test runs

## Mocking Providers

### Override Providers

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
```text
### Mock Repository

```dart
class MockDiveRepository extends Mock implements DiveRepository {
  @override
  Future<List<Dive>> getAllDives({String? diverId}) async {
    return [testDive1, testDive2];
  }
}
```

## Shared Isolates in CI

`flutter test` compiles and loads every test file as its own entrypoint. In CI
that made the cost of a run follow the number of test files, so the test job
runs bundles instead: generated entrypoints that import many test files and
call each one's `main()` inside a group named after the file
(`scripts/bundle_tests.py`, issue #2500). Local runs and the pre-push hook still
run test files one by one. At local concurrency a bundle is no faster, because
it runs its files one after another in a single isolate.

### The rule: put back what you replace

The files in a bundle share process-wide state. A test that replaces a global
restores it, so the next file starts from the same place.

| You change | Put it back with |
|---|---|
| The path provider | `useFakePathProvider(fake)` from `test/helpers/fake_path_provider.dart`, in `setUp` or the test. It restores the previous provider when the test ends |
| Any other `*Platform.instance`, or `HttpOverrides.global` | Read the previous value into a variable, and assign that variable back in `tearDown` or `addTearDown` |
| `debugPrint`, `FlutterError.onError` or `debugDefaultTargetPlatformOverride` | Put the saved value (or `null` for the platform override) back before the test ends. flutter_test requires this in the body of a `testWidgets` |
| `QualityScanScheduler.enabled`, `SensorSummaryScheduler.enabled` or `debugCanShareFiles` | `applyGlobalTestDefaults()` from `test/helpers/global_test_defaults.dart`, in `tearDown` |
| A mock handler on the path provider or share channel | `clearPathAndShareChannelMocks()` from `test/helpers/mock_channels.dart`, or `setMockMethodCallHandler(channel, null)`, in a `tearDown` or `tearDownAll` |
| The share sheet | Assign your fake to `SharePlatform.instance` and restore it. The harness pins a forwarder, so the fake is looked up on every share |
| PDF fonts | `loadPdfRoboto()` in `setUpAll` and `unloadPdfRoboto()` in `tearDownAll`, from `test/helpers/pdf_roboto.dart` |

A restore belongs in a teardown, so that it runs when a test fails too. A
`tearDown` answers for the group it is declared in, and an `addTearDown` for the
test that registers it, so restoring in one group does not cover a replacement
in another. The foundation hooks above are the exception.

Two checks enforce the rule:

- `test/architecture/test_global_state_restored_test.dart` reads the source and
  fails on an assignment that nothing in its scope restores. It names the file
  and line, and it runs locally like any other test.
- In CI, each generated bundle records the process-wide state before a file's
  tests (`test/helpers/global_state_snapshot.dart`) and fails that file's group
  if anything is left changed afterwards, whatever shape the code took.

The bundle also checks each file's `main()`, which runs while the bundle is
declared, before any test. Each file is declared from the harness defaults. A
file that throws while declaring fails in a test named `declares its tests`,
and one that leaves a global changed fails in `declares its tests without
changing global state`. The other files in the bundle still run.

A shared isolate exposes two more things:

- Code in the body of `main()` or `group()` runs while the file is declared,
  before any test. By then an earlier file has set up the test binding. Build
  anything that touches the network or a platform channel inside `setUp` or the
  test, or make it `late final`.
- A warm isolate is faster than a cold one. An assertion that two timestamps
  differ needs the difference built in, not left to the clock.

### Reproducing a CI failure locally

```bash
# The bundle that runs a given test file:
flutter test $(python3 scripts/bundle_tests.py --containing test/path/to/my_test.dart)

# A whole CI shard. The shard count is TOTAL_SHARDS in .github/workflows/ci.yaml:
flutter test --exclude-tags performance $(python3 scripts/bundle_tests.py --shard 2 --total-shards 6)

# Exactly these files, in this order, in one isolate:
flutter test $(python3 scripts/bundle_tests.py --files test/a_test.dart test/b_test.dart)
```

A failure names the file it came from: every test in a bundle sits in a group
named after its file's path. To find the earlier file a failing test depends
on, take the files imported before it in the bundle and halve the list with
`--files` until one is left.

### Files that run as their own entrypoint

A file is left out of the bundles when it has a library-level `@Tags`,
`@TestOn`, `@Timeout`, `@Skip`, `@Retry` or `@OnPlatform` annotation (the test
runner reads those from an entrypoint only), calls `matchesGoldenFile`, or has
a `main` that is `async` or takes parameters.

The comment `// test-bundle: run-alone <reason>`, on a line of its own, does the
same for any file. It is there to unblock main while a conflict is fixed, not
to leave one in place.

## Best Practices

1. **Isolation** - Each test is independent and doesn't rely on other tests
2. **Cleanup** - Always dispose of resources in tearDown
3. **Naming** - Use descriptive test names that explain what is being tested
4. **Performance** - Keep tests fast (<1s for unit tests, <5s for integration tests)
5. **Documentation** - Complex tests include comments explaining the scenario
6. **Assertions** - Each test has clear, specific assertions

## Troubleshooting

### Tests Fail Randomly

- Ensure proper async/await usage
- Check for race conditions
- Verify test database cleanup

### Performance Tests Timeout

- Increase timeout in test configuration
- Run on more powerful hardware
- Check for memory leaks

### Import Errors

- Run `flutter pub get`
- Verify all dependencies are installed
- Check pubspec.yaml

## Contributing Tests

When adding new features:

1. Write unit tests for new repositories/services
2. Add widget tests for new UI components
3. Update integration tests if workflow changes
4. Run performance tests if data model changes
5. Update this documentation

## Coverage Goals

| Test Type | Target |
|-----------|--------|
| Unit Tests | 80%+ code coverage |
| Widget Tests | All critical user paths |
| Integration Tests | Complete workflows |
| Performance Tests | All operations with large datasets |

**Current Status:** All goals met
