# SAC and RMV Exclude Surface Time Implementation Plan

> **For agentic workers:** executed inline with superpowers:executing-plans
> (this repo's build-feature workflow). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Whole-dive SAC and RMV divide by the time underwater and the depth
over that time, leaving out surface runs at the start and end of the profile.

**Architecture:** One pure function finds the gas-use window in depth samples.
The `Dive` entity runs it on its profile when it has one; otherwise it reads a
copy stored in the device-local `dive_derived_metrics` cache, which the
derived-metrics sweep fills with the same function. SQL rates read the same
cache row, so every surface agrees.

**Tech Stack:** Dart, Flutter, Drift (SQLite), Riverpod.

**Spec:** `docs/design/specs/2026-11-08-sac-excludes-surface-time-design.md`

## Global Constraints

- Surface threshold `kGasUseSurfaceDepthM = 1.0` metres; a sample deeper is underwater.
- Rate time = `min(window seconds, measured runtime seconds)`; rate depth = window avg depth.
- No window (nothing trimmed, nothing underwater, fewer than 2 samples) means today's numbers, unchanged.
- Runtime, bottom time, avg depth as stored and displayed, and the profile never change.
- Schema version 348 (renumbered from 347 when #4222 shipped 347 first).
- `DerivedMetricsService.version` 3 to 4.
- No em-dashes; no AI attribution anywhere.

## Review Focus

- A dive whose runtime column is already shorter than the window (hand-edited): the rate keeps the runtime. Test in Task 2.
- A dive with a mid-dive surface interval: not trimmed. Test in Task 1.
- A profile with unsorted samples, or samples starting at a nonzero timestamp. Test in Task 1.
- A list read (no samples) and the detail read (samples) of the same dive give the same SAC. Test in Task 5.
- A dive whose cache row has not been built yet: SQL and list fall back to today's numbers. Test in Task 4.

---

### Task 1: The gas-use window rule

**Files:**
- Create: `lib/features/dive_log/domain/services/gas_use_window.dart`
- Test: `test/features/dive_log/domain/services/gas_use_window_test.dart`

**Interfaces:**
- Produces:
  - `const double kGasUseSurfaceDepthM = 1.0;`
  - `class GasUse { final int seconds; final double avgDepth; }` (const ctor, `==`/`hashCode`).
  - `class GasUseWindow { final int startSeconds; final int endSeconds; final double avgDepth; int get seconds; GasUse get use; }`
  - `GasUseWindow? gasUseWindowOf<T>(Iterable<T> samples, {required int Function(T) time, required double Function(T) depth})`

- [ ] **Step 1: Failing tests** (sample helper `(t, d)` records):
  - trailing surface tail `[(0,0),(60,5),(600,12),(1200,4),(1260,0.5),(1500,0.3),(1800,0.2)]` gives start 0, end 1260, seconds 1260.
  - leading surface `[(0,0.2),(120,0.4),(180,6),(900,6),(960,0)]` gives start 120, end 960.
  - nothing to trim `[(0,0),(60,10),(120,0)]` gives null.
  - all at surface, one sample, empty: null.
  - mid-dive surface `[(0,0),(60,8),(300,0.2),(360,8),(600,0)]` gives null (nothing trimmed at ends).
  - unsorted input gives the same window as sorted.
  - avg depth is the time-weighted mean over the window only: for the trailing-tail case, equals `timeWeightedMean` of the first five samples.
- [ ] **Step 2:** `flutter test test/features/dive_log/domain/services/gas_use_window_test.dart` fails (missing file).
- [ ] **Step 3:** Implement. Sort by time; first/last index with depth > threshold; start = previous sample's time (or the first underwater one's), end = next sample's time (or the last underwater one's); null when start == first time and end == last time; avg depth via `timeWeightedMean` (`lib/core/utils/`, the one `Dive.calculateAvgDepthFromProfile` uses) over the samples from the start index to the end index inclusive.
- [ ] **Step 4:** Tests pass.
- [ ] **Step 5:** Commit `feat(dive-log): find the gas-use window in a profile`.

### Task 2: Dive SAC and RMV use the window

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (field, ctor, copyWith, props, `sac`, `rmvFor`)
- Modify: `lib/features/dive_log/domain/services/dive_mirror_fields.dart` (unmirrored: `storedGasUse`)
- Modify: `lib/features/dive_computer/domain/services/planned_dive_fill_fields.dart` (measured: `storedGasUse`)
- Test: `test/features/dive_log/domain/entities/dive_gas_use_test.dart`

**Interfaces:**
- Consumes: Task 1.
- Produces: `final GasUse? storedGasUse;` (read-only, never written to the DB by the dive, filled by repositories); `GasUse? get gasUse` (profile with 2+ samples: `gasUseWindowOf(profile).use`, else `storedGasUse`).

