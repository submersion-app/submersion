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
  });
}
