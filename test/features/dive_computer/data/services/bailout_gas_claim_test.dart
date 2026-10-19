import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/data/services/bailout_gas_claim.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/services/ccr_bailout_timeline.dart';

/// Issue #3307: a transmitter the diver (or the registry) made the bailout
/// has no gas of its own, while the computer's gas list gave the same bailout
/// a separate pressureless cylinder. The transmitter claims that cylinder:
/// it takes the mix, the cylinder goes, and the switches follow.
void main() {
  TankData claimer({String? roleSource, bool mixRecorded = false}) => TankData(
    index: 1,
    o2Percent: 100,
    role: 'bailout',
    roleSource: roleSource,
    transmitterSerial: '222222',
    mixRecorded: mixRecorded,
  );
  const diluent = TankData(
    index: 0,
    o2Percent: 10,
    hePercent: 50,
    role: 'diluent',
    transmitterSerial: '111111',
  );
  TankData sensorlessBailout(int index, {double o2 = 18, double he = 45}) =>
      TankData(index: index, o2Percent: o2, hePercent: he, role: 'bailout');

  List<TimelinePressure> series(int from, int to, double start, double rate) =>
      [
        for (var t = from; t <= to; t += 10)
          (t: t, bar: start - rate * (t - from) / 60),
      ];

  test('a registry bailout claims the OC cylinder it was breathed from', () {
    final result = claimBailoutGases(
      tanks: [
        diluent,
        claimer(),
        sensorlessBailout(3),
        sensorlessBailout(4, o2: 50, he: 0),
      ],
      switches: const [
        GasSwitchEvent(timeSeconds: 2400, depth: 40, toTankIndex: 3),
      ],
      pressuresByIndex: {
        1: [...series(0, 2390, 200, 0), ...series(2400, 3000, 200, 6)],
      },
      inWaterEndSeconds: null,
    );
    expect(result.tanks.map((t) => t.index), [0, 1, 4]);
    final tx = result.tanks.firstWhere((t) => t.index == 1);
    expect(tx.o2Percent, 18);
    expect(tx.hePercent, 45);
    expect(tx.mixRecorded, isTrue);
    expect(result.remappedIndices, {3: 1});
  });

  test('without timeline evidence a single sensorless bailout is claimed', () {
    final result = claimBailoutGases(
      tanks: [diluent, claimer(), sensorlessBailout(3)],
      switches: const [],
      pressuresByIndex: const {},
      inWaterEndSeconds: null,
    );
    expect(result.tanks.map((t) => t.index), [0, 1]);
    expect(result.tanks[1].o2Percent, 18);
    expect(result.remappedIndices, {3: 1});
  });

  test('two sensorless bailouts and no evidence claim nothing', () {
    final tanks = [
      diluent,
      claimer(),
      sensorlessBailout(3),
      sensorlessBailout(4, o2: 21, he: 0),
    ];
    final result = claimBailoutGases(
      tanks: tanks,
      switches: const [],
      pressuresByIndex: const {},
      inWaterEndSeconds: null,
    );
    expect(result.tanks, tanks);
    expect(result.remappedIndices, isEmpty);
  });

  test('a tank with a recorded mix never claims', () {
    final tanks = [diluent, claimer(mixRecorded: true), sensorlessBailout(3)];
    final result = claimBailoutGases(
      tanks: tanks,
      switches: const [],
      pressuresByIndex: const {},
      inWaterEndSeconds: null,
    );
    expect(result.tanks, tanks);
    expect(result.remappedIndices, isEmpty);
  });

  test('a cylinder the diver edited is never claimed', () {
    final tanks = [diluent, claimer(), sensorlessBailout(3)];
    final result = claimBailoutGases(
      tanks: tanks,
      switches: const [],
      pressuresByIndex: const {},
      inWaterEndSeconds: null,
      keep: const {3},
    );
    expect(result.tanks, tanks);
    expect(result.remappedIndices, isEmpty);
  });

  test('a name-derived tank never claims', () {
    final tanks = [
      diluent,
      claimer(roleSource: 'transmitterName'),
      sensorlessBailout(3),
    ];
    final result = claimBailoutGases(
      tanks: tanks,
      switches: const [],
      pressuresByIndex: const {},
      inWaterEndSeconds: null,
    );
    expect(result.tanks, tanks);
    expect(result.remappedIndices, isEmpty);
  });
}
