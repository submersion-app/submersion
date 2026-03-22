import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;
import 'package:submersion/core/constants/enums.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late db.AppDatabase database;
  late BuddyRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = BuddyRepository();
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
