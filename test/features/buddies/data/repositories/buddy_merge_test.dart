import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_role_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;
import 'package:submersion/features/buddies/domain/entities/buddy_role_credential.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart'
    as cert_domain;
import 'package:submersion/core/constants/enums.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late db.AppDatabase database;
  late BuddyRepository repository;
  late BuddyRoleRepository roleRepository;
  late CertificationRepository certificationRepository;

  setUp(() async {
    await setUpTestDatabase();
    repository = BuddyRepository();
    roleRepository = BuddyRoleRepository();
    certificationRepository = CertificationRepository();
    database = DatabaseService.instance.database;
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('mergeBuddies', () {
    test('merges two buddies with no shared dives', () async {
      final buddyA = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Alice',
          email: 'alice@example.com',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final buddyB = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Bob',
          email: 'bob@example.com',
          phone: '555-0100',
          notes: 'Good buddy',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      await database
          .into(database.dives)
          .insert(
            db.DivesCompanion.insert(
              id: 'dive1',
              diveDateTime: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await repository.addBuddyToDive('dive1', buddyB.id, BuddyRole.buddy);

      final mergedBuddy = buddyA.copyWith(
        name: 'Alice',
        email: 'alice@example.com',
        phone: '555-0100',
      );
      final result = await repository.mergeBuddies(
        mergedBuddy: mergedBuddy,
        buddyIds: [buddyA.id, buddyB.id],
      );

      expect(result, isNotNull);
      expect(result!.survivorId, buddyA.id);
      expect(result.snapshot, isNotNull);

      final survivor = await repository.getBuddyById(buddyA.id);
      expect(survivor!.name, 'Alice');
      expect(survivor.phone, '555-0100');

      final deleted = await repository.getBuddyById(buddyB.id);
      expect(deleted, isNull);

      final diveBuddies = await repository.getBuddiesForDive('dive1');
      expect(diveBuddies.length, 1);
      expect(diveBuddies.first.buddy.id, buddyA.id);
      expect(diveBuddies.first.role, BuddyRole.buddy);
    });

    test('collision: keeps higher-ranked role (instructor > buddy)', () async {
      final buddyA = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Alice',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final buddyB = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Bob',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      await database
          .into(database.dives)
          .insert(
            db.DivesCompanion.insert(
              id: 'dive1',
              diveDateTime: now,
              createdAt: now,
              updatedAt: now,
            ),
          );

      await repository.addBuddyToDive('dive1', buddyA.id, BuddyRole.buddy);
      await repository.addBuddyToDive('dive1', buddyB.id, BuddyRole.instructor);

      final result = await repository.mergeBuddies(
        mergedBuddy: buddyA.copyWith(name: 'Alice'),
        buddyIds: [buddyA.id, buddyB.id],
      );

      final diveBuddies = await repository.getBuddiesForDive('dive1');
      expect(diveBuddies.length, 1);
      expect(diveBuddies.first.buddy.id, buddyA.id);
      expect(diveBuddies.first.role, BuddyRole.instructor);

      expect(result!.snapshot!.modifiedDiveBuddyEntries.length, 1);
      expect(result.snapshot!.modifiedDiveBuddyEntries.first.role, 'buddy');
    });

    test('merges 3 buddies with overlapping dives', () async {
      final buddyA = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'A',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final buddyB = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'B',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final buddyC = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'C',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      await database
          .into(database.dives)
          .insert(
            db.DivesCompanion.insert(
              id: 'dive1',
              diveDateTime: now,
              createdAt: now,
              updatedAt: now,
            ),
          );

      await repository.addBuddyToDive('dive1', buddyA.id, BuddyRole.buddy);
      await repository.addBuddyToDive('dive1', buddyB.id, BuddyRole.diveMaster);
      await repository.addBuddyToDive('dive1', buddyC.id, BuddyRole.instructor);

      await repository.mergeBuddies(
        mergedBuddy: buddyA.copyWith(name: 'A'),
        buddyIds: [buddyA.id, buddyB.id, buddyC.id],
      );

      final diveBuddies = await repository.getBuddiesForDive('dive1');
      expect(diveBuddies.length, 1);
      expect(diveBuddies.first.buddy.id, buddyA.id);
      expect(diveBuddies.first.role, BuddyRole.instructor);
    });

    test('merges buddy with no dives', () async {
      final buddyA = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Alice',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final buddyB = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Bob',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final result = await repository.mergeBuddies(
        mergedBuddy: buddyA.copyWith(name: 'Alice'),
        buddyIds: [buddyA.id, buddyB.id],
      );

      expect(result, isNotNull);
      expect(result!.survivorId, buddyA.id);
      expect(await repository.getBuddyById(buddyB.id), isNull);
    });
  });

  group('mergeBuddies - credentials and certifications (issue #395)', () {
    test('merge relinks duplicate buddy credentials to the survivor', () async {
      final buddyA = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Alice',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final buddyB = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Bob',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Duplicate (buddyB) has an instructor credential; survivor (buddyA)
      // has none.
      final now = DateTime.now();
      await roleRepository.setRolesForBuddy(buddyB.id, [
        BuddyRoleCredential(
          id: '',
          buddyId: buddyB.id,
          role: BuddyRole.instructor,
          credentialNumber: 'INS-100',
          agency: CertificationAgency.padi,
          notes: '',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final originalRow = await (database.select(
        database.buddyRoles,
      )..where((t) => t.buddyId.equals(buddyB.id))).getSingle();

      await repository.mergeBuddies(
        mergedBuddy: buddyA.copyWith(name: 'Alice'),
        buddyIds: [buddyA.id, buddyB.id],
      );

      final survivorRoles = await (database.select(
        database.buddyRoles,
      )..where((t) => t.buddyId.equals(buddyA.id))).get();
      expect(survivorRoles.length, 1);
      expect(survivorRoles.first.id, originalRow.id);
      expect(survivorRoles.first.role, 'instructor');
      expect(survivorRoles.first.credentialNumber, 'INS-100');

      final duplicateRoles = await (database.select(
        database.buddyRoles,
      )..where((t) => t.buddyId.equals(buddyB.id))).get();
      expect(duplicateRoles, isEmpty);
    });

    test('merge drops a duplicate credential when the survivor already has '
        'that role, keeping the survivor row', () async {
      final buddyA = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Alice',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final buddyB = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Bob',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Both hold an instructor credential.
      final now = DateTime.now();
      await roleRepository.setRolesForBuddy(buddyA.id, [
        BuddyRoleCredential(
          id: '',
          buddyId: buddyA.id,
          role: BuddyRole.instructor,
          credentialNumber: 'A-INS',
          agency: CertificationAgency.padi,
          notes: '',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      await roleRepository.setRolesForBuddy(buddyB.id, [
        BuddyRoleCredential(
          id: '',
          buddyId: buddyB.id,
          role: BuddyRole.instructor,
          credentialNumber: 'B-INS',
          agency: CertificationAgency.ssi,
          notes: '',
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await repository.mergeBuddies(
        mergedBuddy: buddyA.copyWith(name: 'Alice'),
        buddyIds: [buddyA.id, buddyB.id],
      );

      final allInstructorRows = await (database.select(
        database.buddyRoles,
      )..where((t) => t.role.equals('instructor'))).get();
      expect(allInstructorRows.length, 1);
      expect(allInstructorRows.first.buddyId, buddyA.id);
      expect(allInstructorRows.first.credentialNumber, 'A-INS');

      final duplicateRoles = await (database.select(
        database.buddyRoles,
      )..where((t) => t.buddyId.equals(buddyB.id))).get();
      expect(duplicateRoles, isEmpty);
    });

    test(
      'merge re-points certifications.instructorId to the survivor',
      () async {
        final buddyA = await repository.createBuddy(
          domain.Buddy(
            id: '',
            name: 'Alice',
            notes: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        final buddyB = await repository.createBuddy(
          domain.Buddy(
            id: '',
            name: 'Bob',
            notes: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final now = DateTime.now();
        final cert = await certificationRepository.createCertification(
          cert_domain.Certification(
            id: '',
            name: 'Open Water Diver',
            agency: CertificationAgency.padi,
            instructorId: buddyB.id,
            notes: '',
            createdAt: now,
            updatedAt: now,
          ),
        );

        await repository.mergeBuddies(
          mergedBuddy: buddyA.copyWith(name: 'Alice'),
          buddyIds: [buddyA.id, buddyB.id],
        );

        final row = await (database.select(
          database.certifications,
        )..where((t) => t.id.equals(cert.id))).getSingle();
        expect(row.instructorId, buddyA.id);
      },
    );
  });

  group('undoMerge', () {
    test('restores all buddies and junction entries', () async {
      final buddyA = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Alice',
          email: 'alice@test.com',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final buddyB = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Bob',
          phone: '555-0100',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      await database
          .into(database.dives)
          .insert(
            db.DivesCompanion.insert(
              id: 'dive1',
              diveDateTime: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await database
          .into(database.dives)
          .insert(
            db.DivesCompanion.insert(
              id: 'dive2',
              diveDateTime: now,
              createdAt: now,
              updatedAt: now,
            ),
          );

      await repository.addBuddyToDive('dive1', buddyA.id, BuddyRole.buddy);
      await repository.addBuddyToDive('dive1', buddyB.id, BuddyRole.instructor);
      await repository.addBuddyToDive('dive2', buddyB.id, BuddyRole.buddy);

      final result = await repository.mergeBuddies(
        mergedBuddy: buddyA.copyWith(name: 'Alice', phone: '555-0100'),
        buddyIds: [buddyA.id, buddyB.id],
      );

      // Undo
      await repository.undoMerge(result!.snapshot!);

      // Both buddies should exist again
      final restoredA = await repository.getBuddyById(buddyA.id);
      final restoredB = await repository.getBuddyById(buddyB.id);
      expect(restoredA, isNotNull);
      expect(restoredB, isNotNull);
      expect(restoredA!.name, 'Alice');
      expect(restoredA.email, 'alice@test.com');

      // Original dive assignments should be restored
      final dive1Buddies = await repository.getBuddiesForDive('dive1');
      expect(dive1Buddies.length, 2);

      final dive2Buddies = await repository.getBuddiesForDive('dive2');
      expect(dive2Buddies.length, 1);
      expect(dive2Buddies.first.buddy.id, buddyB.id);
    });

    test(
      'undoMerge restores duplicate credentials and certification links',
      () async {
        final buddyA = await repository.createBuddy(
          domain.Buddy(
            id: '',
            name: 'Alice',
            notes: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        final buddyB = await repository.createBuddy(
          domain.Buddy(
            id: '',
            name: 'Bob',
            notes: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final now = DateTime.now();

        // Survivor already holds an instructor credential (collision case).
        await roleRepository.setRolesForBuddy(buddyA.id, [
          BuddyRoleCredential(
            id: '',
            buddyId: buddyA.id,
            role: BuddyRole.instructor,
            credentialNumber: 'A-INS',
            agency: CertificationAgency.padi,
            notes: '',
            createdAt: now,
            updatedAt: now,
          ),
        ]);
        // Duplicate holds a colliding instructor credential (dropped) and a
        // dive master credential (relinked).
        await roleRepository.setRolesForBuddy(buddyB.id, [
          BuddyRoleCredential(
            id: '',
            buddyId: buddyB.id,
            role: BuddyRole.instructor,
            credentialNumber: 'B-INS',
            agency: CertificationAgency.ssi,
            notes: '',
            createdAt: now,
            updatedAt: now,
          ),
          BuddyRoleCredential(
            id: '',
            buddyId: buddyB.id,
            role: BuddyRole.diveMaster,
            credentialNumber: 'B-DM',
            agency: CertificationAgency.padi,
            notes: '',
            createdAt: now,
            updatedAt: now,
          ),
        ]);
        final originalDuplicateRoles = await (database.select(
          database.buddyRoles,
        )..where((t) => t.buddyId.equals(buddyB.id))).get();
        expect(originalDuplicateRoles.length, 2);

        final cert = await certificationRepository.createCertification(
          cert_domain.Certification(
            id: '',
            name: 'Open Water Diver',
            agency: CertificationAgency.padi,
            instructorId: buddyB.id,
            notes: '',
            createdAt: now,
            updatedAt: now,
          ),
        );

        final result = await repository.mergeBuddies(
          mergedBuddy: buddyA.copyWith(name: 'Alice'),
          buddyIds: [buddyA.id, buddyB.id],
        );

        // Sanity check the merge actually mutated state before undoing.
        final mergedCert = await (database.select(
          database.certifications,
        )..where((t) => t.id.equals(cert.id))).getSingle();
        expect(mergedCert.instructorId, buddyA.id);

        await repository.undoMerge(result!.snapshot!);

        // Duplicate buddy's credentials are restored with original ids.
        final restoredDuplicateRoles = await (database.select(
          database.buddyRoles,
        )..where((t) => t.buddyId.equals(buddyB.id))).get();
        expect(restoredDuplicateRoles.length, 2);
        expect(
          restoredDuplicateRoles.map((r) => r.id).toSet(),
          originalDuplicateRoles.map((r) => r.id).toSet(),
        );
        expect(restoredDuplicateRoles.map((r) => r.credentialNumber).toSet(), {
          'B-INS',
          'B-DM',
        });

        // Survivor's original credential set is restored (no leftover
        // relinked rows from the duplicate).
        final survivorRoles = await (database.select(
          database.buddyRoles,
        )..where((t) => t.buddyId.equals(buddyA.id))).get();
        expect(survivorRoles.length, 1);
        expect(survivorRoles.first.credentialNumber, 'A-INS');

        // Certification instructor link restored to the duplicate.
        final restoredCert = await (database.select(
          database.certifications,
        )..where((t) => t.id.equals(cert.id))).getSingle();
        expect(restoredCert.instructorId, buddyB.id);
      },
    );
  });

  group('bulkDeleteBuddies', () {
    test('deletes multiple buddies', () async {
      final buddyA = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'A',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final buddyB = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'B',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await repository.bulkDeleteBuddies([buddyA.id, buddyB.id]);

      expect(await repository.getBuddyById(buddyA.id), isNull);
      expect(await repository.getBuddyById(buddyB.id), isNull);
    });
  });
}
