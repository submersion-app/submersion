import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/species_id/data/repositories/identification_crop_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/named_crop_backfill.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';

import '../../../helpers/temp_dir.dart';
import '../../../helpers/test_database.dart';
import 'identification_fixtures.dart';

/// The crops of named identifications sync with the logbook (issue #4876);
/// unnamed ones stay files on the device that analysed them.
void main() {
  late Directory support;
  late IdentificationCropRepository table;
  late IdentificationCropStore store;
  late MediaIdentificationRepository identifications;
  final sync = SyncRepository();
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 1, 2, 0xFF, 0xD9]);

  setUp(() async {
    await setUpTestDatabase();
    support = await Directory.systemTemp.createTemp('named_crops');
    // The app's own logbook: writes publish.
    table = IdentificationCropRepository();
    store = IdentificationCropStore(
      supportPath: () async => support.path,
      table: table,
    );
    identifications = MediaIdentificationRepository();
  });
  tearDown(() async {
    await store.dispose();
    await deleteTempDir(support);
    await tearDownTestDatabase();
  });

  Future<bool> fileExists(String mediaId, String id) async =>
      (await store.fileFor(mediaId, id)).exists();

  Future<Set<String>> pendingCrops() async => {
    for (final r in await sync.getPendingRecords())
      if (r.entityType == 'mediaIdentificationCrops') r.recordId,
  };

  Future<Set<String>> cropTombstones() async => {
    for (final d in await sync.getAllDeletions())
      if (d.entityType == 'mediaIdentificationCrops') d.recordId,
  };

  test('isNamed: something in particular, suggested, or said by the diver', () {
    final unnamed = identification(
      'u',
    ).copyWith(suggestable: false, specific: false);
    expect(isNamed(unnamed), isFalse);
    expect(isNamed(unnamed.copyWith(specific: true)), isTrue);
    expect(isNamed(unnamed.copyWith(suggestable: true)), isTrue);
    expect(isNamed(unnamed.copyWith(claimedSpeciesId: () => 'sp1')), isTrue);
    expect(
      isNamed(unnamed.copyWith(decision: IdentificationDecision.rejected)),
      isTrue,
    );
  });

  test('a named crop goes to the logbook, published; an unnamed one is a '
      'file', () async {
    await store.write('m1', 'named', jpeg, named: true);
    await store.write('m1', 'plain', jpeg);

    expect(await table.bytesFor('named'), jpeg);
    expect(await fileExists('m1', 'named'), isFalse);
    expect(await table.bytesFor('plain'), isNull);
    expect(await fileExists('m1', 'plain'), isTrue);
    expect(await pendingCrops(), {'named'});
  });

  test('read finds a crop in either place', () async {
    await store.write('m1', 'named', jpeg, named: true);
    await store.write('m1', 'plain', jpeg);
    expect(await store.read('m1', 'named'), isA<CropBytes>());
    expect(await store.read('m1', 'plain'), isA<CropFile>());
    expect(await store.read('m1', 'missing'), isNull);
    expect(await store.allPresent('m1', ['named', 'plain']), isTrue);
    expect(await store.allPresent('m1', ['named', 'missing']), isFalse);
  });

  test('promote moves a file crop into the logbook once', () async {
    await identifications.storeRun(
      run(),
      insert: [identification('a')],
      deleteIds: const [],
    );
    await store.write('m1', 'a', jpeg);
    expect(await store.promote('m1', ['a', 'missing']), 1);
    expect(await table.bytesFor('a'), jpeg);
    expect(await fileExists('m1', 'a'), isFalse);
    expect(await store.promote('m1', ['a']), 0);
  });

  test('promote leaves a crop whose identification a sync has deleted since '
      'the rows were read: it never comes back as a synced crop', () async {
    await store.write('m1', 'gone', jpeg);

    expect(await store.promote('m1', ['gone']), 0);
    expect(await table.bytesFor('gone'), isNull);
    expect(await pendingCrops(), isEmpty);
  });

  test('deleting crops tombstones the synced ones only', () async {
    await store.write('m1', 'named', jpeg, named: true);
    await store.write('m1', 'plain', jpeg);
    await store.delete('m1', ['named', 'plain']);
    expect(await table.bytesFor('named'), isNull);
    expect(await fileExists('m1', 'plain'), isFalse);
    expect(await cropTombstones(), {'named'});
  });

  test('deleting a media\'s crops removes the synced ones too', () async {
    await store.write('m1', 'named', jpeg, named: true);
    await store.deleteMedia(['m1']);
    expect(await table.bytesFor('named'), isNull);
    expect(await cropTombstones(), {'named'});
  });

  group('the backfill', () {
    Future<void> storeRows(String mediaId, {String? madeBy}) async {
      await identifications.storeRun(
        run(mediaId: mediaId).copyWith(analysedBy: () => madeBy),
        insert: [
          identification('$mediaId-s', mediaId: mediaId),
          identification(
            '$mediaId-u',
            mediaId: mediaId,
          ).copyWith(suggestable: false, specific: false),
          identification(
            '$mediaId-d',
            mediaId: mediaId,
            decision: IdentificationDecision.accepted,
          ).copyWith(suggestable: false),
        ],
        deleteIds: const [],
      );
      for (final suffix in ['s', 'u', 'd']) {
        await store.write(mediaId, '$mediaId-$suffix', jpeg);
      }
    }

    test('moves this device\'s named crops into the logbook, and is safe to '
        'run again', () async {
      await storeRows('m1');
      final backfill = NamedCropBackfill(
        identifications: identifications,
        crops: store,
        deviceId: () async => null,
      );

      expect(await backfill.run(), 2);
      expect(await table.bytesFor('m1-s'), jpeg);
      expect(await table.bytesFor('m1-d'), jpeg);
      expect(await fileExists('m1', 'm1-u'), isTrue);
      expect(await backfill.run(), 0);
    });

    test('publishes a synced crop whose mark was lost, as no sync backfill '
        'covers crops', () async {
      // Written with no marks: as when marking failed after the write.
      await IdentificationCropRepository(
        database: DatabaseService.instance.database,
      ).put('lost', 'm9', jpeg);
      expect(await pendingCrops(), isEmpty);

      await NamedCropBackfill(
        identifications: identifications,
        crops: store,
        deviceId: () async => null,
      ).run();

      expect(await pendingCrops(), {'lost'});
    });

    test('leaves runs another device made', () async {
      await storeRows('m2', madeBy: 'laptop');
      final moved = await NamedCropBackfill(
        identifications: identifications,
        crops: store,
        deviceId: () async => 'phone',
      ).run();
      expect(moved, 0);
    });
  });

  test('in a browser only the synced crops are read, and no file is '
      'touched', () async {
    final browser = IdentificationCropStore(
      // A support folder a browser does not have: reaching it fails.
      supportPath: () async => throw UnsupportedError('no files'),
      table: table,
      files: false,
    );
    addTearDown(browser.dispose);
    await table.put('named', 'm1', jpeg);

    expect(await browser.read('m1', 'named'), isA<CropBytes>());
    expect(await browser.read('m1', 'plain'), isNull);
    expect(await browser.allPresent('m1', ['named']), isTrue);
    expect(await browser.wasAnalysedHere('m1'), isFalse);
    expect(await browser.sizeBytes(), 0);
    await browser.delete('m1', ['named']);
    expect(await table.bytesFor('named'), isNull);
  });
}
