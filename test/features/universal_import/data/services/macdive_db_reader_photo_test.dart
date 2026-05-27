import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/macdive_db_reader.dart';

import '../../../../fixtures/macdive_sqlite/build_synthetic_db.dart';

void main() {
  test('reads ZDIVEIMAGE rows into MacDiveRawLogbook.diveImages', () async {
    final path =
        '${Directory.systemTemp.path}/mdi_${DateTime.now().microsecondsSinceEpoch}.sqlite';
    final dbFile = buildSyntheticMacDiveDb(path);
    addTearDown(() {
      if (dbFile.existsSync()) dbFile.deleteSync();
    });

    final logbook = await MacDiveDbReader.readAll(
      Uint8List.fromList(await dbFile.readAsBytes()),
    );

    expect(logbook.diveImages.length, 3);
    final first = logbook.diveImages.firstWhere((i) => i.pk == 1);
    expect(first.caption, 'Shark!');
    expect(first.path, '/Users/test/Pictures/Diving/shark.jpg');
    expect(first.originalPath, '/old/Pictures/shark.jpg');
    expect(first.uuid, 'img-uuid-1');
    expect(first.diveFk, 1);
    expect(first.position, 0);

    final second = logbook.diveImages.firstWhere((i) => i.pk == 2);
    expect(second.caption, isNull);
    expect(second.originalPath, isNull);
  });
}
