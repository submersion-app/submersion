import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// An Insights observation dismissal travels through every sync arm
/// unchanged, and an Undo (dismissedAt back to null) travels as an update
/// of the same row (#2381).
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
  });
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> row(
    String id, {
    int? dismissedAt = 1790000000000,
    int updatedAt = 1790000000000,
  }) => {
    'id': id,
    'diverId': 'd1',
    'ruleId': 'rmvTrend',
    'fingerprint': 'down:1',
    'dismissedAt': dismissedAt,
    'createdAt': 1790000000000,
    'updatedAt': updatedAt,
    'hlc': null,
  };

  test('SyncData carries the entity and the base table key', () {
    expect(
      SyncDataSerializer.debugBaseTableKeys,
      contains('insightObservationDismissals'),
    );
    expect(
      SyncData.fromJson({
        'insightObservationDismissals': [row('od_a')],
      }).insightObservationDismissals,
      hasLength(1),
    );
    expect(
      const SyncData().toJson().keys,
      contains('insightObservationDismissals'),
    );
  });

  test('upsert, undo by update, fetch and delete one dismissal', () async {
    final s = SyncDataSerializer();
    await s.upsertRecord('insightObservationDismissals', row('od_a'));
    final fetched = await s.fetchRecord('insightObservationDismissals', 'od_a');
    expect(fetched, isNotNull);
    expect(fetched!['dismissedAt'], 1790000000000);

    await s.upsertRecord(
      'insightObservationDismissals',
      row('od_a', dismissedAt: null, updatedAt: 1790000000500),
    );
    expect(
      (await s.fetchRecord(
        'insightObservationDismissals',
        'od_a',
      ))!['dismissedAt'],
      isNull,
    );

    await s.deleteRecord('insightObservationDismissals', 'od_a');
    expect(await s.fetchRecord('insightObservationDismissals', 'od_a'), isNull);
  });

  test('batch upsert and fetch keep every dismissal', () async {
    final s = SyncDataSerializer();
    await s.upsertRecords('insightObservationDismissals', [
      row('od_a'),
      row('od_b', dismissedAt: null),
    ]);
    final fetched = await s.fetchRecords('insightObservationDismissals', [
      'od_a',
      'od_b',
      'x',
    ]);
    expect(fetched.keys, unorderedEquals(['od_a', 'od_b']));
    expect(fetched['od_b']!['dismissedAt'], isNull);
    expect(await s.recordIdsFor('insightObservationDismissals'), {
      'od_a',
      'od_b',
    });
  });
}
