import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/util/site_time_zone.dart';

void main() {
  group('SiteTimeZone.zoneIdFor', () {
    final fixture =
        json.decode(
              File(
                p.join(
                  'test',
                  'core',
                  'util',
                  'fixtures',
                  'tz_lookup_parity.json',
                ),
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final points = (fixture['points'] as List).cast<Map<String, dynamic>>();

    test('matches upstream tz.js at every fixture point', () {
      expect(points.length, greaterThan(200));
      for (final point in points) {
        expect(
          SiteTimeZone.zoneIdFor(
            (point['lat'] as num).toDouble(),
            (point['lon'] as num).toDouble(),
          ),
          point['zone'],
          reason: '${point['name']} (${point['lat']}, ${point['lon']})',
        );
      }
    });

    test('invalid coordinates fall back to a longitude zone', () {
      expect(SiteTimeZone.zoneIdFor(95.0, -68.0), 'Etc/GMT+5');
      expect(SiteTimeZone.zoneIdFor(10.0, 200.0), 'Etc/GMT-12');
      expect(SiteTimeZone.zoneIdFor(double.nan, double.nan), 'Etc/GMT');
    });
  });
}
