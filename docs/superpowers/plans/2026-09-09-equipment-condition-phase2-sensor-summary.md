# Equipment Condition Intelligence, Phase 2: Sensor Summary

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fill the `dive_sensor_summaries` table that phase 1 created: a pure service turns a dive's primary profile and tank pressure series into per-slot O2 cell metrics, per-tank transmitter gap figures, scrubber consumption and the profile extremes; a repository computes it once per dive version on an isolate; a sweep, a fire-and-forget scheduler and a settings action keep every dive current; and the profile chart shades cell divergence ranges when the O2 cell overlay is on.

**Architecture:** Nothing in this phase decodes a profile except the isolate worker. The repository reads the dive scalars, the primary series blobs and the tank series blobs, hands them to `computeSensorSummaryFromBlobs` through `compute`, and upserts one row keyed by dive. Staleness is `engine_version` plus `source_updated_at` against `dives.updated_at`, which every save, download and re-parse already bumps. `diveSensorSummaryProvider(diveId)` is a compute-through-cache family like `safetyReviewProvider`; `EquipmentConditionSweep` mirrors `SafetyReviewSweep`; `SensorSummaryScheduler` mirrors `QualityScanScheduler` and is called beside every `scheduleQualityScan` call plus the re-parse service. The exposure query from phase 1 already left-joins the table, so clocks pick up profile depth and temperature the moment rows exist.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, `compute` isolates, fl_chart, flutter_localizations with ARB files (11 locales), flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-09-equipment-condition-intelligence-design.md` (sections Architecture, Data model for `dive_sensor_summaries`, Sensor summary, Surfaces: dive profile chart). This plan is phase 2 of four.

**Decisions taken for this phase (asked and answered 2026-09-09):** stacked PRs, one per phase, phase 2 branches from main; inline execution; one plan per phase written just before building it; existing libraries are backfilled by a background sweep at startup plus a manual "Rebuild sensor summaries" action in the Equipment condition settings section; the refresh hook is its own scheduler called beside each quality-scan call; the chart gains a list of secondary highlight ranges and keeps the single selected-finding range.

## Global Constraints

- No em-dashes anywhere (code, comments, commit messages, ARB strings). Rewrite the sentence instead.
- No mention of Claude, Claude Code or Anthropic in any commit, comment, file or PR body.
- Run `dart format .` before every commit. The pre-push hook runs format, analyze, l10n staleness and tests.
- TDD: write the failing test first, run it, watch it fail, then implement.
- Every user-facing string goes through `context.l10n` and is added to all 11 ARB files (`lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`). Only `app_en.arb` is alphabetical; in the other ten files insert each key next to the same neighbouring key it sits beside in English. Regenerate with `flutter gen-l10n` after editing ARB files. Key style is `section_camelCase`, matching phase 1 (`equipmentConditionSettings_title`).
- Anything displaying units respects the active diver's unit settings (`UnitFormatter`). This phase displays no unit values; stored values stay metric (Celsius, metres, bar, seconds).
- **No schema rung.** `dive_sensor_summaries` exists since v202 (`lib/core/database/database.dart:3148`). `currentSchemaVersion` stays at 203. Do not touch the migration.
- Profile blobs are decoded only inside `computeSensorSummaryFromBlobs`. No other new code calls a codec.
- The word `build` alone in a Bash command can be refused by the harness's read-deny rule. If `dart run build_runner build --delete-conflicting-outputs` is refused, write it into a script under the scratchpad directory and run that script. This phase needs no codegen unless `database.dart` is touched, and it is not.
- Commit after every task with the message given in the task. Never `git add -A`; stage the listed paths.
- Tests that run `compute` need `TestWidgetsFlutterBinding.ensureInitialized()` at the top of `main`.
- Every new regression test is run once against the code before the implementation lands, to prove it fails.

## File structure

New files:

| File | Responsibility |
| --- | --- |
| `lib/features/equipment/domain/entities/dive_sensor_summary.dart` | `DiveSensorSummary`, `CellMetrics`, `DivergenceRange`, `TransmitterGap` value objects and their JSON codecs |
| `lib/features/equipment/domain/services/dive_sensor_summary_service.dart` | Pure `DiveSensorSummaryService` (`version = 1`): extremes, scrubber, cell metrics, transmitter gaps |
| `lib/features/equipment/data/services/sensor_summary_worker.dart` | `SensorSummaryWorkInput`, `TankSeriesBlob`, top-level `computeSensorSummaryFromBlobs` for `compute` |
| `lib/features/equipment/data/repositories/dive_sensor_summary_repository.dart` | Read, upsert, staleness query and `ensureCurrent` compute-through-cache |
| `lib/features/equipment/data/services/sensor_summary_scheduler.dart` | `SensorSummaryScheduler` singleton, `scheduleSensorSummaryRefresh`, stale sweep |
| `lib/features/equipment/presentation/providers/dive_sensor_summary_providers.dart` | `diveSensorSummaryRepositoryProvider`, `diveSensorSummaryProvider` |
| `lib/features/equipment/presentation/providers/equipment_condition_sweep.dart` | `EquipmentConditionSweep`, `EquipmentConditionSweepResult`, provider |
| `lib/features/dive_log/presentation/widgets/cell_divergence_highlight.dart` | Maps a summary's divergence ranges to `ProfileHighlightRange`s |
| `test/features/equipment/domain/entities/dive_sensor_summary_test.dart` | JSON codec round-trips and tolerance |
| `test/features/equipment/domain/services/dive_sensor_summary_service_test.dart` | Extremes, scrubber, gain, divergence, ranges, current limiting, gaps |
| `test/features/equipment/data/services/sensor_summary_worker_test.dart` | Blob decode, merge of several primary blobs, unreadable blob skipped |
| `test/features/equipment/data/repositories/dive_sensor_summary_repository_test.dart` | Compute-through-cache, staleness, cascade, stale id query |
| `test/features/equipment/data/services/sensor_summary_scheduler_test.dart` | Single-flight refresh and stale sweep |
| `test/features/equipment/presentation/providers/dive_sensor_summary_providers_test.dart` | Provider returns the row and refreshes on a dive tick |
| `test/features/equipment/presentation/providers/equipment_condition_sweep_test.dart` | Progress, cancel, failure counting, force |
| `test/features/dive_log/presentation/widgets/cell_divergence_highlight_test.dart` | Mapping helper |
| `test/features/dive_log/presentation/widgets/dive_profile_chart_secondary_ranges_test.dart` | Bands appear only with the O2 cell overlay on |

Modified files: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (detail-change stream), `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`, `lib/features/dive_log/presentation/widgets/dive_profile_chart_host.dart`, `lib/features/settings/presentation/pages/equipment_condition_settings_page.dart`, `lib/app.dart`, `lib/features/backup/presentation/providers/backup_providers.dart`, `lib/features/dive_computer/data/services/reparse_service.dart`, `lib/features/import_wizard/data/adapters/{dive_computer,suunto_cloud,garmin_cloud,healthkit,universal}_adapter.dart`, `lib/features/dive_log/presentation/pages/{dive_edit_page,dive_detail_page}.dart`, `lib/features/dive_log/presentation/widgets/run_dive_consolidation.dart`, `test/flutter_test_config.dart`, `test/features/settings/presentation/pages/equipment_condition_settings_page_test.dart`, the 11 ARB files.

---

### Task 0: Worktree preflight

**Files:** none modified.

- [ ] **Step 1: Confirm the branch and its base**

```bash
git branch --show-current
git merge-base --is-ancestor origin/main HEAD && echo "on main"
```

Expected: `ericgriffin/equipment-condition-phase2-sensor-summary`, `on main`.

- [ ] **Step 2: Confirm the worktree is initialised**

```bash
git submodule update --init --recursive && flutter pub get
```

- [ ] **Step 3: Confirm the baseline analyzes clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Confirm the table and the phase 1 join are present**

```bash
grep -n "class DiveSensorSummaries" lib/core/database/database.dart
grep -n "LEFT JOIN dive_sensor_summaries" lib/features/equipment/data/repositories/equipment_repository_impl.dart
grep -n "currentSchemaVersion = " lib/core/database/database.dart
```

Expected: one hit each; the version line reads `203`.

---

### Task 1: Sensor summary value objects and JSON codecs

**Files:**
- Create: `lib/features/equipment/domain/entities/dive_sensor_summary.dart`
- Test: `test/features/equipment/domain/entities/dive_sensor_summary_test.dart`

**Interfaces:**
- Produces: `DivergenceRange`, `CellMetrics`, `TransmitterGap`, `DiveSensorSummary`, `encodeCellMetrics`, `decodeCellMetrics`, `encodeTransmitterGaps`, `decodeTransmitterGaps` (used by Tasks 2 to 12).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/domain/entities/dive_sensor_summary_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';

void main() {
  group('CellMetrics json', () {
    const metrics = CellMetrics(
      slot: 2,
      samples: 1840,
      gainMvPerBar: 51.3,
      p95DivergenceBar: 0.04,
      highPpO2Samples: 612,
      lowAtHighFraction: 0.0,
      divergenceRanges: [
        DivergenceRange(startSeconds: 1260, endSeconds: 1410, peakBar: 0.14),
      ],
    );

    test('round-trips through the stored column shape', () {
      final json = encodeCellMetrics([metrics]);
      expect(
        json,
        '[{"slot":2,"samples":1840,"gainMvPerBar":51.3,"p95DivergenceBar":0.04,'
        '"highPpO2Samples":612,"lowAtHighFraction":0.0,'
        '"divergenceRanges":[[1260,1410,0.14]]}]',
      );
      expect(decodeCellMetrics(json), [metrics]);
    });

    test('nullable fields survive as null', () {
      const gainOnly = CellMetrics(slot: 1, samples: 10, gainMvPerBar: 48.0);
      expect(decodeCellMetrics(encodeCellMetrics([gainOnly])), [gainOnly]);
      expect(gainOnly.p95DivergenceBar, isNull);
      expect(gainOnly.lowAtHighFraction, isNull);
      expect(gainOnly.divergenceRanges, isEmpty);
    });

    test('tolerates the column default and malformed text', () {
      expect(decodeCellMetrics('[]'), isEmpty);
      expect(decodeCellMetrics(''), isEmpty);
      expect(decodeCellMetrics('not json'), isEmpty);
      expect(decodeCellMetrics('{"slot":1}'), isEmpty);
    });
  });

  group('TransmitterGap json', () {
    const gap = TransmitterGap(
      tankId: 't1',
      transmitterSerial: '180777',
      computerId: 'c1',
      cadenceSeconds: 10,
      gapSeconds: 130,
      gapCount: 3,
      longestGapSeconds: 80,
      diveSeconds: 3480,
    );

    test('round-trips and exposes the gap fraction', () {
      expect(decodeTransmitterGaps(encodeTransmitterGaps([gap])), [gap]);
      expect(gap.gapFraction, closeTo(130 / 3480, 1e-9));
    });

    test('a zero-length dive has a zero fraction, never a division error', () {
      const empty = TransmitterGap(
        tankId: 't1',
        cadenceSeconds: 10,
        gapSeconds: 0,
        gapCount: 0,
        longestGapSeconds: 0,
        diveSeconds: 0,
      );
      expect(empty.gapFraction, 0);
      expect(decodeTransmitterGaps(encodeTransmitterGaps([empty])), [empty]);
    });

    test('tolerates the column default and malformed text', () {
      expect(decodeTransmitterGaps('[]'), isEmpty);
      expect(decodeTransmitterGaps('garbage'), isEmpty);
    });
  });

  test('DiveSensorSummary is a value object', () {
    final a = DiveSensorSummary(
      diveId: 'd1',
      engineVersion: 1,
      sourceUpdatedAt: 5,
      computedAt: DateTime.utc(2026, 9, 9),
      minTemperature: 4.0,
      maxDepth: 41.2,
      scrubberConsumedMinutes: 95,
    );
    final b = DiveSensorSummary(
      diveId: 'd1',
      engineVersion: 1,
      sourceUpdatedAt: 5,
      computedAt: DateTime.utc(2026, 9, 9),
      minTemperature: 4.0,
      maxDepth: 41.2,
      scrubberConsumedMinutes: 95,
    );
    expect(a, b);
    expect(a.cellMetrics, isEmpty);
    expect(a.transmitterGaps, isEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/domain/entities/dive_sensor_summary_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 3: Write the entity file**

```dart
// lib/features/equipment/domain/entities/dive_sensor_summary.dart
import 'dart:convert';

import 'package:equatable/equatable.dart';

/// A contiguous run where one O2 cell disagreed with the median of its
/// peers by more than the divergence threshold. Seconds are profile
/// seconds, so the chart can draw the run directly.
class DivergenceRange extends Equatable {
  final int startSeconds;
  final int endSeconds;

  /// The largest absolute divergence inside the run, in bar.
  final double peakBar;

  const DivergenceRange({
    required this.startSeconds,
    required this.endSeconds,
    required this.peakBar,
  });

  int get durationSeconds => endSeconds - startSeconds;

  /// Stored as `[start, end, peak]`, the spec's compact shape.
  List<num> toJson() => [startSeconds, endSeconds, peakBar];

  static DivergenceRange? fromJson(Object? json) {
    if (json is! List || json.length < 3) return null;
    final start = json[0];
    final end = json[1];
    final peak = json[2];
    if (start is! num || end is! num || peak is! num) return null;
    return DivergenceRange(
      startSeconds: start.toInt(),
      endSeconds: end.toInt(),
      peakBar: peak.toDouble(),
    );
  }

  @override
  List<Object?> get props => [startSeconds, endSeconds, peakBar];
}

/// What one O2 cell slot did on one dive. One entry per slot that carried
/// ppO2 data; a slot the computer never reported is absent, not zeroed.
class CellMetrics extends Equatable {
  /// 1-based slot number, matching `o2Sensor1` to `o2Sensor6`.
  final int slot;

  /// Samples with a ppO2 reading for this slot, so every sentence built
  /// from these numbers can state its n.
  final int samples;

  /// Median of mV over ppO2 for the slot's own reading, in mV per bar.
  /// Null when the profile carries no millivolts for the slot.
  final double? gainMvPerBar;

  /// 95th percentile of the absolute difference between this slot and the
  /// median of all slots with data, in bar. Null when fewer than two slots
  /// ever carried data at the same sample.
  final double? p95DivergenceBar;

  /// Samples where the median ppO2 exceeded the current-limit line.
  final int highPpO2Samples;

  /// Of [highPpO2Samples], the fraction where this slot read more than the
  /// current-limit margin below the median. Null when the slot did not
  /// agree with its peers at low ppO2 on this dive, or when there were no
  /// high-ppO2 samples, so the figure is never quoted without its basis.
  final double? lowAtHighFraction;

  final List<DivergenceRange> divergenceRanges;

  const CellMetrics({
    required this.slot,
    required this.samples,
    this.gainMvPerBar,
    this.p95DivergenceBar,
    this.highPpO2Samples = 0,
    this.lowAtHighFraction,
    this.divergenceRanges = const [],
  });

  Map<String, Object?> toJson() => {
    'slot': slot,
    'samples': samples,
    'gainMvPerBar': gainMvPerBar,
    'p95DivergenceBar': p95DivergenceBar,
    'highPpO2Samples': highPpO2Samples,
    'lowAtHighFraction': lowAtHighFraction,
    'divergenceRanges': [for (final r in divergenceRanges) r.toJson()],
  };

  static CellMetrics? fromJson(Object? json) {
    if (json is! Map) return null;
    final slot = json['slot'];
    final samples = json['samples'];
    if (slot is! num || samples is! num) return null;
    final ranges = json['divergenceRanges'];
    return CellMetrics(
      slot: slot.toInt(),
      samples: samples.toInt(),
      gainMvPerBar: _double(json['gainMvPerBar']),
      p95DivergenceBar: _double(json['p95DivergenceBar']),
      highPpO2Samples: (json['highPpO2Samples'] as num?)?.toInt() ?? 0,
      lowAtHighFraction: _double(json['lowAtHighFraction']),
      divergenceRanges: ranges is List
          ? [for (final r in ranges) ?DivergenceRange.fromJson(r)]
          : const [],
    );
  }

  @override
  List<Object?> get props => [
    slot,
    samples,
    gainMvPerBar,
    p95DivergenceBar,
    highPpO2Samples,
    lowAtHighFraction,
    divergenceRanges,
  ];
}

/// How reliably one tank's transmitter reported during one dive.
class TransmitterGap extends Equatable {
  final String tankId;

  /// Normalised transmitter serial from the dive tank, or null when the
  /// computer logged none. Phase 3 maps it to a transmitter item.
  final String? transmitterSerial;
  final String? computerId;

  /// Median interval between consecutive pressure samples, seconds.
  final double cadenceSeconds;

  /// Seconds inside gaps (intervals longer than three cadences, plus the
  /// spans of the profile the series never covered).
  final int gapSeconds;
  final int gapCount;
  final int longestGapSeconds;

  /// Seconds the dive spans, the denominator of [gapFraction].
  final int diveSeconds;

  const TransmitterGap({
    required this.tankId,
    this.transmitterSerial,
    this.computerId,
    required this.cadenceSeconds,
    required this.gapSeconds,
    required this.gapCount,
    required this.longestGapSeconds,
    required this.diveSeconds,
  });

