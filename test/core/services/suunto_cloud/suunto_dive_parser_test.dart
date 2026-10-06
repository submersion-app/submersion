import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';

Map<String, dynamic> _header({
  String deviceName = 'Porvoo',
  int activityType = 51,
}) => {
  'DateTime': '2024-05-01T10:00:00.000Z',
  'ActivityType': activityType,
  'Device': {
    'Name': deviceName,
    'SerialNumber': 'SN123',
    'Info': {'SW': '1.2.3'},
  },
  'Depth': {'Max': 18.5, 'Avg': 10.2},
  'DiveTime': 1800,
  'Temperature': {'Max': 296.0, 'Min': 299.0},
  'Diving': {
    'Gases': [
      {
        'Oxygen': 0.21,
        'Helium': 0.0,
        'TankSize': 0.012,
        'StartPressure': 20000000,
        'EndPressure': 5000000,
      },
    ],
    'GfLow': 30,
    'GfHigh': 85,
  },
};

void main() {
  // Submersion stores a dive's time as the diver's local wall clock flagged
  // as UTC (see parsedDiveToDownloadedDive, which stamps libdivecomputer's
  // local fields with DateTime.utc). Suunto writes that wall clock together
  // with the computer's UTC offset, so the offset has to be re-applied, not
  // resolved away.
  //
  // Every other fixture in this file is Z-suffixed, where the wrong and the
  // right conversion agree -- these cases are deliberately offset-bearing so
  // they can tell the two apart.
  group('timezone handling', () {
    Map<String, dynamic> headerAt(String dateTime) => {
      'DateTime': dateTime,
      'ActivityType': 51,
      'Device': {'Name': 'Porvoo'},
      'DiveTime': 1800,
    };

    test('keeps the local wall clock for a positive UTC offset', () {
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-08-20T15:27:23.140+02:00'),
        samples: const [],
      );

      expect(result.dive.startTime, DateTime.utc(2026, 8, 20, 15, 27, 23, 140));
    });

    test('keeps the local wall clock for a negative UTC offset', () {
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-08-20T15:27:23-05:00'),
        samples: const [],
      );

      expect(result.dive.startTime, DateTime.utc(2026, 8, 20, 15, 27, 23));
    });

    test('accepts a compact +HHMM offset', () {
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-08-20T15:27:23+0930'),
        samples: const [],
      );

      expect(result.dive.startTime, DateTime.utc(2026, 8, 20, 15, 27, 23));
    });

    test('treats a Z timestamp as already being the wall clock', () {
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-08-20T15:27:23Z'),
        samples: const [],
      );

      expect(result.dive.startTime, DateTime.utc(2026, 8, 20, 15, 27, 23));
    });

    test(
      'takes an offset-less timestamp at face value, not in the host zone',
      () {
        // DateTime.parse() would hand back a machine-local value here, so a
        // naive .toUtc() shifts this dive by whatever zone the importing
        // computer sits in. Asserting an exact UTC instant is what makes this
        // fail on a non-UTC machine if that ever regresses.
        final result = SuuntoDiveParser.parse(
          header: headerAt('2026-08-20T15:27:23'),
          samples: const [],
        );

        expect(result.dive.startTime, DateTime.utc(2026, 8, 20, 15, 27, 23));
      },
    );

    test('derives the dive start from offset-bearing samples', () {
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-08-20T15:00:00+02:00'),
        samples: const [
          {
            'TimeISO8601': '2026-08-20T15:27:23+02:00',
            'Depth': 0.5,
            'DiveEvents': {'DiveStatus': true},
          },
          {'TimeISO8601': '2026-08-20T15:27:33+02:00', 'Depth': 4.0},
        ],
      );

      expect(result.dive.startTime, DateTime.utc(2026, 8, 20, 15, 27, 23));
    });

    test('leaves elapsed sample times unaffected by the offset', () {
      List<int> elapsedFor(String offset) {
        final result = SuuntoDiveParser.parse(
          header: headerAt('2026-08-20T15:00:00$offset'),
          samples: [
            {
              'TimeISO8601': '2026-08-20T15:27:23$offset',
              'Depth': 0.5,
              'DiveEvents': const {'DiveStatus': true},
            },
            {'TimeISO8601': '2026-08-20T15:27:33$offset', 'Depth': 4.0},
            {'TimeISO8601': '2026-08-20T15:28:23$offset', 'Depth': 12.0},
          ],
        );
        return result.dive.profile.map((s) => s.timeSeconds).toList();
      }

      expect(elapsedFor('+02:00'), [0, 10, 60]);
      expect(elapsedFor('-08:00'), elapsedFor('+02:00'));
      expect(elapsedFor('Z'), elapsedFor('+02:00'));
    });
  });

  // The cloud's sml export carries two clocks: the computer's own
  // Header.DateTime, and a TimeISO8601 the cloud stamps on every sample
  // envelope. On a Nautic dive logged at 13:44 CEST the envelope read 15:44,
  // so the dive imported two hours late while Suunto showed 13:44 (#2604).
  // The header is the computer's clock and settles the zone; the samples
  // still place the dive-active moment within the log.
  group('sample clock disagreeing with the header', () {
    Map<String, dynamic> headerAt(String dateTime) => {
      'DateTime': dateTime,
      'ActivityType': 51,
      'Device': {'Name': 'Porvoo'},
      'DiveTime': 1800,
    };

    // A surface sample opening the log at [hhmm], then the dive-active
    // sample 40 s in and a descent sample 10 s after that.
    List<Map<String, dynamic>> samplesFrom(String hhmm, String offset) => [
      {'TimeISO8601': '2026-04-19T$hhmm:00.000$offset', 'Depth': 0.0},
      {
        'TimeISO8601': '2026-04-19T$hhmm:40.000$offset',
        'Depth': 1.2,
        'DiveEvents': const {'DiveStatus': true},
      },
      {'TimeISO8601': '2026-04-19T$hhmm:50.000$offset', 'Depth': 6.0},
    ];

    test('files the dive at the header clock when the samples run late', () {
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-04-19T13:44:00.000+02:00'),
        samples: samplesFrom('15:44', '+02:00'),
      );

      expect(result.dive.startTime, DateTime.utc(2026, 4, 19, 13, 44, 40));
    });

    test('files the dive at the header clock when the samples are UTC', () {
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-04-19T13:44:00.000+02:00'),
        samples: samplesFrom('11:44', 'Z'),
      );

      expect(result.dive.startTime, DateTime.utc(2026, 4, 19, 13, 44, 40));
    });

    test('corrects a west-of-UTC dive in the other direction', () {
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-04-19T09:10:00-05:00'),
        samples: samplesFrom('04:10', '-05:00'),
      );

      expect(result.dive.startTime, DateTime.utc(2026, 4, 19, 9, 10, 40));
    });

    test('corrects by a half-hour zone exactly', () {
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-04-19T10:15:00+05:30'),
        samples: samplesFrom('15:45', '+05:30'),
      );

      expect(result.dive.startTime, DateTime.utc(2026, 4, 19, 10, 15, 40));
    });

    test('keeps the sample clock when the header agrees within minutes', () {
      // The header may mark the log opening a little before or after the
      // first sample; seconds-level disagreement is not a zone error.
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-04-19T13:46:30+02:00'),
        samples: samplesFrom('13:44', '+02:00'),
      );

      expect(result.dive.startTime, DateTime.utc(2026, 4, 19, 13, 44, 40));
    });

    test('keeps a real header-to-sample delay alongside the zone error', () {
      // 27 minutes of the gap are real and 2 hours are the zone. Rounding
      // the whole 2h27m to quarter hours would take 2h30m and move the dive
      // 3 minutes early; the header's own +02:00 says which part is zone.
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-04-19T15:00:00+02:00'),
        samples: samplesFrom('17:27', '+02:00'),
      );

      expect(result.dive.startTime, DateTime.utc(2026, 4, 19, 15, 27, 40));
    });

    test('keeps the sample clock when the gap is not the header offset', () {
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-04-19T14:14:00+02:00'),
        samples: samplesFrom('13:44', '+02:00'),
      );

      expect(result.dive.startTime, DateTime.utc(2026, 4, 19, 13, 44, 40));
    });

    test('treats a Z header as a declared zero offset, not a missing one', () {
      // Z declares UTC, so there is no zone for the samples to be off by;
      // the gap is real and the sample clock stands.
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-04-19T11:44:00Z'),
        samples: samplesFrom('13:44', 'Z'),
      );

      expect(result.dive.startTime, DateTime.utc(2026, 4, 19, 13, 44, 40));
    });

    test('rounds to quarter hours when the header declares no offset', () {
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-04-19T13:44:00'),
        samples: samplesFrom('15:44', '+02:00'),
      );

      expect(result.dive.startTime, DateTime.utc(2026, 4, 19, 13, 44, 40));
    });

    test('keeps the sample clock for a gap shorter than any zone', () {
      // Half an hour rounds cleanly to quarter hours, but no zone sits that
      // close to UTC, so it cannot be an offset error.
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-04-19T14:14:00'),
        samples: samplesFrom('13:44', ''),
      );

      expect(result.dive.startTime, DateTime.utc(2026, 4, 19, 13, 44, 40));
    });

    test('leaves elapsed sample times unchanged by the correction', () {
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-04-19T13:44:00.000+02:00'),
        samples: samplesFrom('15:44', '+02:00'),
      );

      expect(result.dive.profile.map((s) => s.timeSeconds), [0, 10]);
    });
  });

  // The parser handles two entirely different signalling shapes: Nautic-era
  // computers use a `DiveEvents` object, EON-era ones an `Events[]` array.
  // Only the first had coverage, so every Events[] branch below (dive start,
  // gas switch, Notify safety stop, Alarm ascent) was untested.
  group('Events[] array signalling', () {
    Map<String, dynamic> eonHeader() => {
      'DateTime': '2026-05-01T10:00:00Z',
      'ActivityType': 51,
      'Device': {'Name': 'EON Steel'},
      'DiveTime': 1800,
      'Diving': {
        'Gases': [
          {'Oxygen': 0.32, 'Helium': 0.0, 'TankSize': 0.012},
          {'Oxygen': 0.5, 'Helium': 0.0, 'TankSize': 0.011},
        ],
      },
    };

    test('detects the dive start from an Events[] "Dive Active" state', () {
      final result = SuuntoDiveParser.parse(
        header: eonHeader(),
        samples: const [
          {'TimeISO8601': '2026-05-01T09:59:00Z', 'Depth': 0.0},
          {
            'TimeISO8601': '2026-05-01T10:00:00Z',
            'Depth': 0.5,
            'Events': [
              {
                'State': {'Active': true, 'Type': 'Dive Active'},
              },
            ],
          },
          {'TimeISO8601': '2026-05-01T10:00:10Z', 'Depth': 8.0},
        ],
      );

      expect(result.dive.startTime, DateTime.utc(2026, 5, 1, 10));
      expect(result.dive.profile.map((s) => s.timeSeconds), [0, 10]);
    });

    test('records a gas switch announced through Events[]', () {
      final result = SuuntoDiveParser.parse(
        header: eonHeader(),
        samples: const [
          {
            'TimeISO8601': '2026-05-01T10:00:00Z',
            'Depth': 0.5,
            'Events': [
              {
                'State': {'Active': true, 'Type': 'Dive Active'},
              },
              {
                'GasSwitch': {'GasNumber': 1},
              },
            ],
          },
          {
            'TimeISO8601': '2026-05-01T10:00:30Z',
            'Depth': 21.0,
            'Events': [
              {
                'GasSwitch': {'GasNumber': 2},
              },
            ],
          },
        ],
      );

      expect(result.dive.gasSwitches.map((g) => g.toTankIndex), [0, 1]);
      expect(result.dive.gasSwitches.last.timeSeconds, 30);
      expect(result.dive.gasSwitches.last.depth, 21.0);
      expect(
        result.dive.events.where((e) => e.type == 'gaschange'),
        hasLength(2),
      );
      // Tank order follows the observed switch order, not the array order.
      expect(result.dive.tanks.map((t) => t.index), [0, 1]);
      expect(result.dive.tanks.map((t) => t.o2Percent), [32.0, 50.0]);
    });

    test('emits a safety-stop event from an active Notify', () {
      final result = SuuntoDiveParser.parse(
        header: eonHeader(),
        samples: const [
          {
            'TimeISO8601': '2026-05-01T10:00:00Z',
            'Depth': 0.5,
            'Events': [
              {
                'State': {'Active': true, 'Type': 'Dive Active'},
              },
            ],
          },
          {
            'TimeISO8601': '2026-05-01T10:00:20Z',
            'Depth': 5.0,
            'Events': [
              {
                'Notify': {'Active': true, 'Type': 'Safety Stop'},
              },
            ],
          },
        ],
      );

      final safetyStops = result.dive.events.where(
        (e) => e.type == 'safetystop',
      );
      expect(safetyStops, hasLength(1));
      expect(safetyStops.single.timeSeconds, 20);
    });

    test('ignores an inactive Notify', () {
      final result = SuuntoDiveParser.parse(
        header: eonHeader(),
        samples: const [
          {
            'TimeISO8601': '2026-05-01T10:00:00Z',
            'Depth': 0.5,
            'Events': [
              {
                'State': {'Active': true, 'Type': 'Dive Active'},
              },
              {
                'Notify': {'Active': false, 'Type': 'Safety Stop'},
              },
            ],
          },
        ],
      );

      expect(result.dive.events.where((e) => e.type == 'safetystop'), isEmpty);
    });

    test('emits an ascent event from an active ascent-speed alarm', () {
      final result = SuuntoDiveParser.parse(
        header: eonHeader(),
        samples: const [
          {
            'TimeISO8601': '2026-05-01T10:00:00Z',
            'Depth': 0.5,
            'Events': [
              {
                'State': {'Active': true, 'Type': 'Dive Active'},
              },
            ],
          },
          {
            'TimeISO8601': '2026-05-01T10:00:40Z',
            'Depth': 9.0,
            'Events': [
              {
                'Alarm': {'Active': true, 'Type': 'Ascent Speed'},
              },
            ],
          },
        ],
      );

      final ascents = result.dive.events.where((e) => e.type == 'ascent');
      expect(ascents, hasLength(1));
      expect(ascents.single.timeSeconds, 40);
    });
  });

  // In sidemount mode a Nautic or Ocean logs both transmitters under one
  // gas: that gas's Cylinders entry carries `Pressure` and `Pressure2`.
  group('more than one transmitter', () {
    Map<String, dynamic> nauticHeader({
      List<Map<String, dynamic>> gases = const [
        {'Oxygen': 0.32, 'Helium': 0.0, 'TankSize': 0.0111},
      ],
    }) => {
      'DateTime': '2026-05-01T10:00:00Z',
      'ActivityType': 51,
      'Device': {'Name': 'Vaasa'},
      'DiveTime': 1800,
      'Diving': {'Gases': gases},
    };

    Map<String, dynamic> start() => {
      'TimeISO8601': '2026-05-01T10:00:00Z',
      'Depth': 0.5,
      'DiveEvents': {'DiveStatus': true},
    };

    Map<String, dynamic> at(int seconds, List<Map<String, dynamic>> cyls) => {
      'TimeISO8601': '2026-05-01T10:00:${seconds.toString().padLeft(2, '0')}Z',
      'Depth': 18.0,
      'Cylinders': cyls,
    };

    test('keeps one profile row per sample with every reading on it', () {
      final result = SuuntoDiveParser.parse(
        header: nauticHeader(),
        samples: [
          start(),
          at(10, const [
            {'GasNumber': 0, 'Pressure': 19500000, 'Pressure2': 21000000},
          ]),
          at(20, const [
            {'GasNumber': 0, 'Pressure': 19400000, 'Pressure2': 20900000},
          ]),
        ],
      );

      final times = result.dive.profile.map((s) => s.timeSeconds).toList();
      expect(times, [0, 10, 20]);

      final atTen = result.dive.profile[1];
      expect(atTen.depth, 18.0);
      // The single pair holds the last reading, as ProfileSample documents.
      expect(atTen.tankIndex, 1);
      expect(atTen.pressure, closeTo(210.0, 0.001));
      expect(atTen.tankPressures, hasLength(2));
      expect(atTen.tankPressures![0], closeTo(195.0, 0.001));
      expect(atTen.tankPressures![1], closeTo(210.0, 0.001));
    });

    test('turns a gas with two transmitters into a sidemount pair', () {
      final result = SuuntoDiveParser.parse(
        header: nauticHeader(
          gases: const [
            {
              'Oxygen': 0.32,
              'Helium': 0.0,
              'TankSize': 0.0111,
              'StartPressure': 19500000,
              'EndPressure': 6000000,
            },
          ],
        ),
        samples: [
          start(),
          at(10, const [
            {'GasNumber': 0, 'Pressure': 19500000, 'Pressure2': 21000000},
          ]),
        ],
      );

      final tanks = result.dive.tanks;
      expect(tanks, hasLength(2));

      final left = tanks.singleWhere((t) => t.index == 0);
      expect(left.role, TankRole.sidemountLeft.name);
      expect(left.o2Percent, closeTo(32.0, 0.001));
      expect(left.startPressure, closeTo(195.0, 0.001));
      expect(left.endPressure, closeTo(60.0, 0.001));

      // Same gas and cylinder size as its partner. The gas's start/end
      // pressures belong to the first transmitter, so this one leaves them
      // for the importer to derive from its own series.
      final right = tanks.singleWhere((t) => t.index == 1);
      expect(right.role, TankRole.sidemountRight.name);
      expect(right.o2Percent, closeTo(32.0, 0.001));
      expect(right.hePercent, 0.0);
      expect(right.volumeLiters, closeTo(11.1, 0.001));
      expect(right.startPressure, isNull);
      expect(right.endPressure, isNull);
    });

    test('leaves a single-transmitter dive as it was', () {
      final result = SuuntoDiveParser.parse(
        header: nauticHeader(),
        samples: [
          start(),
          at(10, const [
            {'GasNumber': 0, 'Pressure': 19500000, 'Pressure2': null},
          ]),
        ],
      );

      expect(result.dive.profile, hasLength(2));
      expect(result.dive.profile[1].tankPressures, isNull);
      expect(result.dive.profile[1].tankIndex, 0);
      expect(result.dive.tanks, hasLength(1));
      expect(result.dive.tanks.single.role, isNull);
    });

    test('gives the second transmitter an index no gas uses', () {
      // Sidemount plus a stage on its own transmitter: numbering transmitters
      // straight through the Cylinders entries would put gas 0's Pressure2
      // and gas 1's Pressure on the same tank.
      final result = SuuntoDiveParser.parse(
        header: nauticHeader(
          gases: const [
            {'Oxygen': 0.32, 'Helium': 0.0, 'TankSize': 0.0111},
            {'Oxygen': 0.5, 'Helium': 0.0, 'TankSize': 0.0057},
          ],
        ),
        samples: [
          {
            ...start(),
            'Events': const [
              {
                'GasSwitch': {'GasNumber': 0},
              },
            ],
          },
          at(10, const [
            {'GasNumber': 0, 'Pressure': 19500000, 'Pressure2': 21000000},
            {'GasNumber': 1, 'Pressure': 20000000, 'Pressure2': null},
          ]),
          {
            'TimeISO8601': '2026-05-01T10:00:20Z',
            'Depth': 6.0,
            'Events': const [
              {
                'GasSwitch': {'GasNumber': 1},
              },
            ],
          },
        ],
      );

      final pressures = result.dive.profile[1].tankPressures!;
      expect(pressures, hasLength(3));
      expect(pressures[0], closeTo(195.0, 0.001));
      expect(pressures[1], closeTo(200.0, 0.001));
      expect(pressures[2], closeTo(210.0, 0.001));

      final roles = {for (final t in result.dive.tanks) t.index: t.role};
      expect(roles, {
        0: TankRole.sidemountLeft.name,
        1: null,
        2: TankRole.sidemountRight.name,
      });
      final right = result.dive.tanks.singleWhere((t) => t.index == 2);
      expect(right.o2Percent, closeTo(32.0, 0.001));
    });

    test('puts a lone second-transmitter reading on its own tank', () {
      // The first transmitter drops out; the second keeps reporting.
      final result = SuuntoDiveParser.parse(
        header: nauticHeader(),
        samples: [
          start(),
          at(10, const [
            {'GasNumber': 0, 'Pressure': 19500000, 'Pressure2': 21000000},
          ]),
          at(20, const [
            {'GasNumber': 0, 'Pressure': null, 'Pressure2': 20900000},
          ]),
        ],
      );

      final atTwenty = result.dive.profile[2];
      expect(atTwenty.tankIndex, 1);
      expect(atTwenty.pressure, closeTo(209.0, 0.001));
    });

    test('numbers the second transmitter above the gases on an EON', () {
      // EON-family gas numbers are one-based; the offset still applies.
      final result = SuuntoDiveParser.parse(
        header: {
          ...nauticHeader(),
          'Device': {'Name': 'EON Steel'},
        },
        samples: const [
          {
            'TimeISO8601': '2026-05-01T10:00:00Z',
            'Depth': 0.5,
            'Events': [
              {
                'State': {'Active': true, 'Type': 'Dive Active'},
              },
            ],
          },
          {
            'TimeISO8601': '2026-05-01T10:00:10Z',
            'Depth': 18.0,
            'Cylinders': [
              {'GasNumber': 1, 'Pressure': 19500000, 'Pressure2': 21000000},
            ],
          },
        ],
      );

      expect(result.dive.profile, hasLength(2));
      final pressures = result.dive.profile[1].tankPressures!;
      expect(pressures[0], closeTo(195.0, 0.001));
      expect(pressures[1], closeTo(210.0, 0.001));
      expect(result.dive.tanks.map((t) => t.index), unorderedEquals([0, 1]));
    });

    test('invents no tank for a gas the header does not list', () {
      // An app export without a Diving block has no gases at all; the
      // pressures stay without a cylinder, as they were before.
      final result = SuuntoDiveParser.parse(
        header: {...nauticHeader()}..remove('Diving'),
        samples: [
          start(),
          at(10, const [
            {'GasNumber': 0, 'Pressure': 19500000, 'Pressure2': 21000000},
          ]),
        ],
      );

      expect(result.dive.tanks, isEmpty);
      expect(result.dive.profile, hasLength(2));
    });

    const sidemountAndStage = [
      {'Oxygen': 0.32, 'Helium': 0.0, 'TankSize': 0.0111},
      {'Oxygen': 0.5, 'Helium': 0.0, 'TankSize': 0.0057},
    ];

    test('pairs a sidemount gas the watch never switched to', () {
      // Multi-gas dive, no GasSwitch at all: the readings alone say the
      // sidemount gas was breathed.
      final result = SuuntoDiveParser.parse(
        header: nauticHeader(gases: sidemountAndStage),
        samples: [
          start(),
          at(10, const [
            {'GasNumber': 0, 'Pressure': 19500000, 'Pressure2': 21000000},
          ]),
        ],
      );

      final roles = {for (final t in result.dive.tanks) t.index: t.role};
      expect(roles, {
        0: TankRole.sidemountLeft.name,
        2: TankRole.sidemountRight.name,
      });
    });

    test('keeps each gas on its own index when the dive starts on gas 1', () {
      final result = SuuntoDiveParser.parse(
        header: nauticHeader(gases: sidemountAndStage),
        samples: [
          {
            ...start(),
            'Events': const [
              {
                'GasSwitch': {'GasNumber': 1},
              },
            ],
          },
          at(10, const [
            {'GasNumber': 0, 'Pressure': 19500000, 'Pressure2': 21000000},
          ]),
          {
            'TimeISO8601': '2026-05-01T10:00:20Z',
            'Depth': 18.0,
            'Events': const [
              {
                'GasSwitch': {'GasNumber': 0},
              },
            ],
          },
        ],
      );

      final o2ByIndex = {
        for (final t in result.dive.tanks) t.index: t.o2Percent.round(),
      };
      expect(o2ByIndex, {0: 32, 1: 50, 2: 32});
    });

    test('ignores readings on samples the profile skips', () {
      // Pressure2 shows up only before the dive starts, while the
      // transmitters pair: no profile row, so no Sidemount Right either.
      final result = SuuntoDiveParser.parse(
        header: nauticHeader(),
        samples: [
          {
            'TimeISO8601': '2026-05-01T09:59:50Z',
            'Depth': 0.0,
            'Cylinders': const [
              {'GasNumber': 0, 'Pressure': 19500000, 'Pressure2': 21000000},
            ],
          },
          start(),
          at(10, const [
            {'GasNumber': 0, 'Pressure': 19500000},
          ]),
        ],
      );

      expect(result.dive.tanks, hasLength(1));
      expect(result.dive.tanks.single.role, isNull);
      expect(result.dive.profile.every((s) => s.tankPressures == null), isTrue);
    });

    test('keeps the first of two readings for one gas', () {
      final result = SuuntoDiveParser.parse(
        header: nauticHeader(),
        samples: [
          start(),
          at(10, const [
            {'GasNumber': 0, 'Pressure': 19500000},
            {'GasNumber': 0, 'Pressure': 18000000},
          ]),
        ],
      );

      final atTen = result.dive.profile[1];
      expect(atTen.tankIndex, 0);
      expect(atTen.pressure, closeTo(195.0, 0.001));
      expect(atTen.tankPressures, isNull);
    });

    test('pairs a gas whose only extra transmitter is Pressure3', () {
      final result = SuuntoDiveParser.parse(
        header: nauticHeader(),
        samples: [
          start(),
          at(10, const [
            {
              'GasNumber': 0,
              'Pressure': 19500000,
              'Pressure2': null,
              'Pressure3': 21000000,
            },
          ]),
        ],
      );

      final roles = {for (final t in result.dive.tanks) t.index: t.role};
      expect(roles, {
        0: TankRole.sidemountLeft.name,
        1: TankRole.sidemountRight.name,
      });
    });

    test('gives a third transmitter on one gas no sidemount role', () {
      final result = SuuntoDiveParser.parse(
        header: nauticHeader(),
        samples: [
          start(),
          at(10, const [
            {
              'GasNumber': 0,
              'Pressure': 19500000,
              'Pressure2': 21000000,
              'Pressure3': 20000000,
            },
          ]),
        ],
      );

      final roles = {for (final t in result.dive.tanks) t.index: t.role};
      expect(roles, {
        0: TankRole.sidemountLeft.name,
        1: TankRole.sidemountRight.name,
        2: null,
      });
      final third = result.dive.tanks.singleWhere((t) => t.index == 2);
      expect(third.o2Percent, closeTo(32.0, 0.001));
    });
  });

  group('device identity', () {
    Map<String, dynamic> headerFor(String deviceName) => {
      'DateTime': '2026-08-20T10:00:00Z',
      'ActivityType': 51,
      'Device': {'Name': deviceName},
      'DiveTime': 1800,
    };

    test('maps the Nautic S codename to its commercial name', () {
      // A Nautic S reports Device.Name "Ylivieska"; without the mapping it
      // imports as the meaningless "Suunto Ylivieska".
      final result = SuuntoDiveParser.parse(
        header: headerFor('Ylivieska'),
        samples: const [],
      );

      expect(result.deviceName, 'Suunto Nautic S');
    });

    test('falls back to "Suunto <codename>" for an unknown device', () {
      final result = SuuntoDiveParser.parse(
        header: headerFor('EON Steel'),
        samples: const [],
      );

      expect(result.deviceName, 'Suunto EON Steel');
    });

    test('numbers gases from zero on a known current-generation device', () {
      final result = SuuntoDiveParser.parse(
        header: headerFor('Ylivieska'),
        samples: const [
          {
            'TimeISO8601': '2026-08-20T10:00:00Z',
            'Depth': 1.0,
            'DiveEvents': {'DiveStatus': true},
            'Cylinders': [
              {'GasNumber': 0, 'Pressure': 20000000},
            ],
          },
        ],
      );

      expect(result.dive.profile.first.tankIndex, 0);
    });

    test('reads the gas numbering off the data for an unknown device', () {
      // An uncatalogued computer that numbers gases from 0 would otherwise
      // take the EON offset of 1 and land every cylinder on index -1.
      final result = SuuntoDiveParser.parse(
        header: headerFor('Kokkola'),
        samples: const [
          {
            'TimeISO8601': '2026-08-20T10:00:00Z',
            'Depth': 1.0,
            'DiveEvents': {'DiveStatus': true},
            'Cylinders': [
              {'GasNumber': 0, 'Pressure': 20000000},
            ],
          },
        ],
      );

      expect(result.dive.profile.first.tankIndex, 0);
    });

    test('keeps the EON one-based numbering when the data starts at 1', () {
      final result = SuuntoDiveParser.parse(
        header: headerFor('EON Core'),
        samples: const [
          {
            'TimeISO8601': '2026-08-20T10:00:00Z',
            'Depth': 1.0,
            'DiveEvents': {'DiveStatus': true},
            'Cylinders': [
              {'GasNumber': 1, 'Pressure': 20000000},
            ],
          },
        ],
      );

      expect(result.dive.profile.first.tankIndex, 0);
    });
  });

  group('SuuntoDiveParser.parse', () {
    test('maps header fields onto the dive', () {
      final result = SuuntoDiveParser.parse(header: _header(), samples: []);
      final dive = result.dive;

      expect(dive.maxDepth, 18.5);
      expect(dive.avgDepth, 10.2);
      expect(dive.durationSeconds, 1800);
      // Suunto's "Min" (299K) is the warmer reading, "Max" (296K) the colder.
      expect(dive.minTemperature, closeTo(296.0 - 273.15, 1e-9));
      expect(dive.maxTemperature, closeTo(299.0 - 273.15, 1e-9));
      expect(dive.gfLow, 30);
      expect(dive.gfHigh, 85);
      expect(dive.decoAlgorithm, 'buhlmann');

      expect(result.deviceName, 'Suunto Ocean');
      expect(result.serialNumber, 'SN123');
      expect(result.firmwareVersion, '1.2.3');
    });

    test('assigns a single reported gas straight to tank 0', () {
      final result = SuuntoDiveParser.parse(header: _header(), samples: []);
      expect(result.dive.tanks, hasLength(1));
      final tank = result.dive.tanks.single;
      expect(tank.index, 0);
      expect(tank.o2Percent, closeTo(21.0, 1e-9));
      expect(tank.hePercent, 0.0);
      expect(tank.volumeLiters, closeTo(12.0, 1e-9));
      expect(tank.startPressure, closeTo(200.0, 1e-9));
      expect(tank.endPressure, closeTo(50.0, 1e-9));
    });

    test('maps Vaasa/Porvoo device codenames to product names', () {
      expect(
        SuuntoDiveParser.parse(
          header: _header(deviceName: 'Vaasa'),
          samples: [],
        ).deviceName,
        'Suunto Nautic',
      );
      expect(
        SuuntoDiveParser.parse(
          header: _header(deviceName: 'EON Steel'),
          samples: [],
        ).deviceName,
        'Suunto EON Steel',
      );
    });

    test(
      'produces no profile when no dive-active marker is found in samples',
      () {
        final result = SuuntoDiveParser.parse(
          header: _header(),
          samples: [
            {'TimeISO8601': '2024-05-01T10:00:00.000Z', 'Depth': 1.0},
          ],
        );
        expect(result.dive.profile, isEmpty);
        // Falls back to the header's own absolute start time.
        expect(
          result.dive.startTime,
          DateTime.parse('2024-05-01T10:00:00.000Z'),
        );
      },
    );

    group('with a full sample stream (1-indexed gas numbers, EON-style)', () {
      Map<String, dynamic> eonHeader() => _header(deviceName: 'EON Steel');

      List<Map<String, dynamic>> samples() => [
        {
          'TimeISO8601': '2024-05-01T10:00:00.000Z',
          'DiveEvents': {'DiveStatus': true},
          'Depth': 0.5,
        },
        {
          'TimeISO8601': '2024-05-01T10:00:10.000Z',
          'Depth': 5.0,
          'Temperature': 296.5,
        },
        {
          'TimeISO8601': '2024-05-01T10:00:20.000Z',
          'Depth': 18.5,
          'Ceiling': 3.0,
          'NoDecTime': 0,
          'TimeToSurface': 120,
          'Cylinders': [
            {'GasNumber': 1, 'Pressure': 19500000},
          ],
        },
        {
          'TimeISO8601': '2024-05-01T10:00:30.000Z',
          'Depth': 3.0,
          'DiveEvents': {
            'State': {'Type': 'At Safety Stop'},
          },
        },
        // Duplicate elapsed second (still within the same wall-clock
        // second as the prior sample) must be skipped.
        {'TimeISO8601': '2024-05-01T10:00:30.500Z', 'Depth': 3.1},
      ];

      test('zeroes elapsed time at the detected dive-active sample', () {
        final result = SuuntoDiveParser.parse(
          header: eonHeader(),
          samples: samples(),
        );
        expect(result.dive.startTime, DateTime.parse('2024-05-01T10:00:00Z'));
        expect(result.dive.profile.map((s) => s.timeSeconds).toList(), [
          0,
          10,
          20,
          30,
        ]);
      });

      test('converts temperature and carries ceiling/ndl/tts', () {
        final result = SuuntoDiveParser.parse(
          header: eonHeader(),
          samples: samples(),
        );
        final profile = result.dive.profile;

        expect(profile[1].temperature, closeTo(296.5 - 273.15, 1e-9));
        expect(profile[2].ceiling, 3.0);
        expect(profile[2].ndl, 0);
        expect(profile[2].tts, 120);
      });

      test('reads cylinder pressure with the 1-indexed gas offset', () {
        final result = SuuntoDiveParser.parse(
          header: eonHeader(),
          samples: samples(),
        );
        final pressureSample = result.dive.profile[2];
        expect(pressureSample.tankIndex, 0);
        expect(pressureSample.pressure, closeTo(195.0, 1e-9));
      });

      test('emits a safety-stop event at the reported time', () {
        final result = SuuntoDiveParser.parse(
          header: eonHeader(),
          samples: samples(),
        );
        expect(
          result.dive.events.any(
            (e) => e.type == 'safetystop' && e.timeSeconds == 30,
          ),
          isTrue,
        );
      });
    });

    test('records a gas switch and gives each gas its own tank', () {
      final header = _header(deviceName: 'EON Steel')
        ..['Diving']['Gases'] = [
          {'Oxygen': 0.21, 'Helium': 0.0, 'TankSize': 0.012},
          {'Oxygen': 0.5, 'Helium': 0.0, 'TankSize': 0.007},
        ];
      final samples = [
        {
          'TimeISO8601': '2024-05-01T10:00:00.000Z',
          'DiveEvents': {'DiveStatus': true},
          'Depth': 0.5,
        },
        {
          'TimeISO8601': '2024-05-01T10:00:10.000Z',
          'Depth': 5.0,
          'DiveEvents': {
            'GasSwitch': {'GasNumber': 1},
          },
        },
        {
          'TimeISO8601': '2024-05-01T10:00:20.000Z',
          'Depth': 6.0,
          'DiveEvents': {
            'GasSwitch': {'GasNumber': 2},
          },
        },
      ];

      final result = SuuntoDiveParser.parse(header: header, samples: samples);

      expect(result.dive.gasSwitches, hasLength(2));
      expect(result.dive.gasSwitches[0].toTankIndex, 0);
      expect(result.dive.gasSwitches[1].toTankIndex, 1);
      expect(result.dive.tanks.map((t) => t.index).toList()..sort(), [0, 1]);
      final byIndex = {for (final t in result.dive.tanks) t.index: t};
      expect(byIndex[0]!.o2Percent, closeTo(21.0, 1e-9));
      expect(byIndex[1]!.o2Percent, closeTo(50.0, 1e-9));
    });
  });

  group('full dive-event extraction', () {
    Map<String, dynamic> header() => {
      'DateTime': '2026-08-26T13:48:11Z',
      'ActivityType': 51,
      'Device': {'Name': 'Porvoo'},
      'DiveTime': 2255,
    };

    Map<String, dynamic> eventSample(String iso, Map<String, dynamic> event) =>
        {
          'TimeISO8601': iso,
          'Depth': 12.0,
          'Events': [
            {
              'State': {'Active': true, 'Type': 'Dive Active'},
            },
            event,
          ],
        };

    test(
      'emits the Alarm / Notify / State events the old importer dropped',
      () {
        final result = SuuntoDiveParser.parse(
          header: header(),
          samples: [
            eventSample('2026-08-26T13:48:11Z', const {
              'State': {'Active': true, 'Type': 'Dive Active'},
            }),
            eventSample('2026-08-26T14:06:01Z', const {
              'Alarm': {'Active': true, 'Type': 'Ascent Speed'},
            }),
            eventSample('2026-08-26T14:09:40Z', const {
              'Notify': {'Active': true, 'Type': 'User Tank Pressure'},
            }),
            eventSample('2026-08-26T14:12:53Z', const {
              'State': {'Active': true, 'Type': 'At Deco Stop'},
            }),
            eventSample('2026-08-26T14:16:28Z', const {
              'State': {'Active': true, 'Type': 'At Safety Stop'},
            }),
            eventSample('2026-08-26T14:18:00Z', const {
              'Warning': {'Active': true, 'Type': 'CNS80%'},
            }),
          ],
        );

        final types = result.dive.events.map((e) => e.type).toList();
        expect(types, containsAll(['ascent', 'airtime', 'deco', 'safetystop']));
        expect(types, contains('cnsWarning'));
      },
    );

    test('stamps DownloadedEvent.value with the native (subgroup<<8|type)', () {
      final result = SuuntoDiveParser.parse(
        header: header(),
        samples: [
          eventSample('2026-08-26T14:06:01Z', const {
            'Alarm': {'Active': true, 'Type': 'Ascent Speed'},
          }),
        ],
      );
      final ascent = result.dive.events.singleWhere((e) => e.type == 'ascent');
      expect(ascent.value, (0x18 << 8) | 5);
    });

    test(
      'a begin held across samples is imported once; a re-trigger again',
      () {
        final held = SuuntoDiveParser.parse(
          header: header(),
          samples: [
            eventSample('2026-08-26T14:06:01Z', const {
              'Alarm': {'Active': true, 'Type': 'Ascent Speed'},
            }),
            eventSample('2026-08-26T14:06:11Z', const {
              'Alarm': {'Active': true, 'Type': 'Ascent Speed'},
            }),
            eventSample('2026-08-26T14:06:21Z', const {
              'Alarm': {'Active': false, 'Type': 'Ascent Speed'},
            }),
          ],
        );
        expect(held.dive.events.where((e) => e.type == 'ascent'), hasLength(1));

        final retrigger = SuuntoDiveParser.parse(
          header: header(),
          samples: [
            eventSample('2026-08-26T14:06:01Z', const {
              'Alarm': {'Active': true, 'Type': 'Ascent Speed'},
            }),
            eventSample('2026-08-26T14:06:11Z', const {
              'Alarm': {'Active': false, 'Type': 'Ascent Speed'},
            }),
            eventSample('2026-08-26T14:07:41Z', const {
              'Alarm': {'Active': true, 'Type': 'Ascent Speed'},
            }),
          ],
        );
        expect(
          retrigger.dive.events.where((e) => e.type == 'ascent'),
          hasLength(2),
        );
      },
    );
  });

  // Suunto records a surface fix before the descent and another after the
  // ascent, and stores the pair in the dive footer's DiveLocation block as
  // radians. The samples' DiveRouteOrigin carries only the entry fix (in
  // degrees), so it is a fallback for dives whose footer has no Start.
  group('surface GPS fixes', () {
    double rad(double degrees) => degrees * math.pi / 180.0;

    Map<String, dynamic> fix(double latDegrees, double lonDegrees) => {
      'Latitude': rad(latDegrees),
      'Longitude': rad(lonDegrees),
      'Ehpe': 4.5,
    };

    Map<String, dynamic> headerWithLocation(Map<String, dynamic> location) => {
      ..._header(),
      'DiveLocation': location,
    };

    test('reads entry from Start and exit from Stop, converted to degrees', () {
      final result = SuuntoDiveParser.parse(
        header: headerWithLocation({
          'Start': fix(34.5, 35.25),
          'Stop': fix(34.502, 35.253),
        }),
        samples: const [],
      );

      expect(result.dive.entryLatitude, closeTo(34.5, 1e-9));
      expect(result.dive.entryLongitude, closeTo(35.25, 1e-9));
      expect(result.dive.exitLatitude, closeTo(34.502, 1e-9));
      expect(result.dive.exitLongitude, closeTo(35.253, 1e-9));
    });

    test('handles southern and western hemispheres', () {
      final result = SuuntoDiveParser.parse(
        header: headerWithLocation({
          'Start': fix(-16.75, -122.4),
          'Stop': fix(-16.751, -122.402),
        }),
        samples: const [],
      );

      expect(result.dive.entryLatitude, closeTo(-16.75, 1e-9));
      expect(result.dive.entryLongitude, closeTo(-122.4, 1e-9));
      expect(result.dive.exitLatitude, closeTo(-16.751, 1e-9));
      expect(result.dive.exitLongitude, closeTo(-122.402, 1e-9));
    });

    test('imports a dive that holds only an exit fix', () {
      final result = SuuntoDiveParser.parse(
        header: headerWithLocation({'Stop': fix(34.502, 35.253)}),
        samples: const [],
      );

      expect(result.dive.entryLatitude, isNull);
      expect(result.dive.entryLongitude, isNull);
      expect(result.dive.exitLatitude, closeTo(34.502, 1e-9));
      expect(result.dive.exitLongitude, closeTo(35.253, 1e-9));
    });

    test('imports a dive that holds only an entry fix', () {
      final result = SuuntoDiveParser.parse(
        header: headerWithLocation({'Start': fix(34.5, 35.25)}),
        samples: const [],
      );

      expect(result.dive.entryLatitude, closeTo(34.5, 1e-9));
      expect(result.dive.exitLatitude, isNull);
      expect(result.dive.exitLongitude, isNull);
    });

    test('falls back to DiveRouteOrigin for entry when Start is absent', () {
      final result = SuuntoDiveParser.parse(
        header: headerWithLocation({'Stop': fix(34.502, 35.253)}),
        samples: const [
          {
            'TimeISO8601': '2024-05-01T10:00:00.000Z',
            'Depth': 0.5,
            'DiveEvents': {'DiveStatus': true},
            'DiveRouteOrigin': {'Latitude': 34.5, 'Longitude': 35.25},
          },
        ],
      );

      expect(result.dive.entryLatitude, closeTo(34.5, 1e-9));
      expect(result.dive.entryLongitude, closeTo(35.25, 1e-9));
      expect(result.dive.exitLatitude, closeTo(34.502, 1e-9));
    });

    test('prefers the footer Start over DiveRouteOrigin', () {
      final result = SuuntoDiveParser.parse(
        header: headerWithLocation({'Start': fix(34.5, 35.25)}),
        samples: const [
          {
            'TimeISO8601': '2024-05-01T10:00:00.000Z',
            'Depth': 0.5,
            'DiveEvents': {'DiveStatus': true},
            'DiveRouteOrigin': {'Latitude': 12.0, 'Longitude': 13.0},
          },
        ],
      );

      expect(result.dive.entryLatitude, closeTo(34.5, 1e-9));
      expect(result.dive.entryLongitude, closeTo(35.25, 1e-9));
    });

    test('keeps DiveRouteOrigin when the footer has no location at all', () {
      final result = SuuntoDiveParser.parse(
        header: _header(),
        samples: const [
          {
            'TimeISO8601': '2024-05-01T10:00:00.000Z',
            'Depth': 0.5,
            'DiveEvents': {'DiveStatus': true},
            'DiveRouteOrigin': {'Latitude': 34.5, 'Longitude': 35.25},
          },
        ],
      );

      expect(result.dive.entryLatitude, closeTo(34.5, 1e-9));
      expect(result.dive.entryLongitude, closeTo(35.25, 1e-9));
      expect(result.dive.exitLatitude, isNull);
    });

    test('ignores a null-island fix', () {
      final result = SuuntoDiveParser.parse(
        header: headerWithLocation({
          'Start': {'Latitude': 0.0, 'Longitude': 0.0},
          'Stop': fix(34.502, 35.253),
        }),
        samples: const [],
      );

      expect(result.dive.entryLatitude, isNull);
      expect(result.dive.exitLatitude, closeTo(34.502, 1e-9));
    });

    test('ignores a fix missing one of its two coordinates', () {
      final result = SuuntoDiveParser.parse(
        header: headerWithLocation({
          'Start': {'Latitude': rad(34.5)},
          'Stop': {'Longitude': rad(35.253)},
        }),
        samples: const [],
      );

      expect(result.dive.entryLatitude, isNull);
      expect(result.dive.exitLatitude, isNull);
    });

    // A value that only makes sense as degrees would land far outside the
    // globe once multiplied by 180/pi, so rejecting out-of-range results
    // stops a mis-scaled fix being imported as a plausible-looking position.
    test('rejects a fix that is out of range once converted', () {
      final result = SuuntoDiveParser.parse(
        header: headerWithLocation({
          'Start': {'Latitude': 34.5, 'Longitude': 35.25},
        }),
        samples: const [],
      );

      expect(result.dive.entryLatitude, isNull);
      expect(result.dive.entryLongitude, isNull);
    });
  });

  group('computer tissue', () {
    Map<String, dynamic> headerWithDiving(Map<String, dynamic> diving) => {
      ..._header(),
      'Diving': {..._header()['Diving'] as Map<String, dynamic>, ...diving},
    };

    test('builds a tissue snapshot from a DeviceLog EON Core header', () {
      final result = SuuntoDiveParser.parse(
        header: headerWithDiving({
          'Algorithm': 'Suunto Fused2 RGBM',
          'StartTissue': {
            'Nitrogen': [
              79000, 79000, 79000, 79000, 79000, 79000, 79008, 79123, //
              79457, 80568, 81755, 82776, 83604, 84269, 85254,
            ],
            'Helium': List<int>.filled(15, 0),
          },
          'EndTissue': {
            'Nitrogen': [
              89665, 97105, 116432, 135968, 142849, 131069, 113059, 103999, //
              98930, 94002, 91918, 90918, 90376, 90058, 89736,
            ],
            'Helium': List<int>.filled(15, 0),
            'CNS': 0.132,
            'OTU': 35.57,
            'RgbmNitrogen': 0.98,
            'RgbmHelium': 0.985,
          },
        }),
        samples: const [],
      );

      final snapshot = result.computerTissue;
      expect(snapshot, isNotNull);
      expect(snapshot!.algorithm, 'Suunto Fused2 RGBM');
      expect(snapshot.start!.n2Bar, hasLength(15));
      expect(snapshot.start!.n2Bar!.first, 0.79);
      expect(snapshot.end!.n2Bar![4], 1.42849);
      expect(snapshot.end!.cnsPercent, closeTo(13.2, 1e-9));
      expect(snapshot.end!.otu, 35.57);
      expect(snapshot.end!.rgbmNitrogen, 0.98);
      // The import pipeline only ever sees the DownloadedDive, so the
      // snapshot has to ride on it too.
      expect(result.dive.computerTissue, snapshot);
    });

    test('reads the HelO2 Pressure-list encoding', () {
      final result = SuuntoDiveParser.parse(
        header: headerWithDiving({
          'Algorithm': 'Suunto Technical RGBM',
          'StartTissue': {
            'Nitrogen': {'Pressure': List<int>.filled(9, 79000)},
          },
          'EndTissue': {'OLF': 0.05, 'CNS': 0.04, 'OTU': 12.0},
        }),
        samples: const [],
      );

      expect(result.computerTissue!.start!.n2Bar, hasLength(9));
      expect(result.computerTissue!.end!.cnsPercent, closeTo(4.0, 1e-9));
    });

    group('decoAlgorithm follows the header Algorithm', () {
      // The header carries a GF pair in every case below, which alone used
      // to make the dive Buhlmann even when the computer ran RGBM.
      final cases = {
        'Suunto Fused2 RGBM': 'rgbm',
        'Suunto Technical RGBM': 'rgbm',
        'Bühlmann 16 GF': 'buhlmann',
        'Buhlmann 16 GF': 'buhlmann',
        ' Something New ': 'something new',
      };
      for (final MapEntry(key: algorithm, value: expected) in cases.entries) {
        test('"$algorithm" is $expected', () {
          final result = SuuntoDiveParser.parse(
            header: headerWithDiving({'Algorithm': algorithm}),
            samples: const [],
          );
          expect(result.dive.decoAlgorithm, expected);
        });
      }

      test('a blank Algorithm falls back to the GF pair', () {
        final result = SuuntoDiveParser.parse(
          header: headerWithDiving({'Algorithm': '  '}),
          samples: const [],
        );
        expect(result.dive.decoAlgorithm, 'buhlmann');
      });

      test('the dive and its snapshot agree on the model', () {
        final result = SuuntoDiveParser.parse(
          header: headerWithDiving({
            'Algorithm': 'Suunto Fused2 RGBM',
            'EndTissue': {'CNS': 0.04},
          }),
          samples: const [],
        );
        expect(result.dive.decoAlgorithm, 'rgbm');
        expect(result.computerTissue!.algorithm, 'Suunto Fused2 RGBM');
      });
    });

    test('leaves the snapshot null for a header without tissue data', () {
      final result = SuuntoDiveParser.parse(header: _header(), samples: []);
      expect(result.computerTissue, isNull);
      expect(result.dive.computerTissue, isNull);
    });

    test('leaves the snapshot null for a header without Diving', () {
      final header = _header()..remove('Diving');
      final result = SuuntoDiveParser.parse(header: header, samples: []);
      expect(result.computerTissue, isNull);
    });
  });

  // The Nautic S records an inertial route that the Suunto app exports as
  // DiveRoute (#1445). It must land on the same clock as the dive itself,
  // including when the cloud's sample clock runs a whole zone off (#2604).
  group('DiveRoute', () {
    Map<String, dynamic> headerAt(String dateTime) => {
      'DateTime': dateTime,
      'ActivityType': 51,
      'Device': {'Name': 'Ylivieska', 'SerialNumber': 'NS-1'},
      'DiveTime': 1800,
    };

    List<Map<String, dynamic>> samplesAt(String hhmm, String offset) => [
      {
        'TimeISO8601': '2026-04-19T$hhmm:40.000$offset',
        'Depth': 1.2,
        'DiveEvents': const {'DiveStatus': true},
        'DiveRouteOrigin': const {'Latitude': 47.3, 'Longitude': -2.9},
        'DiveRoute': const {'X': 0.0, 'Y': 0.0, 'Z': 1.2},
      },
      {
        'TimeISO8601': '2026-04-19T$hhmm:41.000$offset',
        'Depth': 1.8,
        'DiveRoute': const {'X': 0.4, 'Y': 0.9, 'Z': 1.8},
      },
    ];

    test('carries the route on the parsed dive, on the dive start clock', () {
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-04-19T13:44:00.000+02:00'),
        samples: samplesAt('13:44', '+02:00'),
      );

      final route = result.route!;
      expect(route.points, hasLength(2));
      expect(
        route.points.first.timestamp,
        result.dive.startTime.millisecondsSinceEpoch ~/ 1000,
      );
      expect(route.originLatitude, 47.3);
      expect(route.originLongitude, -2.9);
    });

    test('shifts the route with the dive when the sample clock runs late '
        '(#2604)', () {
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-04-19T13:44:00.000+02:00'),
        samples: samplesAt('15:44', '+02:00'),
      );

      expect(result.dive.startTime, DateTime.utc(2026, 4, 19, 13, 44, 40));
      expect(
        result.route!.points.first.timestamp,
        result.dive.startTime.millisecondsSinceEpoch ~/ 1000,
      );
    });

    test('has no route when the export carries no DiveRoute samples', () {
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-04-19T13:44:00.000+02:00'),
        samples: [
          {
            'TimeISO8601': '2026-04-19T13:44:40.000+02:00',
            'Depth': 1.2,
            'DiveEvents': const {'DiveStatus': true},
          },
        ],
      );
      expect(result.route, isNull);
    });

    test('copyWith keeps the route', () {
      final result = SuuntoDiveParser.parse(
        header: headerAt('2026-04-19T13:44:00.000+02:00'),
        samples: samplesAt('13:44', '+02:00'),
      );
      expect(result.copyWith(notes: 'n').route, same(result.route));
    });
  });
}
