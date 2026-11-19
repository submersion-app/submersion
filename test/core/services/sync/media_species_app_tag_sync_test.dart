import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';

import '../../../features/media/data/repositories/species_photo_fixtures.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/peer_pull.dart';
import '../../../helpers/test_database.dart';

/// The marks on a species tag the app applied travel with the tag (issue
/// #4727). Confirming clears them to null on one device; the merge applies
/// tags with nulls dropped, so the clear must land the way a parent-gated
/// child's does (#2644): from a strictly newer copy only.
void main() {
  late FakeCloudStorageProvider cloud;
  late Map<String, dynamic> local;
  late Hlc localHlc;
  late String tagId;

  setUp(() async {
    await setUpTestDatabase();
    cloud = FakeCloudStorageProvider();
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10));
    await insertTestSpecies(id: 'c1', name: 'Grouper');
    await insertTestMedia(id: 'p1', diveId: 'd1');
    final tag = await MediaSpeciesRepository().addTag(
      mediaId: 'p1',
      speciesId: 'c1',
      unconfirmed: true,
      createdSighting: true,
    );
    tagId = tag.id;
    local = (await SyncDataSerializer().fetchRecord('mediaSpecies', tagId))!;
    localHlc = Hlc.parse(local['hlc'] as String);
    // This device has published; what follows is a peer's payload.
    await SyncRepository().clearAllSyncRecords();
  });
  tearDown(() {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  Future<Map<String, dynamic>> pull(Map<String, dynamic> theirs) async {
    final result = await pullPeerPayload(
      cloud,
      SyncData(mediaSpecies: [theirs]),
    );
    expect(result.status, isNot(SyncResultStatus.error));
    return (await SyncDataSerializer().fetchRecord('mediaSpecies', tagId))!;
  }

  Hlc shifted(int ms) =>
      Hlc(localHlc.physicalTime + ms, localHlc.counter, 'peer-b');

  test('the export carries the marks', () {
    expect(local['unconfirmed'], 1);
    expect(local['createdSighting'], 1);
    expect(local['createdSpecies'], isNull);
  });

  test('a newer confirmed copy clears the marks', () async {
    final row = await pull({
      ...local,
      'unconfirmed': null,
      'createdSighting': null,
      'createdSpecies': null,
      'hlc': shifted(1000).toString(),
    });
    expect(row['unconfirmed'], isNull);
    expect(row['createdSighting'], isNull);
  });

  test('a newer copy clears only the marks: the tag\'s notes, box and '
      'sighting stay', () async {
    final db = DatabaseService.instance.database;
    await insertTestSighting(id: 'sg1', diveId: 'd1', speciesId: 'c1');
    await (db.update(db.mediaSpecies)..where((t) => t.id.equals(tagId))).write(
      const MediaSpeciesCompanion(
        notes: Value('by the wreck'),
        bboxX: Value(0.2),
        sightingId: Value('sg1'),
      ),
    );

    final row = await pull({
      ...local,
      'unconfirmed': null,
      'createdSighting': null,
      'notes': null,
      'bboxX': null,
      'sightingId': null,
      'hlc': shifted(1000).toString(),
    });

    expect(row['unconfirmed'], isNull);
    expect(row['notes'], 'by the wreck');
    expect(row['bboxX'], 0.2);
    expect(row['sightingId'], 'sg1');
  });

  test('a newer unconfirmed copy marks a tag this device has', () async {
    await MediaSpeciesRepository().confirmTag(mediaId: 'p1', speciesId: 'c1');
    final confirmed = (await SyncDataSerializer().fetchRecord(
      'mediaSpecies',
      tagId,
    ))!;
    await SyncRepository().clearAllSyncRecords();
    final row = await pull({
      ...confirmed,
      'unconfirmed': 1,
      'hlc': Hlc(
        Hlc.parse(confirmed['hlc'] as String).physicalTime + 1000,
        0,
        'peer-b',
      ).toString(),
    });
    expect(row['unconfirmed'], 1);
  });

  test('a copy that omits the keys keeps the marks', () async {
    final theirs = {...local, 'hlc': shifted(1000).toString()}
      ..remove('unconfirmed')
      ..remove('createdSighting')
      ..remove('createdSpecies');
    final row = await pull(theirs);
    expect(row['unconfirmed'], 1);
    expect(row['createdSighting'], 1);
  });

  test('an exact tie keeps the marks', () async {
    final row = await pull({...local, 'unconfirmed': null});
    expect(row['unconfirmed'], 1);
  });

  test('a strictly older confirmed copy is skipped', () async {
    final row = await pull({
      ...local,
      'unconfirmed': null,
      'hlc': shifted(-1000).toString(),
    });
    expect(row['unconfirmed'], 1);
  });
}
