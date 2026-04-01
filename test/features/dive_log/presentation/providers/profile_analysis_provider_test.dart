import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart'
    as divers;
import 'package:submersion/features/divers/domain/entities/diver.dart' as domain;
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SharedPreferences _prefs;

class _FakeDiverRepository extends divers.DiverRepository {
  @override
  Future<domain.Diver?> getDiverById(String id) async => null;

  @override
  Future<domain.Diver?> getDefaultDiver() async => null;

  @override
  Future<String?> getActiveDiverIdFromSettings() async => null;

  @override
  Future<void> setActiveDiverIdInSettings(String? diverId) async {}
}

class _FakeDiverSettingsRepository extends DiverSettingsRepository {
  @override
  Future<AppSettings> getOrCreateSettingsForDiver(
    String diverId, {
    AppSettings? defaultSettings,
  }) async {
    return const AppSettings(notificationsEnabled: false);
  }

  @override
  Future<void> updateSettingsForDiver(
    String diverId,
    AppSettings settings,
  ) async {}
}

class _TestSettingsNotifier extends SettingsNotifier {
  _TestSettingsNotifier(Ref ref) : super(_FakeDiverSettingsRepository(), ref);
}

class _SettingsNotifier extends _TestSettingsNotifier {
  _SettingsNotifier(super.ref);
}

class _FakeDiveRepository extends DiveRepository {
  _FakeDiveRepository({
    required this.currentDive,
    this.previousDive,
    this.surfaceInterval,
    this.sameDayDives = const [],
  });

  final Dive currentDive;
  final Dive? previousDive;
  final Duration? surfaceInterval;
  final List<Dive> sameDayDives;

  @override
  Future<Dive?> getDiveById(String id) async {
    if (id == currentDive.id) return currentDive;
    if (id == previousDive?.id) return previousDive;
    return null;
  }

  @override
  Future<Dive?> getPreviousDive(String diveId) async {
    if (diveId == currentDive.id) return previousDive;
    return null;
  }

  @override
  Future<Duration?> getSurfaceInterval(String diveId) async {
    if (diveId == currentDive.id) return surfaceInterval;
    return null;
  }

  @override
  Future<List<GasSwitchWithTank>> getGasSwitchesForDive(String diveId) async {
    return const [];
  }

  @override
  Future<List<Dive>> getDivesInRange(
    DateTime start,
    DateTime end, {
    String? diverId,
  }) async {
    return sameDayDives;
  }
}

