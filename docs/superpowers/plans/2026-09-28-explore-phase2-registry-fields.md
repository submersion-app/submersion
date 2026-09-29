# Explore Phase 2: Profile-Derived Fields on the Query Registry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver search dives by SAC, SAC trend, SAC change, final-stop stability, excursion and length, and safety findings, in the typed query language, the rule builder, the dive list filter and Explore's sentences.

**Architecture:** A pure engine derives per-dive metrics from the undecoded profile and tank-pressure blobs on a worker isolate, and a single-flight scheduler keeps one device-local table, `dive_derived_metrics`, current. The metrics become fields on the dive query registry whose SQL reads that table, so every surface that compiles a dive query gets them at once; Explore lowers its new clauses into `DiveFilterState.query`, exactly as it lowers average depth today. The `sac` field reuses the formula Insights already charts, and safety findings become a child relation over the existing synced `dive_safety_findings` table.

**Tech Stack:** Flutter, Dart, Drift (SQLite), Riverpod, the entity query language (`lib/core/query`, `lib/features/dive_log/query`), Explore (`lib/features/explore`).

**Spec:** `docs/superpowers/specs/2026-09-19-explore-natural-language-search-design.md` (section "Phase 2: profile-derived predicates") and `docs/superpowers/specs/2026-09-25-entity-query-language-design.md` (Explore, lines 277-285 and 459-465). This plan **supersedes** `docs/superpowers/plans/2026-09-20-explore-phase2-derived-predicates.md`, whose filter wiring (a `derivedPredicates` axis, hand SQL in three paths, a custom tick) predates the query language and no longer fits main.

**Source of the engine code:** branch `origin/ericgriffin/explore-phase2-derived-predicates` (called **B** below). Its engine, worker and scheduler were written and tested on 2026-09-20; this plan restores them with `git show` and changes only what the new design needs. Restore commands use `B=origin/ericgriffin/explore-phase2-derived-predicates` and must brace the ref (`"${B}:path"`): in zsh, `$B:l...` is read as a colon modifier.

## Decisions (fixed with Eric on 2026-09-28; do not re-litigate)

| Question | Decision |
| --- | --- |
| "SAC rose after N minutes" | A query field's SQL is fixed text and cannot take a diver-chosen N. Two stored fields answer instead: `sacTrend` (rising, steady, falling, from the least-squares slope) and `sacChange` (percent change from the dive's first half to its second). N is dropped; Explore puts the "after N minutes" words in `unplaced`, so the diver sees what was not applied. No `dive_sac_buckets` table. |
| A searchable SAC number | Yes, in the diver's pressure unit. The query language gains a pressure-rate dimension (`bar/min`, `psi/min`). The field reuses the formula Insights charts (see below). |
| Final-stop stability | `finalStop` enum (`stable`, `unstable`, `noStop`; unstable means the stop strayed more than 1 m from its median depth), plus `finalStopExcursion` (a depth, diver's unit) and `finalStopDuration` (minutes). |
| Safety findings | Yes, as a `findings` child relation on dives over the synced `dive_safety_findings` table, leaving out dismissed findings and findings from an older review engine. |
| Scope against query-language PR 5 | Phase 2 adds registry fields and keeps Explore on its `DiveFilterState` path. It does **not** replace `ExploreDiveField`/`DiveFieldCatalog`, change `CompiledQuery.filter`, or move `NameIndex`/`unit_grounding`: that is PR 5, which takes these fields as given. |

**One call made while planning, for Eric's review:** the `sac` field reads the same formula as `InsightsRepository.getSacPressurePerDive` (the back-gas tank's pressure drop over the runtime, normalised by average depth), not the engine's bucketed mean. A diver searching "SAC over 1.5" then gets the dives the Insights SAC chart plots at over 1.5, and the SAC chart Explore draws for that search shows the same numbers. The engine's bucketed SAC feeds only `sacTrend` and `sacChange`, which have no other source. If Eric prefers the engine mean, only Task 6's `kDiveSacSql` changes.

## Global Constraints

