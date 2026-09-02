import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_api_exception.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_sml_normalizer.dart';

Map<String, dynamic> _cloudFixture() => {
  'Summary': {
    'Samples': [
      {
        'Attributes': {
          'suunto/sml': {
            'Header': {
              'DateTime': '2024-05-01T10:00:00.000Z',
              'ActivityType': 51,
              'Device': {
                'Name': 'Porvoo',
                'SerialNumber': 'SN123',
                'Info': {'SW': '1.2.3'},
              },
              'Depth': {'Max': 18.5, 'Avg': 10.2},
              'DiveTime': 1800,
              'Temperature': {'Max': 296.0, 'Min': 299.0},
            },
          },
        },
      },
      {
        'Attributes': {
          'suunto/sml': {
            'DiveHeader': {
              'Gases': [
                {
                  'Oxygen': 21,
                  'Helium': 0,
                  'TankSize': 0.012,
                  'TankFillPressure': 20000000,
                  'StartPressure': 20000000,
                  'EndPressure': 5000000,
                },
                // Unused gas (no tank filled) must be dropped.
                {'Oxygen': 100, 'Helium': 0, 'TankSize': 0},
              ],
              'LowGf': 30,
              'HighGf': 85,
            },
          },
        },
      },
    ],
  },
  'Data': {
    'Samples': [
      {
        'TimeISO8601': '2024-05-01T10:00:00.000Z',
        'Attributes': {
          'suunto/sml': {
            'Sample': {
              'DiveEvents': {'DiveStatus': true},
              'Depth': 0.5,
            },
          },
        },
      },
      {
        'TimeISO8601': '2024-05-01T10:00:10.000Z',
        'Attributes': {
          'suunto/sml': {
            'Sample': {'Depth': 5.0, 'Temperature': 296.5},
          },
        },
      },
    ],
  },
};

void main() {
  group('SuuntoSmlNormalizer.parse (cloud shape)', () {
    test('flattens Summary/Data into header/samples', () {
      final export = SuuntoSmlNormalizer.parse(_cloudFixture());

      expect(export.header['ActivityType'], 51);
      expect(export.header['DateTime'], '2024-05-01T10:00:00.000Z');
      expect(export.samples, hasLength(2));
      expect(export.samples[0]['TimeISO8601'], '2024-05-01T10:00:00.000Z');
      expect(export.samples[0]['DiveEvents'], {'DiveStatus': true});
      expect(export.samples[1]['Depth'], 5.0);
    });

    test('converts gas percentages to fractions and drops unused gases', () {
      final export = SuuntoSmlNormalizer.parse(_cloudFixture());
      final gases = export.header['Diving']['Gases'] as List;

      expect(gases, hasLength(1));
      expect(gases[0]['Oxygen'], 0.21);
      expect(gases[0]['Helium'], 0.0);
      expect(gases[0]['TankSize'], 0.012);
    });

    test('rescales a bare-bar pressure value into Pa', () {
      final fixture = _cloudFixture();
      final diveHeader =
          (((fixture['Summary'] as Map)['Samples'] as List)[1]
                  as Map)['Attributes']['suunto/sml']['DiveHeader']
              as Map;
      (diveHeader['Gases'] as List)[0]['StartPressure'] = 232;

      final export = SuuntoSmlNormalizer.parse(fixture);
      final gases = export.header['Diving']['Gases'] as List;
      expect(gases[0]['StartPressure'], 23200000);
    });

    test('carries gradient factors through when present', () {
      final export = SuuntoSmlNormalizer.parse(_cloudFixture());
      expect(export.header['Diving']['GfLow'], 30);
      expect(export.header['Diving']['GfHigh'], 85);
    });

    test('omits Diving.Gases when no gas has a filled tank', () {
      final fixture = _cloudFixture();
      (((fixture['Summary'] as Map)['Samples'] as List)[1]
          as Map)['Attributes']['suunto/sml']['DiveHeader'] = {
        'Gases': [
          {'Oxygen': 21, 'Helium': 0, 'TankSize': 0},
        ],
      };

      final export = SuuntoSmlNormalizer.parse(fixture);
      expect(export.header.containsKey('Diving'), isFalse);
    });
  });

  group('SuuntoSmlNormalizer.parse (app DeviceLog shape)', () {
    test('reads the flat DeviceLog.Header/Samples shape directly', () {
      final json = {
        'DeviceLog': {
          'Header': {'ActivityType': 51, 'DateTime': '2024-05-01T10:00:00Z'},
          'Samples': [
            {'TimeISO8601': '2024-05-01T10:00:00Z', 'Depth': 1.0},
          ],
        },
      };

      final export = SuuntoSmlNormalizer.parse(json);
      expect(export.header['ActivityType'], 51);
      expect(export.samples, hasLength(1));
      expect(export.samples[0]['Depth'], 1.0);
    });
  });

  group('SuuntoSmlNormalizer.parse error cases', () {
    test('throws when neither shape is recognizable', () {
      expect(
        () => SuuntoSmlNormalizer.parse({'unrelated': true}),
        throwsA(isA<SuuntoApiException>()),
      );
    });

    test('throws when the activity type is not scuba diving (51)', () {
      final json = {
        'DeviceLog': {
          'Header': {'ActivityType': 3},
          'Samples': <Map<String, dynamic>>[],
        },
      };

      expect(
        () => SuuntoSmlNormalizer.parse(json),
        throwsA(
          isA<SuuntoApiException>().having(
            (e) => e.message,
            'message',
            contains('ActivityType=3'),
          ),
        ),
      );
    });
  });
}
