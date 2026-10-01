import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';
import 'package:submersion/features/universal_import/data/services/tank_pressure_glitch_normalizer.dart';

/// Issue #2687: a UDDF dive whose `tankpressureend` holds 0.34 bar while its
/// `tankpressurebegin` and its own pressure series are normal must not import
/// that end pressure as-is.
void main() {
  /// One tank whose header starts at 200 bar and ends at [endPa]; with
  /// [withSeries] its own series drains from 200 bar to 84 bar.
  String uddf({required int endPa, bool withSeries = true}) {
    final waypoints = StringBuffer();
    for (var t = 0; t <= 2400; t += 60) {
      final bar = 200 - t * (116 / 2400);
      waypoints.writeln('''
          <waypoint>
            <depth>${t == 0 || t == 2400 ? 0.5 : 18}</depth>
            <divetime>$t</divetime>
            ${withSeries ? '<tankpressure ref="tank-1">${(bar * 100000).round()}</tankpressure>' : ''}
          </waypoint>''');
    }
    return '''
<uddf version="3.2.3">
  <profiledata>
    <repetitiongroup>
      <dive id="dive-1">
        <informationbeforedive>
          <datetime>2026-05-01T10:00:00Z</datetime>
        </informationbeforedive>
        <tankdata id="tank-1">
          <tankpressurebegin>20000000</tankpressurebegin>
          <tankpressureend>$endPa</tankpressureend>
        </tankdata>
        <samples>
$waypoints
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';
  }

  Future<Map<String, dynamic>> importTank(String content) async {
    final parsed = await UddfImportParser().parse(
      Uint8List.fromList(utf8.encode(content)),
    );
    final payload = replaceGlitchedTankPressures(parsed);
    final dive = payload.entitiesOf(ImportEntityType.dives).single;
    return (dive['tanks'] as List).single as Map<String, dynamic>;
  }

  test('a near-zero end takes the series reading at the end', () async {
    final tank = await importTank(uddf(endPa: 34000));
    expect(tank['startPressure'], closeTo(200, 1e-9));
    expect(tank['endPressure'], closeTo(84, 1e-6));
  });

  test('a near-zero end with no series is cleared', () async {
    final tank = await importTank(uddf(endPa: 46000, withSeries: false));
    expect(tank['startPressure'], closeTo(200, 1e-9));
    expect(tank['endPressure'], isNull);
  });

  test('a plausible end is imported as the source reported it', () async {
    final tank = await importTank(uddf(endPa: 8500000));
    expect(tank['endPressure'], closeTo(85, 1e-9));
  });
}
