# Merge Non-Overlapping Dives as Another Computer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver fold two records of one dive, whose computer clocks disagree so the records do not overlap in time, into one dive with an additional computer, aligned by depth profile (issue #552).

**Architecture:** A new pure `ProfileAligner` finds the shift that best lines one depth trace up with another. `DiveConsolidationBuilder.classify/build` take an optional `ConsolidationAlignment`; with one set, a non-overlapping secondary is no longer rejected but offset by the aligner (or by 0 for "align starts"). The service and the shared runner pass the mode through, and the combine dialog adds a Join / Merge choice, an alignment toggle, a same-dive hint and notes.

**Tech Stack:** Flutter, Riverpod, Drift, flutter_test, ARB l10n (`flutter gen-l10n`).

**Spec:** `docs/design/specs/2026-10-05-merge-non-overlapping-dives-as-computer-design.md`

## Global Constraints

- `alignment == null` keeps today's behaviour exactly, including the `notOverlapping` rejection.
- Offsets mean "seconds to ADD to the secondary's child timestamps to land on the primary's timeline" (existing `DiveConsolidationPlan.offsetsSeconds` contract).
- Best-fit window: plus or minus min(half the shorter trace's span, 15 min). Grid 5 s, coarse step 10 s, refine 1 s within 10 s. Ties go to the smallest absolute offset.
- Fallback (offset 0, no score, never a strong match) when either profile has fewer than 3 samples deeper than 0.5 m.
- Strong match: overlap >= 80% of the shorter trace and RMS depth error <= max(1.0 m, 5% of the primary's max depth).
- Same-dive preselect also requires every selected dive to carry a non-empty computer serial.
- New user-facing strings are translated into all 10 non-English ARBs; run `flutter gen-l10n` only after every ARB has them.
- No em dashes or en dashes as punctuation anywhere (code, comments, docs, commits).
- Paths built with `p.join`, never string concatenation (none expected here).
- `dart format .`, `flutter analyze`, the affected tests and `test/architecture/` pass before each commit that adds `lib/` files.

## Review Focus

1. Two different dives from two computers on the same day (a morning and an afternoon dive) must not be preselected as Merge. Pinned in Task 1 ("two different dives are not a strong match") and Task 6 ("Join stays selected when the profiles differ").
2. A record with no profile (manually logged, or a computer that only kept summary data) must still merge, at start alignment, and say so. Pinned in Task 1 (fallback tests) and Task 5 (fallback note).
3. A flat profile (pool session, constant depth) must not drift to the edge of the window on floating-point ties. Pinned in Task 1 ("a flat profile ties to offset 0").
4. The phone-width dialog (390 pt) must lay out the long segment labels and the action buttons without overflow. Pinned in Task 5 (narrow controls) and Task 6 (phone-width preview).
5. A fully overlapping selection must persist with `alignment: null`, so a sync that moves a dive between preview and confirm is still rejected strictly. Pinned in Task 6 ("a fully overlapping selection passes no alignment").

---

## File Structure

| File | Responsibility |
| --- | --- |
| Create `lib/features/dive_log/domain/services/profile_alignment.dart` | `ConsolidationAlignment`, `ProfileAlignmentResult`, `ProfileAligner` (pure math) |
| Modify `lib/features/dive_log/domain/services/dive_consolidation_builder.dart` | alignment parameter, `realignedIds`, `alignments` |
| Modify `lib/features/dive_log/data/services/dive_consolidation_service.dart` | `apply(alignment:)` passthrough |
| Modify `lib/features/dive_log/presentation/widgets/run_dive_consolidation.dart` | `alignment` passthrough |
| Create `lib/features/dive_log/presentation/widgets/consolidation_alignment_controls.dart` | `CombineMode`, `CombineModeSelector`, `ConsolidationAlignmentControls` |
| Modify `lib/features/dive_log/presentation/widgets/combine_dives_dialog.dart` | mode state, plan memo, wiring, OverflowBar fix |
| Modify `lib/l10n/arb/app_*.arb` (11) + generated `app_localizations*.dart` | 8 new keys |
| Modify `test/helpers/fake_dive_consolidation_service.dart` | capture `alignment` |
| Modify `docs/guide/dive-computer.md` | describe Merge for non-overlapping records; drop the removed detail-page action |

---

### Task 1: ProfileAligner

**Files:**
- Create: `lib/features/dive_log/domain/services/profile_alignment.dart`
- Test: `test/features/dive_log/domain/services/profile_alignment_test.dart`

**Interfaces:**
- Produces:
  - `enum ConsolidationAlignment { bestFit, starts }`
  - `class ProfileAlignmentResult { int offsetSeconds; double? rmsDepthError; double overlapFraction; bool usedFallback; bool isStrongMatch; ProfileAlignmentResult copyWith({int? offsetSeconds}); const ProfileAlignmentResult.fallback(); }`
  - `class ProfileAligner { const ProfileAligner(); ProfileAlignmentResult align(List<DiveProfilePoint> primary, List<DiveProfilePoint> secondary); }`

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_alignment.dart';

/// Knots of a 48 minute multilevel reef dive: (seconds, metres).
const _reefKnots = <(int, double)>[
  (0, 0), (120, 18), (240, 22), (600, 21), (900, 16), (1300, 14),
  (1700, 10), (2200, 8), (2400, 5), (2580, 5), (2760, 4.8), (2880, 0),
];

double _depthOn(List<(int, double)> knots, int t) {
  if (t <= knots.first.$1) return knots.first.$2;
  for (var i = 1; i < knots.length; i++) {
    final (t0, d0) = knots[i - 1];
    final (t1, d1) = knots[i];
    if (t <= t1) return d0 + (d1 - d0) * (t - t0) / (t1 - t0);
  }
  return knots.last.$2;
}

/// Samples [knots] every [interval] seconds. [lead] seconds of surface come
/// first (a computer that started logging early); [skip] drops the first
/// [skip] seconds of the dive (a computer switched on late); [scale]
/// multiplies every depth (fresh versus salt water calibration).
List<DiveProfilePoint> trace(
  List<(int, double)> knots, {
  int interval = 10,
  int lead = 0,
  int skip = 0,
  double scale = 1.0,
}) {
  final end = knots.last.$1 - skip + lead;
  return [
    for (var t = 0; t <= end; t += interval)
      DiveProfilePoint(
        timestamp: t,
        depth: t < lead ? 0 : _depthOn(knots, t - lead + skip) * scale,
      ),
  ];
}

void main() {
  const aligner = ProfileAligner();
  final reef = trace(_reefKnots);

  test('identical traces align at 0 with no error and a strong match', () {
    final r = aligner.align(reef, trace(_reefKnots));
    expect(r.offsetSeconds, 0);
    expect(r.rmsDepthError, closeTo(0, 1e-9));
    expect(r.usedFallback, isFalse);
    expect(r.isStrongMatch, isTrue);
  });

  test('a secondary that logged 40 s at the surface first is shifted back '
      '40 s', () {
    final r = aligner.align(reef, trace(_reefKnots, lead: 40));
    expect(r.offsetSeconds, -40);
    expect(r.isStrongMatch, isTrue);
  });

  test('a secondary switched on 90 s late is shifted forward about 90 s, '
      'whatever its sample rate', () {
    final r = aligner.align(reef, trace(_reefKnots, interval: 20, skip: 90));
    expect(r.offsetSeconds, closeTo(90, 3));
    expect(r.isStrongMatch, isTrue);
  });

  test('a 3% depth scale (fresh versus salt water) is still a strong match',
      () {
    final r = aligner.align(reef, trace(_reefKnots, lead: 40, scale: 1.03));
    expect(r.offsetSeconds, closeTo(-40, 2));
    expect(r.isStrongMatch, isTrue);
  });

  test('two different dives are not a strong match', () {
    const square = <(int, double)>[
      (0, 0), (90, 35), (1500, 35), (1800, 6), (1980, 6), (2040, 0),
    ];
    final r = aligner.align(reef, trace(square));
    expect(r.usedFallback, isFalse);
    expect(r.isStrongMatch, isFalse);
  });

  test('an empty profile falls back to offset 0 with no score', () {
    final r = aligner.align(reef, const []);
    expect(r.offsetSeconds, 0);
    expect(r.usedFallback, isTrue);
    expect(r.rmsDepthError, isNull);
    expect(r.isStrongMatch, isFalse);
  });

  test('a profile that never leaves the surface falls back', () {
    final surface = [
      for (var t = 0; t <= 600; t += 10)
        DiveProfilePoint(timestamp: t, depth: t == 300 ? 1.0 : 0.2),
    ];
    final r = aligner.align(surface, reef);
    expect(r.usedFallback, isTrue);
    expect(r.offsetSeconds, 0);
  });

  test('a flat profile ties to offset 0', () {
    final flat = [
      for (var t = 0; t <= 1800; t += 10)
        DiveProfilePoint(timestamp: t, depth: 10),
    ];
    final r = aligner.align(flat, [...flat]);
    expect(r.offsetSeconds, 0);
  });

  test('the search stays inside the window', () {
    // 20 minutes of surface before the descent: the true shift (-1200 s) is
    // outside the 15 minute window, so the result must not exceed it.
    final r = aligner.align(reef, trace(_reefKnots, lead: 1200));
    expect(r.offsetSeconds.abs(), lessThanOrEqualTo(900));
  });

  test('a short dive narrows the window to half its span', () {
    const short = <(int, double)>[(0, 0), (60, 8), (480, 8), (600, 0)];
    final r = aligner.align(trace(short), trace(short, lead: 400));
    expect(r.offsetSeconds.abs(), lessThanOrEqualTo(300));
  });

  test('copyWith replaces only the offset', () {
    final r = aligner.align(reef, trace(_reefKnots, lead: 40));
    final moved = r.copyWith(offsetSeconds: 0);
    expect(moved.offsetSeconds, 0);
    expect(moved.rmsDepthError, r.rmsDepthError);
    expect(moved.isStrongMatch, r.isStrongMatch);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/dive_log/domain/services/profile_alignment_test.dart`
Expected: FAIL, `profile_alignment.dart` does not exist.

- [ ] **Step 3: Implement**

```dart
import 'dart:math' as math;

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// How a secondary record that does not overlap the primary in time is
/// placed on the primary's timeline when it is merged as another computer
/// (#552). Its clock cannot be trusted: that is why the records do not
/// overlap.
enum ConsolidationAlignment {
  /// Slide the secondary's depth trace to where it matches the primary's.
  bestFit,

  /// Line the two records' starts up (offset 0).
  starts,
}

/// Where [ProfileAligner] placed a secondary trace, and how well it fits.
class ProfileAlignmentResult {
  const ProfileAlignmentResult({
    required this.offsetSeconds,
    required this.rmsDepthError,
    required this.overlapFraction,
    required this.usedFallback,
    required this.isStrongMatch,
  });

  /// No usable profile on one side: the starts are lined up and nothing is
  /// scored, so the result can never suggest the records are one dive.
  const ProfileAlignmentResult.fallback()
    : offsetSeconds = 0,
      rmsDepthError = null,
      overlapFraction = 0,
      usedFallback = true,
      isStrongMatch = false;

  /// Seconds to add to the secondary's timestamps (may be negative).
  final int offsetSeconds;

  /// Root mean square depth difference, in metres, where the traces overlap.
  final double? rmsDepthError;

  /// The overlapping span as a fraction of the shorter trace, 0 to 1.
  final double overlapFraction;
  final bool usedFallback;

  /// Whether the two traces look like one dive recorded twice.
  final bool isStrongMatch;

  ProfileAlignmentResult copyWith({int? offsetSeconds}) =>
      ProfileAlignmentResult(
        offsetSeconds: offsetSeconds ?? this.offsetSeconds,
        rmsDepthError: rmsDepthError,
        overlapFraction: overlapFraction,
        usedFallback: usedFallback,
        isStrongMatch: isStrongMatch,
      );
}

class _Fit {
  const _Fit(this.shift, this.rms, this.overlap);
  final int shift;
  final double rms;
  final double overlap;
}

/// Finds the shift that best lines one dive computer's depth trace up with
/// another's.
///
/// Both profiles' timestamps count from their own record's start, so a shift
/// of 0 lines the starts up and the wall-clock difference between the two
/// computers never enters the search.
class ProfileAligner {
  const ProfileAligner();

  static const int maxWindowSeconds = 15 * 60;
  static const int gridSeconds = 5;
  static const int coarseStepSeconds = 10;
  static const double surfaceDepthMeters = 0.5;
  static const int minSubmergedSamples = 3;
  static const double strongMatchMinOverlap = 0.8;
  static const double strongMatchMinRmsMeters = 1.0;

  /// A computer set to fresh water reads about 3% deeper than one set to
  /// salt, at every depth, so the allowed error grows with depth.
  static const double strongMatchDepthFraction = 0.05;
  static const double _tieEpsilon = 1e-9;

  ProfileAlignmentResult align(
    List<DiveProfilePoint> primary,
    List<DiveProfilePoint> secondary,
  ) {
    final p = _sorted(primary);
    final s = _sorted(secondary);
    if (_submerged(p) < minSubmergedSamples ||
        _submerged(s) < minSubmergedSamples) {
      return const ProfileAlignmentResult.fallback();
    }
    final shorter = math.min(
      p.last.timestamp - p.first.timestamp,
      s.last.timestamp - s.first.timestamp,
    );
    if (shorter <= 0) return const ProfileAlignmentResult.fallback();
    // Wide enough for a computer switched on late or one that logged the
    // surface first; narrow enough that one record's descent cannot slide
    // onto the other's ascent.
    final window = math.min(shorter ~/ 2, maxWindowSeconds);

    _Fit? best;
    void consider(int shift) {
      if (shift.abs() > window) return;
      final fit = _score(p, s, shift, shorter);
      if (fit == null) return;
      final current = best;
      if (current == null ||
          fit.rms < current.rms - _tieEpsilon ||
          ((fit.rms - current.rms).abs() <= _tieEpsilon &&
              shift.abs() < current.shift.abs())) {
        best = fit;
      }
    }

    for (var k = 0; k * coarseStepSeconds <= window; k++) {
      consider(k * coarseStepSeconds);
      if (k > 0) consider(-k * coarseStepSeconds);
    }
    final coarse = best;
    if (coarse == null) return const ProfileAlignmentResult.fallback();
    for (
      var shift = coarse.shift - coarseStepSeconds;
      shift <= coarse.shift + coarseStepSeconds;
      shift++
    ) {
      consider(shift);
    }

    final fit = best!;
    final maxDepth = p.map((e) => e.depth).reduce(math.max);
    final threshold = math.max(
      strongMatchMinRmsMeters,
      strongMatchDepthFraction * maxDepth,
    );
    return ProfileAlignmentResult(
      offsetSeconds: fit.shift,
      rmsDepthError: fit.rms,
      overlapFraction: fit.overlap,
      usedFallback: false,
      isStrongMatch:
          fit.overlap >= strongMatchMinOverlap && fit.rms <= threshold,
    );
  }

  static List<DiveProfilePoint> _sorted(List<DiveProfilePoint> points) =>
      [...points]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  static int _submerged(List<DiveProfilePoint> points) =>
      points.where((e) => e.depth > surfaceDepthMeters).length;

  /// RMS depth difference with the secondary shifted by [shift] seconds,
  /// over the span both traces cover, or null when they barely overlap.
  static _Fit? _score(
    List<DiveProfilePoint> p,
    List<DiveProfilePoint> s,
    int shift,
    int shorter,
  ) {
    final start = math.max(p.first.timestamp, s.first.timestamp + shift);
    final end = math.min(p.last.timestamp, s.last.timestamp + shift);
    if (end - start < gridSeconds) return null;
    var sum = 0.0;
    var n = 0;
    for (var t = start; t <= end; t += gridSeconds) {
      final d = _depthAt(p, t) - _depthAt(s, t - shift);
      sum += d * d;
      n++;
    }
    return _Fit(
      shift,
      math.sqrt(sum / n),
      math.min(1.0, (end - start) / shorter),
    );
  }

  /// Linear interpolation of [points] (sorted, [t] within their span).
  static double _depthAt(List<DiveProfilePoint> points, int t) {
    var lo = 0;
    var hi = points.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (points[mid].timestamp <= t) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    if (lo >= points.length - 1) return points.last.depth;
    final a = points[lo];
    final b = points[lo + 1];
    final span = b.timestamp - a.timestamp;
    if (span <= 0) return a.depth;
    return a.depth + (b.depth - a.depth) * (t - a.timestamp) / span;
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/dive_log/domain/services/profile_alignment_test.dart`
Expected: all PASS.

- [ ] **Step 5: Format, analyze, architecture, commit**

```bash
dart format lib/features/dive_log/domain/services/profile_alignment.dart test/features/dive_log/domain/services/profile_alignment_test.dart
flutter analyze lib/features/dive_log test/features/dive_log
flutter test test/architecture/
git add lib/features/dive_log/domain/services/profile_alignment.dart test/features/dive_log/domain/services/profile_alignment_test.dart
git commit -m "feat(dive-log): align two dive computers' depth traces by best fit"
```

---

### Task 2: Builder alignment mode

**Files:**
- Modify: `lib/features/dive_log/domain/services/dive_consolidation_builder.dart`
- Test: `test/features/dive_log/domain/services/dive_consolidation_builder_test.dart`

**Interfaces:**
- Consumes: Task 1 (`ConsolidationAlignment`, `ProfileAligner`, `ProfileAlignmentResult`).
- Produces:
  - `ConsolidationReady.realignedIds` (`Set<String>`, default `const {}`)
  - `DiveConsolidationPlan.alignments` (`Map<String, ProfileAlignmentResult>`, default `const {}`)
  - `classify(List<Dive>, {String? primaryDiveId, ConsolidationAlignment? alignment})`
  - `build(List<Dive>, {String? primaryDiveId, ConsolidationAlignment? alignment})`

- [ ] **Step 1: Write the failing tests** (append a group to `main()` in the builder test; add the helper above `main()`)

```dart
import 'package:submersion/features/dive_log/domain/services/profile_alignment.dart';

/// A multilevel reef dive sampled every 10 s; [lead] seconds at the surface
/// first.
List<DiveProfilePoint> reefProfile({int lead = 0}) {
  const knots = <(int, double)>[
    (0, 0), (120, 18), (240, 22), (600, 21), (900, 16), (1300, 14),
    (1700, 10), (2200, 8), (2400, 5), (2580, 5), (2760, 4.8), (2880, 0),
  ];
  double at(int t) {
    for (var i = 1; i < knots.length; i++) {
      final (t0, d0) = knots[i - 1];
      final (t1, d1) = knots[i];
      if (t <= t1) return d0 + (d1 - d0) * (t - t0) / (t1 - t0);
    }
    return 0;
  }

  return [
    for (var t = 0; t <= 2880 + lead; t += 10)
      DiveProfilePoint(timestamp: t, depth: t < lead ? 0 : at(t - lead)),
  ];
}
```

```dart
  group('alignment mode (#552)', () {
    // 'b' is the same dive on a computer whose clock runs 66 minutes fast
    // and which logged 40 s at the surface before the descent.
    List<Dive> skewedPair() => [
      makeDive('a', entry: t, runtimeMin: 48, serial: 'A',
          profile: reefProfile()),
      makeDive('b', entry: t.add(const Duration(minutes: 66)),
          runtimeMin: 48, serial: 'B', profile: reefProfile(lead: 40)),
    ];

    test('a mode accepts a non-overlapping pair and marks it realigned', () {
      final result = builder.classify(
        skewedPair(),
        alignment: ConsolidationAlignment.bestFit,
      );
      expect(result, isA<ConsolidationReady>());
      expect((result as ConsolidationReady).realignedIds, {'b'});
    });

    test('a mode still rejects two records from one computer', () {
      final result = builder.classify([
        makeDive('a', entry: t, serial: 'SAME'),
        makeDive('b', entry: t.add(const Duration(hours: 2)), serial: 'SAME'),
      ], alignment: ConsolidationAlignment.bestFit);
      expect(
        (result as ConsolidationInvalid).reason,
        ConsolidationInvalidReason.sameComputer,
      );
    });

    test('overlapping secondaries are not realigned', () {
      final result = builder.classify([
        makeDive('a', entry: t, serial: 'A'),
        makeDive('b', entry: t.add(const Duration(minutes: 5)), serial: 'B'),
        makeDive('c', entry: t.add(const Duration(minutes: 90)), serial: 'C'),
      ], alignment: ConsolidationAlignment.starts);
      expect((result as ConsolidationReady).realignedIds, {'c'});
    });

    test('realignedIds follows the chosen primary', () {
      final dives = [
        makeDive('a', entry: t, serial: 'A'),
        makeDive('b', entry: t.add(const Duration(minutes: 20)), serial: 'B'),
        makeDive('c', entry: t.add(const Duration(minutes: 45)), serial: 'C'),
      ];
      final fromA = builder.classify(
        dives,
        alignment: ConsolidationAlignment.bestFit,
      );
      final fromB = builder.classify(
        dives,
        primaryDiveId: 'b',
        alignment: ConsolidationAlignment.bestFit,
      );
      expect((fromA as ConsolidationReady).realignedIds, {'c'});
      expect((fromB as ConsolidationReady).realignedIds, isEmpty);
    });

    test('best fit offsets a skewed secondary by its profile, not its clock',
        () {
      final plan = builder.build(
        skewedPair(),
        alignment: ConsolidationAlignment.bestFit,
      );
      expect(plan.offsetsSeconds['b'], -40);
      expect(plan.alignments['b']!.isStrongMatch, isTrue);
      expect(plan.previewSeries['b']!.first.timestamp, -40);
    });

    test('align starts offsets the realigned secondary by 0 and keeps the '
        'best-fit score', () {
      final plan = builder.build(
        skewedPair(),
        alignment: ConsolidationAlignment.starts,
      );
      expect(plan.offsetsSeconds['b'], 0);
      expect(plan.alignments['b']!.offsetSeconds, 0);
      expect(plan.alignments['b']!.isStrongMatch, isTrue);
    });

    test('a mixed selection keeps the entry-time offset for an overlapping '
        'secondary', () {
      final plan = builder.build([
        makeDive('a', entry: t, runtimeMin: 48, serial: 'A',
            profile: reefProfile()),
        makeDive('b', entry: t.add(const Duration(minutes: 5)),
            runtimeMin: 48, serial: 'B', profile: reefProfile()),
        makeDive('c', entry: t.add(const Duration(minutes: 90)),
            runtimeMin: 48, serial: 'C', profile: reefProfile(lead: 40)),
      ], alignment: ConsolidationAlignment.bestFit);
      expect(plan.offsetsSeconds['b'], 300);
      expect(plan.offsetsSeconds['c'], -40);
      expect(plan.alignments.keys, ['c']);
    });

    test('without a mode the plan carries no alignments', () {
      final plan = builder.build([
        makeDive('a', entry: t, serial: 'A'),
        makeDive('b', entry: t.add(const Duration(minutes: 5)), serial: 'B'),
      ]);
      expect(plan.alignments, isEmpty);
    });
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/domain/services/dive_consolidation_builder_test.dart`
Expected: compile errors (`alignment` parameter, `realignedIds`, `alignments` undefined).

- [ ] **Step 3: Implement**

In `dive_consolidation_builder.dart`:

1. Import `profile_alignment.dart`.
2. `ConsolidationReady` gains the field:

```dart
class ConsolidationReady extends DiveConsolidationClassification {
  const ConsolidationReady({
    required this.primary,
    required this.secondaries,
    this.realignedIds = const {},
  });
  final Dive primary;

  /// Chronological by entry time; excludes [primary].
  final List<Dive> secondaries;

  /// Secondaries that do not overlap [primary] in time, accepted only because
  /// an alignment mode was given. Their clocks are not trusted, so `build`
  /// places them by that mode instead of by entry time (#552).
  final Set<String> realignedIds;
}
```

3. `DiveConsolidationPlan` gains `this.alignments = const {}` in the constructor and the field:

```dart
  /// Realigned secondary id -> where the alignment placed it and how well
  /// its profile matches the primary's. Empty without an alignment mode.
  final Map<String, ProfileAlignmentResult> alignments;
```

4. `classify` signature and the overlap loop:

```dart
  /// [alignment] null rejects a secondary that does not overlap the primary
  /// in time. With a mode, that secondary is accepted and listed in
  /// [ConsolidationReady.realignedIds] for `build` to align.
  DiveConsolidationClassification classify(
    List<Dive> dives, {
    String? primaryDiveId,
    ConsolidationAlignment? alignment,
  }) {
```

```dart
    final realigned = <String>{};
    for (final s in secondaries) {
      if (_overlaps(primary, s)) continue;
      if (alignment == null) {
        return const ConsolidationInvalid(
          ConsolidationInvalidReason.notOverlapping,
        );
      }
      realigned.add(s.id);
    }
    return ConsolidationReady(
      primary: primary,
      secondaries: secondaries,
      realignedIds: realigned,
    );
```

5. `build` signature `DiveConsolidationPlan build(List<Dive> dives, {String? primaryDiveId, ConsolidationAlignment? alignment})`, pass `alignment` to `classify`, then replace the offsets block:

```dart
    // A realigned secondary's clock disagrees with the primary's by more
    // than the dive lasted, so its entry time would reproduce that error.
    // The best-fit score is kept under "starts" too, so the same-dive hint
    // does not change when the user flips the toggle.
    final alignments = <String, ProfileAlignmentResult>{
      for (final s in secondaries)
        if (classification.realignedIds.contains(s.id))
          s.id: _aligned(primary, s, alignment!),
    };
    final offsets = <String, int>{
      primary.id: 0,
      for (final s in secondaries)
        s.id:
            alignments[s.id]?.offsetSeconds ??
            s.effectiveEntryTime
                .difference(primary.effectiveEntryTime)
                .inSeconds,
    };
```

with the helper on the class:

```dart
  ProfileAlignmentResult _aligned(
    Dive primary,
    Dive secondary,
    ConsolidationAlignment alignment,
  ) {
    final fit = const ProfileAligner().align(
      primary.profile,
      secondary.profile,
    );
    return switch (alignment) {
      ConsolidationAlignment.bestFit => fit,
      ConsolidationAlignment.starts => fit.copyWith(offsetSeconds: 0),
    };
  }
```

and pass `alignments: alignments` to the `DiveConsolidationPlan` constructor.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/dive_log/domain/services/dive_consolidation_builder_test.dart`
Expected: all PASS (old tests unchanged).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_log/domain/services/dive_consolidation_builder.dart test/features/dive_log/domain/services/dive_consolidation_builder_test.dart
flutter analyze lib/features/dive_log test/features/dive_log
git add lib/features/dive_log/domain/services/dive_consolidation_builder.dart test/features/dive_log/domain/services/dive_consolidation_builder_test.dart
git commit -m "feat(dive-log): consolidate non-overlapping dives under an alignment mode"
```

---

### Task 3: Service and runner passthrough

**Files:**
- Modify: `lib/features/dive_log/data/services/dive_consolidation_service.dart`
- Modify: `lib/features/dive_log/presentation/widgets/run_dive_consolidation.dart`
- Modify: `test/helpers/fake_dive_consolidation_service.dart`
- Test: `test/features/dive_log/data/services/dive_consolidation_service_series_test.dart`
- Test: `test/features/dive_log/presentation/widgets/run_dive_consolidation_test.dart`

**Interfaces:**
- Consumes: Task 2 `build(..., alignment:)`.
- Produces:
  - `DiveConsolidationService.apply({required String targetDiveId, required List<String> secondaryDiveIds, ConsolidationAlignment? alignment})`
  - `runDiveConsolidation({..., ConsolidationAlignment? alignment})`
  - `FakeDiveConsolidationService.capturedAlignment` (`ConsolidationAlignment?`)

- [ ] **Step 1: Write the failing service test** (in the series test file, after the existing tests; it reuses that file's `setUp` dives `t` at 09:00 and `s` at 09:01 and its `copiedSourceId()` helper)

```dart
  List<ProfileSample> reefSamples({int lead = 0}) {
    const knots = <(int, double)>[
      (0, 0), (120, 18), (240, 22), (600, 21), (900, 16), (1300, 14),
      (1700, 10), (2200, 8), (2400, 5), (2580, 5), (2760, 4.8), (2880, 0),
    ];
    double at(int t) {
      for (var i = 1; i < knots.length; i++) {
        final (t0, d0) = knots[i - 1];
        final (t1, d1) = knots[i];
        if (t <= t1) return d0 + (d1 - d0) * (t - t0) / (t1 - t0);
      }
      return 0;
    }

    return [
      for (var t = 0; t <= 2880 + lead; t += 10)
        ProfileSample(timestamp: t, depth: t < lead ? 0 : at(t - lead)),
    ];
  }

  test('apply with best fit folds a clock-skewed secondary onto the '
      "primary's timeline (#552)", () async {
    // 's' recorded the same dive on a clock 66 minutes fast, after 40 s at
    // the surface, so the two records do not overlap in time.
    final skewedEntry = DateTime.utc(2026, 7, 1, 10, 6);
    await (db.update(db.dives)..where((d) => d.id.equals('s'))).write(
      DivesCompanion(
        entryTime: Value(skewedEntry.millisecondsSinceEpoch),
        runtime: const Value(48 * 60),
      ),
    );
    await (db.update(db.dives)..where((d) => d.id.equals('t'))).write(
      const DivesCompanion(runtime: Value(48 * 60)),
    );
    await profileSeries.insertSeries(
      diveId: 't',
      computerId: 'comp-t',
      sourceId: 'src-t',
      samples: reefSamples(),
      now: 1000,
    );
    await profileSeries.insertSeries(
      diveId: 's',
      computerId: 'comp-s',
      sourceId: 'src-s',
      samples: reefSamples(lead: 40),
      now: 1000,
    );

    await expectLater(
      service.apply(targetDiveId: 't', secondaryDiveIds: ['s']),
      throwsArgumentError,
    );

    final outcome = await service.apply(
      targetDiveId: 't',
      secondaryDiveIds: ['s'],
      alignment: ConsolidationAlignment.bestFit,
    );

    final source = await copiedSourceId();
    final sourceRow = await (db.select(
      db.diveDataSources,
    )..where((d) => d.id.equals(source))).getSingle();
    expect(sourceRow.timeOffsetSeconds, -40);
    final copied = (await profileSeries.getSeriesForDive(
      't',
    )).where((r) => r.sourceId == source).single;
    expect(copied.samples.first.timestamp, -40);

    await service.undo(outcome.snapshot);
    final restored = await diveRepo.getDivesByIds(['s']);
    // isAtSameMomentAs, not ==: DateTime.== also compares UTC versus local.
    expect(restored.single.entryTime!.isAtSameMomentAs(skewedEntry), isTrue);
  });
```

Add `import 'package:submersion/features/dive_log/domain/services/profile_alignment.dart';` to the series test. The `dives.runtime` column stores seconds and `dives.entryTime` epoch milliseconds (`lib/core/database/tables/dive_tables.dart`).

- [ ] **Step 2: Write the failing runner test** (in `run_dive_consolidation_test.dart`: give `_pumpAndRun` and `_run` an optional `ConsolidationAlignment? alignment` forwarded to `runDiveConsolidation`, then add)

```dart
    testWidgets('forwards the alignment to apply', (tester) async {
      final service = FakeDiveConsolidationService();

      await _pumpAndRun(
        tester,
        service: service,
        alignment: ConsolidationAlignment.starts,
      );

      expect(service.capturedAlignment, ConsolidationAlignment.starts);
    });
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/dive_log/data/services/dive_consolidation_service_series_test.dart test/features/dive_log/presentation/widgets/run_dive_consolidation_test.dart`
Expected: compile errors (`alignment` parameters, `capturedAlignment`).

- [ ] **Step 4: Implement**

Service `apply`:

```dart
  /// Folds [secondaryDiveIds] into [targetDiveId] as additional computer
  /// sources. Throws [ArgumentError] (with the ConsolidationInvalidReason in
  /// the message) when the selection cannot be consolidated. All-or-nothing:
  /// nothing is written to the DB if validation fails.
  ///
  /// [alignment] null requires every secondary to overlap the target in
  /// time. With a mode, a secondary that does not is placed by that mode
  /// (#552); see [DiveConsolidationBuilder.build].
  Future<DiveConsolidationOutcome> apply({
    required String targetDiveId,
    required List<String> secondaryDiveIds,
    ConsolidationAlignment? alignment,
  }) async {
```

and `_builder.build(dives, primaryDiveId: targetDiveId, alignment: alignment)`. Import `profile_alignment.dart`.

`runDiveConsolidation`: add `ConsolidationAlignment? alignment,` after `required VoidCallback onConsolidated,` and pass `alignment: alignment` to `service.apply`. Import `profile_alignment.dart`.

Fake service: add the field and parameter:

```dart
  ConsolidationAlignment? capturedAlignment;

  @override
  Future<DiveConsolidationOutcome> apply({
    required String targetDiveId,
    required List<String> secondaryDiveIds,
    ConsolidationAlignment? alignment,
  }) async {
    capturedTargetDiveId = targetDiveId;
    capturedSecondaryDiveIds = secondaryDiveIds;
    capturedAlignment = alignment;
```

- [ ] **Step 5: Regenerate the Mockito mocks** (they mock `DiveConsolidationService` and are gitignored build output)

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: exits 0.

- [ ] **Step 6: Run to verify pass**

Run: `flutter test test/features/dive_log/data/services/ test/features/dive_log/presentation/widgets/run_dive_consolidation_test.dart test/features/dive_log/data/repositories/dive_consolidation_test.dart test/features/import_wizard/data/adapters/`
Expected: all PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format lib/features/dive_log test/features/dive_log test/helpers/fake_dive_consolidation_service.dart
flutter analyze
git add lib/features/dive_log/data/services/dive_consolidation_service.dart lib/features/dive_log/presentation/widgets/run_dive_consolidation.dart test/helpers/fake_dive_consolidation_service.dart test/features/dive_log/data/services/dive_consolidation_service_series_test.dart test/features/dive_log/presentation/widgets/run_dive_consolidation_test.dart
git commit -m "feat(dive-log): pass the consolidation alignment through apply"
```

---

### Task 4: Strings in every locale

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the 10 locale ARBs
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces getters: `diveLog_combine_modeJoin`, `diveLog_combine_modeMerge`, `diveLog_consolidate_alignmentLabel`, `diveLog_consolidate_alignBestFit`, `diveLog_consolidate_alignStarts`, `diveLog_consolidate_sameDiveHint`, `diveLog_consolidate_clockNote`, `diveLog_consolidate_noProfileFallback`.

- [ ] **Step 1: Insert the keys by anchor line** with a scratchpad Python script (python3.14). For every ARB, insert each new key as `'  "%s": %s,' % (key, json.dumps(value, ensure_ascii=False))`. In `app_en.arb` the two `diveLog_combine_mode*` keys go directly after the `"diveLog_combine_longSurfaceWarning"` line and the six `diveLog_consolidate_*` keys directly after `"diveLog_consolidate_confirm"` (keeping it sorted); in the locale ARBs all eight go after the `"diveLog_consolidate_undone"` line. Never `json.dump` a whole file. After writing, `json.loads` every file, and check `git diff --numstat -- lib/l10n/arb/*.arb` shows exactly `8 0` per ARB.

| Key | en | de | es | fr | it |
| --- | --- | --- | --- | --- | --- |
| modeJoin | Join into one dive | Zu einem Tauchgang verbinden | Unir en una inmersión | Joindre en une seule plongée | Concatena in un'unica immersione |
| modeMerge | Merge as another computer | Als weiteren Computer zusammenführen | Fusionar como otro ordenador | Fusionner comme un autre ordinateur | Unisci come un altro computer |
| alignmentLabel | Line up the records by | Aufzeichnungen ausrichten nach | Alinear los registros por | Aligner les enregistrements par | Allinea le registrazioni per |
| alignBestFit | Best fit | Beste Übereinstimmung | Mejor ajuste | Meilleure correspondance | Miglior corrispondenza |
| alignStarts | Align starts | Anfänge ausrichten | Alinear inicios | Aligner les débuts | Allinea gli inizi |
| sameDiveHint | These profiles look like the same dive recorded by two computers. | Diese Profile sehen aus wie derselbe Tauchgang, aufgezeichnet von zwei Computern. | Estos perfiles parecen la misma inmersión registrada por dos ordenadores. | Ces profils ressemblent à la même plongée enregistrée par deux ordinateurs. | Questi profili sembrano la stessa immersione registrata da due computer. |
| clockNote | These records don't overlap in time, so one computer's clock is probably off. The dive keeps the primary computer's time. | Diese Aufzeichnungen überschneiden sich zeitlich nicht, daher geht die Uhr eines Computers wahrscheinlich falsch. Der Tauchgang behält die Zeit des primären Computers. | Estos registros no se superponen en el tiempo, así que probablemente el reloj de un ordenador está mal. La inmersión conserva la hora del ordenador principal. | Ces enregistrements ne se chevauchent pas dans le temps : l'horloge d'un ordinateur est probablement décalée. La plongée garde l'heure de l'ordinateur principal. | Queste registrazioni non si sovrappongono nel tempo, quindi l'orologio di un computer è probabilmente sbagliato. L'immersione mantiene l'ora del computer principale. |
| noProfileFallback | A record has no depth profile to match, so its start is lined up with the primary's. | Eine Aufzeichnung hat kein Tiefenprofil zum Abgleichen, daher wird ihr Anfang an dem des primären Computers ausgerichtet. | Un registro no tiene perfil de profundidad para comparar, así que su inicio se alinea con el del principal. | Un enregistrement n'a pas de profil de profondeur à comparer, son début est donc aligné sur celui du principal. | Una registrazione non ha un profilo di profondità da confrontare, quindi il suo inizio viene allineato a quello del principale. |

| Key | nl | pt | hu |
| --- | --- | --- | --- |
| modeJoin | Aan elkaar koppelen tot één duik | Juntar em um mergulho | Összefűzés egy merüléssé |
| modeMerge | Samenvoegen als extra computer | Mesclar como outro computador | Összevonás másik számítógépként |
| alignmentLabel | Registraties uitlijnen op | Alinhar os registros por | Felvételek igazítása |
| alignBestFit | Beste overeenkomst | Melhor ajuste | Legjobb illeszkedés |
| alignStarts | Begin uitlijnen | Alinhar inícios | Kezdetek igazítása |
| sameDiveHint | Deze profielen lijken op dezelfde duik, vastgelegd door twee computers. | Estes perfis parecem o mesmo mergulho registrado por dois computadores. | Ezek a profilok ugyanannak a merülésnek tűnnek, amelyet két számítógép rögzített. |
| clockNote | Deze registraties overlappen niet in tijd, dus de klok van een computer staat waarschijnlijk verkeerd. De duik behoudt de tijd van de primaire computer. | Estes registros não se sobrepõem no tempo, então o relógio de um computador provavelmente está errado. O mergulho mantém a hora do computador principal. | Ezek a felvételek időben nem fedik egymást, így valószínűleg az egyik számítógép órája rosszul jár. A merülés az elsődleges számítógép idejét tartja meg. |
| noProfileFallback | Een registratie heeft geen diepteprofiel om te vergelijken, dus het begin wordt uitgelijnd met dat van de primaire computer. | Um registro não tem perfil de profundidade para comparar, então o início dele é alinhado com o do principal. | Az egyik felvételnek nincs összevethető mélységprofilja, ezért a kezdete az elsődleges számítógépéhez igazodik. |

| Key | ar | he | zh |
| --- | --- | --- | --- |
| modeJoin | ربط في غوصة واحدة | חיבור לצלילה אחת | 连接为一次潜水 |
| modeMerge | دمج ككمبيوتر إضافي | מיזוג כמחשב נוסף | 作为另一台电脑合并 |
| alignmentLabel | محاذاة السجلات حسب | יישור הרשומות לפי | 记录对齐方式 |
| alignBestFit | أفضل تطابق | התאמה מיטבית | 最佳匹配 |
| alignStarts | محاذاة البدايات | יישור התחלות | 对齐开始时间 |
| sameDiveHint | تبدو هذه الملفات كأنها الغوصة نفسها سجّلها جهازا كمبيوتر. | הפרופילים האלה נראים כמו אותה צלילה שתועדה על ידי שני מחשבים. | 这些剖面看起来是两台电脑记录的同一次潜水。 |
| clockNote | هذه السجلات لا تتداخل زمنيًا، لذا ربما تكون ساعة أحد أجهزة الكمبيوتر خاطئة. تحتفظ الغوصة بوقت الكمبيوتر الأساسي. | הרשומות האלה לא חופפות בזמן, כך שכנראה השעון של אחד המחשבים שגוי. הצלילה שומרת על השעה של המחשב הראשי. | 这些记录在时间上没有重叠，可能是某台电脑的时钟不准。潜水保留主电脑的时间。 |
| noProfileFallback | أحد السجلات لا يحتوي على ملف عمق للمطابقة، لذا تتم محاذاة بدايته مع بداية الأساسي. | לאחת הרשומות אין פרופיל עומק להתאמה, ולכן ההתחלה שלה מיושרת להתחלה של הראשי. | 有一条记录没有可供匹配的深度剖面，因此将其开始时间与主电脑对齐。 |

- [ ] **Step 2: Generate** (only now, after every ARB has the keys)

Run: `flutter gen-l10n`
Then: `grep -A2 "get diveLog_consolidate_clockNote" lib/l10n/arb/app_localizations_de.dart` shows the German text, not English.

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/arb/
git commit -m "i18n(dive-log): strings for merging non-overlapping dives as another computer"
```

---

### Task 5: Mode selector and alignment controls

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/consolidation_alignment_controls.dart`
- Test: `test/features/dive_log/presentation/widgets/consolidation_alignment_controls_test.dart`

**Interfaces:**
- Consumes: Task 1 `ConsolidationAlignment`; Task 4 strings.
- Produces:
  - `enum CombineMode { join, merge }`
  - `CombineModeSelector({required CombineMode mode, required ValueChanged<CombineMode> onChanged, bool showSameDiveHint = false})`
  - `ConsolidationAlignmentControls({required ConsolidationAlignment alignment, required ValueChanged<ConsolidationAlignment> onChanged, bool showFallbackNote = false})`

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/services/profile_alignment.dart';
import 'package:submersion/features/dive_log/presentation/widgets/consolidation_alignment_controls.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Future<void> _pump(WidgetTester tester, Widget child, {double width = 400}) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(child: SizedBox(width: width, child: child)),
        ),
      ),
    );

void main() {
  group('CombineModeSelector', () {
    testWidgets('reports the tapped mode', (tester) async {
      CombineMode? picked;
      await _pump(
        tester,
        CombineModeSelector(
          mode: CombineMode.join,
          onChanged: (m) => picked = m,
        ),
      );
      await tester.tap(find.text('Merge as another computer'));
      expect(picked, CombineMode.merge);
    });

    testWidgets('shows the same-dive hint only when asked', (tester) async {
      const hint =
          'These profiles look like the same dive recorded by two computers.';
      await _pump(
        tester,
        CombineModeSelector(mode: CombineMode.merge, onChanged: (_) {}),
      );
      expect(find.text(hint), findsNothing);
      await _pump(
        tester,
        CombineModeSelector(
          mode: CombineMode.merge,
          onChanged: (_) {},
          showSameDiveHint: true,
        ),
      );
      expect(find.text(hint), findsOneWidget);
    });

    testWidgets('fits a phone-width dialog without overflowing', (
      tester,
    ) async {
      await _pump(
        tester,
        CombineModeSelector(mode: CombineMode.join, onChanged: (_) {}),
        width: 262,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('ConsolidationAlignmentControls', () {
    testWidgets('shows the clock note and reports the tapped alignment', (
      tester,
    ) async {
      ConsolidationAlignment? picked;
      await _pump(
        tester,
        ConsolidationAlignmentControls(
          alignment: ConsolidationAlignment.bestFit,
          onChanged: (a) => picked = a,
        ),
      );
      expect(find.textContaining("don't overlap in time"), findsOneWidget);
      expect(find.text('Line up the records by'), findsOneWidget);
      await tester.tap(find.text('Align starts'));
      expect(picked, ConsolidationAlignment.starts);
    });

    testWidgets('shows the no-profile note only when asked', (tester) async {
      const note =
          "A record has no depth profile to match, so its start is lined up "
          "with the primary's.";
      await _pump(
        tester,
        ConsolidationAlignmentControls(
          alignment: ConsolidationAlignment.bestFit,
          onChanged: (_) {},
        ),
      );
      expect(find.text(note), findsNothing);
      await _pump(
        tester,
        ConsolidationAlignmentControls(
          alignment: ConsolidationAlignment.bestFit,
          onChanged: (_) {},
          showFallbackNote: true,
        ),
      );
      expect(find.text(note), findsOneWidget);
    });

    testWidgets('fits a phone-width dialog without overflowing', (
      tester,
    ) async {
      await _pump(
        tester,
        ConsolidationAlignmentControls(
          alignment: ConsolidationAlignment.starts,
          onChanged: (_) {},
          showFallbackNote: true,
        ),
        width: 262,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/widgets/consolidation_alignment_controls_test.dart`
Expected: FAIL, file does not exist.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/services/profile_alignment.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the combine dialog does with dives that do not overlap in time
/// (#552).
enum CombineMode {
  /// Join them end to end into one continuous dive.
  join,

  /// Fold them into one dive as additional dive computers.
  merge,
}

/// The Join / Merge choice at the top of the combine dialog, shown when a
/// non-overlapping selection could also be merged as computers.
class CombineModeSelector extends StatelessWidget {
  const CombineModeSelector({
    super.key,
    required this.mode,
    required this.onChanged,
    this.showSameDiveHint = false,
  });

  final CombineMode mode;
  final ValueChanged<CombineMode> onChanged;

  /// Whether the profiles matched well enough to call the records one dive.
  final bool showSameDiveHint;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<CombineMode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: CombineMode.join,
              label: Text(l10n.diveLog_combine_modeJoin),
            ),
            ButtonSegment(
              value: CombineMode.merge,
              label: Text(l10n.diveLog_combine_modeMerge),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (selection) => onChanged(selection.single),
        ),
        if (showSameDiveHint) ...[
          const SizedBox(height: 8),
          _Note(
            icon: Icons.lightbulb_outline,
            text: l10n.diveLog_consolidate_sameDiveHint,
          ),
        ],
      ],
    );
  }
}

/// The clock note and the Best fit / Align starts toggle, shown above the
/// consolidation preview when a secondary does not overlap the primary.
class ConsolidationAlignmentControls extends StatelessWidget {
  const ConsolidationAlignmentControls({
    super.key,
    required this.alignment,
    required this.onChanged,
    this.showFallbackNote = false,
  });

  final ConsolidationAlignment alignment;
  final ValueChanged<ConsolidationAlignment> onChanged;

  /// Whether best fit had no profile to match for some record.
  final bool showFallbackNote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Note(icon: Icons.schedule, text: l10n.diveLog_consolidate_clockNote),
        const SizedBox(height: 12),
        Text(
          l10n.diveLog_consolidate_alignmentLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<ConsolidationAlignment>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: ConsolidationAlignment.bestFit,
              label: Text(l10n.diveLog_consolidate_alignBestFit),
            ),
            ButtonSegment(
              value: ConsolidationAlignment.starts,
              label: Text(l10n.diveLog_consolidate_alignStarts),
            ),
          ],
          selected: {alignment},
          onSelectionChanged: (selection) => onChanged(selection.single),
        ),
        if (showFallbackNote) ...[
          const SizedBox(height: 8),
          _Note(
            icon: Icons.info_outline,
            text: l10n.diveLog_consolidate_noProfileFallback,
          ),
        ],
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run to verify pass.** If either phone-width test overflows, the `SegmentedButton` is not wrapping its labels at 262 px: stop and ask the user before switching the control (it is the approved "segmented choice").

Run: `flutter test test/features/dive_log/presentation/widgets/consolidation_alignment_controls_test.dart`
Expected: all PASS.

- [ ] **Step 5: Format, analyze, architecture, commit**

```bash
dart format lib/features/dive_log/presentation/widgets/consolidation_alignment_controls.dart test/features/dive_log/presentation/widgets/consolidation_alignment_controls_test.dart
flutter analyze lib/features/dive_log test/features/dive_log
flutter test test/architecture/
git add lib/features/dive_log/presentation/widgets/consolidation_alignment_controls.dart test/features/dive_log/presentation/widgets/consolidation_alignment_controls_test.dart
git commit -m "feat(dive-log): join or merge selector and alignment toggle for combine"
```

---

### Task 6: Wire the combine dialog

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/combine_dives_dialog.dart`
- Test: `test/features/dive_log/presentation/widgets/combine_dives_dialog_test.dart`

**Interfaces:**
- Consumes: Tasks 2, 3 and 5.

- [ ] **Step 1: Write the failing dialog tests.** In the test file: give `pumpCombineDialog` a `Size size = const Size(1024, 768)` parameter used for `tester.view.physicalSize`; import `profile_alignment.dart`; add the helpers and group below; and replace the `consolidateOnly` test "a non-overlapping pair shows the not-overlapping error ..." with the two `consolidateOnly` tests in the group. In the existing test "confirming calls DiveConsolidationService.apply with the selected primary ...", add `expect(service.capturedAlignment, isNull);`.

```dart
/// A multilevel reef dive sampled every 10 s; [lead] seconds at the surface
/// first, depths multiplied by [scale].
List<domain.DiveProfilePoint> _reef({int lead = 0, double scale = 1.0}) {
  const knots = <(int, double)>[
    (0, 0), (120, 18), (240, 22), (600, 21), (900, 16), (1300, 14),
    (1700, 10), (2200, 8), (2400, 5), (2580, 5), (2760, 4.8), (2880, 0),
  ];
  double at(int t) {
    for (var i = 1; i < knots.length; i++) {
      final (t0, d0) = knots[i - 1];
      final (t1, d1) = knots[i];
      if (t <= t1) return d0 + (d1 - d0) * (t - t0) / (t1 - t0);
    }
    return 0;
  }

  return [
    for (var t = 0; t <= 2880 + lead; t += 10)
      domain.DiveProfilePoint(
        timestamp: t,
        depth: t < lead ? 0 : at(t - lead) * scale,
      ),
  ];
}

/// A 35 m square dive, nothing like [_reef].
List<domain.DiveProfilePoint> _square() => [
  for (var t = 0; t <= 2040; t += 10)
    domain.DiveProfilePoint(
      timestamp: t,
      depth: t < 90 ? t * 35 / 90 : (t < 1800 ? 35 : 6),
    ),
];

/// One dive on two computers, the second's clock 66 minutes fast.
List<domain.Dive> _skewedPair({String? serialB = 'serial-b'}) => [
  diveAt('a', DateTime.utc(2026, 7, 1, 9), runtimeMin: 48,
      diveComputerModel: 'Perdix', diveComputerSerial: 'serial-a',
      profile: _reef()),
  diveAt('b', DateTime.utc(2026, 7, 1, 10, 6), runtimeMin: 48,
      diveComputerModel: 'Teric', diveComputerSerial: serialB,
      profile: _reef(lead: 40, scale: 1.03)),
];

const _sameDiveHint =
    'These profiles look like the same dive recorded by two computers.';
const _notOverlapping =
    "These dives don't overlap in time, so they can't be merged as the same "
    'dive.';
```

```dart
  group('non-overlapping dives from different computers (#552)', () {
    testWidgets('preselects Merge with the hint when the profiles match', (
      tester,
    ) async {
      await pumpCombineDialog(tester, dives: _skewedPair());

      expect(find.text('Join into one dive'), findsOneWidget);
      expect(find.text('Merge as another computer'), findsOneWidget);
      expect(find.text(_sameDiveHint), findsOneWidget);
      expect(find.text('Best fit'), findsOneWidget);
      expect(find.textContaining("don't overlap in time, so one"),
          findsOneWidget);
      expect(find.text('Keep as one dive with both computers'),
          findsOneWidget);
      expect(find.text('Combine into one dive'), findsNothing);
    });

    testWidgets('Join stays selected when the profiles differ', (
      tester,
    ) async {
      final dives = _skewedPair();
      await pumpCombineDialog(tester, dives: [
        dives.first,
        diveAt('b', DateTime.utc(2026, 7, 1, 10, 6), runtimeMin: 34,
            diveComputerSerial: 'serial-b', profile: _square()),
      ]);

      expect(find.text('Merge as another computer'), findsOneWidget);
      expect(find.text(_sameDiveHint), findsNothing);
      expect(find.text('Combine into one dive'), findsOneWidget);
    });

    testWidgets('no preselect when a dive has no computer serial', (
      tester,
    ) async {
      await pumpCombineDialog(tester, dives: _skewedPair(serialB: null));

      expect(find.text('Merge as another computer'), findsOneWidget);
      expect(find.text(_sameDiveHint), findsNothing);
      expect(find.text('Combine into one dive'), findsOneWidget);
    });

    testWidgets('no Merge choice when both dives come from one computer', (
      tester,
    ) async {
      await pumpCombineDialog(tester, dives: _skewedPair(serialB: 'serial-a'));

      expect(find.text('Merge as another computer'), findsNothing);
      expect(find.text('Combine into one dive'), findsOneWidget);
    });

    testWidgets('switching to Join shows the sequential preview', (
      tester,
    ) async {
      await pumpCombineDialog(tester, dives: _skewedPair());

      await tester.tap(find.text('Join into one dive'));
      await tester.pumpAndSettle();

      expect(find.text('Combine into one dive'), findsOneWidget);
      expect(find.text('Best fit'), findsNothing);
    });

    testWidgets('Align starts redraws the preview at offset 0', (
      tester,
    ) async {
      await pumpCombineDialog(tester, dives: _skewedPair());
      int secondStart() => tester
          .widget<DiveSparkline>(find.byType(DiveSparkline))
          .extraSeries
          .single
          .profile
          .first
          .timestamp;

      expect(secondStart(), closeTo(-40, 2));
      await tester.tap(find.text('Align starts'));
      await tester.pumpAndSettle();
      expect(secondStart(), 0);
    });

    testWidgets('confirming Merge passes the alignment to apply', (
      tester,
    ) async {
      final service = FakeDiveConsolidationService(mergedDiveId: 'a');
      await pumpCombineDialog(
        tester,
        dives: _skewedPair(),
        consolidationService: service,
      );

      await tester.tap(find.text('Align starts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep as one dive with both computers'));
      await tester.pumpAndSettle();

      expect(service.capturedTargetDiveId, 'a');
      expect(service.capturedSecondaryDiveIds, ['b']);
      expect(service.capturedAlignment, ConsolidationAlignment.starts);
    });

    testWidgets('a mixed selection shows the alignment toggle instead of the '
        'not-overlapping error', (tester) async {
      final service = FakeDiveConsolidationService(mergedDiveId: 'a');
      await pumpCombineDialog(
        tester,
        dives: [
          diveAt('a', DateTime.utc(2026, 7, 1, 9), runtimeMin: 48,
              diveComputerSerial: 'serial-a', profile: _reef()),
          diveAt('b', DateTime.utc(2026, 7, 1, 9, 5), runtimeMin: 48,
              diveComputerSerial: 'serial-b', profile: _reef()),
          diveAt('c', DateTime.utc(2026, 7, 1, 10, 30), runtimeMin: 48,
              diveComputerSerial: 'serial-c', profile: _reef(lead: 40)),
        ],
        consolidationService: service,
      );

      expect(find.text(_notOverlapping), findsNothing);
      expect(find.text('Best fit'), findsOneWidget);
      expect(find.byType(RadioListTile<String>), findsNWidgets(3));
      expect(find.text('Join into one dive'), findsNothing);

      await tester.tap(find.text('Keep as one dive with both computers'));
      await tester.pumpAndSettle();
      expect(service.capturedAlignment, ConsolidationAlignment.bestFit);
    });

    testWidgets('consolidateOnly: a non-overlapping pair opens the Merge '
        'panel with the toggle and no Join choice', (tester) async {
      await pumpCombineDialog(
        tester,
        dives: [
          diveAt('a', DateTime.utc(2026, 7, 1, 9)),
          diveAt('b', DateTime.utc(2026, 7, 1, 10)),
        ],
        consolidateOnly: true,
      );

      expect(find.text(_notOverlapping), findsNothing);
      expect(find.text('Best fit'), findsOneWidget);
      expect(find.text('Keep as one dive with both computers'),
          findsOneWidget);
      expect(find.text('Join into one dive'), findsNothing);
      expect(find.text('Combine into one dive'), findsNothing);
    });

    testWidgets('consolidateOnly: one computer still shows the '
        'same-computer error', (tester) async {
      await pumpCombineDialog(
        tester,
        dives: [
          diveAt('a', DateTime.utc(2026, 7, 1, 9), diveComputerSerial: 'x'),
          diveAt('b', DateTime.utc(2026, 7, 1, 10), diveComputerSerial: 'x'),
        ],
        consolidateOnly: true,
      );

      expect(find.textContaining('same dive computer'), findsOneWidget);
    });

    testWidgets('the sequential preview fits a phone-width dialog', (
      tester,
    ) async {
      await pumpCombineDialog(
        tester,
        dives: _skewedPair(serialB: 'serial-a'),
        size: const Size(390, 844),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Combine into one dive'), findsOneWidget);
    });

    testWidgets('the Merge panel fits a phone-width dialog', (tester) async {
      await pumpCombineDialog(
        tester,
        dives: _skewedPair(),
        size: const Size(390, 844),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Best fit'), findsOneWidget);
    });
  });
```

Also check `test/features/data_quality/` for a test asserting the old not-overlapping text on a `consolidateOnly` open: `grep -rn "don't overlap in time" test/`. Update any hit to the new expectation.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/widgets/combine_dives_dialog_test.dart`
Expected: the new tests FAIL (no mode selector, the error panel still shown); the phone-width sequential test fails on the 3 px `Row` overflow.

- [ ] **Step 3: Implement in `combine_dives_dialog.dart`**

1. Imports: `profile_alignment.dart` and `consolidation_alignment_controls.dart`.
2. Class doc: add a sentence: "A non-overlapping selection from different computers can instead be merged as additional computers, aligned by profile (#552)."
3. State fields after `_selectedPrimaryId`:

```dart
  /// Whether a non-overlapping selection may instead be merged as additional
  /// computers (#552): consolidation accepts it once an alignment mode
  /// replaces the overlap test.
  bool _mergeAvailable = false;

  /// Whether the records look like one dive from different computers, which
  /// preselects Merge and shows a hint.
  bool _looksLikeSameDive = false;

  CombineMode _mode = CombineMode.join;

  /// How a secondary that does not overlap the primary is lined up.
  ConsolidationAlignment _alignment = ConsolidationAlignment.bestFit;

  /// The last consolidation plan and its inputs: best fit scans every
  /// candidate shift, so it is not rebuilt on every frame.
  ({String? primaryId, ConsolidationAlignment alignment})? _planKey;
  DiveConsolidationPlan? _plan;
```

4. In `_load`, compute the classification first and initialize the merge choice inside `setState`:

```dart
      final classification = const DiveMergeBuilder().classify(dives);
      setState(() {
        _dives = dives;
        _classification = classification;
        if (classification is MergeSequential) _initMergeChoice(dives);
      });
```

```dart
  /// Whether this non-overlapping selection can be merged as additional
  /// computers, and whether Merge should be the preselected choice.
  void _initMergeChoice(List<domain.Dive> dives) {
    const builder = DiveConsolidationBuilder();
    final consolidation = builder.classify(
      dives,
      alignment: ConsolidationAlignment.bestFit,
    );
    if (consolidation is! ConsolidationReady) return;
    _mergeAvailable = true;
    final plan = _planFor();
    // classify() rejects a repeated serial, so a serial on every dive is what
    // proves each record came from a different computer.
    _looksLikeSameDive =
        dives.every((d) => (d.diveComputerSerial ?? '').isNotEmpty) &&
        plan.alignments.isNotEmpty &&
        plan.alignments.values.every((a) => a.isStrongMatch);
    if (_looksLikeSameDive) _mode = CombineMode.merge;
  }

  DiveConsolidationPlan _planFor() {
    final key = (primaryId: _selectedPrimaryId, alignment: _alignment);
    if (_plan == null || _planKey != key) {
      _plan = const DiveConsolidationBuilder().build(
        _dives!,
        primaryDiveId: _selectedPrimaryId,
        alignment: _alignment,
      );
      _planKey = key;
    }
    return _plan!;
  }
```

`_initMergeChoice` runs inside `setState` after `_dives` is assigned, so `_planFor` can read `_dives!`.

5. `build` switch: replace the two `MergeSequential` arms with

```dart
          MergeSequential() when widget.consolidateOnly =>
            _buildConsolidationPanel(context),
          MergeSequential() when _mergeAvailable && _mode == CombineMode.merge =>
            _buildConsolidationPanel(context),
          final MergeSequential seq => _buildPreview(context, seq),
```

6. `_buildPreview`: directly after the title `Row` inside the scrolled column, insert

```dart
                  if (_mergeAvailable) ...[
                    const SizedBox(height: 16),
                    _modeSelector(),
                  ],
```

and replace the bottom button `Row(mainAxisAlignment: MainAxisAlignment.end, ...)` with an `OverflowBar(spacing: 8, alignment: MainAxisAlignment.end, children: [TextButton(...), FilledButton(...)])` (same two buttons, drop the `SizedBox(width: 8)`). Update the comment above the consolidation panel's `OverflowBar` to say both panels use it.

```dart
  Widget _modeSelector() => CombineModeSelector(
    mode: _mode,
    showSameDiveHint: _looksLikeSameDive,
    onChanged: (mode) => setState(() => _mode = mode),
  );
```

7. `_buildConsolidationPanel`: classify with the current mode, so a mixed or non-overlapping selection is accepted:

```dart
    final classification = const DiveConsolidationBuilder().classify(
      _dives!,
      primaryDiveId: _selectedPrimaryId,
      alignment: _alignment,
    );
```

Keep the `notOverlapping` arm of the error mapping (the switch is exhaustive) and add a comment that it is unreachable here because a mode is always passed.

8. `_buildConsolidationReadyPanel`: use `final plan = _planFor();` instead of calling `build` directly. After the title `Row` insert

```dart
                  if (_mergeAvailable && !widget.consolidateOnly) ...[
                    const SizedBox(height: 16),
                    _modeSelector(),
                  ],
                  if (ready.realignedIds.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ConsolidationAlignmentControls(
                      alignment: _alignment,
                      onChanged: (a) => setState(() => _alignment = a),
                      showFallbackNote:
                          _alignment == ConsolidationAlignment.bestFit &&
                          plan.alignments.values.any((a) => a.usedFallback),
                    ),
                  ],
```

9. `_confirmConsolidation(ready)`: compute

```dart
    // A fully overlapping selection keeps the strict check at apply time, so
    // a dive moved by a sync after this preview is still rejected.
    final alignment = ready.realignedIds.isEmpty ? null : _alignment;
```

and pass `alignment: alignment` to `runDiveConsolidation`.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/dive_log/presentation/widgets/ test/features/data_quality/`
Expected: all PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_log/presentation/widgets/combine_dives_dialog.dart test/features/dive_log/presentation/widgets/combine_dives_dialog_test.dart
flutter analyze
git add lib/features/dive_log/presentation/widgets/combine_dives_dialog.dart test/features/dive_log/presentation/widgets/combine_dives_dialog_test.dart
git commit -m "feat(dive-log): merge non-overlapping dives as another computer from Combine"
```

---

### Task 7: User guide, full verification, after screenshots

**Files:**
- Modify: `docs/guide/dive-computer.md` (Multi-Computer Dives, step 4)

- [ ] **Step 1: Rewrite step 4** of "Multi-Computer Dives" (the "Merge with another dive" detail-page action it names no longer exists):

```markdown
4. Dives already imported as separate entries can be consolidated later:
   select them in the dive list and choose **Combine**. When the records
   overlap in time they are merged as one dive with each computer. When
   they do not (one computer's clock was wrong), choose **Merge as another
   computer**: Submersion lines the records up by their depth profiles
   (**Best fit**) or by their starts (**Align starts**), shows the result
   before anything is saved, and suggests Merge when two computers' profiles
   match
```

- [ ] **Step 2: Full checks**

```bash
dart format .
flutter analyze
flutter test test/features/dive_log/ test/features/data_quality/ test/features/import_wizard/ test/features/dive_import/ test/architecture/
```

Expected: no format changes left, analyze clean, all PASS.

- [ ] **Step 3: After screenshots** with the throwaway golden harness kept in the scratchpad (`combine_shots_test.dart`, run with `SHOT_LABEL=after`): default (Merge preselected), Join selected, at desktop and phone widths. Save as `01-combine-dialog-after[-phone].png` (Merge) and `02-combine-dialog-join-after[-phone].png`, then delete `test/tmp_shots/`.

- [ ] **Step 4: Commit**

```bash
git add docs/guide/dive-computer.md
git commit -m "docs(dive-log): describe merging non-overlapping dives as another computer"
```
