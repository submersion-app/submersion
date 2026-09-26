import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// A fill travels through every per-record sync arm unchanged (issue #2334).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> row(String id, {double o2 = 32}) => {
    'id': id,
    'diverId': null,
    'passportId': 'pp-1',
    'equipmentId': null,
    'filledAt': 1790000000000,
    'o2Percent': o2,
    'hePercent': 0.0,
    'pressureBar': 220.0,
    'temperatureC': 21.5,
    'analyzer': 'Divesoft',
    'stationName': 'Blue Water Fills',
    'stationKey': null,
    'signedRecord': null,
    'source': 'manual',
    'notes': 'topped',
    'createdAt': 1790000000000,
    'updatedAt': 1790000000000,
    'hlc': null,
  };

  test('upsert, fetch and delete one fill', () async {
    final s = SyncDataSerializer();
    await s.upsertRecord('cylinderFills', row('f1'));
    final fetched = await s.fetchRecord('cylinderFills', 'f1');
    expect(fetched, isNotNull);
    expect(fetched!['stationName'], 'Blue Water Fills');
    expect(fetched['temperatureC'], 21.5);

    await s.upsertRecord('cylinderFills', row('f1', o2: 36));
    expect((await s.fetchRecord('cylinderFills', 'f1'))!['o2Percent'], 36);

    await s.deleteRecord('cylinderFills', 'f1');
    expect(await s.fetchRecord('cylinderFills', 'f1'), isNull);
  });

  test('batch upsert and fetch keep every fill', () async {
    final s = SyncDataSerializer();
    await s.upsertRecords('cylinderFills', [row('a'), row('b', o2: 50)]);
    final fetched = await s.fetchRecords('cylinderFills', ['a', 'b', 'x']);
    expect(fetched.keys, unorderedEquals(['a', 'b']));
    expect(fetched['b']!['o2Percent'], 50);
  });
}
