import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

/// Issue #577: after a bailout the O2 cells keep reading a loop the diver no
/// longer breathes. ppO2, CNS/OTU and the gas overlays follow the bailout gas.
void main() {
  // CCR at 1.3 over air diluent at 21 m; bailout to EAN50 at 20 min.
  final timestamps = [for (var t = 0; t <= 40 * 60; t += 60) t];
  final depths = [for (final t in timestamps) t < 120 ? 21.0 * t / 120 : 21.0];
  final loopCurve = List<double>.filled(timestamps.length, 1.3);
  const bailoutAt = 20 * 60;
  final bailoutIndex = timestamps.indexOf(bailoutAt);
  const ambient = 3.1; // 21 m on the service's 1 + d/10 basis
  final service = ProfileAnalysisService(gfLow: 0.3, gfHigh: 0.7);

  const loop = ProfileGasSegment(
    startTimestamp: 0,
    fN2: airN2Fraction,
    setpoint: 1.3,
  );
  const bailout = ProfileGasSegment(startTimestamp: bailoutAt, fN2: 0.5);

  ProfileAnalysis analyze(List<ProfileGasSegment> segments) => service.analyze(
    diveId: 'ccr-bailout',
    depths: depths,
    timestamps: timestamps,
    o2Fraction: 1.0 - airN2Fraction,
    diveMode: DiveMode.ccr,
    setpointHigh: 1.3,
    gasSegments: segments,
    rebreatherPpO2Curve: loopCurve,
  );

  test('ppO2 follows the loop before the bailout and the gas after', () {
    final analysis = analyze(const [loop, bailout]);
    expect(analysis.ppO2Curve[bailoutIndex - 1], closeTo(1.3, 1e-9));
    expect(analysis.ppO2Curve[bailoutIndex], closeTo(ambient * 0.5, 1e-9));
    expect(analysis.ppO2Curve.last, closeTo(ambient * 0.5, 1e-9));
  });

  test('CNS and OTU count the bailout gas', () {
    final loopOnly = analyze(const [loop]);
    final bailedOut = analyze(const [loop, bailout]);
    expect(
      bailedOut.o2Exposure.cnsEnd,
      greaterThan(loopOnly.o2Exposure.cnsEnd),
    );
    expect(bailedOut.o2Exposure.otu, greaterThan(loopOnly.o2Exposure.otu));
    expect(bailedOut.o2Exposure.maxPpO2, closeTo(ambient * 0.5, 1e-6));
  });

  test('ppN2 and the MOD line describe the bailout gas', () {
    final analysis = analyze(const [loop, bailout]);
    // On the loop over air diluent all inert gas is N2: ambient less ppO2.
    expect(analysis.ppN2Curve![bailoutIndex - 1], closeTo(ambient - 1.3, 1e-9));
    expect(analysis.ppN2Curve![bailoutIndex], closeTo(ambient * 0.5, 1e-9));
    expect(
      analysis.modCurve![bailoutIndex - 1],
      closeTo(
        O2ToxicityCalculator.calculateMod(1.0 - airN2Fraction, maxPpO2: 1.4),
        1e-9,
      ),
    );
    expect(
      analysis.modCurve![bailoutIndex],
      closeTo(O2ToxicityCalculator.calculateMod(0.5, maxPpO2: 1.4), 1e-9),
    );
  });

  test('a loop-only schedule keeps the loop ppO2 throughout', () {
    final analysis = analyze(const [loop]);
    expect(analysis.ppO2Curve.skip(1), everyElement(closeTo(1.3, 1e-9)));
  });
}
