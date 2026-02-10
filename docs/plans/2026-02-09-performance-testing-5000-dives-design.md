# Performance Testing with Large Datasets (5000+ Dives)

## Overview

Build a comprehensive performance testing and optimization suite for Submersion at scale: 5,000+ dives, 2,000+ sites, and 8M+ profile data points. The suite includes a configurable synthetic data generator, two-layer measurement infrastructure (Stopwatch instrumentation + Flutter frame tracing), strict mobile-grade thresholds, and targeted fixes for bottlenecks discovered during testing.

## Scope

- **Test harness**: Configurable data generator with light/realistic/heavy presets
- **Performance fixes**: Address bottlenecks found by the benchmarks (query optimization, indexing, map clustering)
- **UI stress testing**: Flutter integration tests with frame tracing for scroll, navigation, and map rendering

## 1. Synthetic Data Generator

**File:** `test/helpers/performance_data_generator.dart`

### Presets

| Preset | Dives | Sites | Sites w/ GPS | Profile Points/Dive | Total Profile Rows |
|--------|-------|-------|-------------|--------------------|--------------------|
| `light` | 100 | 30 | 24 | 900-1,800 | ~130K |
| `realistic` | 5,000 | 2,000 | 1,600 | 900-5,400 | ~8.3M |
| `heavy` | 10,000 | 4,000 | 3,200 | 900-5,400 | ~16.5M |

Profile points are generated every 2 seconds of dive time (matching real dive computer sampling rates).

### Dive Type Distribution (realistic preset)

- **70% recreational** (3,500 dives): single tank, 30-60 min, max depth 18-30m, simple profiles
- **20% advanced** (1,000 dives): 1-2 tanks, multi-level profiles with safety stops, 40-80 min
- **10% technical** (500 dives): CCR/SCR, 2-4 tanks with gas switches, deco stops, 60-180 min, full gradient factors

### Related Data

- Sites distributed across ~40 countries and ~150 regions
- Power-law dive distribution: ~50 popular sites get 20-60 dives, long tail has 1-5 dives
- 1-3 buddies per dive from pool of ~20
- Equipment from pool of ~30 items, assigned by dive type
- Tags from pool of ~15
- Marine life sightings from built-in species catalog

### Implementation

Inserts directly via Drift batch API (`_db.batch((b) => b.insertAll(...))`) for fast generation. Returns `GeneratedDataSummary` with counts and ID lists for targeted queries.

Target generation time: < 15 seconds for realistic preset.

## 2. Performance Measurement Infrastructure

### Layer 1: PerfTimer Utility

**File:** `lib/core/performance/perf_timer.dart`

Lightweight `Stopwatch` wrapper with named operations:

```dart
class PerfTimer {
  static final Map<String, Duration> _results = {};

  static Future<T> measure<T>(String name, Future<T> Function() action) async;
  static T measureSync<T>(String name, T Function() action);
  static Duration? lastResult(String name);
  static void reset();
}
```

- `kDebugMode` guard: zero overhead in release builds (tree-shaken by Dart compiler)
- Test API: `PerfTimer.lastResult('name')` for threshold assertions
- Static methods, no DI (development/test tool, not production service)

### Instrumented Operations

| File | Method | Measurement Name |
|------|--------|-----------------|
| `dive_repository_impl.dart` | `getDiveSummaries()` | `getDiveSummaries` |
| `dive_repository_impl.dart` | `getDiveCount()` | `getDiveCount` |
| `dive_repository_impl.dart` | `getDiveById()` | `getDiveById` |
| `dive_repository_impl.dart` | `getDiveProfile()` | `getDiveProfile` |
| `dive_repository_impl.dart` | `getBatchProfileSummaries()` | `batchProfileSummaries` |
| `dive_repository_impl.dart` | `getAllDives()` | `getAllDives` |
| `dive_providers.dart` | `_applySorting()` | `applySorting` |
| `site_repository_impl.dart` | `getAllSites()` | `getAllSites` |
| `site_repository_impl.dart` | `getSitesWithDiveCounts()` | `getSitesWithDiveCounts` |
| `site_repository_impl.dart` | `searchSites()` | `searchSites` |
| `site_providers.dart` | `_applySiteSorting()` | `applySiteSorting` |

### Layer 2: Flutter Integration Tests with Frame Tracing

Uses `IntegrationTestWidgetsFlutterBinding` with `binding.traceAction()` to capture frame build/raster timelines during user interactions.

Frame metrics extracted: `averageFrameBuildTimeMillis`, `worstFrameBuildTimeMillis`, `99thPercentileFrameBuildTimeMillis`, `missedFrameCount`.

## 3. Performance Thresholds (Strict Mobile-Grade)

### Dive Operations (5,000 dives)

| Operation | Threshold |
|-----------|-----------|
| `getDiveSummaries` (page of 50) | < 500ms |
| `getDiveCount` (filtered) | < 200ms |
| `getDiveById` (single dive detail) | < 100ms |
| `getDiveProfile` (single dive, up to 5,400 points) | < 300ms |
| `batchProfileSummaries` (50 dives, downsampled) | < 500ms |
| `getAllDives` (legacy full load) | < 500ms (warn only) |
| Filter/sort provider rebuild | < 200ms |

### Site Operations (2,000 sites)

| Operation | Threshold |
|-----------|-----------|
| `getAllSites` (2,000 full objects) | < 300ms |
| `getSitesWithDiveCounts` (2,000 sites) | < 500ms |
| `searchSites` (text search) | < 150ms |
| Client-side filter + sort | < 100ms |

