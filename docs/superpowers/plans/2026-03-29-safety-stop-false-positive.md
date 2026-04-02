# Safety Stop False Positive Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate false safety stop markers on shallow dives and improve detection robustness with three layered checks.

**Architecture:** Three independent layers added to `_detectSafetyStops()` in `ProfileAnalysisService`: a max-depth gate (skip dives < 10m), an ascent-phase restriction (only detect after max depth point), and consolidation (merge stops separated by brief gaps). The method signature gains one parameter (`maxDepthIndex`); the internal loop collects raw segments before emitting events.

**Tech Stack:** Dart, Flutter test framework

**Spec:** `docs/superpowers/specs/2026-03-29-safety-stop-false-positive-design.md`

---

### Task 1: Layer 1 - Max Depth Gate (Tests)

**Files:**
- Modify: `test/features/dive_log/data/services/profile_analysis_service_test.dart`

- [ ] **Step 1: Write failing tests for max depth gate**

Add a new test group at the end of the file, before the closing `});` of `main()`. These tests exercise safety stop detection through the public `analyze()` API. Helper function builds a simple dive profile.

```dart
import 'package:submersion/core/constants/enums.dart';

// Inside main(), add:

  group('Safety stop detection', () {
    late ProfileAnalysisService service;

    setUp(() {
      service = ProfileAnalysisService(gfLow: 1.0, gfHigh: 1.0);
    });

    /// Build a dive profile: descend to [maxDepth] over 2 min, hold for
    /// [bottomMinutes], ascend and pause at [stopDepth] for
    /// [stopMinutes], then surface over 1 min. 1-second sample interval.
    ({List<double> depths, List<int> timestamps}) buildDiveProfile({
      required double maxDepth,
      int bottomMinutes = 10,
      double stopDepth = 5.0,
      int stopMinutes = 3,
    }) {
      final depths = <double>[];
      final timestamps = <int>[];
      var t = 0;

      // Descent: 2 minutes to maxDepth
      for (var s = 0; s <= 120; s++) {
        timestamps.add(t);
        depths.add(maxDepth * s / 120.0);
        t++;
      }

      // Bottom time
      for (var s = 0; s < bottomMinutes * 60; s++) {
        timestamps.add(t);
        depths.add(maxDepth);
        t++;
      }

      // Ascent to stop depth: 1 minute
      for (var s = 0; s <= 60; s++) {
        timestamps.add(t);
        depths.add(maxDepth - (maxDepth - stopDepth) * s / 60.0);
        t++;
      }

      // Hold at stop depth
      for (var s = 0; s < stopMinutes * 60; s++) {
        timestamps.add(t);
        depths.add(stopDepth);
        t++;
      }

      // Surface: 1 minute
      for (var s = 0; s <= 60; s++) {
        timestamps.add(t);
        depths.add(stopDepth * (1 - s / 60.0));
        t++;
      }

      return (depths: depths, timestamps: timestamps);
    }

    List<ProfileEvent> safetyStopEvents(ProfileAnalysis result) {
      return result.events
          .where((e) =>
              e.eventType == ProfileEventType.safetyStopStart ||
              e.eventType == ProfileEventType.safetyStopEnd)
          .toList();
    }

    group('max depth gate', () {
      test('shallow dive at 5m produces no safety stop events', () {
        final profile = buildDiveProfile(maxDepth: 5.0, stopDepth: 4.0);
        final result = service.analyze(
          diveId: 'shallow',
          depths: profile.depths,
          timestamps: profile.timestamps,
        );
        expect(safetyStopEvents(result), isEmpty);
      });

      test('dive at exactly 10m with stop produces safety stop events', () {
        final profile = buildDiveProfile(maxDepth: 10.0);
        final result = service.analyze(
          diveId: 'threshold',
          depths: profile.depths,
          timestamps: profile.timestamps,
        );
        expect(safetyStopEvents(result), isNotEmpty);
      });

      test('dive at 9.9m produces no safety stop events', () {
        final profile = buildDiveProfile(maxDepth: 9.9);
        final result = service.analyze(
          diveId: 'below-threshold',
          depths: profile.depths,
          timestamps: profile.timestamps,
        );
        expect(safetyStopEvents(result), isEmpty);
      });
    });
  });
```

Note: You will also need to add the `ProfileEvent` import if not already present:

