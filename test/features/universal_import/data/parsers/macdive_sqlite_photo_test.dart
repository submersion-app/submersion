import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_sqlite_parser.dart';

import '../../../../fixtures/macdive_sqlite/build_synthetic_db.dart';

void main() {
  test('MacDiveSqliteParser emits media entries from ZDIVEIMAGE', () async {
    final dir = Directory.systemTemp.createTempSync('msp_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final dbFile = buildSyntheticMacDiveDb(p.join(dir.path, 'msp.sqlite'));

    final payload = await const MacDiveSqliteParser().parse(
      Uint8List.fromList(await dbFile.readAsBytes()),
    );

    final media = payload.entitiesOf(ImportEntityType.media);
    expect(media, hasLength(3));
    final dives = payload.entitiesOf(ImportEntityType.dives);
    final shark = media.firstWhere((m) => m['caption'] == 'Shark!');
    expect(shark['filename'], '/Users/test/Pictures/Diving/shark.jpg');
    final diveIndex = shark['_diveIndex'] as int;
    expect(diveIndex, inInclusiveRange(0, dives.length - 1));
    // Every media entry points inside the dives list it was emitted with.
    for (final m in media) {
      expect(m['_diveIndex'], inInclusiveRange(0, dives.length - 1));
    }
  });
}