### UI Frame Performance

| Scenario | Threshold |
|----------|-----------|
| Dive list scroll (worst frame build) | < 16ms (60fps) |
| Dive list scroll (99th percentile) | < 8ms |
| Filter apply + list rebuild | < 200ms |
| Detail page navigation (transition + data load) | < 100ms |
| Profile chart render (5,400 points) | < 300ms |
| Site list scroll (worst frame) | < 16ms |
| Site map initial render (1,600 pins) | < 1000ms |
| Site map pan/zoom (frame time) | < 16ms |

## 4. Existing Architecture (No Changes Needed)

The dive list already has a well-designed performance architecture:

- **`DiveSummary`** entity: ~15 lightweight fields vs full `Dive` with 60+ columns
- **`PaginatedDiveListNotifier`**: cursor-based pagination, 50 items per page
- **`getDiveSummaries()`**: raw SQL with cursor comparison `(ts, num, id) < (?, ?, ?)`
- **SQL-level filtering**: `DiveFilterState` translated to WHERE clauses
- **Lazy profile loading**: `getDiveProfile()` on demand, `batchProfileSummaries()` for mini-charts
- **Optimistic UI mutations**: add/update/delete without full reload

The performance testing validates and tunes this existing implementation rather than replacing it.

## 5. Likely Optimization Targets

Based on code review, these are the most probable bottlenecks the benchmarks will surface:

1. **`getSitesWithDiveCounts()` N+1 fix** -- If using per-site COUNT queries, needs single `LEFT JOIN dives GROUP BY site_id` query
2. **Database indexes** -- Verify indexes exist on `diver_id`, `COALESCE(entry_time, dive_date_time)`, `dive_number` for cursor queries; `site_id` for join performance
3. **Map pin clustering** -- 1,600 overlapping pins needs marker clustering plugin
4. **Profile downsampling** -- `getBatchProfileSummaries()` processing 900-5,400 points x 50 dives may benefit from SQL-level downsampling
5. **`getAllDives()` legacy path** -- At 5,000 dives this will be slow; add warning log or migrate remaining consumers (export, map views)

Fix strategy: run benchmarks first, fix in priority order based on actual measurements. No speculative optimization.

## 6. Test Organization

### Inline Smoke Tests (run with `flutter test`)

Added to existing test files, tagged `@Tags(['performance'])`. Use `light` preset (100 dives, 30 sites):

- `getDiveSummaries` < 100ms
- `getDiveById` < 50ms
- `getDiveProfile` (900 points) < 50ms
- `getAllSites` < 50ms

### Heavy Benchmarks (run on demand)

```
test/performance/
  dive_repository_perf_test.dart     # Data-layer dive benchmarks
  site_repository_perf_test.dart     # Data-layer site benchmarks
  profile_loading_perf_test.dart     # Profile + downsampling benchmarks
  ui_scroll_perf_test.dart           # Dive list scroll + filter frame tracing
  ui_navigation_perf_test.dart       # Detail page + chart render frame tracing
  ui_site_map_perf_test.dart         # Site map pin rendering frame tracing
  README.md                          # How to run, thresholds, baseline updates
```

Run via:
```bash
flutter test test/performance/
./scripts/run_perf_tests.sh          # Wrapper with summary table output
```

### Summary Table Output

```
Performance Results (realistic - 5,000 dives, 2,000 sites)
------------------------------------------------------------
getDiveSummaries (page 1)    48ms   [PASS < 500ms]
getDiveCount (filtered)      12ms   [PASS < 200ms]
getDiveById                  23ms   [PASS < 100ms]
getDiveProfile (tech dive)   89ms   [PASS < 300ms]
batchProfileSummaries (50)   210ms  [PASS < 500ms]
getAllDives (legacy)          1842ms [WARN > 500ms]
getAllSites (2,000)           145ms  [PASS < 300ms]
getSitesWithDiveCounts       2301ms [FAIL < 500ms]
searchSites                  67ms   [PASS < 150ms]
Scroll 60fps worst frame     11ms   [PASS < 16ms]
Map render (1,600 pins)      890ms  [PASS < 1000ms]
```

## 7. Implementation Sequence

### Phase 1: Data Generator
- `test/helpers/performance_data_generator.dart`
- Self-test verifying correct counts per preset
- Measure generation time (target: < 15s for realistic)

### Phase 2: PerfTimer Utility
- `lib/core/performance/perf_timer.dart`
- Instrument 11 hot paths (7 dive + 4 site)
- Unit test for timing capture

### Phase 3: Smoke Tests
- Add lightweight perf assertions to existing test files
- Tagged `@Tags(['performance'])`
- Verify all pass on current codebase (establish baseline)

### Phase 4: Heavy Benchmarks
- Full stress tests with realistic/heavy presets
- `test/performance/` directory with 3 data-layer test files
- `./scripts/run_perf_tests.sh`
- Run once, record initial results, identify failures

### Phase 5: Fix Bottlenecks
- Address failures from Phase 4 in priority order
- `getSitesWithDiveCounts()` N+1 fix (if confirmed)
- Database index additions
- Profile downsampling optimization (if needed)
- `getAllDives()` legacy path warning/migration

### Phase 6: UI Integration Tests
- 3 integration test files with frame tracing
- Map pin clustering implementation (if benchmarks confirm needed)

### Phase 7: Documentation and CI Script
- `test/performance/README.md`
- Finalized `./scripts/run_perf_tests.sh`

Estimated: 7-9 focused commits, one per phase.
