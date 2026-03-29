import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_merge_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('BuddyMergeRepository error handling', () {
    late BuddyMergeRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = BuddyMergeRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('methods handle database errors gracefully', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      final now = DateTime.now();
      final buddy = Buddy(
        id: 'b1',
        name: 'Merged Buddy',
        createdAt: now,
        updatedAt: now,
      );

      // mergeBuddies - rethrows
      await expectLater(
        repository.mergeBuddies(mergedBuddy: buddy, buddyIds: ['b1', 'b2']),
        throwsA(anything),
      );

      // undoMerge - rethrows
      final snapshot = BuddyMergeSnapshot(
        originalSurvivor: buddy,
        deletedBuddies: const [],
        deletedDiveBuddyEntries: const [],
        modifiedDiveBuddyEntries: const [],
      );
      await expectLater(repository.undoMerge(snapshot), throwsA(anything));

      // bulkDeleteBuddies - rethrows
      await expectLater(
        repository.bulkDeleteBuddies(['b1', 'b2']),
        throwsA(anything),
      );
    });
  });
}
