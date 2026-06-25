import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/data/services/parsed_tank_resolver.dart';

void main() {
  group('resolveParsedTanks', () {
    // DC_GASMIX_UNKNOWN: Shearwater never links a tank to a gas mix, so its
    // tank records carry this sentinel.
    const unknownGasMixIndex = 4294967295;

    pigeon.ParsedDive makeParsedDive({
      List<pigeon.ProfileSample> samples = const [],
      List<pigeon.TankInfo> tanks = const [],
      List<pigeon.GasMix> gasMixes = const [],
    }) {
      return pigeon.ParsedDive(
        fingerprint: 'test',
        dateTimeYear: 2026,
        dateTimeMonth: 6,
        dateTimeDay: 20,
        dateTimeHour: 9,
        dateTimeMinute: 43,
        dateTimeSecond: 2,
        maxDepthMeters: 23.4,
        avgDepthMeters: 16.6,
        durationSeconds: 6409,
        samples: samples,
        tanks: tanks,
        gasMixes: gasMixes,
        events: const [],
      );
    }

    pigeon.ProfileSample sample(int t, int tankIndex, int gasMixIndex) =>
        pigeon.ProfileSample(
          timeSeconds: t,
          depthMeters: 10.0,
          pressureBar: 150.0,
          tankIndex: tankIndex,
          gasMixIndex: gasMixIndex,
        );

    test('multi-gas dive with one transmitter keeps both gases and labels the '
        'transmitter tank with the gas actually breathed on it', () {
      // Real Teric dive: gas[0]=99% deco (no transmitter), gas[1]=32% back gas
      // (transmitter). Tank 0's gas is 32% (what it was breathed on), not
      // gasMixes.first (99%), and the 99% must survive as a separate cylinder.
      final parsed = makeParsedDive(
        gasMixes: [
          pigeon.GasMix(index: 0, o2Percent: 99.0, hePercent: 0.0),
          pigeon.GasMix(index: 1, o2Percent: 32.0, hePercent: 0.0),
        ],
        tanks: [
          pigeon.TankInfo(
            index: 0,
            gasMixIndex: unknownGasMixIndex,
            startPressureBar: 246.8,
            endPressureBar: 86.6,
          ),
        ],
        // Bottom phase on gas 1 (32%), deco phase on gas 0 (99%); the
        // transmitter (tank 0) is sampled throughout.
        samples: [
          sample(2, 0, 1),
          sample(1000, 0, 1),
          sample(3000, 0, 1),
          sample(5000, 0, 1),
          sample(5958, 0, 0),
          sample(6400, 0, 0),
        ],
      );

      final tanks = resolveParsedTanks(parsed);

      expect(tanks, hasLength(2), reason: 'both gases must be kept');

      final backGas = tanks.firstWhere((t) => t.o2Percent == 32.0);
      expect(backGas.index, 0, reason: 'transmitter tank keeps its index');
      expect(backGas.startPressure, 246.8);
      expect(backGas.endPressure, 86.6);

      final decoGas = tanks.firstWhere((t) => t.o2Percent == 99.0);
      expect(
        decoGas.startPressure,
        isNull,
        reason: 'deco gas had no transmitter',
      );
      expect(decoGas.endPressure, isNull);
      expect(
        decoGas.index,
        isNot(0),
        reason: 'synthesized cylinder must not collide with the tank index',
      );
    });

    test(
      'single-gas dive with transmitter yields one correctly-labeled tank',
      () {
        final parsed = makeParsedDive(
          gasMixes: [pigeon.GasMix(index: 0, o2Percent: 32.0, hePercent: 0.0)],
          tanks: [
            pigeon.TankInfo(
              index: 0,
              gasMixIndex: unknownGasMixIndex,
              startPressureBar: 242.8,
              endPressureBar: 123.1,
            ),
          ],
          samples: [sample(2, 0, 0), sample(3000, 0, 0)],
        );

        final tanks = resolveParsedTanks(parsed);

        expect(tanks, hasLength(1));
        expect(tanks[0].o2Percent, 32.0);
        expect(tanks[0].startPressure, 242.8);
      },
    );

    test(
      'uses the most-breathed gas when a transmitter spans a gas switch',
      () {
        // Tank 0 sampled mostly on gas 1 (32%), briefly on gas 0 (99%): the
        // tank's gas is the dominant one.
        final parsed = makeParsedDive(
          gasMixes: [
            pigeon.GasMix(index: 0, o2Percent: 99.0, hePercent: 0.0),
            pigeon.GasMix(index: 1, o2Percent: 32.0, hePercent: 0.0),
          ],
          tanks: [pigeon.TankInfo(index: 0, gasMixIndex: unknownGasMixIndex)],
          samples: [
            sample(2, 0, 1),
            sample(100, 0, 1),
            sample(200, 0, 1),
            sample(300, 0, 0),
          ],
        );

        final backGas = resolveParsedTanks(
          parsed,
        ).firstWhere((t) => t.index == 0);
        expect(backGas.o2Percent, 32.0);
      },
    );

    test('labels each transmitter with the gas breathed on its own tank', () {
      // Two transmitters (e.g. sidemount/twinset): tank 0 on gas 0 (32%),
      // tank 1 on gas 1 (50%). Each tank is labeled from its own samples.
      final parsed = makeParsedDive(
        gasMixes: [
          pigeon.GasMix(index: 0, o2Percent: 32.0, hePercent: 0.0),
          pigeon.GasMix(index: 1, o2Percent: 50.0, hePercent: 0.0),
        ],
        tanks: [
          pigeon.TankInfo(
            index: 0,
            gasMixIndex: unknownGasMixIndex,
            startPressureBar: 210.0,
          ),
          pigeon.TankInfo(
            index: 1,
            gasMixIndex: unknownGasMixIndex,
            startPressureBar: 205.0,
          ),
        ],
        samples: [
          sample(2, 0, 0),
          sample(100, 0, 0),
          sample(200, 1, 1),
          sample(300, 1, 1),
        ],
      );

      final tanks = resolveParsedTanks(parsed);

      expect(tanks, hasLength(2));
      expect(tanks.firstWhere((t) => t.index == 0).o2Percent, 32.0);
      expect(tanks.firstWhere((t) => t.index == 1).o2Percent, 50.0);
    });

    test('breaks a sample-count tie toward the first-breathed gas', () {
      // Equal samples on gas 1 then gas 0 for the same tank: the earliest gas
      // (gas 1, breathed first) wins.
      final parsed = makeParsedDive(
        gasMixes: [
          pigeon.GasMix(index: 0, o2Percent: 99.0, hePercent: 0.0),
          pigeon.GasMix(index: 1, o2Percent: 32.0, hePercent: 0.0),
        ],
        tanks: [pigeon.TankInfo(index: 0, gasMixIndex: unknownGasMixIndex)],
        samples: [sample(2, 0, 1), sample(100, 0, 0)],
      );

      final backGas = resolveParsedTanks(
        parsed,
      ).firstWhere((t) => t.index == 0);
      expect(backGas.o2Percent, 32.0);
    });

    test('honors a valid tank gasMixIndex when the computer sets it', () {
      final parsed = makeParsedDive(
        gasMixes: [
          pigeon.GasMix(index: 0, o2Percent: 21.0, hePercent: 0.0),
          pigeon.GasMix(index: 1, o2Percent: 50.0, hePercent: 0.0),
        ],
        tanks: [
          pigeon.TankInfo(index: 0, gasMixIndex: 1, startPressureBar: 200.0),
        ],
      );

      final tanks = resolveParsedTanks(parsed);
      final t0 = tanks.firstWhere((t) => t.index == 0);
      expect(t0.o2Percent, 50.0);
    });

    test(
      'synthesizes one cylinder per gas mix when there are no tank records',
      () {
        final parsed = makeParsedDive(
          gasMixes: [
            pigeon.GasMix(index: 0, o2Percent: 32.0, hePercent: 0.0),
            pigeon.GasMix(index: 1, o2Percent: 50.0, hePercent: 0.0),
          ],
        );

        final tanks = resolveParsedTanks(parsed);
        expect(tanks, hasLength(2));
        expect(tanks[0].index, 0);
        expect(tanks[0].o2Percent, 32.0);
        expect(tanks[1].o2Percent, 50.0);
        expect(tanks[0].startPressure, isNull);
      },
    );

    test('falls back to air when a tank has no gas information at all', () {
      final parsed = makeParsedDive(
        tanks: [pigeon.TankInfo(index: 0, gasMixIndex: unknownGasMixIndex)],
      );

      final tanks = resolveParsedTanks(parsed);
      expect(tanks, hasLength(1));
      expect(tanks[0].o2Percent, 21.0);
      expect(tanks[0].isAir, isTrue);
    });
  });
}
