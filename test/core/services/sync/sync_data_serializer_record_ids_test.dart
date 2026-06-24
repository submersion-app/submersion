import 'package:flutter_test/flutter_test.dart';
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

  test('keys settings on key; unknown entity is empty', () async {
    final s = SyncDataSerializer();
    await s.upsertRecord('settings', {
      'key': 'theme',
      'value': 'dark',
      'updatedAt': 1,
    });

    expect(await s.recordIdsFor('settings'), {'theme'});
    expect(await s.recordIdsFor('notATable'), <String>{});
  });

  test('every synced entity resolves without throwing (smoke)', () async {
    final s = SyncDataSerializer();
    for (final entity in SyncService.entityHasUpdatedAt.keys) {
      expect(
        await s.recordIdsFor(entity),
        isA<Set<String>>(),
        reason: '$entity must have a recordIdsFor case',
      );
    }
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
