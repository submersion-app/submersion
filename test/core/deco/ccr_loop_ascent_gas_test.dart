import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ccr_loop_ascent_gas.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';

CcrLoopAscentGas _loop({double switchDepth = 10.0}) => CcrLoopAscentGas(
  environment: DiveEnvironment.standard,
  setpointLow: 0.7,
  setpointHigh: 1.3,
  switchDepth: switchDepth,
  diluentFO2: 0.18,
  diluentFHe: 0.45,
);

void main() {
  test('effective fractions at 40 m match the python vector', () {
    // python3 (Task 1): inert = (5.0-0.0627) - 1.3, split 37:45,
    // divided by alveolar pressure.
    final gas = _loop().gasForDepth(40.0);
    expect(gas.fN2, closeTo(0.3324126003498506, 1e-9));
    expect(gas.fHe, closeTo(0.40428559502008854, 1e-9));
  });

  test('shallow clamp: high setpoint above alveolar pressure => pure O2', () {
    // With the HIGH setpoint in force at 3 m (switchDepth 0), SP 1.3 exceeds
    // the alveolar pressure (1.2373 bar) and the loop clamps to pure O2.
    final gas = _loop(switchDepth: 0.0).gasForDepth(3.0);
    expect(gas.fN2, 0.0);
    expect(gas.fHe, 0.0);

    // On the LOW setpoint (0.7 bar) at 3 m the loop still carries inert gas.
    final lowSp = _loop().gasForDepth(3.0);
    expect(lowSp.fN2, greaterThan(0));
  });

  test('setpointAt honors the switch depth on both sides', () {
    final loop = _loop();
    expect(loop.setpointAt(40.0), 1.3);
    expect(loop.setpointAt(10.0), 0.7); // at the boundary: low
    expect(loop.setpointAt(3.0), 0.7);
  });

  test('switchDepthsBetween reports the setpoint switch when crossed', () {
    final loop = _loop();
    expect(loop.switchDepthsBetween(21.0, 3.0), [10.0]);
    expect(loop.switchDepthsBetween(9.0, 3.0), isEmpty);
    expect(loop.switchDepthsBetween(40.0, 12.0), isEmpty);
  });

  test('no break gas: air breaks never apply to the loop', () {
    expect(_loop().breakGasForDepth(6.0), isNull);
  });

  test('effective fractions reproduce constant-ppO2 loading exactly', () {
    // The design's load-bearing equivalence: loading a constant-depth
    // segment on the effective fractions equals loading it via the
    // ClosedCircuit breathing config.
    final viaFractions = BuhlmannAlgorithm(gfLow: 0.5, gfHigh: 0.8);
    final viaBreathing = BuhlmannAlgorithm(gfLow: 0.5, gfHigh: 0.8);
    final gas = _loop().gasForDepth(40.0);

    viaFractions.calculateSegment(
      depthMeters: 40,
      durationSeconds: 20 * 60,
      fN2: gas.fN2,
      fHe: gas.fHe,
    );
    viaBreathing.calculateSegment(
      depthMeters: 40,
      durationSeconds: 20 * 60,
      breathing: const ClosedCircuit(
        setpoint: 1.3,
        diluentFO2: 0.18,
        diluentFHe: 0.45,
      ),
    );

    for (var i = 0; i < 16; i++) {
      expect(
        viaFractions.compartments[i].currentPN2,
        closeTo(viaBreathing.compartments[i].currentPN2, 1e-12),
      );
      expect(
        viaFractions.compartments[i].currentPHe,
        closeTo(viaBreathing.compartments[i].currentPHe, 1e-12),
      );
    }
  });
}
