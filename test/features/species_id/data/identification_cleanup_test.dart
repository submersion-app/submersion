import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/species_id/data/repositories/identification_crop_repository.dart';
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
    await library.customStatement(
      'INSERT INTO deletion_log (id, entity_type, record_id, deleted_at) '
      "VALUES ('t1', 'media', 'm-gone', 1)",
    );

    expect(await cleanup.sweepOrphans(), 1);

    expect(await identifications.forMedia('m-live'), hasLength(1));
    expect(await identifications.forMedia('m-gone'), isEmpty);
    expect(await embeddings.get(['i2'], classifierId: 'clf'), isEmpty);
    expect(await crops.allPresent('m-gone', ['i2']), isFalse);
    expect(await crops.allPresent('m-live', ['i1']), isTrue);
  });

  test('the sweep keeps rows whose media has not arrived yet (issue #4876, '
      'Review Focus 4)', () async {
    await seed('m-on-its-way', 'i3');
    // As a run synced from another device arrives: with its maker.
    await identifications.storeRun(
      run(mediaId: 'm-on-its-way').copyWith(analysedBy: () => 'laptop'),
      insert: const [],
      deleteIds: const [],
    );
    expect(await cleanup.sweepOrphans(), 0);
    expect(await identifications.forMedia('m-on-its-way'), hasLength(1));
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

  test('a purge whose embeddings cannot be reached still removes the synced '
      'crops (issue #4876)', () async {
    final table = IdentificationCropRepository(database: library);
    final withTable = IdentificationCropStore(
      supportPath: () async => support.path,
      table: table,
    );
    addTearDown(withTable.dispose);
    await seed('m1', 'i1');
    await withTable.write('m1', 'i1', jpeg, named: true);
    await local.close();
    final broken = IdentificationCleanup(
      identifications: identifications,
      embeddings: IdentificationEmbeddingRepository(database: local),
      crops: withTable,
    );
    await broken.onMediaDeleted(['m1'], undoable: false);
    expect(await table.bytesFor('i1'), isNull);
  });

  group('identifications another device deleted (issue #4890)', () {
    final vector = Float32List.fromList([1, 0, 0]);

    /// Two identifications on [mediaId], each with a crop file and an
    /// embedding.
    Future<void> seedTwo(String mediaId) async {
      await identifications.storeRun(
        run(mediaId: mediaId, count: 2),
        insert: [
          identification('i1', mediaId: mediaId),
          identification('i2', mediaId: mediaId),
        ],
        deleteIds: const [],
      );
      await embeddings.put({'i1': vector, 'i2': vector}, classifierId: 'clf');
      await crops.write(mediaId, 'i1', jpeg);
      await crops.write(mediaId, 'i2', jpeg);
    }

    /// What applying a peer's tombstone leaves: no row, and the tombstone
    /// logged.
    Future<void> deletedByPeer(String id) async {
      await library.customStatement(
        'DELETE FROM media_identifications WHERE id = ?',
        [id],
      );
      await library.customStatement(
        'INSERT INTO deletion_log (id, entity_type, record_id, deleted_at) '
        "VALUES (?, 'mediaIdentifications', ?, 1)",
        ['t-$id', id],
      );
    }

    test('a deletion sync applied removes the crop file and embedding, '
        'and keeps the rest of the photo', () async {
      await seedTwo('m1');
      await deletedByPeer('i1');

      await cleanup.onDeletedBySync([(mediaId: 'm1', id: 'i1')]);

      expect(await crops.allPresent('m1', ['i1']), isFalse);
      expect(await embeddings.get(['i1'], classifierId: 'clf'), isEmpty);
      expect(await crops.allPresent('m1', ['i2']), isTrue);
      expect(await embeddings.get(['i2'], classifierId: 'clf'), hasLength(1));
    });

    test('a named crop in the logbook is left to the peer\'s own '
        'tombstone', () async {
      final table = IdentificationCropRepository(database: library);
      final withTable = IdentificationCropStore(
        supportPath: () async => support.path,
        table: table,
      );
      addTearDown(withTable.dispose);
      final hooked = IdentificationCleanup(
        identifications: identifications,
        embeddings: embeddings,
        crops: withTable,
      );
      await seedTwo('m1');
      await withTable.write('m1', 'i1', jpeg, named: true);
      await deletedByPeer('i1');

      await hooked.onDeletedBySync([(mediaId: 'm1', id: 'i1')]);

      expect(await table.bytesFor('i1'), isNotNull);
      expect(await embeddings.get(['i1'], classifierId: 'clf'), isEmpty);
    });

    test('a deletion that committed with no tombstone logged still removes '
        'the leftovers', () async {
      await seedTwo('m1');
      await library.customStatement(
        "DELETE FROM media_identifications WHERE id = 'i1'",
      );

      await cleanup.onDeletedBySync([(mediaId: 'm1', id: 'i1')]);

      expect(await crops.allPresent('m1', ['i1']), isFalse);
      expect(await embeddings.get(['i1'], classifierId: 'clf'), isEmpty);
      expect(await crops.allPresent('m1', ['i2']), isTrue);
    });

    test('each identification\'s file is removed from its own photo', () async {
      await seedTwo('m1');
      await identifications.storeRun(
        run(mediaId: 'm2'),
        insert: [identification('i3', mediaId: 'm2')],
        deleteIds: const [],
      );
      await crops.write('m2', 'i3', jpeg);
      // A crop of m2 named like m1's: only m1's goes.
      await crops.write('m2', 'i1', jpeg);
      await deletedByPeer('i1');
      await deletedByPeer('i3');

      await cleanup.onDeletedBySync([
        (mediaId: 'm1', id: 'i1'),
        (mediaId: 'm2', id: 'i3'),
      ]);

      expect(await crops.allPresent('m1', ['i1']), isFalse);
      expect(await crops.allPresent('m2', ['i3']), isFalse);
      expect(await crops.allPresent('m1', ['i2']), isTrue);
      expect(await crops.allPresent('m2', ['i1']), isTrue);
    });

    test('a deletion whose apply rolled back removes nothing', () async {
      await seedTwo('m1');

      await cleanup.onDeletedBySync([(mediaId: 'm1', id: 'i1')]);

      expect(await crops.allPresent('m1', ['i1']), isTrue);
      expect(await embeddings.get(['i1'], classifierId: 'clf'), hasLength(1));
    });

    test('the launch sweep removes what an earlier sync left behind, and '
        'keeps files this logbook holds no tombstone for', () async {
      await addMedia('m1');
      await seedTwo('m1');
      await deletedByPeer('i1');
      // Another logbook's photo: a crop and an embedding, no rows here.
      await crops.write('m-other', 'i-other', jpeg);
      await embeddings.put({'i-other': vector}, classifierId: 'clf');

      expect(await cleanup.sweepOrphans(), 0);

      expect(await crops.allPresent('m1', ['i1']), isFalse);
      expect(await embeddings.get(['i1'], classifierId: 'clf'), isEmpty);
      expect(await crops.allPresent('m1', ['i2']), isTrue);
      expect(await crops.allPresent('m-other', ['i-other']), isTrue);
      expect(
        await embeddings.get(['i-other'], classifierId: 'clf'),
        hasLength(1),
      );
    });

    test('the launch sweep counts a photo known only by its run as this '
        'logbook\'s', () async {
      // Results synced in before the photo itself: a run, no media row.
      // Made on another device, so the orphan purge leaves it be.
      await identifications.storeRun(
        run(mediaId: 'm-later', count: 2).copyWith(analysedBy: () => 'laptop'),
        insert: [
          identification('i1', mediaId: 'm-later'),
          identification('i2', mediaId: 'm-later'),
        ],
        deleteIds: const [],
      );
      await crops.write('m-later', 'i1', jpeg);
      await crops.write('m-later', 'i2', jpeg);
      await deletedByPeer('i1');

      await cleanup.sweepOrphans();

      expect(await crops.allPresent('m-later', ['i1']), isFalse);
      expect(await crops.allPresent('m-later', ['i2']), isTrue);
    });

    test('the launch sweep keeps another logbook\'s crop even when this one '
        'holds a tombstone for its id', () async {
      // Sync logs a peer's tombstone whether or not the row was here.
      await deletedByPeer('i-other');
      await crops.write('m-other', 'i-other', jpeg);
      await embeddings.put({'i-other': vector}, classifierId: 'clf');

      await cleanup.sweepOrphans();

      expect(await crops.allPresent('m-other', ['i-other']), isTrue);
      expect(
        await embeddings.get(['i-other'], classifierId: 'clf'),
        hasLength(1),
      );
    });

    test('a failure does not escape the sync hook', () async {
      await library.close();
      await expectLater(
        cleanup.onDeletedBySync([(mediaId: 'm1', id: 'i1')]),
        completes,
      );
      library = AppDatabase(
        NativeDatabase.memory(setup: registerAppSqlFunctions),
      );
    });
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
