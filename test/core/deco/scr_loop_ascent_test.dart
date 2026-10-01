import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';

/// A semi-closed loop's measured ppO2 is not a setpoint: the loop does not
/// hold it on the way up. Tissues load on the measured value along the
/// recorded profile, but the simulated ascent (TTS, deco stops) must not keep
/// the deep ppO2 to the surface, or it under-states the obligation.
void main() {
  // 50 m for 30 minutes on a 32% supply with a measured 1.2 bar loop.
  final timestamps = [for (var t = 0; t <= 32 * 60; t += 60) t];
  final depths = [for (final t in timestamps) t < 120 ? 50.0 * t / 120 : 50.0];

  List<int> ttsCurve({required bool holdsSetpoint}) =>
      BuhlmannAlgorithm(gfLow: 0.3, gfHigh: 0.7)
          .processProfileWithGasSegments(
            depths: depths,
            timestamps: timestamps,
            gasSegments: [
              ProfileGasSegment(
                startTimestamp: 0,
                fN2: 0.68,
                setpoint: 1.2,
                loopHoldsSetpoint: holdsSetpoint,
              ),
            ],
          )
          .map((s) => s.ttsSeconds)
          .toList();

  test('a semi-closed ascent does not hold the measured ppO2', () {
    final heldLoop = ttsCurve(holdsSetpoint: true);
    final scrLoop = ttsCurve(holdsSetpoint: false);

    expect(heldLoop.last, greaterThan(0), reason: 'the dive is in deco');
    expect(scrLoop.last, greaterThan(heldLoop.last));
  });

  test('loading along the recorded profile is the same either way', () {
    List<double> tensions({required bool holdsSetpoint}) => BuhlmannAlgorithm()
        .processProfileWithGasSegments(
          depths: depths,
          timestamps: timestamps,
          gasSegments: [
            ProfileGasSegment(
              startTimestamp: 0,
              fN2: 0.68,
              setpoint: 1.2,
              loopHoldsSetpoint: holdsSetpoint,
            ),
          ],
        )
        .last
        .compartments
        .map((c) => c.totalInertGas)
        .toList();

    expect(tensions(holdsSetpoint: false), tensions(holdsSetpoint: true));
  });

  test('a segment holds its setpoint unless told otherwise', () {
    const segment = ProfileGasSegment(startTimestamp: 0, fN2: 0.79);
    expect(segment.loopHoldsSetpoint, isTrue);
  });
}
