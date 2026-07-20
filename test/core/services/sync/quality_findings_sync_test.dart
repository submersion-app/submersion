import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    // Findings reference dives; skip seeding the full dive graph.
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });
  tearDown(tearDownTestDatabase);

  // Serializer record maps use camelCase keys (mapped to snake_case columns
  // internally), matching equipment_set_geofence_sync_test.dart.
  Map<String, dynamic> findingRecord(String id) => {
    'id': id,
    'diveId': 'dive-1',
    'relatedDiveId': null,
    'computerId': null,
    'detectorId': 'depth_spike',
    'detectorVersion': 1,
    'category': 'profile',
    'severity': 'warning',
    'status': 'open',
    'params': '{"atSeconds":120}',
    'createdAt': 1700000000000,
    'updatedAt': 1700000000000,
    'hlc': '2026-07-17T00:00:00.000Z-0000-abcdef',
  };

  test('upsertRecord + fetchRecord round-trips a finding', () async {
    await serializer.upsertRecord('qualityFindings', findingRecord('qf-1'));
    final fetched = await serializer.fetchRecord('qualityFindings', 'qf-1');
    expect(fetched, isNotNull);
    expect(fetched!['detectorId'], 'depth_spike');
    expect(fetched['status'], 'open');
  });

  test('deleteRecord removes a finding', () async {
    await serializer.upsertRecord('qualityFindings', findingRecord('qf-2'));
    await serializer.deleteRecord('qualityFindings', 'qf-2');
    expect(await serializer.fetchRecord('qualityFindings', 'qf-2'), isNull);
  });

  test('batch upsertRecords + fetchRecords round-trips', () async {
    await serializer.upsertRecords('qualityFindings', [
      findingRecord('qf-3'),
      findingRecord('qf-4'),
    ]);
    final fetched = await serializer.fetchRecords('qualityFindings', [
      'qf-3',
      'qf-4',
    ]);
    expect(fetched, hasLength(2));
  });
}
