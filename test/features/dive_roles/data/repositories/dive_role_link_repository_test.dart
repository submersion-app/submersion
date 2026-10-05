import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_link_repository.dart';

import '../../../../helpers/test_database.dart';

/// The role junctions behind several roles per person (issue #1221).
void main() {
  late AppDatabase db;
  late DiveRoleLinkRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRoleLinkRepository();
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0), ('d2', 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO buddies (id, name, created_at, updated_at) '
      "VALUES ('b1', 'Ana', 0, 0), ('b2', 'Ben', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_buddies (id, dive_id, buddy_id, role, created_at) '
      "VALUES ('l1', 'd1', 'b1', 'buddy', 0), ('l2', 'd1', 'b2', 'buddy', 0)",
    );
  });

  tearDown(tearDownTestDatabase);

  Future<int> count(String sql) async =>
      (await db.customSelect(sql).getSingle()).read<int>('n');

  Future<String?> diverScalar(String diveId) async =>
      (await db
              .customSelect("SELECT diver_role FROM dives WHERE id = '$diveId'")
              .getSingle())
          .read<String?>('diver_role');

  group('diver roles', () {
    test('writeDiverRoles stores the set and the primary scalar', () async {
      await repo.writeDiverRoles('d1', ['diveMaster', 'diveGuide']);
      expect(await repo.diverRoleIdsForDives(['d1', 'd2']), {
        'd1': ['diveGuide', 'diveMaster'],
        'd2': <String>[],
      });
      expect(await diverScalar('d1'), 'diveGuide');
    });

    test('a legacy dive reads its scalar role', () async {
      await db.customStatement(
        "UPDATE dives SET diver_role = 'instructor' WHERE id = 'd2'",
      );
      expect((await repo.diverRoleIdsForDives(['d2']))['d2'], ['instructor']);
    });

    test("an older peer's scalar change wins", () async {
      await repo.writeDiverRoles('d1', ['diveMaster', 'diveGuide']);
      await db.customStatement(
        "UPDATE dives SET diver_role = 'student' WHERE id = 'd1'",
      );
      expect((await repo.diverRoleIdsForDives(['d1']))['d1'], ['student']);
    });

    test(
      'a rewrite keeps unchanged rows and tombstones removed ones',
      () async {
        await repo.writeDiverRoles('d1', ['diveMaster', 'diveGuide']);
        final before = await db.select(db.diveDiverRoles).get();
        final dmId = before.firstWhere((r) => r.roleId == 'diveMaster').id;

        await repo.writeDiverRoles('d1', ['diveMaster', 'instructor']);

        final after = await db.select(db.diveDiverRoles).get();
        expect(after.map((r) => r.roleId).toSet(), {
          'diveMaster',
          'instructor',
        });
        expect(after.firstWhere((r) => r.roleId == 'diveMaster').id, dmId);
        expect(
          await count(
            'SELECT COUNT(*) AS n FROM deletion_log '
            "WHERE entity_type = 'diveDiverRoles'",
          ),
          1,
        );
      },
    );

    test('Solo beside another role is dropped on write', () async {
      await repo.writeDiverRoles('d1', ['solo', 'instructor']);
      expect((await repo.diverRoleIdsForDives(['d1']))['d1'], ['instructor']);
    });

    test('an empty diver set clears the scalar and the rows', () async {
      await repo.writeDiverRoles('d1', ['diveMaster']);
      await repo.writeDiverRoles('d1', const []);
      expect((await repo.diverRoleIdsForDives(['d1']))['d1'], isEmpty);
      expect(await diverScalar('d1'), isNull);
      expect(await count('SELECT COUNT(*) AS n FROM dive_diver_roles'), 0);
    });

    test('new rows and a changed scalar are marked pending', () async {
      await repo.writeDiverRoles('d1', ['diveMaster', 'diveGuide']);
      expect(
        await count(
          'SELECT COUNT(*) AS n FROM sync_records '
          "WHERE entity_type = 'diveDiverRoles'",
        ),
        2,
      );
      expect(
        await count(
          'SELECT COUNT(*) AS n FROM sync_records '
          "WHERE entity_type = 'dives' AND record_id = 'd1'",
        ),
        1,
      );
    });
  });

  group('buddy roles', () {
    test('writeBuddyRoles sets the pair scalar and the set', () async {
      await repo.writeBuddyRoles('d1', 'b1', ['diveMaster', 'diveGuide']);
      expect(await repo.buddyRoleIdsForDives(['d1']), {
        'd1': {
          'b1': ['diveGuide', 'diveMaster'],
          'b2': ['buddy'],
        },
      });
      final row = await db
          .customSelect("SELECT role FROM dive_buddies WHERE id = 'l1'")
          .getSingle();
      expect(row.read<String>('role'), 'diveGuide');
    });

    test('an empty buddy set becomes Buddy', () async {
      await repo.writeBuddyRoles('d1', 'b1', const []);
      expect((await repo.buddyRoleIdsForDives(['d1']))['d1']!['b1'], ['buddy']);
    });

    test("an older peer's role change on the link wins", () async {
      await repo.writeBuddyRoles('d1', 'b1', ['diveMaster', 'diveGuide']);
      await db.customStatement(
        "UPDATE dive_buddies SET role = 'instructor' WHERE id = 'l1'",
      );
      expect((await repo.buddyRoleIdsForDives(['d1']))['d1']!['b1'], [
        'instructor',
      ]);
    });

    test('deleteBuddyRoles removes and tombstones the rows', () async {
      await repo.writeBuddyRoles('d1', 'b1', ['diveMaster', 'diveGuide']);
      await repo.deleteBuddyRoles('d1', ['b1']);
      expect(await count('SELECT COUNT(*) AS n FROM dive_buddy_roles'), 0);
      expect(
        await count(
          'SELECT COUNT(*) AS n FROM deletion_log '
          "WHERE entity_type = 'diveBuddyRoles'",
        ),
        2,
      );
    });

    test('allBuddyRoleIds reads every link without a dive filter', () async {
      await repo.writeBuddyRoles('d1', 'b1', ['diveMaster', 'diveGuide']);
      expect(await repo.allBuddyRoleIds(), {
        'd1': {
          'b1': ['diveGuide', 'diveMaster'],
          'b2': ['buddy'],
        },
      });
    });
  });

  group('restoreRows', () {
    test('puts back exactly the captured diver rows', () async {
      await repo.writeDiverRoles('d1', ['diveMaster', 'diveGuide']);
      final captured = await repo.diverRoleRowsForDives(['d1']);
      await repo.writeDiverRoles('d1', ['instructor']);

      await repo.restoreRows(diveIds: ['d1'], diverRows: captured);

      final rows = await db.select(db.diveDiverRoles).get();
      expect(rows.map((r) => r.id).toSet(), captured.map((r) => r.id).toSet());
    });

    test('null diverRows leaves the diver rows alone', () async {
      await repo.writeDiverRoles('d1', ['diveMaster', 'diveGuide']);
      await repo.restoreRows(diveIds: ['d1'], buddyRows: const []);
      expect(await count('SELECT COUNT(*) AS n FROM dive_diver_roles'), 2);
    });

    test('onlyBuddyIds limits which buddies are restored', () async {
      await repo.writeBuddyRoles('d1', 'b1', ['diveMaster']);
      await repo.writeBuddyRoles('d1', 'b2', ['instructor']);
      final b1Rows = [
        for (final r in await repo.buddyRoleRowsForDives(['d1']))
          if (r.buddyId == 'b1') r,
      ];
      await repo.writeBuddyRoles('d1', 'b1', ['student']);

      await repo.restoreRows(
        diveIds: ['d1'],
        buddyRows: b1Rows,
        onlyBuddyIds: {'b1'},
      );

      final rows = await db.select(db.diveBuddyRoles).get();
      expect(
        {for (final r in rows) '${r.buddyId}:${r.roleId}'},
        {'b1:diveMaster', 'b2:instructor'},
      );
    });
  });
}
