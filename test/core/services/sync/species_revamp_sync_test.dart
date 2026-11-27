import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Species covers and practice rows travel through every sync arm, newer
/// writes replace older ones by id, and a delete removes them (#5027).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('d1'),
            name: Value('Diver'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    await db
        .into(db.species)
        .insert(
          const SpeciesCompanion(
            id: Value('grouper'),
            commonName: Value('Grouper'),
            category: Value('fish'),
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> cover(
    String id, {
    String? mediaId = 'm1',
    String? hlc,
  }) => {
    'id': id,
    'diverId': 'd1',
    'speciesId': 'grouper',
    'mediaId': mediaId,
    'identificationId': 'i1',
    'createdAt': 1790000000000,
    'updatedAt': 1790000000000,
    'hlc': hlc,
  };

  Map<String, dynamic> practice(String id, {int box = 2, String? hlc}) => {
    'id': id,
    'diverId': 'd1',
    'speciesId': 'grouper',
    'box': box,
    'dueAt': 1790000000000,
    'rightCount': 3,
    'wrongCount': 1,
    'lastPractisedAt': 1789000000000,
    'createdAt': 1780000000000,
    'updatedAt': 1790000000000,
    'hlc': hlc,
  };

  test('SyncData carries both entities and base table keys', () {
    for (final key in ['speciesCovers', 'speciesPractice']) {
      expect(SyncDataSerializer.debugBaseTableKeys, contains(key));
      expect(const SyncData().toJson().keys, contains(key));
    }
    final data = SyncData.fromJson({
      'speciesCovers': [cover('sc_a')],
      'speciesPractice': [practice('spr_a')],
    });
    expect(data.speciesCovers, hasLength(1));
    expect(data.speciesPractice, hasLength(1));
  });

  test('a cover upserts, clears by update, fetches and deletes', () async {
    final s = SyncDataSerializer();
    await s.upsertRecord('speciesCovers', cover('sc_a'));
    expect((await s.fetchRecord('speciesCovers', 'sc_a'))!['mediaId'], 'm1');

    await s.upsertRecord('speciesCovers', cover('sc_a', mediaId: null));
    expect((await s.fetchRecord('speciesCovers', 'sc_a'))!['mediaId'], isNull);

    await s.deleteRecord('speciesCovers', 'sc_a');
    expect(await s.fetchRecord('speciesCovers', 'sc_a'), isNull);
  });

  test('practice rows batch upsert and round-trip every field', () async {
    final s = SyncDataSerializer();
    await s.upsertRecords('speciesPractice', [
      practice('spr_a'),
      practice('spr_b', box: 5),
    ]);
    final fetched = await s.fetchRecords('speciesPractice', ['spr_a', 'spr_b']);
    expect(fetched['spr_b']!['box'], 5);
    expect(fetched['spr_a']!['rightCount'], 3);
    expect(fetched['spr_a']!['lastPractisedAt'], 1789000000000);
    expect(await s.recordIdsFor('speciesPractice'), {'spr_a', 'spr_b'});
  });

  test('export after a clock carries only newer rows', () async {
    final s = SyncDataSerializer();
    await s.upsertRecord('speciesCovers', cover('sc_old', hlc: '0001'));
    await s.upsertRecord('speciesCovers', cover('sc_new', hlc: '0009'));
    await s.upsertRecord('speciesPractice', practice('spr_new', hlc: '0009'));
    final data = (await s.exportChangeset(
      deviceId: 'dev',
      hlcWatermark: '0005',
      deletions: const [],
    )).data;
    expect(data.speciesCovers.map((r) => r['id']), ['sc_new']);
    expect(data.speciesPractice.map((r) => r['id']), ['spr_new']);
  });
}