```dart
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion && flutter test test/features/dive_log/data/services/profile_analysis_service_test.dart -v`

Expected: The "shallow dive at 5m" and "dive at 9.9m" tests FAIL (safety stop events are found where none should be). The "dive at exactly 10m" test should PASS.

---

### Task 2: Layer 1 - Max Depth Gate (Implementation)

**Files:**
- Modify: `lib/features/dive_log/data/services/profile_analysis_service.dart:804` (call site)
- Modify: `lib/features/dive_log/data/services/profile_analysis_service.dart:865-920` (`_detectSafetyStops`)

- [ ] **Step 1: Add max depth gate and maxDepthIndex parameter**

In `_detectSafetyStops`, add the `maxDepthIndex` parameter (needed for Task 3) and the max depth gate. Replace lines 865-920 with:

```dart
  /// Detect safety stops in the profile.
  ///
  /// Only detects stops on dives deeper than [_minDiveDepthForSafetyStop]
  /// and only during the ascent phase (after [maxDepthIndex]).
  void _detectSafetyStops(
    String diveId,
    List<double> depths,
    List<int> timestamps,
    int maxDepthIndex,
    List<ProfileEvent> events,
    DateTime now,
  ) {
    const minDiveDepth = 10.0;
    const minStopDepth = 3.0;
    const maxStopDepth = 6.0;
    const minStopDuration = 120; // 2 minutes

    // Layer 1: Skip shallow dives
    final maxDepth = depths.reduce((a, b) => a > b ? a : b);
    if (maxDepth < minDiveDepth) return;

    int? stopStartIndex;
    int? stopStartTimestamp;

    for (int i = 0; i < depths.length; i++) {
      final depth = depths[i];
      final timestamp = timestamps[i];

      if (depth >= minStopDepth && depth <= maxStopDepth) {
        if (stopStartIndex == null) {
          stopStartIndex = i;
          stopStartTimestamp = timestamp;
        }
      } else {
        if (stopStartIndex != null && stopStartTimestamp != null) {
          final duration = timestamps[i - 1] - stopStartTimestamp;
          if (duration >= minStopDuration) {
            events.add(
              ProfileEvent.safetyStop(
                id: _uuid.v4(),
                diveId: diveId,
                timestamp: stopStartTimestamp,
                depth: depths[stopStartIndex],
                createdAt: now,
                isStart: true,
              ),
            );
            events.add(
              ProfileEvent.safetyStop(
                id: _uuid.v4(),
                diveId: diveId,
                timestamp: timestamps[i - 1],
                depth: depths[i - 1],
                createdAt: now,
                isStart: false,
              ),
            );
          }
          stopStartIndex = null;
          stopStartTimestamp = null;
        }
      }
    }
  }
```

- [ ] **Step 2: Update call site to pass maxDepthIndex**

At line 804 in `_detectEvents`, replace:

```dart
    _detectSafetyStops(diveId, depths, timestamps, events, now);
```

with:

```dart
    final maxDepthIndex = depths.indexOf(maxDepth);
    _detectSafetyStops(diveId, depths, timestamps, maxDepthIndex, events, now);
```

- [ ] **Step 3: Run tests to verify they pass**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion && flutter test test/features/dive_log/data/services/profile_analysis_service_test.dart -v`

Expected: All three max depth gate tests PASS.

- [ ] **Step 4: Run full test suite**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion && flutter test`

Expected: All tests pass. No regressions.

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
dart format lib/features/dive_log/data/services/profile_analysis_service.dart test/features/dive_log/data/services/profile_analysis_service_test.dart
git add lib/features/dive_log/data/services/profile_analysis_service.dart test/features/dive_log/data/services/profile_analysis_service_test.dart
git commit -m "fix: skip safety stop detection on dives shallower than 10m

Adds a max depth gate to _detectSafetyStops() so that dives with
a maximum depth less than 10m produce no safety stop events.
This prevents false positives on shallow dives that hover at
safety stop depths (3-6m).