class _FakeTankPressureRepository extends TankPressureRepository {
  @override
  Future<Map<String, List<TankPressurePoint>>> getTankPressuresForDive(
    String diveId,
  ) async {
    return const {};
  }
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
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  group('buildProfileGasSegments', () {
    test('returns primary tank gas when there are no switches', () {
      final dive = Dive(
        id: 'dive-1',
        dateTime: DateTime.utc(2026, 3, 31),
        tanks: const [DiveTank(id: 'tank-air', gasMix: GasMix(o2: 21, he: 0))],
      );

      final segments = buildProfileGasSegments(dive, const []);

      expect(segments, hasLength(1));
      expect(segments.single.startTimestamp, equals(0));
      expect(segments.single.fN2, closeTo(airN2Fraction, 0.000001));
      expect(segments.single.fHe, closeTo(0.0, 0.000001));
    });

    test('adds sorted switch segments using switch tank gas mixes', () {
      final dive = Dive(
        id: 'dive-2',
        dateTime: DateTime.utc(2026, 3, 31),
        tanks: const [
          DiveTank(id: 'tank-air', gasMix: GasMix(o2: 21, he: 0)),
          DiveTank(id: 'tank-ean32', gasMix: GasMix(o2: 32, he: 0)),
          DiveTank(id: 'tank-tx50', gasMix: GasMix(o2: 50, he: 0)),
        ],
      );

      final switches = [
        GasSwitchWithTank(
          gasSwitch: GasSwitch(
            id: 'switch-2',
            diveId: dive.id,
            timestamp: 1200,
            tankId: 'tank-tx50',
            createdAt: DateTime.utc(2026, 3, 31),
          ),
          tankName: '50%',
          gasMix: 'EAN50',
          o2Fraction: 0.50,
        ),
        GasSwitchWithTank(
          gasSwitch: GasSwitch(
            id: 'switch-1',
            diveId: dive.id,
            timestamp: 600,
            tankId: 'tank-ean32',
            createdAt: DateTime.utc(2026, 3, 31),
          ),
          tankName: '32%',
          gasMix: 'EAN32',
          o2Fraction: 0.32,
        ),
      ];

      final segments = buildProfileGasSegments(dive, switches);

      expect(segments, hasLength(3));
      expect(segments[0].startTimestamp, equals(0));
      expect(segments[0].fN2, closeTo(airN2Fraction, 0.000001));
      expect(segments[1].startTimestamp, equals(600));
      expect(segments[1].fN2, closeTo(0.68, 0.000001));
      expect(segments[2].startTimestamp, equals(1200));
      expect(segments[2].fN2, closeTo(0.5, 0.000001));
    });

    test(
      'resolveProfileGasSegments returns warning for unresolved gas switch',
      () {
        final dive = Dive(
          id: 'dive-3',
          dateTime: DateTime.utc(2026, 3, 31),
          tanks: const [
            DiveTank(id: 'tank-air', gasMix: GasMix(o2: 21, he: 0)),
          ],
        );

        final resolution = resolveProfileGasSegments(dive, [
          GasSwitchWithTank(
            gasSwitch: GasSwitch(
              id: 'switch-bad',
              diveId: dive.id,
              timestamp: 1122,
              tankId: 'missing-tank',
              createdAt: DateTime.utc(2026, 3, 31),
            ),
            tankName: 'Unknown Tank',
            gasMix: 'Unknown',
            o2Fraction: 0,
            isResolved: false,
          ),
        ]);

        expect(resolution.isValid, isFalse);
        expect(resolution.gasSegments, isNull);
        expect(
          resolution.warningMessage,
          equals('Calculated deco unavailable: unknown gas switch at 18:42'),
        );
      },
    );

    test('treats an existing default-air tank as a valid switch target', () {
      final dive = Dive(
        id: 'dive-air-default',
        dateTime: DateTime.utc(2026, 3, 31),
        tanks: const [
          DiveTank(id: 'tank-1', gasMix: GasMix()),
          DiveTank(id: 'tank-2', gasMix: GasMix()),
        ],
      );

      final resolution = resolveProfileGasSegments(dive, [
        GasSwitchWithTank(
          gasSwitch: GasSwitch(
            id: 'switch-air',
            diveId: dive.id,
            timestamp: 300,
            tankId: 'tank-2',
            createdAt: DateTime.utc(2026, 3, 31),
          ),
          tankName: 'Backgas 2',
          gasMix: 'Air',
          o2Fraction: 0.21,
          heFraction: 0.0,
          isResolved: true,
        ),
      ]);

      expect(resolution.isValid, isTrue);
      expect(resolution.warningMessage, isNull);
      expect(resolution.gasSegments, isNotNull);
      expect(resolution.gasSegments![1].fN2, closeTo(airN2Fraction, 0.000001));
    });
  });

  group('calculated deco invalidation', () {
    test('inherits invalid warning from previous dive analysis', () {
      final analysis = ProfileAnalysis.empty().copyWith(
        calculatedDecoWarningMessage:
            'Calculated deco unavailable: unknown gas switch at 18:42',
      );

      expect(
        inheritedDecoInvalidityWarning(analysis),
        equals(
          'Calculated deco unavailable: previous dive has invalid gas-switch data',
        ),
      );
    });

    test('invalidateCalculatedDeco clears Buhlmann-derived outputs only', () {
      final service = ProfileAnalysisService(gfLow: 0.30, gfHigh: 0.70);
      final profile = _generateSquareProfile(
        maxDepth: 30.0,
        bottomSeconds: 600,
      );
      final depths = profile.map((p) => p.depth).toList();
      final timestamps = profile.map((p) => p.timestamp).toList();

      final analysis = service.analyze(
        diveId: 'invalidate-calculated-deco',
        depths: depths,
        timestamps: timestamps,
      );

      final invalidated = invalidateCalculatedDeco(
        analysis,
        'Calculated deco unavailable: unknown gas switch at 18:42',
      );

      expect(invalidated.ceilingCurve, isEmpty);
      expect(invalidated.ndlCurve, isEmpty);
      expect(invalidated.decoStatuses, isEmpty);
      expect(invalidated.gfCurve, isEmpty);
      expect(invalidated.surfaceGfCurve, isEmpty);
      expect(invalidated.ttsCurve, isEmpty);
      expect(invalidated.ppO2Curve, equals(analysis.ppO2Curve));
      expect(invalidated.cnsCurve, equals(analysis.cnsCurve));
      expect(invalidated.otuCurve, equals(analysis.otuCurve));
      expect(
        invalidated.calculatedDecoWarningMessage,
        equals('Calculated deco unavailable: unknown gas switch at 18:42'),
      );
    });
  });

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

    test('forward-fills computer NDL after first reported value', () {
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

      // Points before the first computer NDL sample remain unpopulated
      expect(result.ndlCurve[50], equals(0));

      expect(sourceInfo.ndlActual, MetricDataSource.computer);
    });

