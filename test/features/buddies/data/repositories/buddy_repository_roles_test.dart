import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

import '../../../../helpers/test_database.dart';

/// Each buddy's role set on a dive (issue #1221).
void main() {
  late AppDatabase db;
  late BuddyRepository repo;
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  final ana = Buddy(id: 'b1', name: 'Ana', createdAt: epoch, updatedAt: epoch);
  final ben = Buddy(id: 'b2', name: 'Ben', createdAt: epoch, updatedAt: epoch);

  DiveRole role(String id) => DiveRole.synthetic(id);

  setUp(() async {
    db = await setUpTestDatabase();
    repo = BuddyRepository();
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0), ('d2', 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO buddies (id, name, created_at, updated_at) '
      "VALUES ('b1', 'Ana', 0, 0), ('b2', 'Ben', 0, 0)",
    );
  });

  tearDown(tearDownTestDatabase);

  Future<int> count(String sql) async =>
      (await db.customSelect(sql).getSingle()).read<int>('n');

  test("setBuddiesForDive stores each buddy's role set", () async {
    await repo.setBuddiesForDive('d1', [
      BuddyWithRole(buddy: ana, roles: [role('diveMaster'), role('diveGuide')]),
    ]);
    final read = await repo.getBuddiesForDive('d1');
    expect(read.single.roleIds, ['diveGuide', 'diveMaster']);
  });

  test('buddy roles survive a dive_buddies row being replaced', () async {
    await repo.setBuddiesForDive('d1', [
      BuddyWithRole(buddy: ana, roles: [role('diveMaster'), role('diveGuide')]),
    ]);
    // What an older app version does on save: the same pair under a fresh
    // row id, carrying the primary role it read.
    await db.customStatement("DELETE FROM dive_buddies WHERE dive_id = 'd1'");
    await db.customStatement(
      'INSERT INTO dive_buddies (id, dive_id, buddy_id, role, created_at) '
      "VALUES ('fresh', 'd1', 'b1', 'diveGuide', 0)",
    );
    expect((await repo.getBuddiesForDive('d1')).single.roleIds, [
      'diveGuide',
      'diveMaster',
    ]);
  });

  test('removing a buddy tombstones their role rows', () async {
    await repo.setBuddiesForDive('d1', [
      BuddyWithRole(buddy: ana, roles: [role('diveMaster'), role('diveGuide')]),
    ]);
    await repo.removeBuddyFromDive('d1', 'b1');
    expect(await count('SELECT COUNT(*) AS n FROM dive_buddy_roles'), 0);
    await repo.addBuddyToDive('d1', 'b1', DiveRole.buddyId);
    expect((await repo.getBuddiesForDive('d1')).single.roleIds, ['buddy']);
  });

  test('a buddy dropped by setBuddiesForDive loses their role rows', () async {
    await repo.setBuddiesForDive('d1', [
      BuddyWithRole(buddy: ana, roles: [role('diveMaster'), role('diveGuide')]),
      BuddyWithRole(buddy: ben, roles: [role('instructor')]),
    ]);
    await repo.setBuddiesForDive('d1', [
      BuddyWithRole(buddy: ben, roles: [role('instructor')]),
    ]);
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM dive_buddy_roles WHERE buddy_id = 'b1'",
      ),
      0,
    );
  });

  test('addBuddyToDiveWithRoles replaces that buddy\'s roles', () async {
    await repo.addBuddyToDiveWithRoles('d1', 'b1', const [
      'diveMaster',
      'diveGuide',
    ]);
    expect((await repo.getBuddiesForDive('d1')).single.roleIds, [
      'diveGuide',
      'diveMaster',
    ]);
    await repo.addBuddyToDiveWithRoles('d1', 'b1', const ['instructor']);
    expect((await repo.getBuddiesForDive('d1')).single.roleIds, ['instructor']);
  });

  test('the batch load returns sets per dive', () async {
    await repo.setBuddiesForDive('d1', [
      BuddyWithRole(buddy: ana, roles: [role('diveMaster'), role('diveGuide')]),
    ]);
    final byDive = await repo.getBuddiesForDives(['d1']);
    expect(byDive['d1']!.single.roleIds, ['diveGuide', 'diveMaster']);
    final withCerts = await repo.getBuddiesForDivesWithCertifications(['d1']);
    expect(withCerts['d1']!.single.roleIds, ['diveGuide', 'diveMaster']);
  });

  test('bulk add, update and replace write role sets', () async {
    await repo.bulkAddBuddies(
      ['d1', 'd2'],
      [
        BuddyWithRole(
          buddy: ana,
          roles: [role('diveMaster'), role('diveGuide')],
        ),
      ],
    );
    expect((await repo.getBuddiesForDive('d2')).single.roleIds, [
      'diveGuide',
      'diveMaster',
    ]);

    await repo.bulkUpdateBuddyRoles(
      ['d1', 'd2'],
      [
        BuddyWithRole(buddy: ana, roles: [role('instructor')]),
      ],
    );
    expect((await repo.getBuddiesForDive('d1')).single.roleIds, ['instructor']);

    await repo.bulkReplaceBuddies(
      ['d1'],
      [
        BuddyWithRole(buddy: ben, roles: [role('safetyDiver')]),
      ],
    );
    final d1 = await repo.getBuddiesForDive('d1');
    expect(d1.single.buddy.id, 'b2');
    expect(d1.single.roleIds, ['safetyDiver']);
    expect(
      await count(
        'SELECT COUNT(*) AS n FROM dive_buddy_roles '
        "WHERE dive_id = 'd1' AND buddy_id = 'b1'",
      ),
      0,
    );
  });

  test('bulkRemoveBuddies deletes role rows', () async {
    await repo.bulkAddBuddies(
      ['d1', 'd2'],
      [
        BuddyWithRole(
          buddy: ana,
          roles: [role('diveMaster'), role('diveGuide')],
        ),
      ],
    );
    await repo.bulkRemoveBuddies(['d1', 'd2'], ['b1']);
    expect(await count('SELECT COUNT(*) AS n FROM dive_buddy_roles'), 0);
  });

  test('unanimous role sets omit buddies whose sets differ', () async {
    await repo.setBuddiesForDive('d1', [
      BuddyWithRole(buddy: ana, roles: [role('diveMaster'), role('diveGuide')]),
    ]);
    await repo.setBuddiesForDive('d2', [
      BuddyWithRole(buddy: ana, roles: [role('diveGuide'), role('diveMaster')]),
      BuddyWithRole(buddy: ben, roles: [role('instructor')]),
    ]);
    expect(await repo.unanimousBuddyRolesForDives(['d1', 'd2']), {
      'b1': ['diveGuide', 'diveMaster'],
      'b2': ['instructor'],
    });

    await repo.setBuddiesForDive('d1', [
      BuddyWithRole(buddy: ana, roles: [role('diveMaster')]),
    ]);
    expect(
      (await repo.unanimousBuddyRolesForDives(['d1', 'd2'])).containsKey('b1'),
      isFalse,
    );
  });
}
