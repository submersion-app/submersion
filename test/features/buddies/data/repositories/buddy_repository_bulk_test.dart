import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late BuddyRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repository = BuddyRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  domain.BuddyWithRole bwr(String id) => domain.BuddyWithRole(
    buddy: domain.Buddy(
      id: id,
      name: 'B$id',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    role: DiveRole.builtInBuddy(),
  );

  domain.BuddyWithRole bwrRole(String id, String roleId) =>
      domain.BuddyWithRole(
        buddy: bwr(id).buddy,
        role: DiveRole.synthetic(roleId),
      );

  test('bulkAddBuddies links each buddy to each dive', () async {
    await repository.bulkAddBuddies(['d1', 'd2'], [bwr('x'), bwr('y')]);
    final d1 = await (db.select(
      db.diveBuddies,
    )..where((t) => t.diveId.equals('d1'))).get();
    expect(d1.map((r) => r.buddyId).toSet(), {'x', 'y'});
    final d2 = await (db.select(
      db.diveBuddies,
    )..where((t) => t.diveId.equals('d2'))).get();
    expect(d2.length, 2);
  });

  test('bulkUpdateBuddyRoles rewrites the role on links that exist', () async {
    await repository.bulkAddBuddies(['d1', 'd2'], [bwr('x')]);
    await repository.bulkUpdateBuddyRoles(
      ['d1', 'd2'],
      [bwrRole('x', DiveRole.instructorId)],
    );
    final rows = await (db.select(
      db.diveBuddies,
    )..where((t) => t.buddyId.equals('x'))).get();
    expect(rows, hasLength(2));
    expect(rows.every((r) => r.role == DiveRole.instructorId), isTrue);
  });

  test('bulkUpdateBuddyRoles never creates a missing link', () async {
    // x is on d1 only. A role-only edit must leave d2 without the buddy.
    await repository.bulkAddBuddies(['d1'], [bwr('x')]);
    await repository.bulkUpdateBuddyRoles(
      ['d1', 'd2'],
      [bwrRole('x', DiveRole.instructorId)],
    );
    final rows = await (db.select(
      db.diveBuddies,
    )..where((t) => t.buddyId.equals('x'))).get();
    expect(rows, hasLength(1));
    expect(rows.single.diveId, 'd1');
    expect(rows.single.role, DiveRole.instructorId);
  });

  test('bulkUpdateBuddyRoles leaves other buddies on the dive alone', () async {
    await repository.bulkAddBuddies(['d1'], [bwr('x'), bwr('y')]);
    await repository.bulkUpdateBuddyRoles(
      ['d1'],
      [bwrRole('x', DiveRole.instructorId)],
    );
    final y = await (db.select(
      db.diveBuddies,
    )..where((t) => t.buddyId.equals('y'))).getSingle();
    expect(y.role, DiveRole.buddyId);
  });

  test('buddyCountsForDives returns per-buddy dive counts', () async {
    await repository.bulkAddBuddies(['d1', 'd2'], [bwr('shared')]);
    await repository.bulkAddBuddies(['d1'], [bwr('onlyD1')]);
    final counts = await repository.buddyCountsForDives(['d1', 'd2']);
    expect(counts['shared'], 2);
    expect(counts['onlyD1'], 1);
    expect(await repository.buddyCountsForDives(const []), isEmpty);
  });

  test('bulkReplaceBuddies overwrites; bulkRemoveBuddies subtracts', () async {
    await repository.bulkAddBuddies(['d1'], [bwr('x'), bwr('y')]);
    await repository.bulkReplaceBuddies(['d1'], [bwr('z')]);
    var rows = await (db.select(
      db.diveBuddies,
    )..where((t) => t.diveId.equals('d1'))).get();
    expect(rows.map((r) => r.buddyId).toSet(), {'z'});

    await repository.bulkRemoveBuddies(['d1'], ['z']);
    rows = await (db.select(
      db.diveBuddies,
    )..where((t) => t.diveId.equals('d1'))).get();
    expect(rows, isEmpty);
  });

  test(
    'bulkAddBuddies updates the role when the link already exists',
    () async {
      await repository.bulkAddBuddies(['d1'], [bwr('x')]); // role buddy
      await repository.bulkAddBuddies(
        ['d1'],
        [
          domain.BuddyWithRole(
            buddy: bwr('x').buddy,
            role: DiveRole(
              id: DiveRole.instructorId,
              name: 'Instructor',
              isBuiltIn: true,
              sortOrder: 2,
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            ),
          ),
        ],
      );
      final rows = await (db.select(
        db.diveBuddies,
      )..where((t) => t.diveId.equals('d1'))).get();
      expect(rows.length, 1); // not duplicated
      expect(rows.single.role, 'instructor'); // role updated in place
    },
  );

  test(
    'bulkAddBuddies leaves existing roles alone when not overwriting',
    () async {
      await repository.bulkAddBuddies(['d1'], [bwrRole('x', 'instructor')]);
      // Membership-only add across both dives: d1 keeps instructor, d2 is new.
      await repository.bulkAddBuddies(
        ['d1', 'd2'],
        [bwrRole('x', DiveRole.buddyId)],
        overwriteRole: false,
      );
      final rows = await db.select(db.diveBuddies).get();
      expect(rows.length, 2);
      expect(
        {for (final r in rows) r.diveId: r.role},
        {'d1': 'instructor', 'd2': DiveRole.buddyId},
      );
    },
  );

  test('unanimousBuddyRolesForDives omits buddies with mixed roles', () async {
    await repository.bulkAddBuddies(['d1', 'd2'], [bwrRole('same', 'student')]);
    await repository.bulkAddBuddies(['d1'], [bwrRole('mixed', 'instructor')]);
    await repository.bulkAddBuddies(['d2'], [bwrRole('mixed', 'student')]);

    final roles = await repository.unanimousBuddyRolesForDives(['d1', 'd2']);
    expect(roles['same'], 'student');
    expect(roles.containsKey('mixed'), isFalse);
    expect(await repository.unanimousBuddyRolesForDives(const []), isEmpty);
  });
}