- Branch `ericgriffin/explore-phase2-registry-2195` off `origin/main`; the PR says `Refs #2195` (phase 3 closes it).
- Schema: main is at **244**. Open PRs claim 245 (#2572) and 246 (#2409), so this plan uses **247**. Re-scan before Task 3 (command in Task 3, Step 1); if 247 is taken, use the next free number everywhere the plan says 247.
- `AppDatabase.minimumCompatibleSchemaVersion` stays **240**: a device-local table does not move the sync floor.
- `dive_derived_metrics` has **no `hlc` column**: sync never sees it, and nothing in sync is registered.
- Field SQL carries **no `?`** (`query_registry_guards_test`): thresholds are literals or stored columns, and every table a fragment reads is declared in the field's `tables`.
- Units: SAC is stored in bar per minute at surface pressure; depths in metres; the table stores durations in seconds, and the `finalStopDuration` field shows minutes.
- No per-minute unit is spelled outside `lib/core/utils/per_minute.dart` and `UnitFormatter` (`test/architecture/rate_unit_single_source_test.dart`).
- Every new ARB key goes in all 11 files in `lib/l10n/arb/`. German never says "SAC" (`test/l10n/german_sac_terminology_test.dart`); it says "AMV", as `diveLog_cylinderSac_noSac` already does. After adding `query_*` keys run `python3.14 scripts/gen_query_label_lookup.py`, then `flutter gen-l10n`.
- Codegen: Bash refuses a bare `build` token, so run `dart run build_runner build --delete-conflicting-outputs` from a script (`printf '#!/bin/bash\ncd "%s"\ndart run build_runner build --delete-conflicting-outputs 2>&1 | tail -3\n' "$PWD" > "$TMPDIR/gen.sh" && chmod +x "$TMPDIR/gen.sh" && "$TMPDIR/gen.sh"`). `*.g.dart` files are gitignored.
- Tests restore any process-wide state they change (CI runs many test files in one isolate). Paths in tests use `p.join` and `Directory.systemTemp`.
- Aggregate SQL over `dives` in repository files needs `DiveStatsScope` or a `// stats-scope-exempt:` marker.
- No em-dashes or en-dashes as punctuation anywhere; no attribution trailers in commits.
- Pipe-free test runs: `flutter test ... 2>&1 | tail` hides the exit status. Check the last line reads `All tests passed!`.

## Review Focus

The spec says what must work; these are the inputs it implies that a person will meet first and no feature test would otherwise pin. Each has a test in the task that owns the code.

1. **A dive the sweep has not reached yet.** It has no metrics row, so `sacTrend = rising` must not match it and `NOT sacTrend = rising` must keep it (the query tree's NOT keeps unknowns). Task 6, `dive_query_derived_fields_test.dart`.
2. **An imperial diver typing a rate.** `sac > 20` with psi preferences, and `sac > 20psimin` with metric ones, both mean 1.38 bar/min; the editor shows `psi/min`. Task 1 (`unit_prefs_test.dart`) and Task 6 (semantics test with imperial prefs).
3. **A finding the diver dismissed, or one from an older review engine.** Neither may match `findings.rule = rapidAscent`. Task 7.
4. **A dive whose SAC cannot be computed** (no back-gas drop, no runtime, no average depth). `sac` is empty, so `sac:none` matches it and `sac > 0` does not. Task 6.
5. **Editing or deleting a dive.** Deleting cascades the metrics row (Task 3); an edit bumps `updated_at`, so the row goes stale and the sweep rebuilds it (Task 4); a filter that reads a derived field re-ticks when the sweep writes, because the field declares its table (Task 6, `diveFilterTablesTouched` test).

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/core/utils/per_minute.dart` (new) | Spells a per-minute unit; free of the settings layer so the query language can use it |
| `lib/core/utils/unit_formatter.dart` | `UnitFormatter.perMinute` delegates to it |
| `lib/core/query/registry/query_field.dart` | `FieldDimension.pressureRate` |
| `lib/core/query/domain/query_value.dart` | `QueryUnit.barMin`, `QueryUnit.psiMin` |
| `lib/core/query/units/unit_prefs.dart` | The rate in every unit switch, plus `displaySuffix` |
| `lib/core/query/presentation/query_value_editor.dart` | The number field's suffix comes from `displaySuffix` |
| `lib/features/dive_log/domain/entities/derived_metrics.dart` (new) | Value types: metrics, trend, stop state |
| `lib/features/dive_log/domain/services/derived_metrics_service.dart` (new) | The pure engine |
| `lib/core/database/tables/dive_derived_metrics_tables.dart` (new) | The Drift table |
| `lib/core/database/migrations/helpers/derived_metrics_migrations.dart` (new) | Idempotent create |
| `lib/core/database/database.dart`, `migrations/app_database_migrations.dart`, `migrations/ladder/rungs_v231_onward.dart`, `migrations/before_open.dart` | Registration, rung 247, backstop |
| `lib/features/dive_log/data/services/derived_metrics_worker.dart` (restored) | Decodes blobs on the isolate |
| `lib/features/dive_log/data/repositories/derived_metrics_repository.dart` (new) | Compute-through-cache, stale list |
| `lib/features/dive_log/data/services/derived_metrics_scheduler.dart` (restored) | Single-flight scheduler and sweep |
| 16 call-site files (Task 5 table) | Refresh derived metrics wherever sensor summaries refresh |
| `lib/features/dive_log/query/dive_query_entity.dart` | Six derived fields and the `findings` relation |
| `lib/features/dive_log/query/dive_child_query_entities.dart` | The `findings` entity |
| `lib/core/query/domain/query_subject.dart`, `lib/features/query/app_query_registry.dart` | The `findings` subject, registered |
| `lib/features/query/presentation/app_query_labels.dart` | Enum value labels for the new enums |
| `lib/features/explore/domain/*` | Catalog fields, units, lowering, prompt, schema version 2 |
| `lib/features/explore/presentation/chip_labeler.dart`, `widgets/explore_charts.dart`, `providers/explore_providers.dart`, `domain/chart_selection.dart` | Chip words, the SAC chart |
| `lib/l10n/arb/app_*.arb` (11) | 15 new `query_*` keys each |

---

### Task 1: A pressure-rate dimension in the query language

**Files:**
- Create: `lib/core/utils/per_minute.dart`
- Modify: `lib/core/utils/unit_formatter.dart:65`
- Modify: `test/architecture/rate_unit_single_source_test.dart` (allowlist)
- Modify: `lib/core/query/registry/query_field.dart:19-29`
- Modify: `lib/core/query/domain/query_value.dart:5-35`
- Modify: `lib/core/query/units/unit_prefs.dart`
- Modify: `lib/core/query/presentation/query_value_editor.dart:183`
- Test: `test/core/query/units/unit_prefs_test.dart`

**Interfaces:**
- Produces: `FieldDimension.pressureRate`; `QueryUnit.barMin` (suffix `barmin`) and `QueryUnit.psiMin` (suffix `psimin`); `String? displaySuffix(FieldDimension dimension, UnitPrefs prefs)` in `unit_prefs.dart`; top-level `String perMinute(String unitSymbol)` in `lib/core/utils/per_minute.dart`.

- [ ] **Step 1: Write the failing tests**

In `test/core/query/units/unit_prefs_test.dart`, add this row to the `cases` list in `'every dimension grounds and displays in both unit systems'` (1 bar/min is 14.5038 psi/min):

```dart
      (FieldDimension.pressureRate, QueryUnit.barMin, QueryUnit.psiMin, 14.5038, 1),
```

and add these two tests at the end of `main()`:

```dart
  test('a rate field shows its unit per minute', () {
    expect(displaySuffix(FieldDimension.pressureRate, kMetricPrefs), 'bar/min');
    expect(displaySuffix(FieldDimension.pressureRate, imperial), 'psi/min');
    expect(displaySuffix(FieldDimension.percent, kMetricPrefs), '%');
    expect(displaySuffix(FieldDimension.depth, imperial), 'ft');
    expect(displaySuffix(FieldDimension.count, kMetricPrefs), isNull);
  });

  test('rate suffixes are letters only, as the number token allows', () {
    expect(QueryUnit.fromSuffix('barmin'), QueryUnit.barMin);
    expect(QueryUnit.fromSuffix('PSIMIN'), QueryUnit.psiMin);
    expect(unitForDimension(FieldDimension.pressureRate, imperial), QueryUnit.psiMin);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/query/units/unit_prefs_test.dart`
Expected: compilation FAIL, `Member not found: 'pressureRate'` and `Method not found: 'displaySuffix'`.

- [ ] **Step 3: Add the one per-minute speller**

Create `lib/core/utils/per_minute.dart`:

```dart
/// Spells a per-minute rate unit: "bar/min", "psi/min", "m/min".
///
/// The one place a rate unit is written, so every surface reads the same.
/// It imports nothing, so the query language can use it without pulling in
/// the settings layer that `UnitFormatter` depends on.
String perMinute(String unitSymbol) => '$unitSymbol/min';
```

In `lib/core/utils/unit_formatter.dart`, add `import 'package:submersion/core/utils/per_minute.dart' as rate;` to the local imports and change line 65 to:

```dart
  static String perMinute(String unitSymbol) => rate.perMinute(unitSymbol);
```

In `test/architecture/rate_unit_single_source_test.dart`, add this entry to the `allowed` map, directly under the `unit_formatter.dart` entry:

```dart
    'lib/core/utils/per_minute.dart':
        'the settings-free speller UnitFormatter.perMinute delegates to',
```

- [ ] **Step 4: Add the dimension and its units**

In `lib/core/query/registry/query_field.dart`, add `pressureRate` after `pressure` in `enum FieldDimension`:

```dart
  pressure,

  /// Pressure per minute (SAC). Stored in bar per minute at the surface.
  pressureRate,
```

In `lib/core/query/domain/query_value.dart`, replace `min('min');` in `enum QueryUnit` with:

```dart
  min('min'),

  /// SAC units. Letters only, because the number token's suffix is
  /// `[A-Za-z]*`: the diver types `1.5barmin`, and the editor shows the
  /// spelled unit ("bar/min") from `displaySuffix`.
  barMin('barmin'),
  psiMin('psimin');
```

- [ ] **Step 5: Teach every unit switch the rate**

In `lib/core/query/units/unit_prefs.dart`:

Add `import 'package:submersion/core/utils/per_minute.dart';` after the `query_field.dart` import.

In `dimensionOfUnit`, add before `QueryUnit.min => FieldDimension.minutes,`:

```dart
  QueryUnit.barMin || QueryUnit.psiMin => FieldDimension.pressureRate,
```

In `unitForDimension`, add after the `case FieldDimension.pressure:` return:

```dart
    case FieldDimension.pressureRate:
      return prefs.pressure == PressureUnit.psi
          ? QueryUnit.psiMin
          : QueryUnit.barMin;
```

In `groundToStorage`, add after the `case FieldDimension.pressure:` block:

```dart
    case FieldDimension.pressureRate:
      // Per minute on both sides, so a rate converts by the pressure factor.
      final from = switch (unit) {
        QueryUnit.barMin => PressureUnit.bar,
        QueryUnit.psiMin => PressureUnit.psi,
        _ => prefs.pressure,
      };
      return from.convert(v, PressureUnit.bar);
```

In `storageToDisplay`, add after the `case FieldDimension.pressure:` block:

```dart
    case FieldDimension.pressureRate:
      final to = switch (typedUnit) {
        QueryUnit.barMin => PressureUnit.bar,
        QueryUnit.psiMin => PressureUnit.psi,
        _ => prefs.pressure,
      };
      return (PressureUnit.bar.convert(storage, to), typedUnit);
```

Append to the file:

```dart
/// What a number field shows after its value: "%" for a percent, the
/// spelled rate ("bar/min", "psi/min") for a pressure rate, otherwise the
/// unit's own suffix. Null for a unitless field.
String? displaySuffix(FieldDimension dimension, UnitPrefs prefs) {
  if (dimension == FieldDimension.percent) return '%';
  final unit = unitForDimension(dimension, prefs);
  return switch (unit) {
    QueryUnit.barMin => perMinute(QueryUnit.bar.suffix),
    QueryUnit.psiMin => perMinute(QueryUnit.psi.suffix),
    _ => unit?.suffix,
  };
}
```

In `lib/core/query/presentation/query_value_editor.dart`, replace line 183:

```dart
      suffix: field.dimension == FieldDimension.percent ? '%' : unit?.suffix,
```

with:

```dart
      suffix: displaySuffix(field.dimension, context.prefs),
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/core/query test/architecture/rate_unit_single_source_test.dart`
Expected: `All tests passed!`. The parser and validator need no change: their unitless sets do not list the rate, and `dimensionOfUnit` now maps both rate units to it.

- [ ] **Step 7: Commit**

```bash
git add lib/core/utils/per_minute.dart lib/core/utils/unit_formatter.dart test/architecture/rate_unit_single_source_test.dart lib/core/query/registry/query_field.dart lib/core/query/domain/query_value.dart lib/core/query/units/unit_prefs.dart lib/core/query/presentation/query_value_editor.dart test/core/query/units/unit_prefs_test.dart
git commit -m "feat(query): a pressure-rate dimension for SAC, in bar/min or psi/min"
```

---

### Task 2: Derived metric value types and the engine

**Files:**
- Create: `lib/features/dive_log/domain/entities/derived_metrics.dart`
- Create: `lib/features/dive_log/domain/services/derived_metrics_service.dart` (restored from B, then edited)
- Test: `test/features/dive_log/domain/entities/derived_metrics_test.dart`
- Test: `test/features/dive_log/domain/services/derived_metrics_service_test.dart` (restored from B, then edited)

**Interfaces:**
- Produces: `DiveDerivedMetrics` (fields below), `enum SacTrend { rising, steady, falling }`, `enum FinalStopState { stable, unstable, noStop }`, `enum FinalStopKind { safety, deco, none }`, `enum UnsupportedReason { noProfile, gaugeMode, noPressureSeries, tooShort }`, `const double kSacSteadyBand = 0.02`, `const double kFinalStopUnstableMeters = 1.0`, `const int kSacBucketSeconds = 300`, `class SacBucket`, `class TankPressureSeries`, `DerivedMetricsService.compute(...)`, `DerivedMetricsService.isCurrent(m, updatedAt)`, `DerivedMetricsService.version == 1`.

- [ ] **Step 1: Write the value-type test**

Create `test/features/dive_log/domain/entities/derived_metrics_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';

void main() {
  DiveDerivedMetrics metrics({
    double? slope,
    double? mean,
    FinalStopKind kind = FinalStopKind.none,
    double? excursion,
    UnsupportedReason? reason,
  }) => DiveDerivedMetrics(
    diveId: 'd1',
    engineVersion: 1,
    sourceUpdatedAt: 100,
    computedAt: 200,
    finalStopKind: kind,
    finalStopMaxExcursionMeters: excursion,
    sacMeanBarPerMin: mean,
    sacSlopeBarPerMinPerMin: slope,
    unsupportedReason: reason,
  );

  test('a bucket is five minutes wide', () {
    expect(kSacBucketSeconds, 300);
  });

  test('the trend reads the slope against a steady band', () {
    expect(metrics(slope: 0.05).sacTrend, SacTrend.rising);
    expect(metrics(slope: -0.05).sacTrend, SacTrend.falling);
    expect(metrics(slope: 0.01).sacTrend, SacTrend.steady);
    expect(metrics(slope: -0.01).sacTrend, SacTrend.steady);
    // On the band edge is still steady: the band is inclusive, so a dive is
    // never called rising on a difference the engine treats as noise.
    expect(metrics(slope: kSacSteadyBand).sacTrend, SacTrend.steady);
  });

  test('a dive with no slope has no trend', () {
    expect(metrics().sacTrend, isNull);
  });

  test('the stop state reads the excursion against one metre', () {
    expect(
      metrics(kind: FinalStopKind.safety, excursion: 0.4).finalStopState,
      FinalStopState.stable,
    );
    expect(
      metrics(kind: FinalStopKind.safety, excursion: 1.0).finalStopState,
      FinalStopState.stable,
    );
    expect(
      metrics(kind: FinalStopKind.deco, excursion: 1.4).finalStopState,
      FinalStopState.unstable,
    );
    expect(metrics().finalStopState, FinalStopState.noStop);
  });

  test('a stop is judged without pressure data, not without a profile', () {
    expect(
      metrics(
        kind: FinalStopKind.safety,
        excursion: 0.2,
        reason: UnsupportedReason.noPressureSeries,
      ).finalStopState,
      FinalStopState.stable,
    );
    for (final reason in [
      UnsupportedReason.noProfile,
      UnsupportedReason.tooShort,
      UnsupportedReason.gaugeMode,
    ]) {
      expect(metrics(reason: reason).finalStopState, isNull, reason: '$reason');
    }
  });

  test('hasSac and hasFinalStop report what was computable', () {
    expect(metrics(mean: 0.6).hasSac, isTrue);
    expect(metrics(reason: UnsupportedReason.noPressureSeries).hasSac, isFalse);
    expect(metrics(kind: FinalStopKind.safety).hasFinalStop, isTrue);
    expect(metrics(kind: FinalStopKind.none).hasFinalStop, isFalse);
  });

  test('buckets compare by value', () {
    expect(
      const SacBucket(index: 1, sacBarPerMin: 0.5),
      const SacBucket(index: 1, sacBarPerMin: 0.5),
    );
    expect(
      const SacBucket(index: 1, sacBarPerMin: 0.5),
      isNot(const SacBucket(index: 2, sacBarPerMin: 0.5)),
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/domain/entities/derived_metrics_test.dart`
Expected: FAIL, `Error when reading 'lib/features/dive_log/domain/entities/derived_metrics.dart'`.

- [ ] **Step 3: Write the value types**

Create `lib/features/dive_log/domain/entities/derived_metrics.dart`:

```dart
/// What only a profile decode can answer about a dive, computed once per
/// dive version so the dive query fields can ask about it in SQL.
///
/// Pure value types: no Flutter, no database, no analysis engine, so the
/// worker isolate can build them.
library;

/// The width of one SAC bucket. Five minutes is coarse enough that a single
/// breath does not move a bucket and fine enough to see a trend.
const int kSacBucketSeconds = 300;

/// A slope within this many bar/min per minute of zero is steady: the
/// engine cannot tell a smaller change from noise.
const double kSacSteadyBand = 0.02;

/// A final stop that strays further than this from its median depth, in
/// metres, is unstable.
const double kFinalStopUnstableMeters = 1.0;

enum FinalStopKind { safety, deco, none }

/// How steady the final stop was. Stored by name; the dive query field
/// `finalStop` lists these names.
enum FinalStopState { stable, unstable, noStop }

/// Why a metric could not be derived. A row always exists for a dive the
/// sweep has visited, so a field is empty rather than the sweep revisiting
/// the dive forever.
enum UnsupportedReason { noProfile, gaugeMode, noPressureSeries, tooShort }

/// Stored by name; the dive query field `sacTrend` lists these names.
enum SacTrend { rising, steady, falling }

/// One five-minute slice of SAC. Computed by the engine and used for the
/// mean, slope and change; not stored.
class SacBucket {
  /// Zero-based, so bucket n covers [n * kSacBucketSeconds, (n+1) * ...).
  final int index;

  /// Bar per minute at surface pressure.
  final double sacBarPerMin;

  const SacBucket({required this.index, required this.sacBarPerMin});

  @override
  bool operator ==(Object other) =>
      other is SacBucket &&
      other.index == index &&
      other.sacBarPerMin == sacBarPerMin;

  @override
  int get hashCode => Object.hash(index, sacBarPerMin);

  @override
  String toString() => 'SacBucket($index, $sacBarPerMin)';
}

class DiveDerivedMetrics {
  final String diveId;
  final int engineVersion;

  /// The dive's `updated_at` this was built from. A mismatch means stale.
  final int sourceUpdatedAt;
  final int computedAt;

  final FinalStopKind finalStopKind;
  final int? finalStopStartSeconds;
  final int? finalStopDurationSeconds;
  final double? finalStopDepthStdDevMeters;
  final double? finalStopMaxExcursionMeters;

  final double? sacMeanBarPerMin;

  /// Least-squares slope of SAC against time, in bar per minute per minute.
  final double? sacSlopeBarPerMinPerMin;

  /// Percent change of mean SAC from the dive's first half to its second.
  final double? sacChangePercent;

  final int? runtimeSeconds;
  final UnsupportedReason? unsupportedReason;

  /// The engine's buckets. Empty when read back from storage.
  final List<SacBucket> sacBuckets;

  const DiveDerivedMetrics({
    required this.diveId,
    required this.engineVersion,
    required this.sourceUpdatedAt,
    required this.computedAt,
    this.finalStopKind = FinalStopKind.none,
    this.finalStopStartSeconds,
    this.finalStopDurationSeconds,
    this.finalStopDepthStdDevMeters,
    this.finalStopMaxExcursionMeters,
    this.sacMeanBarPerMin,
    this.sacSlopeBarPerMinPerMin,
    this.sacChangePercent,
    this.runtimeSeconds,
    this.unsupportedReason,
    this.sacBuckets = const [],
  });

  bool get hasSac => sacMeanBarPerMin != null;

  bool get hasFinalStop => finalStopKind != FinalStopKind.none;

  /// Rising, falling or steady against [kSacSteadyBand]. Null when no slope
  /// could be computed.
  SacTrend? get sacTrend {
    final slope = sacSlopeBarPerMinPerMin;
    if (slope == null) return null;
    if (slope > kSacSteadyBand) return SacTrend.rising;
    if (slope < -kSacSteadyBand) return SacTrend.falling;
    return SacTrend.steady;
  }

  /// Null when the profile could not be judged at all. Missing pressure
  /// data does not stop the depth track from being read, so a dive with no
  /// pressure series still gets a stop state.
  FinalStopState? get finalStopState {
    final reason = unsupportedReason;
    if (reason != null && reason != UnsupportedReason.noPressureSeries) {
      return null;
    }
    if (finalStopKind == FinalStopKind.none) return FinalStopState.noStop;
    final excursion = finalStopMaxExcursionMeters ?? 0;
    return excursion > kFinalStopUnstableMeters
        ? FinalStopState.unstable
        : FinalStopState.stable;
  }
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/features/dive_log/domain/entities/derived_metrics_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Restore the engine and its test**

```bash
B=origin/ericgriffin/explore-phase2-derived-predicates
mkdir -p lib/features/dive_log/domain/services test/features/dive_log/domain/services
git show "${B}:lib/features/dive_log/domain/services/derived_metrics_service.dart" > lib/features/dive_log/domain/services/derived_metrics_service.dart
git show "${B}:test/features/dive_log/domain/services/derived_metrics_service_test.dart" > test/features/dive_log/domain/services/derived_metrics_service_test.dart
sed -i '' 's/m\.trend()/m.sacTrend/g' test/features/dive_log/domain/services/derived_metrics_service_test.dart
```

- [ ] **Step 6: Add the failing engine tests**

In `test/features/dive_log/domain/services/derived_metrics_service_test.dart`:

In test `'a steady safety stop is stable'`, add as its last line:

```dart
      expect(m.finalStopState, FinalStopState.stable);
```

In test `'a dive that surfaces straight from depth has no final stop'`, add as its last line:

```dart
      expect(m.finalStopState, FinalStopState.noStop);
```

In test `'a single bucket yields a mean but no slope'`, add as its last line:

```dart
      expect(m.sacChangePercent, isNull);
```

In test `'a rising consumption gives a positive slope'`, add as its last line (1 bar/min of stored pressure in the first half against 4 in the second):

```dart
      expect(m.sacChangePercent, greaterThan(50));
```

Add these tests inside `group('SAC', ...)`, after `'a single bucket yields a mean but no slope'`:

```dart
    test('a steady tank at a steady depth does not change', () {
      final level = [
        for (var t = 0; t <= 1800; t += 10)
          ProfileSample(timestamp: t, depth: 20),
      ];
      final m = run(samples: level, tanks: [steadyTank(end: 1800)]);
      expect(m.sacChangePercent, closeTo(0, 1));
      expect(m.sacTrend, SacTrend.steady);
    });
```

and inside the final-stop group, after `'a stop shorter than a minute does not count'`:

```dart
    test('a stop that strays over a metre from its median is unstable', () {
      // 3.6 m and 6.4 m alternate: a spread of 2.8 m keeps it one level run,
      // and the median of 5.0 m puts every sample 1.4 m away.
      final samples = [
        for (var t = 0; t <= 1200; t += 10)
          ProfileSample(
            timestamp: t,
            depth: t < 900 ? 20 : ((t ~/ 10).isEven ? 3.6 : 6.4),
          ),
      ];
      final m = run(samples: samples);
      expect(
        m.finalStopMaxExcursionMeters,
        greaterThan(kFinalStopUnstableMeters),
      );
      expect(m.finalStopState, FinalStopState.unstable);
    });
```

- [ ] **Step 7: Run them to verify they fail**

Run: `flutter test test/features/dive_log/domain/services/derived_metrics_service_test.dart`
Expected: it compiles (the value type already has `sacChangePercent`), and the change assertions FAIL because the engine never sets it: `Expected: a numeric value within <1> of <0>  Actual: <null>` and `Expected: a value greater than <50>  Actual: <null>`.

- [ ] **Step 8: Compute the change in the engine**

In `lib/features/dive_log/domain/services/derived_metrics_service.dart`:

In `compute`, add after `sacSlopeBarPerMinPerMin: sac?.slope,`:

```dart
      sacChangePercent: sac?.change,
```

Change the `_sac` return type and body end. Replace:

```dart
  static ({List<SacBucket> buckets, double mean, double? slope})? _sac(
```

with:

```dart
  static ({
    List<SacBucket> buckets,
    double mean,
    double? slope,
    double? change,
  })?
  _sac(
```

and replace the last three lines of `_sac`:

```dart
    if (buckets.isEmpty) return null;
    final values = buckets.map((b) => b.sacBarPerMin).toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    return (buckets: buckets, mean: mean, slope: _slope(midMinutes, values));
  }
```

with:

```dart
    if (buckets.isEmpty) return null;
    final values = buckets.map((b) => b.sacBarPerMin).toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    return (
      buckets: buckets,
      mean: mean,
      slope: _slope(midMinutes, values),
      change: _change(midMinutes, values, lastTime / 2 / 60.0),
    );
  }

  /// Percent change of the mean SAC after [halfMinutes] against before it.
  /// Null unless both halves have a bucket: one side alone is not a change.
  static double? _change(
    List<double> midMinutes,
    List<double> values,
    double halfMinutes,
  ) {
    final early = <double>[];
    final late = <double>[];
    for (var i = 0; i < values.length; i++) {
      (midMinutes[i] < halfMinutes ? early : late).add(values[i]);
    }
    if (early.isEmpty || late.isEmpty) return null;
    final before = early.reduce((a, b) => a + b) / early.length;
    final after = late.reduce((a, b) => a + b) / late.length;
    if (before <= 0) return null;
    return (after - before) / before * 100;
  }
```

- [ ] **Step 9: Run the engine and value-type tests to verify they pass**

Run: `flutter test test/features/dive_log/domain`
Expected: `All tests passed!`

- [ ] **Step 10: Commit**

```bash
git add lib/features/dive_log/domain/entities/derived_metrics.dart lib/features/dive_log/domain/services/derived_metrics_service.dart test/features/dive_log/domain/entities/derived_metrics_test.dart test/features/dive_log/domain/services/derived_metrics_service_test.dart
git commit -m "feat(dive-log): derive SAC trend, SAC change and final-stop stability from a profile"
```

---

### Task 3: The `dive_derived_metrics` table and schema rung 247

**Files:**
- Create: `lib/core/database/tables/dive_derived_metrics_tables.dart`
- Create: `lib/core/database/migrations/helpers/derived_metrics_migrations.dart`
- Modify: `lib/core/database/database.dart` (imports, exports, `@DriftDatabase`, `currentSchemaVersion`, `migrationVersions`)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (one `part` line)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (append the rung)
- Modify: `lib/core/database/migrations/before_open.dart` (one backstop call, after the v242 one)
- Test: `test/core/database/migration_v247_dive_derived_metrics_test.dart`
- Modify: `test/core/database/migration_v244_dive_plan_missions_test.dart` (relax)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: Drift table class `DiveDerivedMetricsRows` (SQL name `dive_derived_metrics`, data class `DiveDerivedMetricsRow`, companion `DiveDerivedMetricsRowsCompanion`, accessor `db.diveDerivedMetricsRows`) with columns `dive_id` (PK, FK to dives, cascade), `engine_version`, `source_updated_at`, `computed_at`, `final_stop_kind` (text, default `none`), `final_stop_state` (text, nullable), `final_stop_start_s`, `final_stop_duration_s`, `final_stop_depth_stddev_m`, `final_stop_max_excursion_m`, `sac_mean_bar_min`, `sac_slope_bar_min_per_min`, `sac_trend` (text, nullable), `sac_change_pct`, `runtime_s`, `unsupported_reason`.

- [ ] **Step 1: Confirm the rung number**

```bash
grep -n "currentSchemaVersion = " lib/core/database/database.dart
gh pr list --repo submersion-app/submersion --state open --json number --jq '.[].number' | while read n; do v=$(gh pr diff "$n" --repo submersion-app/submersion 2>/dev/null | grep -oE '^\+ *static const int currentSchemaVersion = [0-9]+' | grep -oE '[0-9]+$'); [ -n "$v" ] && echo "#$n claims $v"; done
```

Expected: main at 244 and claims of 245 and 246. If 247 is claimed or main has moved past it, pick the next free number and use it for every `247` in this task and in Task 5's tests.

- [ ] **Step 2: Write the failing migration test**

Create `test/core/database/migration_v247_dive_derived_metrics_test.dart`:

```dart
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

/// v247 adds dive_derived_metrics (issue #2195, Explore phase 2): what only a
/// profile decode can answer about a dive. Device-local: no hlc column, and
/// the sync floor stays at 240.

const _expectedColumns = {
  'dive_id',
  'engine_version',
  'source_updated_at',
  'computed_at',
  'final_stop_kind',
  'final_stop_state',
  'final_stop_start_s',
  'final_stop_duration_s',
  'final_stop_depth_stddev_m',
  'final_stop_max_excursion_m',
  'sac_mean_bar_min',
  'sac_slope_bar_min_per_min',
  'sac_trend',
  'sac_change_pct',
  'runtime_s',
  'unsupported_reason',
};

Future<Set<String>> _columns(AppDatabase db) async {
  final rows = await db
      .customSelect("PRAGMA table_info('dive_derived_metrics')")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

/// A full current schema written to a file, then the table dropped and the
/// stored version set to [storedVersion], as a database from an older build
/// or a restored copy has it. Reopened for the test.
Future<AppDatabase> _reopenWithout({required int storedVersion}) async {
  final dir = await Directory.systemTemp.createTemp('derived_metrics_rung');
  addTearDown(() => dir.delete(recursive: true));
  final file = File(p.join(dir.path, 'app.db'));
  final first = AppDatabase(NativeDatabase(file));
  await first.customStatement('DROP TABLE dive_derived_metrics');
  await first.customStatement('PRAGMA user_version = $storedVersion');
  await first.close();
  final reopened = AppDatabase(NativeDatabase(file));
  addTearDown(reopened.close);
  return reopened;
}

void main() {
  test('v247 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 247);
    expect(AppDatabase.migrationVersions, contains(247));
    expect(AppDatabase.migrationStepCount(244), 1);
    // A device-local table: the sync compatibility floor must not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('a fresh database has the table and no hlc column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final columns = await _columns(db);
    expect(columns, _expectedColumns);
    expect(columns, isNot(contains('hlc')));
  });

  test('a database from a v244 build gains the table', () async {
    final db = await _reopenWithout(storedVersion: 244);
    expect(await _columns(db), _expectedColumns);
  });

  test('a database already at the current version gains it', () async {
    // Only the beforeOpen backstop reaches it: the ladder has nothing to run.
    final db = await _reopenWithout(
      storedVersion: AppDatabase.currentSchemaVersion,
    );
    expect(await _columns(db), _expectedColumns);
  });

  test('deleting a dive deletes its metrics', () async {
    final db = await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final now = DateTime(2026, 9, 28).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('d1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await db
        .into(db.diveDerivedMetricsRows)
        .insert(
          DiveDerivedMetricsRowsCompanion.insert(
            diveId: 'd1',
            engineVersion: 1,
            sourceUpdatedAt: now,
            computedAt: now,
          ),
        );
    await (db.delete(db.dives)..where((t) => t.id.equals('d1'))).go();
    expect(await db.select(db.diveDerivedMetricsRows).get(), isEmpty);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/core/database/migration_v247_dive_derived_metrics_test.dart`
Expected: compilation FAIL, `The getter 'diveDerivedMetricsRows' isn't defined`.

- [ ] **Step 4: Write the table**

Create `lib/core/database/tables/dive_derived_metrics_tables.dart`:

```dart
/// The Explore derived metrics (issue #2195, phase 2).
library;

// Table classes are pure drift DSL: the generated code is what runs.
// coverage:ignore-file

import 'package:drift/drift.dart';
import 'package:submersion/core/database/tables/dive_tables.dart';

/// What only a profile decode can answer about a dive, computed once per
/// dive version by `DerivedMetricsService` and read by the dive query
/// fields (`sacTrend`, `sacChange`, `finalStop`, `finalStopExcursion`,
/// `finalStopDuration`). Device-local: no hlc column, so sync never reads or
/// writes it; a restore or a synced pull rebuilds it by sweep.
///
/// Named `...Rows` because `DiveDerivedMetrics` is the domain value type.
@DataClassName('DiveDerivedMetricsRow')
class DiveDerivedMetricsRows extends Table {
  @override
  String get tableName => 'dive_derived_metrics';

  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  IntColumn get engineVersion => integer()();

  /// The dive's `updated_at` this row was built from; a mismatch is stale.
  IntColumn get sourceUpdatedAt => integer()();
  IntColumn get computedAt => integer()();

  /// `FinalStopKind.name`, defaulting to none so a row always classifies.
  TextColumn get finalStopKind => text().withDefault(const Constant('none'))();

  /// `FinalStopState.name`; null when the profile could not be judged.
  TextColumn get finalStopState => text().nullable()();
  IntColumn get finalStopStartS => integer().nullable()();
  IntColumn get finalStopDurationS => integer().nullable()();
  RealColumn get finalStopDepthStddevM => real().nullable()();
  RealColumn get finalStopMaxExcursionM => real().nullable()();

  /// Bar per minute at surface pressure.
  RealColumn get sacMeanBarMin => real().nullable()();
  RealColumn get sacSlopeBarMinPerMin => real().nullable()();

  /// `SacTrend.name`; null when no slope could be computed.
  TextColumn get sacTrend => text().nullable()();

  /// Percent change of mean SAC from the dive's first half to its second.
  RealColumn get sacChangePct => real().nullable()();
  IntColumn get runtimeS => integer().nullable()();

  /// `UnsupportedReason.name` when a metric could not be derived.
  TextColumn get unsupportedReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {diveId};
}
```

- [ ] **Step 5: Register it and add the rung**

In `lib/core/database/database.dart`:
- Add `import 'package:submersion/core/database/tables/dive_derived_metrics_tables.dart';` and `export 'package:submersion/core/database/tables/dive_derived_metrics_tables.dart';` in alphabetical position among the existing `tables/` imports and exports.
- In `@DriftDatabase(tables: [...])`, add directly after `DiveSensorSummaries,`:

```dart
    // Explore derived metrics (v247, issue #2195), local only
    DiveDerivedMetricsRows,
```

- Change `static const int currentSchemaVersion = 244;` to `static const int currentSchemaVersion = 247;`.
- Append to `migrationVersions`, after the `244,` entry:

```dart
    // v247: dive_derived_metrics, the Explore derived metrics the dive query
    // fields read (issue #2195, phase 2). A table with no hlc, never synced,
    // so the floor does not move. 245 and 246 are held by #2572 and #2409.
    247,
```

Create `lib/core/database/migrations/helpers/derived_metrics_migrations.dart`:

```dart
part of '../app_database_migrations.dart';

/// The Explore derived metrics (issue #2195).
extension DerivedMetricsMigrations on AppDatabase {
  /// v247: the device-local derived metrics table. Idempotent; skipped on a
  /// partial fixture with no dives table to reference.
  Future<void> _assertDerivedMetricsTable() async {
    if (!await _tableExists('dives')) return;
    await Migrator(this).createTable(diveDerivedMetricsRows);
  }
}
```

In `lib/core/database/migrations/app_database_migrations.dart`, add after `part 'helpers/data_source_migrations.dart';`:

```dart
part 'helpers/derived_metrics_migrations.dart';
```

In `lib/core/database/migrations/ladder/rungs_v231_onward.dart`, append inside the method, after the `if (from < 244) await reportProgress();` line:

```dart
    // v247: the Explore derived metrics (issue #2195). Table-only rung, no
    // backfill: the startup sweep fills it. Re-asserted in beforeOpen.
    if (from < 247) {
      await _assertDerivedMetricsTable();
    }
    if (from < 247) await reportProgress();
```

In `lib/core/database/migrations/before_open.dart`, add directly after `await _assertEquipmentServiceStatusTable();` (the v242 backstop):

```dart

    // v247 backstop: the Explore derived metrics (local, idempotent).
    await _assertDerivedMetricsTable();
```

- [ ] **Step 6: Relax the v244 test**

In `test/core/database/migration_v244_dive_plan_missions_test.dart`, replace the first test:

```dart
  test('v244 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 244);
    expect(AppDatabase.migrationVersions, contains(244));
    expect(AppDatabase.migrationStepCount(242), 1);
```

with:

```dart
  test('v244 is at or below the current schema version and in the ladder', () {
    // Relaxed once v247 (Explore derived metrics) landed on top; the newest
    // rung owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(244));
    expect(AppDatabase.migrationVersions, contains(244));
    expect(AppDatabase.migrationStepCount(242), greaterThanOrEqualTo(1));
```

- [ ] **Step 7: Regenerate and run the tests**

Run codegen (Global Constraints), then:
`flutter test test/core/database`
Expected: `All tests passed!` (includes `database_table_libraries_test.dart`: `before_open.dart` stays under 800 lines).

- [ ] **Step 8: Commit**

```bash
git add lib/core/database/tables/dive_derived_metrics_tables.dart lib/core/database/migrations/helpers/derived_metrics_migrations.dart lib/core/database/database.dart lib/core/database/migrations/app_database_migrations.dart lib/core/database/migrations/ladder/rungs_v231_onward.dart lib/core/database/migrations/before_open.dart test/core/database/migration_v247_dive_derived_metrics_test.dart test/core/database/migration_v244_dive_plan_missions_test.dart
git commit -m "feat(dive-log): a device-local table for the Explore derived metrics (v247)"
```

---

### Task 4: The worker and the repository

**Files:**
- Create: `lib/features/dive_log/data/services/derived_metrics_worker.dart` (restored from B, unchanged)
- Create: `lib/features/dive_log/data/repositories/derived_metrics_repository.dart`
- Test: `test/features/dive_log/data/services/derived_metrics_worker_test.dart` (restored from B, unchanged)
- Test: `test/features/dive_log/data/repositories/derived_metrics_repository_test.dart`

**Interfaces:**
- Consumes: Task 2's `DiveDerivedMetrics`, `DerivedMetricsService`, `TankPressureSeries`; Task 3's `db.diveDerivedMetricsRows`.
- Produces: `DerivedMetricsWorkInput`, `TankPressureBlob`, `computeDerivedMetricsFromBlobs(input)` (worker); `DerivedMetricsRepository({AppDatabase? database, DerivedMetricsRunner? runner})` with `Future<DiveDerivedMetrics?> ensureCurrent(String diveId, {bool force = false})`, `Future<DiveDerivedMetrics?> getMetrics(String diveId)`, `Future<void> saveMetrics(DiveDerivedMetrics m)`, `Future<List<String>> staleDiveIds({String? diverId})`, `Stream<void> watchChanges()`; `typedef DerivedMetricsRunner = Future<DiveDerivedMetrics> Function(DerivedMetricsWorkInput input)`.

- [ ] **Step 1: Restore the worker and its test**

```bash
B=origin/ericgriffin/explore-phase2-derived-predicates
mkdir -p lib/features/dive_log/data/services test/features/dive_log/data/services
git show "${B}:lib/features/dive_log/data/services/derived_metrics_worker.dart" > lib/features/dive_log/data/services/derived_metrics_worker.dart
git show "${B}:test/features/dive_log/data/services/derived_metrics_worker_test.dart" > test/features/dive_log/data/services/derived_metrics_worker_test.dart
flutter test test/features/dive_log/data/services/derived_metrics_worker_test.dart
```

Expected: `All tests passed!` The worker decodes with `ProfileSeriesCodec` and `TankPressureSeriesCodec`, which main still has; if either signature moved, fix the call and say so in the commit message.

- [ ] **Step 2: Write the failing repository test**

Create `test/features/dive_log/data/repositories/derived_metrics_repository_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/derived_metrics_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/services/derived_metrics_service.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  var runs = 0;

  DerivedMetricsRepository repo({DiveDerivedMetrics? result}) {
    runs = 0;
    return DerivedMetricsRepository(
      runner: (input) async {
        runs++;
        return result ??
            DiveDerivedMetrics(
              diveId: input.diveId,
              engineVersion: DerivedMetricsService.version,
              sourceUpdatedAt: input.sourceUpdatedAt,
              computedAt: input.computedAtMs,
              finalStopKind: FinalStopKind.safety,
              finalStopDurationSeconds: 180,
              finalStopMaxExcursionMeters: 1.4,
              sacMeanBarPerMin: 0.6,
              sacSlopeBarPerMinPerMin: 0.05,
              sacChangePercent: 25,
              sacBuckets: const [
                SacBucket(index: 0, sacBarPerMin: 0.5),
                SacBucket(index: 1, sacBarPerMin: 0.7),
              ],
            );
      },
    );
  }

  Future<void> insertDive(String id, {int? updatedAt}) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(updatedAt ?? now),
        ),
      );

  test('ensureCurrent computes, stores and returns the metrics', () async {
    await insertDive('d1');
    final r = repo();
    final metrics = await r.ensureCurrent('d1');
    expect(metrics, isNotNull);
    expect(runs, 1);
    expect(metrics!.finalStopKind, FinalStopKind.safety);

    final stored = await r.getMetrics('d1');
    expect(stored!.sacMeanBarPerMin, 0.6);
    expect(stored.sacChangePercent, 25);
    expect(stored.sacTrend, SacTrend.rising);
    expect(stored.finalStopState, FinalStopState.unstable);
    expect(stored.finalStopDurationSeconds, 180);
    expect(stored.unsupportedReason, isNull);
    // Buckets are the engine's working, never stored.
    expect(stored.sacBuckets, isEmpty);
  });

  test('the query columns hold the names the dive fields list', () async {
    await insertDive('d1');
    await repo().ensureCurrent('d1');
    final row = await db.select(db.diveDerivedMetricsRows).getSingle();
    expect(row.sacTrend, 'rising');
    expect(row.finalStopState, 'unstable');
    expect(row.sacChangePct, 25);
  });

  test('an unsupported reason round-trips and leaves the fields empty', () async {
    await insertDive('d1');
    final r = repo(
      result: DiveDerivedMetrics(
        diveId: 'd1',
        engineVersion: DerivedMetricsService.version,
        sourceUpdatedAt: now,
        computedAt: now,
        unsupportedReason: UnsupportedReason.gaugeMode,
      ),
    );
    await r.ensureCurrent('d1');
    final stored = await r.getMetrics('d1');
    expect(stored!.unsupportedReason, UnsupportedReason.gaugeMode);
    expect(stored.finalStopKind, FinalStopKind.none);
    final row = await db.select(db.diveDerivedMetricsRows).getSingle();
    expect(row.sacTrend, isNull);
    expect(row.finalStopState, isNull);
  });

  test('a second call reads the stored row without recomputing', () async {
    await insertDive('d1');
    final r = repo();
    await r.ensureCurrent('d1');
    await r.ensureCurrent('d1');
    expect(runs, 1);
  });

  test('force recomputes even when the row is current', () async {
    await insertDive('d1');
    final r = repo();
    await r.ensureCurrent('d1');
    await r.ensureCurrent('d1', force: true);
    expect(runs, 2);
  });

  test('a dive that does not exist yields null and no work', () async {
    final r = repo();
    expect(await r.ensureCurrent('missing'), isNull);
    expect(runs, 0);
  });

  group('staleDiveIds', () {
    test('lists a dive with no row', () async {
      await insertDive('d1');
      expect(await repo().staleDiveIds(), ['d1']);
    });

    test('lists a dive whose engine version is older', () async {
      await insertDive('d1');
      final r = repo();
      await r.ensureCurrent('d1');
      await db.customStatement(
        'UPDATE dive_derived_metrics SET engine_version = 0',
      );
      expect(await r.staleDiveIds(), ['d1']);
    });

    test('lists a dive whose source stamp drifted', () async {
      await insertDive('d1');
      final r = repo();
      await r.ensureCurrent('d1');
      await (db.update(db.dives)..where((t) => t.id.equals('d1'))).write(
        DivesCompanion(updatedAt: Value(now + 1)),
      );
      expect(await r.staleDiveIds(), ['d1']);
    });

    test('omits a dive that is current', () async {
      await insertDive('d1');
      final r = repo();
      await r.ensureCurrent('d1');
      expect(await r.staleDiveIds(), isEmpty);
    });

    test('returns the oldest dive first', () async {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: const Value('new'),
              diveDateTime: Value(now + 1000),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await insertDive('old');
      expect(await repo().staleDiveIds(), ['old', 'new']);
    });

    test('a diver filter narrows the work list', () async {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: const Value('diver1'),
              name: const Value('Ada'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: const Value('mine'),
              diverId: const Value('diver1'),
              diveDateTime: Value(now),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await insertDive('theirs');
      expect(await repo().staleDiveIds(diverId: 'diver1'), ['mine']);
    });
  });

  test('the change tick fires on a metrics write', () async {
    await insertDive('d1');
    final r = repo();
    final ticks = <void>[];
    final sub = r.watchChanges().listen(ticks.add);
    await r.ensureCurrent('d1');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(ticks, isNotEmpty);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/derived_metrics_repository_test.dart`
Expected: compilation FAIL, `Error when reading 'lib/features/dive_log/data/repositories/derived_metrics_repository.dart'`.

- [ ] **Step 4: Write the repository**

Create `lib/features/dive_log/data/repositories/derived_metrics_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show compute;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_worker.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/services/derived_metrics_service.dart';

typedef DerivedMetricsRunner =
    Future<DiveDerivedMetrics> Function(DerivedMetricsWorkInput input);

Future<DiveDerivedMetrics> _computeOnIsolate(DerivedMetricsWorkInput input) =>
    compute(computeDerivedMetricsFromBlobs, input);

/// Reads and writes the Explore derived metrics, computing them on a worker
/// isolate when the stored row is missing or stale.
///
/// The stored row carries the query-ready columns the dive query fields
/// read (`sac_trend`, `final_stop_state`, `sac_change_pct`), written from
/// the value type's getters so the thresholds live in one place. Tests
/// substitute a same-isolate [DerivedMetricsRunner].
class DerivedMetricsRepository {
  DerivedMetricsRepository({
    AppDatabase? database,
    DerivedMetricsRunner? runner,
  }) : _dbOverride = database,
       _runner = runner ?? _computeOnIsolate;

  final AppDatabase? _dbOverride;
  final DerivedMetricsRunner _runner;

  AppDatabase get _db => _dbOverride ?? DatabaseService.instance.database;

  ProfileSeriesRepository get _series =>
      ProfileSeriesRepository(database: _dbOverride);

  /// The stored metrics when they describe the dive as it is now, otherwise
  /// freshly computed and stored before they are returned. Null when the
  /// dive does not exist.
  ///
  /// [force] rebuilds a row that looks current, for a data-quality repair
  /// that rewrote a profile without touching the dive's `updated_at`.
  Future<DiveDerivedMetrics?> ensureCurrent(
    String diveId, {
    bool force = false,
  }) async {
    final dive = await (_db.select(
      _db.dives,
    )..where((t) => t.id.equals(diveId))).getSingleOrNull();
    if (dive == null) return null;

    if (!force) {
      final stored = await getMetrics(diveId);
      if (stored != null &&
          DerivedMetricsService.isCurrent(stored, dive.updatedAt)) {
        return stored;
      }
    }

    final seriesRows = await _series.getPrimaryRowsForDives([diveId]);
    final tankRows = await (_db.select(
      _db.diveTanks,
    )..where((t) => t.diveId.equals(diveId))).get();
    final pressureRows = await (_db.select(
      _db.tankPressureSeries,
    )..where((t) => t.diveId.equals(diveId))).get();

    final metrics = await _runner(
      DerivedMetricsWorkInput(
        diveId: diveId,
        primaryBlobs: [for (final r in seriesRows) r.samples],
        tankBlobs: [
          for (final t in tankRows)
            if (_richestSeriesFor(pressureRows, t.id) case final series?)
              TankPressureBlob(
                tankId: t.id,
                volumeLiters: t.volume,
                samples: series.samples,
              ),
        ],
        diveMode: DiveMode.fromCode(dive.diveMode),
        sourceUpdatedAt: dive.updatedAt,
        computedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    await saveMetrics(metrics);
    return metrics;
  }

  /// A tank can carry one series per computer that logged it. Pick the
  /// longest, breaking a tie on id, so the same database always produces
  /// the same metrics.
  TankPressureSeriesRow? _richestSeriesFor(
    List<TankPressureSeriesRow> rows,
    String tankId,
  ) {
    TankPressureSeriesRow? best;
    for (final row in rows) {
      if (row.tankId != tankId) continue;
      if (best == null ||
          row.sampleCount > best.sampleCount ||
          (row.sampleCount == best.sampleCount &&
              row.id.compareTo(best.id) < 0)) {
        best = row;
      }
    }
    return best;
  }

  Future<DiveDerivedMetrics?> getMetrics(String diveId) async {
    final row = await (_db.select(
      _db.diveDerivedMetricsRows,
    )..where((t) => t.diveId.equals(diveId))).getSingleOrNull();
    if (row == null) return null;
    return DiveDerivedMetrics(
      diveId: row.diveId,
      engineVersion: row.engineVersion,
      sourceUpdatedAt: row.sourceUpdatedAt,
      computedAt: row.computedAt,
      finalStopKind: FinalStopKind.values.firstWhere(
        (k) => k.name == row.finalStopKind,
        orElse: () => FinalStopKind.none,
      ),
      finalStopStartSeconds: row.finalStopStartS,
      finalStopDurationSeconds: row.finalStopDurationS,
      finalStopDepthStdDevMeters: row.finalStopDepthStddevM,
      finalStopMaxExcursionMeters: row.finalStopMaxExcursionM,
      sacMeanBarPerMin: row.sacMeanBarMin,
      sacSlopeBarPerMinPerMin: row.sacSlopeBarMinPerMin,
      sacChangePercent: row.sacChangePct,
      runtimeSeconds: row.runtimeS,
      unsupportedReason: row.unsupportedReason == null
          ? null
          : UnsupportedReason.values.firstWhere(
              (r) => r.name == row.unsupportedReason,
              orElse: () => UnsupportedReason.noProfile,
            ),
    );
  }

  /// Through Drift, so the table tick reaches every list filtered on a
  /// derived field.
  Future<void> saveMetrics(DiveDerivedMetrics m) async {
    await _db
        .into(_db.diveDerivedMetricsRows)
        .insertOnConflictUpdate(
          DiveDerivedMetricsRowsCompanion(
            diveId: Value(m.diveId),
            engineVersion: Value(m.engineVersion),
            sourceUpdatedAt: Value(m.sourceUpdatedAt),
            computedAt: Value(m.computedAt),
            finalStopKind: Value(m.finalStopKind.name),
            finalStopState: Value(m.finalStopState?.name),
            finalStopStartS: Value(m.finalStopStartSeconds),
            finalStopDurationS: Value(m.finalStopDurationSeconds),
            finalStopDepthStddevM: Value(m.finalStopDepthStdDevMeters),
            finalStopMaxExcursionM: Value(m.finalStopMaxExcursionMeters),
            sacMeanBarMin: Value(m.sacMeanBarPerMin),
            sacSlopeBarMinPerMin: Value(m.sacSlopeBarPerMinPerMin),
            sacTrend: Value(m.sacTrend?.name),
            sacChangePct: Value(m.sacChangePercent),
            runtimeS: Value(m.runtimeSeconds),
            unsupportedReason: Value(m.unsupportedReason?.name),
          ),
        );
  }

  /// Dives whose row is missing, built by an older engine, or built from a
  /// different dive version. Oldest dive first.
  // stats-scope-exempt: a work list, not an aggregate; an excluded dive
  // still needs its metrics for the query fields to answer about it.
  Future<List<String>> staleDiveIds({String? diverId}) async {
    final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
    final rows = await _db
        .customSelect(
          'SELECT d.id AS id FROM dives d '
          'LEFT JOIN dive_derived_metrics m ON m.dive_id = d.id '
          'WHERE (m.dive_id IS NULL OR m.engine_version < ? '
          'OR m.source_updated_at != d.updated_at) $diverFilter '
          'ORDER BY d.dive_date_time ASC, d.id ASC',
          variables: [
            const Variable(DerivedMetricsService.version),
            if (diverId != null) Variable(diverId),
          ],
          readsFrom: {_db.dives, _db.diveDerivedMetricsRows},
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toList();
  }

  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.diveDerivedMetricsRows));
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/dive_log/data test/core/database/dive_stats_scope_census_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_log/data/services/derived_metrics_worker.dart lib/features/dive_log/data/repositories/derived_metrics_repository.dart test/features/dive_log/data/services/derived_metrics_worker_test.dart test/features/dive_log/data/repositories/derived_metrics_repository_test.dart
git commit -m "feat(dive-log): derive metrics from undecoded blobs and keep them per dive version"
```

---

### Task 5: The scheduler, its hooks and the test harness

**Files:**
- Create: `lib/features/dive_log/data/services/derived_metrics_scheduler.dart` (restored from B, unchanged)
- Test: `test/features/dive_log/data/services/derived_metrics_scheduler_test.dart` (restored from B, unchanged)
- Create: `test/architecture/derived_metrics_hooks_test.dart`
- Modify: `test/helpers/global_test_defaults.dart:41`, `test/architecture/global_state_scanner.dart:45`
- Modify: the 16 files in the Step 4 table

**Interfaces:**
- Consumes: Task 4's `DerivedMetricsRepository`.
- Produces: `DerivedMetricsScheduler.instance` with `static bool enabled`, `void schedule(Set<String> diveIds, {bool force = false})`, `void scheduleStaleSweep({String? diverId})`; top-level `void scheduleDerivedMetricsRefresh(Iterable<String> diveIds, {bool force = false})`.

- [ ] **Step 1: Restore the scheduler and its test, and switch it off in tests**

```bash
B=origin/ericgriffin/explore-phase2-derived-predicates
git show "${B}:lib/features/dive_log/data/services/derived_metrics_scheduler.dart" > lib/features/dive_log/data/services/derived_metrics_scheduler.dart
git show "${B}:test/features/dive_log/data/services/derived_metrics_scheduler_test.dart" > test/features/dive_log/data/services/derived_metrics_scheduler_test.dart
```

In `test/helpers/global_test_defaults.dart`, add the import `import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';` and, directly after `SensorSummaryScheduler.enabled = false;`:

```dart
  DerivedMetricsScheduler.enabled = false;
```

In `test/architecture/global_state_scanner.dart`, add to `harnessDefaults`, directly after `'SensorSummaryScheduler.enabled',`:

```dart
  'DerivedMetricsScheduler.enabled',
```

Run: `flutter test test/features/dive_log/data/services/derived_metrics_scheduler_test.dart test/architecture`
Expected: `All tests passed!` (the scheduler test turns `enabled` on in its own `setUp` and restores it; if the global-state guard flags it, restore it in `addTearDown` as the guard says).

- [ ] **Step 2: Write the failing hook guard**

Create `test/architecture/derived_metrics_hooks_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The derived metrics and the sensor summaries are both computed from a
/// dive's profile, so every site that refreshes one refreshes the other. A
/// site that forgets leaves the SAC and final-stop fields answering about a
/// profile the diver has since changed, until the next launch sweep.
void main() {
  test('derived metrics are scheduled wherever sensor summaries are', () {
    int count(String text, String call) => call.allMatches(text).length;
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.endsWith('/sensor_summary_scheduler.dart')) continue;
      if (path.endsWith('/derived_metrics_scheduler.dart')) continue;
      final text = entity.readAsStringSync();
      final refreshes = count(text, 'scheduleSensorSummaryRefresh(');
      final derived = count(text, 'scheduleDerivedMetricsRefresh(');
      final sweeps = count(
        text,
        'SensorSummaryScheduler.instance.scheduleStaleSweep(',
      );
      final derivedSweeps = count(
        text,
        'DerivedMetricsScheduler.instance.scheduleStaleSweep(',
      );
      if (refreshes != derived || sweeps != derivedSweeps) {
        offenders.add(
          '$path: $refreshes sensor vs $derived derived refreshes, '
          '$sweeps sensor vs $derivedSweeps derived sweeps',
        );
      }
    }
    expect(offenders, isEmpty);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/architecture/derived_metrics_hooks_test.dart`
Expected: FAIL, listing the 16 files in the table below.

- [ ] **Step 4: Add the hooks**

At each site, add the derived call on the line directly after the sensor call, with the **same ids and the same `force`**, and add the import `import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';` to each file (alphabetical among the `features/dive_log` imports). Line numbers are main's at planning time; find each by the sensor call.

| File | After this line | Add |
| --- | --- | --- |
| `lib/app.dart` | `SensorSummaryScheduler.instance.scheduleStaleSweep();` (157) | `DerivedMetricsScheduler.instance.scheduleStaleSweep();` |
| `lib/features/settings/presentation/providers/sync_providers.dart` | same, 1417 | `DerivedMetricsScheduler.instance.scheduleStaleSweep();` |
| `lib/features/backup/presentation/providers/backup_providers.dart` | same, 362, 563 and 615 | `DerivedMetricsScheduler.instance.scheduleStaleSweep();` (three times) |
| `lib/features/data_quality/data/services/quality_repair_executor.dart` | `scheduleSensorSummaryRefresh(diveIds, force: true);` (63) | `scheduleDerivedMetricsRefresh(diveIds, force: true);` |
| `lib/features/data_quality/presentation/pages/data_quality_inbox_page.dart` | `scheduleSensorSummaryRefresh([diveId, newId], force: true);` (239) | `scheduleDerivedMetricsRefresh([diveId, newId], force: true);` |
| `lib/features/import_wizard/data/adapters/suunto_cloud_adapter.dart` | `scheduleSensorSummaryRefresh(importedDiveIds);` (425) | `scheduleDerivedMetricsRefresh(importedDiveIds);` |
| `lib/features/import_wizard/data/adapters/healthkit_adapter.dart` | same, 321 | `scheduleDerivedMetricsRefresh(importedDiveIds);` |
| `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart` | same, 899 | `scheduleDerivedMetricsRefresh(importedDiveIds);` |
| `lib/features/import_wizard/data/adapters/garmin_cloud_adapter.dart` | same, 433 | `scheduleDerivedMetricsRefresh(importedDiveIds);` |
| `lib/features/import_wizard/data/adapters/universal_adapter.dart` | `scheduleSensorSummaryRefresh(netImportedDiveIds);` (1256) | `scheduleDerivedMetricsRefresh(netImportedDiveIds);` |
| `lib/features/dive_log/presentation/pages/dive_edit_page.dart` | `scheduleSensorSummaryRefresh(ids);` (2210) and `scheduleSensorSummaryRefresh([savedDiveId]);` (5757) | `scheduleDerivedMetricsRefresh(ids);` and `scheduleDerivedMetricsRefresh([savedDiveId]);` |
| `lib/features/dive_log/presentation/widgets/run_dive_consolidation.dart` | `scheduleSensorSummaryRefresh([targetDiveId, ...secondaryDiveIds]);` (52 and 70) | `scheduleDerivedMetricsRefresh([targetDiveId, ...secondaryDiveIds]);` (twice) |
| `lib/features/dive_log/presentation/pages/dive_detail_page.dart` | `scheduleSensorSummaryRefresh([dive.id, newDiveId]);` (5418) and `scheduleSensorSummaryRefresh([dive.id, ...newDiveIds]);` (5468) | `scheduleDerivedMetricsRefresh([dive.id, newDiveId]);` and `scheduleDerivedMetricsRefresh([dive.id, ...newDiveIds]);` |
| `lib/features/dive_log/presentation/widgets/combine_dives_dialog.dart` | the `scheduleSensorSummaryRefresh([...widget.diveIds, outcome.mergedDive.id], force: true);` statement (99-102) | `scheduleDerivedMetricsRefresh([...widget.diveIds, outcome.mergedDive.id], force: true);` |
| `lib/features/dive_log/presentation/widgets/dive_list_content.dart` | the `scheduleSensorSummaryRefresh([...ids, toUndo.mergedDive.id], force: true);` statement (619-622) | `scheduleDerivedMetricsRefresh([...ids, toUndo.mergedDive.id], force: true);` |
| `lib/features/dive_computer/data/services/reparse_service.dart` | `if (sources.isNotEmpty) scheduleSensorSummaryRefresh([diveId]);` (507) | `if (sources.isNotEmpty) scheduleDerivedMetricsRefresh([diveId]);` |

- [ ] **Step 5: Run the guard and the touched features' tests**

Run: `dart format lib test && flutter analyze lib test/architecture && flutter test test/architecture test/features/dive_log/data`
Expected: `No issues found!` then `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_log/data/services/derived_metrics_scheduler.dart test/features/dive_log/data/services/derived_metrics_scheduler_test.dart test/architecture/derived_metrics_hooks_test.dart test/helpers/global_test_defaults.dart test/architecture/global_state_scanner.dart lib/app.dart lib/features/settings/presentation/providers/sync_providers.dart lib/features/backup/presentation/providers/backup_providers.dart lib/features/data_quality/data/services/quality_repair_executor.dart lib/features/data_quality/presentation/pages/data_quality_inbox_page.dart lib/features/import_wizard/data/adapters/suunto_cloud_adapter.dart lib/features/import_wizard/data/adapters/healthkit_adapter.dart lib/features/import_wizard/data/adapters/dive_computer_adapter.dart lib/features/import_wizard/data/adapters/garmin_cloud_adapter.dart lib/features/import_wizard/data/adapters/universal_adapter.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/features/dive_log/presentation/widgets/run_dive_consolidation.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/dive_log/presentation/widgets/combine_dives_dialog.dart lib/features/dive_log/presentation/widgets/dive_list_content.dart lib/features/dive_computer/data/services/reparse_service.dart
git commit -m "feat(dive-log): keep the derived metrics current wherever sensor summaries refresh"
```

---

### Task 6: The derived fields on the dive query registry

**Files:**
- Modify: `lib/features/dive_log/query/dive_query_entity.dart`
- Modify: `lib/features/query/presentation/app_query_labels.dart` (enum value labels)
- Modify: `lib/l10n/arb/app_*.arb` (11 files, 12 keys each), then regenerate `lib/features/query/presentation/query_label_lookup.dart` and the l10n classes
- Create: `test/features/dive_log/query/dive_query_derived_fields_test.dart`
- Modify: `test/features/dive_log/query/dive_filter_three_paths_test.dart` (one case)

**Interfaces:**
- Consumes: Task 1's `FieldDimension.pressureRate`; Task 2's `SacTrend`, `FinalStopState`; Task 3's table.
- Produces: dive fields `sac` (number, pressureRate, bar/min), `sacTrend` (enum `rising|steady|falling`), `sacChange` (number, percent), `finalStop` (enum `stable|unstable|noStop`), `finalStopExcursion` (number, depth, metres), `finalStopDuration` (number, minutes); constants `kDiveDerivedMetricsTable = 'dive_derived_metrics'` and `kDiveSacSql` in `dive_query_entity.dart`; ARB keys `query_dives_sac`, `query_dives_sacTrend`, `query_dives_sacTrend_rising`, `query_dives_sacTrend_steady`, `query_dives_sacTrend_falling`, `query_dives_sacChange`, `query_dives_finalStop`, `query_dives_finalStop_stable`, `query_dives_finalStop_unstable`, `query_dives_finalStop_noStop`, `query_dives_finalStopExcursion`, `query_dives_finalStopDuration`.

- [ ] **Step 1: Write the failing semantics test**

Create `test/features/dive_log/query/dive_query_derived_fields_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';

/// The Explore derived fields (#2195) typed, parsed, validated, compiled and
/// run against a seeded database.
///
/// d1: back-gas 200 to 140 bar over 50 min at 15 m average, so SAC is
///     60 / 50 / 2.5 = 0.48 bar/min; rising SAC (+30%); a stable 4 min stop.
/// d2: no tank; steady SAC (+2%); an unstable 3 min stop 1.4 m off.
/// d3: swept, but a gauge dive: every derived field empty.
/// d4: not swept yet: no row at all.
void main() {
  late AppDatabase db;
  final now = DateTime(2026, 9, 28).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: const Value('me'),
            name: const Value('Me'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    Future<void> dive(String id, {int? runtime, double? avgDepth}) => db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diverId: const Value('me'),
            diveDateTime: now,
            runtime: Value(runtime),
            avgDepth: Value(avgDepth),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await dive('d1', runtime: 3000, avgDepth: 15);
    await dive('d2', runtime: 2400, avgDepth: 12);
    await dive('d3');
    await dive('d4');
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 't1',
            diveId: 'd1',
            startPressure: const Value(200),
            endPressure: const Value(140),
          ),
        );
    Future<void> metrics(
      String diveId, {
      String? trend,
      double? change,
      String? stop,
      double? excursion,
      int? stopSeconds,
      String? unsupported,
    }) => db
        .into(db.diveDerivedMetricsRows)
        .insert(
          DiveDerivedMetricsRowsCompanion.insert(
            diveId: diveId,
            engineVersion: 1,
            sourceUpdatedAt: now,
            computedAt: now,
            sacTrend: Value(trend),
            sacChangePct: Value(change),
            finalStopState: Value(stop),
            finalStopMaxExcursionM: Value(excursion),
            finalStopDurationS: Value(stopSeconds),
            unsupportedReason: Value(unsupported),
          ),
        );
    await metrics(
      'd1',
      trend: 'rising',
      change: 30,
      stop: 'stable',
      excursion: 0.3,
      stopSeconds: 240,
    );
    await metrics(
      'd2',
      trend: 'steady',
      change: 2,
      stop: 'unstable',
      excursion: 1.4,
      stopSeconds: 180,
    );
    await metrics('d3', unsupported: 'gaugeMode');
  });
  tearDown(tearDownTestDatabase);

  final dives = appQueryRegistry.entityFor(QuerySubject.dives);
  const imperial = UnitPrefs(
    depth: DepthUnit.feet,
    temperature: TemperatureUnit.fahrenheit,
    pressure: PressureUnit.psi,
    weight: WeightUnit.pounds,
    volume: VolumeUnit.cubicFeet,
  );

  Future<Set<String>> ids(String text, {UnitPrefs prefs = kMetricPrefs}) async {
    final parser = QueryParser(
      appQueryRegistry,
      dives,
      ParseContext(
        prefs: prefs,
        now: DateTime(2026, 9, 28),
        names: const MapNameResolver({}),
      ),
    );
    final parsed = parser.parse(text);
    expect(parsed, isA<ParseOk>(), reason: '$parsed');
    final node = (parsed as ParseOk).node;
    expect(validateQuery(node, dives, appQueryRegistry), isEmpty);
    final q = compileQuery(node, dives, appQueryRegistry, rootAlias: 'd');
    final rows = await db
        .customSelect(
          'SELECT d.id FROM dives d WHERE d.diver_id = ? AND ${q.where}',
          variables: [
            const Variable<String>('me'),
            ...q.params.map((p) => Variable(p)),
          ],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test('the SAC trend and change', () async {
    expect(await ids('sacTrend = rising'), {'d1'});
    expect(await ids('sacChange > 20'), {'d1'});
    expect(await ids('sacChange < 5'), {'d2'});
  });

  test('a dive the sweep has not reached is empty, never a match', () async {
    expect(await ids('sacTrend:none'), {'d3', 'd4'});
    // NOT keeps an unknown: an unswept dive is not known to be rising.
    expect(await ids('NOT sacTrend = rising'), {'d2', 'd3', 'd4'});
  });

  test('the final stop state, excursion and length', () async {
    expect(await ids('finalStop = unstable'), {'d2'});
    expect(await ids('finalStop:none'), {'d3', 'd4'});
    expect(await ids('finalStopExcursion > 1'), {'d2'});
    expect(await ids('finalStopDuration >= 4'), {'d1'});
  });

  test('the excursion is a depth in the diver unit', () async {
    // 3 ft is 0.91 m: d2 strayed 1.4 m, d1 0.3 m.
    expect(await ids('finalStopExcursion > 3', prefs: imperial), {'d2'});
    expect(await ids('finalStopExcursion > 3ft'), {'d2'});
  });

  test('SAC uses the Insights formula and the diver pressure unit', () async {
    expect(await ids('sac > 0.47'), {'d1'});
    expect(await ids('sac < 0.49'), {'d1'});
    // 0.48 bar/min is 6.96 psi/min.
    expect(await ids('sac > 6', prefs: imperial), {'d1'});
    expect(await ids('sac > 7', prefs: imperial), isEmpty);
    expect(await ids('sac > 6psimin'), {'d1'});
    // No back-gas drop, no runtime or no average depth: no SAC.
    expect(await ids('sac:none'), {'d2', 'd3', 'd4'});
  });

  test('SAC agrees with the Insights SAC chart', () async {
    final points = await InsightsRepository().getSacPressurePerDive(
      diverId: 'me',
    );
    expect(points.map((p) => p.diveId).toSet(), await ids('sac:any'));
    expect(points.single.value, closeTo(0.48, 0.001));
  });

  test('a filter on a derived field follows its table', () {
    DiveFilterState on(String key, QueryValue value) => DiveFilterState(
      query: ConditionNode(FieldPath([key]), QueryOp.eq, value),
    );
    expect(
      diveFilterTablesTouched(on('sacTrend', const EnumValue('rising'))),
      contains('dive_derived_metrics'),
    );
    expect(
      diveFilterTablesTouched(on('sac', const NumberValue(1, null))),
      contains('dive_tanks'),
    );
  });
}
```

(`QueryValue`, `EnumValue` and `NumberValue` reach the test through `query_node.dart`, which exports the value types; a separate `query_value.dart` import is flagged as unnecessary.)

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/query/dive_query_derived_fields_test.dart`
Expected: FAIL at the first parse: `ParseError(unknownField ...)` for `sacTrend`.

- [ ] **Step 3: Register the fields**

In `lib/features/dive_log/query/dive_query_entity.dart`, add the import `import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';`, then add these top-level declarations directly above `final QueryEntity diveQueryEntity = QueryEntity(`:

```dart
/// The Explore derived metrics (#2195): a device-local table the derived
/// metrics scheduler keeps current. A dive not yet swept has no row, so its
/// derived fields are empty (`:none`) until the sweep reaches it.
const kDiveDerivedMetricsTable = 'dive_derived_metrics';

String _derived(String column) =>
    '(SELECT m.$column FROM $kDiveDerivedMetricsTable m '
    'WHERE m.dive_id = {r}.id)';

/// SAC in bar per minute at the surface, by the formula the Insights SAC
/// chart plots (`InsightsRepository.getSacPressurePerDive`): the back-gas
/// tank's pressure drop over the runtime, normalised by the average depth,
/// so a search and the chart agree. Empty with no such tank, no runtime or
/// no average depth.
const kDiveSacSql =
    '(SELECT (t.start_pressure - t.end_pressure) '
    '/ (COALESCE({r}.runtime, {r}.bottom_time) / 60.0) '
    '/ (({r}.avg_depth / 10.0) + 1) '
    'FROM dive_tanks t WHERE t.id = ('
    'SELECT t2.id FROM dive_tanks t2 WHERE t2.dive_id = {r}.id '
    'AND t2.start_pressure > t2.end_pressure '
    "AND (t2.tank_role = 'backGas' OR NOT EXISTS ("
    'SELECT 1 FROM dive_tanks t3 WHERE t3.dive_id = {r}.id '
    "AND t3.tank_role = 'backGas')) "
    'ORDER BY t2.tank_order, t2.rowid LIMIT 1) '
    'AND COALESCE({r}.runtime, {r}.bottom_time) > 0 '
    'AND {r}.avg_depth > 0)';
```

Add these fields to `fields:`, directly after the `gasCount` field:

```dart
    _num(
      'sac',
      kDiveSacSql,
      dimension: FieldDimension.pressureRate,
      sanity: (min: 0, max: 20),
      tables: ['dive_tanks'],
    ),
    QueryField(
      key: 'sacTrend',
      type: FieldType.enumName,
      sql: _derived('sac_trend'),
      emptySql: '${_derived('sac_trend')} IS NULL',
      labelKey: _label('sacTrend'),
      enumValues: _names(SacTrend.values),
      tables: const [kDiveDerivedMetricsTable],
    ),
    _num(
      'sacChange',
      _derived('sac_change_pct'),
      dimension: FieldDimension.percent,
      sanity: (min: -100, max: 1000),
      tables: [kDiveDerivedMetricsTable],
    ),
    QueryField(
      key: 'finalStop',
      type: FieldType.enumName,
      sql: _derived('final_stop_state'),
      emptySql: '${_derived('final_stop_state')} IS NULL',
      labelKey: _label('finalStop'),
      enumValues: _names(FinalStopState.values),
      tables: const [kDiveDerivedMetricsTable],
    ),
    _num(
      'finalStopExcursion',
      _derived('final_stop_max_excursion_m'),
      dimension: FieldDimension.depth,
      sanity: (min: 0, max: 10),
      tables: [kDiveDerivedMetricsTable],
    ),
    // Whole minutes, truncated, like bottomTime.
    _num(
      'finalStopDuration',
      _derived('final_stop_duration_s / 60'),
      dimension: FieldDimension.minutes,
      tables: [kDiveDerivedMetricsTable],
    ),
```

(`_derived('final_stop_duration_s / 60')` yields `(SELECT m.final_stop_duration_s / 60 FROM ...)`: the division happens inside the subquery.)

- [ ] **Step 4: Add the labels in all 11 locales**

Save this as `$TMPDIR/add_query_keys.py`. It inserts each key as text directly after its anchor key (and after the anchor's one-line `@` metadata in English), which keeps every other line of the ARB byte-for-byte:

```python
import json
import pathlib
import sys

ARB = pathlib.Path('lib/l10n/arb')
LOCALES = ['en', 'ar', 'de', 'es', 'fr', 'he', 'hu', 'it', 'nl', 'pt', 'zh']

FIELD = 'Field label in the query builder'
VALUE = 'Enum value label in the query builder'
ENTITY = 'Entity label in the query builder'


def t(*texts):
    return dict(zip(LOCALES, texts))


TASK6 = [
    ('query_dives_sac', 'query_dives_rating', FIELD,
     t('SAC', 'SAC', 'AMV', 'SAC', 'SAC', 'SAC', 'SAC', 'SAC', 'SAC', 'SAC', 'SAC')),
    ('query_dives_sacTrend', 'query_dives_rating', FIELD,
     t('SAC trend', 'اتجاه SAC', 'AMV-Trend', 'Tendencia del SAC', 'Tendance du SAC',
       'מגמת SAC', 'SAC-trend', 'Andamento del SAC', 'SAC-trend', 'Tendência do SAC', 'SAC 趋势')),
    ('query_dives_sacTrend_rising', 'query_dives_rating', VALUE,
     t('Rising', 'متزايد', 'Steigend', 'En aumento', 'En hausse', 'עולה', 'Emelkedő',
       'In aumento', 'Stijgend', 'Em alta', '上升')),
    ('query_dives_sacTrend_steady', 'query_dives_rating', VALUE,
     t('Steady', 'ثابت', 'Gleichbleibend', 'Estable', 'Stable', 'יציב', 'Egyenletes',
       'Stabile', 'Stabiel', 'Estável', '平稳')),
    ('query_dives_sacTrend_falling', 'query_dives_rating', VALUE,
     t('Falling', 'متناقص', 'Fallend', 'En descenso', 'En baisse', 'יורד', 'Csökkenő',
       'In calo', 'Dalend', 'Em queda', '下降')),
    ('query_dives_sacChange', 'query_dives_rating', FIELD,
     t('SAC change', 'تغير SAC', 'AMV-Änderung', 'Variación del SAC', 'Variation du SAC',
       'שינוי SAC', 'SAC-változás', 'Variazione del SAC', 'SAC-verandering',
       'Variação do SAC', 'SAC 变化')),
    ('query_dives_finalStop', 'query_dives_rating', FIELD,
     t('Final stop', 'التوقف الأخير', 'Letzter Stopp', 'Última parada', 'Dernier palier',
       'עצירה אחרונה', 'Utolsó megálló', 'Ultima sosta', 'Laatste stop', 'Última parada',
       '最后停留')),
    ('query_dives_finalStop_stable', 'query_dives_rating', VALUE,
     t('Stable', 'مستقر', 'Stabil', 'Estable', 'Stable', 'יציבה', 'Stabil', 'Stabile',
       'Stabiel', 'Estável', '稳定')),
    ('query_dives_finalStop_unstable', 'query_dives_rating', VALUE,
     t('Unstable', 'غير مستقر', 'Instabil', 'Inestable', 'Instable', 'לא יציבה', 'Instabil',
       'Instabile', 'Instabiel', 'Instável', '不稳定')),
    ('query_dives_finalStop_noStop', 'query_dives_rating', VALUE,
     t('No stop', 'بلا توقف', 'Kein Stopp', 'Sin parada', 'Aucun palier', 'ללא עצירה',
       'Nincs megálló', 'Nessuna sosta', 'Geen stop', 'Sem parada', '无停留')),
    ('query_dives_finalStopExcursion', 'query_dives_rating', FIELD,
     t('Final stop excursion', 'الانحراف في التوقف الأخير', 'Abweichung beim letzten Stopp',
       'Desvío en la última parada', 'Écart au dernier palier', 'סטייה בעצירה האחרונה',
       'Eltérés az utolsó megállónál', "Scostamento all'ultima sosta",
       'Afwijking bij laatste stop', 'Desvio na última parada', '最后停留偏差')),
    ('query_dives_finalStopDuration', 'query_dives_rating', FIELD,
     t('Final stop length', 'مدة التوقف الأخير', 'Dauer des letzten Stopps',
       'Duración de la última parada', 'Durée du dernier palier', 'משך העצירה האחרונה',
       'Az utolsó megálló hossza', "Durata dell'ultima sosta", 'Duur laatste stop',
       'Duração da última parada', '最后停留时长')),
]

TASK7 = [
    ('query_dives_findings', 'query_dives_rating', FIELD,
     t('Safety findings', 'نتائج السلامة', 'Sicherheitsbefunde', 'Hallazgos de seguridad',
       'Constats de sécurité', 'ממצאי בטיחות', 'Biztonsági megállapítások',
       'Rilievi di sicurezza', 'Veiligheidsbevindingen', 'Constatações de segurança',
       '安全发现')),
    ('query_entity_findings', 'query_entity_equipmentAttributes', ENTITY,
     t('Safety findings', 'نتائج السلامة', 'Sicherheitsbefunde', 'Hallazgos de seguridad',
       'Constats de sécurité', 'ממצאי בטיחות', 'Biztonsági megállapítások',
       'Rilievi di sicurezza', 'Veiligheidsbevindingen', 'Constatações de segurança',
       '安全发现')),
    ('query_findings_rule', 'query_entity_equipmentAttributes', FIELD,
     t('Rule', 'القاعدة', 'Regel', 'Regla', 'Règle', 'כלל', 'Szabály', 'Regola', 'Regel',
       'Regra', '规则')),
]

keys = {'task6': TASK6, 'task7': TASK7}[sys.argv[1]]
for locale in LOCALES:
    path = ARB / f'app_{locale}.arb'
    lines = path.read_text(encoding='utf-8').split('\n')
    for key, anchor, desc, texts in reversed(keys):
        at = next(i for i, l in enumerate(lines)
                  if l.lstrip().startswith(f'"{anchor}"'))
        if at + 1 < len(lines) and lines[at + 1].lstrip().startswith(f'"@{anchor}"'):
            at += 1
        new = [f'  "{key}": {json.dumps(texts[locale], ensure_ascii=False)},']
        if locale == 'en':
            new.append(f'  "@{key}": {{"description": {json.dumps(desc)}}},')
        lines[at + 1:at + 1] = new
    text = '\n'.join(lines)
    json.loads(text)
    path.write_text(text, encoding='utf-8')
print('ok')
```

Run it, then regenerate:

```bash
LC_ALL=en_US.UTF-8 python3.14 "$TMPDIR/add_query_keys.py" task6
python3.14 scripts/gen_query_label_lookup.py
flutter gen-l10n
```

Expected: `ok`, and `git diff --stat lib/l10n/arb/*.arb` shows 12 insertions per locale (24 in English), no deletions.

- [ ] **Step 5: Label the enum values**

In `lib/features/query/presentation/app_query_labels.dart`, in `enumValue`'s `switch (field.labelKey)`, add directly before `case 'query_equipment_serviceDue':`:

```dart
      case 'query_dives_sacTrend':
      case 'query_dives_finalStop':
        return queryLabelForKey(_l10n, '${field.labelKey}_$value');
```

- [ ] **Step 6: Add a three-path parity case**

In `test/features/dive_log/query/dive_filter_three_paths_test.dart`, add to the `cases` map after `'typed text'`:

```dart
    'typed derived field': DiveFilterState(
      query: ConditionNode(
        FieldPath(['finalStop']),
        QueryOp.eq,
        const EnumValue('unstable'),
      ),
    ),
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/features/dive_log/query test/features/query test/l10n test/core/query`
Expected: `All tests passed!` This includes `query_registry_guards_test.dart` (the SQL compiles, `dive_tanks` and `dive_derived_metrics` are declared, no `?`, labels exist in every locale), `query_labels_test.dart` (the regenerated lookup), `app_query_registry_test.dart` (label convention) and `german_sac_terminology_test.dart`.

- [ ] **Step 8: Commit**

```bash
git add lib/features/dive_log/query/dive_query_entity.dart lib/features/query/presentation/app_query_labels.dart lib/features/query/presentation/query_label_lookup.dart lib/l10n/arb test/features/dive_log/query/dive_query_derived_fields_test.dart test/features/dive_log/query/dive_filter_three_paths_test.dart
git commit -m "feat(query): SAC, SAC trend and change, and final-stop fields on dives"
```

---

### Task 7: Safety findings as a relation on dives

**Files:**
- Modify: `lib/core/query/domain/query_subject.dart` (`findings`)
- Modify: `lib/features/dive_log/query/dive_child_query_entities.dart` (`findingQueryEntity`)
- Modify: `lib/features/dive_log/query/dive_query_entity.dart` (the `findings` relation)
- Modify: `lib/features/query/app_query_registry.dart` (register it)
- Modify: `lib/features/dive_log/presentation/widgets/safety_finding_text.dart` (`safetyRuleLabel`)
- Modify: `lib/features/query/presentation/app_query_labels.dart` (rule labels)
- Modify: `lib/l10n/arb/app_*.arb` (3 keys each)
- Test: `test/features/dive_log/query/dive_query_derived_fields_test.dart` (a findings group)
- Test: `test/features/dive_log/query/dive_filter_three_paths_test.dart` (one case)

**Interfaces:**
- Consumes: `SafetyRuleId` (`lib/features/dive_log/domain/entities/safety_finding.dart`), `SafetyReviewService.engineVersion` (`lib/features/dive_log/domain/services/safety_review_service.dart`).
- Produces: `QuerySubject.findings`; `findingQueryEntity` (table `dive_safety_findings`, field `rule`, enum values `SafetyRuleId.dbValue`); dive relation `findings` (alias `finding`); `String safetyRuleLabel(SafetyRuleId rule, AppLocalizations l10n)`; ARB keys `query_dives_findings`, `query_entity_findings`, `query_findings_rule`.

- [ ] **Step 1: Write the failing findings tests**

In `test/features/dive_log/query/dive_query_derived_fields_test.dart`, add the imports `import 'package:submersion/features/dive_log/domain/services/safety_review_service.dart';`, then add this group at the end of `main()`:

```dart
  group('safety findings', () {
    setUp(() async {
      Future<void> finding(
        String id,
        String diveId,
        String rule, {
        int? engine,
        int? dismissedAt,
      }) => db
          .into(db.diveSafetyFindings)
          .insert(
            DiveSafetyFindingsCompanion.insert(
              id: id,
              diveId: diveId,
              ruleId: rule,
              severity: 'caution',
              engineVersion: engine ?? SafetyReviewService.engineVersion,
              dismissedAt: Value(dismissedAt),
              createdAt: now,
            ),
          );
      await finding('f1', 'd1', 'rapidAscent');
      await finding('f2', 'd2', 'rapidAscent', dismissedAt: now);
      await finding('f3', 'd2', 'sawtoothProfile');
      await finding(
        'f4',
        'd3',
        'rapidAscent',
        engine: SafetyReviewService.engineVersion - 1,
      );
    });

    test('a rule matches only live findings of it', () async {
      // d2's is dismissed and d3's is from an older review engine.
      expect(await ids('findings.rule = rapidAscent'), {'d1'});
      expect(await ids('finding.rule = sawtoothProfile'), {'d2'});
    });

    test('no live finding is :none', () async {
      expect(await ids('findings:none'), {'d3', 'd4'});
      expect(await ids('NOT findings.rule = rapidAscent'), {'d2', 'd3', 'd4'});
    });
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/query/dive_query_derived_fields_test.dart`
Expected: FAIL, `ParseError(unknownField ...)` for `findings`.

- [ ] **Step 3: Add the subject, the entity, the relation**

In `lib/core/query/domain/query_subject.dart`, add after `siteTypes,`:

```dart

  /// A dive's safety review findings (#2195), a relation target of dives.
  findings,
```

In `lib/features/dive_log/query/dive_child_query_entities.dart`, add the import `import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';` and append:

```dart
/// A dive's safety review findings. Reached only through the dive relation
/// `findings`, which already leaves out dismissed findings and those from an
/// older review engine, so a finding here is one the diver still sees.
final findingQueryEntity = QueryEntity(
  subject: QuerySubject.findings,
  table: 'dive_safety_findings',
  fields: [
    QueryField(
      key: 'rule',
      type: FieldType.enumName,
      sql: '{r}.rule_id',
      emptySql: '{r}.rule_id IS NULL',
      labelKey: 'query_findings_rule',
      enumValues: [for (final r in SafetyRuleId.values) r.dbValue],
    ),
  ],
);
```

In `lib/features/dive_log/query/dive_query_entity.dart`, add the import `import 'package:submersion/features/dive_log/domain/services/safety_review_service.dart';` and add to `relations:`, directly after `_child('media', QuerySubject.media),`:

```dart
    // Live findings only: a dismissed finding is one the diver waved off,
    // and one from an older engine is replaced when the dive is next
    // reviewed.
    QueryRelation(
      key: 'findings',
      aliases: const ['finding'],
      target: QuerySubject.findings,
      shape: RelationShape.child,
      joinSql:
          '{to}.dive_id = {from}.id AND {to}.dismissed_at IS NULL '
          'AND {to}.engine_version >= ${SafetyReviewService.engineVersion}',
      isMany: true,
      labelKey: _label('findings'),
    ),
```

In `lib/features/query/app_query_registry.dart`, add `findingQueryEntity,` after `mediaQueryEntity,` (the import of `dive_child_query_entities.dart` is already there).

- [ ] **Step 4: Label the rules, reusing the safety settings names**

In `lib/features/dive_log/presentation/widgets/safety_finding_text.dart`, replace `safetyFindingShortLabel` with:

```dart
/// Localized rule name only (settings-page strings), for narrow contexts
/// like wide lane chips.
String safetyFindingShortLabel(SafetyFinding finding, AppLocalizations l10n) =>
    safetyRuleLabel(finding.ruleId, l10n);

/// A rule's name as the safety settings page shows it.
String safetyRuleLabel(SafetyRuleId rule, AppLocalizations l10n) {
  return switch (rule) {
    SafetyRuleId.rapidAscent => l10n.safetySettings_rule_rapidAscent,
    SafetyRuleId.missedDecoStop => l10n.safetySettings_rule_missedDecoStop,
    SafetyRuleId.omittedSafetyStop =>
      l10n.safetySettings_rule_omittedSafetyStop,
    SafetyRuleId.sawtoothProfile => l10n.safetySettings_rule_sawtoothProfile,
    SafetyRuleId.highSurfaceGf => l10n.safetySettings_rule_highSurfaceGf,
  };
}
```

In `lib/features/query/presentation/app_query_labels.dart`, add the imports for `safety_finding.dart` and `safety_finding_text.dart`, and add before `case 'query_equipment_serviceDue':`:

```dart
      case 'query_findings_rule':
        final rule = SafetyRuleId.fromDbValue(value);
        return rule == null ? value : safetyRuleLabel(rule, _l10n);
```

- [ ] **Step 5: Add the three labels**

```bash
LC_ALL=en_US.UTF-8 python3.14 "$TMPDIR/add_query_keys.py" task7
python3.14 scripts/gen_query_label_lookup.py
flutter gen-l10n
```

Expected: `ok`, 3 insertions per locale (6 in English).

- [ ] **Step 6: Add a three-path parity case**

In `test/features/dive_log/query/dive_filter_three_paths_test.dart`, add after the `'typed derived field'` case:

```dart
    'typed findings': DiveFilterState(
      query: ConditionNode(
        FieldPath(['findings', 'rule']),
        QueryOp.eq,
        const EnumValue('rapidAscent'),
      ),
    ),
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/features/dive_log test/features/query test/core/query test/l10n test/features/explore`
Expected: `All tests passed!` (`nl_prompt_test.dart` compares the vocabulary's subjects to `QuerySubject.values`, so it follows the new subject by itself).

- [ ] **Step 8: Commit**

```bash
git add lib/core/query/domain/query_subject.dart lib/features/dive_log/query/dive_child_query_entities.dart lib/features/dive_log/query/dive_query_entity.dart lib/features/query/app_query_registry.dart lib/features/dive_log/presentation/widgets/safety_finding_text.dart lib/features/query/presentation/app_query_labels.dart lib/features/query/presentation/query_label_lookup.dart lib/l10n/arb test/features/dive_log/query/dive_query_derived_fields_test.dart test/features/dive_log/query/dive_filter_three_paths_test.dart
git commit -m "feat(query): safety findings as a relation on dives"
```

---

### Task 8: Explore understands the new fields (query schema v2)

**Files:**
- Modify: `lib/features/explore/domain/dive_field_catalog.dart` (dimension, fields, specs)
- Modify: `lib/features/explore/domain/query_model.dart` (`kQuerySchemaVersion` 2, `ClauseUnit.barMin`/`psiMin`)
- Modify: `lib/features/explore/domain/unit_grounding.dart` (the rate)
- Modify: `lib/features/explore/domain/query_compiler.dart` (number fields, the band, the findings path)
- Modify: `lib/features/explore/domain/nl_engine.dart` (prompt)
- Modify: `lib/features/explore/presentation/chip_labeler.dart` (names, the rate, enum values)
- Test: `test/features/explore/domain/query_compiler_query_fields_test.dart`, `test/features/explore/domain/nl_prompt_test.dart`, `test/features/explore/presentation/chip_labeler_test.dart`
- Modify (schema version literals): `test/features/explore/data/channel_nl_engine_test.dart:41,45`, `test/features/explore/domain/query_compiler_test.dart:68,126,158,219,237,253,297,314`, `test/features/explore/domain/query_model_test.dart:8,84,191,199`, `test/features/explore/presentation/pages/explore_page_test.dart:52`, `test/features/explore/presentation/providers/explore_providers_test.dart:83,191,246,268,315`

**Interfaces:**
- Consumes: Tasks 6 and 7's registry fields and `findingQueryEntity`; `queryLabelForKey`; `safetyRuleLabel`; `UnitFormatter.formatSac`.
- Produces: `ExploreDiveField.sac`, `.sacTrend`, `.sacChange`, `.finalStop`, `.finalStopExcursion`, `.finalStopDuration`, `.finding`; Explore `FieldDimension.pressureRate`; `ClauseUnit.barMin` (`bar_min`), `ClauseUnit.psiMin` (`psi_min`); `kQuerySchemaVersion == 2`.

- [ ] **Step 1: Point the old tests at the constant**

The version moves to 2, so every hard-coded `1` in the files listed above becomes the constant. In Dart maps write `'schemaVersion': kQuerySchemaVersion`; in JSON string literals write `"schemaVersion":$kQuerySchemaVersion` (the literals are plain single-quoted strings, so interpolation works); add `import 'package:submersion/features/explore/domain/query_model.dart';` where a file lacks it. In `query_model_test.dart` line 84, the rejection test must reject both neighbours of the real version:

```dart
  test('rejects a wrong schema version', () {
    for (final wrong in [kQuerySchemaVersion - 1, kQuerySchemaVersion + 1]) {
      expect(
        () => ParsedQuery.fromJson(sample()..['schemaVersion'] = wrong),
        throwsA(isA<QuerySchemaException>()),
        reason: 'version $wrong',
      );
    }
  });
```

In `nl_prompt_test.dart` line 12, change `contains('"schemaVersion": 1')` to `contains('"schemaVersion": $kQuerySchemaVersion')`.

Run: `flutter test test/features/explore`
Expected: `All tests passed!` (nothing has changed version yet; this proves the literals are gone).

- [ ] **Step 2: Write the failing compiler, prompt and chip tests**

Append to `main()` in `test/features/explore/domain/query_compiler_query_fields_test.dart`:

```dart
  group('the derived fields', () {
    test('SAC is a rate grounded from the unit said', () {
      final q = compile([
        {...clause('sac', 'gt', 21.76), 'unit': 'psi_min'},
      ]);
      expect(q.unplaced, isEmpty);
      final bound = (q.filter.query! as ConditionNode).value as NumberValue;
      expect(bound.value, closeTo(1.5, 0.01));
    });

    test('exactly a SAC is a tenth either side', () {
      final q = compile([clause('sac', 'eq', 1.2)]);
      expect(
        q.filter.query,
        AndNode([
          cond('sac', QueryOp.gte, const NumberValue(1.15, null)),
          cond('sac', QueryOp.lte, const NumberValue(1.25, null)),
        ]),
      );
    });

    test('trend, change, stop, excursion and length', () {
      final q = compile([
        clause('sacTrend', 'eq', 'rising'),
        clause('sacChange', 'gt', 10),
        clause('finalStop', 'eq', 'unstable'),
        clause('finalStopExcursion', 'gt', 1),
        clause('finalStopDuration', 'gte', 3),
      ]);
      expect(q.unplaced, isEmpty);
      expect(
        q.filter.query,
        AndNode([
          cond('sacTrend', QueryOp.inList, ListValue(const [EnumValue('rising')])),
          cond('sacChange', QueryOp.gte, const NumberValue(10, null)),
          cond(
            'finalStop',
            QueryOp.inList,
            ListValue(const [EnumValue('unstable')]),
          ),
          cond('finalStopExcursion', QueryOp.gte, const NumberValue(1, null)),
          cond('finalStopDuration', QueryOp.gte, const NumberValue(3, null)),
        ]),
      );
    });

    test('a finding is a rule of any of the dive findings', () {
      final rule = ConditionNode(
        FieldPath(['findings', 'rule']),
        QueryOp.inList,
        ListValue(const [EnumValue('rapidAscent')]),
      );
      expect(compile([clause('finding', 'eq', 'rapidAscent')]).filter.query, rule);
      expect(
        compile([
          clause('finding', 'not', ['rapidAscent']),
        ]).filter.query,
        NotNode(rule),
      );
    });

    test('a change below minus 100 percent is out of range', () {
      expect(
        compile([clause('sacChange', 'lt', -150)]).unplaced.single.reason,
        'outOfRange',
      );
    });
  });
```

Append to `main()` in `test/features/explore/domain/nl_prompt_test.dart`:

```dart
  test('the cold-water example places SAC and the final stop', () {
    final text = NlPrompt.instructions();
    expect(text, contains('"field":"sacChange"'));
    expect(text, contains('"field":"finalStop","op":"eq","value":"unstable"'));
    // Only the minute mark stays unplaced: there is no N-minutes field.
    expect(text, contains('"unplaced":["after 20 minutes"]'));
    expect(text, contains('bar_min, psi_min'));
  });
```

Append to `main()` in `test/features/explore/presentation/chip_labeler_test.dart`:

```dart
  test('SAC reads in the diver pressure unit, findings by rule name', () {
    const sac = ClauseChip(
      field: ExploreDiveField.sac,
      op: ClauseOp.gte,
      value: 1.5,
      dimension: FieldDimension.pressureRate,
    );
    expect(metric.label(sac), contains('bar/min'));
    expect(imperial.label(sac), contains('psi/min'));
    expect(
      metric.label(
        chip(ExploreDiveField.finding, ['rapidAscent'], op: ClauseOp.inList),
      ),
      contains(l10n.safetySettings_rule_rapidAscent),
    );
    expect(
      metric.label(
        chip(ExploreDiveField.finalStop, ['unstable'], op: ClauseOp.inList),
      ),
      contains(l10n.query_dives_finalStop_unstable),
    );
  });
```

(`imperial` in that file must use `pressureUnit: PressureUnit.psi` for the second expectation; add it to the `AppSettings` there if it is missing.)

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/features/explore/domain/query_compiler_query_fields_test.dart test/features/explore/domain/nl_prompt_test.dart test/features/explore/presentation/chip_labeler_test.dart`
Expected: compilation FAIL, `Member not found: 'sac'` on `ExploreDiveField`.

- [ ] **Step 4: The catalog, the units and the version**

In `lib/features/explore/domain/dive_field_catalog.dart`:
- Add `pressureRate,` after `pressure,` in `enum FieldDimension`.
- Change the enum comment "schema v1" to "schema v2".
- Replace `diveType('diveType');` with:

```dart
  diveType('diveType'),
  sac('sac'),
  sacTrend('sacTrend'),
  sacChange('sacChange'),
  finalStop('finalStop'),
  finalStopExcursion('finalStopExcursion'),
  finalStopDuration('finalStopDuration'),
  finding('finding');
```

- Add `import 'package:submersion/features/dive_log/query/dive_child_query_entities.dart';`, and add to `_specs` after the `diveType` entry:

```dart
    ExploreDiveField.sac: const FieldSpec(
      dimension: FieldDimension.pressureRate,
      valueType: FieldValueType.number,
      ops: _ordering,
    ),
    ExploreDiveField.sacTrend: FieldSpec(
      dimension: FieldDimension.none,
      valueType: FieldValueType.enumName,
      ops: _membership,
      enumValues: _registryValues('sacTrend'),
    ),
    ExploreDiveField.sacChange: const FieldSpec(
      dimension: FieldDimension.percent,
      valueType: FieldValueType.number,
      ops: _ordering,
    ),
    ExploreDiveField.finalStop: FieldSpec(
      dimension: FieldDimension.none,
      valueType: FieldValueType.enumName,
      ops: _membership,
      enumValues: _registryValues('finalStop'),
    ),
    ExploreDiveField.finalStopExcursion: _depth,
    ExploreDiveField.finalStopDuration: const FieldSpec(
      dimension: FieldDimension.minutes,
      valueType: FieldValueType.number,
      ops: _ordering,
    ),
    // The rule of any of the dive's live findings.
    ExploreDiveField.finding: FieldSpec(
      dimension: FieldDimension.none,
      valueType: FieldValueType.enumName,
      ops: _membership,
      enumValues: findingQueryEntity.field('rule')!.enumValues!,
    ),
```

In `lib/features/explore/domain/query_model.dart`: change `const int kQuerySchemaVersion = 1;` to `2`, and replace `cuftMin('cuft_min');` with:

```dart
  cuftMin('cuft_min'),
  barMin('bar_min'),
  psiMin('psi_min');
```

In `lib/features/explore/domain/unit_grounding.dart`, add after the `case FieldDimension.pressure:` block:

```dart
    case FieldDimension.pressureRate:
      final from = switch (unit) {
        ClauseUnit.barMin => PressureUnit.bar,
        ClauseUnit.psiMin => PressureUnit.psi,
        _ => prefs.pressure,
      };
      return from.convert(v, PressureUnit.bar);
```

- [ ] **Step 5: Lower the fields**

In `lib/features/explore/domain/query_compiler.dart`:

Add to `_numberQueryFields`:

```dart
  ExploreDiveField.sac,
  ExploreDiveField.sacChange,
  ExploreDiveField.finalStopExcursion,
  ExploreDiveField.finalStopDuration,
```

In `_lowerNumber`, replace the `case ClauseOp.eq:` body:

```dart
          // A measured depth or temperature is almost never exactly the
          // number said, so "exactly 15 m" is the half unit either side of
          // it in the unit the diver used, the way it would be rounded.
          final continuous =
              spec.dimension == FieldDimension.depth ||
              spec.dimension == FieldDimension.temperature;
          lo = continuous ? ground(raw - 0.5) : v;
          hi = continuous ? ground(raw + 0.5) : v;
```

with:

```dart
          // A measured value is almost never exactly the number said, so
          // "exactly 15 m" is the half unit either side of it in the unit
          // the diver used, the way it would be rounded. SAC is read to a
          // tenth, so "a SAC of 1.2" is 1.15 to 1.25. Counts stay exact.
          final half = switch (spec.dimension) {
            FieldDimension.depth || FieldDimension.temperature => 0.5,
            FieldDimension.pressureRate => 0.05,
            _ => 0.0,
          };
          lo = half == 0 ? v : ground(raw - half);
          hi = half == 0 ? v : ground(raw + half);
```

In `_enumCondition`, replace `FieldPath([key]),` with `FieldPath(_enumPath(field, key)),` and add below the method:

```dart
  /// The registry path an enum field lowers onto: the dive field of its own
  /// name, or for a safety finding the rule of any of the dive's findings.
  static List<String> _enumPath(ExploreDiveField field, String key) =>
      field == ExploreDiveField.finding ? const ['findings', 'rule'] : [key];
```

- [ ] **Step 6: The prompt**

In `lib/features/explore/domain/nl_engine.dart`, in `instructions()`:
- Shape line: replace `{"schemaVersion": 1, "subject"` with `{"schemaVersion": $kQuerySchemaVersion, "subject"`.
- Fields paragraph: replace `diveType: the name of a dive type.` with:

```text
diveType: the name of a dive type. sac: gas consumption rate, as pressure per minute at the surface. sacTrend: whether gas consumption was ${_oneOf(ExploreDiveField.sacTrend)} through the dive. sacChange: percent change in gas consumption from the first half of the dive to the second; a rise is a positive number. finalStop: ${_oneOf(ExploreDiveField.finalStop)}, for the last safety or decompression stop. finalStopExcursion: how far the diver drifted from the depth of the last stop. finalStopDuration: minutes spent at the last stop. finding: a safety finding, ${_oneOf(ExploreDiveField.finding)}.
```

- Units line: replace `unit is one of: m, ft, c, f, bar, psi, min, l_min, cuft_min.` with `unit is one of: ${ClauseUnit.values.map((u) => u.jsonName).join(', ')}.`
- Examples 1 and 3: replace `{"schemaVersion":1,` with `{"schemaVersion":$kQuerySchemaVersion,`.
- Example 2: replace its JSON line with:

```text
{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","clauses":[{"field":"waterTemp","op":"lt","value":15,"unit":"c","text":"cold-water"},{"field":"sacChange","op":"gt","value":10,"text":"SAC increased"},{"field":"finalStop","op":"eq","value":"unstable","text":"the final stop was unstable"}],"mentions":[{"kind":"gear","text":"trilaminate suit"}],"time":null,"unplaced":["after 20 minutes"]}
```

- [ ] **Step 7: The chip words**

In `lib/features/explore/presentation/chip_labeler.dart`, add the imports `import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';`, `import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_text.dart';` and `import 'package:submersion/features/query/presentation/query_label_lookup.dart';`.

In `fieldName`, add after the `diveType` case:

```dart
    ExploreDiveField.sac => queryLabelForKey(l10n, 'query_dives_sac'),
    ExploreDiveField.sacTrend => queryLabelForKey(l10n, 'query_dives_sacTrend'),
    ExploreDiveField.sacChange => queryLabelForKey(l10n, 'query_dives_sacChange'),
    ExploreDiveField.finalStop => queryLabelForKey(l10n, 'query_dives_finalStop'),
    ExploreDiveField.finalStopExcursion =>
      queryLabelForKey(l10n, 'query_dives_finalStopExcursion'),
    ExploreDiveField.finalStopDuration =>
      queryLabelForKey(l10n, 'query_dives_finalStopDuration'),
    ExploreDiveField.finding => queryLabelForKey(l10n, 'query_dives_findings'),
```

In `_value`, add after the pressure case:

```dart
    FieldDimension.pressureRate => units.formatSac(v),
```

In `_enumValue`, add before `_ => v,`:

```dart
    ExploreDiveField.sacTrend || ExploreDiveField.finalStop =>
      queryLabelForKey(l10n, 'query_dives_${field.jsonName}_$v'),
    ExploreDiveField.finding => switch (SafetyRuleId.fromDbValue(v)) {
      final rule? => safetyRuleLabel(rule, l10n),
      null => v,
    },
```

- [ ] **Step 8: Run the Explore tests and measure the prompt**

Run: `flutter test test/features/explore`
Expected: `All tests passed!`, including `nl_prompt_test.dart`'s `text.length < 7000` (the template was 3,337 characters before this task; if the budget is exceeded, shorten the field descriptions, never the examples) and `chip_labeler_test.dart`'s "every catalog field has a label" and "every catalog enum value has a label", which now cover the seven new fields.

- [ ] **Step 9: Commit**

```bash
git add lib/features/explore test/features/explore
git commit -m "feat(explore): SAC, final-stop and finding clauses, query schema v2"
```

---

### Task 9: A SAC chart for a SAC clause

**Files:**
- Modify: `lib/features/explore/domain/chart_selection.dart` (`ChartKind.sacTrend`)
- Modify: `lib/features/explore/presentation/providers/explore_providers.dart` (the chart query)
- Modify: `lib/features/explore/presentation/widgets/explore_charts.dart` (title, formatters)
- Test: `test/features/explore/domain/chart_selection_test.dart`, `test/features/explore/presentation/widgets/explore_charts_test.dart`

**Interfaces:**
- Consumes: `InsightsRepository.getSacPressurePerDive({String? diverId, DiveFilterState filter})` (bar/min per dive, the same formula as the `sac` field).
- Produces: `ChartKind.sacTrend`.

- [ ] **Step 1: Write the failing tests**

Append to `main()` in `test/features/explore/domain/chart_selection_test.dart`:

```dart
  test('a SAC clause draws a SAC chart', () {
    expect(
      selectCharts(
        numericFields: const [ExploreDiveField.sac],
        resolvedEntityCounts: const {},
      ),
      contains(const ChartRequest(ChartKind.sacTrend)),
    );
  });
```

Append to `main()` in `test/features/explore/presentation/widgets/explore_charts_test.dart`:

```dart
  testWidgets('the SAC chart is titled SAC and reads per minute', (
    tester,
  ) async {
    await pump(
      tester,
      [const ChartRequest(ChartKind.sacTrend)],
      data: ExploreChartData(
        points: [TrendDataPoint(date: DateTime(2025, 6, 1), value: 1.2)],
      ),
    );
    expect(find.text(en.query_dives_sac), findsOneWidget);
    expect(find.byType(DiveTrendChart), findsOneWidget);
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/explore/domain/chart_selection_test.dart test/features/explore/presentation/widgets/explore_charts_test.dart`
Expected: compilation FAIL, `Member not found: 'sacTrend'` on `ChartKind`.

- [ ] **Step 3: Add the chart**

In `lib/features/explore/domain/chart_selection.dart`, add `sacTrend,` after `bottomTimeTrend,` in `enum ChartKind`, and add to the `trends` map:

```dart
    ExploreDiveField.sac: ChartKind.sacTrend,
```

In `lib/features/explore/presentation/providers/explore_providers.dart`, add to the `switch (request.kind)` in `exploreChartDataProvider`, after the `bottomTimeTrend` case:

```dart
        case ChartKind.sacTrend:
          return ExploreChartData(
            points: await stats.getSacPressurePerDive(
              diverId: diverId,
              filter: filter,
            ),
          );
```

In `lib/features/explore/presentation/widgets/explore_charts.dart`, add the import `import 'package:submersion/features/query/presentation/query_label_lookup.dart';`, then:
- In the `title` switch: `ChartKind.sacTrend => queryLabelForKey(l10n, 'query_dives_sac'),`
- In `valueFormatter`: `ChartKind.sacTrend => units.formatSac(v),`
- In `yAxisFormatter`: `ChartKind.sacTrend => units.convertSac(v).toStringAsFixed(1),`

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/explore`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/explore test/features/explore
git commit -m "feat(explore): a SAC chart when the sentence asks about SAC"
```

---

### Task 10: Specs, whole-project verification and the PR

**Files:**
- Modify: `docs/superpowers/specs/2026-09-19-explore-natural-language-search-design.md` (a deviations section)
- Modify: `docs/superpowers/specs/2026-09-25-entity-query-language-design.md` (the Explore note)
- Modify: `docs/superpowers/plans/2026-09-20-explore-phase2-derived-predicates.md` (a superseded line)

- [ ] **Step 1: Record the deviations**

Append to the Explore spec:

```markdown
## Deviations recorded during implementation (phase 2, 2026-09-28)

Phase 2 was rebuilt on main after the entity query language (#2365) made
every dive surface compile one query tree. The profile-derived predicates
became fields on the dive query registry, so the typed syntax, the rule
builder, the dive list and Explore all get them.

- One table, `dive_derived_metrics` (schema v247), device-local with no hlc.
  No `dive_sac_buckets`: a registry field's SQL cannot take a diver-chosen
  N, so "SAC before versus after N minutes" became `sacTrend` (rising,
  steady, falling; slope band 0.02 bar/min per minute) and `sacChange`
  (percent, first half of the dive against the second). Explore leaves the
  "after N minutes" words unplaced.
- `sac` is searchable in the diver's pressure unit through a new
  pressure-rate dimension (`barmin`, `psimin`). It uses the formula the
  Insights SAC chart plots, not the engine's bucketed mean, so a search and
  the chart agree.
- `finalStop` is an enum (stable, unstable over 1.0 m from the median,
  noStop), with `finalStopExcursion` (a depth) and `finalStopDuration`
  (minutes) beside it. Null when the profile could not be judged.
- Safety findings are the relation `findings` over `dive_safety_findings`,
  live findings only (not dismissed, current review engine).
- The engine computes SAC itself from the decoded samples and the richest
  pressure series per tank, as the phase 2 branch did: the isolate has no
  hydrated `Dive`. Constants: 7.0 m, 60 s, a 1.5 m level window, 300 s
  buckets; a bucket where pressure rises is skipped.
- Explore stays on `DiveFilterState` and lowers the new clauses into its
  query tree; query schema version 2. Replacing `ExploreDiveField` with the
  registry remains query-language PR 5.
```

In the entity query language spec, after the paragraph at lines 277-285 that says the derived predicates register in PR 5, add:

```markdown
Update (2026-09-28): Explore phase 2 registered them first, as dive fields
over the stored table `dive_derived_metrics` (`sacTrend`, `sacChange`,
`finalStop`, `finalStopExcursion`, `finalStopDuration`), plus `sac` and the
`findings` relation; `derivedPredicateCondition` was never built. PR 5 takes
them as given.
```

At the top of `docs/superpowers/plans/2026-09-20-explore-phase2-derived-predicates.md`, under the title, add:

```markdown
> **Superseded** by `2026-09-28-explore-phase2-registry-fields.md`: this plan's filter wiring predates the entity query language.
```

- [ ] **Step 2: Verify the whole project**

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
scripts/run_all_tests.sh
```

Expected: no files changed, `No issues found!`, and every test passing. If `scripts/run_all_tests.sh` is absent, run `flutter test` and read its last line. Check the ARB diff once more: `git diff --stat origin/main -- lib/l10n/arb/*.arb` shows only insertions.

- [ ] **Step 3: Capture the screenshots**

The PR changes what the diver sees (rule-builder fields and the `bar/min` suffix, Explore chips, the SAC chart), so it needs after screenshots (these are new, so no before): the rule-builder field picker showing the new fields, a `sac` number field with its `bar/min` and `psi/min` suffix, Explore chips for "SAC over 1.5" and "unstable final stop", and the SAC chart; light and dark. Capture them with a throwaway golden test (`matchesGoldenFile` plus `--update-goldens`, font loaded in `setUpAll`), keep the PNGs out of the commit, and hand them to Eric.

- [ ] **Step 4: Commit, push, open the PR**

```bash
git add docs/superpowers/specs/2026-09-19-explore-natural-language-search-design.md docs/superpowers/specs/2026-09-25-entity-query-language-design.md docs/superpowers/plans/2026-09-20-explore-phase2-derived-predicates.md
git commit -m "docs(explore): phase 2 as registry fields, and what that leaves to PR 5"
git push -u origin ericgriffin/explore-phase2-registry-2195
```

Open the PR against `main` with a body in the repository template: `Refs #2195` under Related Issue; a Summary of the fields and the rung; Changes as the task list; the Test Plan; the Screenshots section listing what each image shows (they are dragged in on github.com). No attribution lines.
