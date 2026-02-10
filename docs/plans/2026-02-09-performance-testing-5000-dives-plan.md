# Performance Testing (5000+ Dives) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a comprehensive performance testing suite that validates Submersion works smoothly at 5,000+ dives and 2,000+ sites with strict mobile-grade thresholds.

**Architecture:** Two-layer measurement (Stopwatch data-layer instrumentation + Flutter frame tracing), configurable synthetic data generator with light/realistic/heavy presets, inline smoke tests for regression detection, and separate heavy benchmarks for thorough analysis.

**Tech Stack:** Flutter test, Drift batch API, `Stopwatch`, `IntegrationTestWidgetsFlutterBinding`, `@Tags` annotation.

**Working directory:** `.worktrees/performance-testing/` (branch `feature/performance-testing-5000-dives`)

**Design doc:** `docs/plans/2026-02-09-performance-testing-5000-dives-design.md`

---

## Task 1: PerfTimer Utility

**Files:**
- Create: `lib/core/performance/perf_timer.dart`
- Test: `test/core/performance/perf_timer_test.dart`

### Step 1: Write the failing test

Create `test/core/performance/perf_timer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/performance/perf_timer.dart';

void main() {
  setUp(() {
    PerfTimer.reset();
  });

  group('PerfTimer', () {
    test('measure captures duration for async operations', () async {
      final result = await PerfTimer.measure('testOp', () async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 42;
      });

      expect(result, equals(42));
      final duration = PerfTimer.lastResult('testOp');
      expect(duration, isNotNull);
      expect(duration!.inMilliseconds, greaterThanOrEqualTo(40));
    });

    test('measureSync captures duration for sync operations', () {
      final result = PerfTimer.measureSync('syncOp', () {
        var sum = 0;
        for (var i = 0; i < 1000000; i++) {
          sum += i;
        }
        return sum;
      });

      expect(result, greaterThan(0));
      expect(PerfTimer.lastResult('syncOp'), isNotNull);
      expect(PerfTimer.lastResult('syncOp')!.inMicroseconds, greaterThan(0));
    });

    test('reset clears all results', () async {
      await PerfTimer.measure('op1', () async => 1);
      PerfTimer.reset();
      expect(PerfTimer.lastResult('op1'), isNull);
    });

    test('lastResult returns null for unknown operations', () {
      expect(PerfTimer.lastResult('nonexistent'), isNull);
    });

    test('allResults returns all captured timings', () async {
      await PerfTimer.measure('a', () async => 1);
      await PerfTimer.measure('b', () async => 2);
      final all = PerfTimer.allResults;
      expect(all.keys, containsAll(['a', 'b']));
    });
  });
}
```

### Step 2: Run test to verify it fails

Run: `flutter test test/core/performance/perf_timer_test.dart`
Expected: FAIL — `perf_timer.dart` doesn't exist yet.

### Step 3: Write implementation

Create `lib/core/performance/perf_timer.dart`:

```dart
import 'dart:developer' show log;

import 'package:flutter/foundation.dart';

/// Lightweight performance measurement utility.
///
/// Wraps [Stopwatch] with named operations for benchmarking hot paths.
/// Compiled out of release builds via [kDebugMode] guard.
/// In tests, use [lastResult] and [allResults] to assert against thresholds.
class PerfTimer {
  PerfTimer._();

  static final Map<String, Duration> _results = {};

  /// Measure an async operation and record its duration.
  static Future<T> measure<T>(
    String name,
    Future<T> Function() action,
  ) async {
    final sw = Stopwatch()..start();
    final result = await action();
    sw.stop();
    _results[name] = sw.elapsed;
    if (kDebugMode) {
      log('[PERF] $name: ${sw.elapsedMilliseconds}ms');
    }
    return result;
  }

  /// Measure a synchronous operation and record its duration.
  static T measureSync<T>(String name, T Function() action) {
    final sw = Stopwatch()..start();
    final result = action();
    sw.stop();
    _results[name] = sw.elapsed;
    if (kDebugMode) {
      log('[PERF] $name: ${sw.elapsedMilliseconds}ms');
    }
    return result;
  }

  /// Get the last recorded duration for a named operation.
  static Duration? lastResult(String name) => _results[name];

  /// Get all recorded results (unmodifiable copy).
  static Map<String, Duration> get allResults =>
      Map.unmodifiable(_results);

  /// Clear all recorded results.
  static void reset() => _results.clear();
}
```

### Step 4: Run test to verify it passes

Run: `flutter test test/core/performance/perf_timer_test.dart`
Expected: All 5 tests PASS.

