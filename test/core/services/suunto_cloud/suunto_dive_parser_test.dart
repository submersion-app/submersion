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
