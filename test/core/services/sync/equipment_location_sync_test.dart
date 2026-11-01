import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

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

  group('saved dive center link (v331)', () {
    Map<String, dynamic> place(String id, {Object? center = 'keep'}) => {
      'id': id,
      'diverId': 'd',
      'name': id,
      'kind': 'diveCenter',
      'notes': '',
      'isArchived': false,
      'createdAt': 1,
      'updatedAt': 2,
      'hlc': null,
      if (center != 'keep') 'diveCenterId': center,
    };

    Future<String?> linkOf(String id) async =>
        (await serializer.fetchRecord(
              'equipmentLocations',
              id,
            ))?['diveCenterId']
            as String?;

    setUp(() async {
      await db
          .into(db.diveCenters)
          .insert(
            DiveCentersCompanion.insert(
              id: 'reef',
              name: 'Reef',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await serializer.upsertRecord(
        'equipmentLocations',
        place('linked', center: 'reef'),
      );
    });

    test('a record with the key sets the link', () async {
      expect(await linkOf('linked'), 'reef');
    });

    test('an explicit null unlinks', () async {
      await serializer.upsertRecord(
        'equipmentLocations',
        place('linked', center: null),
      );
      expect(await linkOf('linked'), isNull);
    });

    test('a record from before v331 keeps the local link', () async {
      await serializer.upsertRecord('equipmentLocations', place('linked'));
      expect(await linkOf('linked'), 'reef');
    });

    test('a new place from before v331 arrives unlinked', () async {
      await serializer.upsertRecord('equipmentLocations', place('fresh'));
      expect(await linkOf('fresh'), isNull);
    });

    test('in one batch each record decides by its own keys', () async {
      await serializer.upsertRecord(
        'equipmentLocations',
        place('other', center: 'reef'),
      );
      await serializer.upsertRecords('equipmentLocations', [
        place('linked'),
        place('other', center: null),
      ]);
      expect(await linkOf('linked'), 'reef');
      expect(await linkOf('other'), isNull);
    });

    test('a tombstoned center clears the link, not the place', () {
      expect(
        SyncService.parentRefs['equipmentLocations'],
        contains((
          field: 'diveCenterId',
          parent: 'diveCenters',
          nullable: true,
        )),
      );
    });
  });

  group('buddy link (v334)', () {
    Map<String, dynamic> place(String id, {Object? buddy = 'keep'}) => {
      'id': id,
      'diverId': 'd',
      'name': id,
      'kind': 'person',
      'notes': '',
      'isArchived': false,
      'createdAt': 1,
      'updatedAt': 2,
      'hlc': null,
      if (buddy != 'keep') 'buddyId': buddy,
    };

    Future<String?> linkOf(String id) async =>
        (await serializer.fetchRecord('equipmentLocations', id))?['buddyId']
            as String?;

    setUp(() async {
      await db
          .into(db.buddies)
          .insert(
            BuddiesCompanion.insert(
              id: 'anna',
              name: 'Anna',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await serializer.upsertRecord(
        'equipmentLocations',
        place('linked', buddy: 'anna'),
      );
    });

    test('a record with the key sets the link', () async {
      expect(await linkOf('linked'), 'anna');
    });

    test('an explicit null unlinks', () async {
      await serializer.upsertRecord(
        'equipmentLocations',
        place('linked', buddy: null),
      );
      expect(await linkOf('linked'), isNull);
    });

    test('a record from before v334 keeps the local link', () async {
      await serializer.upsertRecord('equipmentLocations', place('linked'));
      expect(await linkOf('linked'), 'anna');
    });

    test('a new place from before v334 arrives unlinked', () async {
      await serializer.upsertRecord('equipmentLocations', place('fresh'));
      expect(await linkOf('fresh'), isNull);
    });

    test('in one batch each record decides by its own keys', () async {
      await serializer.upsertRecord(
        'equipmentLocations',
        place('other', buddy: 'anna'),
      );
      await serializer.upsertRecords('equipmentLocations', [
        place('linked'),
        place('other', buddy: null),
      ]);
      expect(await linkOf('linked'), 'anna');
      expect(await linkOf('other'), isNull);
    });

    test('a tombstoned buddy clears the link, not the place', () {
      expect(
        SyncService.parentRefs['equipmentLocations'],
        contains((field: 'buddyId', parent: 'buddies', nullable: true)),
      );
    });
  });

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
