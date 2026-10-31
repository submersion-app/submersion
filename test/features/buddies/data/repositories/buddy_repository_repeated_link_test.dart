import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3895: `dive_buddies` is unique only on its row id, so one buddy can
/// hold several links to one dive (two devices adding the buddy offline keep
/// both rows through sync). Those links are still one dive with one buddy.
void main() {
  late BuddyRepository repository;
  late db.AppDatabase database;
  final now = DateTime(2026, 1, 1);
  final sam = Buddy(id: 'sam', name: 'Sam', createdAt: now, updatedAt: now);

  Future<void> insertSite(String id, String name) => database
      .into(database.diveSites)
      .insert(
        db.DiveSitesCompanion(
          id: Value(id),
          name: Value(name),
          createdAt: const Value(1),
          updatedAt: const Value(1),
        ),
      );

  Future<void> insertDive(String id, {String? siteId, int at = 1}) => database
      .into(database.dives)
      .insert(
        db.DivesCompanion(
          id: Value(id),
          diveDateTime: Value(at),
          siteId: Value(siteId),
          createdAt: const Value(1),
          updatedAt: const Value(1),
        ),
      );

  Future<void> link(
    String diveId, {
    int copies = 2,
    List<String> roles = const [DiveRole.buddyId, DiveRole.instructorId],
  }) async {
    for (var i = 0; i < copies; i++) {
      await database
          .into(database.diveBuddies)
          .insert(
            db.DiveBuddiesCompanion(
              id: Value('$diveId-$i'),
              diveId: Value(diveId),
              buddyId: const Value('sam'),
              role: Value(roles[i % roles.length]),
              createdAt: const Value(1),
            ),
          );
    }
  }

  setUp(() async {
    await setUpTestDatabase();
    repository = BuddyRepository();
    database = DatabaseService.instance.database;
    await repository.createBuddy(sam);
  });
  tearDown(tearDownTestDatabase);

  group('counts each dive once', () {
    setUp(() async {
      await insertDive('d1');
      await link('d1');
    });

    test('getDiveCountForBuddy', () async {
      expect(await repository.getDiveCountForBuddy('sam'), 1);
    });

    test('getBuddyStats total', () async {
      expect((await repository.getBuddyStats('sam')).totalDives, 1);
    });

    test('getAllBuddiesWithDiveCount', () async {
      final rows = await repository.getAllBuddiesWithDiveCount();

      expect(rows.map((r) => (r.buddy.id, r.diveCount)), [('sam', 1)]);
    });

    test('buddyCountsForDives', () async {
      expect(await repository.buddyCountsForDives(['d1']), {'sam': 1});
    });
  });

  test('favorite site is the one with the most dives, not links', () async {
    await insertSite('reef', 'Reef');
    await insertSite('wreck', 'Wreck');
    await insertDive('d1', siteId: 'reef');
    await link('d1', copies: 3);
    await insertDive('d2', siteId: 'wreck');
    await insertDive('d3', siteId: 'wreck');
    await link('d2', copies: 1);
    await link('d3', copies: 1);

    expect((await repository.getBuddyStats('sam')).favoriteSite, 'Wreck');
  });

  test('getDiveIdsForBuddy lists each dive once, newest first', () async {
    await insertDive('d1', at: 1);
    await insertDive('d2', at: 3);
    await insertDive('d3', at: 2);
    await link('d1');
    await link('d2');
    await link('d3');

    expect(await repository.getDiveIdsForBuddy('sam'), ['d2', 'd3', 'd1']);
  });

  group('a dive lists the buddy once', () {
    setUp(() async {
      await insertDive('d1');
      await link('d1');
    });

    test('getBuddiesForDive', () async {
      final buddies = await repository.getBuddiesForDive('d1');

      expect(buddies.map((b) => b.buddy.id), ['sam']);
    });

    test('getBuddiesForDives', () async {
      final byDive = await repository.getBuddiesForDives(['d1']);

      expect(byDive['d1']!.map((b) => b.buddy.id), ['sam']);
    });

    test('getBuddiesForDives keeps the buddy on each of their dives', () async {
      await insertDive('d2');
      await link('d2');

      final byDive = await repository.getBuddiesForDives(['d1', 'd2']);

      expect(byDive['d1']!.map((b) => b.buddy.id), ['sam']);
      expect(byDive['d2']!.map((b) => b.buddy.id), ['sam']);
    });
  });

  group('adding a buddy already linked twice', () {
    setUp(() async {
      await insertDive('d1');
      await link('d1');
    });

    Future<List<String>> roleIds() async =>
        (await repository.getBuddiesForDive('d1')).single.roleIds;

    test('addBuddyToDiveWithRoles replaces the roles', () async {
      await repository.addBuddyToDiveWithRoles('d1', 'sam', [
        DiveRole.diveMasterId,
      ]);

      expect(await roleIds(), [DiveRole.diveMasterId]);
      expect(await database.select(database.diveBuddies).get(), hasLength(2));
    });

    test('bulkAddBuddies overwrites the roles', () async {
      await repository.bulkAddBuddies(
        ['d1'],
        [
          BuddyWithRole(
            buddy: sam,
            roles: [DiveRole.synthetic(DiveRole.diveMasterId)],
          ),
        ],
      );

      expect(await roleIds(), [DiveRole.diveMasterId]);
      expect(await database.select(database.diveBuddies).get(), hasLength(2));
    });

    test('bulkAddBuddies keeps the roles when told not to overwrite', () async {
      await repository.bulkAddBuddies(
        ['d1'],
        [
          BuddyWithRole(
            buddy: sam,
            roles: [DiveRole.synthetic(DiveRole.diveMasterId)],
          ),
        ],
        overwriteRole: false,
      );

      expect(await roleIds(), isNot(contains(DiveRole.diveMasterId)));
    });
  });
}