  double get gapFraction => diveSeconds <= 0 ? 0 : gapSeconds / diveSeconds;

  Map<String, Object?> toJson() => {
    'tankId': tankId,
    'transmitterSerial': transmitterSerial,
    'computerId': computerId,
    'cadenceSeconds': cadenceSeconds,
    'gapSeconds': gapSeconds,
    'gapCount': gapCount,
    'longestGapSeconds': longestGapSeconds,
    'diveSeconds': diveSeconds,
  };

  static TransmitterGap? fromJson(Object? json) {
    if (json is! Map) return null;
    final tankId = json['tankId'];
    final cadence = json['cadenceSeconds'];
    if (tankId is! String || cadence is! num) return null;
    return TransmitterGap(
      tankId: tankId,
      transmitterSerial: json['transmitterSerial'] as String?,
      computerId: json['computerId'] as String?,
      cadenceSeconds: cadence.toDouble(),
      gapSeconds: (json['gapSeconds'] as num?)?.toInt() ?? 0,
      gapCount: (json['gapCount'] as num?)?.toInt() ?? 0,
      longestGapSeconds: (json['longestGapSeconds'] as num?)?.toInt() ?? 0,
      diveSeconds: (json['diveSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    tankId,
    transmitterSerial,
    computerId,
    cadenceSeconds,
    gapSeconds,
    gapCount,
    longestGapSeconds,
    diveSeconds,
  ];
}

/// One `dive_sensor_summaries` row: everything a profile decode can tell
/// the condition engine about one dive, computed once per dive version.
class DiveSensorSummary extends Equatable {
  final String diveId;
  final int engineVersion;

  /// The dive's `updated_at` when computed. A mismatch means stale.
  final int sourceUpdatedAt;
  final DateTime computedAt;

  /// Profile minimum, Celsius. Null when the profile carries no temperature.
  final double? minTemperature;

  /// Profile maximum, metres. Null when the dive has no profile.
  final double? maxDepth;

  /// Scrubber minutes consumed on this dive; see
  /// `DiveSensorSummaryService.scrubberConsumedMinutes`.
  final double? scrubberConsumedMinutes;
  final List<CellMetrics> cellMetrics;
  final List<TransmitterGap> transmitterGaps;

  const DiveSensorSummary({
    required this.diveId,
    required this.engineVersion,
    required this.sourceUpdatedAt,
    required this.computedAt,
    this.minTemperature,
    this.maxDepth,
    this.scrubberConsumedMinutes,
    this.cellMetrics = const [],
    this.transmitterGaps = const [],
  });

  @override
  List<Object?> get props => [
    diveId,
    engineVersion,
    sourceUpdatedAt,
    computedAt,
    minTemperature,
    maxDepth,
    scrubberConsumedMinutes,
    cellMetrics,
    transmitterGaps,
  ];
}

String encodeCellMetrics(List<CellMetrics> metrics) =>
    jsonEncode([for (final m in metrics) m.toJson()]);

/// Lenient on purpose: the column defaults to `[]`, and a row written by a
/// newer build with a shape this build does not know must not throw on
/// read. Unreadable entries are dropped, not surfaced.
List<CellMetrics> decodeCellMetrics(String json) =>
    _decodeList(json, CellMetrics.fromJson);

String encodeTransmitterGaps(List<TransmitterGap> gaps) =>
    jsonEncode([for (final g in gaps) g.toJson()]);

List<TransmitterGap> decodeTransmitterGaps(String json) =>
    _decodeList(json, TransmitterGap.fromJson);

List<T> _decodeList<T>(String json, T? Function(Object?) parse) {
  if (json.isEmpty) return const [];
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException {
    return const [];
  }
  if (raw is! List) return const [];
  return [for (final entry in raw) ?parse(entry)];
}

double? _double(Object? value) => value is num ? value.toDouble() : null;
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/equipment/domain/entities/dive_sensor_summary_test.dart`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/equipment/domain/entities/dive_sensor_summary.dart test/features/equipment/domain/entities/dive_sensor_summary_test.dart
git add lib/features/equipment/domain/entities/dive_sensor_summary.dart test/features/equipment/domain/entities/dive_sensor_summary_test.dart
git commit -m "feat(equipment): sensor summary value objects and column codecs (condition phase 2)"
```

---

### Task 2: DiveSensorSummaryService: extremes and scrubber consumption

**Files:**
- Create: `lib/features/equipment/domain/services/dive_sensor_summary_service.dart`
- Test: `test/features/equipment/domain/services/dive_sensor_summary_service_test.dart`

**Interfaces:**
- Consumes: Task 1 entities; `ProfileSample` (`lib/features/dive_log/domain/codecs/profile_sample.dart`); `TankPressureSample` (`lib/features/dive_log/domain/codecs/tank_pressure_series_codec.dart`); `DiveMode` (`lib/core/constants/enums.dart`, values `oc, ccr, scr, gauge`).
- Produces: `TankSensorSeries`, `DiveSensorSummaryService.version`, `summarize(...)`, `scrubberConsumedMinutes(...)`. Tasks 3 and 4 add `cellMetrics` and `transmitterGaps` to the same class.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/domain/services/dive_sensor_summary_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/equipment/domain/services/dive_sensor_summary_service.dart';

void main() {
  const service = DiveSensorSummaryService();
  final computedAt = DateTime.utc(2026, 9, 9, 12);

  group('extremes', () {
    test('min temperature and max depth come from the profile', () {
      final summary = service.summarize(
        diveId: 'd1',
        samples: const [
          ProfileSample(timestamp: 0, depth: 0.0, temperature: 18.0),
          ProfileSample(timestamp: 10, depth: 12.5, temperature: 9.5),
          ProfileSample(timestamp: 20, depth: 31.2, temperature: 4.1),
          ProfileSample(timestamp: 30, depth: 5.0),
        ],
        sourceUpdatedAt: 7,
        computedAt: computedAt,
      );
      expect(summary.diveId, 'd1');
      expect(summary.engineVersion, DiveSensorSummaryService.version);
      expect(summary.sourceUpdatedAt, 7);
      expect(summary.computedAt, computedAt);
      expect(summary.maxDepth, 31.2);
      expect(summary.minTemperature, 4.1);
    });

    test('an empty profile yields null extremes and empty metrics', () {
      final summary = service.summarize(
        diveId: 'd1',
        samples: const [],
        sourceUpdatedAt: 7,
        computedAt: computedAt,
      );
      expect(summary.maxDepth, isNull);
      expect(summary.minTemperature, isNull);
      expect(summary.cellMetrics, isEmpty);
      expect(summary.transmitterGaps, isEmpty);
    });

    test('a profile without temperature yields a depth but no temperature', () {
      final summary = service.summarize(
        diveId: 'd1',
        samples: const [ProfileSample(timestamp: 0, depth: 3.0)],
        sourceUpdatedAt: 7,
        computedAt: computedAt,
      );
      expect(summary.maxDepth, 3.0);
      expect(summary.minTemperature, isNull);
    });
  });

  group('scrubberConsumedMinutes', () {
    test('rated minus remaining when both are present', () {
      expect(
        DiveSensorSummaryService.scrubberConsumedMinutes(
          diveMode: DiveMode.oc,
          runtimeSeconds: 3600,
          durationMinutes: 180,
          remainingMinutes: 85,
        ),
        95,
      );
    });

    test('a negative difference falls through to runtime on the loop', () {
      expect(
        DiveSensorSummaryService.scrubberConsumedMinutes(
          diveMode: DiveMode.ccr,
          runtimeSeconds: 5400,
          durationMinutes: 180,
          remainingMinutes: 200,
        ),
        90,
      );
    });

    test('runtime minutes for CCR and SCR dives without scrubber figures', () {
      expect(
        DiveSensorSummaryService.scrubberConsumedMinutes(
          diveMode: DiveMode.ccr,
          runtimeSeconds: 4500,
        ),
        75,
      );
      expect(
        DiveSensorSummaryService.scrubberConsumedMinutes(
          diveMode: DiveMode.scr,
          runtimeSeconds: 600,
        ),
        10,
      );
    });

    test('null for open circuit and gauge dives without figures', () {
      expect(
        DiveSensorSummaryService.scrubberConsumedMinutes(
          diveMode: DiveMode.oc,
          runtimeSeconds: 4500,
        ),
        isNull,
      );
      expect(
        DiveSensorSummaryService.scrubberConsumedMinutes(
          diveMode: DiveMode.gauge,
          runtimeSeconds: 4500,
        ),
        isNull,
      );
    });

    test('null on the loop when runtime is missing or zero', () {
      expect(
        DiveSensorSummaryService.scrubberConsumedMinutes(
          diveMode: DiveMode.ccr,
        ),
        isNull,
      );
      expect(
        DiveSensorSummaryService.scrubberConsumedMinutes(
          diveMode: DiveMode.ccr,
          runtimeSeconds: 0,
        ),
        isNull,
      );
    });

    test('summarize threads the dive fields through', () {
      final summary = service.summarize(
        diveId: 'd1',
        samples: const [],
        diveMode: DiveMode.ccr,
        runtimeSeconds: 3000,
        scrubberDurationMinutes: 180,
        scrubberRemainingMinutes: 120,
        sourceUpdatedAt: 1,
        computedAt: computedAt,
      );
      expect(summary.scrubberConsumedMinutes, 60);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/domain/services/dive_sensor_summary_service_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 3: Write the service**

```dart
// lib/features/equipment/domain/services/dive_sensor_summary_service.dart
import 'dart:math' as math;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';

/// One tank's pressure series with the identity the gap rules key on.
class TankSensorSeries {
  final String tankId;
  final String? transmitterSerial;
  final String? computerId;

  /// Sorted by timestamp, as the repository stores them.
  final List<TankPressureSample> samples;

  const TankSensorSeries({
    required this.tankId,
    this.transmitterSerial,
    this.computerId,
    required this.samples,
  });
}

/// Pure: decoded samples in, one [DiveSensorSummary] out. Runs on the
/// worker isolate through `computeSensorSummaryFromBlobs`, so it must not
/// touch Flutter, the database or any provider.
///
/// Bump [version] whenever a rule here changes what a stored row would
/// contain; the repository recomputes every row whose version is older.
class DiveSensorSummaryService {
  static const int version = 1;

  /// Cells report `o2Sensor1` to `o2Sensor6`.
  static const int slotCount = 6;

  /// Gain samples below this ppO2 are skipped: the reading is dominated by
  /// offset and noise, not the cell's output.
  static const double minGainPpO2Bar = 0.2;

  /// A slot more than this far from the median of its peers is diverging.
  static const double divergenceRangeThresholdBar = 0.1;

  /// A divergence run shorter than this is not stored as a range.
  static const int divergenceRangeMinSeconds = 30;

  /// Current limiting is judged over samples above this median ppO2.
  static const double currentLimitHighPpO2Bar = 1.2;

  /// A slot reading more than this below the median at high ppO2 counts as
  /// limited on that sample.
  static const double currentLimitLowByBar = 0.1;

  /// The slot must have tracked its peers within this at low ppO2 on the
  /// same dive, or the limiting figure is not computed at all.
  static const double currentLimitAgreementBar = 0.05;
  static const double currentLimitAgreementMaxPpO2Bar = 1.0;

  /// An interval longer than this many cadences is a transmitter gap.
  static const int gapCadenceFactor = 3;

  const DiveSensorSummaryService();

  DiveSensorSummary summarize({
    required String diveId,
    required List<ProfileSample> samples,
    List<TankSensorSeries> tanks = const [],
    DiveMode diveMode = DiveMode.oc,
    int? runtimeSeconds,
    int? scrubberDurationMinutes,
    int? scrubberRemainingMinutes,
    required int sourceUpdatedAt,
    required DateTime computedAt,
  }) {
    double? minTemperature;
    double? maxDepth;
    for (final sample in samples) {
      final temperature = sample.temperature;
      if (temperature != null &&
          (minTemperature == null || temperature < minTemperature)) {
        minTemperature = temperature;
      }
      if (maxDepth == null || sample.depth > maxDepth) {
        maxDepth = sample.depth;
      }
    }
    return DiveSensorSummary(
      diveId: diveId,
      engineVersion: version,
      sourceUpdatedAt: sourceUpdatedAt,
      computedAt: computedAt,
      minTemperature: minTemperature,
      maxDepth: maxDepth,
      scrubberConsumedMinutes: scrubberConsumedMinutes(
        diveMode: diveMode,
        runtimeSeconds: runtimeSeconds,
        durationMinutes: scrubberDurationMinutes,
        remainingMinutes: scrubberRemainingMinutes,
      ),
      cellMetrics: cellMetrics(samples),
      transmitterGaps: transmitterGaps(samples, tanks),
    );
  }

  /// Rated minus remaining when the dive carries both and the difference is
  /// not negative; else runtime minutes on the loop (CCR or SCR); else null,
  /// so an open-circuit dive never charges a scrubber.
  static double? scrubberConsumedMinutes({
    required DiveMode diveMode,
    int? runtimeSeconds,
    int? durationMinutes,
    int? remainingMinutes,
  }) {
    if (durationMinutes != null && remainingMinutes != null) {
      final consumed = durationMinutes - remainingMinutes;
      if (consumed >= 0) return consumed.toDouble();
    }
    final onLoop = diveMode == DiveMode.ccr || diveMode == DiveMode.scr;
    if (onLoop && runtimeSeconds != null && runtimeSeconds > 0) {
      return runtimeSeconds / 60.0;
    }
    return null;
  }

  /// Task 3 fills this in.
  static List<CellMetrics> cellMetrics(List<ProfileSample> samples) =>
      const [];

  /// Task 4 fills this in.
  static List<TransmitterGap> transmitterGaps(
    List<ProfileSample> samples,
    List<TankSensorSeries> tanks,
  ) => const [];

  /// Median of a non-empty list. Even counts average the middle pair.
  static double median(List<double> values) {
    assert(values.isNotEmpty, 'median of nothing');
    final sorted = List<double>.of(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// Nearest-rank percentile of a non-empty list, [fraction] in 0 to 1.
  static double percentile(List<double> values, double fraction) {
    assert(values.isNotEmpty, 'percentile of nothing');
    final sorted = List<double>.of(values)..sort();
    final index = (fraction * (sorted.length - 1)).round();
    return sorted[math.max(0, math.min(sorted.length - 1, index))];
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/equipment/domain/services/dive_sensor_summary_service_test.dart`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/equipment/domain/services/dive_sensor_summary_service.dart test/features/equipment/domain/services/dive_sensor_summary_service_test.dart
git add lib/features/equipment/domain/services/dive_sensor_summary_service.dart test/features/equipment/domain/services/dive_sensor_summary_service_test.dart
git commit -m "feat(equipment): sensor summary service with profile extremes and scrubber use (condition phase 2)"
```

---

### Task 3: Cell metrics: gain, divergence, ranges, current limiting

**Files:**
- Modify: `lib/features/equipment/domain/services/dive_sensor_summary_service.dart` (replace the `cellMetrics` stub)
- Test: `test/features/equipment/domain/services/dive_sensor_summary_service_test.dart` (add a group)

**Interfaces:**
- Produces: `DiveSensorSummaryService.cellMetrics(List<ProfileSample>) -> List<CellMetrics>`, one entry per slot that carried ppO2.

Definitions (from the spec, pinned here so the tests and code agree):

- A slot "has data" at a sample when its `o2SensorN` is non-null. `samples` counts those.
- Gain sample = `o2SensorMvN / o2SensorN` when both are present and ppO2 is at least 0.2 bar. `gainMvPerBar` is the median; null when no gain sample exists.
- Per-sample median = median of the ppO2 of every slot with data at that sample, defined only when at least two slots have data. Divergence = slot ppO2 minus that median. `p95DivergenceBar` = nearest-rank 95th percentile of the absolute divergence over the slot's samples that have a median; null when none.
- A divergence range is a maximal run of consecutive samples (each with data and a median) where the absolute divergence exceeds 0.1 bar, whose span from first to last timestamp is at least 30 seconds. `[start, end, peak]`.
- Agreement at low ppO2: over samples where the median is at or below 1.0 bar, the median of the slot's absolute divergence is at most 0.05 bar, and at least one such sample exists.
- `highPpO2Samples` = samples where the median exceeds 1.2 bar. `lowAtHighFraction` = share of those where divergence is below minus 0.1 bar; null unless the slot agreed at low ppO2 and `highPpO2Samples` is positive.

- [ ] **Step 1: Write the failing tests**

Add to the test file, inside `main()` after the scrubber group:

```dart
  group('cellMetrics', () {
    /// Three cells reading [c1, c2, c3] bar with optional millivolts.
    ProfileSample cells(
      int t,
      List<double?> ppO2, {
      List<int?> mv = const [null, null, null],
    }) => ProfileSample(
      timestamp: t,
      depth: 20.0,
      o2Sensor1: ppO2[0],
      o2Sensor2: ppO2[1],
      o2Sensor3: ppO2[2],
      o2SensorMv1: mv[0],
      o2SensorMv2: mv[1],
      o2SensorMv3: mv[2],
    );

    test('gain is the median of mV over ppO2, skipping low ppO2', () {
      final metrics = DiveSensorSummaryService.cellMetrics([
        cells(0, [1.0, null, null], mv: [50, null, null]),
        cells(10, [1.2, null, null], mv: [66, null, null]),
        cells(20, [0.7, null, null], mv: [42, null, null]),
        // Below the 0.2 bar floor: skipped even though it would read 500.
        cells(30, [0.1, null, null], mv: [50, null, null]),
        // No millivolts: counts as a sample, contributes no gain.
        cells(40, [1.0, null, null]),
      ]);
      expect(metrics, hasLength(1));
      final slot1 = metrics.single;
      expect(slot1.slot, 1);
      expect(slot1.samples, 5);
      // 50, 55, 60 -> median 55.
      expect(slot1.gainMvPerBar, closeTo(55.0, 1e-9));
      // A single slot never diverges from anything.
      expect(slot1.p95DivergenceBar, isNull);
      expect(slot1.divergenceRanges, isEmpty);
      expect(slot1.lowAtHighFraction, isNull);
    });

    test('a slot with no millivolts has a null gain but keeps its count', () {
      final metrics = DiveSensorSummaryService.cellMetrics([
        cells(0, [1.0, 1.0, null]),
        cells(10, [1.0, 1.0, null]),
      ]);
      expect(metrics.map((m) => m.slot), [1, 2]);
      expect(metrics.first.gainMvPerBar, isNull);
      expect(metrics.first.samples, 2);
    });

    test('divergence is against the median of the slots with data', () {
      // Slot 3 reads 0.3 bar high on every sample; the median of three is
      // the middle value, so slots 1 and 2 diverge by 0 and slot 3 by 0.3.
      final metrics = DiveSensorSummaryService.cellMetrics([
        for (var t = 0; t < 100; t += 10) cells(t, [1.0, 1.0, 1.3]),
      ]);
      final bySlot = {for (final m in metrics) m.slot: m};
      expect(bySlot[1]!.p95DivergenceBar, closeTo(0.0, 1e-9));
      expect(bySlot[2]!.p95DivergenceBar, closeTo(0.0, 1e-9));
      expect(bySlot[3]!.p95DivergenceBar, closeTo(0.3, 1e-9));
    });

    test('p95 is the nearest-rank 95th percentile of |divergence|', () {
      // Slot 3 diverges by 0.02 on 19 samples and by 0.5 on one.
      final metrics = DiveSensorSummaryService.cellMetrics([
        for (var t = 0; t < 190; t += 10) cells(t, [1.0, 1.0, 1.02]),
        cells(190, [1.0, 1.0, 1.5]),
      ]);
      final slot3 = metrics.firstWhere((m) => m.slot == 3);
      // round(0.95 * 19) = 18 -> the 19th sorted value, still 0.02.
      expect(slot3.p95DivergenceBar, closeTo(0.02, 1e-9));
    });

    test('a divergence run of exactly 30 seconds is stored', () {
      final metrics = DiveSensorSummaryService.cellMetrics([
        cells(0, [1.0, 1.0, 1.0]),
        cells(100, [1.0, 1.0, 1.15]),
        cells(110, [1.0, 1.0, 1.2]),
        cells(120, [1.0, 1.0, 1.18]),
        cells(130, [1.0, 1.0, 1.12]),
        cells(140, [1.0, 1.0, 1.0]),
      ]);
      final slot3 = metrics.firstWhere((m) => m.slot == 3);
      expect(slot3.divergenceRanges, hasLength(1));
      final range = slot3.divergenceRanges.single;
      expect(range.startSeconds, 100);
      expect(range.endSeconds, 130);
      expect(range.peakBar, closeTo(0.2, 1e-9));
    });

    test('a divergence run shorter than 30 seconds is not stored', () {
      final metrics = DiveSensorSummaryService.cellMetrics([
        cells(0, [1.0, 1.0, 1.0]),
        cells(100, [1.0, 1.0, 1.15]),
        cells(110, [1.0, 1.0, 1.2]),
        cells(120, [1.0, 1.0, 1.18]),
        cells(130, [1.0, 1.0, 1.0]),
      ]);
      final slot3 = metrics.firstWhere((m) => m.slot == 3);
      expect(slot3.divergenceRanges, isEmpty);
    });

    test('a run is broken by a sample where the slot has no data', () {
      final metrics = DiveSensorSummaryService.cellMetrics([
        cells(0, [1.0, 1.0, 1.2]),
        cells(10, [1.0, 1.0, 1.2]),
        cells(20, [1.0, 1.0, null]),
        cells(30, [1.0, 1.0, 1.2]),
        cells(40, [1.0, 1.0, 1.2]),
      ]);
      final slot3 = metrics.firstWhere((m) => m.slot == 3);
      // Two runs of 10 seconds each, neither long enough.
      expect(slot3.divergenceRanges, isEmpty);
    });

    test('divergence at exactly 0.1 bar is not a range', () {
      final metrics = DiveSensorSummaryService.cellMetrics([
        for (var t = 0; t < 100; t += 10) cells(t, [1.0, 1.0, 1.1]),
      ]);
      final slot3 = metrics.firstWhere((m) => m.slot == 3);
      expect(slot3.divergenceRanges, isEmpty);
    });

    test('current limiting is computed only after low-ppO2 agreement', () {
      // Slot 3 agrees at 0.7 bar, then reads 0.2 low once the loop is
      // above 1.2 bar. Median of [1.3, 1.3, 1.1] is 1.3.
      final agreed = DiveSensorSummaryService.cellMetrics([
        for (var t = 0; t < 50; t += 10) cells(t, [0.7, 0.7, 0.72]),
        for (var t = 100; t < 140; t += 10) cells(t, [1.3, 1.3, 1.1]),
        cells(140, [1.3, 1.3, 1.3]),
      ]);
      final slot3 = agreed.firstWhere((m) => m.slot == 3);
      expect(slot3.highPpO2Samples, 5);
      expect(slot3.lowAtHighFraction, closeTo(0.8, 1e-9));
      // Slots 1 and 2 sat on the median at high ppO2.
      expect(agreed.firstWhere((m) => m.slot == 1).lowAtHighFraction, 0);

      // Same high-ppO2 behaviour, but slot 3 was already 0.1 off at low
      // ppO2: the limiting figure is withheld.
      final disagreed = DiveSensorSummaryService.cellMetrics([
        for (var t = 0; t < 50; t += 10) cells(t, [0.7, 0.7, 0.8]),
        for (var t = 100; t < 140; t += 10) cells(t, [1.3, 1.3, 1.1]),
        cells(140, [1.3, 1.3, 1.3]),
      ]);
      expect(
        disagreed.firstWhere((m) => m.slot == 3).lowAtHighFraction,
        isNull,
      );
      expect(disagreed.firstWhere((m) => m.slot == 3).highPpO2Samples, 5);
    });

    test('no high-ppO2 samples yields a null fraction', () {
      final metrics = DiveSensorSummaryService.cellMetrics([
        for (var t = 0; t < 50; t += 10) cells(t, [0.7, 0.7, 0.7]),
      ]);
      expect(metrics.first.highPpO2Samples, 0);
      expect(metrics.first.lowAtHighFraction, isNull);
    });

    test('reading exactly 0.1 below the median is not limited', () {
      final metrics = DiveSensorSummaryService.cellMetrics([
        for (var t = 0; t < 50; t += 10) cells(t, [0.7, 0.7, 0.7]),
        for (var t = 100; t < 150; t += 10) cells(t, [1.3, 1.3, 1.2]),
      ]);
      expect(
        metrics.firstWhere((m) => m.slot == 3).lowAtHighFraction,
        0,
      );
    });

    test('slots the computer never reported are absent', () {
      final metrics = DiveSensorSummaryService.cellMetrics([
        cells(0, [1.0, null, 1.0]),
      ]);
      expect(metrics.map((m) => m.slot), [1, 3]);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/domain/services/dive_sensor_summary_service_test.dart --name cellMetrics`
Expected: FAIL, `metrics` is empty (`hasLength(1)` fails).

- [ ] **Step 3: Replace the `cellMetrics` stub**

Replace the two-line stub with:

```dart
  /// One [CellMetrics] per slot that carried ppO2 on the dive, in slot
  /// order. See the class constants for every threshold.
  static List<CellMetrics> cellMetrics(List<ProfileSample> samples) {
    // Per-sample median over the slots with data, or null when fewer than
    // two slots reported, so a single-cell profile yields gain only.
    final medians = List<double?>.filled(samples.length, null);
    for (var i = 0; i < samples.length; i++) {
      final values = <double>[
        for (var slot = 1; slot <= slotCount; slot++)
          ?_ppO2(samples[i], slot),
      ];
      if (values.length >= 2) medians[i] = median(values);
    }

    final result = <CellMetrics>[];
    for (var slot = 1; slot <= slotCount; slot++) {
      var used = 0;
      final gains = <double>[];
      final magnitudes = <double>[];
      final lowMagnitudes = <double>[];
      var highSamples = 0;
      var lowAtHigh = 0;
      final ranges = <DivergenceRange>[];
      int? runStart;
      int? runEnd;
      var runPeak = 0.0;

      void closeRun() {
        if (runStart != null &&
            runEnd! - runStart! >= divergenceRangeMinSeconds) {
          ranges.add(
            DivergenceRange(
              startSeconds: runStart!,
              endSeconds: runEnd!,
              peakBar: runPeak,
            ),
          );
        }
        runStart = null;
        runEnd = null;
        runPeak = 0.0;
      }

      for (var i = 0; i < samples.length; i++) {
        final sample = samples[i];
        final ppO2 = _ppO2(sample, slot);
        if (ppO2 == null) {
          closeRun();
          continue;
        }
        used++;
        final mv = _mv(sample, slot);
        if (mv != null && ppO2 >= minGainPpO2Bar) gains.add(mv / ppO2);

        final medianPpO2 = medians[i];
        if (medianPpO2 == null) {
          closeRun();
          continue;
        }
        final divergence = ppO2 - medianPpO2;
        final magnitude = divergence.abs();
        magnitudes.add(magnitude);

        if (magnitude > divergenceRangeThresholdBar) {
          runStart ??= sample.timestamp;
          runEnd = sample.timestamp;
          if (magnitude > runPeak) runPeak = magnitude;
        } else {
          closeRun();
        }

        if (medianPpO2 <= currentLimitAgreementMaxPpO2Bar) {
          lowMagnitudes.add(magnitude);
        }
        if (medianPpO2 > currentLimitHighPpO2Bar) {
          highSamples++;
          if (divergence < -currentLimitLowByBar) lowAtHigh++;
        }
      }
      closeRun();
      if (used == 0) continue;

      final agreedAtLow =
          lowMagnitudes.isNotEmpty &&
          median(lowMagnitudes) <= currentLimitAgreementBar;
      result.add(
        CellMetrics(
          slot: slot,
          samples: used,
          gainMvPerBar: gains.isEmpty ? null : median(gains),
          p95DivergenceBar: magnitudes.isEmpty
              ? null
              : percentile(magnitudes, 0.95),
          highPpO2Samples: highSamples,
          lowAtHighFraction: agreedAtLow && highSamples > 0
              ? lowAtHigh / highSamples
              : null,
          divergenceRanges: ranges,
        ),
      );
    }
    return result;
  }

  static double? _ppO2(ProfileSample s, int slot) => switch (slot) {
    1 => s.o2Sensor1,
    2 => s.o2Sensor2,
    3 => s.o2Sensor3,
    4 => s.o2Sensor4,
    5 => s.o2Sensor5,
    6 => s.o2Sensor6,
    _ => null,
  };

  static int? _mv(ProfileSample s, int slot) => switch (slot) {
    1 => s.o2SensorMv1,
    2 => s.o2SensorMv2,
    3 => s.o2SensorMv3,
    4 => s.o2SensorMv4,
    5 => s.o2SensorMv5,
    6 => s.o2SensorMv6,
    _ => null,
  };
```

Note the `?_ppO2(...)` null-aware element inside the list literal; the codebase already uses this Dart 3.8 syntax (see `profile_series_repository.dart`, `?_decodeOrNull(row)`).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/equipment/domain/services/dive_sensor_summary_service_test.dart`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/equipment/domain/services/dive_sensor_summary_service.dart test/features/equipment/domain/services/dive_sensor_summary_service_test.dart
git add lib/features/equipment/domain/services/dive_sensor_summary_service.dart test/features/equipment/domain/services/dive_sensor_summary_service_test.dart
git commit -m "feat(equipment): O2 cell gain, divergence and current-limit metrics (condition phase 2)"
```

---

### Task 4: Transmitter gaps

**Files:**
- Modify: `lib/features/equipment/domain/services/dive_sensor_summary_service.dart` (replace the `transmitterGaps` stub)
- Test: `test/features/equipment/domain/services/dive_sensor_summary_service_test.dart` (add a group)

**Interfaces:**
- Produces: `DiveSensorSummaryService.transmitterGaps(List<ProfileSample>, List<TankSensorSeries>) -> List<TransmitterGap>`, one per tank whose series has at least two samples.

Definitions:

- Cadence = median of the intervals between consecutive pressure samples.
- A gap is an interval strictly longer than three cadences. Its whole length counts as gap seconds.
- The dive spans from the earlier of the profile start and the series start to the later of the profile end and the series end. The uncovered span before the first pressure sample and after the last one each count as a gap under the same rule (this is the spec's "run of samples with no pressure value while the depth series continues").
- `diveSeconds` is that span; `gapFraction` divides by it.

- [ ] **Step 1: Write the failing tests**

Add to the test file, after the `cellMetrics` group:

```dart
  group('transmitterGaps', () {
    List<ProfileSample> depth(int endSeconds) => [
      for (var t = 0; t <= endSeconds; t += 10)
        ProfileSample(timestamp: t, depth: 20.0),
    ];

    TankSensorSeries tank(List<int> timestamps, {String id = 't1'}) =>
        TankSensorSeries(
          tankId: id,
          transmitterSerial: '180777',
          computerId: 'c1',
          samples: [
            for (final t in timestamps)
              TankPressureSample(timestamp: t, pressure: 200.0),
          ],
        );

    test('a clean series has no gaps and carries its identity', () {
      final gaps = DiveSensorSummaryService.transmitterGaps(depth(100), [
        tank([0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]),
      ]);
      expect(gaps, hasLength(1));
      final gap = gaps.single;
      expect(gap.tankId, 't1');
      expect(gap.transmitterSerial, '180777');
      expect(gap.computerId, 'c1');
      expect(gap.cadenceSeconds, 10);
      expect(gap.gapSeconds, 0);
      expect(gap.gapCount, 0);
      expect(gap.longestGapSeconds, 0);
      expect(gap.diveSeconds, 100);
      expect(gap.gapFraction, 0);
    });

    test('an interval of exactly three cadences is not a gap', () {
      final gaps = DiveSensorSummaryService.transmitterGaps(depth(60), [
        tank([0, 10, 20, 50, 60]),
      ]);
      expect(gaps.single.gapCount, 0);
    });

    test('an interval longer than three cadences is a gap', () {
      final gaps = DiveSensorSummaryService.transmitterGaps(depth(100), [
        tank([0, 10, 20, 60, 70, 80, 90, 100]),
      ]);
      final gap = gaps.single;
      expect(gap.cadenceSeconds, 10);
      expect(gap.gapCount, 1);
      expect(gap.gapSeconds, 40);
      expect(gap.longestGapSeconds, 40);
      expect(gap.gapFraction, closeTo(0.4, 1e-9));
    });

    test('several gaps accumulate and the longest is kept', () {
      final gaps = DiveSensorSummaryService.transmitterGaps(depth(200), [
        tank([0, 10, 20, 60, 70, 80, 90, 100, 190, 200]),
      ]);
      final gap = gaps.single;
      expect(gap.gapCount, 2);
      expect(gap.gapSeconds, 130);
      expect(gap.longestGapSeconds, 90);
    });

    test('a series that stops while the profile continues is a gap', () {
      final gaps = DiveSensorSummaryService.transmitterGaps(depth(200), [
        tank([0, 10, 20, 30, 40, 50]),
      ]);
      final gap = gaps.single;
      expect(gap.diveSeconds, 200);
      expect(gap.gapCount, 1);
      expect(gap.gapSeconds, 150);
    });

    test('a series that starts late is a gap too', () {
      final gaps = DiveSensorSummaryService.transmitterGaps(depth(100), [
        tank([60, 70, 80, 90, 100]),
      ]);
      expect(gaps.single.gapSeconds, 60);
    });

    test('without a profile the series span is the dive span', () {
      final gaps = DiveSensorSummaryService.transmitterGaps(const [], [
        tank([0, 10, 20, 30]),
      ]);
      expect(gaps.single.diveSeconds, 30);
      expect(gaps.single.gapCount, 0);
    });

    test('a series with fewer than two samples is skipped', () {
      final gaps = DiveSensorSummaryService.transmitterGaps(depth(100), [
        tank([50]),
        tank([0, 50, 100], id: 't2'),
      ]);
      expect(gaps.map((g) => g.tankId), ['t2']);
    });
  });
```

Add the import at the top of the test file:

```dart
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/domain/services/dive_sensor_summary_service_test.dart --name transmitterGaps`
Expected: FAIL, `gaps` is empty.

- [ ] **Step 3: Replace the `transmitterGaps` stub**

```dart
  /// One [TransmitterGap] per tank whose series has at least two samples.
  static List<TransmitterGap> transmitterGaps(
    List<ProfileSample> samples,
    List<TankSensorSeries> tanks,
  ) {
    final profileStart = samples.isEmpty ? null : samples.first.timestamp;
    final profileEnd = samples.isEmpty ? null : samples.last.timestamp;
    final result = <TransmitterGap>[];
    for (final tank in tanks) {
      final series = tank.samples;
      if (series.length < 2) continue;
      final intervals = <double>[
        for (var i = 1; i < series.length; i++)
          (series[i].timestamp - series[i - 1].timestamp).toDouble(),
      ];
      final cadence = median(intervals);
      if (cadence <= 0) continue;
      final limit = cadence * gapCadenceFactor;

      var gapSeconds = 0;
      var gapCount = 0;
      var longest = 0;
      void account(int seconds) {
        if (seconds <= limit) return;
        gapSeconds += seconds;
        gapCount++;
        if (seconds > longest) longest = seconds;
      }

      for (final interval in intervals) {
        account(interval.round());
      }
      final start = profileStart == null
          ? series.first.timestamp
          : math.min(profileStart, series.first.timestamp);
      final end = profileEnd == null
          ? series.last.timestamp
          : math.max(profileEnd, series.last.timestamp);
      account(series.first.timestamp - start);
      account(end - series.last.timestamp);

      result.add(
        TransmitterGap(
          tankId: tank.tankId,
          transmitterSerial: tank.transmitterSerial,
          computerId: tank.computerId,
          cadenceSeconds: cadence,
          gapSeconds: gapSeconds,
          gapCount: gapCount,
          longestGapSeconds: longest,
          diveSeconds: end - start,
        ),
      );
    }
    return result;
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/equipment/domain/services/dive_sensor_summary_service_test.dart`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/equipment/domain/services/dive_sensor_summary_service.dart test/features/equipment/domain/services/dive_sensor_summary_service_test.dart
git add lib/features/equipment/domain/services/dive_sensor_summary_service.dart test/features/equipment/domain/services/dive_sensor_summary_service_test.dart
git commit -m "feat(equipment): transmitter dropout gaps per tank (condition phase 2)"
```

---

### Task 5: Isolate worker over blobs

**Files:**
- Create: `lib/features/equipment/data/services/sensor_summary_worker.dart`
- Test: `test/features/equipment/data/services/sensor_summary_worker_test.dart`

**Interfaces:**
- Consumes: `ProfileSeriesCodec().decode(Uint8List)` and `.encode(List<ProfileSample>)` (`lib/features/dive_log/domain/codecs/profile_series_codec.dart`; encode returns an object with `.bytes`); `TankPressureSeriesCodec().decode/encode` (`tank_pressure_series_codec.dart`, encode returns `EncodedTankPressureSeries` with `.bytes`); both throw `ProfileSeriesCodecException` (`profile_series_codec_exception.dart`); `mergeSort` from `package:collection`.
- Produces: `TankSeriesBlob`, `SensorSummaryWorkInput`, top-level `DiveSensorSummary computeSensorSummaryFromBlobs(SensorSummaryWorkInput input)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/data/services/sensor_summary_worker_test.dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_worker.dart';

void main() {
  const profileCodec = ProfileSeriesCodec();
  const tankCodec = TankPressureSeriesCodec();

  Uint8List profile(List<ProfileSample> samples) =>
      profileCodec.encode(samples).bytes;
  Uint8List pressures(List<TankPressureSample> samples) =>
      tankCodec.encode(samples).bytes;

  SensorSummaryWorkInput input({
    List<Uint8List> primary = const [],
    List<TankSeriesBlob> tanks = const [],
  }) => SensorSummaryWorkInput(
    diveId: 'd1',
    primaryBlobs: primary,
    tankBlobs: tanks,
    diveMode: DiveMode.ccr,
    runtimeSeconds: 3000,
    scrubberDurationMinutes: null,
    scrubberRemainingMinutes: null,
    sourceUpdatedAt: 42,
    computedAtMs: DateTime.utc(2026, 9, 9).millisecondsSinceEpoch,
  );

  test('decodes the profile and tank blobs and summarises them', () {
    final summary = computeSensorSummaryFromBlobs(
      input(
        primary: [
          profile(const [
            ProfileSample(timestamp: 0, depth: 0, temperature: 12),
            ProfileSample(timestamp: 60, depth: 25.5, temperature: 6),
            ProfileSample(timestamp: 120, depth: 3, temperature: 10),
          ]),
        ],
        tanks: [
          TankSeriesBlob(
            tankId: 't1',
            transmitterSerial: '180777',
            computerId: 'c1',
            samples: pressures(const [
              TankPressureSample(timestamp: 0, pressure: 200),
              TankPressureSample(timestamp: 10, pressure: 199),
              TankPressureSample(timestamp: 20, pressure: 198),
              TankPressureSample(timestamp: 120, pressure: 190),
            ]),
          ),
        ],
      ),
    );
    expect(summary.diveId, 'd1');
    expect(summary.sourceUpdatedAt, 42);
    expect(summary.computedAt, DateTime.utc(2026, 9, 9));
    expect(summary.maxDepth, 25.5);
    expect(summary.minTemperature, 6);
    expect(summary.scrubberConsumedMinutes, 50);
    expect(summary.transmitterGaps.single.tankId, 't1');
    expect(summary.transmitterGaps.single.gapCount, 1);
    expect(summary.transmitterGaps.single.gapSeconds, 100);
  });

  test('several primary blobs are merged by timestamp', () {
    final summary = computeSensorSummaryFromBlobs(
      input(
        primary: [
          profile(const [
            ProfileSample(timestamp: 100, depth: 30, temperature: 5),
            ProfileSample(timestamp: 200, depth: 10),
          ]),
          profile(const [
            ProfileSample(timestamp: 0, depth: 0, temperature: 20),
            ProfileSample(timestamp: 50, depth: 15),
          ]),
        ],
      ),
    );
    expect(summary.maxDepth, 30);
    expect(summary.minTemperature, 5);
  });

  test('an unreadable blob is skipped, not fatal', () {
    final summary = computeSensorSummaryFromBlobs(
      input(
        primary: [
          Uint8List.fromList([1, 2, 3]),
          profile(const [ProfileSample(timestamp: 0, depth: 7)]),
        ],
        tanks: [
          TankSeriesBlob(
            tankId: 't1',
            samples: Uint8List.fromList([9, 9]),
          ),
        ],
      ),
    );
    expect(summary.maxDepth, 7);
    expect(summary.transmitterGaps, isEmpty);
  });

  test('no blobs at all still yields a row', () {
    final summary = computeSensorSummaryFromBlobs(input());
    expect(summary.maxDepth, isNull);
    expect(summary.cellMetrics, isEmpty);
    expect(summary.scrubberConsumedMinutes, 50);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/data/services/sensor_summary_worker_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 3: Write the worker**

```dart
// lib/features/equipment/data/services/sensor_summary_worker.dart
import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';
import 'package:submersion/features/equipment/domain/services/dive_sensor_summary_service.dart';

/// One tank's pressure series as it crosses the isolate boundary: identity
/// plus the undecoded blob, like `SeriesBlob` in the statistics aggregates.
class TankSeriesBlob {
  final String tankId;
  final String? transmitterSerial;
  final String? computerId;
  final Uint8List samples;

  const TankSeriesBlob({
    required this.tankId,
    this.transmitterSerial,
    this.computerId,
    required this.samples,
  });
}

/// Everything [computeSensorSummaryFromBlobs] needs, read on the main
/// isolate without decoding anything.
class SensorSummaryWorkInput {
  final String diveId;
  final List<Uint8List> primaryBlobs;
  final List<TankSeriesBlob> tankBlobs;
  final DiveMode diveMode;
  final int? runtimeSeconds;
  final int? scrubberDurationMinutes;
  final int? scrubberRemainingMinutes;
  final int sourceUpdatedAt;
  final int computedAtMs;

  const SensorSummaryWorkInput({
    required this.diveId,
    required this.primaryBlobs,
    required this.tankBlobs,
    required this.diveMode,
    required this.runtimeSeconds,
    required this.scrubberDurationMinutes,
    required this.scrubberRemainingMinutes,
    required this.sourceUpdatedAt,
    required this.computedAtMs,
  });
}

/// Top-level so `compute` can send it to a worker. Decodes every blob,
/// merges the primary segments by timestamp (stable, so two segments with
/// the same second keep their order), and runs the pure service.
///
/// A blob that fails to decode is skipped: one corrupt segment must not
/// leave the dive without a row, or the sweep would revisit it forever.
DiveSensorSummary computeSensorSummaryFromBlobs(SensorSummaryWorkInput input) {
  const profileCodec = ProfileSeriesCodec();
  const tankCodec = TankPressureSeriesCodec();

  final samples = <ProfileSample>[];
  for (final blob in input.primaryBlobs) {
    try {
      samples.addAll(profileCodec.decode(blob));
    } on ProfileSeriesCodecException {
      continue;
    }
  }
  if (input.primaryBlobs.length > 1) {
    mergeSort<ProfileSample>(
      samples,
      compare: (a, b) => a.timestamp.compareTo(b.timestamp),
    );
  }

  final tanks = <TankSensorSeries>[];
  for (final blob in input.tankBlobs) {
    try {
      tanks.add(
        TankSensorSeries(
          tankId: blob.tankId,
          transmitterSerial: blob.transmitterSerial,
          computerId: blob.computerId,
          samples: tankCodec.decode(blob.samples),
        ),
      );
    } on ProfileSeriesCodecException {
      continue;
    }
  }

  return const DiveSensorSummaryService().summarize(
    diveId: input.diveId,
    samples: samples,
    tanks: tanks,
    diveMode: input.diveMode,
    runtimeSeconds: input.runtimeSeconds,
    scrubberDurationMinutes: input.scrubberDurationMinutes,
    scrubberRemainingMinutes: input.scrubberRemainingMinutes,
    sourceUpdatedAt: input.sourceUpdatedAt,
    computedAt: DateTime.fromMillisecondsSinceEpoch(
      input.computedAtMs,
      isUtc: true,
    ),
  );
}
```

If `TankPressureSeriesCodec.decode` throws a different exception type on garbage (check `tank_pressure_series_codec.dart` around line 130), catch that type as well in the tank loop.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/equipment/data/services/sensor_summary_worker_test.dart`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/equipment/data/services/sensor_summary_worker.dart test/features/equipment/data/services/sensor_summary_worker_test.dart
git add lib/features/equipment/data/services/sensor_summary_worker.dart test/features/equipment/data/services/sensor_summary_worker_test.dart
git commit -m "feat(equipment): sensor summary isolate worker over series blobs (condition phase 2)"
```

---

### Task 6: DiveSensorSummaryRepository: compute-through-cache and staleness

**Files:**
- Create: `lib/features/equipment/data/repositories/dive_sensor_summary_repository.dart`
- Test: `test/features/equipment/data/repositories/dive_sensor_summary_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` tables `dives`, `diveProfileSeries`, `diveTanks`, `tankPressureSeries`, `diveSensorSummaries` (row class `DiveSensorSummaryRow`, companion `DiveSensorSummariesCompanion`); `DatabaseService.instance.database`; `DiveMode.fromCode(String)`; `compute` from `package:flutter/foundation.dart`; Task 5 worker.
- Produces:
  - `typedef SensorSummaryRunner = Future<DiveSensorSummary> Function(SensorSummaryWorkInput input);`
  - `DiveSensorSummaryRepository({AppDatabase? db, SensorSummaryRunner? runner})`
  - `Future<DiveSensorSummary?> getSummary(String diveId)`
  - `Future<DiveSensorSummary?> ensureCurrent(String diveId, {bool force = false})` (null when the dive does not exist)
  - `Future<void> saveSummary(DiveSensorSummary summary)`
  - `Future<List<String>> staleDiveIds({String? diverId})` (oldest first)
  - `Future<int> countStale({String? diverId})`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/data/repositories/dive_sensor_summary_repository_test.dart
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_worker.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';
import 'package:submersion/features/equipment/domain/services/dive_sensor_summary_service.dart';

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DiveSensorSummaryRepository repo;
  var runs = 0;

  setUp(() async {
    db = await setUpTestDatabase();
    runs = 0;
    // Run the worker on this isolate so the test can count invocations;
    // the default runner goes through compute and is covered separately.
    repo = DiveSensorSummaryRepository(
      db: db,
      runner: (input) async {
        runs++;
        return computeSensorSummaryFromBlobs(input);
      },
    );
  });

  tearDown(tearDownTestDatabase);

  Future<void> insertDive(
    String id, {
    int dateMs = 1000,
    int updatedAt = 1000,
    String mode = 'ccr',
    int? runtime = 3000,
    String? diverId,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: dateMs,
          createdAt: dateMs,
          updatedAt: updatedAt,
        ).copyWith(
          runtime: Value(runtime),
          diveMode: Value(mode),
          diverId: Value(diverId),
        ),
      );

  Future<void> insertDiver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion.insert(
          id: id,
          name: id,
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  Future<void> insertProfile(String diveId, List<ProfileSample> samples) =>
      ProfileSeriesRepository(db: db).insertSeries(
        diveId: diveId,
        samples: samples,
        now: 1000,
      );

  test('a dive without a row is computed and stored', () async {
    await insertDive('d1');
    await insertProfile('d1', const [
      ProfileSample(timestamp: 0, depth: 0, temperature: 10),
      ProfileSample(timestamp: 60, depth: 22, temperature: 4),
    ]);

    final summary = await repo.ensureCurrent('d1');
    expect(runs, 1);
    expect(summary, isNotNull);
    expect(summary!.maxDepth, 22);
    expect(summary.minTemperature, 4);
    expect(summary.sourceUpdatedAt, 1000);
    expect(summary.engineVersion, DiveSensorSummaryService.version);
    expect(summary.scrubberConsumedMinutes, 50);

    final stored = await repo.getSummary('d1');
    expect(stored, summary);
  });

  test('a current row is returned without recomputing', () async {
    await insertDive('d1');
    await repo.ensureCurrent('d1');
    await repo.ensureCurrent('d1');
    expect(runs, 1);
  });

  test('a row whose source_updated_at differs is recomputed', () async {
    await insertDive('d1', updatedAt: 1000);
    await repo.ensureCurrent('d1');
    await (db.update(db.dives)..where((t) => t.id.equals('d1'))).write(
      const DivesCompanion(updatedAt: Value(2000), maxDepth: Value(30)),
    );
    final summary = await repo.ensureCurrent('d1');
    expect(runs, 2);
    expect(summary!.sourceUpdatedAt, 2000);
  });

  test('a row from an older engine version is recomputed', () async {
    await insertDive('d1');
    await repo.ensureCurrent('d1');
    await (db.update(
      db.diveSensorSummaries,
    )..where((t) => t.diveId.equals('d1'))).write(
      const DiveSensorSummariesCompanion(engineVersion: Value(0)),
    );
    await repo.ensureCurrent('d1');
    expect(runs, 2);
  });

  test('force recomputes a current row', () async {
    await insertDive('d1');
    await repo.ensureCurrent('d1');
    await repo.ensureCurrent('d1', force: true);
    expect(runs, 2);
  });

  test('a missing dive yields null and writes nothing', () async {
    expect(await repo.ensureCurrent('nope'), isNull);
    expect(runs, 0);
    expect(await repo.getSummary('nope'), isNull);
  });

  test('tank series reach the worker with the tank identity', () async {
    await insertDive('d1');
    await insertProfile('d1', const [
      ProfileSample(timestamp: 0, depth: 0),
      ProfileSample(timestamp: 100, depth: 10),
    ]);
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(id: 't1', diveId: 'd1').copyWith(
            transmitterSerial: const Value('180777'),
            computerId: const Value.absent(),
          ),
        );
    await TankPressureSeriesRepository(db: db).insertSeries(
      diveId: 'd1',
      tankId: 't1',
      samples: const [
        TankPressureSample(timestamp: 0, pressure: 200),
        TankPressureSample(timestamp: 10, pressure: 199),
        TankPressureSample(timestamp: 20, pressure: 198),
        TankPressureSample(timestamp: 100, pressure: 190),
      ],
      now: 1000,
    );

    final summary = await repo.ensureCurrent('d1');
    final gap = summary!.transmitterGaps.single;
    expect(gap.tankId, 't1');
    expect(gap.transmitterSerial, '180777');
    expect(gap.gapCount, 1);
  });

  test('cell metrics and gaps round-trip through the row', () async {
    await insertDive('d1');
    await insertProfile('d1', const [
      ProfileSample(timestamp: 0, depth: 10, o2Sensor1: 1.0, o2Sensor2: 1.0),
      ProfileSample(timestamp: 10, depth: 10, o2Sensor1: 1.0, o2Sensor2: 1.0),
    ]);
    final computed = await repo.ensureCurrent('d1');
    expect(computed!.cellMetrics.map((m) => m.slot), [1, 2]);
    final stored = await repo.getSummary('d1');
    expect(stored!.cellMetrics, computed.cellMetrics);
  });

  test('deleting the dive removes the row', () async {
    await insertDive('d1');
    await repo.ensureCurrent('d1');
    await (db.delete(db.dives)..where((t) => t.id.equals('d1'))).go();
    expect(await repo.getSummary('d1'), isNull);
  });

  group('staleDiveIds', () {
    test('lists missing, stale-source and old-engine rows, oldest first', () async {
      await insertDive('missing', dateMs: 3000);
      await insertDive('current', dateMs: 1000);
      await insertDive('stale', dateMs: 2000);
      await insertDive('old', dateMs: 4000);
      await repo.ensureCurrent('current');
      await repo.ensureCurrent('stale');
      await repo.ensureCurrent('old');
      await (db.update(db.dives)..where((t) => t.id.equals('stale'))).write(
        const DivesCompanion(updatedAt: Value(9999)),
      );
      await (db.update(
        db.diveSensorSummaries,
      )..where((t) => t.diveId.equals('old'))).write(
        const DiveSensorSummariesCompanion(engineVersion: Value(0)),
      );

      expect(await repo.staleDiveIds(), ['stale', 'missing', 'old']);
      expect(await repo.countStale(), 3);
    });

    test('scopes to a diver when asked', () async {
      await insertDiver('a');
      await insertDiver('b');
      await insertDive('da', diverId: 'a');
      await insertDive('db', diverId: 'b');
      expect(await repo.staleDiveIds(diverId: 'a'), ['da']);
      expect(await repo.staleDiveIds(), ['da', 'db']);
    });
  });

  test('the default runner computes through compute', () async {
    await insertDive('d1');
    await insertProfile('d1', const [ProfileSample(timestamp: 0, depth: 9)]);
    final viaCompute = DiveSensorSummaryRepository(db: db);
    final summary = await viaCompute.ensureCurrent('d1');
    expect(summary!.maxDepth, 9);
  });

  test('saveSummary upserts by dive id', () async {
    await insertDive('d1');
    final first = DiveSensorSummary(
      diveId: 'd1',
      engineVersion: 1,
      sourceUpdatedAt: 1,
      computedAt: DateTime.utc(2026),
      maxDepth: 1,
    );
    await repo.saveSummary(first);
    await repo.saveSummary(
      DiveSensorSummary(
        diveId: 'd1',
        engineVersion: 1,
        sourceUpdatedAt: 2,
        computedAt: DateTime.utc(2026),
        maxDepth: 2,
      ),
    );
    final stored = await repo.getSummary('d1');
    expect(stored!.maxDepth, 2);
    expect(stored.sourceUpdatedAt, 2);
  });
}
```

Check the `DiversCompanion.insert` required fields against `lib/core/database/database.dart` (`class Divers`) and the `DiveTanksCompanion.insert` required fields (`class DiveTanks`, line 974); adjust the two helpers to whatever is `required`. `ProfileSeriesRepository` and `TankPressureSeriesRepository` take `{AppDatabase? db}`; confirm the constructor parameter name at the top of each file and adjust if it differs.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/data/repositories/dive_sensor_summary_repository_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 3: Write the repository**

```dart
// lib/features/equipment/data/repositories/dive_sensor_summary_repository.dart
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/database_service.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_worker.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';
import 'package:submersion/features/equipment/domain/services/dive_sensor_summary_service.dart';

/// Runs the worker. The default hops to an isolate through `compute`; tests
/// substitute a same-isolate runner to count invocations.
typedef SensorSummaryRunner =
    Future<DiveSensorSummary> Function(SensorSummaryWorkInput input);

Future<DiveSensorSummary> _computeOnIsolate(SensorSummaryWorkInput input) =>
    compute(computeSensorSummaryFromBlobs, input);

/// Owns `dive_sensor_summaries`: the device-local, per-dive cache of what
/// only a profile decode can produce. Never synced; a restore rebuilds it.
class DiveSensorSummaryRepository {
  final AppDatabase? _dbOverride;
  final SensorSummaryRunner _runner;

  DiveSensorSummaryRepository({AppDatabase? db, SensorSummaryRunner? runner})
    : _dbOverride = db,
      _runner = runner ?? _computeOnIsolate;

  AppDatabase get _db => _dbOverride ?? DatabaseService.instance.database;

  Future<DiveSensorSummary?> getSummary(String diveId) async {
    final row = await (_db.select(
      _db.diveSensorSummaries,
    )..where((t) => t.diveId.equals(diveId))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// The stored row when its engine version and source stamp match the
  /// dive, else a fresh computation, stored before it is returned. Null
  /// when [diveId] does not exist. [force] recomputes regardless.
  Future<DiveSensorSummary?> ensureCurrent(
    String diveId, {
    bool force = false,
  }) async {
    final dive = await (_db.select(
      _db.dives,
    )..where((t) => t.id.equals(diveId))).getSingleOrNull();
    if (dive == null) return null;

    if (!force) {
      final stored = await getSummary(diveId);
      if (stored != null &&
          stored.engineVersion >= DiveSensorSummaryService.version &&
          stored.sourceUpdatedAt == dive.updatedAt) {
        return stored;
      }
    }

    final primaryRows =
        await (_db.select(_db.diveProfileSeries)
              ..where((t) => t.diveId.equals(diveId) & t.isPrimary.equals(true))
              ..orderBy([
                (t) => OrderingTerm.asc(t.startTimestamp),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final tankRows = await (_db.select(
      _db.diveTanks,
    )..where((t) => t.diveId.equals(diveId))).get();
    final tankSeriesRows =
        await (_db.select(_db.tankPressureSeries)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm.asc(t.tankId)]))
            .get();
    final tanksById = {for (final t in tankRows) t.id: t};

    final summary = await _runner(
      SensorSummaryWorkInput(
        diveId: diveId,
        primaryBlobs: [for (final r in primaryRows) r.samples],
        tankBlobs: [
          for (final r in tankSeriesRows)
            TankSeriesBlob(
              tankId: r.tankId,
              transmitterSerial: tanksById[r.tankId]?.transmitterSerial,
              computerId: r.computerId ?? tanksById[r.tankId]?.computerId,
              samples: r.samples,
            ),
        ],
        diveMode: DiveMode.fromCode(dive.diveMode),
        runtimeSeconds: dive.runtime ?? dive.bottomTime,
        scrubberDurationMinutes: dive.scrubberDurationMinutes,
        scrubberRemainingMinutes: dive.scrubberRemainingMinutes,
        sourceUpdatedAt: dive.updatedAt,
        computedAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
    );
    await saveSummary(summary);
    return summary;
  }

  Future<void> saveSummary(DiveSensorSummary summary) => _db
      .into(_db.diveSensorSummaries)
      .insertOnConflictUpdate(
        DiveSensorSummariesCompanion.insert(
          diveId: summary.diveId,
          engineVersion: summary.engineVersion,
          sourceUpdatedAt: summary.sourceUpdatedAt,
          computedAt: summary.computedAt.millisecondsSinceEpoch,
          minTemperature: Value(summary.minTemperature),
          maxDepth: Value(summary.maxDepth),
          scrubberConsumedMinutes: Value(summary.scrubberConsumedMinutes),
          cellMetrics: Value(encodeCellMetrics(summary.cellMetrics)),
          transmitterGaps: Value(encodeTransmitterGaps(summary.transmitterGaps)),
        ),
      );

  /// Dives with no row, a row from an older engine, or a row whose source
  /// stamp no longer matches the dive; oldest dive first so a sweep primes
  /// the same order the safety review uses.
  Future<List<String>> staleDiveIds({String? diverId}) async {
    final rows = await _db
        .customSelect(
          'SELECT d.id AS id FROM dives d '
          'LEFT JOIN dive_sensor_summaries s ON s.dive_id = d.id '
          'WHERE (s.dive_id IS NULL OR s.engine_version < ? '
          'OR s.source_updated_at != d.updated_at)'
          '${diverId == null ? '' : ' AND d.diver_id = ?'} '
          'ORDER BY d.dive_date_time ASC, d.id ASC',
          variables: [
            Variable.withInt(DiveSensorSummaryService.version),
            if (diverId != null) Variable.withString(diverId),
          ],
          readsFrom: {_db.dives, _db.diveSensorSummaries},
        )
        .get();
    return [for (final r in rows) r.read<String>('id')];
  }

  Future<int> countStale({String? diverId}) async =>
      (await staleDiveIds(diverId: diverId)).length;

  DiveSensorSummary _toDomain(DiveSensorSummaryRow row) => DiveSensorSummary(
    diveId: row.diveId,
    engineVersion: row.engineVersion,
    sourceUpdatedAt: row.sourceUpdatedAt,
    computedAt: DateTime.fromMillisecondsSinceEpoch(row.computedAt, isUtc: true),
    minTemperature: row.minTemperature,
    maxDepth: row.maxDepth,
    scrubberConsumedMinutes: row.scrubberConsumedMinutes,
    cellMetrics: decodeCellMetrics(row.cellMetrics),
    transmitterGaps: decodeTransmitterGaps(row.transmitterGaps),
  );
}
```

Check the exact generated column and row field names in `lib/core/database/database.g.dart` (`class DiveSensorSummaryRow`, around line 50035) and the `dives` row fields (`runtime`, `bottomTime`, `diveMode`, `scrubberDurationMinutes`, `scrubberRemainingMinutes`, `updatedAt`); the Dives row class is Drift's default `Dive`, which is why `database.dart` is imported without a prefix here and no domain entity is imported.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/equipment/data/repositories/dive_sensor_summary_repository_test.dart`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/equipment/data/repositories/dive_sensor_summary_repository.dart test/features/equipment/data/repositories/dive_sensor_summary_repository_test.dart
git add lib/features/equipment/data/repositories/dive_sensor_summary_repository.dart test/features/equipment/data/repositories/dive_sensor_summary_repository_test.dart
git commit -m "feat(equipment): sensor summary repository with staleness-gated compute (condition phase 2)"
```

---

### Task 7: diveSensorSummaryProvider and the detail-change tick

**Files:**
- Create: `lib/features/equipment/presentation/providers/dive_sensor_summary_providers.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart:176-200` (`watchDiveDetailChanges` table list)
- Test: `test/features/equipment/presentation/providers/dive_sensor_summary_providers_test.dart`

**Interfaces:**
- Consumes: Task 6 repository; `diveRepositoryProvider` (`lib/features/dive_log/presentation/providers/dive_repository_provider.dart`); `ref.invalidateSelfWhen` (`lib/core/providers/provider.dart`).
- Produces: `diveSensorSummaryRepositoryProvider`, `diveSensorSummaryProvider = FutureProvider.family<DiveSensorSummary?, String>`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/presentation/providers/dive_sensor_summary_providers_test.dart
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_worker.dart';
import 'package:submersion/features/equipment/presentation/providers/dive_sensor_summary_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  var runs = 0;

  setUp(() async {
    db = await setUpTestDatabase();
    runs = 0;
    container = ProviderContainer(
      overrides: [
        diveSensorSummaryRepositoryProvider.overrideWithValue(
          DiveSensorSummaryRepository(
            db: db,
            runner: (input) async {
              runs++;
              return computeSensorSummaryFromBlobs(input);
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: 1000,
            createdAt: 1000,
            updatedAt: 1000,
          ).copyWith(runtime: const Value(600), diveMode: const Value('ccr')),
        );
  });

  tearDown(tearDownTestDatabase);

  test('computes on first read and serves the row afterwards', () async {
    final first = await container.read(diveSensorSummaryProvider('d1').future);
    expect(first!.scrubberConsumedMinutes, 10);
    expect(runs, 1);

    container.invalidate(diveSensorSummaryProvider('d1'));
    final second = await container.read(
      diveSensorSummaryProvider('d1').future,
    );
    expect(second, first);
    expect(runs, 1);
  });

  test('a dive write ticks the provider into a recompute', () async {
    final sub = container.listen(
      diveSensorSummaryProvider('d1'),
      (_, _) {},
    );
    addTearDown(sub.close);
    await container.read(diveSensorSummaryProvider('d1').future);
    expect(runs, 1);

    await (db.update(db.dives)..where((t) => t.id.equals('d1'))).write(
      const DivesCompanion(updatedAt: Value(2000), runtime: Value(1200)),
    );
    // The detail-change stream is debounced; poll rather than pump the
    // event queue (see the drift tick memory).
    for (var i = 0; i < 50 && runs < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final refreshed = await container.read(
      diveSensorSummaryProvider('d1').future,
    );
    expect(runs, 2);
    expect(refreshed!.scrubberConsumedMinutes, 20);
  });

  test('an unknown dive yields null', () async {
    expect(await container.read(diveSensorSummaryProvider('x').future), isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/presentation/providers/dive_sensor_summary_providers_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 3: Write the providers**

```dart
// lib/features/equipment/presentation/providers/dive_sensor_summary_providers.dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';

final diveSensorSummaryRepositoryProvider = Provider<DiveSensorSummaryRepository>(
  (ref) => DiveSensorSummaryRepository(),
);

/// Compute-through-cache: the stored summary when it is current for the
/// dive's version, otherwise a fresh one, stored before it is returned.
/// Null when the dive does not exist. Mirrors `safetyReviewProvider`.
///
/// Self-invalidates on the dive detail-change stream, which includes the
/// summaries table itself, so a sweep or a restore writing rows directly
/// reaches an open dive page without a restart.
final diveSensorSummaryProvider =
    FutureProvider.family<DiveSensorSummary?, String>((ref, diveId) async {
      final repo = ref.watch(diveSensorSummaryRepositoryProvider);
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
      );
      return repo.ensureCurrent(diveId);
    });
```

- [ ] **Step 4: Add the table to the detail-change stream**

In `lib/features/dive_log/data/repositories/dive_repository_impl.dart`, inside `watchDiveDetailChanges()`, after the line `TableUpdateQuery.onTable(_db.diveSafetyFindings),` add:

```dart
          // The sensor summary cache (phase 2): written by the sweep and the
          // scheduler outside any notifier, read by the chart host.
          TableUpdateQuery.onTable(_db.diveSensorSummaries),
```

Also extend the doc comment above the method with one sentence: "Also watches `dive_sensor_summaries`, which the condition sweep fills outside any notifier."

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/equipment/presentation/providers/dive_sensor_summary_providers_test.dart`
Expected: all tests pass. If the tick test times out, confirm the table was added to the stream in Step 4.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/equipment/presentation/providers/dive_sensor_summary_providers.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/equipment/presentation/providers/dive_sensor_summary_providers_test.dart
git add lib/features/equipment/presentation/providers/dive_sensor_summary_providers.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/equipment/presentation/providers/dive_sensor_summary_providers_test.dart
git commit -m "feat(equipment): diveSensorSummaryProvider computes through the cache (condition phase 2)"
```

---

### Task 8: EquipmentConditionSweep

**Files:**
- Create: `lib/features/equipment/presentation/providers/equipment_condition_sweep.dart`
- Test: `test/features/equipment/presentation/providers/equipment_condition_sweep_test.dart`

**Interfaces:**
- Consumes: Task 6 repository through `diveSensorSummaryRepositoryProvider`; `diveRepositoryProvider.getOrderedDiveIds({diverId, sort})` and `SafetyReviewSweep.oldestFirstSort`.
- Produces:
  - `EquipmentConditionSweepResult({swept, failed, cancelled})`, `static const empty`
  - `EquipmentConditionSweep(Ref)`, `Future<EquipmentConditionSweepResult> run({String? diverId, List<String>? diveIds, bool force = false, void Function(int done, int total)? onProgress, bool Function()? isCancelled})`
  - `equipmentConditionSweepProvider`

Behaviour: without `diveIds`, the sweep visits `staleDiveIds(diverId)` when `force` is false and every dive of the diver (oldest first) when `force` is true. Each dive goes through `ensureCurrent(id, force: force)`; a throw counts as failed and does not abort. Progress and cancel follow `SafetyReviewSweep` exactly.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/presentation/providers/equipment_condition_sweep_test.dart
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_worker.dart';
import 'package:submersion/features/equipment/presentation/providers/dive_sensor_summary_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_sweep.dart';

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  final visited = <String>[];
  var failOn = <String>{};

  setUp(() async {
    db = await setUpTestDatabase();
    visited.clear();
    failOn = {};
    container = ProviderContainer(
      overrides: [
        diveSensorSummaryRepositoryProvider.overrideWithValue(
          DiveSensorSummaryRepository(
            db: db,
            runner: (input) async {
              visited.add(input.diveId);
              if (failOn.contains(input.diveId)) {
                throw StateError('boom ${input.diveId}');
              }
              return computeSensorSummaryFromBlobs(input);
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    for (final (id, date) in [('d1', 1000), ('d2', 2000), ('d3', 3000)]) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: date,
              createdAt: date,
              updatedAt: date,
            ).copyWith(runtime: const Value(600)),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  EquipmentConditionSweep sweep() =>
      container.read(equipmentConditionSweepProvider);

  test('visits stale dives oldest first and reports progress', () async {
    final progress = <(int, int)>[];
    final result = await sweep().run(
      onProgress: (done, total) => progress.add((done, total)),
    );
    expect(visited, ['d1', 'd2', 'd3']);
    expect(result.swept, 3);
    expect(result.failed, 0);
    expect(result.cancelled, isFalse);
    expect(progress, [(0, 3), (1, 3), (2, 3), (3, 3)]);
  });

  test('a second pass without force visits nothing', () async {
    await sweep().run();
    visited.clear();
    final result = await sweep().run();
    expect(visited, isEmpty);
    expect(result.swept, 0);
  });

  test('force visits every dive again', () async {
    await sweep().run();
    visited.clear();
    final result = await sweep().run(force: true);
    expect(visited, ['d1', 'd2', 'd3']);
    expect(result.swept, 3);
  });

  test('explicit dive ids are visited as given', () async {
    final result = await sweep().run(diveIds: ['d3', 'd1']);
    expect(visited, ['d3', 'd1']);
    expect(result.swept, 2);
  });

  test('a failing dive is counted and does not stop the sweep', () async {
    failOn = {'d2'};
    final result = await sweep().run();
    expect(visited, ['d1', 'd2', 'd3']);
    expect(result.swept, 3);
    expect(result.failed, 1);
  });

  test('cancel is polled before each dive', () async {
    var calls = 0;
    final result = await sweep().run(isCancelled: () => ++calls > 2);
    expect(visited, ['d1', 'd2']);
    expect(result.swept, 2);
    expect(result.cancelled, isTrue);
  });

  test('scopes to a diver', () async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(id: 'a', name: 'a', createdAt: 1, updatedAt: 1),
        );
    await (db.update(db.dives)..where((t) => t.id.equals('d2'))).write(
      const DivesCompanion(diverId: Value('a')),
    );
    final result = await sweep().run(diverId: 'a');
    expect(visited, ['d2']);
    expect(result.swept, 1);
  });
}
```

Adjust `DiversCompanion.insert` to the required fields found in Task 6.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/presentation/providers/equipment_condition_sweep_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 3: Write the sweep**

```dart
// lib/features/equipment/presentation/providers/equipment_condition_sweep.dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_sweep.dart';
import 'package:submersion/features/equipment/presentation/providers/dive_sensor_summary_providers.dart';

/// Outcome of an [EquipmentConditionSweep.run].
class EquipmentConditionSweepResult {
  /// Dives visited, including those that failed. Mirrors the progress bar.
  final int swept;

  /// Dives whose summary threw. They stay stale and recompute lazily.
  final int failed;

  /// True when the caller's isCancelled callback stopped the sweep early.
  final bool cancelled;

  const EquipmentConditionSweepResult({
    required this.swept,
    required this.failed,
    required this.cancelled,
  });

  static const empty = EquipmentConditionSweepResult(
    swept: 0,
    failed: 0,
    cancelled: false,
  );
}

/// Brings `dive_sensor_summaries` up to date over a logbook, one dive at a
/// time, oldest first. Shared by the settings action, the post-restore
/// pass and the startup scheduler so the visit order and the cancel
/// contract live in one place. Same shape as [SafetyReviewSweep].
class EquipmentConditionSweep {
  final Ref _ref;

  const EquipmentConditionSweep(this._ref);

  /// Visits exactly [diveIds] when supplied; otherwise the stale dives of
  /// [diverId] (null means every diver), or every dive when [force] is
  /// true. [force] also recomputes rows that are current.
  ///
  /// [onProgress] fires once with (0, total), then after each dive.
  /// [isCancelled] is polled before each dive; cancelling is lossless, an
  /// unvisited dive computes lazily on first view.
  Future<EquipmentConditionSweepResult> run({
    String? diverId,
    List<String>? diveIds,
    bool force = false,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final repo = _ref.read(diveSensorSummaryRepositoryProvider);
    final ids =
        diveIds ??
        (force
            ? await _ref
                  .read(diveRepositoryProvider)
                  .getOrderedDiveIds(
                    diverId: diverId,
                    sort: SafetyReviewSweep.oldestFirstSort,
                  )
            : await repo.staleDiveIds(diverId: diverId));

    final total = ids.length;
    onProgress?.call(0, total);

    var swept = 0;
    var failed = 0;
    for (final diveId in ids) {
      if (isCancelled?.call() ?? false) {
        return EquipmentConditionSweepResult(
          swept: swept,
          failed: failed,
          cancelled: true,
        );
      }
      try {
        await repo.ensureCurrent(diveId, force: force);
      } catch (_) {
        // A corrupt series must not abort the pass; the dive stays stale
        // and is counted so the caller can say so.
        failed++;
      }
      swept++;
      onProgress?.call(swept, total);
    }
    return EquipmentConditionSweepResult(
      swept: swept,
      failed: failed,
      cancelled: false,
    );
  }
}

final equipmentConditionSweepProvider = Provider<EquipmentConditionSweep>(
  (ref) => EquipmentConditionSweep(ref),
);
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/equipment/presentation/providers/equipment_condition_sweep_test.dart`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/equipment/presentation/providers/equipment_condition_sweep.dart test/features/equipment/presentation/providers/equipment_condition_sweep_test.dart
git add lib/features/equipment/presentation/providers/equipment_condition_sweep.dart test/features/equipment/presentation/providers/equipment_condition_sweep_test.dart
git commit -m "feat(equipment): condition sweep over stale sensor summaries (condition phase 2)"
```

---

### Task 9: SensorSummaryScheduler and the refresh hooks

**Files:**
- Create: `lib/features/equipment/data/services/sensor_summary_scheduler.dart`
- Modify: `test/flutter_test_config.dart`
- Modify (one line beside each `scheduleQualityScan` call):
  - `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart:650`
  - `lib/features/import_wizard/data/adapters/suunto_cloud_adapter.dart:410`
  - `lib/features/import_wizard/data/adapters/garmin_cloud_adapter.dart:410`
  - `lib/features/import_wizard/data/adapters/healthkit_adapter.dart:297`
  - `lib/features/import_wizard/data/adapters/universal_adapter.dart:795`
  - `lib/features/dive_log/presentation/pages/dive_edit_page.dart:1964` and `:5293`
  - `lib/features/dive_log/presentation/pages/dive_detail_page.dart:5262` and `:5311`
  - `lib/features/dive_log/presentation/widgets/run_dive_consolidation.dart:50` and `:67`
- Modify: `lib/features/dive_computer/data/services/reparse_service.dart` (`reparseDive`, line 377)
- Test: `test/features/equipment/data/services/sensor_summary_scheduler_test.dart`

**Interfaces:**
- Consumes: `LoggerService` (`lib/core/services/logger_service.dart`); Task 6 repository.
- Produces: `SensorSummaryScheduler.instance`, `static bool enabled`, `Future<void> get idle` (`@visibleForTesting`), `void schedule(Set<String> diveIds)`, `void scheduleStaleSweep()`, `@visibleForTesting DiveSensorSummaryRepository Function() repositoryFactory`; top-level `void scheduleSensorSummaryRefresh(Iterable<String> diveIds)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/data/services/sensor_summary_scheduler_test.dart
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_worker.dart';

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final visited = <String>[];

  setUp(() async {
    db = await setUpTestDatabase();
    visited.clear();
    SensorSummaryScheduler.enabled = true;
    SensorSummaryScheduler.instance.repositoryFactory = () =>
        DiveSensorSummaryRepository(
          db: db,
          runner: (input) async {
            visited.add(input.diveId);
            return computeSensorSummaryFromBlobs(input);
          },
        );
    addTearDown(() {
      SensorSummaryScheduler.enabled = false;
      SensorSummaryScheduler.instance.repositoryFactory =
          SensorSummaryScheduler.defaultRepositoryFactory;
    });
    for (final (id, date) in [('d1', 1000), ('d2', 2000)]) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: date,
              createdAt: date,
              updatedAt: date,
            ).copyWith(runtime: const Value(600)),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  test('schedule refreshes the given dives once, merging bursts', () async {
    scheduleSensorSummaryRefresh(['d1']);
    scheduleSensorSummaryRefresh(['d1', 'd2']);
    await SensorSummaryScheduler.instance.idle;
    expect(visited.toSet(), {'d1', 'd2'});
    expect(visited.length, lessThanOrEqualTo(3));
  });

  test('a scheduled dive that is already current is not recomputed', () async {
    scheduleSensorSummaryRefresh(['d1']);
    await SensorSummaryScheduler.instance.idle;
    scheduleSensorSummaryRefresh(['d1']);
    await SensorSummaryScheduler.instance.idle;
    expect(visited, ['d1']);
  });

  test('scheduleStaleSweep visits every stale dive', () async {
    SensorSummaryScheduler.instance.scheduleStaleSweep();
    await SensorSummaryScheduler.instance.idle;
    expect(visited, ['d1', 'd2']);
  });

  test('disabled means no work', () async {
    SensorSummaryScheduler.enabled = false;
    scheduleSensorSummaryRefresh(['d1']);
    SensorSummaryScheduler.instance.scheduleStaleSweep();
    await SensorSummaryScheduler.instance.idle;
    expect(visited, isEmpty);
  });

  test('a failing dive does not poison the queue', () async {
    SensorSummaryScheduler.instance.repositoryFactory = () =>
        DiveSensorSummaryRepository(
          db: db,
          runner: (input) async {
            visited.add(input.diveId);
            if (input.diveId == 'd1') throw StateError('boom');
            return computeSensorSummaryFromBlobs(input);
          },
        );
    scheduleSensorSummaryRefresh(['d1']);
    scheduleSensorSummaryRefresh(['d2']);
    await SensorSummaryScheduler.instance.idle;
    expect(visited, containsAll(['d1', 'd2']));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/data/services/sensor_summary_scheduler_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 3: Write the scheduler**

```dart
// lib/features/equipment/data/services/sensor_summary_scheduler.dart
import 'package:flutter/foundation.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';

/// Fire-and-forget entry point for the hooks that change a dive's profile
/// or tanks: downloads, re-parses, saves, splits and consolidations.
/// Serialises work (single-flight) and merges bursts of requests, like
/// `QualityScanScheduler`, which it is called beside.
class SensorSummaryScheduler {
  SensorSummaryScheduler._();
  static final SensorSummaryScheduler instance = SensorSummaryScheduler._();

  /// Widget tests that drive save flows against a fake-async zone set this
  /// to false (flutter_test_config does) to keep Drift work out of the zone.
  static bool enabled = true;

  static const _log = LoggerService('SensorSummaryScheduler');

  static DiveSensorSummaryRepository defaultRepositoryFactory() =>
      DiveSensorSummaryRepository();

  /// Tests substitute a repository bound to their in-memory database.
  @visibleForTesting
  DiveSensorSummaryRepository Function() repositoryFactory =
      defaultRepositoryFactory;

  Future<void> _tail = Future.value();
  final Set<String> _pending = {};
  bool _staleSweepPending = false;

  @visibleForTesting
  Future<void> get idle => _tail;

  /// Refreshes [diveIds] whose row is missing or stale.
  void schedule(Set<String> diveIds) {
    if (!enabled || diveIds.isEmpty) return;
    _pending.addAll(diveIds);
    _enqueue();
  }

  /// Refreshes every dive whose row is missing or stale: the startup
  /// backfill and the post-restore rebuild.
  void scheduleStaleSweep() {
    if (!enabled) return;
    _staleSweepPending = true;
    _enqueue();
  }

  void _enqueue() {
    _tail = _tail.then((_) async {
      final ids = Set.of(_pending);
      _pending.clear();
      final sweep = _staleSweepPending;
      _staleSweepPending = false;
      if (ids.isEmpty && !sweep) return;
      final repo = repositoryFactory();
      if (sweep) {
        try {
          ids.addAll(await repo.staleDiveIds());
        } catch (e, st) {
          _log.error('Stale sensor summary query failed', error: e, stackTrace: st);
        }
      }
      for (final id in ids) {
        try {
          await repo.ensureCurrent(id);
        } catch (e, st) {
          _log.error(
            'Scheduled sensor summary failed for $id',
            error: e,
            stackTrace: st,
          );
        }
      }
    });
  }
}

void scheduleSensorSummaryRefresh(Iterable<String> diveIds) =>
    SensorSummaryScheduler.instance.schedule(diveIds.toSet());
```

Check `LoggerService.error` takes named `error:` and `stackTrace:` (it does in `quality_scan_service.dart:213`).

- [ ] **Step 4: Disable it for the test suite**

In `test/flutter_test_config.dart` add the import and the line beside the quality-scan one:

```dart
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
```

```dart
  QualityScanScheduler.enabled = false;
  SensorSummaryScheduler.enabled = false;
```

Extend the doc comment with: "The sensor summary scheduler (phase 2 of the condition program) is disabled for the same reason; `sensor_summary_scheduler_test` opts back in."

- [ ] **Step 5: Run the scheduler test to verify it passes**

Run: `flutter test test/features/equipment/data/services/sensor_summary_scheduler_test.dart`
Expected: all tests pass.

- [ ] **Step 6: Add the hook beside each quality-scan call**

In each listed file, add the import

```dart
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
```

and directly after each `scheduleQualityScan(...)` line add the same call with the same argument:

| File | After | Add |
| --- | --- | --- |
| `dive_computer_adapter.dart:650` | `scheduleQualityScan(importedDiveIds);` | `scheduleSensorSummaryRefresh(importedDiveIds);` |
| `suunto_cloud_adapter.dart:410` | `scheduleQualityScan(importedDiveIds);` | `scheduleSensorSummaryRefresh(importedDiveIds);` |
| `garmin_cloud_adapter.dart:410` | `scheduleQualityScan(importedDiveIds);` | `scheduleSensorSummaryRefresh(importedDiveIds);` |
| `healthkit_adapter.dart:297` | `scheduleQualityScan(importedDiveIds);` | `scheduleSensorSummaryRefresh(importedDiveIds);` |
| `universal_adapter.dart:795` | `scheduleQualityScan(netImportedDiveIds);` | `scheduleSensorSummaryRefresh(netImportedDiveIds);` |
| `dive_edit_page.dart:1964` | `scheduleQualityScan(ids);` | `scheduleSensorSummaryRefresh(ids);` |
| `dive_edit_page.dart:5293` | `scheduleQualityScan([savedDiveId]);` | `scheduleSensorSummaryRefresh([savedDiveId]);` |
| `dive_detail_page.dart:5262` | `scheduleQualityScan([dive.id, newDiveId]);` | `scheduleSensorSummaryRefresh([dive.id, newDiveId]);` |
| `dive_detail_page.dart:5311` | `scheduleQualityScan([dive.id, ...newDiveIds]);` | `scheduleSensorSummaryRefresh([dive.id, ...newDiveIds]);` |
| `run_dive_consolidation.dart:50` | `scheduleQualityScan([targetDiveId, ...secondaryDiveIds]);` | `scheduleSensorSummaryRefresh([targetDiveId, ...secondaryDiveIds]);` |
| `run_dive_consolidation.dart:67` | same, inside the Undo action | same |

Line numbers are those at the time of writing; locate each by the `scheduleQualityScan` text.

- [ ] **Step 7: Hook the re-parse**

In `lib/features/dive_computer/data/services/reparse_service.dart`, add the import above and, in `reparseDive` (line 377), change the final `return` so a re-parse that touched at least one source queues the refresh:

```dart
    if (sources.isNotEmpty) scheduleSensorSummaryRefresh([diveId]);
    return (errors: errors, profilesPreserved: profilesPreserved);
```

`reparseAllForComputer` calls `reparseDive` per dive, so the bulk path is covered by the same line.

- [ ] **Step 8: Analyze and run the touched tests**

Run:

```bash
flutter analyze
flutter test test/features/dive_log/presentation/widgets/run_dive_consolidation_test.dart test/features/dive_computer/data/services test/features/import_wizard
```

Expected: `No issues found!` and all tests pass (the scheduler is disabled by the test config, so no hook does work).

- [ ] **Step 9: Commit**

```bash
dart format .
git add lib/features/equipment/data/services/sensor_summary_scheduler.dart test/features/equipment/data/services/sensor_summary_scheduler_test.dart test/flutter_test_config.dart lib/features/import_wizard/data/adapters/dive_computer_adapter.dart lib/features/import_wizard/data/adapters/suunto_cloud_adapter.dart lib/features/import_wizard/data/adapters/garmin_cloud_adapter.dart lib/features/import_wizard/data/adapters/healthkit_adapter.dart lib/features/import_wizard/data/adapters/universal_adapter.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/dive_log/presentation/widgets/run_dive_consolidation.dart lib/features/dive_computer/data/services/reparse_service.dart
git commit -m "feat(equipment): refresh sensor summaries after downloads, saves, splits, merges and re-parses (condition phase 2)"
```

---

### Task 10: Startup backfill and post-restore rebuild

**Files:**
- Modify: `lib/app.dart:111-116` (post-frame callback)
- Modify: `lib/features/backup/presentation/providers/backup_providers.dart:357` and `:554` (after each `await _runPostRestoreSafetyReview();`)

**Interfaces:**
- Consumes: `SensorSummaryScheduler.instance.scheduleStaleSweep()` (Task 9).

No new test: both are one-line calls into a scheduler already covered, and both call sites are exercised only by integration paths. The existing `test/features/backup` and app tests must keep passing with the scheduler disabled.

- [ ] **Step 1: Startup**

In `lib/app.dart`, add the import

```dart
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
```

and inside the `addPostFrameCallback` at line 111, after `_republishOwnedMedia();`:

```dart
      // Fill the per-dive sensor summary cache for dives that predate it or
      // changed since. Single-flight, oldest first, no-op when current.
      SensorSummaryScheduler.instance.scheduleStaleSweep();
```

- [ ] **Step 2: Post-restore**

In `lib/features/backup/presentation/providers/backup_providers.dart`, add the same import and, after each of the two `await _runPostRestoreSafetyReview();` lines (357 and 554):

```dart
      // The restored library carries its own summary rows, or none; either
      // way a stale sweep brings them up to this build. Runs in the
      // background so the restore barrier does not wait on it.
      SensorSummaryScheduler.instance.scheduleStaleSweep();
```

- [ ] **Step 3: Analyze and run the backup tests**

Run:

```bash
flutter analyze
flutter test test/features/backup test/app_test.dart
```

(Skip `test/app_test.dart` if it does not exist; run `ls test/*.dart` to find the app-level test.) Expected: clean analyze, tests pass.

- [ ] **Step 4: Commit**

```bash
dart format lib/app.dart lib/features/backup/presentation/providers/backup_providers.dart
git add lib/app.dart lib/features/backup/presentation/providers/backup_providers.dart
git commit -m "feat(equipment): backfill sensor summaries at launch and after a restore (condition phase 2)"
```

---

### Task 11: "Rebuild sensor summaries" in the Equipment condition settings

**Files:**
- Modify: `lib/features/settings/presentation/pages/equipment_condition_settings_page.dart`
- Modify: the 11 ARB files
- Test: `test/features/settings/presentation/pages/equipment_condition_settings_page_test.dart`

**Interfaces:**
- Consumes: `equipmentConditionSweepProvider` (Task 8); `currentDiverIdProvider` (grep `final currentDiverIdProvider` under `lib/features`); `LoggerService`.
- Produces: seven l10n keys (below); the page becomes a `ConsumerStatefulWidget`.

- [ ] **Step 1: Add the English keys**

In `lib/l10n/arb/app_en.arb`, immediately after `"equipmentConditionSettings_saveFailed"` (line 17132, alphabetical order within the prefix is already broken by phase 1, so keep the block together):

```json
  "equipmentConditionSettings_sensorHeader": "Sensor summaries",
  "equipmentConditionSettings_sensorHelp": "Each dive's profile is summarised once for cell output, transmitter dropouts and scrubber use. New and edited dives are summarised on their own.",
  "equipmentConditionSettings_rebuild": "Rebuild sensor summaries",
  "equipmentConditionSettings_rebuild_subtitle": "Recompute every dive's summary from its profile",
  "equipmentConditionSettings_rebuild_progress": "Summarised {done} of {total}",
  "@equipmentConditionSettings_rebuild_progress": {
    "placeholders": {
      "done": {"type": "int"},
      "total": {"type": "int"}
    }
  },
  "equipmentConditionSettings_rebuild_done": "Sensor summaries rebuilt",
  "equipmentConditionSettings_rebuild_doneWithErrors": "Sensor summaries rebuilt; {count, plural, =1{1 dive could not be summarised} other{{count} dives could not be summarised}}",
  "@equipmentConditionSettings_rebuild_doneWithErrors": {
    "placeholders": {
      "count": {"type": "int"}
    }
  },
  "equipmentConditionSettings_rebuild_failed": "Could not rebuild the sensor summaries.",
```

Match the surrounding file's `@` metadata style (check how `safetySettings_analyzeAll_progress` declares its placeholders at line 9678 and copy that shape exactly).

- [ ] **Step 2: Add the ten translations**

Insert the same seven keys (and their `@` entries) after `"equipmentConditionSettings_saveFailed"` in each other ARB file, using the Translation Appendix at the end of this plan.

- [ ] **Step 3: Regenerate**

Run: `flutter gen-l10n`
Expected: no errors; `lib/l10n/arb/app_localizations.dart` gains the getters.

- [ ] **Step 4: Write the failing widget test**

Append to `test/features/settings/presentation/pages/equipment_condition_settings_page_test.dart` (read the file first; reuse its `_build` helper and `MockSettingsNotifier` import, and add these imports):

```dart
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_sweep.dart';
```

```dart
  group('rebuild sensor summaries', () {
    testWidgets('runs a forced sweep for the active diver and reports', (
      tester,
    ) async {
      var forced = false;
      String? diverSeen;
      final notifier = MockSettingsNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => notifier),
            equipmentConditionSweepProvider.overrideWithValue(
              _FakeSweep((diverId, force, onProgress) async {
                forced = force;
                diverSeen = diverId;
                onProgress?.call(0, 2);
                onProgress?.call(2, 2);
                return const EquipmentConditionSweepResult(
                  swept: 2,
                  failed: 0,
                  cancelled: false,
                );
              }),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: EquipmentConditionSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rebuild sensor summaries'), findsOneWidget);
      await tester.tap(find.text('Rebuild sensor summaries'));
      await tester.pumpAndSettle();

      expect(forced, isTrue);
      expect(diverSeen, isNull);
      expect(find.text('Sensor summaries rebuilt'), findsOneWidget);
    });

    testWidgets('a failing sweep shows the failure text', (tester) async {
      final notifier = MockSettingsNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => notifier),
            equipmentConditionSweepProvider.overrideWithValue(
              _FakeSweep((_, _, _) async => throw StateError('no db')),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: EquipmentConditionSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rebuild sensor summaries'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not rebuild the sensor summaries.'),
        findsOneWidget,
      );
    });
  });
```

And the fake at the bottom of the file:

```dart
class _FakeSweep implements EquipmentConditionSweep {
  final Future<EquipmentConditionSweepResult> Function(
    String? diverId,
    bool force,
    void Function(int, int)? onProgress,
  )
  _run;

  _FakeSweep(this._run);

  @override
  Future<EquipmentConditionSweepResult> run({
    String? diverId,
    List<String>? diveIds,
    bool force = false,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) => _run(diverId, force, onProgress);
}
```

`currentDiverIdProvider` resolves to null in the base test scope, which is why `diverSeen` is expected null; if the existing test file already overrides a diver, expect that id instead.

- [ ] **Step 5: Run the test to verify it fails**

Run: `flutter test test/features/settings/presentation/pages/equipment_condition_settings_page_test.dart`
Expected: FAIL, `Rebuild sensor summaries` not found.

- [ ] **Step 6: Convert the page and add the section**

Rewrite the top of `equipment_condition_settings_page.dart`: the class becomes a `ConsumerStatefulWidget` with a `_EquipmentConditionSettingsPageState`; the existing `build` body moves into the state unchanged except for the new section appended to the `ListView` children. Add the imports:

```dart
import 'package:submersion/core/providers/current_diver_provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_sweep.dart';
```

(Locate `currentDiverIdProvider` with `grep -rn "final currentDiverIdProvider" lib` and import that file.)

State fields and the section:

```dart
class _EquipmentConditionSettingsPageState
    extends ConsumerState<EquipmentConditionSettingsPage> {
  static const _log = LoggerService('EquipmentConditionSettingsPage');

  bool _rebuilding = false;
  int _rebuildDone = 0;
  int _rebuildTotal = 0;

  @override
  Widget build(BuildContext context) {
    // ... existing body, then after the O2 threshold field:
          const SizedBox(height: 24),
          Text(
            l10n.equipmentConditionSettings_sensorHeader,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.equipmentConditionSettings_sensorHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          ListTile(
            key: const Key('rebuild-sensor-summaries'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.sensors),
            title: Text(l10n.equipmentConditionSettings_rebuild),
            subtitle: _rebuilding
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.equipmentConditionSettings_rebuild_progress(
                          _rebuildDone,
                          _rebuildTotal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: _rebuildTotal == 0
                            ? null
                            : _rebuildDone / _rebuildTotal,
                      ),
                    ],
                  )
                : Text(l10n.equipmentConditionSettings_rebuild_subtitle),
            enabled: !_rebuilding,
            onTap: _rebuilding ? null : _rebuildSummaries,
          ),
  }

  Future<void> _rebuildSummaries() async {
    final diverId = ref.read(currentDiverIdProvider);
    setState(() {
      _rebuilding = true;
      _rebuildDone = 0;
      _rebuildTotal = 0;
    });

    final EquipmentConditionSweepResult result;
    try {
      result = await ref
          .read(equipmentConditionSweepProvider)
          .run(
            diverId: diverId,
            force: true,
            onProgress: (done, total) {
              if (!mounted) return;
              setState(() {
                _rebuildDone = done;
                _rebuildTotal = total;
              });
            },
            isCancelled: () => !mounted,
          );
    } catch (error, stackTrace) {
      _log.error(
        'Sensor summary rebuild failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() => _rebuilding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.equipmentConditionSettings_rebuild_failed),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _rebuilding = false);
    if (result.cancelled) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.failed == 0
              ? context.l10n.equipmentConditionSettings_rebuild_done
              : context.l10n.equipmentConditionSettings_rebuild_doneWithErrors(
                  result.failed,
                ),
        ),
      ),
    );
  }
}
```

Update the class doc comment: "Phase 2 adds the sensor summary rebuild; phase 3 adds the condition engine toggles."

- [ ] **Step 7: Run the settings tests and the ARB parity gate**

Run:

```bash
flutter test test/features/settings/presentation/pages/equipment_condition_settings_page_test.dart test/l10n
```

Expected: all pass, including `arb_parity_test` (every locale has every key, placeholders match).

- [ ] **Step 8: Commit**

```bash
dart format lib/features/settings/presentation/pages/equipment_condition_settings_page.dart test/features/settings/presentation/pages/equipment_condition_settings_page_test.dart
git add lib/features/settings/presentation/pages/equipment_condition_settings_page.dart test/features/settings/presentation/pages/equipment_condition_settings_page_test.dart lib/l10n/arb/app_ar.arb lib/l10n/arb/app_de.arb lib/l10n/arb/app_en.arb lib/l10n/arb/app_es.arb lib/l10n/arb/app_fr.arb lib/l10n/arb/app_he.arb lib/l10n/arb/app_hu.arb lib/l10n/arb/app_it.arb lib/l10n/arb/app_nl.arb lib/l10n/arb/app_pt.arb lib/l10n/arb/app_zh.arb
git status --short lib/l10n
```

If `git status` shows generated files under `lib/l10n` that are tracked (check with `git ls-files lib/l10n | grep -v arb/app_` ), stage them too, then:

```bash
git commit -m "feat(settings): rebuild sensor summaries from the equipment condition section (condition phase 2)"
```

---

### Task 12: Cell divergence bands on the profile chart

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/cell_divergence_highlight.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (new `secondaryRanges` parameter; `_buildHighlightRangeAnnotations` at line 6704)
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart_host.dart` (around line 412)
- Test: `test/features/dive_log/presentation/widgets/cell_divergence_highlight_test.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_secondary_ranges_test.dart`

**Interfaces:**
- Consumes: `ProfileHighlightRange` (`profile_highlight_range.dart`), `highlightBandSpan`, `DiveSensorSummary`, `diveSensorSummaryProvider`, the chart's `_showO2CellMv` flag (line 663, synced from the legend at line 2133), `MockSettingsNotifier(const AppSettings(defaultShowO2CellMv: true))` to seed the legend on in tests.
- Produces: `List<ProfileHighlightRange> cellDivergenceHighlightRanges(DiveSensorSummary? summary, ColorScheme scheme)`; `DiveProfileChart.secondaryRanges` (`List<ProfileHighlightRange>`, default `const []`).

- [ ] **Step 1: Write the failing helper test**

```dart
// test/features/dive_log/presentation/widgets/cell_divergence_highlight_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/cell_divergence_highlight.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';

void main() {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);

  test('null or empty summaries map to no ranges', () {
    expect(cellDivergenceHighlightRanges(null, scheme), isEmpty);
    expect(
      cellDivergenceHighlightRanges(
        DiveSensorSummary(
          diveId: 'd',
          engineVersion: 1,
          sourceUpdatedAt: 1,
          computedAt: DateTime.utc(2026),
        ),
        scheme,
      ),
      isEmpty,
    );
  });

  test('every slot range becomes a highlight, sorted by start', () {
    final ranges = cellDivergenceHighlightRanges(
      DiveSensorSummary(
        diveId: 'd',
        engineVersion: 1,
        sourceUpdatedAt: 1,
        computedAt: DateTime.utc(2026),
        cellMetrics: const [
          CellMetrics(
            slot: 2,
            samples: 10,
            divergenceRanges: [
              DivergenceRange(startSeconds: 600, endSeconds: 700, peakBar: 0.2),
            ],
          ),
          CellMetrics(
            slot: 1,
            samples: 10,
            divergenceRanges: [
              DivergenceRange(startSeconds: 100, endSeconds: 200, peakBar: 0.15),
              DivergenceRange(startSeconds: 900, endSeconds: 950, peakBar: 0.11),
            ],
          ),
        ],
      ),
      scheme,
    );
    expect(ranges.map((r) => r.startTimestamp), [100, 600, 900]);
    expect(ranges.map((r) => r.endTimestamp), [200, 700, 950]);
    expect(ranges.every((r) => r.color == scheme.error), isTrue);
  });
}
```

- [ ] **Step 2: Write the failing chart test**

```dart
// test/features/dive_log/presentation/widgets/dive_profile_chart_secondary_ranges_test.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_highlight_range.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  final profile = List.generate(
    10,
    (i) => DiveProfilePoint(
      timestamp: i * 30,
      depth: i < 5 ? i * 3.0 : (10 - i) * 3.0,
      o2Sensor1: 1.0,
      o2Sensor2: 1.0,
      o2SensorMv1: 50,
      o2SensorMv2: 50,
    ),
  );

  const secondary = [
    ProfileHighlightRange(startTimestamp: 30, endTimestamp: 90, color: Colors.red),
    ProfileHighlightRange(startTimestamp: 150, endTimestamp: 210, color: Colors.red),
  ];

  Future<void> pumpChart(
    WidgetTester tester, {
    required bool cellOverlayOn,
    ProfileHighlightRange? highlightRange,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(
              AppSettings(defaultShowO2CellMv: cellOverlayOn),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: DiveProfileChart(
                profile: profile,
                o2SensorCurves: const [
                  [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
                  [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
                ],
                o2CellMvCurves: const [
                  [50, 50, 50, 50, 50, 50, 50, 50, 50, 50],
                  [50, 50, 50, 50, 50, 50, 50, 50, 50, 50],
                ],
                highlightRange: highlightRange,
                secondaryRanges: secondary,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  LineChartData chartData(WidgetTester tester) =>
      tester.widget<LineChart>(find.byType(LineChart).first).data;

  testWidgets('secondary ranges are hidden while the cell overlay is off', (
    tester,
  ) async {
    await pumpChart(tester, cellOverlayOn: false);
    expect(chartData(tester).rangeAnnotations.verticalRangeAnnotations, isEmpty);
  });

  testWidgets('secondary ranges draw as bands when the cell overlay is on', (
    tester,
  ) async {
    await pumpChart(tester, cellOverlayOn: true);
    final annotations = chartData(tester).rangeAnnotations.verticalRangeAnnotations;
    expect(annotations, hasLength(2));
    expect(annotations.map((a) => a.x1), [30, 150]);
    expect(annotations.map((a) => a.x2), [90, 210]);
    // Bands only: no edge lines, unlike the primary highlight.
    expect(chartData(tester).extraLinesData.verticalLines, isEmpty);
  });

  testWidgets('the primary highlight is drawn after the secondary bands', (
    tester,
  ) async {
    await pumpChart(
      tester,
      cellOverlayOn: true,
      highlightRange: const ProfileHighlightRange(
        startTimestamp: 60,
        endTimestamp: 120,
        color: Colors.teal,
      ),
    );
    final annotations = chartData(tester).rangeAnnotations.verticalRangeAnnotations;
    expect(annotations, hasLength(3));
    expect(annotations.last.x1, 60);
    expect(annotations.last.x2, 120);
  });
}
```

Check the `DiveProfilePoint` constructor accepts `o2Sensor1`, `o2Sensor2`, `o2SensorMv1`, `o2SensorMv2` (`dive.dart:870-985`); drop the fields from the point if the chart takes the curves only.

- [ ] **Step 3: Run both tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/cell_divergence_highlight_test.dart test/features/dive_log/presentation/widgets/dive_profile_chart_secondary_ranges_test.dart`
Expected: FAIL: the helper import does not resolve; the chart test does not compile (`secondaryRanges` unknown).

- [ ] **Step 4: Write the helper**

```dart
// lib/features/dive_log/presentation/widgets/cell_divergence_highlight.dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/profile_highlight_range.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';

/// The dive's O2 cell divergence runs as chart bands, sorted by start.
/// Drawn only while the O2 cell overlay is on (the chart gates them), in
/// the error colour so a diverging cell reads as a warning, not a
/// selection.
List<ProfileHighlightRange> cellDivergenceHighlightRanges(
  DiveSensorSummary? summary,
  ColorScheme scheme,
) {
  if (summary == null) return const [];
  final ranges = [
    for (final cell in summary.cellMetrics)
      for (final range in cell.divergenceRanges)
        ProfileHighlightRange(
          startTimestamp: range.startSeconds,
          endTimestamp: range.endSeconds,
          color: scheme.error,
        ),
  ]..sort((a, b) => a.startTimestamp.compareTo(b.startTimestamp));
  return ranges;
}
```

- [ ] **Step 5: Add `secondaryRanges` to the chart**

In `dive_profile_chart.dart`:

1. After the `highlightRange` field (line 241) add:

```dart
  /// Ranges drawn as plain bands behind [highlightRange], without edge
  /// lines, and only while the O2 cell overlay is on: the cell divergence
  /// runs from the dive's sensor summary.
  final List<ProfileHighlightRange> secondaryRanges;
```

2. In the constructor (line 586 area) add `this.secondaryRanges = const [],` next to `this.highlightRange,`.

3. Replace `_buildHighlightRangeAnnotations` (line 6704) with:

```dart
  List<VerticalRangeAnnotation> _buildHighlightRangeAnnotations(
    ({double x1, double x2})? span, {
    required double visibleMinX,
    required double visibleMaxX,
  }) {
    final annotations = <VerticalRangeAnnotation>[];
    if (_showO2CellMv) {
      for (final range in widget.secondaryRanges) {
        final visible = visibleHighlightSpan(
          range,
          visibleMinX: visibleMinX,
          visibleMaxX: visibleMaxX,
        );
        if (visible == null) continue;
        annotations.add(
          VerticalRangeAnnotation(
            x1: visible.x1,
            x2: visible.x2,
            color: range.color.withValues(alpha: 0.10),
          ),
        );
      }
    }
    final range = widget.highlightRange;
    if (range != null && span != null) {
      annotations.add(
        VerticalRangeAnnotation(
          x1: span.x1,
          x2: span.x2,
          color: range.color.withValues(alpha: 0.12),
        ),
      );
    }
    return annotations;
  }
```

4. Update the single call site (line 3263) to pass the visible window, which `_buildChart` already has in scope as `visibleMinX` and `visibleMaxX` (see line 2820):

```dart
              verticalRangeAnnotations: _buildHighlightRangeAnnotations(
                highlightSpan,
                visibleMinX: visibleMinX,
                visibleMaxX: visibleMaxX,
              ),
```

`visibleHighlightSpan` is exported by `profile_highlight_range.dart:30` and clamps a range to the visible window, returning null when fully outside.

- [ ] **Step 6: Feed the host**

In `dive_profile_chart_host.dart` add the imports

```dart
import 'package:submersion/features/dive_log/presentation/widgets/cell_divergence_highlight.dart';
import 'package:submersion/features/equipment/presentation/providers/dive_sensor_summary_providers.dart';
```

read the summary next to the other async inputs (after `gasSwitches`, around line 170):

```dart
    // Cell divergence bands (phase 2). .value keeps the previous summary
    // while the provider reloads behind a detail tick, like the inputs
    // above.
    final sensorSummary = ref.watch(diveSensorSummaryProvider(diveId)).value;
```

and pass, next to `highlightRange:` (line 412):

```dart
        secondaryRanges: cellDivergenceHighlightRanges(
          sensorSummary,
          Theme.of(context).colorScheme,
        ),
```

- [ ] **Step 7: Run the chart tests and the host tests**

Run:

```bash
flutter test test/features/dive_log/presentation/widgets/cell_divergence_highlight_test.dart test/features/dive_log/presentation/widgets/dive_profile_chart_secondary_ranges_test.dart test/features/dive_log/presentation/widgets/dive_profile_chart_highlight_test.dart test/features/dive_log/presentation/widgets/dive_profile_chart_host_combine_test.dart test/features/dive_log/presentation/pages/dive_detail_page_test.dart test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart
```

Expected: all pass. The host now watches `diveSensorSummaryProvider`; if a page test fails on a missing database, override `diveSensorSummaryProvider(diveId)` with `(ref) async => null` in that test's overrides list (the same way the tests override `safetyReviewProvider`).

- [ ] **Step 8: Commit**

```bash
dart format lib/features/dive_log/presentation/widgets/cell_divergence_highlight.dart lib/features/dive_log/presentation/widgets/dive_profile_chart.dart lib/features/dive_log/presentation/widgets/dive_profile_chart_host.dart test/features/dive_log/presentation/widgets/cell_divergence_highlight_test.dart test/features/dive_log/presentation/widgets/dive_profile_chart_secondary_ranges_test.dart
git add lib/features/dive_log/presentation/widgets/cell_divergence_highlight.dart lib/features/dive_log/presentation/widgets/dive_profile_chart.dart lib/features/dive_log/presentation/widgets/dive_profile_chart_host.dart test/features/dive_log/presentation/widgets/cell_divergence_highlight_test.dart test/features/dive_log/presentation/widgets/dive_profile_chart_secondary_ranges_test.dart
```

Also stage any page test files touched in Step 7, then:

```bash
git commit -m "feat(dive-log): shade O2 cell divergence runs on the profile chart (condition phase 2)"
```

---

### Task 13: Wrap-up

**Files:** none new.

- [ ] **Step 1: Format the whole project**

Run: `dart format .`
Expected: only files from this branch change, if any. Commit any formatting-only change as `style: format (condition phase 2)`.

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: `No issues found!` (infos count as failures in CI).

- [ ] **Step 3: Confirm generated l10n is not stale**

Run: `flutter gen-l10n && git status --short lib/l10n`
Expected: no changes.

- [ ] **Step 4: Run the touched test directories**

Run:

```bash
flutter test test/features/equipment test/features/dive_log test/features/settings test/features/backup test/l10n test/core/database
```

Expected: all pass. Run the whole suite once before pushing if time allows (`flutter test`, expect the count to be at least the 25974 from phase 1 plus this plan's new tests); do not overlap it with another local run.

- [ ] **Step 5: Prove each new regression test fails against the unfixed code**

For the chart gate, temporarily revert the `_showO2CellMv` guard in `_buildHighlightRangeAnnotations` (`if (true)`) and run `dive_profile_chart_secondary_ranges_test.dart`; the "hidden while off" test must fail. Restore the guard. For the staleness gate, temporarily change `stored.sourceUpdatedAt == dive.updatedAt` to `true` in `ensureCurrent` and run the repository test; the "source_updated_at differs" test must fail. Restore. Nothing to commit from this step.

- [ ] **Step 6: Push and open the PR**

```bash
git push -u origin ericgriffin/equipment-condition-phase2-sensor-summary
```

Open the PR against `main` with the title `feat(equipment): per-dive sensor summaries, sweep and chart divergence bands (condition intelligence phase 2)` and a body that lists: what the summary stores and how staleness works; the four refresh paths plus startup and restore; the settings action; the chart bands; no schema change; the test files added. No attribution lines of any kind.

- [ ] **Step 7: Update the program memory**

Record in the equipment condition program memory: phase 2 branch, PR number, that no rung was taken, the decisions from the header of this plan, and any execution lessons.

---

## Translation Appendix

Insert each block after `"equipmentConditionSettings_saveFailed"` in the named file. The `@` placeholder entries are identical in every locale and are omitted below; copy them from `app_en.arb`.

### app_ar.arb

```json
  "equipmentConditionSettings_sensorHeader": "ملخصات المستشعرات",
  "equipmentConditionSettings_sensorHelp": "يُلخَّص ملف كل غطسة مرة واحدة لقياس خرج الخلايا وانقطاعات جهاز الإرسال واستهلاك المنظّف. تُلخَّص الغطسات الجديدة والمعدّلة تلقائيًا.",
  "equipmentConditionSettings_rebuild": "إعادة بناء ملخصات المستشعرات",
  "equipmentConditionSettings_rebuild_subtitle": "إعادة حساب ملخص كل غطسة من ملفها",
  "equipmentConditionSettings_rebuild_progress": "تم تلخيص {done} من {total}",
  "equipmentConditionSettings_rebuild_done": "أُعيد بناء ملخصات المستشعرات",
  "equipmentConditionSettings_rebuild_doneWithErrors": "أُعيد بناء ملخصات المستشعرات؛ {count, plural, =1{تعذّر تلخيص غطسة واحدة} other{تعذّر تلخيص {count} غطسات}}",
  "equipmentConditionSettings_rebuild_failed": "تعذّرت إعادة بناء ملخصات المستشعرات.",
```

### app_de.arb

```json
  "equipmentConditionSettings_sensorHeader": "Sensorzusammenfassungen",
  "equipmentConditionSettings_sensorHelp": "Das Profil jedes Tauchgangs wird einmal für Zellenausgang, Sender-Aussetzer und Scrubber-Verbrauch zusammengefasst. Neue und bearbeitete Tauchgänge werden automatisch erfasst.",
  "equipmentConditionSettings_rebuild": "Sensorzusammenfassungen neu erstellen",
  "equipmentConditionSettings_rebuild_subtitle": "Die Zusammenfassung jedes Tauchgangs aus seinem Profil neu berechnen",
  "equipmentConditionSettings_rebuild_progress": "{done} von {total} zusammengefasst",
  "equipmentConditionSettings_rebuild_done": "Sensorzusammenfassungen neu erstellt",
  "equipmentConditionSettings_rebuild_doneWithErrors": "Sensorzusammenfassungen neu erstellt; {count, plural, =1{1 Tauchgang konnte nicht zusammengefasst werden} other{{count} Tauchgänge konnten nicht zusammengefasst werden}}",
  "equipmentConditionSettings_rebuild_failed": "Die Sensorzusammenfassungen konnten nicht neu erstellt werden.",
```

### app_es.arb

```json
  "equipmentConditionSettings_sensorHeader": "Resúmenes de sensores",
  "equipmentConditionSettings_sensorHelp": "El perfil de cada inmersión se resume una vez para la salida de las células, las pérdidas del transmisor y el uso del absorbente. Las inmersiones nuevas y editadas se resumen solas.",
  "equipmentConditionSettings_rebuild": "Reconstruir resúmenes de sensores",
  "equipmentConditionSettings_rebuild_subtitle": "Recalcular el resumen de cada inmersión a partir de su perfil",
  "equipmentConditionSettings_rebuild_progress": "Resumidas {done} de {total}",
  "equipmentConditionSettings_rebuild_done": "Resúmenes de sensores reconstruidos",
  "equipmentConditionSettings_rebuild_doneWithErrors": "Resúmenes de sensores reconstruidos; {count, plural, =1{1 inmersión no se pudo resumir} other{{count} inmersiones no se pudieron resumir}}",
  "equipmentConditionSettings_rebuild_failed": "No se pudieron reconstruir los resúmenes de sensores.",
```

### app_fr.arb

```json
  "equipmentConditionSettings_sensorHeader": "Synthèses des capteurs",
  "equipmentConditionSettings_sensorHelp": "Le profil de chaque plongée est synthétisé une fois pour la sortie des cellules, les pertes de l'émetteur et l'usage de la chaux. Les plongées nouvelles ou modifiées sont synthétisées d'elles-mêmes.",
  "equipmentConditionSettings_rebuild": "Reconstruire les synthèses des capteurs",
  "equipmentConditionSettings_rebuild_subtitle": "Recalculer la synthèse de chaque plongée à partir de son profil",
  "equipmentConditionSettings_rebuild_progress": "{done} sur {total} synthétisées",
  "equipmentConditionSettings_rebuild_done": "Synthèses des capteurs reconstruites",
  "equipmentConditionSettings_rebuild_doneWithErrors": "Synthèses des capteurs reconstruites ; {count, plural, =1{1 plongée n'a pas pu être synthétisée} other{{count} plongées n'ont pas pu être synthétisées}}",
  "equipmentConditionSettings_rebuild_failed": "Impossible de reconstruire les synthèses des capteurs.",
```

### app_he.arb

```json
  "equipmentConditionSettings_sensorHeader": "סיכומי חיישנים",
  "equipmentConditionSettings_sensorHelp": "פרופיל כל צלילה מסוכם פעם אחת עבור פלט התאים, נפילות המשדר ושימוש בסופג. צלילות חדשות ונערכות מסוכמות מעצמן.",
  "equipmentConditionSettings_rebuild": "בנייה מחדש של סיכומי חיישנים",
  "equipmentConditionSettings_rebuild_subtitle": "חישוב מחדש של סיכום כל צלילה מהפרופיל שלה",
  "equipmentConditionSettings_rebuild_progress": "סוכמו {done} מתוך {total}",
  "equipmentConditionSettings_rebuild_done": "סיכומי החיישנים נבנו מחדש",
  "equipmentConditionSettings_rebuild_doneWithErrors": "סיכומי החיישנים נבנו מחדש; {count, plural, =1{צלילה אחת לא ניתן היה לסכם} other{{count} צלילות לא ניתן היה לסכם}}",
  "equipmentConditionSettings_rebuild_failed": "לא ניתן היה לבנות מחדש את סיכומי החיישנים.",
```

### app_hu.arb

```json
  "equipmentConditionSettings_sensorHeader": "Szenzor-összegzések",
  "equipmentConditionSettings_sensorHelp": "Minden merülés profilját egyszer összegezzük a cellakimenet, az adókimaradások és a szűrőfelhasználás szerint. Az új és a szerkesztett merülések maguktól összegződnek.",
  "equipmentConditionSettings_rebuild": "Szenzor-összegzések újraépítése",
  "equipmentConditionSettings_rebuild_subtitle": "Minden merülés összegzésének újraszámítása a profiljából",
  "equipmentConditionSettings_rebuild_progress": "{done} / {total} összegezve",
  "equipmentConditionSettings_rebuild_done": "Szenzor-összegzések újraépítve",
  "equipmentConditionSettings_rebuild_doneWithErrors": "Szenzor-összegzések újraépítve; {count, plural, =1{1 merülést nem sikerült összegezni} other{{count} merülést nem sikerült összegezni}}",
  "equipmentConditionSettings_rebuild_failed": "A szenzor-összegzéseket nem sikerült újraépíteni.",
```

### app_it.arb

```json
  "equipmentConditionSettings_sensorHeader": "Riepiloghi dei sensori",
  "equipmentConditionSettings_sensorHelp": "Il profilo di ogni immersione viene riepilogato una volta per l'uscita delle celle, le perdite del trasmettitore e l'uso del filtro. Le immersioni nuove e modificate si riepilogano da sole.",
  "equipmentConditionSettings_rebuild": "Ricostruisci i riepiloghi dei sensori",
  "equipmentConditionSettings_rebuild_subtitle": "Ricalcola il riepilogo di ogni immersione dal suo profilo",
  "equipmentConditionSettings_rebuild_progress": "Riepilogate {done} di {total}",
  "equipmentConditionSettings_rebuild_done": "Riepiloghi dei sensori ricostruiti",
  "equipmentConditionSettings_rebuild_doneWithErrors": "Riepiloghi dei sensori ricostruiti; {count, plural, =1{1 immersione non è stata riepilogata} other{{count} immersioni non sono state riepilogate}}",
  "equipmentConditionSettings_rebuild_failed": "Impossibile ricostruire i riepiloghi dei sensori.",
```

### app_nl.arb

```json
  "equipmentConditionSettings_sensorHeader": "Sensorsamenvattingen",
  "equipmentConditionSettings_sensorHelp": "Het profiel van elke duik wordt eenmaal samengevat voor celuitvoer, zenderuitval en scrubbergebruik. Nieuwe en bewerkte duiken worden vanzelf samengevat.",
  "equipmentConditionSettings_rebuild": "Sensorsamenvattingen opnieuw opbouwen",
  "equipmentConditionSettings_rebuild_subtitle": "De samenvatting van elke duik opnieuw berekenen uit het profiel",
  "equipmentConditionSettings_rebuild_progress": "{done} van {total} samengevat",
  "equipmentConditionSettings_rebuild_done": "Sensorsamenvattingen opnieuw opgebouwd",
  "equipmentConditionSettings_rebuild_doneWithErrors": "Sensorsamenvattingen opnieuw opgebouwd; {count, plural, =1{1 duik kon niet worden samengevat} other{{count} duiken konden niet worden samengevat}}",
  "equipmentConditionSettings_rebuild_failed": "De sensorsamenvattingen konden niet opnieuw worden opgebouwd.",
```

### app_pt.arb

```json
  "equipmentConditionSettings_sensorHeader": "Resumos de sensores",
  "equipmentConditionSettings_sensorHelp": "O perfil de cada mergulho é resumido uma vez para a saída das células, as falhas do transmissor e o uso do absorvente. Mergulhos novos e editados são resumidos sozinhos.",
  "equipmentConditionSettings_rebuild": "Reconstruir resumos de sensores",
  "equipmentConditionSettings_rebuild_subtitle": "Recalcular o resumo de cada mergulho a partir do seu perfil",
  "equipmentConditionSettings_rebuild_progress": "Resumidos {done} de {total}",
  "equipmentConditionSettings_rebuild_done": "Resumos de sensores reconstruídos",
  "equipmentConditionSettings_rebuild_doneWithErrors": "Resumos de sensores reconstruídos; {count, plural, =1{1 mergulho não pôde ser resumido} other{{count} mergulhos não puderam ser resumidos}}",
  "equipmentConditionSettings_rebuild_failed": "Não foi possível reconstruir os resumos de sensores.",
```

### app_zh.arb

```json
  "equipmentConditionSettings_sensorHeader": "传感器摘要",
  "equipmentConditionSettings_sensorHelp": "每次潜水的剖面只汇总一次，用于电池输出、发射器断连和吸收剂用量。新增和编辑的潜水会自动汇总。",
  "equipmentConditionSettings_rebuild": "重建传感器摘要",
  "equipmentConditionSettings_rebuild_subtitle": "根据每次潜水的剖面重新计算其摘要",
  "equipmentConditionSettings_rebuild_progress": "已汇总 {done} / {total}",
  "equipmentConditionSettings_rebuild_done": "传感器摘要已重建",
  "equipmentConditionSettings_rebuild_doneWithErrors": "传感器摘要已重建；{count, plural, =1{1 次潜水无法汇总} other{{count} 次潜水无法汇总}}",
  "equipmentConditionSettings_rebuild_failed": "无法重建传感器摘要。",
```
