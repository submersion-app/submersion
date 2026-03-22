import 'package:drift/drift.dart' show Value;
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
  });
}
