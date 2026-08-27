import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late BuddyRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
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
      test(
        'should create a new buddy with generated ID when ID is empty',
        () async {
          final buddy = createTestBuddy(name: 'John Doe');

          final createdBuddy = await repository.createBuddy(buddy);

          expect(createdBuddy.id, isNotEmpty);
          expect(createdBuddy.name, equals('John Doe'));
        },
      );

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
          notes: 'Great dive buddy',
        );

        final createdBuddy = await repository.createBuddy(buddy);
        final fetchedBuddy = await repository.getBuddyById(createdBuddy.id);

        expect(fetchedBuddy, isNotNull);
        expect(fetchedBuddy!.name, equals('Complete Diver'));
        expect(fetchedBuddy.email, equals('diver@example.com'));
        expect(fetchedBuddy.phone, equals('+1-555-1234'));
        expect(fetchedBuddy.notes, equals('Great dive buddy'));
        // Certifications are no longer stored on the buddy (issue #553); they
        // live in the certifications table and are derived on read.
        expect(fetchedBuddy.certificationLevel, isNull);
        expect(fetchedBuddy.certificationAgency, isNull);
      });
    });

    group('getBuddyById', () {
      test('should return buddy when found', () async {
        final buddy = await repository.createBuddy(
          createTestBuddy(name: 'Find Me'),
        );

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
        final buddy = await repository.createBuddy(
          createTestBuddy(name: 'Original Name', email: 'old@example.com'),
        );

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

      test('updateBuddy does not persist certification fields (they are '
          'derived from the certifications table, issue #553)', () async {
        final buddy = await repository.createBuddy(
          createTestBuddy(name: 'Cert Buddy'),
        );

        // Setting cert fields on the entity is now ignored by updateBuddy;
        // buddy certs are managed through CertificationRepository.
        final updatedBuddy = buddy.copyWith(
          certificationLevel: CertificationLevel.rescue,
          certificationAgency: CertificationAgency.ssi,
        );
        await repository.updateBuddy(updatedBuddy);
        final result = await repository.getBuddyById(buddy.id);

        expect(result!.certificationLevel, isNull);
        expect(result.certificationAgency, isNull);
      });
    });

    group('deleteBuddy', () {
      test('should delete existing buddy', () async {
        final buddy = await repository.createBuddy(
          createTestBuddy(name: 'To Delete'),
        );

        await repository.deleteBuddy(buddy.id);
        final result = await repository.getBuddyById(buddy.id);

        expect(result, isNull);
      });

      test('should not throw when deleting non-existent buddy', () async {
        await expectLater(repository.deleteBuddy('non-existent-id'), completes);
      });
    });

    group('searchBuddies', () {
      setUp(() async {
        await repository.createBuddy(
          createTestBuddy(
            name: 'John Smith',
            email: 'john@dive.com',
            phone: '+1-555-1111',
          ),
        );
        await repository.createBuddy(
          createTestBuddy(
            name: 'Jane Doe',
            email: 'jane@ocean.com',
            phone: '+1-555-2222',
          ),
        );
        await repository.createBuddy(
          createTestBuddy(
            name: 'Bob Johnson',
            email: 'bob@reef.com',
            phone: '+1-555-3333',
          ),
        );
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
        final buddy = await repository.createBuddy(
          createTestBuddy(name: 'New Buddy'),
        );

        final count = await repository.getDiveCountForBuddy(buddy.id);

        expect(count, equals(0));
      });
    });

    group('getAllBuddiesWithDiveCount (issue #638)', () {
      Future<void> insertDive(String id) async {
        final db = DatabaseService.instance.database;
        await db.customStatement(
          "INSERT INTO dives (id, dive_date_time, created_at, updated_at) "
          "VALUES ('$id', 1000, 1000, 1000)",
        );
      }

      test('reports the correct dive count per buddy', () async {
        await insertDive('d1');
        await insertDive('d2');
        final frequent = await repository.createBuddy(
          createTestBuddy(id: 'frequent', name: 'Frequent Buddy'),
        );
        final rare = await repository.createBuddy(
          createTestBuddy(id: 'rare', name: 'Rare Buddy'),
        );
        await repository.addBuddyToDive('d1', frequent.id, DiveRole.buddyId);
        await repository.addBuddyToDive('d2', frequent.id, DiveRole.buddyId);
        await repository.addBuddyToDive('d1', rare.id, DiveRole.buddyId);

        final results = await repository.getAllBuddiesWithDiveCount();
        final byId = {for (final r in results) r.buddy.id: r.diveCount};

        expect(byId['frequent'], equals(2));
        expect(byId['rare'], equals(1));
      });

      test('carries the isFavorite flag through', () async {
        await repository.createBuddy(
          createTestBuddy(id: 'fav', name: 'Favorite Buddy'),
        );
        await repository.toggleFavorite('fav');

        final results = await repository.getAllBuddiesWithDiveCount();
        final fav = results.firstWhere((r) => r.buddy.id == 'fav');

        expect(fav.buddy.isFavorite, isTrue);
      });

      test('query filters by name, matching the picker search box', () async {
        await repository.createBuddy(
          createTestBuddy(id: 'alice', name: 'Alice'),
        );
        await repository.createBuddy(createTestBuddy(id: 'bob', name: 'Bob'));

        final results = await repository.getAllBuddiesWithDiveCount(
          query: 'ali',
        );

        expect(results.map((r) => r.buddy.id), equals(['alice']));
      });
    });

    group('favorites (issue #638)', () {
      test('toggleFavorite flips false to true and back', () async {
        final buddy = await repository.createBuddy(
          createTestBuddy(name: 'Toggle Buddy'),
        );
        expect(buddy.isFavorite, isFalse);

        await repository.toggleFavorite(buddy.id);
        expect((await repository.getBuddyById(buddy.id))!.isFavorite, isTrue);

        await repository.toggleFavorite(buddy.id);
        expect((await repository.getBuddyById(buddy.id))!.isFavorite, isFalse);
      });

      test('setFavorite sets the flag explicitly', () async {
        final buddy = await repository.createBuddy(
          createTestBuddy(name: 'Set Favorite Buddy'),
        );

        await repository.setFavorite(buddy.id, true);
        expect((await repository.getBuddyById(buddy.id))!.isFavorite, isTrue);

        await repository.setFavorite(buddy.id, false);
        expect((await repository.getBuddyById(buddy.id))!.isFavorite, isFalse);
      });

      test(
        'setFavorite on an unknown id leaves no pending sync record',
        () async {
          await repository.setFavorite('does-not-exist', true);

          final pending = await db.select(db.syncRecords).get();
          expect(pending, isEmpty);
        },
      );

      test(
        'toggleFavorite on an unknown id leaves no pending sync record',
        () async {
          await repository.toggleFavorite('does-not-exist');

          final pending = await db.select(db.syncRecords).get();
          expect(pending, isEmpty);
        },
      );
    });

    group('getBuddyStats', () {
      test('should return stats with zero dives for new buddy', () async {
        final buddy = await repository.createBuddy(
          createTestBuddy(name: 'Stats Buddy'),
        );

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
        final buddy = await repository.createBuddy(
          createTestBuddy(name: 'Dive Partner'),
        );
        buddyId = buddy.id;
      });

      test(
        'getBuddiesForDive should return empty list when no buddies assigned',
        () async {
          final buddies = await repository.getBuddiesForDive('some-dive-id');

          expect(buddies, isEmpty);
        },
      );

      test(
        'getDiveIdsForBuddy should return empty list when buddy has no dives',
        () async {
          final diveIds = await repository.getDiveIdsForBuddy(buddyId);

          expect(diveIds, isEmpty);
        },
      );
    });

    group('getBuddiesForDives (batch, #626)', () {
      Future<void> insertDive(String id) async {
        final db = DatabaseService.instance.database;
        await db.customStatement(
          "INSERT INTO dives (id, dive_date_time, created_at, updated_at) "
          "VALUES ('$id', 1000, 1000, 1000)",
        );
      }

      test('returns an empty map for empty input', () async {
        expect(await repository.getBuddiesForDives([]), isEmpty);
      });

      test('groups buddies by dive id and resolves roles', () async {
        await insertDive('d1');
        await insertDive('d2');
        final alice = await repository.createBuddy(
          createTestBuddy(id: 'b1', name: 'Alice'),
        );
        final guido = await repository.createBuddy(
          createTestBuddy(id: 'b2', name: 'Guido'),
        );
        await repository.addBuddyToDive('d1', alice.id, DiveRole.buddyId);
        await repository.addBuddyToDive('d1', guido.id, DiveRole.diveMasterId);
        await repository.addBuddyToDive('d2', alice.id, DiveRole.buddyId);

        final result = await repository.getBuddiesForDives(['d1', 'd2']);

        expect(result['d1'], hasLength(2));
        expect(result['d2'], hasLength(1));
        expect(
          result['d1']!.map((b) => b.buddy.name),
          containsAll(['Alice', 'Guido']),
        );
        final guidoLink = result['d1']!.firstWhere(
          (b) => b.buddy.name == 'Guido',
        );
        expect(guidoLink.role.id, DiveRole.diveMasterId);
        expect(result['d2']!.single.buddy.name, 'Alice');
      });

      test('omits dives that have no buddies', () async {
        await insertDive('d1');
        final result = await repository.getBuddiesForDives(['d1']);
        expect(result.containsKey('d1'), isFalse);
      });
    });

    group('dive role resolution', () {
      Future<void> insertDive(String id) async {
        final db = DatabaseService.instance.database;
        await db.customStatement(
          "INSERT INTO dives (id, dive_date_time, created_at, updated_at) "
          "VALUES ('$id', 1000, 1000, 1000)",
        );
      }

      Future<String> insertDiver() async {
        final db = DatabaseService.instance.database;
        await db.customStatement(
          "INSERT INTO divers (id, name, created_at, updated_at) "
          "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
        );
        return 'diver-1';
      }

      test('getBuddiesForDive resolves built-in role ids to DiveRole '
          'entities', () async {
        await insertDive('d1');
        final buddy = await repository.createBuddy(createTestBuddy(id: 'b1'));
        await repository.addBuddyToDive('d1', buddy.id, DiveRole.diveGuideId);

        final result = await repository.getBuddiesForDive('d1');
        expect(result.single.role.id, DiveRole.diveGuideId);
        expect(result.single.role.isBuiltIn, isTrue);
        expect(result.single.role.name, 'Dive Guide');
      });

      test('getBuddiesForDive resolves custom roles and keeps unknown slugs '
          'as synthetic roles', () async {
        await insertDive('d1');
        final diverId = await insertDiver();
        final buddy = await repository.createBuddy(createTestBuddy(id: 'b1'));
        final roleRepo = DiveRoleRepository();
        final custom = await roleRepo.createDiveRole(
          name: 'Hekkensluiter',
          diverId: diverId,
        );
        await repository.addBuddyToDive('d1', buddy.id, custom.id);

        var result = await repository.getBuddiesForDive('d1');
        expect(result.single.role.name, 'Hekkensluiter');
        expect(result.single.role.isBuiltIn, isFalse);

        // Unknown slug: written directly, must surface as synthetic, not
        // silently coerce to Buddy.
        final db = DatabaseService.instance.database;
        await db.customStatement(
          "UPDATE dive_buddies SET role = 'mysterySlug' WHERE dive_id = 'd1'",
        );
        result = await repository.getBuddiesForDive('d1');
        expect(result.single.role.id, 'mysterySlug');
        expect(result.single.role.name, 'mysterySlug');
      });

      test(
        'setBuddiesForDive persists the role id, not the display name',
        () async {
          await insertDive('d1');
          final buddy = await repository.createBuddy(createTestBuddy(id: 'b1'));

          await repository.setBuddiesForDive('d1', [
            BuddyWithRole(buddy: buddy, role: DiveRole.builtInBuddy()),
          ]);

          final db = DatabaseService.instance.database;
          final row = await db
              .customSelect(
                "SELECT role FROM dive_buddies WHERE dive_id = 'd1'",
              )
              .getSingle();
          expect(row.read<String>('role'), 'buddy'); // id, NOT 'Buddy'
        },
      );
    });
    // Issue #982: the shared-dives preview showed an arbitrary five dives
    // because the ids came back in `dive_buddies.created_at` order (when the
    // link was written) and the caller truncated before sorting by dive date.
    group('getDiveIdsForBuddy ordering (#982)', () {
      Future<void> insertDive(
        String id, {
        required int diveDateTime,
        int? entryTime,
        int? diveNumber,
      }) async {
        final db = DatabaseService.instance.database;
        await db.customStatement(
          'INSERT INTO dives '
          '(id, dive_date_time, entry_time, dive_number, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, 1000, 1000)',
          [id, diveDateTime, entryTime, diveNumber],
        );
      }

      /// Forces the junction row's link timestamp so link order can be made to
      /// contradict dive order.
      Future<void> setLinkCreatedAt(
        String buddyId,
        String diveId,
        int createdAt,
      ) async {
        final db = DatabaseService.instance.database;
        await db.customStatement(
          'UPDATE dive_buddies SET created_at = ? '
          'WHERE dive_id = ? AND buddy_id = ?',
          [createdAt, diveId, buddyId],
        );
      }

      test(
        'returns newest dive first regardless of link creation order',
        () async {
          final buddy = await repository.createBuddy(createTestBuddy(id: 'b1'));
          await insertDive('old', diveDateTime: 1000);
          await insertDive('newest', diveDateTime: 3000);
          await insertDive('middle', diveDateTime: 2000);
          for (final id in ['old', 'newest', 'middle']) {
            await repository.addBuddyToDive(id, buddy.id, DiveRole.buddyId);
          }
          // Link order deliberately inverted relative to dive date order.
          await setLinkCreatedAt(buddy.id, 'old', 9000);
          await setLinkCreatedAt(buddy.id, 'newest', 8000);
          await setLinkCreatedAt(buddy.id, 'middle', 7000);

          final diveIds = await repository.getDiveIdsForBuddy(buddy.id);

          expect(diveIds, equals(['newest', 'middle', 'old']));
        },
      );

      test('prefers entry time over dive date time', () async {
        final buddy = await repository.createBuddy(createTestBuddy(id: 'b1'));
        // `later` has the older dive_date_time but the newer entry_time.
        await insertDive('earlier', diveDateTime: 5000);
        await insertDive('later', diveDateTime: 4000, entryTime: 6000);
        for (final id in ['earlier', 'later']) {
          await repository.addBuddyToDive(id, buddy.id, DiveRole.buddyId);
        }
        // Link order deliberately inverted relative to entry time order.
        await setLinkCreatedAt(buddy.id, 'earlier', 9000);
        await setLinkCreatedAt(buddy.id, 'later', 1);

        final diveIds = await repository.getDiveIdsForBuddy(buddy.id);

        expect(diveIds, equals(['later', 'earlier']));
      });

      test(
        'breaks ties on the same timestamp by dive number descending',
        () async {
          final buddy = await repository.createBuddy(createTestBuddy(id: 'b1'));
          await insertDive('lower', diveDateTime: 1000, diveNumber: 893);
          await insertDive('higher', diveDateTime: 1000, diveNumber: 894);
          for (final id in ['lower', 'higher']) {
            await repository.addBuddyToDive(id, buddy.id, DiveRole.buddyId);
          }
          await setLinkCreatedAt(buddy.id, 'lower', 9000);
          await setLinkCreatedAt(buddy.id, 'higher', 1);

          final diveIds = await repository.getDiveIdsForBuddy(buddy.id);

          expect(diveIds, equals(['higher', 'lower']));
        },
      );

      test('sorts a null dive number last, as SQLite DESC does', () async {
        final buddy = await repository.createBuddy(createTestBuddy(id: 'b1'));
        // Ids are chosen so the id tiebreak would give the OPPOSITE order:
        // only the dive-number rule can produce the expectation below.
        await insertDive('aaa-no-number', diveDateTime: 1000);
        await insertDive('zzz-has-number', diveDateTime: 1000, diveNumber: 3);
        for (final id in ['aaa-no-number', 'zzz-has-number']) {
          await repository.addBuddyToDive(id, buddy.id, DiveRole.buddyId);
        }

        final diveIds = await repository.getDiveIdsForBuddy(buddy.id);

        expect(diveIds, equals(['zzz-has-number', 'aaa-no-number']));
      });

      test(
        'is deterministic when timestamp and dive number both tie',
        () async {
          final buddy = await repository.createBuddy(createTestBuddy(id: 'b1'));
          // Same instant, no dive number: only the id can separate these. They
          // are inserted in reverse id order so a query with no id tiebreak
          // returns them in insertion order instead.
          await insertDive('zzz', diveDateTime: 1000);
          await insertDive('aaa', diveDateTime: 1000);
          for (final id in ['zzz', 'aaa']) {
            await repository.addBuddyToDive(id, buddy.id, DiveRole.buddyId);
          }

          final diveIds = await repository.getDiveIdsForBuddy(buddy.id);

          expect(
            diveIds,
            equals(['aaa', 'zzz']),
            reason:
                'the caller truncates this list, so an unstable tail would '
                'change which dives the preview shows, not just their order',
          );
        },
      );
    });
  });
}
