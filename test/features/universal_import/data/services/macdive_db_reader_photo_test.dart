import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/universal_import/data/services/macdive_db_reader.dart';

import '../../../../fixtures/macdive_sqlite/build_synthetic_db.dart';

void main() {
  test('reads ZDIVEIMAGE rows into MacDiveRawLogbook.diveImages', () async {
    final dir = Directory.systemTemp.createTempSync('mdi_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final dbFile = buildSyntheticMacDiveDb(p.join(dir.path, 'mdi.sqlite'));

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

  test('a logbook without a ZDIVEIMAGE table reads with no images', () async {
    final dir = Directory.systemTemp.createTempSync('mdi_noimg_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final dbFile = buildSyntheticMacDiveDb(
      p.join(dir.path, 'mdi_noimg.sqlite'),
      includeDiveImages: false,
    );

    final logbook = await MacDiveDbReader.readAll(
      Uint8List.fromList(await dbFile.readAsBytes()),
    );

    expect(logbook.diveImages, isEmpty);
    expect(logbook.dives, isNotEmpty);
  });
}
