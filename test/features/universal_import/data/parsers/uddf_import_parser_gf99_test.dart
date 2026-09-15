import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

/// The universal import wizard reads UDDF through [UddfImportParser]; the
/// per-waypoint GF99 has to survive that path to reach the entity importer.
const _petrel3 = 'test/dives/006_ccr_petrel3_shearwater-cloud-export.uddf';

void main() {
  test('carries the waypoint GF99 as gf99 on the dive samples', () async {
    final payload = await UddfImportParser().parse(
      Uint8List.fromList(File(_petrel3).readAsBytesSync()),
    );

    final dives = payload.entities[ImportEntityType.dives]!;
    expect(dives, hasLength(1));
    final profile = dives.single['profile'] as List<Map<String, dynamic>>;
    final values = profile.map((p) => p['gf99']).whereType<int>().toList();

    expect(values.length, greaterThan(100));
    expect(values.every((v) => v >= 0 && v <= 200), isTrue);
    expect(values.last, 59);
  });
}
