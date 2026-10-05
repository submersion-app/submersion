import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';

/// Issue #577: a CCR dive that bails out mixes loop and open-circuit
/// segments. The simulated ascent from a loop sample stays on the loop; from
/// a bailout sample it uses the carried open-circuit gases.
void main() {
  final timestamps = [for (var t = 0; t <= 32 * 60; t += 60) t];
  final depths = [for (final t in timestamps) t < 120 ? 45.0 * t / 120 : 45.0];
  const loop = ProfileGasSegment(
    startTimestamp: 0,
    fN2: airN2Fraction,
    setpoint: 1.3,
  );
  OptimalOcAscentGas airOnly() => OptimalOcAscentGas(
    gases: [const AvailableGas(fN2: airN2Fraction, fHe: 0.0, maxPpO2Mod: 66.0)],
    maxPpO2: 1.6,
  );

  int finalTts(List<ProfileGasSegment> segments, AscentGasPlan? plan) =>
      BuhlmannAlgorithm(gfLow: 0.3, gfHigh: 0.7)
          .processProfileWithGasSegments(
            depths: depths,
            timestamps: timestamps,
            gasSegments: segments,
            ascentGasPlan: plan,
          )
          .last
          .ttsSeconds;

  test('a loop sample ascends on the loop even with an OC plan supplied', () {
    expect(finalTts(const [loop], airOnly()), finalTts(const [loop], null));
  });

  test('a bailout sample ascends on the supplied OC plan', () {
    const segments = [
      loop,
      ProfileGasSegment(startTimestamp: 20 * 60, fN2: airN2Fraction),
    ];
    final withDecoGas = OptimalOcAscentGas(
      gases: [
        const AvailableGas(fN2: airN2Fraction, fHe: 0.0, maxPpO2Mod: 66.0),
        const AvailableGas(fN2: 0.5, fHe: 0.0, maxPpO2Mod: 22.0),
      ],
      maxPpO2: 1.6,
    );
    expect(finalTts(segments, withDecoGas), lessThan(finalTts(segments, null)));
  });
}
