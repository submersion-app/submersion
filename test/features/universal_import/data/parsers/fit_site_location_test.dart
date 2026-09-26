import 'dart:typed_data';

import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/fit_import_parser.dart';

/// FIT's share of the shared location contract (#2232).
///
/// FIT is the one registered format that carries a position without ever
/// building a site, so the dive's own fix is all there is. It must be judged
/// by the same rule a site's coordinates are, or a dive with no usable fix
/// still persists an entry location.
void main() {
  Uint8List fitBytes({double? lat, double? lon}) {
    final builder = FitFileBuilder(autoDefine: true, minStringSize: 50);
    final start = DateTime.utc(2025, 10, 13, 11, 24, 0);

    builder.add(
      FileIdMessage()
        ..type = FileType.activity
        ..manufacturer = 1
        ..product = 4223
        ..serialNumber = 3502016516
        ..timeCreated = start.millisecondsSinceEpoch,
    );
    builder.add(
      RecordMessage()
        ..timestamp = start.millisecondsSinceEpoch
        ..depth = 12.0,
    );
    builder.add(
      SessionMessage()
        ..sport = Sport.diving
        ..timestamp = start
            .add(const Duration(seconds: 3600))
            .millisecondsSinceEpoch
        ..startTime = start.millisecondsSinceEpoch
        ..totalElapsedTime = 3600.0
        ..totalTimerTime = 3600.0
        ..startPositionLat = lat
        ..startPositionLong = lon,
    );

    return builder.build().toBytes();
  }

  Future<Map<String, dynamic>> diveFrom(Uint8List bytes) async {
    final payload = await const FitImportParser().parse(bytes);
    return payload.entities[ImportEntityType.dives]!.single;
  }

  test('a usable fix becomes the dive\'s entry coordinates', () async {
    final dive = await diveFrom(fitBytes(lat: 20.2114, lon: -87.4654));

    expect(dive['latitude'], closeTo(20.2114, 1e-3));
    expect(dive['longitude'], closeTo(-87.4654, 1e-3));
  });

  test('a 0/0 fix is not persisted as a location', () async {
    final dive = await diveFrom(fitBytes(lat: 0, lon: 0));

    expect(dive['latitude'], isNull);
    expect(dive['longitude'], isNull);
  });

  test('a dive with no fix at all carries no coordinates', () async {
    final dive = await diveFrom(fitBytes());

    expect(dive.containsKey('latitude'), isFalse);
  });
}
