# Post-Dive Safety Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically analyze recorded dive profiles for safety-relevant events (rapid ascents, missed deco stops, omitted safety stops, sawtooth profiles, high surface GF) and surface them as a quiet badge on the dive list plus a neutral-toned "Safety review" section in dive detail.

**Architecture:** A pure rules engine (`SafetyReviewService`) consumes the existing `ProfileAnalysis` (produced by the Bühlmann replay in `ProfileAnalysisService`) and emits `SafetyFinding`s. Findings persist to two new child-of-dive tables (`dive_safety_reviews` marker + `dive_safety_findings`) so list badges never require replaying a profile. Computation is lazy (compute-through-cache in a Riverpod provider when a dive is viewed, or via a bulk "Analyze all dives" settings action); invalidation happens at the two profile-write choke points. Spec: `docs/superpowers/specs/2026-07-16-safety-features-design.md` (Phase 1 section).

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, go_router. Worktree: `.claude/worktrees/safety-features` (branch `worktree-safety-features`).

## Global Constraints

- All work happens in the worktree `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/safety-features`. Never touch the main checkout.
- Schema version: bump `currentSchemaVersion` from **112 → 116** (113 is claimed by PR #600's renumber, 114 by the equipment-attributes spec, 115 by PR #602 gear service ledger). Before Task 5, re-verify with `grep -n "currentSchemaVersion = " lib/core/database/database.dart` — if main has moved past 115, claim the next free number instead and use it everywhere this plan says 116.
- Child-of-dive tables carry NO hlc/updatedAt columns (mirror `DiveProfileEvents`, `lib/core/database/database.dart:1757`). Sync correctness comes from `_syncRepository.markRecordPending(...)` on writes and `_syncRepository.logDeletion(...)` per deleted row.
- Tone requirements from the spec: neutral wording ("Ascent exceeded 12 m/min for 40 s at 18 m"), no red alarm iconography on the dive list (small neutral dot only), per-finding dismiss, master + per-rule settings toggles.
- No emojis anywhere. All user-visible strings via l10n (`context.l10n.<key>`); en first, all 10 other locales in the final task.
- Anything displaying depth/rate respects the active diver's unit settings (`UnitFormatter`).
- Run `dart format .` (whole project, never a subset) before every commit. Never pipe `flutter analyze` or `flutter test` through `tail`/`head`.
- Run tests by specific file path (never the whole suite mid-task; the full suite runs on pre-push).
- Commit at the end of every task with the exact message given. No Co-Authored-By lines, no session URLs.
- After modifying any `Table` class in `database.dart`, run `dart run build_runner build --delete-conflicting-outputs` before analyzing/testing.

---

### Task 1: SafetyFinding entities + engine skeleton + rapid-ascent rule

**Files:**
- Create: `lib/features/dive_log/domain/entities/safety_finding.dart`
- Create: `lib/features/dive_log/domain/services/safety_review_service.dart`
- Test: `test/features/dive_log/domain/services/safety_review_service_test.dart`
- Test helper: `test/features/dive_log/domain/services/safety_review_fixtures.dart`

**Interfaces:**
- Consumes: `ProfileAnalysis`, `AscentRateViolation` (both exported by `package:submersion/features/dive_log/data/services/profile_analysis_service.dart` and `package:submersion/core/deco/ascent_rate_calculator.dart`).
- Produces (later tasks rely on these exact names):
  - `enum SafetyRuleId { rapidAscent, missedDecoStop, omittedSafetyStop, sawtoothProfile, highSurfaceGf }` with `String get dbValue` (the enum `name`) and `static SafetyRuleId? fromDbValue(String v)`.
  - `enum SafetySeverity { info, caution, significant }` with same `dbValue`/`fromDbValue` pattern.
  - `class SafetyFinding` — fields: `String id`, `String diveId`, `SafetyRuleId ruleId`, `SafetySeverity severity`, `int? startTimestamp`, `int? endTimestamp`, `double? value`, `int engineVersion`, `DateTime? dismissedAt`, `DateTime createdAt`; plus `copyWith`.
  - `class SafetyReviewService` — `static const int engineVersion = 1;` and
    `List<SafetyFinding> review({required String diveId, required ProfileAnalysis analysis, required DateTime now, String Function()? idGenerator})`.

- [ ] **Step 1: Write the fixture helper**

The engine's tests feed synthetic depth profiles through the REAL `ProfileAnalysisService` so fixtures stay honest. Create `test/features/dive_log/domain/services/safety_review_fixtures.dart`:

```dart
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

/// Runs the real profile analysis over a synthetic profile.
/// Default settings: air, GF 30/70, sea level.
ProfileAnalysis analyzeFixture({
  required List<double> depths,
  required List<int> timestamps,
}) {
  final service = ProfileAnalysisService();
  return service.analyze(
    diveId: 'fixture-dive',
    depths: depths,
    timestamps: timestamps,
  );
}

/// Builds (depths, timestamps) by concatenating linear segments.
/// Each segment is (targetDepth, durationSeconds); sampling every 10 s.
({List<double> depths, List<int> timestamps}) buildProfile(
  List<(double, int)> segments,
) {
  final depths = <double>[0];
  final timestamps = <int>[0];
  var t = 0;
  var d = 0.0;
  for (final (target, duration) in segments) {
    final steps = duration ~/ 10;
    for (var i = 1; i <= steps; i++) {
      t += 10;
      depths.add(d + (target - d) * i / steps);
      timestamps.add(t);
    }
    d = target;
  }
  return (depths: depths, timestamps: timestamps);
}

/// 18 m for 20 min, slow ascent with a 3-min stop at 5 m. No findings expected.
({List<double> depths, List<int> timestamps}) cleanDiveProfile() => buildProfile([
  (18, 120), // descend to 18 m over 2 min
  (18, 1200), // 20 min bottom
  (5, 160), // ascend to 5 m at ~4.9 m/min
  (5, 180), // 3-min safety stop
  (0, 90), // slow final ascent (~3.3 m/min)
]);

/// Same dive but the ascent from 18 m runs at 18 m/min (rapid, critical).
({List<double> depths, List<int> timestamps}) rapidAscentProfile() => buildProfile([
  (18, 120),
  (18, 1200),
  (0, 60), // 18 m in 60 s = 18 m/min, straight to surface
]);
```

- [ ] **Step 2: Write the failing tests**

Create `test/features/dive_log/domain/services/safety_review_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/services/safety_review_service.dart';

import 'safety_review_fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 7, 16);
  var idCounter = 0;
  String nextId() => 'finding-${idCounter++}';

  setUp(() => idCounter = 0);

  List<SafetyFinding> reviewProfile(
    ({List<double> depths, List<int> timestamps}) profile,
  ) {
    final analysis = analyzeFixture(
      depths: profile.depths,
      timestamps: profile.timestamps,
    );
    return const SafetyReviewService().review(
      diveId: 'dive-1',
      analysis: analysis,
      now: now,
      idGenerator: nextId,
    );
  }

  group('rapid ascent rule', () {
    test('clean dive produces no rapid ascent findings', () {
      final findings = reviewProfile(cleanDiveProfile());
      expect(
        findings.where((f) => f.ruleId == SafetyRuleId.rapidAscent),
        isEmpty,
      );
    });

    test('18 m/min ascent produces a significant rapid ascent finding', () {
      final findings = reviewProfile(rapidAscentProfile());
      final rapid = findings
          .where((f) => f.ruleId == SafetyRuleId.rapidAscent)
          .toList();
      expect(rapid, isNotEmpty);
      expect(rapid.first.severity, SafetySeverity.significant);
      expect(rapid.first.value, greaterThan(12));
      expect(rapid.first.startTimestamp, isNotNull);
      expect(rapid.first.endTimestamp, isNotNull);
      expect(rapid.first.engineVersion, SafetyReviewService.engineVersion);
      expect(rapid.first.diveId, 'dive-1');
    });
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/domain/services/safety_review_service_test.dart`
Expected: FAIL — `safety_finding.dart` / `safety_review_service.dart` do not exist (compile error).

- [ ] **Step 4: Write the entity**

Create `lib/features/dive_log/domain/entities/safety_finding.dart`:

```dart
import 'package:equatable/equatable.dart';

/// The rule that produced a safety finding.
enum SafetyRuleId {
  rapidAscent,
  missedDecoStop,
  omittedSafetyStop,
  sawtoothProfile,
  highSurfaceGf;

  String get dbValue => name;

  static SafetyRuleId? fromDbValue(String value) {
    for (final rule in SafetyRuleId.values) {
      if (rule.name == value) return rule;
    }
    return null;
  }
}

/// Neutral severity scale for safety findings. Not alarm levels: the UI
/// renders these with muted styling per the safety-features spec.
enum SafetySeverity {
  info,
  caution,
  significant;

  String get dbValue => name;

  static SafetySeverity fromDbValue(String value) {
    for (final s in SafetySeverity.values) {
      if (s.name == value) return s;
    }
    return SafetySeverity.info;
  }
}

/// One observation from the post-dive safety review engine.
///
/// Findings carry the raw numbers (value, profile time range); user-facing
/// text is composed at display time from localized templates so stored rows
/// stay language-neutral.
class SafetyFinding extends Equatable {
  final String id;
  final String diveId;
  final SafetyRuleId ruleId;
  final SafetySeverity severity;

  /// Profile time range in seconds from dive start (null when the finding
  /// applies to the dive as a whole).
  final int? startTimestamp;
  final int? endTimestamp;

  /// Rule-specific value: peak ascent rate (m/min), max ceiling excess (m),
  /// remaining safety-stop seconds, sawtooth cycle count, or surface GF (%).
  final double? value;

  final int engineVersion;
  final DateTime? dismissedAt;
  final DateTime createdAt;

  const SafetyFinding({
    required this.id,
    required this.diveId,
    required this.ruleId,
    required this.severity,
    this.startTimestamp,
    this.endTimestamp,
    this.value,
    required this.engineVersion,
    this.dismissedAt,
    required this.createdAt,
  });

  bool get isDismissed => dismissedAt != null;

  SafetyFinding copyWith({
    String? id,
    String? diveId,
    SafetyRuleId? ruleId,
    SafetySeverity? severity,
    int? startTimestamp,
    int? endTimestamp,
    double? value,
    int? engineVersion,
    DateTime? dismissedAt,
    bool clearDismissedAt = false,
    DateTime? createdAt,
  }) {
    return SafetyFinding(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      ruleId: ruleId ?? this.ruleId,
      severity: severity ?? this.severity,
      startTimestamp: startTimestamp ?? this.startTimestamp,
      endTimestamp: endTimestamp ?? this.endTimestamp,
      value: value ?? this.value,
      engineVersion: engineVersion ?? this.engineVersion,
      dismissedAt: clearDismissedAt ? null : (dismissedAt ?? this.dismissedAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveId,
    ruleId,
    severity,
    startTimestamp,
    endTimestamp,
    value,
    engineVersion,
    dismissedAt,
    createdAt,
  ];
}
```

- [ ] **Step 5: Write the engine with the rapid-ascent rule**

Create `lib/features/dive_log/domain/services/safety_review_service.dart`:

```dart
import 'package:uuid/uuid.dart';

import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';

/// Pure rules engine for the post-dive safety review.
///
/// Consumes a completed [ProfileAnalysis] (the Buhlmann replay of a recorded
/// profile) and emits neutral [SafetyFinding]s. Every rule runs every time;
/// per-rule visibility toggles are applied at display time so stored results
/// do not depend on settings.
class SafetyReviewService {
  /// Bump when rule logic or thresholds change. Stored reviews with an older
  /// version are recomputed lazily, so history is re-graded honestly instead
  /// of silently diverging from what the user was shown.
  static const int engineVersion = 1;

  const SafetyReviewService();

  List<SafetyFinding> review({
    required String diveId,
    required ProfileAnalysis analysis,
    required DateTime now,
    String Function()? idGenerator,
  }) {
    final nextId = idGenerator ?? const Uuid().v4;
    final findings = <SafetyFinding>[];

    findings.addAll(_rapidAscentFindings(diveId, analysis, now, nextId));

    return findings;
  }

  List<SafetyFinding> _rapidAscentFindings(
    String diveId,
    ProfileAnalysis analysis,
    DateTime now,
    String Function() nextId,
  ) {
    return [
      for (final violation in analysis.ascentRateViolations)
        SafetyFinding(
          id: nextId(),
          diveId: diveId,
          ruleId: SafetyRuleId.rapidAscent,
          severity: violation.isCritical
              ? SafetySeverity.significant
              : SafetySeverity.caution,
          startTimestamp: violation.startTimestamp,
          endTimestamp: violation.endTimestamp,
          value: violation.maxRate,
          engineVersion: engineVersion,
          createdAt: now,
        ),
    ];
  }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/domain/services/safety_review_service_test.dart`
Expected: PASS (both tests). If the clean dive unexpectedly produces a rapid-ascent finding, its ascent segments are too fast for the smoothing window — slow the fixture's final ascent (increase segment durations), do NOT loosen the rule.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add lib/features/dive_log/domain/entities/safety_finding.dart lib/features/dive_log/domain/services/safety_review_service.dart test/features/dive_log/domain/services/
git commit -m "feat: add safety review engine with rapid ascent rule"
```

---

### Task 2: Missed deco stop + high surface GF rules

**Files:**
- Modify: `lib/features/dive_log/domain/services/safety_review_service.dart`
- Modify: `test/features/dive_log/domain/services/safety_review_fixtures.dart`
- Test: `test/features/dive_log/domain/services/safety_review_service_test.dart`

**Interfaces:**
- Consumes: `analysis.ndlCurve` (`List<int>`, -1 while in deco), `analysis.ceilingCurve` (`List<double>` meters), `analysis.ascentRates` (`List<AscentRatePoint>` — per-sample `timestamp` and `depth`), `analysis.decoStatuses` (`List<DecoStatus>` — `surfGf` getter, `gfHigh` field).
- Produces: findings with `ruleId == SafetyRuleId.missedDecoStop` (severity always `significant`, `value` = max ceiling excess in meters) and `ruleId == SafetyRuleId.highSurfaceGf` (severity always `info`, `value` = surfacing GF percent).

- [ ] **Step 1: Add a deco-violation fixture**

Append to `safety_review_fixtures.dart`:

```dart
/// 45 m for 25 min builds a real deco obligation, then a direct 9 m/min
/// ascent to the surface blows through every required stop.
({List<double> depths, List<int> timestamps}) missedDecoStopProfile() =>
    buildProfile([
      (45, 180), // descend to 45 m over 3 min
      (45, 1500), // 25 min bottom time on air
      (0, 300), // straight up at 9 m/min, no stops
    ]);
```

- [ ] **Step 2: Write the failing tests**

Add to `safety_review_service_test.dart` (inside `main`, after the rapid-ascent group):

```dart
  group('missed deco stop rule', () {
    test('clean dive produces no missed stop findings', () {
      final findings = reviewProfile(cleanDiveProfile());
      expect(
        findings.where((f) => f.ruleId == SafetyRuleId.missedDecoStop),
        isEmpty,
      );
    });

    test('blowing through deco stops produces a significant finding', () {
      final findings = reviewProfile(missedDecoStopProfile());
      final missed = findings
          .where((f) => f.ruleId == SafetyRuleId.missedDecoStop)
          .toList();
      expect(missed, isNotEmpty);
      expect(missed.first.severity, SafetySeverity.significant);
      expect(missed.first.value, greaterThan(0));
    });
  });

  group('high surface GF rule', () {
    test('clean dive surfaces below GF-high', () {
      final findings = reviewProfile(cleanDiveProfile());
      expect(
        findings.where((f) => f.ruleId == SafetyRuleId.highSurfaceGf),
        isEmpty,
      );
    });

    test('deco violation dive surfaces above GF-high', () {
      final findings = reviewProfile(missedDecoStopProfile());
      final high = findings
          .where((f) => f.ruleId == SafetyRuleId.highSurfaceGf)
          .toList();
      expect(high, isNotEmpty);
      expect(high.first.severity, SafetySeverity.info);
      expect(high.first.value, greaterThan(70)); // fixture GF-high is 70
    });
  });
```

- [ ] **Step 3: Run tests to verify the new ones fail**

Run: `flutter test test/features/dive_log/domain/services/safety_review_service_test.dart`
Expected: the two new "produces" tests FAIL (no findings emitted); all Task 1 tests still PASS.

- [ ] **Step 4: Implement both rules**

In `safety_review_service.dart`, add two calls in `review(...)` after the rapid-ascent line:

```dart
    findings.addAll(_missedDecoStopFindings(diveId, analysis, now, nextId));
    findings.addAll(_highSurfaceGfFindings(diveId, analysis, now, nextId));
```

and the implementations:

```dart
  /// Depth above (shallower than) the computed ceiling while in deco.
  /// Contiguous ranges shorter than [_minViolationSeconds] are ignored as
  /// sample noise.
  static const int _minViolationSeconds = 10;
  static const double _ceilingToleranceMeters = 0.5;

  List<SafetyFinding> _missedDecoStopFindings(
    String diveId,
    ProfileAnalysis analysis,
    DateTime now,
    String Function() nextId,
  ) {
    final samples = analysis.ascentRates;
    final n = samples.length;
    if (n == 0 ||
        analysis.ndlCurve.length != n ||
        analysis.ceilingCurve.length != n) {
      return const [];
    }

    final findings = <SafetyFinding>[];
    int? violationStart;
    var maxExcess = 0.0;

    void close(int endTimestamp) {
      if (violationStart == null) return;
      if (endTimestamp - violationStart! >= _minViolationSeconds) {
        findings.add(
          SafetyFinding(
            id: nextId(),
            diveId: diveId,
            ruleId: SafetyRuleId.missedDecoStop,
            severity: SafetySeverity.significant,
            startTimestamp: violationStart,
            endTimestamp: endTimestamp,
            value: maxExcess,
            engineVersion: engineVersion,
            createdAt: now,
          ),
        );
      }
      violationStart = null;
      maxExcess = 0.0;
    }

    for (var i = 0; i < n; i++) {
      final inDeco = analysis.ndlCurve[i] < 0;
      final ceiling = analysis.ceilingCurve[i];
      final depth = samples[i].depth;
      final excess = ceiling - depth; // positive = shallower than ceiling
      final violating =
          inDeco && ceiling > 0 && excess > _ceilingToleranceMeters;
      if (violating) {
        violationStart ??= samples[i].timestamp;
        if (excess > maxExcess) maxExcess = excess;
      } else {
        close(i > 0 ? samples[i - 1].timestamp : samples[i].timestamp);
      }
    }
    close(samples.last.timestamp);
    return findings;
  }

  /// Surfacing GF above the configured GF-high. Informational only: the
  /// diver ended the dive with less conservatism margin than they configured.
  List<SafetyFinding> _highSurfaceGfFindings(
    String diveId,
    ProfileAnalysis analysis,
    DateTime now,
    String Function() nextId,
  ) {
    if (analysis.decoStatuses.isEmpty) return const [];
    final last = analysis.decoStatuses.last;
    final surfGf = last.surfGf;
    final threshold = last.gfHigh * 100.0;
    if (surfGf <= threshold) return const [];
    return [
      SafetyFinding(
        id: nextId(),
        diveId: diveId,
        ruleId: SafetyRuleId.highSurfaceGf,
        severity: SafetySeverity.info,
        startTimestamp: analysis.ascentRates.isEmpty
            ? null
            : analysis.ascentRates.last.timestamp,
        endTimestamp: analysis.ascentRates.isEmpty
            ? null
            : analysis.ascentRates.last.timestamp,
        value: surfGf,
        engineVersion: engineVersion,
        createdAt: now,
      ),
    ];
  }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/domain/services/safety_review_service_test.dart`
Expected: PASS. If the missed-stop test fails because the fixture never enters deco, lengthen the bottom segment (e.g. 30 min at 45 m) — verify by asserting `analysis.hadDecoObligation` is true inside the test before the findings assertion.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/dive_log/domain/services/safety_review_service.dart test/features/dive_log/domain/services/
git commit -m "feat: add missed deco stop and high surface GF rules"
```

---

### Task 3: Omitted safety stop rule

**Files:**
- Modify: `lib/features/dive_log/domain/services/safety_review_service.dart`
- Modify: `test/features/dive_log/domain/services/safety_review_fixtures.dart`
- Test: `test/features/dive_log/domain/services/safety_review_service_test.dart`

**Interfaces:**
- Consumes: `analysis.decoStatuses.last.safetyStopSeconds` (remaining recommended safety-stop seconds; 0 once completed or when a deco obligation supersedes it), `analysis.maxDepth`, `analysis.hadDecoObligation`, `analysis.ascentRates` (final depth check).
- Produces: findings with `ruleId == SafetyRuleId.omittedSafetyStop`, severity `info` (or `caution` when `maxDepth > 25`), `value` = remaining stop seconds.

- [ ] **Step 1: Add fixture**

Append to `safety_review_fixtures.dart`:

```dart
/// 25 m for 15 min (comfortably no-deco), then a steady 8 m/min ascent
/// straight to the surface with no safety stop. 8 m/min stays under the
/// 9 m/min warning threshold so only the omitted stop should flag.
({List<double> depths, List<int> timestamps}) omittedSafetyStopProfile() =>
    buildProfile([
      (25, 180),
      (25, 900),
      (0, 190), // ~7.9 m/min direct ascent
    ]);
```

- [ ] **Step 2: Write the failing tests**

Add to `safety_review_service_test.dart`:

```dart
  group('omitted safety stop rule', () {
    test('dive with a completed safety stop produces no finding', () {
      final findings = reviewProfile(cleanDiveProfile());
      expect(
        findings.where((f) => f.ruleId == SafetyRuleId.omittedSafetyStop),
        isEmpty,
      );
    });

    test('skipping the safety stop on a 25 m dive produces a caution', () {
      final findings = reviewProfile(omittedSafetyStopProfile());
      final omitted = findings
          .where((f) => f.ruleId == SafetyRuleId.omittedSafetyStop)
          .toList();
      expect(omitted, hasLength(1));
      // maxDepth 25 is not > 25, so severity stays info per the spec table.
      expect(omitted.first.severity, SafetySeverity.info);
      expect(omitted.first.value, greaterThan(30));
    });

    test('deco dives are exempt (deco stops supersede the safety stop)', () {
      final findings = reviewProfile(missedDecoStopProfile());
      expect(
        findings.where((f) => f.ruleId == SafetyRuleId.omittedSafetyStop),
        isEmpty,
      );
    });
  });
```

- [ ] **Step 3: Run tests to verify the new ones fail**

Run: `flutter test test/features/dive_log/domain/services/safety_review_service_test.dart`
Expected: the "skipping" test FAILS; the two absence tests pass vacuously.

- [ ] **Step 4: Implement the rule**

Add the call in `review(...)`:

```dart
    findings.addAll(_omittedSafetyStopFindings(diveId, analysis, now, nextId));
```

and the implementation. The Buhlmann replay already tracks safety-stop credit per sample (`DecoStatus.safetyStopSeconds` counts down as the diver accumulates time in the stop zone), so the rule reads the final sample instead of re-detecting stop holds:

```dart
  static const double _safetyStopRelevantDepthMeters = 10.0;
  static const double _safetyStopCautionDepthMeters = 25.0;
  static const int _safetyStopRemainingThresholdSeconds = 30;
  static const double _surfacedDepthMeters = 1.0;

  List<SafetyFinding> _omittedSafetyStopFindings(
    String diveId,
    ProfileAnalysis analysis,
    DateTime now,
    String Function() nextId,
  ) {
    if (analysis.decoStatuses.isEmpty || analysis.ascentRates.isEmpty) {
      return const [];
    }
    if (analysis.maxDepth <= _safetyStopRelevantDepthMeters) return const [];
    // Deco dives are handled by the missed-stop rule; the engine zeroes
    // safetyStopSeconds under a deco obligation anyway.
    if (analysis.hadDecoObligation) return const [];
    // Only meaningful when the profile actually ends at the surface.
    if (analysis.ascentRates.last.depth > _surfacedDepthMeters) {
      return const [];
    }
    final remaining = analysis.decoStatuses.last.safetyStopSeconds;
    if (remaining <= _safetyStopRemainingThresholdSeconds) return const [];
    return [
      SafetyFinding(
        id: nextId(),
        diveId: diveId,
        ruleId: SafetyRuleId.omittedSafetyStop,
        severity: analysis.maxDepth > _safetyStopCautionDepthMeters
            ? SafetySeverity.caution
            : SafetySeverity.info,
        startTimestamp: analysis.ascentRates.last.timestamp,
        endTimestamp: analysis.ascentRates.last.timestamp,
        value: remaining.toDouble(),
        engineVersion: engineVersion,
        createdAt: now,
      ),
    ];
  }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/domain/services/safety_review_service_test.dart`
Expected: PASS. If the clean dive flags, its safety-stop segment isn't accumulating credit — check that the fixture's stop is inside the engine's 3–6 m zone (5 m is) and 180 s long; print `analyzeFixture(...).decoStatuses.last.safetyStopSeconds` in a scratch test to debug, and adjust the fixture (never the thresholds) unless the engine's zone genuinely differs.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/dive_log/domain/services/safety_review_service.dart test/features/dive_log/domain/services/
git commit -m "feat: add omitted safety stop rule"
```

---

### Task 4: Sawtooth profile rule

**Files:**
- Modify: `lib/features/dive_log/domain/services/safety_review_service.dart`
- Modify: `test/features/dive_log/domain/services/safety_review_fixtures.dart`
- Test: `test/features/dive_log/domain/services/safety_review_service_test.dart`

**Interfaces:**
- Consumes: `analysis.ascentRates` (per-sample depth/timestamp).
- Produces: findings with `ruleId == SafetyRuleId.sawtoothProfile`, severity `caution`, `value` = tooth count, time range spanning first to last tooth.

- [ ] **Step 1: Add fixture**

Append to `safety_review_fixtures.dart`:

```dart
/// 20 m bottom with three 6 m up-and-back excursions (20 -> 14 -> 20),
/// then a normal slow ascent with safety stop.
({List<double> depths, List<int> timestamps}) sawtoothProfile() =>
    buildProfile([
      (20, 120),
      (20, 300),
      (14, 90), (20, 90), // tooth 1
      (20, 120),
      (14, 90), (20, 90), // tooth 2
      (20, 120),
      (14, 90), (20, 90), // tooth 3
      (20, 120),
      (5, 190), // slow ascent
      (5, 180), // safety stop
      (0, 90),
    ]);
```

- [ ] **Step 2: Write the failing tests**

```dart
  group('sawtooth profile rule', () {
    test('clean dive produces no sawtooth finding', () {
      final findings = reviewProfile(cleanDiveProfile());
      expect(
        findings.where((f) => f.ruleId == SafetyRuleId.sawtoothProfile),
        isEmpty,
      );
    });

    test('three 6 m excursions produce a sawtooth caution', () {
      final findings = reviewProfile(sawtoothProfile());
      final sawtooth = findings
          .where((f) => f.ruleId == SafetyRuleId.sawtoothProfile)
          .toList();
      expect(sawtooth, hasLength(1));
      expect(sawtooth.first.severity, SafetySeverity.caution);
      expect(sawtooth.first.value, greaterThanOrEqualTo(3));
    });
  });
```

- [ ] **Step 3: Run tests to verify the new one fails**

Run: `flutter test test/features/dive_log/domain/services/safety_review_service_test.dart`
Expected: "three 6 m excursions" FAILS.

- [ ] **Step 4: Implement the rule**

Add the call in `review(...)`:

```dart
    findings.addAll(_sawtoothFindings(diveId, analysis, now, nextId));
```

Implementation — a zigzag filter over the depth series. A "tooth" is an ascent of at least `_toothAmplitudeMeters` followed by a re-descent of at least the same amplitude (the final surface ascent never re-descends, so it can't count):

```dart
  static const double _toothAmplitudeMeters = 3.0;
  static const int _minToothCount = 3;

  List<SafetyFinding> _sawtoothFindings(
    String diveId,
    ProfileAnalysis analysis,
    DateTime now,
    String Function() nextId,
  ) {
    final samples = analysis.ascentRates;
    if (samples.length < 3) return const [];

    final points = _zigzag(samples, _toothAmplitudeMeters);

    // Count teeth: an interior turning point shallower than both neighbors
    // means the diver ascended >= amplitude and then re-descended >= amplitude
    // (the final surface ascent never re-descends, so it cannot count).
    var toothCount = 0;
    int? firstToothTs;
    int? lastToothTs;
    for (var i = 1; i < points.length - 1; i++) {
      final isShallowPoint =
          points[i].depth < points[i - 1].depth &&
          points[i].depth < points[i + 1].depth;
      if (isShallowPoint) {
        toothCount++;
        firstToothTs ??= points[i].ts;
        lastToothTs = points[i].ts;
      }
    }

    if (toothCount < _minToothCount) return const [];
    return [
      SafetyFinding(
        id: nextId(),
        diveId: diveId,
        ruleId: SafetyRuleId.sawtoothProfile,
        severity: SafetySeverity.caution,
        startTimestamp: firstToothTs,
        endTimestamp: lastToothTs,
        value: toothCount.toDouble(),
        engineVersion: engineVersion,
        createdAt: now,
      ),
    ];
  }
```

And the zigzag reducer as a private method in the same class:

```dart
  /// Reduces the depth series to alternating turning points, ignoring
  /// reversals smaller than [amplitude]. Standard zigzag filter.
  List<({int ts, double depth})> _zigzag(
    List<AscentRatePoint> samples,
    double amplitude,
  ) {
    final points = <({int ts, double depth})>[
      (ts: samples.first.timestamp, depth: samples.first.depth),
    ];
    var extreme = points.first; // furthest point of the current leg
    var direction = 0; // +1 = getting deeper, -1 = getting shallower
    for (final sample in samples.skip(1)) {
      final p = (ts: sample.timestamp, depth: sample.depth);
      if (direction == 0) {
        if ((p.depth - points.first.depth).abs() >= amplitude) {
          direction = p.depth > points.first.depth ? 1 : -1;
          extreme = p;
        }
      } else if ((direction == 1 && p.depth >= extreme.depth) ||
          (direction == -1 && p.depth <= extreme.depth)) {
        extreme = p; // same direction: extend the current leg
      } else if ((extreme.depth - p.depth).abs() >= amplitude) {
        points.add(extreme); // confirmed turning point
        direction = -direction;
        extreme = p;
      }
    }
    points.add(extreme);
    return points;
  }
```

Note: the descent-then-bottom shape means the first turning points are the surface and max depth; clean dives count 0 teeth because the safety-stop hold never re-descends by 3 m. If the clean-dive test fails, debug by printing `_zigzag`'s output for the clean fixture.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/domain/services/safety_review_service_test.dart`
Expected: PASS (all groups).

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/dive_log/domain/services/safety_review_service.dart test/features/dive_log/domain/services/
git commit -m "feat: add sawtooth profile rule"
```

---

### Task 5: Database schema v116 — findings tables + settings columns

**Files:**
- Modify: `lib/core/database/database.dart`
- Test: `test/core/database/safety_review_schema_test.dart` (create)

**Interfaces:**
- Produces (Drift-generated, used by Tasks 6, 8, 10):
  - Table class `DiveSafetyReviews` → generated `diveSafetyReviews` accessor, row class `DiveSafetyReview` — columns: `diveId` (text PK, FK dives cascade), `engineVersion` (int), `reviewedAt` (int, epoch millis).
  - Table class `DiveSafetyFindings` → generated `diveSafetyFindings` accessor, row class `DiveSafetyFinding` — columns: `id` (text PK), `diveId` (text, FK dives cascade), `ruleId` (text), `severity` (text), `startTimestamp`/`endTimestamp` (int nullable), `value` (real nullable), `engineVersion` (int), `dismissedAt` (int nullable), `createdAt` (int).
  - `DiverSettings` gains `safetyReviewEnabled` (bool, default true) and `safetyReviewDisabledRules` (text nullable, JSON array of `SafetyRuleId.dbValue` strings).

- [ ] **Step 1: Re-verify the schema ladder**

Run: `grep -n "currentSchemaVersion = " lib/core/database/database.dart`
Expected: `static const int currentSchemaVersion = 112;`. If it is already >= 116, pick the next free number and substitute it for 116 in every step below (and in the memory note at the end of the plan).

- [ ] **Step 2: Write the failing schema test**

Create `test/core/database/safety_review_schema_test.dart`. First check how existing DB tests open an in-memory database: `grep -rn "NativeDatabase.memory\|AppDatabase(" test/core/database/ | head -5` and mirror that construction exactly (there may be a shared helper; use it if present). The test body:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('safety review tables exist with expected columns', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final reviewCols = await db
        .customSelect("PRAGMA table_info('dive_safety_reviews')")
        .get();
    final reviewNames = reviewCols.map((r) => r.read<String>('name')).toSet();
    expect(
      reviewNames,
      containsAll(['dive_id', 'engine_version', 'reviewed_at']),
    );

    final findingCols = await db
        .customSelect("PRAGMA table_info('dive_safety_findings')")
        .get();
    final findingNames = findingCols.map((r) => r.read<String>('name')).toSet();
    expect(
      findingNames,
      containsAll([
        'id',
        'dive_id',
        'rule_id',
        'severity',
        'start_timestamp',
        'end_timestamp',
        'value',
        'engine_version',
        'dismissed_at',
        'created_at',
      ]),
    );

    final settingsCols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final settingsNames = settingsCols
        .map((r) => r.read<String>('name'))
        .toSet();
    expect(
      settingsNames,
      containsAll(['safety_review_enabled', 'safety_review_disabled_rules']),
    );
  });
}
```

(If `AppDatabase.forTesting` does not exist, use the constructor pattern found in the grep above.)

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/database/safety_review_schema_test.dart`
Expected: FAIL — tables missing.

- [ ] **Step 4: Add the table classes**

In `lib/core/database/database.dart`, directly after the `DiveProfileEvents` class (around line 1790), add:

```dart
/// Marker row recording that the safety review engine has analyzed a dive.
/// Lets zero-findings (clean) dives be distinguished from never-analyzed
/// dives without replaying the profile. Write-once child of Dives: no HLC
/// columns; sync uses markRecordPending/logDeletion like DiveProfileEvents.
class DiveSafetyReviews extends Table {
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  IntColumn get engineVersion => integer()();
  IntColumn get reviewedAt => integer()();

  @override
  Set<Column> get primaryKey => {diveId};
}

/// One safety review observation for a dive (see SafetyFinding entity).
/// Write-once child of Dives except for dismissed_at, which toggles.
class DiveSafetyFindings extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get ruleId => text()();
  TextColumn get severity => text()();
  IntColumn get startTimestamp => integer().nullable()();
  IntColumn get endTimestamp => integer().nullable()();
  RealColumn get value => real().nullable()();
  IntColumn get engineVersion => integer()();
  IntColumn get dismissedAt => integer().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Add both to the `@DriftDatabase(tables: [...])` list (search for `DiveProfileEvents,` in that list and add `DiveSafetyReviews,` and `DiveSafetyFindings,` after it).

- [ ] **Step 5: Add the DiverSettings columns**

In `class DiverSettings` (line ~1133), after the last `BoolColumn` in the file's grouping of display toggles, add:

```dart
  // Post-dive safety review (safety features phase 1)
  BoolColumn get safetyReviewEnabled =>
      boolean().withDefault(const Constant(true))();
  TextColumn get safetyReviewDisabledRules => text().nullable()();
```

- [ ] **Step 6: Add migration + backstop**

Bump the version: `static const int currentSchemaVersion = 116;` (line ~2208).

First read one existing idempotent assert helper to copy its exact style: `grep -n "_assertEquipmentThicknessColumn" lib/core/database/database.dart` and read that method. Then add a sibling:

```dart
  /// Idempotently creates the safety review tables, index, and settings
  /// columns (v116). Safe to re-run: used by both onUpgrade and the
  /// beforeOpen backstop so parallel-branch schema version collisions
  /// self-heal.
  Future<void> _assertSafetyReviewSchema() async {
    final m = createMigrator();
    await m.createTable(diveSafetyReviews);
    await m.createTable(diveSafetyFindings);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dive_safety_findings_dive_id '
      'ON dive_safety_findings (dive_id)',
    );
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    if (!names.contains('safety_review_enabled')) {
      await m.addColumn(diverSettings, diverSettings.safetyReviewEnabled);
    }
    if (!names.contains('safety_review_disabled_rules')) {
      await m.addColumn(
        diverSettings,
        diverSettings.safetyReviewDisabledRules,
      );
    }
  }
```

(`Migrator.createTable` uses CREATE TABLE IF NOT EXISTS semantics in this codebase's helpers — verify against the existing `_assert*` methods and match exactly what they do; if they guard with a PRAGMA existence check first, do the same.)

In `onUpgrade`, after the `if (from < 112)` block (line ~5541):

```dart
        if (from < 116) {
          await _assertSafetyReviewSchema();
        }
        if (from < 116) await reportProgress();
```

In `beforeOpen` (line ~5547), alongside the other `_assert*` backstops:

```dart
          await _assertSafetyReviewSchema();
```

- [ ] **Step 7: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes without errors; `database.g.dart` gains `DiveSafetyReview`/`DiveSafetyFinding` row classes.

- [ ] **Step 8: Run the schema test**

Run: `flutter test test/core/database/safety_review_schema_test.dart`
Expected: PASS.

- [ ] **Step 9: Format and commit**

```bash
dart format .
git add lib/core/database/database.dart lib/core/database/database.g.dart test/core/database/safety_review_schema_test.dart
git commit -m "feat: add dive safety review tables and settings columns (schema v116)"
```

---

### Task 6: SafetyFindingsRepository + providers + invalidation hooks

**Files:**
- Create: `lib/features/dive_log/data/repositories/safety_findings_repository.dart`
- Create: `lib/features/dive_log/presentation/providers/safety_review_providers.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (in `saveEditedProfile`, line ~510)
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (in `importProfile`'s replace path, line ~813+)
- Test: `test/features/dive_log/data/repositories/safety_findings_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `SyncRepository` (`markRecordPending`, `logDeletion` — see `lib/core/data/repositories/sync_repository.dart:742`), `SafetyFinding`/`SafetyRuleId`/`SafetySeverity` (Task 1), generated tables (Task 5), `profileAnalysisProvider` (`FutureProvider.family<ProfileAnalysis?, String>`, `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart:748`), `settingsProvider` (`AppSettings`).
- Produces:
  - `class SafetyReview { final String diveId; final int engineVersion; final DateTime reviewedAt; final List<SafetyFinding> findings; }` (declared in `safety_finding.dart`).
  - `class SafetyFindingsRepository` with:
    - `Future<SafetyReview?> getReview(String diveId)` — null when never analyzed.
    - `Future<void> saveReview(SafetyReview review)` — transactional replace (delete old findings with per-row `logDeletion`, upsert marker, insert findings, `markRecordPending` for each new row and the marker).
    - `Future<void> setDismissed({required String findingId, required bool dismissed, required DateTime now})`.
    - `static Future<void> clearReviewForDive(AppDatabase db, SyncRepository sync, String diveId)` — the invalidation helper both dive repositories call.
  - Providers in `safety_review_providers.dart`:
    - `final safetyFindingsRepositoryProvider = Provider<SafetyFindingsRepository>(...)`
    - `final safetyReviewProvider = FutureProvider.family<SafetyReview?, String>(...)` — compute-through-cache.

- [ ] **Step 1: Check existing repository test setup**

Run: `grep -rln "SyncRepository" test/features/dive_log/data/repositories/ | head -3` and read one hit to learn how tests construct `AppDatabase` + `SyncRepository` (real vs fake). Mirror that setup. If no precedent exists in that directory, search `test/` more broadly for `markRecordPending` fakes.

- [ ] **Step 2: Write the failing repository tests**

Create `test/features/dive_log/data/repositories/safety_findings_repository_test.dart` (adapt the DB/sync construction to what Step 1 found; the assertions below are the contract):

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SafetyFindingsRepository repo;
  final now = DateTime.utc(2026, 7, 16);

  SafetyFinding finding(String id, {SafetyRuleId rule = SafetyRuleId.rapidAscent}) =>
      SafetyFinding(
        id: id,
        diveId: 'dive-1',
        ruleId: rule,
        severity: SafetySeverity.caution,
        startTimestamp: 100,
        endTimestamp: 140,
        value: 14.2,
        engineVersion: 1,
        createdAt: now,
      );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Insert the parent dive row 'dive-1' the FK requires — copy the minimal
    // DivesCompanion insert used by existing repository tests.
    // Construct repo with the SyncRepository (or fake) from Step 1.
  });

  tearDown(() => db.close());

  test('getReview returns null for a never-analyzed dive', () async {
    expect(await repo.getReview('dive-1'), isNull);
  });

  test('saveReview then getReview round-trips findings', () async {
    await repo.saveReview(SafetyReview(
      diveId: 'dive-1',
      engineVersion: 1,
      reviewedAt: now,
      findings: [finding('f1'), finding('f2', rule: SafetyRuleId.sawtoothProfile)],
    ));
    final review = await repo.getReview('dive-1');
    expect(review, isNotNull);
    expect(review!.engineVersion, 1);
    expect(review.findings, hasLength(2));
    expect(review.findings.first.ruleId, SafetyRuleId.rapidAscent);
  });

  test('saveReview replaces prior findings', () async {
    await repo.saveReview(SafetyReview(
      diveId: 'dive-1', engineVersion: 1, reviewedAt: now,
      findings: [finding('f1')],
    ));
    await repo.saveReview(SafetyReview(
      diveId: 'dive-1', engineVersion: 2, reviewedAt: now,
      findings: [finding('f3')],
    ));
    final review = await repo.getReview('dive-1');
    expect(review!.engineVersion, 2);
    expect(review.findings.map((f) => f.id), ['f3']);
  });

  test('a zero-findings review still marks the dive analyzed', () async {
    await repo.saveReview(SafetyReview(
      diveId: 'dive-1', engineVersion: 1, reviewedAt: now, findings: const [],
    ));
    final review = await repo.getReview('dive-1');
    expect(review, isNotNull);
    expect(review!.findings, isEmpty);
  });

  test('setDismissed toggles dismissedAt', () async {
    await repo.saveReview(SafetyReview(
      diveId: 'dive-1', engineVersion: 1, reviewedAt: now,
      findings: [finding('f1')],
    ));
    await repo.setDismissed(findingId: 'f1', dismissed: true, now: now);
    var review = await repo.getReview('dive-1');
    expect(review!.findings.single.isDismissed, isTrue);
    await repo.setDismissed(findingId: 'f1', dismissed: false, now: now);
    review = await repo.getReview('dive-1');
    expect(review!.findings.single.isDismissed, isFalse);
  });

  test('clearReviewForDive removes marker and findings', () async {
    await repo.saveReview(SafetyReview(
      diveId: 'dive-1', engineVersion: 1, reviewedAt: now,
      findings: [finding('f1')],
    ));
    await SafetyFindingsRepository.clearReviewForDive(db, /* sync */, 'dive-1');
    expect(await repo.getReview('dive-1'), isNull);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/data/repositories/safety_findings_repository_test.dart`
Expected: FAIL (repository does not exist).

- [ ] **Step 4: Add SafetyReview to the entity file and implement the repository**

Append to `lib/features/dive_log/domain/entities/safety_finding.dart`:

```dart
/// A dive's stored safety review: the engine version it was produced with
/// plus all findings (including dismissed ones).
class SafetyReview extends Equatable {
  final String diveId;
  final int engineVersion;
  final DateTime reviewedAt;
  final List<SafetyFinding> findings;

  const SafetyReview({
    required this.diveId,
    required this.engineVersion,
    required this.reviewedAt,
    required this.findings,
  });

  List<SafetyFinding> get activeFindings =>
      findings.where((f) => !f.isDismissed).toList();

  @override
  List<Object?> get props => [diveId, engineVersion, reviewedAt, findings];
}
```

Create `lib/features/dive_log/data/repositories/safety_findings_repository.dart`. Follow the write conventions in `dive_computer_repository_impl.dart:1368` (`addProfileEvent`): insert companion → `markRecordPending` → `SyncEventBus.notifyLocalChange()`; and `clearEventsForDive` (line 1423) for the delete-with-tombstones pattern:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';

/// Persistence for post-dive safety reviews.
///
/// dive_safety_reviews is the "analyzed" marker (one row per analyzed dive);
/// dive_safety_findings holds the observations. Both are write-once children
/// of dives (no HLC columns): sync integrity comes from markRecordPending on
/// writes and per-row logDeletion on deletes, mirroring DiveProfileEvents.
class SafetyFindingsRepository {
  final AppDatabase _db;
  final SyncRepository _syncRepository;

  SafetyFindingsRepository({
    required AppDatabase db,
    required SyncRepository syncRepository,
  }) : _db = db,
       _syncRepository = syncRepository;

  Future<SafetyReview?> getReview(String diveId) async {
    final marker = await (_db.select(
      _db.diveSafetyReviews,
    )..where((t) => t.diveId.equals(diveId))).getSingleOrNull();
    if (marker == null) return null;
    final rows =
        await (_db.select(_db.diveSafetyFindings)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm.asc(t.startTimestamp)]))
            .get();
    return SafetyReview(
      diveId: diveId,
      engineVersion: marker.engineVersion,
      reviewedAt: DateTime.fromMillisecondsSinceEpoch(marker.reviewedAt),
      findings: [for (final row in rows) _toDomain(row)],
    );
  }

  Future<void> saveReview(SafetyReview review) async {
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.diveSafetyFindings,
      )..where((t) => t.diveId.equals(review.diveId))).get();
      await (_db.delete(
        _db.diveSafetyFindings,
      )..where((t) => t.diveId.equals(review.diveId))).go();
      for (final row in existing) {
        await _syncRepository.logDeletion(
          entityType: 'diveSafetyFindings',
          recordId: row.id,
        );
      }
      await _db
          .into(_db.diveSafetyReviews)
          .insertOnConflictUpdate(
            DiveSafetyReviewsCompanion.insert(
              diveId: review.diveId,
              engineVersion: review.engineVersion,
              reviewedAt: review.reviewedAt.millisecondsSinceEpoch,
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'diveSafetyReviews',
        recordId: review.diveId,
        localUpdatedAt: review.reviewedAt.millisecondsSinceEpoch,
      );
      for (final finding in review.findings) {
        await _db
            .into(_db.diveSafetyFindings)
            .insert(
              DiveSafetyFindingsCompanion.insert(
                id: finding.id,
                diveId: finding.diveId,
                ruleId: finding.ruleId.dbValue,
                severity: finding.severity.dbValue,
                startTimestamp: Value(finding.startTimestamp),
                endTimestamp: Value(finding.endTimestamp),
                value: Value(finding.value),
                engineVersion: finding.engineVersion,
                dismissedAt: Value(
                  finding.dismissedAt?.millisecondsSinceEpoch,
                ),
                createdAt: finding.createdAt.millisecondsSinceEpoch,
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: 'diveSafetyFindings',
          recordId: finding.id,
          localUpdatedAt: finding.createdAt.millisecondsSinceEpoch,
        );
      }
    });
    SyncEventBus.notifyLocalChange();
  }

  Future<void> setDismissed({
    required String findingId,
    required bool dismissed,
    required DateTime now,
  }) async {
    await (_db.update(
      _db.diveSafetyFindings,
    )..where((t) => t.id.equals(findingId))).write(
      DiveSafetyFindingsCompanion(
        dismissedAt: Value(dismissed ? now.millisecondsSinceEpoch : null),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'diveSafetyFindings',
      recordId: findingId,
      localUpdatedAt: now.millisecondsSinceEpoch,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Invalidation hook for profile writes: drops the review so the next view
  /// recomputes against the new profile. Static so both dive repositories
  /// can call it without holding a SafetyFindingsRepository.
  static Future<void> clearReviewForDive(
    AppDatabase db,
    SyncRepository sync,
    String diveId,
  ) async {
    final existing = await (db.select(
      db.diveSafetyFindings,
    )..where((t) => t.diveId.equals(diveId))).get();
    if (existing.isEmpty) {
      final marker = await (db.select(
        db.diveSafetyReviews,
      )..where((t) => t.diveId.equals(diveId))).getSingleOrNull();
      if (marker == null) return;
    }
    await (db.delete(
      db.diveSafetyFindings,
    )..where((t) => t.diveId.equals(diveId))).go();
    for (final row in existing) {
      await sync.logDeletion(
        entityType: 'diveSafetyFindings',
        recordId: row.id,
      );
    }
    final deletedMarker = await (db.delete(
      db.diveSafetyReviews,
    )..where((t) => t.diveId.equals(diveId))).go();
    if (deletedMarker > 0) {
      await sync.logDeletion(
        entityType: 'diveSafetyReviews',
        recordId: diveId,
      );
    }
  }

  SafetyFinding _toDomain(DiveSafetyFinding row) {
    return SafetyFinding(
      id: row.id,
      diveId: row.diveId,
      ruleId: SafetyRuleId.fromDbValue(row.ruleId) ?? SafetyRuleId.rapidAscent,
      severity: SafetySeverity.fromDbValue(row.severity),
      startTimestamp: row.startTimestamp,
      endTimestamp: row.endTimestamp,
      value: row.value,
      engineVersion: row.engineVersion,
      dismissedAt: row.dismissedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.dismissedAt!),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    );
  }
}
```

Adjust `markRecordPending` parameter names to the actual signature at `sync_repository.dart:742` (read it first). Note: unknown `ruleId` values from a future engine version fall back to `rapidAscent` — if reviewers prefer, drop such rows instead; keep whichever the existing enum-from-db convention in this codebase does (check `SafetyRuleId`-like `fromDbValue` usages, e.g. how `ProfileEventType` handles unknown strings in `profile_event_mapper.dart`).

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/data/repositories/safety_findings_repository_test.dart`
Expected: PASS.

- [ ] **Step 6: Create the providers**

Create `lib/features/dive_log/presentation/providers/safety_review_providers.dart`. First check how `diveRepositoryProvider` obtains `AppDatabase`/`SyncRepository` (`lib/features/dive_log/presentation/providers/dive_repository_provider.dart:12` and the providers it reads) and mirror it:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/services/safety_review_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

final safetyFindingsRepositoryProvider = Provider<SafetyFindingsRepository>((
  ref,
) {
  // Mirror dive_repository_provider.dart: read the same database and sync
  // repository providers it uses.
  return SafetyFindingsRepository(
    db: ref.watch(databaseProvider),
    syncRepository: ref.watch(syncRepositoryProvider),
  );
});

/// Compute-through-cache: returns the stored review when it is current,
/// otherwise runs the engine over the profile analysis and persists the
/// result. Returns null when the dive has no profile or the review feature
/// is disabled and nothing is stored.
final safetyReviewProvider = FutureProvider.family<SafetyReview?, String>((
  ref,
  diveId,
) async {
  final settings = ref.watch(settingsProvider);
  final repo = ref.watch(safetyFindingsRepositoryProvider);

  final stored = await repo.getReview(diveId);
  if (stored != null &&
      stored.engineVersion >= SafetyReviewService.engineVersion) {
    return stored;
  }
  if (!settings.safetyReviewEnabled) return stored;

  final analysis = await ref.watch(profileAnalysisProvider(diveId).future);
  if (analysis == null || analysis.ascentRates.isEmpty) return stored;

  final review = SafetyReview(
    diveId: diveId,
    engineVersion: SafetyReviewService.engineVersion,
    reviewedAt: DateTime.now(),
    findings: const SafetyReviewService().review(
      diveId: diveId,
      analysis: analysis,
      now: DateTime.now(),
    ),
  );
  await repo.saveReview(review);
  return review;
});
```

(`databaseProvider`/`syncRepositoryProvider` are placeholders for whatever names Step 6's inspection finds — use the real ones.)

- [ ] **Step 7: Wire the invalidation hooks**

In `lib/features/dive_log/data/repositories/dive_repository_impl.dart`, inside `saveEditedProfile` (line ~510), after the profile rows are replaced and before the method returns, add (matching the local field names for db and sync repository in that class):

```dart
    // Profile changed: drop the stored safety review so it recomputes.
    await SafetyFindingsRepository.clearReviewForDive(_db, _syncRepository, diveId);
```

In `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart`, inside `importProfile` (line ~813): find where the replace path deletes/rewrites existing profile rows for an existing dive (near where `clearEventsForDive` is invoked) and add the same call with that dive's id. Add the import for `safety_findings_repository.dart` in both files.

- [ ] **Step 8: Analyze and re-run tests**

Run: `flutter analyze lib/features/dive_log test/features/dive_log`
Expected: no new issues.
Run: `flutter test test/features/dive_log/data/repositories/safety_findings_repository_test.dart test/features/dive_log/domain/services/safety_review_service_test.dart`
Expected: PASS.

- [ ] **Step 9: Format and commit**

```bash
dart format .
git add lib/features/dive_log test/features/dive_log
git commit -m "feat: add safety findings repository, providers, and profile-write invalidation"
```

---

### Task 7: Sync serializer registration

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart`
- Test: whatever test covers `debugBaseTableKeys` / serializer round-trips — find with `grep -rln "debugBaseTableKeys\|_baseTables" test/ | head -3` and extend it if it enumerates entities.

**Interfaces:**
- Consumes: generated `diveSafetyReviews` / `diveSafetyFindings` tables.
- Produces: sync entity type strings `'diveSafetyReviews'` and `'diveSafetyFindings'` (must match the strings used in Task 6's `markRecordPending`/`logDeletion` calls exactly).

- [ ] **Step 1: Register in `_baseTables`**

In `sync_data_serializer.dart` find the `diveProfileEvents` entry in `_baseTables` (line ~709) and add, immediately after it, entries following the exact same record shape:

```dart
      (key: 'diveSafetyReviews', table: _db.diveSafetyReviews, blob: false, full: null),
      (key: 'diveSafetyFindings', table: _db.diveSafetyFindings, blob: false, full: null),
```

(Match the actual record fields of neighboring entries — if they carry more/different named fields, mirror the `diveProfileEvents` entry verbatim with only key/table changed.)

- [ ] **Step 2: Add DTO fields**

Mirror `diveProfileEvents` in the `SyncData`/`SyncPayload` DTO (fields at line ~261, `toJson` ~376, `fromJson` `_parseList` ~435, `_safeExport` ~1120). IMPORTANT: `debugBaseTableKeys` asserts `_baseTables` order equals `toJson` key order — insert the two new keys in the same relative position in every list.

- [ ] **Step 3: Add apply-switch cases**

In the `switch (entityType)` beginning at line ~1267, add `case 'diveSafetyReviews':` and `case 'diveSafetyFindings':` following the `case 'diveProfileEvents':` pattern (upsert into the table; delete by primary key for deletions — note `diveSafetyReviews`'s PK is `diveId`).

- [ ] **Step 4: Run the serializer/sync tests**

Run: `grep -rln "SyncDataSerializer" test/ | head -5`, then run those test files, e.g.:
`flutter test test/core/services/sync/`
Expected: PASS — the `debugBaseTableKeys` guard passing proves ordering is consistent. If a test enumerates all entity types explicitly, add the two new ones.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/core/services/sync/ test/
git commit -m "feat: register safety review tables in sync serializer"
```

---

### Task 8: Settings wiring (AppSettings + notifier)

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`
- Modify: the settings repository that maps `AppSettings` ↔ `DiverSettings` row (find with `grep -rn "updateSettingsForDiver" lib/features/settings/ | head -3` and update its read/write mapping)
- Test: `test/features/settings/presentation/providers/settings_notifier_real_test.dart` (extend)

**Interfaces:**
- Consumes: `DiverSettings.safetyReviewEnabled` / `safetyReviewDisabledRules` columns (Task 5), `SafetyRuleId` (Task 1).
- Produces (Tasks 9–11 rely on these):
  - `AppSettings.safetyReviewEnabled` (`bool`, default `true`)
  - `AppSettings.safetyReviewDisabledRules` (`Set<String>`, default empty — stores `SafetyRuleId.dbValue` strings)
  - `SettingsNotifier.setSafetyReviewEnabled(bool value)`
  - `SettingsNotifier.setSafetyRuleEnabled(SafetyRuleId rule, bool enabled)`
  - `final safetyReviewEnabledProvider = Provider<bool>(...)` (select on settingsProvider)

- [ ] **Step 1: Write the failing tests**

Open `test/features/settings/presentation/providers/settings_notifier_real_test.dart`, find an existing boolean-setting test (e.g. for `setShowCeilingOnProfile`), and add alongside it:

```dart
  test('setSafetyReviewEnabled persists', () async {
    final notifier = container.read(settingsProvider.notifier);
    expect(container.read(settingsProvider).safetyReviewEnabled, isTrue);
    await notifier.setSafetyReviewEnabled(false);
    expect(container.read(settingsProvider).safetyReviewEnabled, isFalse);
  });

  test('setSafetyRuleEnabled toggles the disabled-rules set', () async {
    final notifier = container.read(settingsProvider.notifier);
    expect(
      container.read(settingsProvider).safetyReviewDisabledRules,
      isEmpty,
    );
    await notifier.setSafetyRuleEnabled(SafetyRuleId.sawtoothProfile, false);
    expect(
      container.read(settingsProvider).safetyReviewDisabledRules,
      contains('sawtoothProfile'),
    );
    await notifier.setSafetyRuleEnabled(SafetyRuleId.sawtoothProfile, true);
    expect(
      container.read(settingsProvider).safetyReviewDisabledRules,
      isEmpty,
    );
  });
```

(Adapt the container/notifier acquisition to the file's existing setup; add the `safety_finding.dart` import.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/settings/presentation/providers/settings_notifier_real_test.dart`
Expected: FAIL (fields/methods missing).

- [ ] **Step 3: Implement**

In `settings_providers.dart`:
- Add to `AppSettings` (line ~81): `final bool safetyReviewEnabled;` and `final Set<String> safetyReviewDisabledRules;` with constructor defaults `true` / `const {}`, and thread both through `copyWith` (line ~450).
- Add to `SettingsNotifier` (line ~705), following the `setShowCeilingOnProfile` pattern (line ~990):

```dart
  Future<void> setSafetyReviewEnabled(bool value) async {
    state = state.copyWith(safetyReviewEnabled: value);
    await _saveSettings();
  }

  Future<void> setSafetyRuleEnabled(SafetyRuleId rule, bool enabled) async {
    final rules = {...state.safetyReviewDisabledRules};
    if (enabled) {
      rules.remove(rule.dbValue);
    } else {
      rules.add(rule.dbValue);
    }
    state = state.copyWith(safetyReviewDisabledRules: rules);
    await _saveSettings();
  }
```

- Add the selector provider near `gfLowDecimalProvider` (line ~1426):

```dart
final safetyReviewEnabledProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider.select((s) => s.safetyReviewEnabled)),
);
```

- In the settings repository mapping (found in this task's Files note): read `safetyReviewEnabled` straight from the row; decode `safetyReviewDisabledRules` with `jsonDecode` (`(jsonDecode(raw) as List).cast<String>().toSet()`, empty set when null); write back with `jsonEncode(sortedList)` (sort for deterministic storage), null when empty.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/settings/presentation/providers/settings_notifier_real_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/settings test/features/settings
git commit -m "feat: add safety review settings (master toggle and per-rule set)"
```

---

### Task 9: Dive detail "Safety review" section

**Files:**
- Modify: `lib/core/constants/dive_detail_sections.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_sectionBuilders`, line ~251)
- Create: `lib/features/dive_log/presentation/widgets/safety_review_section.dart`
- Modify: `lib/l10n/arb/app_en.arb` (en strings only in this task)
- Test: `test/features/dive_log/presentation/widgets/safety_review_section_test.dart`

**Interfaces:**
- Consumes: `safetyReviewProvider` (Task 6), `safetyFindingsRepositoryProvider.setDismissed`, `settingsProvider` fields (Task 8), `CollapsibleSection` (`lib/features/dive_log/presentation/widgets/collapsible_section.dart:9` — `title`, `icon`, `trailing`, `isExpanded`, `onToggle`, `child`), `UnitFormatter`.
- Produces: `DiveDetailSectionId.safetyReview` enum value; `class SafetyReviewSection extends ConsumerWidget` with constructor `SafetyReviewSection({required String diveId, super.key})`.

- [ ] **Step 1: Add the enum value + l10n keys**

In `dive_detail_sections.dart` add `safetyReview,` to `DiveDetailSectionId` immediately after `decoO2` (declaration order = default display order; `ensureAllSections` at line 207 auto-appends it for existing users). Extend the four getters (`displayName`, `description`, `localizedDisplayName`, `localizedDescription`) following the existing switch style; the localized ones reference `l10n.diveDetailSection_safetyReview_name` / `_description`.

Add to `lib/l10n/arb/app_en.arb` (near the other `diveDetailSection_` keys):

```json
  "diveDetailSection_safetyReview_name": "Safety review",
  "diveDetailSection_safetyReview_description": "Automatic post-dive profile observations",
  "safetyReview_sectionTitle": "Safety review",
  "safetyReview_findingCount": "{count, plural, =1{1 observation} other{{count} observations}}",
  "@safetyReview_findingCount": {"placeholders": {"count": {"type": "int"}}},
  "safetyReview_rapidAscent_title": "Ascent exceeded {rate} for {duration}",
  "@safetyReview_rapidAscent_title": {"placeholders": {"rate": {"type": "String"}, "duration": {"type": "String"}}},
  "safetyReview_missedDecoStop_title": "Depth was {excess} above the required stop ceiling for {duration}",
  "@safetyReview_missedDecoStop_title": {"placeholders": {"excess": {"type": "String"}, "duration": {"type": "String"}}},
  "safetyReview_omittedSafetyStop_title": "The recommended safety stop was cut short by {remaining}",
  "@safetyReview_omittedSafetyStop_title": {"placeholders": {"remaining": {"type": "String"}}},
  "safetyReview_sawtoothProfile_title": "{count} repeated up-and-down depth changes during the dive",
  "@safetyReview_sawtoothProfile_title": {"placeholders": {"count": {"type": "int"}}},
  "safetyReview_highSurfaceGf_title": "Surfaced at gradient factor {gf}, above the configured {gfHigh}",
  "@safetyReview_highSurfaceGf_title": {"placeholders": {"gf": {"type": "String"}, "gfHigh": {"type": "String"}}},
  "safetyReview_timeRange": "At {start}–{end}",
  "@safetyReview_timeRange": {"placeholders": {"start": {"type": "String"}, "end": {"type": "String"}}},
  "safetyReview_dismiss": "Dismiss",
  "safetyReview_restore": "Restore",
  "safetyReview_showDismissed": "{count, plural, =1{Show 1 dismissed} other{Show {count} dismissed}}",
  "@safetyReview_showDismissed": {"placeholders": {"count": {"type": "int"}}},
```

Then run `flutter gen-l10n` (or the project's codegen if l10n is generated via build) — check how existing arb changes regenerate: `grep -rn "gen-l10n\|l10n.yaml" . --include="*.yaml" -l | head -3`.

- [ ] **Step 2: Write the failing widget test**

Look at an existing widget test for a detail-section widget for the harness pattern (`grep -rln "CollapsibleSection" test/ | head -3`; remember the FormSection gotchas memory: labels may be uppercased, `ensureVisible` before taps, `themeAnimationDuration: Duration.zero`). Create `test/features/dive_log/presentation/widgets/safety_review_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_review_section.dart';

void main() {
  final now = DateTime.utc(2026, 7, 16);

  SafetyReview reviewWith(List<SafetyFinding> findings) => SafetyReview(
    diveId: 'dive-1',
    engineVersion: 1,
    reviewedAt: now,
    findings: findings,
  );

  SafetyFinding rapidAscent() => SafetyFinding(
    id: 'f1',
    diveId: 'dive-1',
    ruleId: SafetyRuleId.rapidAscent,
    severity: SafetySeverity.significant,
    startTimestamp: 1500,
    endTimestamp: 1540,
    value: 14.2,
    engineVersion: 1,
    createdAt: now,
  );

  Future<void> pump(WidgetTester tester, SafetyReview review) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          safetyReviewProvider('dive-1').overrideWith((ref) async => review),
        ],
        child: const MaterialApp(
          // add localizationsDelegates/supportedLocales per existing tests
          home: Scaffold(body: SafetyReviewSection(diveId: 'dive-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders a rapid ascent finding', (tester) async {
    await pump(tester, reviewWith([rapidAscent()]));
    expect(find.textContaining('Ascent exceeded'), findsOneWidget);
  });

  testWidgets('renders nothing when there are no active findings', (
    tester,
  ) async {
    await pump(tester, reviewWith(const []));
    expect(find.textContaining('Safety review'), findsNothing);
  });
}
```

(Fill in the localization delegates exactly as sibling widget tests do.)

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/safety_review_section_test.dart`
Expected: FAIL (widget missing).

- [ ] **Step 4: Implement the widget**

Create `lib/features/dive_log/presentation/widgets/safety_review_section.dart`. Requirements (tone rules from the spec):
- Watches `safetyReviewProvider(diveId)`; renders `SizedBox.shrink()` while loading, on error, when the review is null, when `settings.safetyReviewEnabled` is false, or when there are no findings to show.
- Filters out findings whose `ruleId.dbValue` is in `settings.safetyReviewDisabledRules`.
- Active findings render as `ListTile`s inside a `CollapsibleSection(title: l10n.safetyReview_sectionTitle, icon: Icons.health_and_safety_outlined, trailing: Text(l10n.safetyReview_findingCount(activeCount)), ...)` (expansion state via the same `CollapsibleSectionNotifier` pattern the other sections use — see `dive_detail_ui_providers.dart:58`).
- Per-finding leading icon by severity, all muted (no error red): `info` → `Icons.info_outline` with `Theme.of(context).colorScheme.onSurfaceVariant`; `caution` → `Icons.report_problem_outlined` with `onSurfaceVariant`; `significant` → same icon with `colorScheme.tertiary`.
- Title per rule from the l10n templates above. Depth/rate values formatted with `UnitFormatter` — find how the profile instrument bar formats ascent rates (`grep -n "m/min\|formatAscentRate\|formatSpeed" lib/core/utils/unit_formatter.dart lib/features/dive_log/presentation/widgets/profile_instrument_bar.dart | head`) and reuse that; durations as `Xm Ys` from `endTimestamp - startTimestamp`; time range via `safetyReview_timeRange` using MM:SS run times (`'$m:${s.toString().padLeft(2, '0')}'`).
- Trailing `IconButton(icon: Icon(Icons.close), tooltip: l10n.safetyReview_dismiss)` → `ref.read(safetyFindingsRepositoryProvider).setDismissed(findingId: f.id, dismissed: true, now: DateTime.now())` then `ref.invalidate(safetyReviewProvider(diveId))`.
- Dismissed findings hidden by default; when any exist, a `TextButton` labeled `l10n.safetyReview_showDismissed(n)` toggles a local expanded state showing them at reduced opacity with a restore button (same call with `dismissed: false`).

- [ ] **Step 5: Register the section builder**

In `dive_detail_page.dart` `_sectionBuilders` map, after the `decoO2` entry, add:

```dart
      DiveDetailSectionId.safetyReview: () {
        return [
          const SizedBox(height: 24),
          SafetyReviewSection(diveId: dive.id),
        ];
      },
```

(The widget itself collapses to nothing when there are no findings, so the builder is unconditional. If rendering an extra `SizedBox` spacer for an empty section causes visible double-spacing, move the spacer inside the widget so it only appears with content — check how other conditional sections handle this and match.)

- [ ] **Step 6: Run tests and analyze**

Run: `flutter test test/features/dive_log/presentation/widgets/safety_review_section_test.dart`
Expected: PASS.
Run: `flutter analyze lib/features/dive_log lib/core/constants`
Expected: no new issues.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add lib/core/constants lib/features/dive_log lib/l10n test/features/dive_log
git commit -m "feat: add safety review section to dive detail"
```

---

### Task 10: Dive list badge

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive_summary.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`getDiveSummaries` line ~1473, `_mapSummaryRows` line ~2093, `searchDiveSummaries` line ~1981)
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart` (`DiveListTile` line ~543 and `CompactDiveListTile`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_item.dart` (pass-through)
- Test: extend the existing `getDiveSummaries` test (find with `grep -rln "getDiveSummaries" test/ | head -3`)

**Interfaces:**
- Consumes: `dive_safety_findings` table, `DiveSummary` (fields listed in Task 10 Step 2), `safetyReviewEnabledProvider` (Task 8).
- Produces: `DiveSummary.safetyFindingCount` (`int`, default 0, count of non-dismissed findings).

- [ ] **Step 1: Write the failing repository test**

In the existing `getDiveSummaries` test file, add a case: insert a dive, insert two `dive_safety_findings` rows for it (one with `dismissed_at` set), call `getDiveSummaries`, and assert the summary's `safetyFindingCount == 1`. Follow the file's existing insert helpers. Also assert a dive with no findings reports 0.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test <that test file>`
Expected: FAIL (`safetyFindingCount` doesn't exist).

- [ ] **Step 3: Add the field to DiveSummary**

In `dive_summary.dart` add `final int safetyFindingCount;` with constructor default `this.safetyFindingCount = 0`, thread through `copyWith` and `props`, and set `safetyFindingCount: 0` in `DiveSummary.fromDive` (an optimistic update can't know the count; the next DB read corrects it).

- [ ] **Step 4: Extend the summary SQL**

In `getDiveSummaries` (line ~1473): the query is a hand-built SELECT over `dives d` with LEFT JOINs. Add to the join clauses:

```sql
LEFT JOIN (
  SELECT dive_id, COUNT(*) AS safety_finding_count
  FROM dive_safety_findings
  WHERE dismissed_at IS NULL
  GROUP BY dive_id
) sf ON sf.dive_id = d.id
```

and add `COALESCE(sf.safety_finding_count, 0) AS safety_finding_count` to the projection. In `_mapSummaryRows` (line ~2093) map it: `safetyFindingCount: row.read<int>('safety_finding_count'),`. Apply the same join/projection to `searchDiveSummaries` (line ~1981) so search results carry the badge too. Match the file's exact SQL string-building style.

- [ ] **Step 5: Render the badge**

In `dive_list_page.dart`: add `final int safetyFindingCount;` (constructor default 0) to both `DiveListTile` and `CompactDiveListTile`. Next to the favorite star rendering in `DiveListTile` (line ~790, `if (isFavorite) ...[ Icon(Icons.star, ...) ]`), add a small neutral dot — no red, no warning glyph:

```dart
                              if (safetyFindingCount > 0) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ],
```

Mirror in `CompactDiveListTile`'s equivalent trailing row. In `dive_list_item.dart`, pass `safetyFindingCount: summary.safetyFindingCount` to both tiles — but gate on the master toggle: read `ref.watch(safetyReviewEnabledProvider)` and pass `0` when disabled. Add a `Tooltip` around the dot with `context.l10n.safetyReview_findingCount(safetyFindingCount)` for discoverability.

- [ ] **Step 6: Run tests and analyze**

Run: `flutter test <the getDiveSummaries test file>`
Expected: PASS.
Run: `flutter analyze lib/features/dive_log`
Expected: no new issues.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add lib/features/dive_log test/
git commit -m "feat: add quiet safety findings badge to dive list"
```

---

### Task 11: Safety settings page + analyze-all action

**Files:**
- Create: `lib/features/settings/presentation/pages/safety_settings_page.dart`
- Modify: `lib/core/router/app_router.dart` (settings child routes, line ~884)
- Modify: `lib/features/settings/presentation/widgets/settings_list_content.dart` (add the entry)
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/settings/presentation/pages/safety_settings_page_test.dart`

**Interfaces:**
- Consumes: `settingsProvider` / `SettingsNotifier.setSafetyReviewEnabled` / `setSafetyRuleEnabled` (Task 8), `safetyReviewProvider` + `safetyFindingsRepositoryProvider` (Task 6), `SafetyRuleId` (Task 1), `diveRepositoryProvider` (for listing dive ids).
- Produces: route name `safetySettings` at path `safety` under the settings shell; `class SafetySettingsPage extends ConsumerStatefulWidget`.

- [ ] **Step 1: Add l10n keys (en)**

```json
  "safetySettings_title": "Safety review",
  "safetySettings_masterToggle": "Post-dive safety review",
  "safetySettings_masterToggle_subtitle": "Automatically note ascent, stop, and profile observations on analyzed dives",
  "safetySettings_rulesHeader": "Rules",
  "safetySettings_rule_rapidAscent": "Rapid ascents",
  "safetySettings_rule_missedDecoStop": "Missed or shortened deco stops",
  "safetySettings_rule_omittedSafetyStop": "Omitted safety stops",
  "safetySettings_rule_sawtoothProfile": "Sawtooth profiles",
  "safetySettings_rule_highSurfaceGf": "High surfacing gradient factor",
  "safetySettings_analyzeAll": "Analyze all dives",
  "safetySettings_analyzeAll_subtitle": "Run the safety review over every dive with a profile that has not been analyzed yet",
  "safetySettings_analyzeAll_progress": "Analyzed {done} of {total}",
  "@safetySettings_analyzeAll_progress": {"placeholders": {"done": {"type": "int"}, "total": {"type": "int"}}},
  "safetySettings_analyzeAll_done": "Analysis complete",
```

- [ ] **Step 2: Write the failing widget test**

Create `test/features/settings/presentation/pages/safety_settings_page_test.dart` following the harness of an existing settings-page widget test (find one: `ls test/features/settings/presentation/pages/`). Assert: the master `SwitchListTile` reflects `settings.safetyReviewEnabled`; toggling it calls through (state flips); the five rule switches render; rule switches are disabled (greyed) when the master toggle is off.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/pages/safety_settings_page_test.dart`
Expected: FAIL.

- [ ] **Step 4: Implement the page**

`SafetySettingsPage`: an `AppBar(title: Text(l10n.safetySettings_title))` + `ListView` with:
1. Master `SwitchListTile` (`value: settings.safetyReviewEnabled`, `onChanged: (v) => ref.read(settingsProvider.notifier).setSafetyReviewEnabled(v)`).
2. A `safetySettings_rulesHeader` section header, then one `SwitchListTile` per `SafetyRuleId.values` (`value: !settings.safetyReviewDisabledRules.contains(rule.dbValue)`, `onChanged: settings.safetyReviewEnabled ? (v) => notifier.setSafetyRuleEnabled(rule, v) : null`).
3. An `ListTile` for `safetySettings_analyzeAll` that runs the backfill: fetch all dive ids (check `DiveRepository` for an id-listing method — `grep -n "Future<List<String>> getAllDiveIds\|getDiveIds" lib/features/dive_log/domain/repositories/dive_repository.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart`; if none exists, add a simple `getAllDiveIds()` select to the repository as part of this task), then sequentially `await ref.read(safetyReviewProvider(id).future)` for each — the compute-through-cache provider skips already-analyzed dives cheaply (marker-row read, no replay). Show progress with a `LinearProgressIndicator` + `safetySettings_analyzeAll_progress` text updated via `setState`, and a `safetySettings_analyzeAll_done` SnackBar at the end. Guard reentrancy with a `_running` flag and check `mounted` after each await (Riverpod 3: never mutate providers in dispose).

- [ ] **Step 5: Register route + settings entry**

In `app_router.dart` after the `dive-detail-sections` GoRoute (line ~884):

```dart
              GoRoute(
                path: 'safety',
                name: 'safetySettings',
                builder: (context, state) => const SafetySettingsPage(),
              ),
```

In `settings_list_content.dart`, add a tile following its existing pattern (icon `Icons.health_and_safety_outlined`, title `l10n.safetySettings_title`, navigating via the route name), placed near the dive-display-related entries.

- [ ] **Step 6: Run tests and analyze**

Run: `flutter test test/features/settings/presentation/pages/safety_settings_page_test.dart`
Expected: PASS.
Run: `flutter analyze lib/features/settings lib/core/router`
Expected: no new issues.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add lib/features/settings lib/core/router lib/l10n test/features/settings
git commit -m "feat: add safety review settings page with analyze-all action"
```

---

### Task 12: Localization sweep + full verification

**Files:**
- Modify: all 10 non-English arb files in `lib/l10n/arb/` (`app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, plus the tenth — run `ls lib/l10n/arb/` to enumerate exactly)

**Interfaces:**
- Consumes: every `safetyReview_*`, `safetySettings_*`, `diveDetailSection_safetyReview_*` key added in Tasks 9 and 11.

- [ ] **Step 1: Translate all new keys into every non-English locale**

For each arb file, add translations of all new keys, preserving ICU plural/placeholder structure exactly. Keep the neutral, non-judgmental register in every language (state what happened; no scolding). Place keys adjacent to where `app_en.arb` has them.

- [ ] **Step 2: Regenerate localizations and analyze**

Run the l10n generation (same command as Task 9 Step 1), then:
Run: `flutter analyze`
Expected: no issues (missing-translation lints would surface here).

- [ ] **Step 3: Run the full feature test set**

Run:
```bash
flutter test test/features/dive_log/domain/services/safety_review_service_test.dart test/features/dive_log/data/repositories/safety_findings_repository_test.dart test/features/dive_log/presentation/widgets/safety_review_section_test.dart test/core/database/safety_review_schema_test.dart test/features/settings/presentation/providers/settings_notifier_real_test.dart test/features/settings/presentation/pages/safety_settings_page_test.dart
```
Expected: all PASS.

- [ ] **Step 4: Format and commit**

```bash
dart format .
git add lib/l10n
git commit -m "feat: translate safety review strings into all locales"
```

- [ ] **Step 5: Verification checklist before handoff**

- `dart format .` produces no changes.
- `flutter analyze` clean.
- Full `flutter test` will run on pre-push (do not push from the plan; the user decides when to push).
- Smoke test on macOS if requested: `flutter run -d macos`, open a dive with a profile, confirm the section renders and the badge appears after viewing (check the user's session isn't already running the app first — two `flutter run -d macos` instances kill each other).