- [ ] **Step 1: Failing tests:**
  - a single 12 L tank 200 to 100 bar dive, runtime 30 min, profile ending in 10 min at 0.3 m: `sac` equals 100 / (window min) / ambient(window avg depth), not the runtime figure.
  - same dive with no surface tail: `sac` is identical to the formula with runtime and stored `avgDepth`.
  - runtime column 15 min, window 20 min: `sac` divides by 15 min.
  - no profile, `storedGasUse: GasUse(seconds: 1200, avgDepth: 10)`: `sac` uses 1200 s and 10 m; `rmvFor` likewise.
  - profile present and `storedGasUse` set to something else: the profile wins.
  - rebreather and no-runtime dives stay null.
- [ ] **Step 2:** run, fails.
- [ ] **Step 3:** Add a private `({double minutes, double avgPressureBar})? _consumptionBasis()` used by both `sac` and `rmvFor`, keeping their existing null guards (runtime, avgDepth, rebreather, tanks empty). Update both doc comments to say surface time at the ends is left out (issue #2930).
- [ ] **Step 4:** pass; also run `test/features/dive_log/domain/services/dive_mirror_fields_test.dart` and `test/features/dive_computer/domain/services/planned_dive_fill_fields_test.dart`.
- [ ] **Step 5:** Commit `feat(dive-log): leave surface time out of a dive's SAC and RMV`.

### Task 3: The cache carries the window (schema v348)

**Files:**
- Modify: `lib/features/dive_log/domain/entities/derived_metrics.dart` (`gasUseSeconds`, `gasUseAvgDepthMeters`, ctor, copyWith)
- Modify: `lib/features/dive_log/domain/services/derived_metrics_service.dart` (version 4; compute on the ordered samples for every non-gauge dive with 2+ samples, rebreathers and pressure-less dives included)
- Modify: `lib/core/database/tables/dive_derived_metrics_tables.dart` (`IntColumn gasUseS`, `RealColumn gasUseAvgDepthM`, nullable)
- Modify: `lib/features/dive_log/data/repositories/derived_metrics_repository.dart` (`getMetrics`, `saveMetrics`)
- Modify: `lib/core/database/migrations/helpers/derived_metrics_migrations.dart` (`_assertDerivedMetricsGasUseColumns` via `_addColumnIfMissing`, guarded on the table)
- Modify: `lib/core/database/migrations/ladder/rungs_v340_onward.dart` (v348 entry), `before_open_table_backstops.dart` (call after `_assertDerivedMetricsTable`), `database.dart` (`currentSchemaVersion = 348`, `migrationVersions`)
- Test: `test/core/database/migration_v348_derived_metrics_gas_use_test.dart`, `test/features/dive_log/domain/services/derived_metrics_service_test.dart`, `test/features/dive_log/data/repositories/derived_metrics_repository_test.dart`

- [ ] **Step 1: Failing tests:** service computes `gasUseSeconds`/`gasUseAvgDepthMeters` for a trailing-tail profile, null for none, present on a CCR dive and a no-pressure dive; repository round-trips both; migration test in the v344 test's shape (ladder contains 348, floor does not move, fresh DB columns nullable, a v347 table upgrades with nulls).
- [ ] **Step 2:** run, fails.
- [ ] **Step 3:** implement; run `dart run build_runner build --delete-conflicting-outputs` (unfiltered, in the background).
- [ ] **Step 4:** pass; also `test/core/database` and any test that pins `DerivedMetricsService.version` (grep for `version, 3`).
- [ ] **Step 5:** Commit `feat(dive-log): store each dive's gas-use window with its derived metrics`.

### Task 4: SQL rates read the window

**Files:**
- Create: `lib/features/dive_log/data/sql/gas_use_sql.dart`
- Modify: `lib/features/dive_log/data/sql/multi_cylinder_sac_sql.dart` (`diveSacPressureSql`)
- Modify: `lib/features/insights/data/repositories/insights_repository.dart` (the six SAC/RMV queries: per dive, records, by tank role, both lanes; `watchInsightsChanges` adds `diveDerivedMetricsRows`)
- Modify: `lib/features/dive_log/query/dive_query_entity.dart` (`sac` field tables add `dive_derived_metrics`)
- Test: `test/features/dive_log/data/sql/gas_use_sql_test.dart`, plus the existing insights SAC tests

**Interfaces:**
- Produces: `String gasUseSecondsSql(String dive)` = `MIN(COALESCE(<cached gas_use_s>, <measured>), <measured>)`; `String gasUseAvgDepthSql(String dive)` = `COALESCE(<cached gas_use_avg_depth_m>, dive.avg_depth)`; `const Set<String> gasUseTables = {'dive_derived_metrics'}`.

- [ ] **Step 1: Failing tests** on an in-memory DB: a dive with a cached window reports the trimmed SAC through `diveSacPressureSql`, equal to `Dive.sac` with the same `storedGasUse`; a dive with no cache row reports today's value; a cached window longer than the runtime column uses the runtime.
- [ ] **Step 2:** run, fails.
- [ ] **Step 3:** implement; swap `measuredRuntimeSecondsSql` / `diveAmbientBarSql(d, 'd.avg_depth')` for the gas-use forms only inside rate expressions. WHERE guards (`> 0`, `avg_depth > 0`) stay as they are.
- [ ] **Step 4:** pass; run `test/features/insights` and `test/features/dive_log/query`.
- [ ] **Step 5:** Commit `feat(insights): leave surface time out of SAC and RMV charts and records`.

### Task 5: List reads carry the stored window

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`_gasUsesFor(rows)` beside `_profileSpansFor`, passed to the mapper as `storedGasUse`; `diveListTickTables` adds `gasUseTables`)
- Test: `test/features/dive_log/data/repositories/dive_repository_gas_use_test.dart`

