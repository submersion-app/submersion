import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Sync of equipment shares and their event log (issue #2046): both are
/// parent-gated children of `equipment`.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['owner', 'wife']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'bcd',
            name: 'BCD',
            type: 'bcd',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('owner'),
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  Future<void> share(String id, {String diverId = 'wife', int at = 1}) => db
      .into(db.equipmentShares)
      .insert(
        EquipmentSharesCompanion.insert(
          id: id,
          equipmentId: 'bcd',
          diverId: diverId,
          createdAt: at,
        ),
      );

  Future<void> event(String id, {String? from, String? to}) => db
      .into(db.equipmentOwnershipEvents)
      .insert(
        EquipmentOwnershipEventsCompanion.insert(
          id: id,
          equipmentId: 'bcd',
          kind: 'shared',
          occurredAt: 5,
          fromDiverId: Value(from),
          toDiverId: Value(to),
        ),
      );

  test(
    'a share row round-trips through fetchRecord and upsertRecord',
    () async {
      await share('s1');
      final json = await serializer.fetchRecord('equipmentShares', 's1');
      expect(json, isNotNull);
      await serializer.deleteRecord('equipmentShares', 's1');
      expect(await serializer.fetchRecord('equipmentShares', 's1'), isNull);
      await serializer.upsertRecord('equipmentShares', json!);
      expect(await serializer.fetchRecord('equipmentShares', 's1'), isNotNull);
    },
  );

  test('an event row round-trips with a null diver id', () async {
    await event('ev1', from: 'owner');
    final json = await serializer.fetchRecord(
      'equipmentOwnershipEvents',
      'ev1',
    );
    expect(json, isNotNull);
    expect(json!['toDiverId'], isNull);
    await serializer.deleteRecord('equipmentOwnershipEvents', 'ev1');
    await serializer.upsertRecords('equipmentOwnershipEvents', [json]);
    expect(
      await serializer.fetchRecord('equipmentOwnershipEvents', 'ev1'),
      isNotNull,
    );
  });

  test('a peer copy of a pair under another id converges on one row', () async {
    await share('zzz-local');
    await serializer.upsertRecords('equipmentShares', [
      {
        'id': 'aaa-peer',
        'equipmentId': 'bcd',
        'diverId': 'wife',
        'createdAt': 2,
        'hlc': null,
      },
    ]);
    final rows = await db.select(db.equipmentShares).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, 'aaa-peer');
  });

  test('a single peer copy under another id also converges', () async {
    await share('zzz-local');
    await serializer.upsertRecord('equipmentShares', {
      'id': 'aaa-peer',
      'equipmentId': 'bcd',
      'diverId': 'wife',
      'createdAt': 2,
      'hlc': null,
    });
    final rows = await db.select(db.equipmentShares).get();
    expect(rows.map((r) => r.id), ['aaa-peer']);
  });

  test(
    'an equipment tombstone drops its shares and events on the peer',
    () async {
      await share('s1');
      await event('ev1');
      await serializer.deleteRecord('equipment', 'bcd');
      expect(await db.select(db.equipmentShares).get(), isEmpty);
      expect(await db.select(db.equipmentOwnershipEvents).get(), isEmpty);
    },
  );

  test('a divers tombstone drops shares and nulls event divers', () async {
    await share('s1');
    await event('ev1', from: 'owner', to: 'wife');
    await serializer.deleteRecord('divers', 'wife');
    expect(await db.select(db.equipmentShares).get(), isEmpty);
    final row = await db.select(db.equipmentOwnershipEvents).getSingle();
    expect(row.toDiverId, isNull);
    expect(row.fromDiverId, 'owner');
  });
}
