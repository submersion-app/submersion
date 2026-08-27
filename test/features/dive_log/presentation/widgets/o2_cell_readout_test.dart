import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/o2_cell_readout.dart';

void main() {
  group('formatO2CellReadout', () {
    test('shows both readings when the calibration is trustworthy', () {
      expect(formatO2CellReadout(bar: 0.98, millivolt: 58), '0.98 bar (58 mV)');
    });

    test('shows millivolts alone when there is no usable ppO2', () {
      // Issue #810: a factory-default calibration means the partial pressure is
      // withheld, but the cell still reported a measurement.
      expect(formatO2CellReadout(bar: null, millivolt: 58), '58 mV');
    });

    test('shows bar alone when the computer reports no millivolts', () {
      expect(formatO2CellReadout(bar: 0.98, millivolt: null), '0.98 bar');
    });

    test('returns null when the cell reported nothing at this sample', () {
      expect(formatO2CellReadout(bar: null, millivolt: null), isNull);
    });

    test('keeps two decimals on bar and no decimals on millivolts', () {
      expect(formatO2CellReadout(bar: 1.0, millivolt: 49), '1.00 bar (49 mV)');
      expect(formatO2CellReadout(bar: 0.666, millivolt: 7), '0.67 bar (7 mV)');
    });

    test('treats a zero millivolt reading as a value, not as absent', () {
      // The native layer already maps "not reported" to its own sentinel, so a
      // zero that reaches here is a real (dead-cell) reading.
      expect(formatO2CellReadout(bar: null, millivolt: 0), '0 mV');
    });

    test('uses the caller-supplied unit strings when provided', () {
      expect(
        formatO2CellReadout(
          bar: 0.98,
          millivolt: 58,
          barUnit: 'Bar',
          millivoltUnit: 'MilliVolt',
        ),
        '0.98 Bar (58 MilliVolt)',
      );
    });
  });

  group('o2CellCount', () {
    test('is the wider of the two curve sets', () {
      expect(o2CellCount(barCurves: null, mvCurves: null), 0);
      expect(o2CellCount(barCurves: [[], []], mvCurves: [[], [], []]), 3);
      expect(o2CellCount(barCurves: [[], [], []], mvCurves: [[]]), 3);
      expect(o2CellCount(barCurves: null, mvCurves: [[], []]), 2);
    });
  });

  group('valueAtSample', () {
    test('reads the cell/sample cell when present', () {
      expect(
        valueAtSample<int>(
          curves: [
            [58, 59],
          ],
          cell: 0,
          sampleIndex: 1,
        ),
        59,
      );
    });

    test('returns null past the end of the curves or the samples', () {
      expect(valueAtSample<int>(curves: null, cell: 0, sampleIndex: 0), isNull);
      expect(
        valueAtSample<int>(
          curves: [
            [58],
          ],
          cell: 2,
          sampleIndex: 0,
        ),
        isNull,
      );
      expect(
        valueAtSample<int>(
          curves: [
            [58],
          ],
          cell: 0,
          sampleIndex: 5,
        ),
        isNull,
      );
    });
  });
}
