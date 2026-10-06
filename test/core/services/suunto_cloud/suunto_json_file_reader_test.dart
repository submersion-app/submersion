import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/suunto_cloud/suunto_json_file_reader.dart';

/// A minimal Suunto app "export as JSON" (the DeviceLog shape) with two
/// samples, both carrying DiveRoute.
Uint8List deviceLogBytes({int activityType = 51}) => utf8.encode(
  jsonEncode({
    'DeviceLog': {
      'Header': {
        'DateTime': '2026-04-19T13:44:00.000+02:00',
        'ActivityType': activityType,
        'Device': {'Name': 'Ylivieska', 'SerialNumber': 'NS-1'},
        'DiveTime': 60,
      },
      'Samples': [
        {
          'TimeISO8601': '2026-04-19T13:44:00.000+02:00',
          'Depth': 1.0,
          'DiveEvents': {'DiveStatus': true},
          'DiveRouteOrigin': {'Latitude': 47.3, 'Longitude': -2.9},
          'DiveRoute': {'X': 0.0, 'Y': 0.0, 'Z': 1.0},
        },
        {
          'TimeISO8601': '2026-04-19T13:44:01.000+02:00',
          'Depth': 2.0,
          'DiveRoute': {'X': 0.5, 'Y': 0.8, 'Z': 2.0},
        },
      ],
    },
  }),
);

SuuntoFileReadResult _read(List<int> bytes) => readSuuntoJsonFile(
  SuuntoJsonFile(name: 'dive.json', bytes: Uint8List.fromList(bytes)),
);

void main() {
  test('reads an app export into a dive with its route', () {
    final result = _read(deviceLogBytes());

    expect(result.rejection, isNull);
    expect(result.dive!.route!.points, hasLength(2));
    expect(result.file.name, 'dive.json');
  });

  test('reads a file that starts with a UTF-8 byte order mark', () {
    final result = _read([0xEF, 0xBB, 0xBF, ...deviceLogBytes()]);

    expect(result.dive, isNotNull);
  });

  test('rejects bytes that are not JSON', () {
    final result = _read(utf8.encode('not json'));

    expect(result.rejection, SuuntoFileRejection.notJson);
    expect(result.dive, isNull);
  });

  test('rejects JSON from another app', () {
    final result = _read(utf8.encode('{"type":"FeatureCollection"}'));

    expect(result.rejection, SuuntoFileRejection.notSuuntoExport);
  });

  test('rejects a JSON array', () {
    expect(
      _read(utf8.encode('[1,2]')).rejection,
      SuuntoFileRejection.notSuuntoExport,
    );
  });

  test('rejects a Suunto export of another activity as not a dive', () {
    expect(
      _read(deviceLogBytes(activityType: 3)).rejection,
      SuuntoFileRejection.notADive,
    );
  });

  test('rejects a DeviceLog whose values have the wrong shape', () {
    final bytes = utf8.encode(
      jsonEncode({
        'DeviceLog': {
          'Header': {'ActivityType': 51},
          'Samples': 'oops',
        },
      }),
    );

    expect(_read(bytes).rejection, SuuntoFileRejection.notSuuntoExport);
  });

  // jsonDecode reads 1e400 as Infinity, and rounding it throws an
  // UnsupportedError deep in the parser: any unexpected failure must still
  // come back as a skipped file, never escape and stall the file step.
  test('turns an unexpected parser failure into a skipped file', () {
    final bytes = utf8.encode(
      '{"DeviceLog":{"Header":{"ActivityType":51,"DiveTime":1e400},'
      '"Samples":[]}}',
    );

    expect(_read(bytes).rejection, SuuntoFileRejection.notSuuntoExport);
  });
}