Fixes #112"
```

---

### Task 3: Layer 2 - Ascent-Phase Restriction (Tests)

**Files:**
- Modify: `test/features/dive_log/data/services/profile_analysis_service_test.dart`

- [ ] **Step 1: Write failing tests for ascent-phase restriction**

Add inside the `'Safety stop detection'` group, after the `'max depth gate'` group:

```dart
    group('ascent-phase restriction', () {
      test('stop during descent is not detected', () {
        // Dive that descends through 3-6m slowly (>2min), then goes to 20m
        final depths = <double>[];
        final timestamps = <int>[];
        var t = 0;

        // Slow descent through safety stop zone: 3 minutes at 4-5m
        for (var s = 0; s <= 180; s++) {
          timestamps.add(t);
          depths.add(3.0 + 2.0 * s / 180.0); // 3m -> 5m over 3 min
          t++;
        }

        // Continue descent to 20m over 1 minute
        for (var s = 1; s <= 60; s++) {
          timestamps.add(t);
          depths.add(5.0 + 15.0 * s / 60.0);
          t++;
        }

        // Bottom at 20m for 10 minutes
        for (var s = 0; s < 600; s++) {
          timestamps.add(t);
          depths.add(20.0);
          t++;
        }

        // Fast ascent to surface (no safety stop), 2 minutes
        for (var s = 0; s <= 120; s++) {
          timestamps.add(t);
          depths.add(20.0 * (1 - s / 120.0));
          t++;
        }

        final result = service.analyze(
          diveId: 'descent-stop',
          depths: depths,
          timestamps: timestamps,
        );
        expect(safetyStopEvents(result), isEmpty);
      });

      test('stop during bottom phase is not detected', () {
        final depths = <double>[];
        final timestamps = <int>[];
        var t = 0;

        // Quick descent to 20m
        for (var s = 0; s <= 60; s++) {
          timestamps.add(t);
          depths.add(20.0 * s / 60.0);
          t++;
        }

        // Bottom at 20m for 5 minutes
        for (var s = 0; s < 300; s++) {
          timestamps.add(t);
          depths.add(20.0);
          t++;
        }

        // Rise to 5m for 3 minutes (simulating bottom excursion, before max depth)
        for (var s = 0; s <= 30; s++) {
          timestamps.add(t);
          depths.add(20.0 - 15.0 * s / 30.0);
          t++;
        }
        for (var s = 0; s < 180; s++) {
          timestamps.add(t);
          depths.add(5.0);
          t++;
        }

        // Go back to 20m (this makes 20m the max depth point later)
        for (var s = 0; s <= 30; s++) {
          timestamps.add(t);
          depths.add(5.0 + 15.0 * s / 30.0);
          t++;
        }
        // Stay at 20m for 5 more minutes (max depth point is here)
        for (var s = 0; s < 300; s++) {
          timestamps.add(t);
          depths.add(20.0);
          t++;
        }

        // Ascent to surface without stop, 2 minutes
        for (var s = 0; s <= 120; s++) {
          timestamps.add(t);
          depths.add(20.0 * (1 - s / 120.0));
          t++;
        }

        final result = service.analyze(
          diveId: 'bottom-stop',
          depths: depths,
          timestamps: timestamps,
        );
        expect(safetyStopEvents(result), isEmpty);
      });

      test('stop during ascent is detected', () {
        final profile = buildDiveProfile(maxDepth: 20.0, stopDepth: 5.0);
        final result = service.analyze(
          diveId: 'ascent-stop',
          depths: profile.depths,
          timestamps: profile.timestamps,
        );
        final stops = safetyStopEvents(result);
        expect(stops.length, equals(2)); // start + end
        expect(stops[0].eventType, ProfileEventType.safetyStopStart);
        expect(stops[1].eventType, ProfileEventType.safetyStopEnd);
      });
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion && flutter test test/features/dive_log/data/services/profile_analysis_service_test.dart -v`

Expected: "stop during descent" and "stop during bottom phase" FAIL (safety stops detected where none should be). "stop during ascent" should PASS.

---

### Task 4: Layer 2 - Ascent-Phase Restriction (Implementation)

**Files:**
- Modify: `lib/features/dive_log/data/services/profile_analysis_service.dart:865-920` (`_detectSafetyStops`)

- [ ] **Step 1: Add ascent-phase restriction to detection loop**

In `_detectSafetyStops`, change the loop start from `i = 0` to `i = maxDepthIndex + 1`. Find:

```dart
    for (int i = 0; i < depths.length; i++) {
```

Replace with:

```dart
    // Layer 2: Only scan ascent phase (after max depth point)
    for (int i = maxDepthIndex + 1; i < depths.length; i++) {
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion && flutter test test/features/dive_log/data/services/profile_analysis_service_test.dart -v`

Expected: All ascent-phase restriction tests PASS. All max depth gate tests still PASS.

- [ ] **Step 3: Run full test suite**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion && flutter test`

Expected: All tests pass.

- [ ] **Step 4: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
dart format lib/features/dive_log/data/services/profile_analysis_service.dart test/features/dive_log/data/services/profile_analysis_service_test.dart
git add lib/features/dive_log/data/services/profile_analysis_service.dart test/features/dive_log/data/services/profile_analysis_service_test.dart
git commit -m "fix: restrict safety stop detection to ascent phase only

Safety stops only occur during ascent, so skip all profile points
at or before the max depth index. Prevents false positives from
slow descents or mid-dive excursions through the 3-6m band."
```

---

### Task 5: Layer 3 - Consolidation (Tests)

**Files:**
- Modify: `test/features/dive_log/data/services/profile_analysis_service_test.dart`

- [ ] **Step 1: Write failing tests for consolidation**

Add inside the `'Safety stop detection'` group, after the `'ascent-phase restriction'` group:

```dart
    group('consolidation', () {
      /// Build a dive that descends to 20m, then ascends through the safety
      /// stop zone with [gaps] — brief excursions outside the 3-6m band.
      /// Each gap is (gapDurationSeconds, depthDuringGap).
      /// Between gaps, the diver holds at 5m for [segmentMinutes] each.
      ({List<double> depths, List<int> timestamps}) buildDiveWithGaps({
        required List<({int durationSeconds, double depth})> gaps,
        int segmentMinutes = 2,
      }) {
        final depths = <double>[];
        final timestamps = <int>[];
        var t = 0;

        // Descent to 20m: 2 minutes
        for (var s = 0; s <= 120; s++) {
          timestamps.add(t);
          depths.add(20.0 * s / 120.0);
          t++;
        }

        // Bottom at 20m: 10 minutes
        for (var s = 0; s < 600; s++) {
          timestamps.add(t);
          depths.add(20.0);
          t++;
        }

        // Ascent to 5m: 1 minute
        for (var s = 0; s <= 60; s++) {
          timestamps.add(t);
          depths.add(20.0 - 15.0 * s / 60.0);
          t++;
        }

        // First safety stop segment
        for (var s = 0; s < segmentMinutes * 60; s++) {
          timestamps.add(t);
          depths.add(5.0);
          t++;
        }

        // Gaps with stop segments between them
        for (final gap in gaps) {
          // Brief excursion outside the band
          for (var s = 0; s < gap.durationSeconds; s++) {
            timestamps.add(t);
            depths.add(gap.depth);
            t++;
          }

          // Return to safety stop depth
          for (var s = 0; s < segmentMinutes * 60; s++) {
            timestamps.add(t);
            depths.add(5.0);
            t++;
          }
        }

        // Surface: 1 minute
        for (var s = 0; s <= 60; s++) {
          timestamps.add(t);
          depths.add(5.0 * (1 - s / 60.0));
          t++;
        }

        return (depths: depths, timestamps: timestamps);
      }

      test('two stops separated by 10s gap are merged into one', () {
        final profile = buildDiveWithGaps(
          gaps: [(durationSeconds: 10, depth: 7.0)],
        );
        final result = service.analyze(
          diveId: 'merge-short-gap',
          depths: profile.depths,
          timestamps: profile.timestamps,
        );
        final stops = safetyStopEvents(result);
        expect(stops.length, equals(2)); // one start + one end
        expect(stops[0].eventType, ProfileEventType.safetyStopStart);
        expect(stops[1].eventType, ProfileEventType.safetyStopEnd);
      });

      test('two stops separated by 31s gap remain separate', () {
        final profile = buildDiveWithGaps(
          gaps: [(durationSeconds: 31, depth: 7.0)],
        );
        final result = service.analyze(
          diveId: 'keep-long-gap',
          depths: profile.depths,
          timestamps: profile.timestamps,
        );
        final stops = safetyStopEvents(result);
        expect(stops.length, equals(4)); // two starts + two ends
      });

      test('three consecutive stops with short gaps merge into one', () {
        final profile = buildDiveWithGaps(
          gaps: [
            (durationSeconds: 10, depth: 7.0),
            (durationSeconds: 15, depth: 2.0),
          ],
        );
        final result = service.analyze(
          diveId: 'merge-three',
          depths: profile.depths,
          timestamps: profile.timestamps,
        );
        final stops = safetyStopEvents(result);
        expect(stops.length, equals(2)); // all merged into one
      });

      test('single stop with no neighbors is unchanged', () {
        final profile = buildDiveProfile(maxDepth: 20.0, stopDepth: 5.0);
        final result = service.analyze(
          diveId: 'single-stop',
          depths: profile.depths,
          timestamps: profile.timestamps,
        );
        final stops = safetyStopEvents(result);
        expect(stops.length, equals(2)); // one start + one end
      });
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion && flutter test test/features/dive_log/data/services/profile_analysis_service_test.dart -v`

Expected: "two stops separated by 10s gap" FAILS (produces 4 events instead of 2). "three consecutive stops" FAILS (produces 6 events instead of 2). The "31s gap" and "single stop" tests may already PASS.

---

### Task 6: Layer 3 - Consolidation (Implementation)

**Files:**
- Modify: `lib/features/dive_log/data/services/profile_analysis_service.dart:865-920` (`_detectSafetyStops`)

- [ ] **Step 1: Refactor to collect raw segments, then consolidate**

Replace the entire `_detectSafetyStops` method with the final version that includes all three layers:

```dart
  /// Detect safety stops in the profile.
  ///
  /// Three-layer detection:
  /// 1. Max depth gate: skip dives shallower than 10m
  /// 2. Ascent-phase restriction: only scan after max depth point
  /// 3. Consolidation: merge stops separated by gaps <= 30s
  void _detectSafetyStops(
    String diveId,
    List<double> depths,
    List<int> timestamps,
    int maxDepthIndex,
    List<ProfileEvent> events,
    DateTime now,
  ) {
    const minDiveDepth = 10.0;
    const minStopDepth = 3.0;
    const maxStopDepth = 6.0;
    const minStopDuration = 120; // 2 minutes
    const maxConsolidationGap = 30; // seconds

    // Layer 1: Skip shallow dives
    final maxDepth = depths.reduce((a, b) => a > b ? a : b);
    if (maxDepth < minDiveDepth) return;

    // Collect raw stop segments: (startIndex, startTimestamp, endIndex, endTimestamp)
    final rawStops = <({
      int startIndex,
      int startTimestamp,
      int endIndex,
      int endTimestamp,
    })>[];

    int? stopStartIndex;
    int? stopStartTimestamp;

    // Layer 2: Only scan ascent phase (after max depth point)
    for (int i = maxDepthIndex + 1; i < depths.length; i++) {
      final depth = depths[i];
      final timestamp = timestamps[i];

      if (depth >= minStopDepth && depth <= maxStopDepth) {
        if (stopStartIndex == null) {
          stopStartIndex = i;
          stopStartTimestamp = timestamp;
        }
      } else {
        if (stopStartIndex != null && stopStartTimestamp != null) {
          final duration = timestamps[i - 1] - stopStartTimestamp;
          if (duration >= minStopDuration) {
            rawStops.add((
              startIndex: stopStartIndex,
              startTimestamp: stopStartTimestamp,
              endIndex: i - 1,
              endTimestamp: timestamps[i - 1],
            ));
          }
          stopStartIndex = null;
          stopStartTimestamp = null;
        }
      }
    }

    // Handle stop that extends to end of profile
    if (stopStartIndex != null && stopStartTimestamp != null) {
      final duration = timestamps.last - stopStartTimestamp;
      if (duration >= minStopDuration) {
        rawStops.add((
          startIndex: stopStartIndex,
          startTimestamp: stopStartTimestamp,
          endIndex: depths.length - 1,
          endTimestamp: timestamps.last,
        ));
      }
    }

    if (rawStops.isEmpty) return;

    // Layer 3: Consolidate stops separated by short gaps
    final merged = <({
      int startIndex,
      int startTimestamp,
      int endIndex,
      int endTimestamp,
    })>[rawStops.first];

    for (int i = 1; i < rawStops.length; i++) {
      final prev = merged.last;
      final curr = rawStops[i];
      final gap = curr.startTimestamp - prev.endTimestamp;

      if (gap <= maxConsolidationGap) {
        // Merge: replace last with extended range
        merged[merged.length - 1] = (
          startIndex: prev.startIndex,
          startTimestamp: prev.startTimestamp,
          endIndex: curr.endIndex,
          endTimestamp: curr.endTimestamp,
        );
      } else {
        merged.add(curr);
      }
    }

    // Emit events from merged stops
    for (final stop in merged) {
      events.add(
        ProfileEvent.safetyStop(
          id: _uuid.v4(),
          diveId: diveId,
          timestamp: stop.startTimestamp,
          depth: depths[stop.startIndex],
          createdAt: now,
          isStart: true,
        ),
      );
      events.add(
        ProfileEvent.safetyStop(
          id: _uuid.v4(),
          diveId: diveId,
          timestamp: stop.endTimestamp,
          depth: depths[stop.endIndex],
          createdAt: now,
          isStart: false,
        ),
      );
    }
  }
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion && flutter test test/features/dive_log/data/services/profile_analysis_service_test.dart -v`

Expected: All consolidation tests PASS. All previous tests still PASS.

- [ ] **Step 3: Run full test suite**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion && flutter test`

Expected: All tests pass.

- [ ] **Step 4: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
dart format lib/features/dive_log/data/services/profile_analysis_service.dart test/features/dive_log/data/services/profile_analysis_service_test.dart
git add lib/features/dive_log/data/services/profile_analysis_service.dart test/features/dive_log/data/services/profile_analysis_service_test.dart
git commit -m "fix: consolidate adjacent safety stops separated by brief gaps

Refactors _detectSafetyStops to collect raw segments first, then
merge consecutive stops separated by gaps of 30 seconds or less.
This prevents fragmented markers when a diver briefly oscillates
outside the 3-6m band during a single continuous safety stop."
```

---

### Task 7: Integration Test

**Files:**
- Modify: `test/features/dive_log/data/services/profile_analysis_service_test.dart`

- [ ] **Step 1: Write integration test simulating the reported shallow dive**

Add inside the `'Safety stop detection'` group, after the `'consolidation'` group:

```dart
    group('integration', () {
      test('shallow dive hovering at safety stop depths produces no stops', () {
        // Simulate the reported issue: a Perdix AI dive that stays
        // entirely at 3-6m depth with brief oscillations above and below.
        final depths = <double>[];
        final timestamps = <int>[];
        var t = 0;

        // Descent to 5m: 30 seconds
        for (var s = 0; s <= 30; s++) {
          timestamps.add(t);
          depths.add(5.0 * s / 30.0);
          t++;
        }

        // Hover at 4-6m for 30 minutes with oscillation
        for (var s = 0; s < 30 * 60; s++) {
          timestamps.add(t);
          // Oscillate between 3.5m and 5.5m with occasional dips
          final base = 4.5;
          final oscillation = 1.0 *
              (s % 120 < 60 ? (s % 60) / 60.0 : 1.0 - (s % 60) / 60.0);
          depths.add(base + oscillation - 0.5);
          t++;
        }

        // Surface: 30 seconds
        for (var s = 0; s <= 30; s++) {
          timestamps.add(t);
          depths.add(5.0 * (1 - s / 30.0));
          t++;
        }

        final result = service.analyze(
          diveId: 'shallow-oscillating',
          depths: depths,
          timestamps: timestamps,
        );
        expect(
          safetyStopEvents(result),
          isEmpty,
          reason: 'Shallow dive at safety stop depths should not trigger '
              'safety stop detection (max depth gate: < 10m)',
        );
      });
    });
```

- [ ] **Step 2: Run the test to verify it passes**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion && flutter test test/features/dive_log/data/services/profile_analysis_service_test.dart -v`

Expected: PASS. The max depth gate (Layer 1) prevents any safety stop detection since the dive never exceeds ~5.5m.

- [ ] **Step 3: Run full test suite and format**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
flutter test
dart format test/features/dive_log/data/services/profile_analysis_service_test.dart
```

Expected: All tests pass, code formatted.

- [ ] **Step 4: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
git add test/features/dive_log/data/services/profile_analysis_service_test.dart
git commit -m "test: add integration test for shallow dive safety stop false positive

Simulates the reported issue #112: a dive hovering at 4-6m with
oscillations produces zero safety stop markers thanks to the
max depth gate."
```
