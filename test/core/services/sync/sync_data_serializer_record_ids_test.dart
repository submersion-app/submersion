import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Unit coverage for [SyncDataSerializer.recordIdsFor]: the bounded, id-only
/// local-row enumeration that the streaming replace-adopt uses to delete local
/// rows absent from the restored library (#358). The contract is that the ids
/// it emits round-trip through [SyncDataSerializer.deleteRecord]: plain `id`
/// for most entities, `key` for `settings`, and the composite `a|b` form for
/// the two junction tables.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async => setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  test('returns plain ids for a simple entity', () async {
    final s = SyncDataSerializer();
    await s.upsertRecord('diveSites', _site('site-1'));
    await s.upsertRecord('diveSites', _site('site-2'));

    expect(await s.recordIdsFor('diveSites'), {'site-1', 'site-2'});
  });

  test('builds composite ids for diveEquipment (diveId|equipmentId)', () async {
    final dives = DiveRepository();
    await dives.createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final s = SyncDataSerializer();
    await s.upsertRecord('equipment', _equipment('e1'));
    await s.upsertRecord('diveEquipment', {
      'diveId': 'd1',
      'equipmentId': 'e1',
    });

    final ids = await s.recordIdsFor('diveEquipment');
    expect(ids, {'d1|e1'});

    // Round-trip: the emitted id deletes the row through deleteRecord.
    await s.deleteRecord('diveEquipment', ids.single);
    expect(await s.recordIdsFor('diveEquipment'), isEmpty);
  });

  test(
    'builds composite ids for equipmentSetItems (setId|equipmentId)',
    () async {
      final s = SyncDataSerializer();
      await s.upsertRecord('equipment', _equipment('e1'));
      await s.upsertRecord('equipmentSets', {
        'id': 'set-1',
        'name': 'Travel kit',
        'description': '',
        'isDefault': false,
        'createdAt': 1000,
        'updatedAt': 1000,
      });
      await s.upsertRecord('equipmentSetItems', {
        'setId': 'set-1',
        'equipmentId': 'e1',
      });

      final ids = await s.recordIdsFor('equipmentSetItems');
      expect(ids, {'set-1|e1'});

      // Round-trip through deleteRecord.
      await s.deleteRecord('equipmentSetItems', ids.single);
      expect(await s.recordIdsFor('equipmentSetItems'), isEmpty);
    },
  );

  test('keys settings on key; unknown entity throws', () async {
    final s = SyncDataSerializer();
    await s.upsertRecord('settings', {
      'key': 'theme',
      'value': 'dark',
      'updatedAt': 1,
    });

    expect(await s.recordIdsFor('settings'), {'theme'});
    // Unknown entity fails loud rather than silently returning empty.
    expect(() => s.recordIdsFor('notATable'), throwsArgumentError);
  });

  test('every synced entity has a recordIdsFor case', () async {
    // recordIdsFor throws on an entity with no case, so iterating every synced
    // entity fails loudly if one is ever added without a case -- which would
    // otherwise silently skip that entity's stale-row deletion on adopt.
    final s = SyncDataSerializer();
    for (final entity in SyncService.entityHasUpdatedAt.keys) {
      expect(
        await s.recordIdsFor(entity),
        isA<Set<String>>(),
        reason: '$entity is missing a recordIdsFor case',
      );
    }
  });

  test('every synced entity has a deleteAllRecords case', () async {
    // deleteAllRecords -> _syncTableFor throws on an entity with no case, so
    // iterating every synced entity fails loudly if one is ever added without a
    // case -- streaming Replace-adopt clears each synced table by entity (#358).
    final s = SyncDataSerializer();
    for (final entity in SyncService.entityHasUpdatedAt.keys) {
      await s.deleteAllRecords(entity); // must not throw on an empty table
    }
  });

  test('deleteAllRecords(settings) preserves device-local keys', () async {
    // Replace-adopt clears each synced table before re-inserting the cloud
    // union. A device-local key (active_diver_id) is excluded from every base
    // (_exportSettings) AND from the re-insert (upsertRecords filter), so
    // clearing it would permanently lose it. It must survive the clear (#447).
    final db = DatabaseService.instance.database;
    // Device-local key: upsertRecord filters it, so insert it directly.
    await db.customStatement(
      "INSERT INTO settings (key, value, updated_at) "
      "VALUES ('active_diver_id', 'diver-1', 1)",
    );
    await SyncDataSerializer().upsertRecord('settings', {
      'key': 'theme',
      'value': 'dark',
      'updatedAt': 1,
    });

    await SyncDataSerializer().deleteAllRecords('settings');

    final keys = {for (final r in await db.select(db.settings).get()) r.key};
    expect(keys, {
      'active_diver_id',
    }, reason: 'device-local key survives; the synced key is cleared');
  });
}

Map<String, dynamic> _site(String id) => {
  'id': id,
  'name': 'Site $id',
  'description': '',
  'notes': '',
  'isShared': false,
  'createdAt': 1000,
  'updatedAt': 1000,
};

Map<String, dynamic> _equipment(String id) => {
  'id': id,
  'name': 'Regulator',
  'type': 'regulator',
  'status': 'active',
  'purchaseCurrency': 'USD',
  'notes': '',
  'isActive': true,
  'createdAt': 1000,
  'updatedAt': 1000,
};
