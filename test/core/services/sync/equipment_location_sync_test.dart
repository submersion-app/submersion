import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Equipment locations (v268) in sync: places are a top-level entity,
/// moves a parent-gated child of equipment.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    const t = 1000;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd',
            name: 'd',
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'reg',
            name: 'Reg',
            type: 'regulator',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('d'),
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  Future<void> seed() async {
    await serializer.upsertRecord('equipmentLocations', {
      'id': 'loc',
      'diverId': 'd',
      'name': 'Garage',
      'kind': 'storage',
      'notes': '',
      'isArchived': false,
      'createdAt': 1,
      'updatedAt': 2,
      'hlc': null,
    });
    await serializer.upsertRecord('equipmentLocationMoves', {
      'id': 'mv',
      'equipmentId': 'reg',
      'locationId': 'loc',
      'movedAt': 5,
      'note': 'n',
      'createdAt': 6,
      'hlc': null,
    });
  }

  test(
    'both entities round-trip through upsertRecord and fetchRecord',
    () async {
      await seed();
      final loc = await serializer.fetchRecord('equipmentLocations', 'loc');
      final mv = await serializer.fetchRecord('equipmentLocationMoves', 'mv');
      expect(loc?['name'], 'Garage');
      expect(loc?['kind'], 'storage');
      expect(mv?['locationId'], 'loc');
      expect(mv?['note'], 'n');
    },
  );

  test('moves are a parent-gated child of equipment', () {
    expect(
      SyncDataSerializer.parentGatedChildEntities,
      contains('equipmentLocationMoves'),
    );
    expect(
      SyncDataSerializer.parentGatedTables['equipmentLocationMoves'],
      'equipment_location_moves',
    );
  });

  test('a full export carries places and moves', () async {
    await seed();
    final payload = await serializer.exportData(
      deviceId: 'dev',
      deletions: const [],
    );
    expect(payload.data.equipmentLocations.single['id'], 'loc');
    expect(payload.data.equipmentLocationMoves.single['id'], 'mv');
  });

  test('an edited move rides a changeset without its item changing', () async {
    await seed();
    // A watermark past every row's clock: the item has not changed since,
    // so only the move's own pending mark can carry it.
    await SyncRepository().markRecordPending(
      entityType: 'equipmentLocationMoves',
      recordId: 'mv',
      localUpdatedAt: 7,
    );
    final payload = await serializer.exportChangeset(
      deviceId: 'dev',
      hlcWatermark: '9999999999999:9999:zzzz',
      deletions: const [],
    );
    expect(
      [for (final r in payload.data.equipmentLocationMoves) r['id']],
      ['mv'],
    );
    expect(payload.data.equipmentLocations, isEmpty);
  });
}
