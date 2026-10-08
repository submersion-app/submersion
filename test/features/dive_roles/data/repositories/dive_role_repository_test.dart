import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

import '../../../../helpers/test_database.dart';

Future<String> _insertDiver() async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
  );
  return 'diver-1';
}

void main() {
  late DiveRoleRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRoleRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('DiveRoleRepository', () {
    test('getAllDiveRoles returns 9 built-ins ordered built-in-first '
        'by sortOrder', () async {
      final roles = await repository.getAllDiveRoles();
      expect(roles.length, 9);
      expect(roles.first.id, DiveRole.buddyId);
      expect(roles.map((r) => r.id).toList(), DiveRole.builtInIds);
      expect(roles.every((r) => r.isBuiltIn), isTrue);
    });

    test('createDiveRole creates a custom role with a UUID id scoped to '
        'the diver, listed after built-ins', () async {
      final diverId = await _insertDiver();
      final created = await repository.createDiveRole(
        name: 'Hekkensluiter',
        diverId: diverId,
      );
      expect(created.isBuiltIn, isFalse);
      expect(created.diverId, diverId);
      expect(DiveRole.builtInIds, isNot(contains(created.id)));
      expect(created.id.length, 36); // uuid v4

      final roles = await repository.getAllDiveRoles(diverId: diverId);
      expect(roles.length, 10);
      expect(roles.last.id, created.id);
    });

    test('custom roles of another diver are not returned', () async {
      final diverId = await _insertDiver();
      await repository.createDiveRole(name: 'Scooter Pilot', diverId: diverId);
      final roles = await repository.getAllDiveRoles(diverId: 'other-diver');
      expect(roles.length, 9);
    });

    test('renameDiveRole renames a custom role and keeps its id', () async {
      final diverId = await _insertDiver();
      final created = await repository.createDiveRole(
        name: 'Hekkensluiter',
        diverId: diverId,
      );
      await repository.renameDiveRole(created.id, 'Sweep');
      final fetched = await repository.getDiveRoleById(created.id);
      expect(fetched!.name, 'Sweep');
    });

    test('renameDiveRole throws for built-in roles', () async {
      expect(
        () => repository.renameDiveRole(DiveRole.buddyId, 'X'),
        throwsException,
      );
    });

    test('deleteDiveRole throws for built-in roles', () async {
      expect(
        () => repository.deleteDiveRole(DiveRole.buddyId),
        throwsException,
      );
    });

    test('deleteDiveRole removes an unused custom role', () async {
      final diverId = await _insertDiver();
      final created = await repository.createDiveRole(
        name: 'Hekkensluiter',
        diverId: diverId,
      );
      await repository.deleteDiveRole(created.id);
      expect(await repository.getDiveRoleById(created.id), isNull);
    });

    test(
      'importDiveRole preserves the original id and is idempotent',
      () async {
        final diverId = await _insertDiver();
        final inserted = await repository.importDiveRole(
          id: 'restored-uuid-1',
          name: 'Hekkensluiter',
          diverId: diverId,
          sortOrder: 12,
        );
        expect(inserted, isTrue);

        final fetched = await repository.getDiveRoleById('restored-uuid-1');
        expect(fetched, isNotNull);
        expect(fetched!.name, 'Hekkensluiter');
        expect(fetched.isBuiltIn, isFalse);

        // Re-import is a no-op, not an error, and reports false.
        final again = await repository.importDiveRole(
          id: 'restored-uuid-1',
          name: 'Different Name',
          diverId: diverId,
        );
        expect(again, isFalse);
        final unchanged = await repository.getDiveRoleById('restored-uuid-1');
        expect(unchanged!.name, 'Hekkensluiter');
      },
    );

    test('isDiveRoleInUse reflects dive_buddies.role and dives.diver_role '
        'references', () async {
      final diverId = await _insertDiver();
      final created = await repository.createDiveRole(
        name: 'Hekkensluiter',
        diverId: diverId,
      );
      expect(await repository.isDiveRoleInUse(created.id), isFalse);

      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO dives (id, dive_date_time, created_at, updated_at, "
        "diver_role) VALUES ('d1', 1000, 1000, 1000, '${created.id}')",
      );
      expect(await repository.isDiveRoleInUse(created.id), isTrue);

      await db.customStatement("DELETE FROM dives WHERE id = 'd1'");
      expect(await repository.isDiveRoleInUse(created.id), isFalse);

      await db.customStatement(
        "INSERT INTO dives (id, dive_date_time, created_at, updated_at) "
        "VALUES ('d2', 1000, 1000, 1000)",
      );
      await db.customStatement(
        "INSERT INTO buddies (id, name, created_at, updated_at) "
        "VALUES ('b1', 'Bud', 1000, 1000)",
      );
      await db.customStatement(
        "INSERT INTO dive_buddies (id, dive_id, buddy_id, role, created_at) "
        "VALUES ('db1', 'd2', 'b1', '${created.id}', 1000)",
      );
      expect(await repository.isDiveRoleInUse(created.id), isTrue);
    });

    test('a role held only in a junction row is in use (#1221)', () async {
      final diverId = await _insertDiver();
      final c1 = await repository.createDiveRole(
        name: 'Photographer',
        diverId: diverId,
      );
      final c2 = await repository.createDiveRole(
        name: 'Videographer',
        diverId: diverId,
      );
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO dives (id, diver_id, dive_date_time, created_at, "
        "updated_at, diver_role) VALUES "
        "('d1', '$diverId', 1000, 1000, 1000, 'diveMaster')",
      );
      await db.customStatement(
        "INSERT INTO buddies (id, name, created_at, updated_at) "
        "VALUES ('b1', 'Bud', 1000, 1000)",
      );
      await db.customStatement(
        "INSERT INTO dive_buddies (id, dive_id, buddy_id, role, created_at) "
        "VALUES ('db1', 'd1', 'b1', 'buddy', 1000)",
      );
      expect(await repository.isDiveRoleInUse(c1.id), isFalse);
      expect(await repository.isDiveRoleInUse(c2.id), isFalse);

      await db.customStatement(
        "INSERT INTO dive_diver_roles (id, dive_id, role_id, created_at) "
        "VALUES ('r1', 'd1', '${c1.id}', 1000)",
      );
      await db.customStatement(
        'INSERT INTO dive_buddy_roles '
        '(id, dive_id, buddy_id, role_id, created_at) '
        "VALUES ('x1', 'd1', 'b1', '${c2.id}', 1000)",
      );
      expect(await repository.isDiveRoleInUse(c1.id), isTrue);
      expect(await repository.isDiveRoleInUse(c2.id), isTrue);
    });

    test('an orphan buddy role row is not a use (#1221)', () async {
      final diverId = await _insertDiver();
      final custom = await repository.createDiveRole(
        name: 'Photographer',
        diverId: diverId,
      );
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO dives (id, diver_id, dive_date_time, created_at, "
        "updated_at) VALUES ('d1', '$diverId', 1000, 1000, 1000)",
      );
      await db.customStatement(
        "INSERT INTO buddies (id, name, created_at, updated_at) "
        "VALUES ('b1', 'Bud', 1000, 1000)",
      );
      // What an older app version leaves when it removes the buddy: the
      // role row without its dive_buddies link.
      await db.customStatement(
        'INSERT INTO dive_buddy_roles '
        '(id, dive_id, buddy_id, role_id, created_at) '
        "VALUES ('x1', 'd1', 'b1', '${custom.id}', 1000)",
      );
      expect(await repository.isDiveRoleInUse(custom.id), isFalse);
    });

    test('isDiveRoleInUse ignores references from another diver\'s dives '
        '(#1806)', () async {
      final diverId = await _insertDiver();
      final created = await repository.createDiveRole(
        name: 'Hekkensluiter',
        diverId: diverId,
      );
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('diver-2', 'Second Diver', 1000, 1000)",
      );
      await db.customStatement(
        "INSERT INTO buddies (id, name, created_at, updated_at) "
        "VALUES ('b1', 'Bud', 1000, 1000)",
      );
      await db.customStatement(
        "INSERT INTO dives (id, diver_id, dive_date_time, created_at, "
        "updated_at, diver_role) VALUES "
        "('d1', 'diver-2', 1000, 1000, 1000, '${created.id}'), "
        "('d2', 'diver-2', 1000, 1000, 1000, NULL)",
      );
      await db.customStatement(
        "INSERT INTO dive_buddies (id, dive_id, buddy_id, role, created_at) "
        "VALUES ('db1', 'd2', 'b1', '${created.id}', 1000)",
      );
      expect(
        await repository.isDiveRoleInUse(created.id),
        isFalse,
        reason: 'only the owner\'s dives can hold the role',
      );

      await db.customStatement(
        "INSERT INTO dives (id, diver_id, dive_date_time, created_at, "
        "updated_at, diver_role) VALUES "
        "('d3', '$diverId', 1000, 1000, 1000, '${created.id}')",
      );
      expect(await repository.isDiveRoleInUse(created.id), isTrue);
    });
  });
}
