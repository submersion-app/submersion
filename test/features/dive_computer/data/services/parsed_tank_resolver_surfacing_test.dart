import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/data/services/parsed_tank_resolver.dart';

/// Issue #1092: a rebreather's oxygen cylinder keeps bleeding down through the
/// constant mass flow orifice after the valve is closed on the surface, and the
/// computer is still recording. libdivecomputer's reported end pressure is
/// simply the last sample it saw, so it lands deep in that tail.
void main() {
  group('resolveParsedTanks tank pressure at surfacing', () {
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
        maxDepthMeters: 51.0,
        avgDepthMeters: 30.0,
        durationSeconds: 4140,
        samples: samples,
        tanks: tanks,
        gasMixes: gasMixes,
        events: const [],
      );
    }

    pigeon.ProfileSample sample(
      int t,
      double depth, {
      double? pressure,
      int tankIndex = 0,
    }) => pigeon.ProfileSample(
      timeSeconds: t,
      depthMeters: depth,
      pressureBar: pressure,
      tankIndex: pressure == null ? null : tankIndex,
      gasMixIndex: 0,
    );

    /// The dive from the issue report: 41 bar of oxygen left at 1.2 m, 4 bar by
    /// the time the recording stops two minutes later on the surface.
    pigeon.ParsedDive bleedingOxygenDive() => makeParsedDive(
      gasMixes: [pigeon.GasMix(index: 0, o2Percent: 100.0, hePercent: 0.0)],
      tanks: [
        pigeon.TankInfo(
          index: 0,
          gasMixIndex: 0,
          startPressureBar: 200.0,
          endPressureBar: 4.0,
        ),
      ],
      samples: [
        sample(0, 0.0, pressure: 200.0),
        sample(600, 51.0, pressure: 120.0),
        sample(3970, 1.2, pressure: 41.0),
        sample(4000, 0.0, pressure: 30.0),
        sample(4140, 0.0, pressure: 4.0),
      ],
    );

    test('reads end pressure at surfacing rather than at the end of the '
        'recording', () {
      final tanks = resolveParsedTanks(
        bleedingOxygenDive(),
        trimAtSurfacing: true,
      );

      expect(tanks.single.endPressure, 41.0);
    });

    test('keeps the computer end pressure when trimming is off', () {
      final tanks = resolveParsedTanks(
        bleedingOxygenDive(),
        trimAtSurfacing: false,
      );

      expect(tanks.single.endPressure, 4.0);
    });

    test('leaves start pressure alone', () {
      final tanks = resolveParsedTanks(
        bleedingOxygenDive(),
        trimAtSurfacing: true,
      );

      expect(tanks.single.startPressure, 200.0);
    });

    test('leaves a dive without a surface tail untouched', () {
      final parsed = makeParsedDive(
        gasMixes: [pigeon.GasMix(index: 0, o2Percent: 21.0, hePercent: 0.0)],
        tanks: [
          pigeon.TankInfo(
            index: 0,
            gasMixIndex: 0,
            startPressureBar: 200.0,
            endPressureBar: 60.0,
          ),
        ],
        samples: [
          sample(0, 5.0, pressure: 200.0),
          sample(600, 20.0, pressure: 120.0),
          sample(1800, 5.0, pressure: 60.0),
        ],
      );

      final tanks = resolveParsedTanks(parsed, trimAtSurfacing: true);

      expect(tanks.single.endPressure, 60.0);
    });

    test('leaves a cylinder with no pressure samples untouched', () {
      final parsed = makeParsedDive(
        gasMixes: [pigeon.GasMix(index: 0, o2Percent: 21.0, hePercent: 0.0)],
        tanks: [
          pigeon.TankInfo(
            index: 0,
            gasMixIndex: 0,
            startPressureBar: 200.0,
            endPressureBar: 60.0,
          ),
        ],
        samples: [sample(0, 5.0), sample(600, 20.0), sample(1800, 0.0)],
      );

      final tanks = resolveParsedTanks(parsed, trimAtSurfacing: true);

      expect(tanks.single.endPressure, 60.0);
    });

    test('trims each transmitter against its own readings', () {
      final parsed = makeParsedDive(
        gasMixes: [
          pigeon.GasMix(index: 0, o2Percent: 21.0, hePercent: 0.0),
          pigeon.GasMix(index: 1, o2Percent: 100.0, hePercent: 0.0),
        ],
        tanks: [
          pigeon.TankInfo(
            index: 0,
            gasMixIndex: 0,
            startPressureBar: 200.0,
            endPressureBar: 136.0,
          ),
          pigeon.TankInfo(
            index: 1,
            gasMixIndex: 1,
            startPressureBar: 200.0,
            endPressureBar: 4.0,
          ),
        ],
        samples: [
          sample(600, 51.0, pressure: 160.0),
          sample(600, 51.0, pressure: 120.0, tankIndex: 1),
          sample(3970, 1.2, pressure: 136.0),
          sample(3970, 1.2, pressure: 41.0, tankIndex: 1),
          sample(4140, 0.0, pressure: 136.0),
          sample(4140, 0.0, pressure: 4.0, tankIndex: 1),
        ],
      );

      final tanks = resolveParsedTanks(parsed, trimAtSurfacing: true);

      // The diluent held steady, the oxygen bled away through the orifice.
      expect(tanks.firstWhere((t) => t.index == 0).endPressure, 136.0);
      expect(tanks.firstWhere((t) => t.index == 1).endPressure, 41.0);
    });

    test('trims by default so a caller cannot forget', () {
      expect(resolveParsedTanks(bleedingOxygenDive()).single.endPressure, 41.0);
    });
  });
}