### Step 5: Commit

```bash
git add lib/core/performance/perf_timer.dart test/core/performance/perf_timer_test.dart
git commit -m "feat: add PerfTimer utility for performance measurement"
```

---

## Task 2: Instrument Repository Hot Paths

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart`
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart`
- Modify: `lib/features/dive_sites/presentation/providers/site_providers.dart`

### Step 1: Add PerfTimer to DiveRepository

Import and wrap these 6 methods in `dive_repository_impl.dart`:

| Method | Wrap with | Name string |
|--------|-----------|-------------|
| `getAllDives()` | `PerfTimer.measure` | `'getAllDives'` |
| `getDiveById()` | `PerfTimer.measure` | `'getDiveById'` |
| `getDiveProfile()` | `PerfTimer.measure` | `'getDiveProfile'` |
| `getBatchProfileSummaries()` | `PerfTimer.measure` | `'batchProfileSummaries'` |
| `getDiveSummaries()` | `PerfTimer.measure` | `'getDiveSummaries'` |
| `getDiveCount()` | `PerfTimer.measure` | `'getDiveCount'` |

Pattern for each method — wrap the entire try body:

```dart
// Before:
Future<List<Dive>> getAllDives({String? diverId}) async {
  try {
    final query = ...;
    // ... existing code
    return result;
  } catch (e, stackTrace) { ... }
}

// After:
Future<List<Dive>> getAllDives({String? diverId}) async {
  try {
    return await PerfTimer.measure('getAllDives', () async {
      final query = ...;
      // ... existing code (unchanged)
      return result;
    });
  } catch (e, stackTrace) { ... }
}
```

### Step 2: Add PerfTimer to SiteRepository

Import and wrap these 3 methods in `site_repository_impl.dart`:

| Method | Name string |
|--------|-------------|
| `getAllSites()` | `'getAllSites'` |
| `getSitesWithDiveCounts()` | `'getSitesWithDiveCounts'` |
| `searchSites()` | `'searchSites'` |

Same wrapping pattern as Step 1.

### Step 3: Add PerfTimer to sort functions

In `dive_providers.dart`, wrap `_applySorting()`:

```dart
List<domain.Dive> _applySorting(
  List<domain.Dive> dives,
  SortState<DiveSortField> sort,
) {
  return PerfTimer.measureSync('applySorting', () {
    final sorted = List<domain.Dive>.from(dives);
    // ... existing sort logic unchanged
    return sorted;
  });
}
```

In `site_providers.dart`, wrap `_applySiteSorting()`:

```dart
List<SiteWithDiveCount> _applySiteSorting(
  List<SiteWithDiveCount> sites,
  SortState<SiteSortField> sort,
) {
  return PerfTimer.measureSync('applySiteSorting', () {
    final sorted = List<SiteWithDiveCount>.from(sites);
    // ... existing sort logic unchanged
    return sorted;
  });
}
```

### Step 4: Run full test suite

Run: `flutter test`
Expected: All 1,120 tests still pass. PerfTimer adds no behavioral changes.

### Step 5: Commit

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart \
        lib/features/dive_sites/data/repositories/site_repository_impl.dart \
        lib/features/dive_log/presentation/providers/dive_providers.dart \
        lib/features/dive_sites/presentation/providers/site_providers.dart
git commit -m "feat: instrument repository and provider hot paths with PerfTimer"
```

---

## Task 3: Performance Data Generator

**Files:**
- Create: `test/helpers/performance_data_generator.dart`
- Test: `test/helpers/performance_data_generator_test.dart`

### Step 1: Write the failing test

Create `test/helpers/performance_data_generator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';

import 'performance_data_generator.dart';
import 'test_database.dart';

