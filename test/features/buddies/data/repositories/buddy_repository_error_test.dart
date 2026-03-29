import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('BuddyRepository error handling', () {
    late BuddyRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = BuddyRepository();
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
        name: 'Test Buddy',
        createdAt: now,
        updatedAt: now,
      );

      // getAllBuddies - rethrows
      await expectLater(repository.getAllBuddies(), throwsA(anything));

      // getBuddyById - rethrows
      await expectLater(repository.getBuddyById('b1'), throwsA(anything));

      // createBuddy - rethrows
      await expectLater(repository.createBuddy(buddy), throwsA(anything));

      // findOrCreateByName - rethrows
      await expectLater(
        repository.findOrCreateByName('Test'),
        throwsA(anything),
      );

      // updateBuddy - rethrows
      await expectLater(repository.updateBuddy(buddy), throwsA(anything));

      // deleteBuddy - rethrows
      await expectLater(repository.deleteBuddy('b1'), throwsA(anything));

      // getAllBuddiesWithDiveCount - rethrows
      await expectLater(
        repository.getAllBuddiesWithDiveCount(),
        throwsA(anything),
      );
    });
  });
}
