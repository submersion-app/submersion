import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_role_credential.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late BuddyRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = ON');
    repository = BuddyRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  domain.Buddy buddyFixture(String name) {
    final now = DateTime.now();
    return domain.Buddy(id: '', name: name, createdAt: now, updatedAt: now);
  }

  group('BuddyRepository role CRUD', () {
    test('setRolesForBuddy inserts and getRolesForBuddy reads back', () async {
      final buddy = await repository.createBuddy(buddyFixture('Alice'));
      final now = DateTime.now();
      await repository.setRolesForBuddy(buddy.id, [
        BuddyRoleCredential(
          id: '',
          buddyId: buddy.id,
          role: BuddyRole.instructor,
          credentialNumber: '12345',
          agency: CertificationAgency.padi,
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final roles = await repository.getRolesForBuddy(buddy.id);
      expect(roles, hasLength(1));
      expect(roles.single.role, BuddyRole.instructor);
      expect(roles.single.credentialNumber, '12345');
      expect(roles.single.agency, CertificationAgency.padi);
    });

    test('setRolesForBuddy dedupes by role (last wins)', () async {
      final buddy = await repository.createBuddy(buddyFixture('Bob'));
      final now = DateTime.now();
      await repository.setRolesForBuddy(buddy.id, [
        BuddyRoleCredential(
          id: '',
          buddyId: buddy.id,
          role: BuddyRole.instructor,
          credentialNumber: '111',
          createdAt: now,
          updatedAt: now,
        ),
        BuddyRoleCredential(
          id: '',
          buddyId: buddy.id,
          role: BuddyRole.instructor,
          credentialNumber: '222',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final roles = await repository.getRolesForBuddy(buddy.id);
      expect(roles, hasLength(1));
      expect(roles.single.credentialNumber, '222');
    });

    test('setRolesForBuddy preserves the row id of a kept role', () async {
      final buddy = await repository.createBuddy(buddyFixture('Carol'));
      final now = DateTime.now();
      await repository.setRolesForBuddy(buddy.id, [
        BuddyRoleCredential(
          id: '',
          buddyId: buddy.id,
          role: BuddyRole.instructor,
          credentialNumber: '111',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final firstRoles = await repository.getRolesForBuddy(buddy.id);
      final originalId = firstRoles.single.id;

      await repository.setRolesForBuddy(buddy.id, [
        BuddyRoleCredential(
          id: '',
          buddyId: buddy.id,
          role: BuddyRole.instructor,
          credentialNumber: '999',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final secondRoles = await repository.getRolesForBuddy(buddy.id);
      expect(secondRoles, hasLength(1));
      expect(secondRoles.single.id, originalId);
      expect(secondRoles.single.credentialNumber, '999');
    });

    test('setRolesForBuddy removes roles omitted from the new list', () async {
      final buddy = await repository.createBuddy(buddyFixture('Dave'));
      final now = DateTime.now();
      await repository.setRolesForBuddy(buddy.id, [
        BuddyRoleCredential(
          id: '',
          buddyId: buddy.id,
          role: BuddyRole.instructor,
          createdAt: now,
          updatedAt: now,
        ),
        BuddyRoleCredential(
          id: '',
          buddyId: buddy.id,
          role: BuddyRole.diveMaster,
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      await repository.setRolesForBuddy(buddy.id, [
        BuddyRoleCredential(
          id: '',
          buddyId: buddy.id,
          role: BuddyRole.instructor,
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final roles = await repository.getRolesForBuddy(buddy.id);
      expect(roles, hasLength(1));
      expect(roles.single.role, BuddyRole.instructor);
    });

    test('deleting a buddy cascades its buddy_roles rows (FK ON)', () async {
      final buddy = await repository.createBuddy(buddyFixture('Erin'));
      final now = DateTime.now();
      await repository.setRolesForBuddy(buddy.id, [
        BuddyRoleCredential(
          id: '',
          buddyId: buddy.id,
          role: BuddyRole.instructor,
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await repository.deleteBuddy(buddy.id);

      final countResult = await db
          .customSelect('SELECT COUNT(*) as count FROM buddy_roles')
          .getSingle();
      expect(countResult.data['count'], 0);
    });

    test('getAllRoles returns a buddyId-keyed map', () async {
      final credentialed = await repository.createBuddy(buddyFixture('Frank'));
      final plain = await repository.createBuddy(buddyFixture('Gina'));
      final now = DateTime.now();
      await repository.setRolesForBuddy(credentialed.id, [
        BuddyRoleCredential(
          id: '',
          buddyId: credentialed.id,
          role: BuddyRole.diveGuide,
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      final map = await repository.getAllRoles();

      expect(map.containsKey(credentialed.id), isTrue);
      expect(map[credentialed.id], hasLength(1));
      expect(map.containsKey(plain.id), isFalse);
    });
  });

  group('BuddyRepository role forward-compatibility (unknown role values)', () {
    Future<void> insertRawRoleRow(
      String buddyId,
      String roleName, {
      String id = 'raw-future-role',
    }) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.buddyRoles)
          .insert(
            BuddyRolesCompanion(
              id: Value(id),
              buddyId: Value(buddyId),
              role: Value(roleName),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }

    test(
      'getRolesForBuddy omits rows with an unrecognized role value',
      () async {
        final buddy = await repository.createBuddy(buddyFixture('Helen'));
        await insertRawRoleRow(buddy.id, 'someFutureRole');

        final roles = await repository.getRolesForBuddy(buddy.id);

        expect(roles, isEmpty);
      },
    );

    test('getAllRoles omits rows with an unrecognized role value', () async {
      final buddy = await repository.createBuddy(buddyFixture('Ian'));
      await insertRawRoleRow(buddy.id, 'someFutureRole');

      final map = await repository.getAllRoles();

      expect(map.containsKey(buddy.id), isFalse);
    });

    test(
      'setRolesForBuddy leaves an unrecognized-role row present and untombstoned',
      () async {
        final buddy = await repository.createBuddy(buddyFixture('Jack'));
        await insertRawRoleRow(buddy.id, 'someFutureRole');
        final now = DateTime.now();

        await repository.setRolesForBuddy(buddy.id, [
          BuddyRoleCredential(
            id: '',
            buddyId: buddy.id,
            role: BuddyRole.instructor,
            createdAt: now,
            updatedAt: now,
          ),
        ]);

        final rawRow = await (db.select(
          db.buddyRoles,
        )..where((t) => t.id.equals('raw-future-role'))).getSingleOrNull();
        expect(rawRow != null, isTrue);
        expect(rawRow!.role, 'someFutureRole');

        final deletionCount = await db
            .customSelect(
              "SELECT COUNT(*) as count FROM deletion_log WHERE record_id = 'raw-future-role'",
            )
            .getSingle();
        expect(deletionCount.data['count'], 0);
      },
    );

    test(
      'professional roles still behave as before alongside an unknown row',
      () async {
        final buddy = await repository.createBuddy(buddyFixture('Kara'));
        await insertRawRoleRow(buddy.id, 'someFutureRole');
        final now = DateTime.now();

        await repository.setRolesForBuddy(buddy.id, [
          BuddyRoleCredential(
            id: '',
            buddyId: buddy.id,
            role: BuddyRole.instructor,
            credentialNumber: '555',
            createdAt: now,
            updatedAt: now,
          ),
        ]);

        final roles = await repository.getRolesForBuddy(buddy.id);
        expect(roles, hasLength(1));
        expect(roles.single.role, BuddyRole.instructor);
        expect(roles.single.credentialNumber, '555');

        // Removing the professional role should still delete it normally.
        await repository.setRolesForBuddy(buddy.id, []);
        final rolesAfterClear = await repository.getRolesForBuddy(buddy.id);
        expect(rolesAfterClear, isEmpty);

        // The unrecognized row is still untouched throughout.
        final rawRow = await (db.select(
          db.buddyRoles,
        )..where((t) => t.id.equals('raw-future-role'))).getSingleOrNull();
        expect(rawRow != null, isTrue);
      },
    );
  });

  group('BuddyRepository setRolesForBuddy no-op update guard', () {
    test(
      'calling setRolesForBuddy twice with identical data leaves updatedAt/hlc unchanged',
      () async {
        final buddy = await repository.createBuddy(buddyFixture('Liam'));
        final now = DateTime.now();

        await repository.setRolesForBuddy(buddy.id, [
          BuddyRoleCredential(
            id: '',
            buddyId: buddy.id,
            role: BuddyRole.instructor,
            credentialNumber: '777',
            agency: CertificationAgency.padi,
            createdAt: now,
            updatedAt: now,
          ),
        ]);

        final before = await (db.select(
          db.buddyRoles,
        )..where((t) => t.buddyId.equals(buddy.id))).getSingle();

        // Re-save with identical credential data (simulating an unrelated
        // buddy field edit that still passes the same role list through).
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await repository.setRolesForBuddy(buddy.id, [
          BuddyRoleCredential(
            id: before.id,
            buddyId: buddy.id,
            role: BuddyRole.instructor,
            credentialNumber: '777',
            agency: CertificationAgency.padi,
            createdAt: now,
            updatedAt: now,
          ),
        ]);

        final after = await (db.select(
          db.buddyRoles,
        )..where((t) => t.buddyId.equals(buddy.id))).getSingle();

        expect(after.updatedAt, before.updatedAt);
        expect(after.hlc, before.hlc);
      },
    );

    test('a changed credential number still updates', () async {
      final buddy = await repository.createBuddy(buddyFixture('Mona'));
      final now = DateTime.now();

      await repository.setRolesForBuddy(buddy.id, [
        BuddyRoleCredential(
          id: '',
          buddyId: buddy.id,
          role: BuddyRole.instructor,
          credentialNumber: '111',
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      final before = await (db.select(
        db.buddyRoles,
      )..where((t) => t.buddyId.equals(buddy.id))).getSingle();

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repository.setRolesForBuddy(buddy.id, [
        BuddyRoleCredential(
          id: before.id,
          buddyId: buddy.id,
          role: BuddyRole.instructor,
          credentialNumber: '222',
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      final after = await (db.select(
        db.buddyRoles,
      )..where((t) => t.buddyId.equals(buddy.id))).getSingle();

      expect(after.credentialNumber, '222');
      expect(after.updatedAt, greaterThan(before.updatedAt));
    });

    test(
      'an unknown agency string reads back as CertificationAgency.other',
      () async {
        final buddy = await repository.createBuddy(buddyFixture('Alice'));
        final now = DateTime.now().millisecondsSinceEpoch;
        await db
            .into(db.buddyRoles)
            .insert(
              BuddyRolesCompanion(
                id: const Value('role-agency'),
                buddyId: Value(buddy.id),
                role: const Value('instructor'),
                agency: const Value('someFutureAgency'),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );

        final roles = await repository.getRolesForBuddy(buddy.id);
        expect(roles.single.agency, CertificationAgency.other);
      },
    );

    test('buddyRolesProvider and allBuddyRolesProvider read through the '
        'repository', () async {
      final buddy = await repository.createBuddy(buddyFixture('Alice'));
      final now = DateTime.now();
      await repository.setRolesForBuddy(buddy.id, [
        BuddyRoleCredential(
          id: '',
          buddyId: buddy.id,
          role: BuddyRole.instructor,
          credentialNumber: '12345',
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final single = await container.read(buddyRolesProvider(buddy.id).future);
      expect(single.single.credentialNumber, '12345');

      final all = await container.read(allBuddyRolesProvider.future);
      expect(all[buddy.id]!.single.role, BuddyRole.instructor);
    });
  });
}