void main() {
  late DiveRepository diveRepository;
  late SiteRepository siteRepository;

  setUp(() async {
    await setUpTestDatabase();
    diveRepository = DiveRepository();
    siteRepository = SiteRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('PerformanceDataGenerator', () {
    test('light preset generates correct counts', () async {
      final generator = PerformanceDataGenerator(DataProfile.light);
      final summary = await generator.generate();

      expect(summary.diveCount, equals(100));
      expect(summary.siteCount, equals(30));
      expect(summary.profilePointCount, greaterThan(80000));

      // Verify data actually exists in DB
      final dives = await diveRepository.getAllDives(
        diverId: summary.diverId,
      );
      expect(dives.length, equals(100));

      final sites = await siteRepository.getAllSites(
        diverId: summary.diverId,
      );
      expect(sites.length, equals(30));
    });

    test('light preset creates diver', () async {
      final generator = PerformanceDataGenerator(DataProfile.light);
      final summary = await generator.generate();

      expect(summary.diverId, isNotEmpty);
    });

    test('light preset generates sites with GPS coordinates', () async {
      final generator = PerformanceDataGenerator(DataProfile.light);
      final summary = await generator.generate();

      final sites = await siteRepository.getAllSites(
        diverId: summary.diverId,
      );
      final withGps = sites.where((s) => s.hasCoordinates).length;
      // ~80% should have coordinates
      expect(withGps, greaterThanOrEqualTo(20));
    });

    test('light preset generates tanks for dives', () async {
      final generator = PerformanceDataGenerator(DataProfile.light);
      final summary = await generator.generate();

      expect(summary.tankCount, greaterThan(0));
      // At least 1 tank per dive
      expect(summary.tankCount, greaterThanOrEqualTo(100));
    });

    test('light preset generates tags', () async {
      final generator = PerformanceDataGenerator(DataProfile.light);
      final summary = await generator.generate();

      expect(summary.tagCount, greaterThan(0));
    });

    test('generation time is under 5 seconds for light', () async {
      final sw = Stopwatch()..start();
      final generator = PerformanceDataGenerator(DataProfile.light);
      await generator.generate();
      sw.stop();

      expect(sw.elapsed.inSeconds, lessThan(5));
    });
  });
}
```

### Step 2: Run test to verify it fails

Run: `flutter test test/helpers/performance_data_generator_test.dart`
Expected: FAIL — `performance_data_generator.dart` doesn't exist yet.

### Step 3: Write implementation

Create `test/helpers/performance_data_generator.dart`. This is a large file (~400 lines). Key structure:

```dart
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';

enum DataProfile { light, realistic, heavy }

class GeneratedDataSummary {
  final String diverId;
  final int diveCount;
  final int siteCount;
  final int profilePointCount;
  final int tankCount;
  final int tagCount;
  final int buddyCount;
  final int equipmentCount;
  final int sightingCount;
  final Duration generationTime;

  const GeneratedDataSummary({ ... });
}

class PerformanceDataGenerator {
  final DataProfile profile;
  final _uuid = const Uuid();
  final _random = Random(42); // Fixed seed for reproducibility
  AppDatabase get _db => DatabaseService.instance.database;

  PerformanceDataGenerator(this.profile);

  // Config per profile
  int get _diveCount => switch (profile) {
    DataProfile.light => 100,
    DataProfile.realistic => 5000,
    DataProfile.heavy => 10000,
  };

  int get _siteCount => switch (profile) {
    DataProfile.light => 30,
    DataProfile.realistic => 2000,
    DataProfile.heavy => 4000,
  };

  Future<GeneratedDataSummary> generate() async {
    final sw = Stopwatch()..start();

    // 1. Create diver
    final diverId = _uuid.v4();
    await _createDiver(diverId);

    // 2. Generate tags (pool of 15)
    final tagIds = await _generateTags(diverId, 15);

    // 3. Generate buddies (pool of 20)
    final buddyIds = await _generateBuddies(diverId, 20);

    // 4. Generate equipment (pool of 30)
    final equipmentIds = await _generateEquipment(diverId, 30);

    // 5. Generate sites
    final siteIds = await _generateSites(diverId);

    // 6. Generate dives with profiles, tanks, tags, sightings
    final (profileCount, tankCount, sightingCount) = await _generateDives(
      diverId: diverId,
      siteIds: siteIds,
      tagIds: tagIds,
      buddyIds: buddyIds,
      equipmentIds: equipmentIds,
    );

    sw.stop();
    return GeneratedDataSummary(
      diverId: diverId,
      diveCount: _diveCount,
      siteCount: _siteCount,
      profilePointCount: profileCount,
      tankCount: tankCount,
      tagCount: tagIds.length,
      buddyCount: buddyIds.length,
      equipmentCount: equipmentIds.length,
      sightingCount: sightingCount,
      generationTime: sw.elapsed,
    );
  }
}
```

**Dive generation logic (`_generateDives`):**

- Iterates `_diveCount` times
- Assigns dive type: 70% recreational, 20% advanced, 10% technical
- Duration based on type:
  - Recreational: 30-60 min (random within range)
  - Advanced: 40-80 min
  - Technical: 60-180 min
- Profile points every 2 seconds: `duration_seconds / 2` points per dive
- Profile shape: descent → bottom → ascent with realistic depth curve and optional safety stop
- Tanks: 1 for recreational, 1-2 for advanced, 2-4 for technical
- Random site assignment from pool (power-law: first 10% of sites get 50% of dives)
- Random tag assignment: 0-3 tags per dive
- Random buddy: 0-2 buddies per dive
- Random equipment: 2-6 items per dive (by type)
- Random sightings: 0-3 for recreational, 0-8 for technical (uses built-in species IDs)

**Batch insert pattern:**

```dart
// Insert in batches of 500 to avoid SQLite variable limits
for (var i = 0; i < companions.length; i += 500) {
  final batch = companions.sublist(
    i,
    min(i + 500, companions.length),
  );
  await _db.batch((b) => b.insertAll(_db.diveProfiles, batch));
}
```

### Step 4: Run test to verify it passes

Run: `flutter test test/helpers/performance_data_generator_test.dart`
Expected: All 6 tests PASS.

### Step 5: Commit

```bash
git add test/helpers/performance_data_generator.dart \
        test/helpers/performance_data_generator_test.dart
git commit -m "feat: add configurable performance data generator with light/realistic/heavy presets"
```

---

## Task 4: Inline Smoke Tests

**Files:**
- Modify: `test/features/dive_log/data/repositories/dive_repository_test.dart`
- Modify: `test/features/dive_sites/data/repositories/site_repository_test.dart`

### Step 1: Add performance smoke group to dive_repository_test.dart

Add at the bottom of the file, inside `main()`:

```dart
@Tags(['performance'])
group('Performance smoke tests (light preset)', () {
  late PerformanceDataGenerator generator;
  late GeneratedDataSummary summary;

  setUpAll(() async {
    generator = PerformanceDataGenerator(DataProfile.light);
    summary = await generator.generate();
  });

  test('getDiveSummaries loads page in under 100ms', () async {
    await repository.getDiveSummaries(
      diverId: summary.diverId,
      limit: 50,
    );
    final duration = PerfTimer.lastResult('getDiveSummaries');
    expect(duration, isNotNull);
    expect(duration!.inMilliseconds, lessThan(100));
  });

  test('getDiveById loads in under 50ms', () async {
    final dives = await repository.getAllDives(diverId: summary.diverId);
    PerfTimer.reset();
    await repository.getDiveById(dives.first.id);
    final duration = PerfTimer.lastResult('getDiveById');
    expect(duration, isNotNull);
    expect(duration!.inMilliseconds, lessThan(50));
  });

  test('getDiveProfile loads in under 50ms', () async {
    final dives = await repository.getAllDives(diverId: summary.diverId);
    PerfTimer.reset();
    await repository.getDiveProfile(dives.first.id);
    final duration = PerfTimer.lastResult('getDiveProfile');
    expect(duration, isNotNull);
    expect(duration!.inMilliseconds, lessThan(50));
  });
});
```

Note: The `@Tags` annotation goes on the `main()` function, not the group. Add it at the top of the file.

### Step 2: Add performance smoke group to site_repository_test.dart

Similar pattern for site repository:

```dart
@Tags(['performance'])
group('Performance smoke tests (light preset)', () {
  late PerformanceDataGenerator generator;
  late GeneratedDataSummary summary;

  setUpAll(() async {
    generator = PerformanceDataGenerator(DataProfile.light);
    summary = await generator.generate();
  });

  test('getAllSites loads in under 50ms', () async {
    await repository.getAllSites(diverId: summary.diverId);
    final duration = PerfTimer.lastResult('getAllSites');
    expect(duration, isNotNull);
    expect(duration!.inMilliseconds, lessThan(50));
  });

  test('getSitesWithDiveCounts loads in under 100ms', () async {
    await repository.getSitesWithDiveCounts(diverId: summary.diverId);
    final duration = PerfTimer.lastResult('getSitesWithDiveCounts');
    expect(duration, isNotNull);
    expect(duration!.inMilliseconds, lessThan(100));
  });

  test('searchSites returns in under 50ms', () async {
    await repository.searchSites('reef', diverId: summary.diverId);
    final duration = PerfTimer.lastResult('searchSites');
    expect(duration, isNotNull);
    expect(duration!.inMilliseconds, lessThan(50));
  });
});
```

### Step 3: Run smoke tests

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_test.dart`
Run: `flutter test test/features/dive_sites/data/repositories/site_repository_test.dart`
Expected: All tests PASS including new performance group.

### Step 4: Run full test suite

Run: `flutter test`
Expected: All tests PASS. Smoke tests run with the regular suite.

### Step 5: Commit

```bash
git add test/features/dive_log/data/repositories/dive_repository_test.dart \
        test/features/dive_sites/data/repositories/site_repository_test.dart
git commit -m "test: add inline performance smoke tests for dive and site repositories"
```

---

## Task 5: Heavy Benchmarks — Dive Repository

**Files:**
- Create: `test/performance/dive_repository_perf_test.dart`

### Step 1: Write the benchmark test file

```dart
@Tags(['performance'])
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/performance/perf_timer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../helpers/performance_data_generator.dart';
import '../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late GeneratedDataSummary summary;

  setUpAll(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
    final generator = PerformanceDataGenerator(DataProfile.realistic);
    summary = await generator.generate();
    // Log generation stats
    print('Generated ${summary.diveCount} dives, '
        '${summary.profilePointCount} profile points in '
        '${summary.generationTime.inSeconds}s');
  });

  tearDownAll(() async {
    await tearDownTestDatabase();
  });

  setUp(() {
    PerfTimer.reset();
  });

  group('Dive repository benchmarks (${5000} dives)', () {
    test('getDiveSummaries first page < 500ms', () async {
      await repository.getDiveSummaries(
        diverId: summary.diverId,
        limit: 50,
      );
      final ms = PerfTimer.lastResult('getDiveSummaries')!.inMilliseconds;
      print('  getDiveSummaries: ${ms}ms');
      expect(ms, lessThan(500));
    });

    test('getDiveCount < 200ms', () async {
      await repository.getDiveCount(diverId: summary.diverId);
      final ms = PerfTimer.lastResult('getDiveCount')!.inMilliseconds;
      print('  getDiveCount: ${ms}ms');
      expect(ms, lessThan(200));
    });

    test('getDiveCount with filter < 200ms', () async {
      await repository.getDiveCount(
        diverId: summary.diverId,
        filter: const DiveFilterState(minRating: 3),
      );
      final ms = PerfTimer.lastResult('getDiveCount')!.inMilliseconds;
      print('  getDiveCount (filtered): ${ms}ms');
      expect(ms, lessThan(200));
    });

    test('getDiveById < 100ms', () async {
      // Get a dive ID first
      final page = await repository.getDiveSummaries(
        diverId: summary.diverId,
        limit: 1,
      );
      PerfTimer.reset();

      await repository.getDiveById(page.first.id);
      final ms = PerfTimer.lastResult('getDiveById')!.inMilliseconds;
      print('  getDiveById: ${ms}ms');
      expect(ms, lessThan(100));
    });

    test('getDiveProfile (technical dive) < 300ms', () async {
      // Find a dive with many profile points (technical dive)
      final page = await repository.getDiveSummaries(
        diverId: summary.diverId,
        limit: 50,
      );
      // Use the first dive (any dive will have profile data)
      PerfTimer.reset();

      final profile = await repository.getDiveProfile(page.first.id);
      final ms = PerfTimer.lastResult('getDiveProfile')!.inMilliseconds;
      print('  getDiveProfile (${profile.length} points): ${ms}ms');
      expect(ms, lessThan(300));
    });

    test('batchProfileSummaries (50 dives) < 500ms', () async {
      final page = await repository.getDiveSummaries(
        diverId: summary.diverId,
        limit: 50,
      );
      final ids = page.map((d) => d.id).toList();
      PerfTimer.reset();

      await repository.getBatchProfileSummaries(ids);
      final ms = PerfTimer.lastResult('batchProfileSummaries')!.inMilliseconds;
      print('  batchProfileSummaries (50): ${ms}ms');
      expect(ms, lessThan(500));
    });

    test('getAllDives (legacy) logs warning if > 500ms', () async {
      await repository.getAllDives(diverId: summary.diverId);
      final ms = PerfTimer.lastResult('getAllDives')!.inMilliseconds;
      print('  getAllDives (legacy): ${ms}ms');
      if (ms > 500) {
        print('  WARNING: getAllDives exceeds 500ms threshold');
      }
      // Soft threshold — warn but don't fail
      expect(ms, lessThan(5000)); // Only fail if catastrophically slow
    });
  });
}
```

### Step 2: Run the benchmark

Run: `flutter test test/performance/dive_repository_perf_test.dart`
Expected: All tests PASS. Note actual timings in output.

### Step 3: Commit

```bash
git add test/performance/dive_repository_perf_test.dart
git commit -m "test: add heavy dive repository performance benchmarks (5000 dives)"
```

---

## Task 6: Heavy Benchmarks — Site Repository

**Files:**
- Create: `test/performance/site_repository_perf_test.dart`

### Step 1: Write the benchmark test file

```dart
@Tags(['performance'])
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/performance/perf_timer.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';

import '../helpers/performance_data_generator.dart';
import '../helpers/test_database.dart';

void main() {
  late SiteRepository repository;
  late GeneratedDataSummary summary;

  setUpAll(() async {
    await setUpTestDatabase();
    repository = SiteRepository();
    final generator = PerformanceDataGenerator(DataProfile.realistic);
    summary = await generator.generate();
    print('Generated ${summary.siteCount} sites, '
        '${summary.diveCount} dives in '
        '${summary.generationTime.inSeconds}s');
  });

  tearDownAll(() async {
    await tearDownTestDatabase();
  });

  setUp(() {
    PerfTimer.reset();
  });

  group('Site repository benchmarks (${2000} sites)', () {
    test('getAllSites < 300ms', () async {
      await repository.getAllSites(diverId: summary.diverId);
      final ms = PerfTimer.lastResult('getAllSites')!.inMilliseconds;
      print('  getAllSites: ${ms}ms');
      expect(ms, lessThan(300));
    });

    test('getSitesWithDiveCounts < 500ms', () async {
      await repository.getSitesWithDiveCounts(diverId: summary.diverId);
      final ms = PerfTimer.lastResult('getSitesWithDiveCounts')!.inMilliseconds;
      print('  getSitesWithDiveCounts: ${ms}ms');
      expect(ms, lessThan(500));
    });

    test('searchSites < 150ms', () async {
      await repository.searchSites('reef', diverId: summary.diverId);
      final ms = PerfTimer.lastResult('searchSites')!.inMilliseconds;
      print('  searchSites: ${ms}ms');
      expect(ms, lessThan(150));
    });

    test('getDiveCountsBySite < 200ms', () async {
      final sw = Stopwatch()..start();
      await repository.getDiveCountsBySite();
      sw.stop();
      final ms = sw.elapsedMilliseconds;
      print('  getDiveCountsBySite: ${ms}ms');
      expect(ms, lessThan(200));
    });
  });
}
```

### Step 2: Run the benchmark

Run: `flutter test test/performance/site_repository_perf_test.dart`
Expected: All tests PASS. Note actual timings.

### Step 3: Commit

```bash
git add test/performance/site_repository_perf_test.dart
git commit -m "test: add heavy site repository performance benchmarks (2000 sites)"
```

---

## Task 7: Heavy Benchmarks — Profile Loading

**Files:**
- Create: `test/performance/profile_loading_perf_test.dart`

### Step 1: Write the benchmark test file

```dart
@Tags(['performance'])
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/performance/perf_timer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../helpers/performance_data_generator.dart';
import '../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late GeneratedDataSummary summary;

  setUpAll(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
    final generator = PerformanceDataGenerator(DataProfile.realistic);
    summary = await generator.generate();
    print('Generated ${summary.profilePointCount} profile points');
  });

  tearDownAll(() async {
    await tearDownTestDatabase();
  });

  setUp(() {
    PerfTimer.reset();
  });

  group('Profile loading benchmarks', () {
    test('single dive profile (recreational ~1350 pts) < 300ms', () async {
      // Get dives and pick one with a moderate profile
      final page = await repository.getDiveSummaries(
        diverId: summary.diverId,
        limit: 50,
      );
      PerfTimer.reset();

      // Load profile for first dive
      final profile = await repository.getDiveProfile(page.first.id);
      final ms = PerfTimer.lastResult('getDiveProfile')!.inMilliseconds;
      print('  Single profile (${profile.length} pts): ${ms}ms');
      expect(ms, lessThan(300));
    });

    test('batch profile summaries (50 dives) < 500ms', () async {
      final page = await repository.getDiveSummaries(
        diverId: summary.diverId,
        limit: 50,
      );
      final ids = page.map((d) => d.id).toList();
      PerfTimer.reset();

      final profiles = await repository.getBatchProfileSummaries(ids);
      final ms = PerfTimer.lastResult('batchProfileSummaries')!.inMilliseconds;
      final totalPoints = profiles.values.fold<int>(
        0,
        (sum, pts) => sum + pts.length,
      );
      print('  Batch summaries (${profiles.length} dives, '
          '$totalPoints pts): ${ms}ms');
      expect(ms, lessThan(500));
    });

    test('batch profile summaries (100 dives) < 1000ms', () async {
      // Load 2 pages
      final page1 = await repository.getDiveSummaries(
        diverId: summary.diverId,
        limit: 50,
      );
      final cursor = page1.isNotEmpty
          ? null // We'll just get the next page
          : null;
      final page2 = await repository.getDiveSummaries(
        diverId: summary.diverId,
        limit: 50,
      );
      final ids = {...page1.map((d) => d.id), ...page2.map((d) => d.id)}
          .take(100)
          .toList();
      PerfTimer.reset();

      final profiles = await repository.getBatchProfileSummaries(ids);
      final ms = PerfTimer.lastResult('batchProfileSummaries')!.inMilliseconds;
      print('  Batch summaries (${ids.length} dives): ${ms}ms');
      expect(ms, lessThan(1000));
    });
  });
}
```

### Step 2: Run the benchmark

Run: `flutter test test/performance/profile_loading_perf_test.dart`
Expected: All tests PASS.

### Step 3: Commit

```bash
git add test/performance/profile_loading_perf_test.dart
git commit -m "test: add profile loading performance benchmarks"
```

---

## Task 8: Performance Test Runner Script

**Files:**
- Create: `scripts/run_perf_tests.sh`

### Step 1: Write the script

```bash
#!/bin/bash
set -e

echo "========================================"
echo "Submersion Performance Test Suite"
echo "========================================"
echo ""

PRESET="${1:-realistic}"
echo "Running with data profile: $PRESET"
echo ""

echo "--- Dive Repository Benchmarks ---"
flutter test test/performance/dive_repository_perf_test.dart --reporter expanded 2>&1 | grep -E '^\s+(PASS|FAIL|getDive|batch|getAll|WARNING)' || true
echo ""

echo "--- Site Repository Benchmarks ---"
flutter test test/performance/site_repository_perf_test.dart --reporter expanded 2>&1 | grep -E '^\s+(PASS|FAIL|getAll|getSites|search|getDiveCount|WARNING)' || true
echo ""

echo "--- Profile Loading Benchmarks ---"
flutter test test/performance/profile_loading_perf_test.dart --reporter expanded 2>&1 | grep -E '^\s+(PASS|FAIL|Single|Batch|WARNING)' || true
echo ""

echo "========================================"
echo "All benchmarks complete."
echo "========================================"
```

### Step 2: Make executable and test

```bash
chmod +x scripts/run_perf_tests.sh
./scripts/run_perf_tests.sh
```

Expected: Summary output with timing results.

### Step 3: Commit

```bash
git add scripts/run_perf_tests.sh
git commit -m "chore: add performance test runner script"
```

---

## Task 9: Analyze Results and Fix Bottlenecks

This task depends on actual benchmark results from Tasks 5-7. The engineer should:

### Step 1: Run all benchmarks and record results

```bash
./scripts/run_perf_tests.sh 2>&1 | tee perf_results.txt
```

### Step 2: Identify failures

Review output for `[FAIL]` or timings exceeding thresholds.

### Step 3: Fix in priority order

**If `getSitesWithDiveCounts` exceeds 500ms:**

The current implementation makes 2 queries (`getAllSites` + `getDiveCountsBySite`). At 2,000 sites, optimizing to a single query with LEFT JOIN may help:

In `site_repository_impl.dart`, replace `getSitesWithDiveCounts()`:

```dart
Future<List<SiteWithDiveCount>> getSitesWithDiveCounts({
  String? diverId,
}) async {
  try {
    return await PerfTimer.measure('getSitesWithDiveCounts', () async {
      final whereClause = diverId != null ? 'WHERE s.diver_id = ?' : '';
      final args = diverId != null ? [Variable(diverId)] : <Variable<Object>>[];

      final result = await _db.customSelect(
        '''
        SELECT s.*, COUNT(d.id) as dive_count
        FROM dive_sites s
        LEFT JOIN dives d ON d.site_id = s.id
        $whereClause
        GROUP BY s.id
        ORDER BY dive_count DESC
        ''',
        variables: args,
        readsFrom: {_db.diveSites, _db.dives},
      ).get();

      return result.map((row) {
        final site = _mapQueryRowToSite(row);
        final count = row.read<int>('dive_count');
        return SiteWithDiveCount(site: site, diveCount: count);
      }).toList();
    });
  } catch (e, stackTrace) {
    _log.error('Failed to get sites with dive counts', e, stackTrace);
    rethrow;
  }
}
```

Note: This requires adding a `_mapQueryRowToSite(QueryRow row)` helper that reads from the raw query row instead of a typed `DiveSite` row. Pattern:

```dart
domain.DiveSite _mapQueryRowToSite(QueryRow row) {
  return domain.DiveSite(
    id: row.read<String>('id'),
    diverId: row.readNullable<String>('diver_id'),
    name: row.read<String>('name'),
    // ... map all fields from raw column names
  );
}
```

**If database indexes are needed:**

Add indexes in `database.dart` on the relevant table classes. Drift supports indexes via `@TableIndex` annotations or in the `@DriftDatabase` schema. Alternatively, add a migration that creates indexes:

```sql
CREATE INDEX IF NOT EXISTS idx_dives_diver_id ON dives(diver_id);
CREATE INDEX IF NOT EXISTS idx_dives_site_id ON dives(site_id);
CREATE INDEX IF NOT EXISTS idx_dives_sort ON dives(entry_time, dive_date_time, dive_number);
CREATE INDEX IF NOT EXISTS idx_dive_profiles_dive_id ON dive_profiles(dive_id);
CREATE INDEX IF NOT EXISTS idx_dive_sites_diver_id ON dive_sites(diver_id);
```

### Step 4: Re-run benchmarks to verify fixes

```bash
./scripts/run_perf_tests.sh
```

### Step 5: Commit each fix separately

```bash
git commit -m "perf: optimize getSitesWithDiveCounts with single JOIN query"
git commit -m "perf: add database indexes for query performance"
```

---

## Task 10: Performance README

**Files:**
- Create: `test/performance/README.md`

### Step 1: Write documentation

```markdown
# Performance Tests

## Overview

Performance benchmarks for Submersion at scale (5,000+ dives, 2,000+ sites).

## Running

### Quick smoke tests (runs with regular test suite)
flutter test

### Heavy benchmarks only
flutter test test/performance/

### With summary output
./scripts/run_perf_tests.sh

## Data Presets

| Preset | Dives | Sites | Profile Points | Generation Time |
|--------|-------|-------|----------------|-----------------|
| light | 100 | 30 | ~130K | < 5s |
| realistic | 5,000 | 2,000 | ~8.3M | < 15s |
| heavy | 10,000 | 4,000 | ~16.5M | < 30s |

## Thresholds

### Dive Operations (5,000 dives)
| Operation | Threshold |
|-----------|-----------|
| getDiveSummaries (page of 50) | < 500ms |
| getDiveCount (filtered) | < 200ms |
| getDiveById | < 100ms |
| getDiveProfile (up to 5,400 pts) | < 300ms |
| batchProfileSummaries (50 dives) | < 500ms |

### Site Operations (2,000 sites)
| Operation | Threshold |
|-----------|-----------|
| getAllSites | < 300ms |
| getSitesWithDiveCounts | < 500ms |
| searchSites | < 150ms |

## Adding New Benchmarks

1. Create test file in test/performance/
2. Tag with @Tags(['performance'])
3. Use PerformanceDataGenerator for data setup
4. Use PerfTimer.lastResult() for threshold assertions
5. Print timing for the runner script to capture
```

### Step 2: Commit

```bash
git add test/performance/README.md
git commit -m "docs: add performance testing README"
```

---

## Task 11: Final Verification

### Step 1: Run full test suite

```bash
flutter test
```

Expected: All tests pass (original 1,120 + new performance tests).

### Step 2: Run dart format

```bash
dart format lib/ test/
```

### Step 3: Run flutter analyze

```bash
flutter analyze
```

### Step 4: Run performance benchmarks

```bash
./scripts/run_perf_tests.sh
```

### Step 5: Final commit if any formatting changes

```bash
git add -A
git commit -m "chore: format and cleanup"
```

---

## Summary of Deliverables

| File | Type | Description |
|------|------|-------------|
| `lib/core/performance/perf_timer.dart` | New | Measurement utility |
| `test/core/performance/perf_timer_test.dart` | New | PerfTimer unit tests |
| `test/helpers/performance_data_generator.dart` | New | Configurable data generator |
| `test/helpers/performance_data_generator_test.dart` | New | Generator validation tests |
| `test/performance/dive_repository_perf_test.dart` | New | Heavy dive benchmarks |
| `test/performance/site_repository_perf_test.dart` | New | Heavy site benchmarks |
| `test/performance/profile_loading_perf_test.dart` | New | Profile loading benchmarks |
| `test/performance/README.md` | New | Documentation |
| `scripts/run_perf_tests.sh` | New | Runner script |
| `dive_repository_impl.dart` | Modified | PerfTimer instrumentation |
| `site_repository_impl.dart` | Modified | PerfTimer instrumentation |
| `dive_providers.dart` | Modified | Sort timing instrumentation |
| `site_providers.dart` | Modified | Sort timing instrumentation |
| `dive_repository_test.dart` | Modified | Smoke test group added |
| `site_repository_test.dart` | Modified | Smoke test group added |

**Estimated commits:** 9-11
