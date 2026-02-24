import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/computer_cns_extractor.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';

/// Generate a simple square-profile dive for testing:
/// Descent to [maxDepth] over [descentSeconds], hold for [bottomSeconds],
/// ascent back to surface over [ascentSeconds].
///
/// Returns a list of [DiveProfilePoint] with 1-second intervals.
List<DiveProfilePoint> _generateSquareProfile({
  double maxDepth = 30.0,
  int descentSeconds = 60,
  int bottomSeconds = 1200,
  int ascentSeconds = 180,
}) {
  final points = <DiveProfilePoint>[];
  int t = 0;

  // Descent
  for (int i = 0; i <= descentSeconds; i++) {
    final depth = maxDepth * (i / descentSeconds);
    points.add(DiveProfilePoint(timestamp: t, depth: depth));
    t++;
  }

  // Bottom
  for (int i = 1; i <= bottomSeconds; i++) {
    points.add(DiveProfilePoint(timestamp: t, depth: maxDepth));
    t++;
  }

  // Ascent
  for (int i = 1; i <= ascentSeconds; i++) {
    final depth = maxDepth * (1.0 - (i / ascentSeconds));
    points.add(DiveProfilePoint(timestamp: t, depth: depth));
    t++;
  }

  return points;
}

void main() {
  group('overlayComputerDecoData - per-metric source selection', () {
    late ProfileAnalysisService service;
    late List<DiveProfilePoint> baseProfile;
    late ProfileAnalysis baseAnalysis;

    setUp(() {
      service = ProfileAnalysisService(gfLow: 0.30, gfHigh: 0.70);
      baseProfile = _generateSquareProfile(maxDepth: 30.0, bottomSeconds: 600);

      final depths = baseProfile.map((p) => p.depth).toList();
      final timestamps = baseProfile.map((p) => p.timestamp).toList();

      baseAnalysis = service.analyze(
        diveId: 'test-overlay',
        depths: depths,
        timestamps: timestamps,
      );
    });

    test('cnsSource: calculated excludes CNS from overlay '
        'while NDL/ceiling/TTS are overlaid', () {
      // Build a profile with computer NDL, ceiling, TTS, AND CNS data
      final profileWithAll = <DiveProfilePoint>[];
      for (int i = 0; i < baseProfile.length; i++) {
        if (i >= 100 && i < 300) {
          profileWithAll.add(
            baseProfile[i].copyWith(ndl: 500, ceiling: 6.0, tts: 90, cns: 42.0),
          );
        } else {
          profileWithAll.add(baseProfile[i]);
        }
      }

      final (result, sourceInfo) = overlayComputerDecoData(
        baseAnalysis,
        profileWithAll,
        ndlSource: MetricDataSource.computer,
        ceilingSource: MetricDataSource.computer,
        ttsSource: MetricDataSource.computer,
        cnsSource: MetricDataSource.calculated,
      );

      // NDL, ceiling, and TTS should be overlaid
      expect(result.ndlCurve[150], equals(500));
      expect(result.ceilingCurve[150], closeTo(6.0, 0.001));
      expect(result.ttsCurve![150], equals(90));

      // CNS curve should NOT be overlaid -- it should remain unchanged
      // from the base analysis (the calculated CNS values)
      expect(
        result.cnsCurve![150],
        closeTo(baseAnalysis.cnsCurve![150], 0.001),
        reason:
            'With cnsSource: calculated, the CNS curve should '
            'retain the calculated values, not computer-reported values',
      );

      expect(sourceInfo.ndlActual, MetricDataSource.computer);
      expect(sourceInfo.ceilingActual, MetricDataSource.computer);
      expect(sourceInfo.ttsActual, MetricDataSource.computer);
      expect(sourceInfo.cnsActual, MetricDataSource.calculated);
    });

    test('cnsSource: computer overlays computer CNS curve', () {
      final profileWithCns = <DiveProfilePoint>[];
      for (int i = 0; i < baseProfile.length; i++) {
        if (i >= 100 && i < 300) {
          profileWithCns.add(baseProfile[i].copyWith(cns: 42.0));
        } else {
          profileWithCns.add(baseProfile[i]);
        }
      }

      final (result, sourceInfo) = overlayComputerDecoData(
        baseAnalysis,
        profileWithCns,
        cnsSource: MetricDataSource.computer,
      );

      // Computer CNS values should appear at the overlaid indices
      expect(result.cnsCurve![150], closeTo(42.0, 0.001));

      // Non-overlaid indices should fall back to calculated values
      expect(result.cnsCurve![50], closeTo(baseAnalysis.cnsCurve![50], 0.001));

      expect(sourceInfo.cnsActual, MetricDataSource.computer);
    });

    test('defaults to calculated for all metrics', () {
      final profileWithCns = <DiveProfilePoint>[];
      for (int i = 0; i < baseProfile.length; i++) {
        if (i >= 100 && i < 200) {
          profileWithCns.add(baseProfile[i].copyWith(cns: 55.0));
        } else {
          profileWithCns.add(baseProfile[i]);
        }
      }

      // Call without specifying any source params (all default to calculated)
      final (result, sourceInfo) = overlayComputerDecoData(
        baseAnalysis,
        profileWithCns,
      );

      // Default is calculated, so computer data should NOT be overlaid
      expect(
        result.cnsCurve![150],
        closeTo(baseAnalysis.cnsCurve![150], 0.001),
        reason:
            'Default source is calculated, '
            'so computer CNS data should be ignored',
      );

      expect(sourceInfo.cnsActual, MetricDataSource.calculated);
      expect(sourceInfo.ndlActual, MetricDataSource.calculated);
      expect(sourceInfo.ceilingActual, MetricDataSource.calculated);
      expect(sourceInfo.ttsActual, MetricDataSource.calculated);
    });

    test('cnsSource: calculated with only CNS computer data '
        'returns original analysis unchanged', () {
      // Profile that ONLY has computer CNS (no NDL, ceiling, or TTS)
      final profileCnsOnly = <DiveProfilePoint>[];
      for (int i = 0; i < baseProfile.length; i++) {
        if (i >= 100 && i < 300) {
          profileCnsOnly.add(baseProfile[i].copyWith(cns: 30.0));
        } else {
          profileCnsOnly.add(baseProfile[i]);
        }
      }

      final (result, sourceInfo) = overlayComputerDecoData(
        baseAnalysis,
        profileCnsOnly,
        cnsSource: MetricDataSource.calculated,
      );

      // With cnsSource: calculated and no other metric sources requesting
      // computer, the function should return the original analysis unchanged
      expect(result, same(baseAnalysis));
      expect(sourceInfo.cnsActual, MetricDataSource.calculated);
    });
  });

  group('Computer CNS to O2Exposure override via copyWith', () {
    test('overriding o2Exposure with computer cnsStart and cnsEnd '
        'produces correct values', () {
      final service = ProfileAnalysisService();
      final profile = _generateSquareProfile(maxDepth: 30.0);
      final depths = profile.map((p) => p.depth).toList();
      final timestamps = profile.map((p) => p.timestamp).toList();

      final analysis = service.analyze(
        diveId: 'test-cns-override',
        depths: depths,
        timestamps: timestamps,
      );

      // Simulate computer CNS: started at 12.5%, ended at 28.3%
      const computerCnsStart = 12.5;
      const computerCnsEnd = 28.3;

      final overridden = analysis.copyWith(
        o2Exposure: analysis.o2Exposure.copyWith(
          cnsStart: computerCnsStart,
          cnsEnd: computerCnsEnd,
        ),
      );

      // Computer CNS values should now be in o2Exposure
      expect(overridden.o2Exposure.cnsStart, equals(computerCnsStart));
      expect(overridden.o2Exposure.cnsEnd, equals(computerCnsEnd));

      // Other o2Exposure fields should remain from the original analysis
      expect(overridden.o2Exposure.otu, equals(analysis.o2Exposure.otu));
      expect(
        overridden.o2Exposure.maxPpO2,
        equals(analysis.o2Exposure.maxPpO2),
      );
      expect(
        overridden.o2Exposure.timeAboveWarning,
        equals(analysis.o2Exposure.timeAboveWarning),
      );
    });

    test('cnsDelta reflects the computer-reported start and end', () {
      const exposure = O2Exposure(cnsStart: 10.0, cnsEnd: 35.0);
      expect(exposure.cnsDelta, closeTo(25.0, 0.001));
    });

    test(
      'O2Exposure.copyWith preserves all fields when overriding only CNS',
      () {
        const original = O2Exposure(
          cnsStart: 0.0,
          cnsEnd: 5.0,
          otu: 42.0,
          maxPpO2: 1.3,
          maxPpO2Depth: 25.0,
          timeAboveWarning: 120,
          timeAboveCritical: 0,
        );

        final updated = original.copyWith(cnsStart: 8.0, cnsEnd: 20.0);

        expect(updated.cnsStart, equals(8.0));
        expect(updated.cnsEnd, equals(20.0));
        expect(updated.otu, equals(42.0));
        expect(updated.maxPpO2, equals(1.3));
        expect(updated.maxPpO2Depth, equals(25.0));
        expect(updated.timeAboveWarning, equals(120));
        expect(updated.timeAboveCritical, equals(0));
      },
    );
  });

  group('extractComputerCns result used as startCns', () {
    test('computerCns.cnsStart is used as the starting CNS for analysis', () {
      // Build a profile with computer CNS starting at 15%
      final profile = <DiveProfilePoint>[
        const DiveProfilePoint(timestamp: 0, depth: 0.0, cns: 15.0),
        const DiveProfilePoint(timestamp: 60, depth: 20.0, cns: 16.0),
        const DiveProfilePoint(timestamp: 120, depth: 20.0, cns: 17.0),
        const DiveProfilePoint(timestamp: 180, depth: 10.0, cns: 17.5),
        const DiveProfilePoint(timestamp: 240, depth: 0.0, cns: 18.0),
      ];

      final computerCns = extractComputerCns(profile);
      expect(computerCns, isNotNull);
      expect(computerCns!.cnsStart, equals(15.0));

      // When using this as startCns for ProfileAnalysisService.analyze,
      // the analysis should account for the non-zero starting CNS
      final service = ProfileAnalysisService();
      final depths = profile.map((p) => p.depth).toList();
      final timestamps = profile.map((p) => p.timestamp).toList();

      final analysis = service.analyze(
        diveId: 'test-start-cns',
        depths: depths,
        timestamps: timestamps,
        startCns: computerCns.cnsStart,
      );

      // The o2Exposure should reflect the 15% starting CNS
      expect(analysis.o2Exposure.cnsStart, equals(15.0));

      // The CNS curve first point should start at 15%
      expect(analysis.cnsCurve, isNotNull);
      expect(analysis.cnsCurve!.first, closeTo(15.0, 0.001));

      // CNS end should be >= startCns (can only increase during dive)
      expect(
        analysis.o2Exposure.cnsEnd,
        greaterThanOrEqualTo(15.0),
        reason: 'CNS should not decrease during a dive',
      );
    });

    test('zero computer cnsStart (dive with no residual) starts at 0', () {
      final profile = <DiveProfilePoint>[
        const DiveProfilePoint(timestamp: 0, depth: 0.0, cns: 0.0),
        const DiveProfilePoint(timestamp: 60, depth: 20.0, cns: 0.5),
        const DiveProfilePoint(timestamp: 120, depth: 20.0, cns: 1.0),
        const DiveProfilePoint(timestamp: 180, depth: 0.0, cns: 1.2),
      ];

      final computerCns = extractComputerCns(profile);
      expect(computerCns, isNotNull);
      expect(computerCns!.cnsStart, equals(0.0));

      final service = ProfileAnalysisService();
      final depths = profile.map((p) => p.depth).toList();
      final timestamps = profile.map((p) => p.timestamp).toList();

      final analysis = service.analyze(
        diveId: 'test-zero-cns',
        depths: depths,
        timestamps: timestamps,
        startCns: computerCns.cnsStart,
      );

      expect(analysis.o2Exposure.cnsStart, equals(0.0));
      expect(analysis.cnsCurve!.first, closeTo(0.0, 0.001));
    });
  });

  group('CnsTable.cnsAfterSurfaceInterval - decay with computer CNS', () {
    test('decay from computer cnsEnd produces correct residual after '
        'one half-time (90 minutes)', () {
      const computerCnsEnd = 40.0;
      const surfaceIntervalMinutes = 90;

      final residual = CnsTable.cnsAfterSurfaceInterval(
        computerCnsEnd,
        surfaceIntervalMinutes,
      );

      // After exactly one half-time (90 min), CNS should halve
      expect(residual, closeTo(20.0, 0.01));
    });

    test('decay from computer cnsEnd after two half-times (180 min)', () {
      const computerCnsEnd = 60.0;
      const surfaceIntervalMinutes = 180;

      final residual = CnsTable.cnsAfterSurfaceInterval(
        computerCnsEnd,
        surfaceIntervalMinutes,
      );

      // After two half-times: 60 * 0.25 = 15
      expect(residual, closeTo(15.0, 0.01));
    });

    test('decay from computer cnsEnd after arbitrary surface interval', () {
      const computerCnsEnd = 50.0;
      const surfaceIntervalMinutes = 45; // half a half-time

      final residual = CnsTable.cnsAfterSurfaceInterval(
        computerCnsEnd,
        surfaceIntervalMinutes,
      );

      // Manual calculation: 50 * 0.5^(45/90) = 50 * 0.5^0.5 = 50 * ~0.7071 = ~35.355
      final expected = 50.0 * math.pow(0.5, 45.0 / 90.0);
      expect(residual, closeTo(expected, 0.01));
    });

    test(
      'zero computer cnsEnd produces zero residual regardless of interval',
      () {
        expect(CnsTable.cnsAfterSurfaceInterval(0.0, 60), equals(0.0));
        expect(CnsTable.cnsAfterSurfaceInterval(0.0, 0), equals(0.0));
        expect(CnsTable.cnsAfterSurfaceInterval(0.0, 1440), equals(0.0));
      },
    );

    test('very long surface interval (24 hours) decays to near zero', () {
      const computerCnsEnd = 100.0;
      const surfaceIntervalMinutes = 1440; // 24 hours

      final residual = CnsTable.cnsAfterSurfaceInterval(
        computerCnsEnd,
        surfaceIntervalMinutes,
      );

      // 1440 / 90 = 16 half-times => 100 * 0.5^16 = ~0.0015%
      expect(
        residual,
        lessThan(0.01),
        reason: 'After 24 hours, CNS should be effectively zero',
      );
    });

    test('short surface interval preserves most of computer cnsEnd', () {
      const computerCnsEnd = 80.0;
      const surfaceIntervalMinutes = 10;

      final residual = CnsTable.cnsAfterSurfaceInterval(
        computerCnsEnd,
        surfaceIntervalMinutes,
      );

      // 10/90 = 0.111 half-times => 80 * 0.5^0.111 = ~73.9
      final expected = 80.0 * math.pow(0.5, 10.0 / 90.0);
      expect(residual, closeTo(expected, 0.01));
      expect(
        residual,
        greaterThan(70.0),
        reason: 'Short surface interval should preserve most CNS',
      );
    });

    test('end-to-end: extract computer CNS, apply surface interval decay, '
        'use as startCns for next dive', () {
      // Dive 1: computer reports CNS from 5% to 25%
      final dive1Profile = <DiveProfilePoint>[
        const DiveProfilePoint(timestamp: 0, depth: 0.0, cns: 5.0),
        const DiveProfilePoint(timestamp: 600, depth: 30.0, cns: 15.0),
        const DiveProfilePoint(timestamp: 1200, depth: 30.0, cns: 22.0),
        const DiveProfilePoint(timestamp: 1500, depth: 0.0, cns: 25.0),
      ];

      final dive1Cns = extractComputerCns(dive1Profile);
      expect(dive1Cns, isNotNull);
      expect(dive1Cns!.cnsEnd, equals(25.0));

      // Surface interval: 60 minutes
      const surfaceMinutes = 60;
      final residualCns = CnsTable.cnsAfterSurfaceInterval(
        dive1Cns.cnsEnd,
        surfaceMinutes,
      );

      // 25 * 0.5^(60/90) = 25 * 0.5^0.6667 = ~15.75
      final expectedResidual = 25.0 * math.pow(0.5, 60.0 / 90.0);
      expect(residualCns, closeTo(expectedResidual, 0.1));

      // Dive 2: use residual as startCns
      final service = ProfileAnalysisService();
      final dive2Profile = _generateSquareProfile(
        maxDepth: 20.0,
        bottomSeconds: 600,
      );
      final depths = dive2Profile.map((p) => p.depth).toList();
      final timestamps = dive2Profile.map((p) => p.timestamp).toList();

      final dive2Analysis = service.analyze(
        diveId: 'dive-2',
        depths: depths,
        timestamps: timestamps,
        startCns: residualCns,
      );

      // Dive 2 should start where the decayed residual left off
      expect(dive2Analysis.o2Exposure.cnsStart, closeTo(residualCns, 0.001));
      expect(dive2Analysis.cnsCurve!.first, closeTo(residualCns, 0.001));

      // Dive 2 CNS end should be greater than start (accumulates during dive)
      expect(
        dive2Analysis.o2Exposure.cnsEnd,
        greaterThan(dive2Analysis.o2Exposure.cnsStart),
      );
    });
  });

  group('Provider decision logic integration', () {
    // These tests simulate the full decision flow from profileAnalysisProvider:
    // 1. Check setting (useComputerCns)
    // 2. Extract computer CNS if setting is on
    // 3. Determine startCns (computer cnsStart or residual/0.0)
    // 4. Run analysis
    // 5. Overlay computer deco data
    // 6. Override o2Exposure if computer CNS available

    /// Helper: build a profile with computer CNS samples on every point.
    List<DiveProfilePoint> buildProfileWithComputerCns({
      double cnsFirst = 5.0,
      double cnsLast = 25.0,
    }) {
      // Simple 5-point dive at 20m with linearly increasing CNS
      const points = 5;
      final profile = <DiveProfilePoint>[];
      for (int i = 0; i < points; i++) {
        final t = i * 300; // 0, 300, 600, 900, 1200
        final depth = i == 0 || i == points - 1
            ? 0.0
            : 20.0; // surface at start/end, 20m in middle
        final cns = cnsFirst + (cnsLast - cnsFirst) * (i / (points - 1));
        profile.add(DiveProfilePoint(timestamp: t, depth: depth, cns: cns));
      }
      return profile;
    }

    test('setting ON + dive with computer CNS -> '
        'o2Exposure uses computer values', () {
      // Setting ON: extract computer CNS from profile
      final profile = buildProfileWithComputerCns(cnsFirst: 5.0, cnsLast: 25.0);

      // Step 2: extract computer CNS (setting is ON)
      final computerCns = extractComputerCns(profile);
      expect(computerCns, isNotNull);
      expect(computerCns!.cnsStart, equals(5.0));
      expect(computerCns.cnsEnd, equals(25.0));

      // Step 3: startCns = computer cnsStart (since computerCns != null)
      final startCns = computerCns.cnsStart;

      // Step 4: run analysis
      final service = ProfileAnalysisService();
      final depths = profile.map((p) => p.depth).toList();
      final timestamps = profile.map((p) => p.timestamp).toList();
      final analysis = service.analyze(
        diveId: 'test-decision-1',
        depths: depths,
        timestamps: timestamps,
        startCns: startCns,
      );

      // Step 5: overlay computer deco data (cnsSource: computer)
      final (overlaid, _) = overlayComputerDecoData(
        analysis,
        profile,
        ndlSource: MetricDataSource.computer,
        ceilingSource: MetricDataSource.computer,
        ttsSource: MetricDataSource.computer,
        cnsSource: MetricDataSource.computer,
      );

      // Step 6: override o2Exposure with computer CNS
      final withCns = overlaid.copyWith(
        o2Exposure: overlaid.o2Exposure.copyWith(
          cnsStart: computerCns.cnsStart,
          cnsEnd: computerCns.cnsEnd,
        ),
      );

      // Assert: final o2Exposure uses computer values
      expect(withCns.o2Exposure.cnsStart, equals(5.0));
      expect(withCns.o2Exposure.cnsEnd, equals(25.0));
    });

    test('setting ON + dive without computer CNS -> '
        'o2Exposure uses calculated values', () {
      // Setting ON, but profile has no CNS samples (plain square profile)
      final profile = _generateSquareProfile(
        maxDepth: 30.0,
        bottomSeconds: 600,
      );

      // Step 2: extract computer CNS (setting is ON, but no CNS data)
      final computerCns = extractComputerCns(profile);
      expect(computerCns, isNull);

      // Step 3: startCns falls back to 0.0 (first dive, no residual)
      const startCns = 0.0;

      // Step 4: run analysis
      final service = ProfileAnalysisService();
      final depths = profile.map((p) => p.depth).toList();
      final timestamps = profile.map((p) => p.timestamp).toList();
      final analysis = service.analyze(
        diveId: 'test-decision-2',
        depths: depths,
        timestamps: timestamps,
        startCns: startCns,
      );

      // Step 5: overlay (no computer data, returns analysis unchanged)
      final (overlaid, _) = overlayComputerDecoData(
        analysis,
        profile,
        ndlSource: MetricDataSource.computer,
        ceilingSource: MetricDataSource.computer,
        ttsSource: MetricDataSource.computer,
        cnsSource: MetricDataSource.computer,
      );

      // Step 6: computerCns is null, so no override -- use overlaid as-is

      // Assert: cnsStart == 0.0 (first dive)
      expect(overlaid.o2Exposure.cnsStart, equals(0.0));
      // Assert: cnsEnd > 0 (dive at 30m on air generates CNS)
      expect(
        overlaid.o2Exposure.cnsEnd,
        greaterThan(0.0),
        reason: 'A dive at 30m on air should accumulate some CNS',
      );
    });

    test('setting OFF + dive with computer CNS -> '
        'o2Exposure uses calculated values (ignores computer)', () {
      // Setting OFF: profile has computer CNS data but it should be ignored
      final profile = buildProfileWithComputerCns(cnsFirst: 5.0, cnsLast: 25.0);

      // Step 2: setting is OFF, so we skip extraction entirely
      // (mirrors: useComputerCns ? extractComputerCns(profile) : null)
      // computerCns is null because the setting is off.

      // Step 3: startCns falls back to 0.0 (first dive, no residual)
      const startCns = 0.0;

      // Step 4: run analysis
      final service = ProfileAnalysisService();
      final depths = profile.map((p) => p.depth).toList();
      final timestamps = profile.map((p) => p.timestamp).toList();
      final analysis = service.analyze(
        diveId: 'test-decision-3',
        depths: depths,
        timestamps: timestamps,
        startCns: startCns,
      );

      // Step 5: overlay with cnsSource: calculated (setting OFF)
      final (overlaid, _) = overlayComputerDecoData(
        analysis,
        profile,
        ndlSource: MetricDataSource.computer,
        ceilingSource: MetricDataSource.computer,
        ttsSource: MetricDataSource.computer,
        cnsSource: MetricDataSource.calculated,
      );

      // Step 6: computerCns is null (setting OFF), so no override

      // Assert: cnsStart == 0.0 (NOT 5.0 from computer)
      expect(overlaid.o2Exposure.cnsStart, equals(0.0));
      // Assert: cnsEnd is the calculated value, NOT 25.0 from computer
      expect(
        overlaid.o2Exposure.cnsEnd,
        isNot(equals(25.0)),
        reason:
            'With setting OFF, o2Exposure.cnsEnd should be the '
            'calculated value, not the computer-reported 25.0',
      );
    });

    test('recursive chain: previous dive has computer CNS, '
        'current does not, setting ON', () {
      // Setting ON for both dives

      // --- Previous dive: computer reports CNS ending at 40.0 ---
      final prevProfile = buildProfileWithComputerCns(
        cnsFirst: 10.0,
        cnsLast: 40.0,
      );
      final prevComputerCns = extractComputerCns(prevProfile);
      expect(prevComputerCns, isNotNull);
      expect(prevComputerCns!.cnsEnd, equals(40.0));

      // --- Surface interval: 90 minutes (exactly one half-time) ---
      const surfaceIntervalMinutes = 90;
      final residualCns = CnsTable.cnsAfterSurfaceInterval(
        prevComputerCns.cnsEnd,
        surfaceIntervalMinutes,
      );
      // 40.0 * 0.5^(90/90) = 40.0 * 0.5 = 20.0
      expect(residualCns, closeTo(20.0, 0.01));

      // --- Current dive: NO computer CNS ---
      final currentProfile = _generateSquareProfile(
        maxDepth: 20.0,
        bottomSeconds: 600,
      );
      final currentComputerCns = extractComputerCns(currentProfile);
      expect(currentComputerCns, isNull);

      // Step 3: computerCns is null for current dive, so startCns = residual
      final startCns = residualCns;

      // Step 4: run analysis
      final service = ProfileAnalysisService();
      final depths = currentProfile.map((p) => p.depth).toList();
      final timestamps = currentProfile.map((p) => p.timestamp).toList();
      final analysis = service.analyze(
        diveId: 'test-decision-4',
        depths: depths,
        timestamps: timestamps,
        startCns: startCns,
      );

      // Step 5: overlay (no computer data on current dive)
      final (overlaid, _) = overlayComputerDecoData(
        analysis,
        currentProfile,
        ndlSource: MetricDataSource.computer,
        ceilingSource: MetricDataSource.computer,
        ttsSource: MetricDataSource.computer,
        cnsSource: MetricDataSource.computer,
      );

      // Step 6: computerCns is null for current dive, no override

      // Assert: current dive starts at the decayed residual (~20.0)
      expect(
        overlaid.o2Exposure.cnsStart,
        closeTo(20.0, 0.1),
        reason:
            'Current dive should start with residual CNS '
            'decayed from previous dive computer CNS end (40.0) '
            'after 90-minute surface interval',
      );
    });
  });

  group('Per-metric source selection', () {
    late ProfileAnalysisService service;
    late List<DiveProfilePoint> profile;
    late ProfileAnalysis baseAnalysis;

    setUp(() {
      service = ProfileAnalysisService(gfLow: 0.30, gfHigh: 0.70);
      // Profile with ALL computer data types
      profile = List.generate(20, (i) {
        final depth = i < 10 ? (i * 3.0) : ((20 - i) * 3.0);
        final timestamp = i * 30;
        return DiveProfilePoint(
          depth: depth,
          timestamp: timestamp,
          temperature: 20.0,
          ndl: depth > 5 ? (99 - i) : null,
          ceiling: depth > 15 ? (depth * 0.1) : null,
          tts: depth > 15 ? (i * 2) : null,
          cns: depth > 0 ? (i * 1.5) : null,
        );
      });

      final depths = profile.map((p) => p.depth).toList();
      final timestamps = profile.map((p) => p.timestamp).toList();
      baseAnalysis = service.analyze(
        diveId: 'test-per-metric',
        depths: depths,
        timestamps: timestamps,
      );
    });

    test('all sources=computer overlays everything', () {
      final (result, sourceInfo) = overlayComputerDecoData(
        baseAnalysis,
        profile,
        ndlSource: MetricDataSource.computer,
        ceilingSource: MetricDataSource.computer,
        ttsSource: MetricDataSource.computer,
        cnsSource: MetricDataSource.computer,
      );

      expect(sourceInfo.ndlActual, MetricDataSource.computer);
      expect(sourceInfo.ceilingActual, MetricDataSource.computer);
      expect(sourceInfo.ttsActual, MetricDataSource.computer);
      expect(sourceInfo.cnsActual, MetricDataSource.computer);

      // Verify NDL curve uses computer values where available
      final ndlPoint = profile.indexWhere((p) => p.ndl != null);
      expect(result.ndlCurve[ndlPoint], profile[ndlPoint].ndl);
    });

    test('mixed sources: NDL=computer, ceiling=calculated, '
        'TTS=computer, CNS=calculated', () {
      final (result, sourceInfo) = overlayComputerDecoData(
        baseAnalysis,
        profile,
        ndlSource: MetricDataSource.computer,
        ceilingSource: MetricDataSource.calculated,
        ttsSource: MetricDataSource.computer,
        cnsSource: MetricDataSource.calculated,
      );

      expect(sourceInfo.ndlActual, MetricDataSource.computer);
      expect(sourceInfo.ceilingActual, MetricDataSource.calculated);
      expect(sourceInfo.ttsActual, MetricDataSource.computer);
      expect(sourceInfo.cnsActual, MetricDataSource.calculated);

      // Ceiling should be unchanged from base analysis
      expect(result.ceilingCurve, equals(baseAnalysis.ceilingCurve));
    });

    test('source=computer with missing data falls back', () {
      // Profile with ONLY NDL data, no ceiling/TTS/CNS
      final ndlOnlyProfile = List.generate(10, (i) {
        return DiveProfilePoint(
          depth: i * 3.0,
          timestamp: i * 30,
          temperature: 20.0,
          ndl: 99 - i,
        );
      });

      final depths = ndlOnlyProfile.map((p) => p.depth).toList();
      final timestamps = ndlOnlyProfile.map((p) => p.timestamp).toList();
      final analysis = service.analyze(
        diveId: 'test-fallback',
        depths: depths,
        timestamps: timestamps,
      );

      final (_, sourceInfo) = overlayComputerDecoData(
        analysis,
        ndlOnlyProfile,
        ndlSource: MetricDataSource.computer,
        ceilingSource: MetricDataSource.computer,
        ttsSource: MetricDataSource.computer,
        cnsSource: MetricDataSource.computer,
      );

      expect(sourceInfo.ndlActual, MetricDataSource.computer);
      expect(sourceInfo.ceilingActual, MetricDataSource.calculated); // Fallback
      expect(sourceInfo.ttsActual, MetricDataSource.calculated); // Fallback
      expect(sourceInfo.cnsActual, MetricDataSource.calculated); // Fallback
    });

    test('all sources=calculated ignores all computer data', () {
      final (result, sourceInfo) = overlayComputerDecoData(
        baseAnalysis,
        profile,
        // All defaults to calculated
      );

      expect(sourceInfo.ndlActual, MetricDataSource.calculated);
      expect(sourceInfo.ceilingActual, MetricDataSource.calculated);
      expect(sourceInfo.ttsActual, MetricDataSource.calculated);
      expect(sourceInfo.cnsActual, MetricDataSource.calculated);

      // Analysis should be unchanged
      expect(result.ndlCurve, equals(baseAnalysis.ndlCurve));
      expect(result.ceilingCurve, equals(baseAnalysis.ceilingCurve));
    });
  });
}
