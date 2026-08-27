import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart'
    as cert_domain;
import 'package:submersion/core/constants/enums.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late db.AppDatabase database;
  late BuddyRepository repository;
  late CertificationRepository certificationRepository;

  setUp(() async {
    await setUpTestDatabase();
    repository = BuddyRepository();
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
      await repository.addBuddyToDive('dive1', buddyB.id, DiveRole.buddyId);

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
      expect(diveBuddies.first.role.id, DiveRole.buddyId);
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

      await repository.addBuddyToDive('dive1', buddyA.id, DiveRole.buddyId);
      await repository.addBuddyToDive(
        'dive1',
        buddyB.id,
        DiveRole.instructorId,
      );

      final result = await repository.mergeBuddies(
        mergedBuddy: buddyA.copyWith(name: 'Alice'),
        buddyIds: [buddyA.id, buddyB.id],
      );

      final diveBuddies = await repository.getBuddiesForDive('dive1');
      expect(diveBuddies.length, 1);
      expect(diveBuddies.first.buddy.id, buddyA.id);
      expect(diveBuddies.first.role.id, DiveRole.instructorId);

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

      await repository.addBuddyToDive('dive1', buddyA.id, DiveRole.buddyId);
      await repository.addBuddyToDive(
        'dive1',
        buddyB.id,
        DiveRole.diveMasterId,
      );
      await repository.addBuddyToDive(
        'dive1',
        buddyC.id,
        DiveRole.instructorId,
      );

      await repository.mergeBuddies(
        mergedBuddy: buddyA.copyWith(name: 'A'),
        buddyIds: [buddyA.id, buddyB.id, buddyC.id],
      );

      final diveBuddies = await repository.getBuddiesForDive('dive1');
      expect(diveBuddies.length, 1);
      expect(diveBuddies.first.buddy.id, buddyA.id);
      expect(diveBuddies.first.role.id, DiveRole.instructorId);
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

  group('mergeBuddies - certifications (issue #395)', () {
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

        final preMergeRow = await (database.select(
          database.certifications,
        )..where((t) => t.id.equals(cert.id))).getSingle();

        await repository.mergeBuddies(
          mergedBuddy: buddyA.copyWith(name: 'Alice'),
          buddyIds: [buddyA.id, buddyB.id],
        );

        final row = await (database.select(
          database.certifications,
        )..where((t) => t.id.equals(cert.id))).getSingle();
        expect(row.instructorId, buddyA.id);
        // The re-point is a real mutation: updatedAt must move alongside it.
        expect(row.updatedAt, greaterThan(preMergeRow.updatedAt));
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

      await repository.addBuddyToDive('dive1', buddyA.id, DiveRole.buddyId);
      await repository.addBuddyToDive(
        'dive1',
        buddyB.id,
        DiveRole.instructorId,
      );
      await repository.addBuddyToDive('dive2', buddyB.id, DiveRole.buddyId);

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

    test('undoMerge restores certification instructor links', () async {
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

      // Certification instructor link restored to the duplicate.
      final restoredCert = await (database.select(
        database.certifications,
      )..where((t) => t.id.equals(cert.id))).getSingle();
      expect(restoredCert.instructorId, buddyB.id);
    });
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