    test('forward-fills computer ceiling after first reported value', () {
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

      // Points before the first computer ceiling sample remain unpopulated
      expect(result.ceilingCurve[50], closeTo(0.0, 0.001));

      expect(sourceInfo.ceilingActual, MetricDataSource.computer);
    });

    test('forward-fills computer TTS after first reported value', () {
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

      // Points before the first computer TTS sample remain unpopulated
      expect(result.ttsCurve![50], equals(0));

      expect(sourceInfo.ttsActual, MetricDataSource.computer);
    });

    test('forward-fills computer CNS after first reported value', () {
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

      // Points before the first computer CNS sample remain unpopulated
      expect(result.cnsCurve![50], closeTo(0.0, 0.001));

      expect(sourceInfo.cnsActual, MetricDataSource.computer);
    });

    test('forward-fills sparse computer data between reported points', () {
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

      // Odd indices inherit the most recent prior computer value
      expect(result.ndlCurve[101], equals(777));

      expect(sourceInfo.ndlActual, MetricDataSource.computer);
    });

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

    test('source=computer without data leaves metric blank', () {
      final (result, sourceInfo) = overlayComputerDecoData(
        baseAnalysis,
        baseProfile,
        ndlSource: MetricDataSource.computer,
      );
      expect(result.ndlCurve, isEmpty);
      expect(sourceInfo.ndlActual, MetricDataSource.computer);
    });

