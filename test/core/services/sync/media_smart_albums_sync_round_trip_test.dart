import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// A smart album travels through every per-record sync arm unchanged
/// (issue #2413).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> row(String id, {String name = 'Mantas'}) => {
    'id': id,
    'name': name,
    'filterJson': '{"speciesIds":["manta-1"]}',
    'sortOrder': 2,
    'createdAt': 1790000000000,
    'updatedAt': 1790000000000,
    'hlc': null,
  };

  test('upsert, fetch and delete one smart album', () async {
    final s = SyncDataSerializer();
    await s.upsertRecord('mediaSmartAlbums', row('a1'));
    final fetched = await s.fetchRecord('mediaSmartAlbums', 'a1');
    expect(fetched, isNotNull);
    expect(fetched!['name'], 'Mantas');
    expect(fetched['filterJson'], '{"speciesIds":["manta-1"]}');
    expect(fetched['sortOrder'], 2);

    await s.upsertRecord('mediaSmartAlbums', row('a1', name: 'Rays'));
    expect((await s.fetchRecord('mediaSmartAlbums', 'a1'))!['name'], 'Rays');

    await s.deleteRecord('mediaSmartAlbums', 'a1');
    expect(await s.fetchRecord('mediaSmartAlbums', 'a1'), isNull);
  });

  test('batch upsert and fetch keep every smart album', () async {
    final s = SyncDataSerializer();
    await s.upsertRecords('mediaSmartAlbums', [
      row('a'),
      row('b', name: 'Wrecks'),
    ]);
    final fetched = await s.fetchRecords('mediaSmartAlbums', ['a', 'b', 'x']);
    expect(fetched.keys, unorderedEquals(['a', 'b']));
    expect(fetched['b']!['name'], 'Wrecks');
  });
}
