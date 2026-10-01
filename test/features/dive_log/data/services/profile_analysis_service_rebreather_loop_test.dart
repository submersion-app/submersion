import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

/// Issue #2593: a rebreather dive whose loop cannot be modelled (no setpoint,
/// no measured ppO2, no dive-level setpoint) used to be loaded as open circuit
/// on the first cylinder. On an imported CCR dive that cylinder is often the
/// O2 supply or a bailout, so a 270 ft dive showed a >60 min NDL. The service
/// now withholds tissue loading instead of computing it from a guessed gas.
void main() {
  // 82 m (270 ft) for 20 minutes, then a slow ascent.
  final timestamps = [for (var t = 0; t <= 40 * 60; t += 60) t];
  final depths = [
    for (final t in timestamps)
      t <= 120
          ? 82.0 * t / 120
          : t <= 22 * 60
          ? 82.0
          : 82.0 * (40 * 60 - t) / (18 * 60),
  ];
  final service = ProfileAnalysisService(gfLow: 0.3, gfHigh: 0.7);

  for (final mode in [DiveMode.ccr, DiveMode.scr]) {
    group('${mode.name} with no loop gas schedule', () {
      late ProfileAnalysis analysis;
      setUp(() {
        analysis = service.analyze(
          diveId: 'loopless-${mode.name}',
          depths: depths,
          timestamps: timestamps,
          // The first cylinder: the O2 supply on many imported CCR dives.
          o2Fraction: 1.0,
          diveMode: mode,
          setpointHigh: 1.3,
        );
      });

      test('withholds tissue loading, NDL, ceiling and TTS', () {
        expect(analysis.tissueLoadingWithheld, isTrue);
        expect(analysis.decoStatuses, isEmpty);
        expect(analysis.ndlCurve, isEmpty);
        expect(analysis.ceilingCurve, isEmpty);
        expect(analysis.decoStopCurve, isEmpty);
        expect(analysis.hasTtsData, isFalse);
        expect(analysis.hasGfData, isFalse);
      });

      test('withholds inert-gas overlays built on the guessed gas', () {
        expect(analysis.hasPpN2Data, isFalse);
        expect(analysis.hasPpHeData, isFalse);
        expect(analysis.hasDensityData, isFalse);
      });

      test('keeps the profile-derived data', () {
        expect(analysis.maxDepth, 82.0);
        expect(analysis.ascentRates, isNotEmpty);
      });
    });
  }

  test('SCR with a measured loop schedule loads tissues on the loop', () {
    // Supply 32%, measured loop 1.0 bar: inspired inert is what the loop's O2
    // leaves of ambient, not the supply gas's 68% of it.
    const supplyFN2 = 0.68;
    final measured = List<double>.filled(depths.length, 1.0);
    final analysis = service.analyze(
      diveId: 'scr-measured',
      depths: depths,
      timestamps: timestamps,
      o2Fraction: 0.32,
      diveMode: DiveMode.scr,
      gasSegments: const [
        ProfileGasSegment(
          startTimestamp: 0,
          fN2: supplyFN2,
          fHe: 0.0,
          setpoint: 1.0,
        ),
      ],
      rebreatherPpO2Curve: measured,
    );

    expect(analysis.tissueLoadingWithheld, isFalse);
    expect(analysis.decoStatuses, hasLength(depths.length));
    final bottom = analysis.decoStatuses[10];
    final pAlv = bottom.ambientPressureBar - 0.0627;
    expect(bottom.inspiredN2Bar, closeTo(pAlv - 1.0, 1e-6));
    // The loop's ppN2/density overlays follow the same loop model.
    expect(analysis.hasPpN2Data, isTrue);
    expect(
      analysis.ppN2Curve![10],
      closeTo(bottom.ambientPressureBar - 1.0, 0.05),
    );
  });

  test('open circuit is never withheld', () {
    final analysis = service.analyze(
      diveId: 'oc',
      depths: [for (final d in depths) d < 30 ? d : 30.0],
      timestamps: timestamps,
    );

    expect(analysis.tissueLoadingWithheld, isFalse);
    expect(analysis.decoStatuses, isNotEmpty);
  });
}