- [ ] **Step 1: Failing test:** save a dive with a trailing-tail profile, run `DerivedMetricsRepository.ensureCurrent`, then the list read's `sac` equals the detail read's `sac` (and differs from the untrimmed figure).
- [ ] **Step 2:** run, fails.
- [ ] **Step 3:** implement; one chunked `SELECT` over `dive_derived_metrics` with a `stats-scope-exempt` marker.
- [ ] **Step 4:** pass; run `test/features/dive_log/data` and `test/architecture`.
- [ ] **Step 5:** Commit `feat(dive-log): give list reads the stored gas-use window`.

### Task 6: SAC by cylinder uses the window

**Files:**
- Modify: `lib/features/dive_log/data/services/gas_analysis_service.dart` (`calculateCylinderSac`: open-circuit path's `diveStart`/`diveEnd` come from `gasUseWindowOf(profile)` when there is one)
- Test: `test/features/dive_log/data/services/gas_analysis_service_test.dart`

- [ ] **Step 1: Failing test:** single-cylinder dive with a trailing tail: the cylinder's SAC equals `dive.sac`.
- [ ] **Step 2:** run, fails.
- [ ] **Step 3:** implement; the CCR path is untouched.
- [ ] **Step 4:** pass; run `test/features/dive_log`.
- [ ] **Step 5:** Commit `feat(dive-log): leave surface time out of SAC by cylinder`.

### Finish

- [ ] `dart format .`, `flutter analyze` (whole repo), `test/architecture`, `test/shared`, `test/core/database`.
- [ ] Before and after screenshots of the dive page's SAC on a dive with a surface tail.

---

## Follow-up: breathing at the surface

Spec section: "Breathing at the surface". Each task is TDD and ends with
`dart format`, `flutter analyze` and the tests named.

### Task S1: surface breathing bounds (pure)

- Create `lib/features/dive_log/domain/services/surface_breathing.dart`:
  `const double kSurfaceBreathingMinDropBar = 5.0;`, class
  `SurfaceBreathing { final int? from; final int? until; }` (value equality),
  and `SurfaceBreathing? surfaceBreathingOf({required GasUseWindow underwater,
  required int recordingStart, required int recordingEnd, required
  Iterable<int> switchTimes, required Iterable<List<TankPressurePoint>>
  pressures})`. Null when neither end moves.
- `gasUseWindowOf` gains `SurfaceBreathing? surfaceBreathing`, stretching the
  start to `from` and the end to `until`; a stretch to the whole recording is
  null.
- Tests: switch after the window closes stretches to the recording end; a
  switch inside the window does nothing; a 6 bar trailing fall stretches to its
  lowest point; a 3 bar fall does nothing; a rise does nothing; a leading fall
  stretches back to the last highest sample.

### Task S2: SAC by cylinder

- `cylinderUsage` takes `Map<String, List<TankPressurePoint>>? pressures` and
  computes the bounds from the breathing switches and the breathing cylinders'
  series. `calculateCylinderSac` passes its resolved series.
- Tests in `gas_analysis_service_gas_use_test.dart`: an oxygen switch logged
  on the surface rates the oxygen over its surface minutes at about 1 bar; a
  back gas whose pressure falls through the tail keeps that time.

### Task S3: cache, entity and stamp

- v348 assert adds `surface_breathed_from_s`, `surface_breathed_until_s`;
  `DiveDerivedMetrics` carries them; `ensureCurrent` reads switches and
  displayed pressures; `_stampSql` adds the switches; engine version 5.
- `Dive.surfaceBreathing` (read-only, mirror field), filled by the detail and
  list reads; `Dive.gasUse` passes it on.
- Tests: repository stores the stretched window and bounds; a switch added
  later makes the row stale; the detail read's `Dive.sac` equals the cylinder
  row on a surface-oxygen dive.

### Task S4: minutes the diver enters

- `dive_tanks.surface_breathing_duration` (v348 assert), `DiveTank.surfaceBreathingDuration`
  (Duration?), read and write mapping, copy flows.
- `_consumptionBasis`, `cylinderUsage`, the role trend and `gasUseSecondsSql` /
  `gasUseAvgDepthSql` add the seconds and blend the depth.
- Tank editor: minutes field and helper line, ARB keys in every locale.
- Tests: entity, cylinder row, SQL against `Dive.sac`, role group, migration,
  editor round trip.
- Only a cylinder with no transmitter log counts its minutes:
  `DiveTank.hasPressureSeries`, set by the list and detail reads, and a
  `tank_pressure_series` check in the SQL. The editor hides the field there.
