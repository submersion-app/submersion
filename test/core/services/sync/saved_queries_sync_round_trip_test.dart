import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// A saved query travels through every per-record sync arm unchanged
/// (#2365).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> row(String id, {String name = 'Deep'}) => {
    'id': id,
    'diverId': null,
    'subject': 'dives',
    'name': name,
    'queryJson':
        '{"version":1,"node":{"t":"cond","path":["depth"],"op":"gt",'
        '"value":{"k":"num","v":30.0}}}',
    'sortOrder': 0,
    'createdAt': 1790000000000,
    'updatedAt': 1790000000000,
    'hlc': null,
  };

  test('upsert, fetch and delete one saved query', () async {
    final s = SyncDataSerializer();
    await s.upsertRecord('savedQueries', row('q1'));
    final fetched = await s.fetchRecord('savedQueries', 'q1');
    expect(fetched, isNotNull);
    expect(fetched!['name'], 'Deep');
    expect(fetched['queryJson'], contains('"t":"cond"'));

    await s.upsertRecord('savedQueries', row('q1', name: 'Deeper'));
    expect((await s.fetchRecord('savedQueries', 'q1'))!['name'], 'Deeper');

    await s.deleteRecord('savedQueries', 'q1');
    expect(await s.fetchRecord('savedQueries', 'q1'), isNull);
  });

  test('batch upsert and fetch keep every saved query', () async {
    final s = SyncDataSerializer();
    await s.upsertRecords('savedQueries', [
      row('a'),
      row('b', name: 'Shallow'),
    ]);
    final fetched = await s.fetchRecords('savedQueries', ['a', 'b', 'x']);
    expect(fetched.keys, unorderedEquals(['a', 'b']));
    expect(fetched['b']!['name'], 'Shallow');
    expect(await s.recordIdsFor('savedQueries'), {'a', 'b'});
  });
}
