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

```
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

### All Tests

```bash
flutter test
```

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
```

### With Coverage

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Performance Tests

```bash
# Performance tests have extended timeouts
flutter test test/performance/ --reporter expanded
```

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
```

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
      child: const MaterialApp(home: StatisticsPage()),
    ),
  );

  await tester.pumpAndSettle();

  expect(find.text('100'), findsOneWidget);
  expect(find.text('75h'), findsOneWidget);
  expect(find.text('40.0m'), findsOneWidget);
});
```

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
```

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
```

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
```

### Mock Repository

```dart
class MockDiveRepository extends Mock implements DiveRepository {
  @override
  Future<List<Dive>> getAllDives({String? diverId}) async {
    return [testDive1, testDive2];
  }
}
```

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

