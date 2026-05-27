import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_sqlite_parser.dart';

import '../../../../fixtures/macdive_sqlite/build_synthetic_db.dart';

void main() {
  test('MacDiveSqliteParser emits imageRefs from ZDIVEIMAGE', () async {
    final path =
        '${Directory.systemTemp.path}/msp_${DateTime.now().microsecondsSinceEpoch}.sqlite';
    final dbFile = buildSyntheticMacDiveDb(path);
    addTearDown(() {
      if (dbFile.existsSync()) dbFile.deleteSync();
    });

    final payload = await const MacDiveSqliteParser().parse(
      Uint8List.fromList(await dbFile.readAsBytes()),
    );

    expect(payload.imageRefs.length, 3);
    final shark = payload.imageRefs.firstWhere((r) => r.caption == 'Shark!');
    expect(shark.originalPath, '/Users/test/Pictures/Diving/shark.jpg');
    expect(shark.diveSourceUuid, isNotEmpty);
  });
}
