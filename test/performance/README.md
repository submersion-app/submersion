# Performance Tests

## Overview

Performance benchmarks for Submersion at scale (5,000+ dives, 2,000+ sites, 8M+ profile points).

Two-layer measurement approach:

- **PerfTimer** (Stopwatch wrapper): instruments data-layer hot paths with named operations
- **Inline smoke tests**: lightweight assertions in existing test files using the `light` preset

## Running

### Quick smoke tests (runs with regular test suite)

```bash
flutter test
```text
Smoke tests use the `light` preset (100 dives, 30 sites) and run as part of the normal test suite.

### Heavy benchmarks only

```bash
flutter test test/performance/
```text
Uses `realistic` preset (5,000 dives, 2,000 sites). Takes several minutes due to data generation.

### With summary output

```bash
./scripts/run_perf_tests.sh
```

## Data Presets

| Preset | Dives | Sites | Sites w/ GPS | Profile Points/Dive | Total Profile Rows |
|--------|-------|-------|-------------|--------------------|--------------------|
| `light` | 100 | 30 | 24 | 900-1,800 | ~130K |
| `realistic` | 5,000 | 2,000 | 1,600 | 900-5,400 | ~8.3M |
| `heavy` | 10,000 | 4,000 | 3,200 | 900-5,400 | ~16.5M |

Profile points are generated every 2 seconds of dive time (matching real dive computer sampling rates). Fixed seed (`Random(42)`) ensures reproducible results across runs.

## Thresholds

### Dive Operations (5,000 dives)

| Operation | Threshold |
|-----------|-----------|
| `getDiveSummaries` (page of 50) | < 500ms |
| `getDiveCount` (filtered) | < 200ms |
| `getDiveById` (single dive) | < 100ms |
| `getDiveProfile` (up to 5,400 pts) | < 300ms |
| `batchProfileSummaries` (50 dives) | < 500ms |
| `getAllDives` (legacy) | warn > 500ms |

### Site Operations (2,000 sites)

| Operation | Threshold |
|-----------|-----------|
| `getAllSites` | < 300ms |
| `getSitesWithDiveCounts` | < 500ms |
| `searchSites` | < 150ms |
| `getDiveCountsBySite` | < 200ms |

## Test Files

| File | Description |
|------|-------------|
| `dive_repository_perf_test.dart` | Dive CRUD and pagination benchmarks |
| `site_repository_perf_test.dart` | Site query and search benchmarks |
| `profile_loading_perf_test.dart` | Profile loading and batch downsampling benchmarks |

## Adding New Benchmarks

1. Create test file in `test/performance/`
2. Tag with `@Tags(['performance'])` followed by `library;`
3. Use `PerformanceDataGenerator` with desired preset for data setup
4. Use `PerfTimer.lastResult('name')` for threshold assertions
5. Print timing with `// ignore: avoid_print` for the runner script to capture

## Profile Series Benchmark Gate

`profile_series_benchmark_test.dart` compares the packed profile series read
path against the legacy row-per-sample shapes, on a fixture synthesized from
a real development database rather than generated data. Build the fixture
once (never point the tool at a live database; it copies the source first):

```bash
dart run tools/synth_fixture.dart <source.db> <out.db> --replicas 25
```

Then run the gate:

```bash
SUBMERSION_BENCH_FIXTURE=<out.db> flutter test --run-skipped --tags performance test/performance/profile_series_benchmark_test.dart
```

The test skips with a message when `SUBMERSION_BENCH_FIXTURE` is unset.
The per-dive row measures the two profile reads (dive profile samples and tank pressure samples), not a full dive entity hydrate.
