import 'package:flutter_test/flutter_test.dart';
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

    test('carries every transmitter reading at the same instant', () {
      // Submersion's profile rows hold one pressure/tankIndex pair each, so
      // a second live transmitter rides along as an extra row stamped with
      // the same elapsed second.
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
            'TimeISO8601': '2026-05-01T10:00:10Z',
            'Depth': 18.0,
            'Cylinders': [
              {'GasNumber': 1, 'Pressure': 19500000, 'Pressure2': 21000000},
            ],
          },
        ],
      );

      final atTen = result.dive.profile
          .where((s) => s.timeSeconds == 10)
          .toList();
      expect(atTen, hasLength(2));
      expect(atTen[0].tankIndex, 0);
      expect(atTen[0].pressure, closeTo(195.0, 0.001));
      expect(atTen[1].tankIndex, 1);
      expect(atTen[1].pressure, closeTo(210.0, 0.001));
      // The extra row repeats the depth so it never reads as a surface point.
      expect(atTen[1].depth, 18.0);
    });

    test('skips a null transmitter slot but keeps the sensor numbering', () {
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
            'TimeISO8601': '2026-05-01T10:00:10Z',
            'Depth': 18.0,
            'Cylinders': [
              {'GasNumber': 1, 'Pressure': null, 'Pressure2': 21000000},
            ],
          },
        ],
      );

      final atTen = result.dive.profile
          .where((s) => s.timeSeconds == 10)
          .toList();
      expect(atTen, hasLength(1));
      expect(atTen.single.tankIndex, 1);
      expect(atTen.single.pressure, closeTo(210.0, 0.001));
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

    test('records a gas switch and assigns tanks by switch order', () {
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
}
