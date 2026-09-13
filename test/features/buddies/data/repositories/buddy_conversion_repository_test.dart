import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_conversion_repository.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late BuddyConversionRepository repo;

  Future<void> insertDiver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion.insert(id: id, name: id, createdAt: 1, updatedAt: 1),
      );

  Future<void> insertDive(
    String id, {
    String diverId = 'me',
    String? buddy,
    String? diveMaster,
    int? number,
    int at = 1000,
    String? siteId,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: Value(diverId),
          diveDateTime: at,
          createdAt: 1,
          updatedAt: 1,
          buddy: Value(buddy),
          diveMaster: Value(diveMaster),
          diveNumber: Value(number),
          siteId: Value(siteId),
        ),
      );

  Future<void> insertBuddy(
    String id,
    String name, {
    String? diverId = 'me',
    int createdAt = 1,
  }) => db
      .into(db.buddies)
      .insert(
        BuddiesCompanion.insert(
          id: id,
          name: name,
          diverId: Value(diverId),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

  Future<void> link(String diveId, String buddyId) => db
      .into(db.diveBuddies)
      .insert(
        DiveBuddiesCompanion.insert(
          id: '$diveId|$buddyId',
          diveId: diveId,
          buddyId: buddyId,
          createdAt: 1,
        ),
      );

  Future<Set<String>> pending(String entityType) async => {
    for (final r in await db.select(db.syncRecords).get())
      if (r.entityType == entityType && r.syncStatus == 'pending') r.recordId,
  };

  Future<Set<String>> tombstones(String entityType) async => {
    for (final t in await db.select(db.deletionLog).get())
      if (t.entityType == entityType) t.recordId,
  };

  setUp(() async {
    db = await setUpTestDatabase();
    repo = BuddyConversionRepository();
    await insertDiver('me');
    await insertDiver('other');
  });

  tearDown(tearDownTestDatabase);

  group('candidateBuddies', () {
    test(
      'returns the diver own and unowned buddies with dive counts',
      () async {
        await insertBuddy('own', 'Ann');
        await insertBuddy('free', 'Bob', diverId: null);
        await insertBuddy('theirs', 'Cy', diverId: 'other');
        await insertDive('d1');
        await link('d1', 'own');

        final byId = {
          for (final c in await repo.candidateBuddies('me')) c.id: c,
        };

        expect(byId.keys, unorderedEquals(['own', 'free']));
        expect(byId['own']!.diveCount, 1);
        expect(byId['own']!.name, 'Ann');
        expect(byId['free']!.diverId, isNull);
        expect(byId['free']!.diveCount, 0);
      },
    );
  });

  group('unlinkedTextDives', () {
    test('lists the diver dives with unlinked text, newest first', () async {
      await db.customStatement(
        "INSERT INTO dive_sites (id, name, created_at, updated_at) "
        "VALUES ('s1', 'Blue Hole', 1, 1)",
      );
      await insertDive(
        'old',
        buddy: 'Ann',
        at: 1000,
        number: 1,
        siteId: 's1',
      );
      await insertDive('new', diveMaster: 'Bob', at: 2000);
      await insertDive('blank', buddy: '   ', at: 3000);
      await insertBuddy('cy', 'Cy');
      await insertDive('linked', buddy: 'Cy', at: 4000);
      await link('linked', 'cy');
      await insertDive('theirs', diverId: 'other', buddy: 'Dee', at: 5000);

      final rows = await repo.unlinkedTextDives('me');

      expect(rows.map((r) => r.diveId), ['new', 'old']);
      expect(rows.first.diveMasterText, 'Bob');
      final old = rows.last;
      expect(old.buddyText, 'Ann');
      expect(old.diveNumber, 1);
      expect(old.siteName, 'Blue Hole');
      expect(
        old.dateTime,
        DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      );
    });
  });
}
