import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_cleanup.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';

import '../../../helpers/temp_dir.dart';
import 'identification_fixtures.dart';

void main() {
  late AppDatabase library;
  late LocalCacheDatabase local;
  late Directory support;
  late MediaIdentificationRepository identifications;
  late IdentificationEmbeddingRepository embeddings;
  late IdentificationCropStore crops;
  late IdentificationCleanup cleanup;

  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

  setUp(() async {
    library = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    local = LocalCacheDatabase(NativeDatabase.memory());
    support = await Directory.systemTemp.createTemp('cleanup_test');
    identifications = MediaIdentificationRepository(database: library);
    embeddings = IdentificationEmbeddingRepository(database: local);
    crops = IdentificationCropStore(supportPath: () async => support.path);
    cleanup = IdentificationCleanup(
      identifications: identifications,
      embeddings: embeddings,
      crops: crops,
    );
  });
  tearDown(() async {
    await library.close();
    await local.close();
    await deleteTempDir(support);
  });

  Future<void> seed(String mediaId, String identificationId) async {
    await identifications.storeRun(
      run(mediaId: mediaId),
      insert: [identification(identificationId, mediaId: mediaId)],
      deleteIds: const [],
    );
    await embeddings.put({
      identificationId: Float32List.fromList([1, 0, 0]),
    }, classifierId: 'clf');
    await crops.write(mediaId, identificationId, jpeg);
  }

  Future<void> addMedia(String id) => library
      .into(library.media)
      .insert(
        MediaCompanion.insert(id: id, filePath: '', createdAt: 0, updatedAt: 0),
      );

  test('a delete held for undo removes nothing', () async {
    await seed('m1', 'i1');
    await cleanup.onMediaDeleted(['m1'], undoable: true);

    expect(await identifications.forMedia('m1'), hasLength(1));
    expect(await embeddings.get(['i1'], classifierId: 'clf'), hasLength(1));
    expect(await crops.allPresent('m1', ['i1']), isTrue);
  });

  test('a final delete removes rows, embeddings and crops', () async {
    await seed('m1', 'i1');
    await seed('m2', 'i2');
    await cleanup.onMediaDeleted(['m1'], undoable: false);

    expect(await identifications.forMedia('m1'), isEmpty);
    expect(await identifications.runFor('m1'), isNull);
    expect(await embeddings.get(['i1'], classifierId: 'clf'), isEmpty);
    expect(await crops.allPresent('m1', ['i1']), isFalse);
    expect(await identifications.forMedia('m2'), hasLength(1));
  });

  test('the sweep removes what belongs to media that is gone', () async {
    await addMedia('m-live');
    await seed('m-live', 'i1');
    await seed('m-gone', 'i2');

    expect(await cleanup.sweepOrphans(), 1);

    expect(await identifications.forMedia('m-live'), hasLength(1));
    expect(await identifications.forMedia('m-gone'), isEmpty);
    expect(await embeddings.get(['i2'], classifierId: 'clf'), isEmpty);
    expect(await crops.allPresent('m-gone', ['i2']), isFalse);
    expect(await crops.allPresent('m-live', ['i1']), isTrue);
  });

  test('clearing removes this logbook\'s suggestions and keeps what '
      'another logbook on the device owns', () async {
    await seed('m1', 'i1');
    // Another logbook's photo: a crop and an embedding, no rows here.
    await crops.write('m-other', 'i-other', jpeg);
    await embeddings.put({
      'i-other': Float32List.fromList([0, 1, 0]),
    }, classifierId: 'clf');

    await cleanup.clearAll();

    expect(await identifications.count(), 0);
    expect(await embeddings.get(['i1'], classifierId: 'clf'), isEmpty);
    expect(await crops.allPresent('m1', ['i1']), isFalse);
    expect(await crops.allPresent('m-other', ['i-other']), isTrue);
    expect(
      await embeddings.get(['i-other'], classifierId: 'clf'),
      hasLength(1),
    );
  });

  test('a failure does not escape a deletion hook', () async {
    await library.close();
    await expectLater(
      cleanup.onMediaDeleted(['m1'], undoable: false),
      completes,
    );
    library = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
  });

  test('embeddings round trip through half precision', () async {
    await embeddings.put({
      'x': Float32List.fromList([0.5, -0.25, 1]),
    }, classifierId: 'clf');
    final back = await embeddings.get(['x'], classifierId: 'clf');
    expect(back['x'], [0.5, -0.25, 1.0]);
    expect(await embeddings.get(['x'], classifierId: 'other'), isEmpty);
  });

  test('more ids than SQLite takes in one statement are deleted in '
      'slices', () async {
    final many = [for (var i = 0; i < 40000; i++) 'gone-$i'];
    await expectLater(
      identifications.deleteForMedia(many),
      completion(isEmpty),
    );
    await expectLater(embeddings.delete(many), completes);
    expect(await embeddings.get(many, classifierId: 'clf'), isEmpty);
  });
}
