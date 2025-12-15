import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late BuddyRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = BuddyRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Buddy createTestBuddy({
    String id = '',
    String name = 'Test Buddy',
    String? email,
    String? phone,
    CertificationLevel? certificationLevel,
    CertificationAgency? certificationAgency,
    String notes = '',
  }) {
    final now = DateTime.now();
    return Buddy(
      id: id,
      name: name,
      email: email,
      phone: phone,
      certificationLevel: certificationLevel,
      certificationAgency: certificationAgency,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('BuddyRepository', () {
    group('createBuddy', () {
      test('should create a new buddy with generated ID when ID is empty', () async {
        final buddy = createTestBuddy(name: 'John Doe');

        final createdBuddy = await repository.createBuddy(buddy);

        expect(createdBuddy.id, isNotEmpty);
        expect(createdBuddy.name, equals('John Doe'));
      });

      test('should create a buddy with provided ID', () async {
        final buddy = createTestBuddy(id: 'custom-buddy-id', name: 'Jane Doe');

        final createdBuddy = await repository.createBuddy(buddy);

        expect(createdBuddy.id, equals('custom-buddy-id'));
      });

      test('should create a buddy with all fields', () async {
        final buddy = createTestBuddy(
          name: 'Complete Diver',
          email: 'diver@example.com',
          phone: '+1-555-1234',
          certificationLevel: CertificationLevel.advancedOpenWater,
          certificationAgency: CertificationAgency.padi,
          notes: 'Great dive buddy',
        );

        final createdBuddy = await repository.createBuddy(buddy);
        final fetchedBuddy = await repository.getBuddyById(createdBuddy.id);

        expect(fetchedBuddy, isNotNull);
        expect(fetchedBuddy!.name, equals('Complete Diver'));
        expect(fetchedBuddy.email, equals('diver@example.com'));
        expect(fetchedBuddy.phone, equals('+1-555-1234'));
        expect(fetchedBuddy.certificationLevel, equals(CertificationLevel.advancedOpenWater));
        expect(fetchedBuddy.certificationAgency, equals(CertificationAgency.padi));
        expect(fetchedBuddy.notes, equals('Great dive buddy'));
      });
    });

    group('getBuddyById', () {
      test('should return buddy when found', () async {
        final buddy = await repository.createBuddy(createTestBuddy(name: 'Find Me'));

        final result = await repository.getBuddyById(buddy.id);

        expect(result, isNotNull);
        expect(result!.name, equals('Find Me'));
      });

      test('should return null when buddy not found', () async {
        final result = await repository.getBuddyById('non-existent-id');

        expect(result, isNull);
      });
    });

    group('getAllBuddies', () {
      test('should return empty list when no buddies exist', () async {
        final result = await repository.getAllBuddies();

        expect(result, isEmpty);
      });

      test('should return all buddies ordered by name', () async {
        await repository.createBuddy(createTestBuddy(name: 'Zack'));
        await repository.createBuddy(createTestBuddy(name: 'Alice'));
        await repository.createBuddy(createTestBuddy(name: 'Mike'));

        final result = await repository.getAllBuddies();

        expect(result.length, equals(3));
        expect(result[0].name, equals('Alice'));
        expect(result[1].name, equals('Mike'));
        expect(result[2].name, equals('Zack'));
      });
    });

    group('updateBuddy', () {
      test('should update buddy fields', () async {
        final buddy = await repository.createBuddy(createTestBuddy(
          name: 'Original Name',
          email: 'old@example.com',
        ));

        final updatedBuddy = buddy.copyWith(
          name: 'Updated Name',
          email: 'new@example.com',
          phone: '+1-555-9999',
        );

        await repository.updateBuddy(updatedBuddy);
        final result = await repository.getBuddyById(buddy.id);

        expect(result, isNotNull);
        expect(result!.name, equals('Updated Name'));
        expect(result.email, equals('new@example.com'));
        expect(result.phone, equals('+1-555-9999'));
      });

      test('should update certification info', () async {
        final buddy = await repository.createBuddy(createTestBuddy(name: 'Cert Buddy'));

        final updatedBuddy = buddy.copyWith(
          certificationLevel: CertificationLevel.rescue,
          certificationAgency: CertificationAgency.ssi,
        );

        await repository.updateBuddy(updatedBuddy);
        final result = await repository.getBuddyById(buddy.id);

        expect(result!.certificationLevel, equals(CertificationLevel.rescue));
        expect(result.certificationAgency, equals(CertificationAgency.ssi));
      });
    });

    group('deleteBuddy', () {
      test('should delete existing buddy', () async {
        final buddy = await repository.createBuddy(createTestBuddy(name: 'To Delete'));

        await repository.deleteBuddy(buddy.id);
        final result = await repository.getBuddyById(buddy.id);

        expect(result, isNull);
      });

      test('should not throw when deleting non-existent buddy', () async {
        await expectLater(
          repository.deleteBuddy('non-existent-id'),
          completes,
        );
      });
    });

    group('searchBuddies', () {
      setUp(() async {
        await repository.createBuddy(createTestBuddy(
          name: 'John Smith',
          email: 'john@dive.com',
          phone: '+1-555-1111',
        ));
        await repository.createBuddy(createTestBuddy(
          name: 'Jane Doe',
          email: 'jane@ocean.com',
          phone: '+1-555-2222',
        ));
        await repository.createBuddy(createTestBuddy(
          name: 'Bob Johnson',
          email: 'bob@reef.com',
          phone: '+1-555-3333',
        ));
      });

      test('should find buddies by name', () async {
        final results = await repository.searchBuddies('John');

        expect(results.length, equals(2)); // John Smith and Bob Johnson
      });

      test('should find buddies by email', () async {
        final results = await repository.searchBuddies('ocean');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Jane Doe'));
      });

      test('should find buddies by phone', () async {
        final results = await repository.searchBuddies('555-1111');

        expect(results.length, equals(1));
        expect(results[0].name, equals('John Smith'));
      });

      test('should return empty list for no matches', () async {
        final results = await repository.searchBuddies('NonExistent');

        expect(results, isEmpty);
      });

      test('should be case insensitive', () async {
        final results = await repository.searchBuddies('JANE');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Jane Doe'));
      });
    });

    group('getDiveCountForBuddy', () {
      test('should return 0 when buddy has no dives', () async {
        final buddy = await repository.createBuddy(createTestBuddy(name: 'New Buddy'));

        final count = await repository.getDiveCountForBuddy(buddy.id);

        expect(count, equals(0));
      });
    });

    group('getBuddyStats', () {
      test('should return stats with zero dives for new buddy', () async {
        final buddy = await repository.createBuddy(createTestBuddy(name: 'Stats Buddy'));

        final stats = await repository.getBuddyStats(buddy.id);

        expect(stats.totalDives, equals(0));
        expect(stats.firstDive, isNull);
        expect(stats.lastDive, isNull);
        expect(stats.favoriteSite, isNull);
      });
    });

    group('dive buddy relationships', () {
      late String buddyId;

      setUp(() async {
        final buddy = await repository.createBuddy(createTestBuddy(name: 'Dive Partner'));
        buddyId = buddy.id;
      });

      test('getBuddiesForDive should return empty list when no buddies assigned', () async {
        final buddies = await repository.getBuddiesForDive('some-dive-id');

        expect(buddies, isEmpty);
      });

      test('getDiveIdsForBuddy should return empty list when buddy has no dives', () async {
        final diveIds = await repository.getDiveIdsForBuddy(buddyId);

        expect(diveIds, isEmpty);
      });
    });
  });
}
