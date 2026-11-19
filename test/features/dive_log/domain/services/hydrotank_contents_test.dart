import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/hydrotank_contents.dart';

/// Issue #4664: the Hydrotank's estimated water and gas, assuming no water at
/// the start. The gas space is (start / now pressure) x gas remaining of the
/// tank; water is the rest.
void main() {
  const psi = 0.0689475729;

  test('dive 1636 ends with a little water', () {
    final c = hydrotankContents(
      startBar: 3488 * psi,
      nowBar: 1302 * psi,
      gasRemainingPercent: 36,
    )!;
    expect(c.water, closeTo(0.0356, 0.001));
    // Gas left is the gas space shaded by gas remaining, from the bottom.
    expect(c.gasLeft, closeTo(c.water + (1 - c.water) * 0.36, 1e-9));
  });

  test('a pump-in raises the water', () {
    final c = hydrotankContents(
      startBar: 3428 * psi,
      nowBar: 2532 * psi,
      gasRemainingPercent: 41,
    )!;
    expect(c.water, closeTo(0.445, 0.001));
  });

  test('at the start the tank is all gas', () {
    final c = hydrotankContents(
      startBar: 240,
      nowBar: 240,
      gasRemainingPercent: 100,
    )!;
    expect(c.water, 0.0);
    expect(c.gasLeft, 1.0);
  });

  test('water clamps at 0 when the estimate goes negative', () {
    // Gas remaining rounds up while the pressure has dropped further: the
    // gas space works out above the whole tank.
    final c = hydrotankContents(
      startBar: 240,
      nowBar: 100,
      gasRemainingPercent: 50,
    )!;
    expect(c.water, 0.0);
    expect(c.gasLeft, closeTo(0.5, 1e-9));
  });

  test('water clamps at the whole tank', () {
    final c = hydrotankContents(
      startBar: 200,
      nowBar: 250,
      gasRemainingPercent: 0,
    )!;
    expect(c.water, 1.0);
    expect(c.gasLeft, 1.0);
  });

  test('no estimate without a positive pressure', () {
    expect(
      hydrotankContents(startBar: 0, nowBar: 100, gasRemainingPercent: 50),
      isNull,
    );
    expect(
      hydrotankContents(startBar: 200, nowBar: 0, gasRemainingPercent: 50),
      isNull,
    );
  });

  group('gasRemainingAt', () {
    const profile = [
      DiveProfilePoint(timestamp: 0, depth: 0.0, aveloGasRemaining: 100),
      DiveProfilePoint(timestamp: 10, depth: 5.0, aveloGasRemaining: 97),
      DiveProfilePoint(timestamp: 20, depth: 9.0),
      DiveProfilePoint(timestamp: 30, depth: 6.0, aveloGasRemaining: 80),
      DiveProfilePoint(timestamp: 40, depth: 0.0, aveloGasRemaining: 79),
    ];

    test('without a time, the last underwater value', () {
      expect(gasRemainingAt(profile, null), 80);
    });

    test('at a time, the last value logged at or before it', () {
      expect(gasRemainingAt(profile, 25), 97);
      expect(gasRemainingAt(profile, 30), 80);
      expect(gasRemainingAt(profile, 45), 79);
    });

    test('null before the first value, or on a dive without any', () {
      expect(gasRemainingAt(profile, -5), isNull);
      expect(
        gasRemainingAt(const [
          DiveProfilePoint(timestamp: 0, depth: 5.0),
        ], null),
        isNull,
      );
    });
  });
}
