import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/data/repositories/identification_crop_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';

import '../../../helpers/temp_dir.dart';
import '../../../helpers/test_database.dart';

/// Which crops a media item still has, and which media hold more than the
/// cap, read from both stores (issue #5032).
void main() {
  late Directory support;
  late IdentificationCropRepository table;
  late IdentificationCropStore store;
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 1, 2, 0xFF, 0xD9]);

  setUp(() async {
    await setUpTestDatabase();
    support = await Directory.systemTemp.createTemp('crop_presence');
    table = IdentificationCropRepository();
    store = IdentificationCropStore(
      supportPath: () async => support.path,
      table: table,
    );
  });
  tearDown(() async {
    await store.dispose();
    await deleteTempDir(support);
    await tearDownTestDatabase();
  });

  test('presentAmong finds files and synced crops', () async {
    await store.write('m1', 'file', jpeg);
    await store.write('m1', 'synced', jpeg, named: true);
    expect(await store.presentAmong('m1', ['file', 'synced', 'gone']), {
      'file',
      'synced',
    });
  });

  test('presentAmong reads a media\'s files with one listing, not one '
      'look per id', () async {
    await store.write('m1', 'a', jpeg);
    final ids = [for (var k = 0; k < 500; k++) 'gone$k', 'a'];
    expect(await store.presentAmong('m1', ids), {'a'});
    expect(await store.presentAmong('m9', ids), isEmpty);
  });

  test('presentAmong is empty for no ids', () async {
    expect(await store.presentAmong('m1', const []), isEmpty);
  });

  test('mediaWithMoreThan counts synced crops and files per media', () async {
    for (var k = 0; k < 4; k++) {
      await store.write('m1', 'a$k', jpeg, named: true);
    }
    for (var k = 0; k < 3; k++) {
      await store.write('m2', 'b$k', jpeg, named: true);
    }
    for (var k = 0; k < 4; k++) {
      await store.write('m3', 'c$k', jpeg);
    }
    await store.markAnalysed('m3');
    expect((await store.mediaWithMoreThan(3)).toSet(), {'m1', 'm3'});
    expect((await table.mediaWithMoreThan(3)).toSet(), {'m1'});
  });
}
