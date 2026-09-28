import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// A saved Connections map travels through every per-record sync arm
/// unchanged (issue #2322).
void main() {
  setUp(() async {
    await setUpTestDatabase();
    final d = DatabaseService.instance.database;
    await d
        .into(d.divers)
        .insert(
          const db.DiversCompanion(
            id: Value('me'),
            name: Value('Me'),
            createdAt: Value(1),
            updatedAt: Value(1),
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> row(String id, {String name = 'Bonaire 2025'}) => {
    'id': id,
    'diverId': 'me',
    'name': name,
    'spec': '{"kinds":["buddy","site"],"links":["buddy-site"],"min":1}',
    'sortOrder': 0,
    'createdAt': 1790000000000,
    'updatedAt': 1790000000000,
    'hlc': null,
  };

  test('upsert, fetch, update and delete one map', () async {
    final s = SyncDataSerializer();
    await s.upsertRecord('connectionMaps', row('m1'));
    final fetched = await s.fetchRecord('connectionMaps', 'm1');
    expect(fetched, isNotNull);
    expect(fetched!['name'], 'Bonaire 2025');
    expect(fetched['spec'], contains('buddy-site'));

    await s.upsertRecord('connectionMaps', row('m1', name: 'Renamed'));
    expect((await s.fetchRecord('connectionMaps', 'm1'))!['name'], 'Renamed');

    await s.deleteRecord('connectionMaps', 'm1');
    expect(await s.fetchRecord('connectionMaps', 'm1'), isNull);
  });

  test('batch upsert and fetch', () async {
    final s = SyncDataSerializer();
    await s.upsertRecords('connectionMaps', [row('a'), row('b')]);
    final all = await s.fetchRecords('connectionMaps', ['a', 'b']);
    expect(all.keys.toSet(), {'a', 'b'});
  });

  test('is a last-writer-wins entity with updatedAt', () {
    expect(SyncService.entityHasUpdatedAt['connectionMaps'], isTrue);
    expect(const SyncData().toJson().keys, contains('connectionMaps'));
  });
}
