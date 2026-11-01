import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_conversion_repository.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_buddy_links.dart';

import '../../../../helpers/test_database.dart';
import '../../../media/data/repositories/species_photo_fixtures.dart';

/// A buddy's places outlive the buddy. Each helper and delete path clears or
/// moves the link by hand and queues the place, because the schema's SET NULL
/// reaches no peer (issue #3790).
void main() {
  late AppDatabase db;
  const stale = 1000;
  const now = 5000;

  setUp(() async {
    db = await setUpTestDatabase();
    await insertTestDiver('me');
    await insertTestBuddy(id: 'anna', name: 'Anna', diverId: 'me');
    await insertTestBuddy(id: 'sam', name: 'Sam', diverId: 'me');
  });
  tearDown(tearDownTestDatabase);

  Future<void> insertPlace(String id, {String? buddyId = 'anna'}) => db
      .into(db.equipmentLocations)
      .insert(
        EquipmentLocationsCompanion.insert(
          id: id,
          diverId: const Value('me'),
          name: id,
          kind: const Value('person'),
          buddyId: Value(buddyId),
          notes: const Value('kept'),
          createdAt: stale,
          updatedAt: stale,
        ),
      );

  Future<EquipmentLocationRow> row(String id) => (db.select(
    db.equipmentLocations,
  )..where((t) => t.id.equals(id))).getSingle();

  Future<bool> isPending(String id) async =>
      (await db.select(db.syncRecords).get()).any(
        (r) => r.entityType == 'equipmentLocations' && r.recordId == id,
      );

  void expectUnlinked(EquipmentLocationRow place) {
    expect(place.buddyId, isNull);
    expect(place.name, isNotEmpty);
    expect(place.notes, 'kept');
    expect(place.updatedAt, greaterThan(stale));
  }

  group('clearEquipmentLocationBuddyLinks', () {
    test(
      'clears, stamps and queues only the places of those buddies',
      () async {
        await insertPlace('hers');
        await insertPlace('his', buddyId: 'sam');

        await clearEquipmentLocationBuddyLinks(db, SyncRepository(), [
          'anna',
        ], now: now);

        final hers = await row('hers');
        expectUnlinked(hers);
        expect(hers.updatedAt, now);
        expect(await isPending('hers'), isTrue);
        expect((await row('his')).buddyId, 'sam');
        expect(await isPending('his'), isFalse);
      },
    );

    test('reaches every buddy in a list longer than one chunk', () async {
      final ids = [for (var i = 0; i < 501; i++) 'b$i'];
      await db.batch((b) {
        b.insertAll(db.buddies, [
          for (final id in ids)
            BuddiesCompanion.insert(
              id: id,
              name: id,
              createdAt: stale,
              updatedAt: stale,
            ),
        ]);
      });
      await insertPlace('last', buddyId: ids.last);

      await clearEquipmentLocationBuddyLinks(
        db,
        SyncRepository(),
        ids,
        now: now,
      );

      expectUnlinked(await row('last'));
    });
  });

  group('repoint and restore', () {
    test(
      'moves links to the buddy that stays and reports the old ones',
      () async {
        await insertPlace('hers');
        await insertPlace('his', buddyId: 'sam');

        final previous = await repointEquipmentLocationBuddyLinks(
          db,
          SyncRepository(),
          fromBuddyIds: ['sam'],
          toBuddyId: 'anna',
          now: now,
        );

        expect(previous, {'his': 'sam'});
        final his = await row('his');
        expect(his.buddyId, 'anna');
        expect(his.updatedAt, now);
        expect(await isPending('his'), isTrue);
        expect(await isPending('hers'), isFalse);
      },
    );

    test('restore puts each place back on its own buddy', () async {
      await insertPlace('hers');
      await insertPlace('his');

      await restoreEquipmentLocationBuddyLinks(db, SyncRepository(), {
        'his': 'sam',
      }, now: now);

      final his = await row('his');
      expect(his.buddyId, 'sam');
      expect(his.updatedAt, now);
      expect(await isPending('his'), isTrue);
      expect((await row('hers')).buddyId, 'anna');
    });
  });

  group('delete paths keep the place', () {
    test('deleteBuddy', () async {
      await insertPlace('hers');
      await BuddyRepository().deleteBuddy('anna');
      expectUnlinked(await row('hers'));
      expect(await isPending('hers'), isTrue);
    });

    test('bulkDeleteBuddies', () async {
      await insertPlace('hers');
      await insertPlace('his', buddyId: 'sam');
      await BuddyRepository().bulkDeleteBuddies(['anna', 'sam']);
      expectUnlinked(await row('hers'));
      expectUnlinked(await row('his'));
      expect(await isPending('hers'), isTrue);
      expect(await isPending('his'), isTrue);
    });

    test('undoing a legacy buddy conversion', () async {
      await insertPlace('hers');
      await BuddyConversionRepository().undo(
        const ConversionReceipt(diverId: 'me', createdBuddyIds: ['anna']),
      );
      final buddies = await db.select(db.buddies).get();
      expect(buddies.map((b) => b.id), isNot(contains('anna')));
      expectUnlinked(await row('hers'));
      expect(await isPending('hers'), isTrue);
    });
  });
}