    test(
      'computer overlays can repopulate suppressed deco metrics on invalid analysis',
      () {
        final invalidAnalysis = invalidateCalculatedDeco(
          baseAnalysis,
          'Calculated deco unavailable: unknown gas switch at 18:42',
        );

        final profileWithComputerDeco = <DiveProfilePoint>[];
        for (int i = 0; i < baseProfile.length; i++) {
          if (i >= 100 && i < 200) {
            profileWithComputerDeco.add(
              baseProfile[i].copyWith(ndl: 500, ceiling: 4.5, tts: 90),
            );
          } else {
            profileWithComputerDeco.add(baseProfile[i]);
          }
        }

        final (result, sourceInfo) = overlayComputerDecoData(
          invalidAnalysis,
          profileWithComputerDeco,
          ndlSource: MetricDataSource.computer,
          ceilingSource: MetricDataSource.computer,
          ttsSource: MetricDataSource.computer,
        );

        expect(result.ndlCurve[150], equals(500));
        expect(result.ceilingCurve[150], closeTo(4.5, 0.001));
        expect(result.ttsCurve![150], equals(90));
        expect(
          result.calculatedDecoWarningMessage,
          equals('Calculated deco unavailable: unknown gas switch at 18:42'),
        );
        expect(sourceInfo.ndlActual, MetricDataSource.computer);
        expect(sourceInfo.ceilingActual, MetricDataSource.computer);
        expect(sourceInfo.ttsActual, MetricDataSource.computer);
      },
    );
  });

  group('profileAnalysisProvider inherited invalidity', () {
    test(
      'suppresses calculated deco when previous dive analysis is invalid',
      () async {
        final currentDive = Dive(
          id: 'current-dive',
          dateTime: DateTime.utc(2026, 3, 31, 12),
          entryTime: DateTime.utc(2026, 3, 31, 12),
          profile: _generateSquareProfile(maxDepth: 24.0, bottomSeconds: 300),
          tanks: const [
            DiveTank(id: 'tank-air', gasMix: GasMix(o2: 21, he: 0)),
          ],
        );
        final previousDive = Dive(
          id: 'previous-dive',
          dateTime: DateTime.utc(2026, 3, 31, 10),
          entryTime: DateTime.utc(2026, 3, 31, 10),
          tanks: const [
            DiveTank(id: 'tank-air', gasMix: GasMix(o2: 21, he: 0)),
          ],
        );

        final repository = _FakeDiveRepository(
          currentDive: currentDive,
          previousDive: previousDive,
          surfaceInterval: const Duration(hours: 2),
          sameDayDives: [currentDive],
        );

        final previousAnalysis = ProfileAnalysis.empty().copyWith(
          calculatedDecoWarningMessage:
              'Calculated deco unavailable: unknown gas switch at 18:42',
        );

        final container = ProviderContainer(
          overrides: [
            useBackgroundProfileAnalysisProvider.overrideWith((ref) => false),
            sharedPreferencesProvider.overrideWithValue(_prefs),
            diverRepositoryProvider.overrideWithValue(_FakeDiverRepository()),
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier(ref)),
            diveRepositoryProvider.overrideWithValue(repository),
            tankPressureRepositoryProvider.overrideWithValue(
              _FakeTankPressureRepository(),
            ),
            diveProvider(currentDive.id).overrideWith((ref) => currentDive),
            profileAnalysisProvider(
              previousDive.id,
            ).overrideWith((ref) => previousAnalysis),
            diveComputerEventsProvider(
              currentDive.id,
            ).overrideWith((ref) => <ProfileEvent>[]),
          ],
        );
        addTearDown(container.dispose);

        final analysis = await container.read(
          profileAnalysisProvider(currentDive.id).future,
        );

        expect(analysis, isNotNull);
        expect(analysis!.ceilingCurve, isEmpty);
        expect(analysis.ndlCurve, isEmpty);
        expect(analysis.decoStatuses, isEmpty);
        expect(analysis.gfCurve, isEmpty);
        expect(analysis.surfaceGfCurve, isEmpty);
        expect(analysis.ttsCurve, isEmpty);
        expect(
          analysis.calculatedDecoWarningMessage,
          equals(
            'Calculated deco unavailable: previous dive has invalid gas-switch data',
          ),
        );
      },
    );

    test(
      'allows computer overlays to repopulate invalid inherited deco metrics',
      () async {
        final profile = _generateSquareProfile(
          maxDepth: 24.0,
          bottomSeconds: 300,
        );
        final profileWithComputerDeco = List<DiveProfilePoint>.generate(
          profile.length,
          (i) => i >= 90 && i < 140
              ? profile[i].copyWith(ndl: 420, ceiling: 3.0, tts: 75)
              : profile[i],
        );

        final currentDive = Dive(
          id: 'current-dive-computer',
          dateTime: DateTime.utc(2026, 3, 31, 12),
          entryTime: DateTime.utc(2026, 3, 31, 12),
          profile: profileWithComputerDeco,
          tanks: const [
            DiveTank(id: 'tank-air', gasMix: GasMix(o2: 21, he: 0)),
          ],
        );
        final previousDive = Dive(
          id: 'previous-dive-computer',
          dateTime: DateTime.utc(2026, 3, 31, 10),
          entryTime: DateTime.utc(2026, 3, 31, 10),
          tanks: const [
            DiveTank(id: 'tank-air', gasMix: GasMix(o2: 21, he: 0)),
          ],
        );

        final repository = _FakeDiveRepository(
          currentDive: currentDive,
          previousDive: previousDive,
          surfaceInterval: const Duration(hours: 2),
          sameDayDives: [currentDive],
        );

        final previousAnalysis = ProfileAnalysis.empty().copyWith(
          calculatedDecoWarningMessage:
              'Calculated deco unavailable: unknown gas switch at 18:42',
        );

        final container = ProviderContainer(
          overrides: [
            useBackgroundProfileAnalysisProvider.overrideWith((ref) => false),
            sharedPreferencesProvider.overrideWithValue(_prefs),
            diverRepositoryProvider.overrideWithValue(_FakeDiverRepository()),
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier(ref)),
            diveRepositoryProvider.overrideWithValue(repository),
            tankPressureRepositoryProvider.overrideWithValue(
              _FakeTankPressureRepository(),
            ),
            diveProvider(currentDive.id).overrideWith((ref) => currentDive),
            profileAnalysisProvider(
              previousDive.id,
            ).overrideWith((ref) => previousAnalysis),
            diveComputerEventsProvider(
              currentDive.id,
            ).overrideWith((ref) => <ProfileEvent>[]),
          ],
        );
        addTearDown(container.dispose);

        final legendNotifier = container.read(profileLegendProvider.notifier);
        legendNotifier.setNdlSource(MetricDataSource.computer);
        legendNotifier.setCeilingSource(MetricDataSource.computer);
        legendNotifier.setTtsSource(MetricDataSource.computer);

        final analysis = await container.read(
          profileAnalysisProvider(currentDive.id).future,
        );

        expect(analysis, isNotNull);
        expect(analysis!.ndlCurve[100], equals(420));
        expect(analysis.ceilingCurve[100], closeTo(3.0, 0.001));
        expect(analysis.ttsCurve![100], equals(75));
        expect(
          analysis.calculatedDecoWarningMessage,
          equals(
            'Calculated deco unavailable: previous dive has invalid gas-switch data',
          ),
        );
      },
    );
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
          sharedPreferencesProvider.overrideWithValue(_prefs),
          diverRepositoryProvider.overrideWithValue(_FakeDiverRepository()),
          settingsProvider.overrideWith((ref) => _SettingsNotifier(ref)),
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
          sharedPreferencesProvider.overrideWithValue(_prefs),
          diverRepositoryProvider.overrideWithValue(_FakeDiverRepository()),
          settingsProvider.overrideWith((ref) => _SettingsNotifier(ref)),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(diveProfileAnalysisProvider(dive));
      expect(result, isNull);
    });
  });
}
