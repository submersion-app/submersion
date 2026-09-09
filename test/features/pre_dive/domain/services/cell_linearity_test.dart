import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/pre_dive/domain/services/cell_linearity.dart';

void main() {
  test('air oxygen fraction is 0.209', () {
    expect(CellLinearity.airOxygenFraction, 0.209);
  });

  test('expected O2 millivolts is the air reading over 0.209', () {
    // The issue's own worked example: 10.1 mV in air.
    final expected = CellLinearity.expectedO2Millivolts(10.1)!;
    expect(expected, closeTo(48.325, 0.001));
  });

  test('linearity is measured over expected, as a percentage', () {
    // 48.0 mV measured against an expected 48.325 mV.
    final percent = CellLinearity.percent(
      airMillivolts: 10.1,
      o2Millivolts: 48.0,
    )!;
    expect(percent, closeTo(99.33, 0.01));
    expect(percent.round(), 99);
  });

  test('a cell that reaches exactly its expected output reads 100 percent', () {
    final percent = CellLinearity.percent(
      airMillivolts: 10.0,
      o2Millivolts: 10.0 / 0.209,
    )!;
    expect(percent, closeTo(100.0, 0.000001));
  });

  test('a current limited cell reads well below 100 percent', () {
    // 10.1 mV in air expects 48.3; a cell topping out at 40 mV is sick.
    final percent = CellLinearity.percent(
      airMillivolts: 10.1,
      o2Millivolts: 40.0,
    )!;
    expect(percent, lessThan(85));
  });

  test('the percentage is computed from the exact expected value', () {
    // Rounding expected to 1 dp first would give 48.0 / 48.3 = 99.379,
    // which rounds to 99 either way, but the exact path must not agree by
    // accident: assert the precise unrounded figure.
    expect(
      CellLinearity.percent(airMillivolts: 10.1, o2Millivolts: 48.0),
      closeTo(48.0 / (10.1 / 0.209) * 100, 1e-9),
    );
  });

  group('missing and unusable inputs yield null, never an error', () {
    test('null air reading', () {
      expect(CellLinearity.expectedO2Millivolts(null), isNull);
      expect(
        CellLinearity.percent(airMillivolts: null, o2Millivolts: 48.0),
        isNull,
      );
    });

    test('zero air reading does not divide into infinity', () {
      expect(CellLinearity.expectedO2Millivolts(0), isNull);
      expect(
        CellLinearity.percent(airMillivolts: 0, o2Millivolts: 48.0),
        isNull,
      );
    });

    test('negative air reading', () {
      expect(CellLinearity.expectedO2Millivolts(-1.5), isNull);
      expect(
        CellLinearity.percent(airMillivolts: -1.5, o2Millivolts: 48.0),
        isNull,
      );
    });

    test('null O2 reading', () {
      expect(
        CellLinearity.percent(airMillivolts: 10.1, o2Millivolts: null),
        isNull,
      );
    });
  });
}
