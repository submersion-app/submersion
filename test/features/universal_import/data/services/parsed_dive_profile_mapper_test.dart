import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/services/parsed_dive_profile_mapper.dart';

void main() {
  group('ParsedDiveProfileMapper.gasSwitches', () {
    // A trimix bottom gas, then EAN50 and oxygen for deco.
    final mixes = [
      pigeon.GasMix(index: 0, o2Percent: 21.0, hePercent: 35.0),
      pigeon.GasMix(index: 1, o2Percent: 50.0, hePercent: 0.0),
      pigeon.GasMix(index: 2, o2Percent: 100.0, hePercent: 0.0),
    ];

    Map<String, dynamic> tank(double o2, [double he = 0.0]) => {
      'gasMix': GasMix(o2: o2, he: he),
    };

    test('a change of gas mix becomes a switch to the matching tank', () {
      final result = ParsedDiveProfileMapper.gasSwitches(
        _dive(mixes, [
          _sample(0, 0.0, 0),
          _sample(600, 60.0, 0),
          _sample(1800, 21.0, 1),
          _sample(2400, 6.0, 2),
          _sample(2700, 0.0, 2),
        ]),
        [tank(21.0, 35.0), tank(50.0), tank(100.0)],
      );

      expect(result.gasSwitches, [
        {'timestamp': 1800, 'depth': 21.0, 'tankIndex': 1},
        {'timestamp': 2400, 'depth': 6.0, 'tankIndex': 2},
      ]);
      expect(result.tanks, hasLength(3));
    });

    test('matches tanks by gas, not by position', () {
      final result = ParsedDiveProfileMapper.gasSwitches(
        _dive(mixes, [_sample(0, 0.0, 0), _sample(1800, 21.0, 1)]),
        // The source lists the deco gas first.
        [tank(50.0), tank(21.0, 35.0)],
      );

      expect(result.gasSwitches, [
        {'timestamp': 1800, 'depth': 21.0, 'tankIndex': 0},
      ]);
    });

    test('tolerates the fraction-to-percent rounding of the native bridge', () {
      final result = ParsedDiveProfileMapper.gasSwitches(
        _dive(
          [
            pigeon.GasMix(index: 0, o2Percent: 32.000000001, hePercent: 0.0),
            pigeon.GasMix(index: 1, o2Percent: 49.999999, hePercent: 0.0),
          ],
          [_sample(0, 0.0, 0), _sample(1500, 21.0, 1)],
        ),
        [tank(32.0), tank(50.0)],
      );

      expect(result.gasSwitches.single['tankIndex'], 1);
    });

    test('appends a pressureless cylinder for a gas the source never '
        'listed', () {
      final listed = [tank(21.0, 35.0)];
      final result = ParsedDiveProfileMapper.gasSwitches(
        _dive(mixes, [
          _sample(0, 0.0, 0),
          _sample(1800, 21.0, 1),
          _sample(2400, 6.0, 2),
        ]),
        listed,
      );

      expect(result.tanks, hasLength(3));
      expect(result.tanks[1]['gasMix'], const GasMix(o2: 50.0));
      expect(result.tanks[1]['role'], TankRole.deco);
      expect(result.tanks[1]['order'], 1);
      expect(result.tanks[1].containsKey('startPressure'), isFalse);
      expect(result.tanks[2]['gasMix'], const GasMix(o2: 100.0));
      expect(result.gasSwitches, [
        {'timestamp': 1800, 'depth': 21.0, 'tankIndex': 1},
        {'timestamp': 2400, 'depth': 6.0, 'tankIndex': 2},
      ]);
      // The caller's list is left as it was.
      expect(listed, hasLength(1));
    });

    test('with no listed tanks the starting gas comes first', () {
      final result = ParsedDiveProfileMapper.gasSwitches(
        _dive(mixes, [
          _sample(0, 0.0, 0),
          _sample(1800, 21.0, 1),
          _sample(2400, 6.0, 2),
        ]),
        const [],
      );

      expect(result.tanks.map((t) => t['gasMix']), const [
        GasMix(o2: 21.0, he: 35.0),
        GasMix(o2: 50.0),
        GasMix(o2: 100.0),
      ]);
      expect(result.tanks[0]['role'], TankRole.backGas);
      expect(result.tanks.map((t) => t['order']), [0, 1, 2]);
      expect(result.gasSwitches.map((s) => s['tankIndex']), [1, 2]);
    });

    test('a gas switched to twice gets one appended cylinder', () {
      final result = ParsedDiveProfileMapper.gasSwitches(
        _dive(mixes, [
          _sample(0, 0.0, 0),
          _sample(1800, 21.0, 1),
          _sample(1900, 24.0, 0),
          _sample(2000, 21.0, 1),
        ]),
        [tank(21.0, 35.0)],
      );

      expect(result.tanks, hasLength(2));
      expect(result.gasSwitches.map((s) => s['tankIndex']), [1, 0, 1]);
    });

    test('a single-gas dive has no switches and keeps its tanks', () {
      final listed = [tank(32.0)];
      final result = ParsedDiveProfileMapper.gasSwitches(
        _dive(
          [pigeon.GasMix(index: 0, o2Percent: 32.0, hePercent: 0.0)],
          [_sample(0, 0.0, 0), _sample(1200, 18.0, 0)],
        ),
        listed,
      );

      expect(result.gasSwitches, isEmpty);
      expect(result.tanks, same(listed));
    });

    test('samples without a usable gas index neither switch nor reset '
        'the baseline', () {
      final result = ParsedDiveProfileMapper.gasSwitches(
        _dive(mixes, [
          _sample(0, 0.0, 0),
          _sample(600, 30.0, null),
          _sample(700, 30.0, 9),
          _sample(800, 30.0, 0),
          _sample(1800, 21.0, 1),
        ]),
        [tank(21.0, 35.0), tank(50.0)],
      );

      expect(result.gasSwitches, [
        {'timestamp': 1800, 'depth': 21.0, 'tankIndex': 1},
      ]);
    });
  });
}

pigeon.ProfileSample _sample(int time, double depth, int? gas) =>
    pigeon.ProfileSample(
      timeSeconds: time,
      depthMeters: depth,
      gasMixIndex: gas,
    );

pigeon.ParsedDive _dive(
  List<pigeon.GasMix> gasMixes,
  List<pigeon.ProfileSample> samples,
) => pigeon.ParsedDive(
  fingerprint: 'fp',
  dateTimeYear: 2026,
  dateTimeMonth: 3,
  dateTimeDay: 11,
  dateTimeHour: 9,
  dateTimeMinute: 0,
  dateTimeSecond: 0,
  maxDepthMeters: 60.0,
  avgDepthMeters: 30.0,
  durationSeconds: 2700,
  samples: samples,
  tanks: [],
  gasMixes: gasMixes,
  events: [],
);
