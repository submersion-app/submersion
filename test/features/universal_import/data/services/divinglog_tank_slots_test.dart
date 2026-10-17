import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_tank_slots.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

Map<String, dynamic> tank(
  int id, {
  double? startPressure,
  double? endPressure,
}) => {
  'uddfTankId': 'divinglog:$id',
  'startPressure': ?startPressure,
  'endPressure': ?endPressure,
};

DivingLogRawSample sample(int t, int? tankId, double? pressure) =>
    DivingLogRawSample(
      timeSeconds: t,
      depthMeters: 10.0,
      tankId: tankId,
      pressureBar: pressure,
    );

void main() {
  group('DivingLogTankSlots.pressureOwners', () {
    test('keeps a continuous series on its cylinder across a gas switch', () {
      // #3339: the main tank's transmitter keeps reporting after the switch
      // to a stage that has no sensor.
      final owners = DivingLogTankSlots.pressureOwners(
        [
          sample(1655, 0, 106.5),
          sample(1660, 0, 106.6),
          sample(1665, 1, 106.7),
          sample(1670, 1, 106.7),
        ],
        [tank(0, startPressure: 203.67), tank(1, startPressure: 180.0)],
      );
      expect(owners, [0, 0, 0, 0]);
    });

    test('moves the series when the reading jumps to the new cylinder', () {
      final owners = DivingLogTankSlots.pressureOwners(
        [sample(0, 0, 120.0), sample(5, 1, 179.5), sample(10, 1, 179.0)],
        [tank(0, startPressure: 200.0), tank(1, startPressure: 180.0)],
      );
      expect(owners, [0, 1, 1]);
    });

    test('moves the series on a large jump with no start pressure', () {
      final owners = DivingLogTankSlots.pressureOwners(
        [sample(0, 0, 200.0), sample(20, 1, 150.0)],
        [tank(0), tank(1)],
      );
      expect(owners, [0, 1]);
    });

    test('keeps the series on a small step with no start pressure', () {
      final owners = DivingLogTankSlots.pressureOwners(
        [sample(0, 0, 107.0), sample(5, 1, 106.8)],
        [tank(0), tank(1)],
      );
      expect(owners, [0, 0]);
    });

    test('returns to a cylinder whose last reading it matches', () {
      final owners = DivingLogTankSlots.pressureOwners(
        [
          sample(0, 0, 150.0),
          sample(5, 1, 179.0),
          sample(10, 1, 170.0),
          sample(15, 0, 149.8),
        ],
        [tank(0, startPressure: 200.0), tank(1, startPressure: 180.0)],
      );
      expect(owners, [0, 1, 1, 0]);
    });

    test('decides on the first reading after a switch without pressure', () {
      final owners = DivingLogTankSlots.pressureOwners(
        [sample(0, 0, 106.6), sample(5, 1, null), sample(10, 1, 106.5)],
        [tank(0, startPressure: 200.0), tank(1, startPressure: 180.0)],
      );
      expect(owners[2], 0);
    });

    test('an unknown tank id cancels a pending switch', () {
      final owners = DivingLogTankSlots.pressureOwners(
        [sample(0, 0, 120.0), sample(5, 1, null), sample(10, 7, 179.5)],
        [tank(0, startPressure: 200.0), tank(1, startPressure: 180.0)],
      );
      expect(owners[2], 0);
    });

    test('moves the series when the current cylinder has no reading yet', () {
      final owners = DivingLogTankSlots.pressureOwners(
        [sample(0, 0, null), sample(5, 1, 150.0)],
        [tank(0, startPressure: 200.0), tank(1, startPressure: 180.0)],
      );
      expect(owners, [0, 1]);
    });

    test('resolves an out-of-range tank id by source id', () {
      final owners = DivingLogTankSlots.pressureOwners(
        [sample(0, 0, 200.0), sample(5, 5, 150.0)],
        [tank(0), tank(5)],
      );
      expect(owners, [0, 1]);
    });

    test('puts a single series on the cylinder its pressures match', () {
      // A dive that starts on an unsensored travel gas: the back-gas
      // transmitter reports from the first sample, under the travel gas id.
      final owners = DivingLogTankSlots.pressureOwners(
        [sample(0, 1, 200.0), sample(5, 0, 199.6), sample(10, 0, 80.5)],
        [
          tank(0, startPressure: 200.0, endPressure: 80.0),
          tank(1, startPressure: 200.0, endPressure: 190.0),
        ],
      );
      expect(owners, [0, 0, 0]);
    });

    test(
      'puts a single series on the closest of several fitting cylinders',
      () {
        final owners = DivingLogTankSlots.pressureOwners(
          [sample(0, 0, 200.0), sample(5, 1, 199.8), sample(10, 1, 81.0)],
          [
            tank(0, startPressure: 205.0, endPressure: 85.0),
            tank(1, startPressure: 200.0, endPressure: 80.0),
            tank(2, startPressure: 198.0, endPressure: 88.0),
          ],
        );
        expect(owners, [1, 1, 1]);
      },
    );

    test('keeps a single series where no cylinder fits its pressures', () {
      final owners = DivingLogTankSlots.pressureOwners(
        [sample(0, 1, 200.0), sample(5, 0, 199.6), sample(10, 0, 80.5)],
        [tank(0, startPressure: 230.0, endPressure: 50.0), tank(1)],
      );
      expect(owners, [1, 1, 1]);
    });

    test('leaves a series that moved between cylinders alone', () {
      final owners = DivingLogTankSlots.pressureOwners(
        [sample(0, 0, 200.0), sample(5, 1, 180.0), sample(10, 1, 120.0)],
        [
          tank(0, startPressure: 200.0, endPressure: 120.0),
          tank(1, startPressure: 180.0, endPressure: 120.0),
        ],
      );
      expect(owners, [0, 1, 1]);
    });

    test('starts on the first sample cylinder', () {
      final owners = DivingLogTankSlots.pressureOwners(
        [sample(0, 1, 180.0), sample(5, 1, 179.0)],
        [tank(0), tank(1)],
      );
      expect(owners, [1, 1]);
    });

    test('falls back to the first cylinder for an unknown tank id', () {
      final owners = DivingLogTankSlots.pressureOwners(
        [sample(0, null, 200.0), sample(5, 7, 199.0)],
        [tank(0)],
      );
      expect(owners, [0, 0]);
    });
  });
}
