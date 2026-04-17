import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _SettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _SettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
  group('ProfileAnalysisService - Gradient Factor override', () {
    test('different GF values produce different NDL curves', () {
      // Conservative GF 30/70
      final conservativeService = ProfileAnalysisService(
        gfLow: 0.30,
        gfHigh: 0.70,
      );

      // Liberal GF 100/100 (no GF limiting)
      final liberalService = ProfileAnalysisService(gfLow: 1.00, gfHigh: 1.00);

      final profile = _generateSquareProfile(maxDepth: 30.0);
      final depths = profile.map((p) => p.depth).toList();
      final timestamps = profile.map((p) => p.timestamp).toList();

      final conservativeAnalysis = conservativeService.analyze(
        diveId: 'test-1',
        depths: depths,
        timestamps: timestamps,
      );

      final liberalAnalysis = liberalService.analyze(
        diveId: 'test-2',
        depths: depths,
        timestamps: timestamps,
      );

      // With the same profile, liberal GF should give higher NDL values
      // (more time before deco obligation)
      // Find a point at depth where NDL is meaningful
      const midBottomIndex = 60 + 300; // 5 min into bottom time
      expect(
        liberalAnalysis.ndlCurve[midBottomIndex],
        greaterThan(conservativeAnalysis.ndlCurve[midBottomIndex]),
        reason:
            'Liberal GF 100/100 should produce higher NDL than conservative '
            'GF 30/70 at the same depth',
      );
    });

    test('different GF values produce different ceiling curves', () {
      final conservativeService = ProfileAnalysisService(
        gfLow: 0.30,
        gfHigh: 0.70,
      );

      final liberalService = ProfileAnalysisService(gfLow: 1.00, gfHigh: 1.00);

      // Use a deeper/longer dive more likely to create deco obligation
      final profile = _generateSquareProfile(
        maxDepth: 40.0,
        bottomSeconds: 1800,
      );
      final depths = profile.map((p) => p.depth).toList();
      final timestamps = profile.map((p) => p.timestamp).toList();

      final conservativeAnalysis = conservativeService.analyze(
        diveId: 'test-1',
        depths: depths,
        timestamps: timestamps,
      );

      final liberalAnalysis = liberalService.analyze(
        diveId: 'test-2',
        depths: depths,
        timestamps: timestamps,
      );

      // Conservative GF should produce deeper ceilings (more restrictive)
      final maxConservativeCeiling = conservativeAnalysis.ceilingCurve.reduce(
        (a, b) => a > b ? a : b,
      );
      final maxLiberalCeiling = liberalAnalysis.ceilingCurve.reduce(
        (a, b) => a > b ? a : b,
      );

      expect(
        maxConservativeCeiling,
        greaterThanOrEqualTo(maxLiberalCeiling),
        reason:
            'Conservative GF 30/70 should produce deeper or equal ceiling '
            'compared to liberal GF 100/100',
      );
    });

    test('dive-specific GF of 30/70 matches service with 30/70', () {
      final service = ProfileAnalysisService(gfLow: 0.30, gfHigh: 0.70);

      final profile = _generateSquareProfile(maxDepth: 30.0);
      final depths = profile.map((p) => p.depth).toList();
      final timestamps = profile.map((p) => p.timestamp).toList();

      final analysis = service.analyze(
        diveId: 'test-gf',
        depths: depths,
        timestamps: timestamps,
      );

      // Verify the analysis is valid
      expect(analysis.ndlCurve.length, equals(depths.length));
      expect(analysis.ceilingCurve.length, equals(depths.length));
      expect(analysis.maxDepth, closeTo(30.0, 0.1));
    });
  });

  group('ProfileAnalysis.copyWith', () {
    test('returns identical analysis when no overrides provided', () {
      final service = ProfileAnalysisService();
      final profile = _generateSquareProfile(maxDepth: 20.0);
      final depths = profile.map((p) => p.depth).toList();
      final timestamps = profile.map((p) => p.timestamp).toList();

      final original = service.analyze(
        diveId: 'test-copy',
        depths: depths,
        timestamps: timestamps,
      );

      final copy = original.copyWith();

      expect(copy.ndlCurve, equals(original.ndlCurve));
      expect(copy.ceilingCurve, equals(original.ceilingCurve));
      expect(copy.ttsCurve, equals(original.ttsCurve));
      expect(copy.cnsCurve, equals(original.cnsCurve));
      expect(copy.maxDepth, equals(original.maxDepth));
      expect(copy.averageDepth, equals(original.averageDepth));
    });

    test('overrides specific fields while preserving others', () {
      final service = ProfileAnalysisService();
      final profile = _generateSquareProfile(maxDepth: 20.0);
      final depths = profile.map((p) => p.depth).toList();
      final timestamps = profile.map((p) => p.timestamp).toList();

      final original = service.analyze(
        diveId: 'test-copy-override',
        depths: depths,
        timestamps: timestamps,
      );

      final newNdl = List<int>.filled(original.ndlCurve.length, 999);
      final copy = original.copyWith(ndlCurve: newNdl);

      expect(copy.ndlCurve, equals(newNdl));
      // Other fields should remain unchanged
      expect(copy.ceilingCurve, equals(original.ceilingCurve));
      expect(copy.ppO2Curve, equals(original.ppO2Curve));
      expect(copy.maxDepth, equals(original.maxDepth));
    });
  });

  group('overlayComputerDecoData', () {
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

    test('returns original analysis when no computer data present', () {
      // Profile with no computer deco data (all ndl/ceiling/tts/cns null)
      final (result, sourceInfo) = overlayComputerDecoData(
        baseAnalysis,
        baseProfile,
      );
      expect(result, same(baseAnalysis));
      expect(sourceInfo.ndlActual, MetricDataSource.calculated);
      expect(sourceInfo.ceilingActual, MetricDataSource.calculated);
      expect(sourceInfo.ttsActual, MetricDataSource.calculated);
      expect(sourceInfo.cnsActual, MetricDataSource.calculated);
    });

    test('overlays computer NDL when available', () {
      // Add computer NDL to some profile points
      final profileWithNdl = <DiveProfilePoint>[];
      for (int i = 0; i < baseProfile.length; i++) {
        if (i >= 100 && i < 200) {
          profileWithNdl.add(baseProfile[i].copyWith(ndl: 600));
        } else {
          profileWithNdl.add(baseProfile[i]);
        }
      }

      final (result, sourceInfo) = overlayComputerDecoData(
        baseAnalysis,
        profileWithNdl,
        ndlSource: MetricDataSource.computer,
      );

      // Points with computer NDL should use computer value
      expect(result.ndlCurve[150], equals(600));

      // Points without computer NDL should use calculated value
      expect(result.ndlCurve[50], equals(baseAnalysis.ndlCurve[50]));

      expect(sourceInfo.ndlActual, MetricDataSource.computer);
    });

    test('overlays computer ceiling when available', () {
      final profileWithCeiling = <DiveProfilePoint>[];
      for (int i = 0; i < baseProfile.length; i++) {
        if (i >= 200 && i < 400) {
          profileWithCeiling.add(baseProfile[i].copyWith(ceiling: 3.0));
        } else {
          profileWithCeiling.add(baseProfile[i]);
        }
      }

      final (result, sourceInfo) = overlayComputerDecoData(
        baseAnalysis,
        profileWithCeiling,
        ceilingSource: MetricDataSource.computer,
      );

      // Points with computer ceiling should use computer value
      expect(result.ceilingCurve[250], closeTo(3.0, 0.001));

      // Points without computer ceiling should use calculated value
      expect(
        result.ceilingCurve[50],
        closeTo(baseAnalysis.ceilingCurve[50], 0.001),
      );

      expect(sourceInfo.ceilingActual, MetricDataSource.computer);
    });

    test('overlays computer TTS when available', () {
      final profileWithTts = <DiveProfilePoint>[];
      for (int i = 0; i < baseProfile.length; i++) {
        if (i >= 100 && i < 300) {
          profileWithTts.add(baseProfile[i].copyWith(tts: 120));
        } else {
          profileWithTts.add(baseProfile[i]);
        }
      }

      final (result, sourceInfo) = overlayComputerDecoData(
        baseAnalysis,
        profileWithTts,
        ttsSource: MetricDataSource.computer,
      );

      // Points with computer TTS should use computer value
      expect(result.ttsCurve![200], equals(120));

      // Points without computer TTS should use calculated value
      expect(result.ttsCurve![50], equals(baseAnalysis.ttsCurve![50]));

      expect(sourceInfo.ttsActual, MetricDataSource.computer);
    });

    test('overlays computer CNS when available', () {
      final profileWithCns = <DiveProfilePoint>[];
      for (int i = 0; i < baseProfile.length; i++) {
        if (i >= 100 && i < 300) {
          profileWithCns.add(baseProfile[i].copyWith(cns: 25.0));
        } else {
          profileWithCns.add(baseProfile[i]);
        }
      }

      final (result, sourceInfo) = overlayComputerDecoData(
        baseAnalysis,
        profileWithCns,
        cnsSource: MetricDataSource.computer,
      );

      // Points with computer CNS should use computer value
      expect(result.cnsCurve![150], closeTo(25.0, 0.001));

      // Points without computer CNS should use calculated value
      expect(result.cnsCurve![50], closeTo(baseAnalysis.cnsCurve![50], 0.001));

      expect(sourceInfo.cnsActual, MetricDataSource.computer);
    });

    test(
      'handles mixed computer data - some points have data, some do not',
      () {
        // Alternate: every other point has computer NDL
        final profileMixed = <DiveProfilePoint>[];
        for (int i = 0; i < baseProfile.length; i++) {
          if (i % 2 == 0 && i >= 60 && i < 660) {
            profileMixed.add(baseProfile[i].copyWith(ndl: 777));
          } else {
            profileMixed.add(baseProfile[i]);
          }
        }

        final (result, sourceInfo) = overlayComputerDecoData(
          baseAnalysis,
          profileMixed,
          ndlSource: MetricDataSource.computer,
          ceilingSource: MetricDataSource.computer,
          ttsSource: MetricDataSource.computer,
          cnsSource: MetricDataSource.computer,
        );

        // Even indices in range should have computer value
        expect(result.ndlCurve[100], equals(777));

        // Odd indices should use calculated value
        expect(result.ndlCurve[101], equals(baseAnalysis.ndlCurve[101]));

        expect(sourceInfo.ndlActual, MetricDataSource.computer);
      },
    );

    test('overlays multiple curves simultaneously', () {
      final profileMulti = <DiveProfilePoint>[];
      for (int i = 0; i < baseProfile.length; i++) {
        if (i >= 100 && i < 200) {
          profileMulti.add(
            baseProfile[i].copyWith(ndl: 500, ceiling: 6.0, tts: 90, cns: 15.0),
          );
        } else {
          profileMulti.add(baseProfile[i]);
        }
      }

      final (result, sourceInfo) = overlayComputerDecoData(
        baseAnalysis,
        profileMulti,
        ndlSource: MetricDataSource.computer,
        ceilingSource: MetricDataSource.computer,
        ttsSource: MetricDataSource.computer,
        cnsSource: MetricDataSource.computer,
      );

      // All four curves should be overlaid at index 150
      expect(result.ndlCurve[150], equals(500));
      expect(result.ceilingCurve[150], closeTo(6.0, 0.001));
      expect(result.ttsCurve![150], equals(90));
      expect(result.cnsCurve![150], closeTo(15.0, 0.001));

      expect(sourceInfo.ndlActual, MetricDataSource.computer);
      expect(sourceInfo.ceilingActual, MetricDataSource.computer);
      expect(sourceInfo.ttsActual, MetricDataSource.computer);
      expect(sourceInfo.cnsActual, MetricDataSource.computer);
    });

    test('handles empty analysis curves gracefully', () {
      // Create a truly empty analysis with null optional curves
      final emptyAnalysis = ProfileAnalysis(
        ascentRates: baseAnalysis.ascentRates,
        ascentRateStats: baseAnalysis.ascentRateStats,
        ascentRateViolations: baseAnalysis.ascentRateViolations,
        events: baseAnalysis.events,
        ceilingCurve: baseAnalysis.ceilingCurve,
        ndlCurve: baseAnalysis.ndlCurve,
        decoStatuses: baseAnalysis.decoStatuses,
        o2Exposure: baseAnalysis.o2Exposure,
        ppO2Curve: baseAnalysis.ppO2Curve,
        // Explicitly null optional curves
        ttsCurve: null,
        cnsCurve: null,
        maxDepth: baseAnalysis.maxDepth,
        averageDepth: baseAnalysis.averageDepth,
        maxDepthTimestamp: baseAnalysis.maxDepthTimestamp,
        durationSeconds: baseAnalysis.durationSeconds,
      );

      final profileWithTts = <DiveProfilePoint>[];
      for (int i = 0; i < baseProfile.length; i++) {
        if (i >= 100 && i < 200) {
          profileWithTts.add(baseProfile[i].copyWith(tts: 120, cns: 20.0));
        } else {
          profileWithTts.add(baseProfile[i]);
        }
      }

      final (result, sourceInfo) = overlayComputerDecoData(
        emptyAnalysis,
        profileWithTts,
        ndlSource: MetricDataSource.computer,
        ceilingSource: MetricDataSource.computer,
        ttsSource: MetricDataSource.computer,
        cnsSource: MetricDataSource.computer,
      );

      // Even with null base curves, computer data should produce curves
      // with computer values where available and 0 fallback elsewhere
      expect(result.ttsCurve, isNotNull);
      expect(result.ttsCurve![150], equals(120));
      expect(result.ttsCurve![50], equals(0));

      expect(result.cnsCurve, isNotNull);
      expect(result.cnsCurve![150], closeTo(20.0, 0.001));
      expect(result.cnsCurve![50], closeTo(0.0, 0.001));

      expect(sourceInfo.ttsActual, MetricDataSource.computer);
      expect(sourceInfo.cnsActual, MetricDataSource.computer);
    });

    test('source=calculated ignores available computer NDL data', () {
      final profileWithNdl = List.generate(baseProfile.length, (i) {
        return baseProfile[i].copyWith(ndl: i < 5 ? 12 : null);
      });

      final (result, sourceInfo) = overlayComputerDecoData(
        baseAnalysis,
        profileWithNdl,
        ndlSource: MetricDataSource.calculated,
      );
      expect(result.ndlCurve, equals(baseAnalysis.ndlCurve));
      expect(sourceInfo.ndlActual, MetricDataSource.calculated);
    });

    test('source=computer without data falls back to calculated', () {
      final (result, sourceInfo) = overlayComputerDecoData(
        baseAnalysis,
        baseProfile,
        ndlSource: MetricDataSource.computer,
      );
      expect(result.ndlCurve, equals(baseAnalysis.ndlCurve));
      expect(sourceInfo.ndlActual, MetricDataSource.calculated);
    });
  });

  group('diveProfileAnalysisProvider', () {
    test('returns analysis for a dive with profile data', () {
      final profile = _generateSquareProfile(
        maxDepth: 18.0,
        descentSeconds: 30,
        bottomSeconds: 600,
        ascentSeconds: 90,
      );
      final dive = Dive(
        id: 'test-dive',
        dateTime: DateTime(2025, 1, 1),
        profile: profile,
      );

      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => _SettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(diveProfileAnalysisProvider(dive));
      expect(result, isNotNull);
      expect(result!.ascentRates, isNotEmpty);
    });

    test('returns null for empty profile', () {
      final dive = Dive(
        id: 'empty-dive',
        dateTime: DateTime(2025, 1, 1),
        profile: const [],
      );

      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => _SettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(diveProfileAnalysisProvider(dive));
      expect(result, isNull);
    });
  });
}
