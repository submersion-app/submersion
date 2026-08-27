import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/services/safety_review_service.dart';

import 'safety_review_fixtures.dart';

/// Regression suite for the false positives reported against the post-dive
/// safety review: absurd ascent rates, "rapid ascent" during a descent,
/// zero-length findings, sawtooth firing on ordinary dives, and a missed
/// safety stop after a genuine shallow stop.
void main() {
  final now = DateTime.utc(2026, 8, 9);
  var idCounter = 0;
  String nextId() => 'finding-${idCounter++}';

  setUp(() => idCounter = 0);

  List<SafetyFinding> review(List<double> depths, List<int> timestamps) {
    return const SafetyReviewService().review(
      diveId: 'dive-1',
      analysis: analyzeFixture(depths: depths, timestamps: timestamps),
      now: now,
      idGenerator: nextId,
    );
  }

  List<SafetyFinding> rapidAscents(List<SafetyFinding> f) =>
      f.where((x) => x.ruleId == SafetyRuleId.rapidAscent).toList();

  group('corrupt depth samples', () {
    test('a single spiked sample during a descent flags no rapid ascent', () {
      // Steady 12 m/min descent at 2 s sampling, one sample reads 27 m deep.
      // A moving average spreads that one bad reading across the whole
      // smoothing window, which used to surface as a large "ascent" at depth.
      final timestamps = <int>[];
      final depths = <double>[];
      for (var i = 0; i < 120; i++) {
        timestamps.add(i * 2);
        depths.add(i * 2 * 0.2);
      }
      depths[60] += 27.0;

      expect(rapidAscents(review(depths, timestamps)), isEmpty);
    });

    test('two interleaved data sources flag no rapid ascent', () {
      // The analysis pipeline is fed every dive_profiles row for a dive, so a
      // dive downloaded from two computers arrives as both series interleaved
      // by timestamp. With the computers' clocks a little apart, the depth
      // jumps back and forth every sample.
      final merged = <({int t, double z})>[];
      double depthAt(int sec) => sec <= 0 ? 0 : (sec * 0.2).clamp(0, 30);
      for (var i = 0; i < 120; i++) {
        merged.add((t: i * 2, z: depthAt(i * 2))); // computer A
        merged.add((t: i * 2 + 1, z: depthAt(i * 2 + 40))); // B, 40 s ahead
      }
      merged.sort((a, b) => a.t.compareTo(b.t));

      final findings = review(
        [for (final m in merged) m.z],
        [for (final m in merged) m.t],
      );
      expect(rapidAscents(findings), isEmpty);
    });

    test('a genuine 18 m/min ascent is still flagged', () {
      // Guard against the outlier filter swallowing real rapid ascents.
      final profile = rapidAscentProfile();
      final findings = review(profile.depths, profile.timestamps);
      expect(rapidAscents(findings), isNotEmpty);
      expect(rapidAscents(findings).first.value, greaterThan(12));
    });
  });

  group('rapid ascent finding shape', () {
    test('a 2.9 m rise in confined water is not a rapid ascent', () {
      // Skills session at 3.5 m: up to 0.6 m at ~9.7 m/min, then back down.
      // The rate clears the 9 m/min threshold, but a 2.9 m excursion in a
      // pool is not a decompression event.
      final profile = buildFineProfile([
        (3.5, 60),
        (3.5, 120),
        (0.6, 18), // 2.9 m up in 18 s = 9.7 m/min
        (0.6, 20),
        (3.5, 40),
        (3.5, 120),
        (0, 40),
      ]);
      expect(rapidAscents(review(profile.depths, profile.timestamps)), isEmpty);
    });

    test('the reported span covers the whole ascent, not one sample', () {
      // The window a finding reports is what the diver reads as "for 30s".
      // It has to describe the excursion that earned the finding.
      final profile = rapidAscentProfile();
      final findings = rapidAscents(review(profile.depths, profile.timestamps));
      expect(findings, isNotEmpty);
      final f = findings.first;
      expect(
        f.endTimestamp! - f.startTimestamp!,
        greaterThanOrEqualTo(50),
        reason: 'the fixture ascends 18 m over 60 s',
      );
    });
  });

  group('sawtooth sensitivity', () {
    ({List<double> depths, List<int> timestamps}) teeth(
      int count,
      double amplitude,
    ) {
      final segments = <(double, int)>[(20, 120), (20, 300)];
      for (var i = 0; i < count; i++) {
        segments.add((20 - amplitude, 90));
        segments.add((20, 90));
        segments.add((20, 120));
      }
      segments.addAll([(5, 190), (5, 180), (0, 90)]);
      return buildProfile(segments);
    }

    List<SafetyFinding> sawtooths(
      ({List<double> depths, List<int> timestamps}) p,
    ) => review(
      p.depths,
      p.timestamps,
    ).where((f) => f.ruleId == SafetyRuleId.sawtoothProfile).toList();

    test('three 6 m excursions on an hour-long dive do not flag', () {
      expect(sawtooths(teeth(3, 6)), isEmpty);
    });

    test('four 3.5 m excursions do not flag', () {
      expect(sawtooths(teeth(4, 3.5)), isEmpty);
    });

    test('four 8 m excursions flag as a caution', () {
      final findings = sawtooths(teeth(4, 8));
      expect(findings, hasLength(1));
      expect(findings.first.severity, SafetySeverity.caution);
    });
  });

  group('safety stop credit', () {
    test('a 4-minute stop at 2.5 m counts as a safety stop', () {
      // Divers routinely hold a shallow stop at 8-10 ft. Off-gassing there is
      // better than at 5 m, so it must not read as an omitted stop.
      final profile = buildProfile([
        (18, 120),
        (18, 1200),
        (2.5, 190), // ascend to 2.5 m
        (2.5, 240), // 4-minute stop, shallower than the old 3 m zone floor
        (0, 60),
      ]);
      final findings = review(profile.depths, profile.timestamps);
      expect(
        findings.where((f) => f.ruleId == SafetyRuleId.omittedSafetyStop),
        isEmpty,
      );
    });

    test('surfacing straight from depth still flags an omitted stop', () {
      final profile = omittedSafetyStopProfile();
      final findings = review(profile.depths, profile.timestamps);
      expect(
        findings.where((f) => f.ruleId == SafetyRuleId.omittedSafetyStop),
        hasLength(1),
      );
    });
  });
}
