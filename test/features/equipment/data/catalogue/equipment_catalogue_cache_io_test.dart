import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/equipment/data/catalogue/equipment_catalogue_cache_io.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('ecat_cache_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('reads nothing before a copy is written', () async {
    expect(await readEquipmentCatalogueCache(supportDir: dir.path), isNull);
  });

  test('round-trips a downloaded copy', () async {
    await writeEquipmentCatalogueCache('{"a":1}', supportDir: dir.path);
    expect(await readEquipmentCatalogueCache(supportDir: dir.path), '{"a":1}');
    expect(
      File(
        p.join(dir.path, 'equipment_catalogue', 'equipment_catalogue.json'),
      ).existsSync(),
      isTrue,
    );
  });

  test('a later copy replaces the earlier one', () async {
    await writeEquipmentCatalogueCache('{"a":1}', supportDir: dir.path);
    await writeEquipmentCatalogueCache('{"a":2}', supportDir: dir.path);
    expect(await readEquipmentCatalogueCache(supportDir: dir.path), '{"a":2}');
  });
}
