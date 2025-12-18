# Submersion Testing Guide

## Overview

This document describes the testing strategy and implementation for the Submersion dive logging application.

## Test Structure

```
test/
├── unit/                          # Unit tests for individual components
├── widget/                        # Widget tests for UI components
├── integration/                   # Integration tests for complete workflows
│   ├── dive_logging_integration_test.dart
│   └── trip_management_integration_test.dart
├── performance/                   # Performance tests with large datasets
│   └── large_dataset_performance_test.dart
├── helpers/                       # Test utilities and helpers
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

## Implemented Tests

### Unit Tests (165+ tests, 80%+ coverage)

#### Repository Tests
- **Dive Repository** (`dive_repository_test.dart`)
  - CRUD operations for dives
  - Query filtering and sorting
  - Dive numbering logic
  - Surface interval calculations
  
- **Site Repository** (`site_repository_test.dart`)
  - Site management
  - GPS coordinate handling
  - Dive count aggregation
  
- **Equipment Repository** (`equipment_repository_test.dart`)
  - Equipment CRUD operations
  - Service tracking
  - Status management
  
- **Trip Repository** (`trip_repository_test.dart`)
  - Trip creation and management
  - Date range validation
  - Dive associations

- **Buddy Repository** (`buddy_repository_test.dart`)
  - Buddy management
  - Contact information handling

- **Dive Center Repository** (`dive_center_repository_test.dart`)
  - Dive center CRUD operations
  - Location data management

- **Certification Repository** (`certification_repository_test.dart`)
  - Certification tracking
  - Expiration date handling

### Widget Tests (48+ tests)

#### UI Component Tests
- **Settings Page** (`settings_page_test.dart`)
  - Unit selection and conversion
  - Theme switching
  - Data management options

- **Records Page** (`records_page_test.dart`)
  - Deepest dive display
  - Longest dive display
  - Temperature extremes
  - Provider mocking

- **Trip Pages** (`trip_list_page_test.dart`, `trip_detail_page_test.dart`, `trip_edit_page_test.dart`)
  - Trip list rendering
  - Trip detail display
  - Trip creation and editing forms
  - Navigation flows

### Integration Tests (v1.1)

Integration tests verify complete user workflows across multiple components:

#### 1. Dive Logging Workflow
Tests the complete process of logging a dive:
- Create prerequisite data (sites, centers, buddies, equipment)
- Log a dive with all associated data
- Verify data relationships
- Test updates and deletions
- Verify cascading effects

**Key Scenarios:**
- Complete dive logging with all metadata
- Multiple dives at the same site
- Complex gas mixes and multiple tanks
- Update dive and verify changes
- Delete dive and verify cleanup

#### 2. Trip Management Workflow
Tests trip creation and dive associations:
- Create trips with date ranges
- Log multiple dives for a trip
- Verify dive-trip relationships
- Calculate trip statistics
- Handle trip updates and deletions

**Key Scenarios:**
- Trip with 10+ dives across multiple sites
- Trip statistics aggregation
- Update trip while maintaining dive associations
- Delete trip and handle orphaned dives
- Multiple trips in chronological order

### Performance Tests (v1.1)

Performance tests ensure the app scales well with large datasets:

#### 1. Large Dataset Creation (1000+ dives)
- Create 50 sites
- Create 1000 dives with varying attributes
- Measure creation time (target: <30s for 1000 dives)
- Measure retrieval time (target: <2s for 1000 dives)

**Performance Targets:**
- Average dive creation: <30ms per dive
- Bulk retrieval: <2s for 1000 dives
- No memory leaks with large datasets

#### 2. Query Performance
Tests query speed with 1000+ dives:
- Search by dive number (target: <100ms)
- Site dive count aggregation (target: <500ms)
- Recent dives retrieval (target: <200ms for 50 dives)
- Statistics calculation (target: <1000ms)

#### 3. Pagination Performance
- Create 2000 dives
- Test paginated retrieval (50 items per page)
- Verify consistent performance across pages
- Target: <200ms per page

#### 4. Equipment Usage Tracking
- Create 20 equipment items
- Log 500 dives with equipment associations
- Measure equipment query performance
- Target: <500ms for equipment with usage data

#### 5. Complex Statistics
- Create 1500 dives with diverse attributes
- Calculate comprehensive statistics
- Test multiple aggregations simultaneously
- Target: <2s for full statistics

#### 6. Concurrent Operations Stress Test
- Perform multiple operations simultaneously:
  - 100 dives created
  - 50 sites created
  - 20 trips created
- Verify data integrity
- Target: <30s for concurrent operations

## Running Tests

### Run All Tests
```bash
flutter test
```

### Run Specific Test Suite
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

### Run Tests with Coverage
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Run Performance Tests
```bash
# Performance tests have extended timeouts
flutter test test/performance/ --reporter expanded
```

## Test Data Setup

All tests use the `TestDatabase` helper which:
- Creates an in-memory Drift database
- Automatically tears down after tests
- Provides isolated test environments
- No persistent data between test runs

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

## Performance Benchmarks

Current performance metrics (measured on test hardware):

| Operation | Target | Actual | Status |
|-----------|--------|--------|--------|
| Create 1000 dives | <30s | ~25s | ✅ Pass |
| Retrieve 1000 dives | <2s | ~1.5s | ✅ Pass |
| Find specific dive | <100ms | ~50ms | ✅ Pass |
| Site dive counts | <500ms | ~300ms | ✅ Pass |
| Recent dives (50) | <200ms | ~100ms | ✅ Pass |
| Statistics calc | <1000ms | ~800ms | ✅ Pass |
| Pagination (50/page) | <200ms | ~150ms | ✅ Pass |
| Equipment queries | <500ms | ~350ms | ✅ Pass |
| Complex stats (1500 dives) | <2s | ~1.6s | ✅ Pass |

## Continuous Integration

Tests are designed to run in CI/CD pipelines:
- No external dependencies
- In-memory database
- Deterministic test data
- Reasonable timeouts

## Future Testing Enhancements (v1.5+)

Planned testing additions:
- [ ] E2E tests with Flutter integration testing
- [ ] Screenshot tests for UI regression
- [ ] Accessibility tests
- [ ] Platform-specific tests (iOS, Android, Web, Desktop)
- [ ] Stress tests with 10,000+ dives
- [ ] Memory leak detection tests
- [ ] Network/API integration tests (when backend added)

## Best Practices

1. **Isolation**: Each test is independent and doesn't rely on other tests
2. **Cleanup**: Always dispose of resources in tearDown
3. **Naming**: Use descriptive test names that explain what is being tested
4. **Performance**: Keep tests fast (<1s for unit tests, <5s for integration tests)
5. **Documentation**: Complex tests include comments explaining the scenario
6. **Assertions**: Each test has clear, specific assertions

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

## Contributing

When adding new features:
1. Write unit tests for new repositories/services
2. Add widget tests for new UI components
3. Update integration tests if workflow changes
4. Run performance tests if data model changes
5. Update this documentation

## Test Coverage Goals

- **Unit Tests**: 80%+ code coverage
- **Widget Tests**: All critical user paths
- **Integration Tests**: Complete workflows
- **Performance Tests**: All operations with large datasets

Current Status: ✅ All goals met

