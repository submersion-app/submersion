@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/suunto_cloud/suunto_crypto.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';

/// Suunto import compiled to JavaScript (issue #4194). `1 << 62` is zero
/// there, so no temperature reading was ever nearer than the starting
/// distance and every sample lost its temperature; and ByteData.setInt64
/// throws, so the cloud sign-in code could not be made.
void main() {
  test('a sample keeps the temperature read with it', () {
    final result = SuuntoDiveParser.parse(
      header: {
        'DateTime': '2024-05-01T10:00:00.000Z',
        'ActivityType': 51,
        'Device': {'Name': 'EON Steel', 'SerialNumber': 'SN123'},
        'Depth': {'Max': 5.0},
        'DiveTime': 20,
      },
      samples: [
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
      ],
    );
    expect(result.dive.profile[1].temperature, closeTo(296.5 - 273.15, 1e-9));
  });

  test('the sign-in code matches the desktop app', () async {
    final code = await SuuntoCrypto.generateTotp(
      'diver@example.com',
      nowMs: 1700000000000,
    );
    expect(code, '953479');
  });
}
