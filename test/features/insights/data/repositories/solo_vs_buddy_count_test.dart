import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

/// Regression coverage for issue #1822: a dive with several linked buddies
/// must count once in the Solo vs Buddy statistic, not once per buddy.
///
/// Issue #1998: a dive counts as solo only when the diver said so (their own
/// role on the dive is Solo). A dive with no buddy and no such role is not
/// recorded, rather than being read as solo.
void main() {
  late InsightsRepository repository;
  late AppDatabase db;
  final now = DateTime(2026, 1, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDiver(String id) async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value('Diver $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertDive(
    String id, {
    String? diverId,
    String? freeTextBuddy,
    String? diverRole,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            buddy: Value(freeTextBuddy),
            diverRole: Value(diverRole),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertBuddy(String id) async {
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion(
            id: Value(id),
            name: Value('Buddy $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> linkBuddy(String diveId, String buddyId) async {
    await db
        .into(db.diveBuddies)
        .insert(
          DiveBuddiesCompanion(
            id: Value('$diveId-$buddyId'),
            diveId: Value(diveId),
            buddyId: Value(buddyId),
            createdAt: Value(now),
          ),
        );
  }

  Future<void> insertBuddies(List<String> ids) async {
    for (final id in ids) {
      await insertBuddy(id);
    }
  }

  group('getSoloVsBuddyCount', () {
    test('counts a dive with three linked buddies once', () async {
      await insertBuddies(['b1', 'b2', 'b3']);
      await insertDive('solo', diverRole: 'solo');
      await insertDive('group');
      for (final buddyId in ['b1', 'b2', 'b3']) {
        await linkBuddy('group', buddyId);
      }

      final result = await repository.getSoloVsBuddyCount();

      expect(result.solo, 1);
      expect(result.buddy, 1);
    });

    test('counts a dive with only a free-text buddy as a buddy dive', () async {
      await insertDive('solo', diverRole: 'solo');
      await insertDive('text-only', freeTextBuddy: 'Alex');

      final result = await repository.getSoloVsBuddyCount();

      expect(result.solo, 1);
      expect(result.buddy, 1);
    });

    test('treats an empty free-text buddy as no buddy', () async {
      await insertDive('empty-text', freeTextBuddy: '');

      final result = await repository.getSoloVsBuddyCount();

      expect(result.solo, 0);
      expect(result.buddy, 0);
      expect(result.notRecorded, 1);
    });

    test('counts a dive with no buddy and no role as not recorded', () async {
      await insertDive('blank');

      final result = await repository.getSoloVsBuddyCount();

      expect(result.solo, 0);
      expect(result.buddy, 0);
      expect(result.notRecorded, 1);
    });

    test('counts a dive whose own role is Solo as solo', () async {
      await insertDive('solo', diverRole: 'solo');

      final result = await repository.getSoloVsBuddyCount();

      expect(result.solo, 1);
      expect(result.buddy, 0);
      expect(result.notRecorded, 0);
    });

    test('a role other than Solo without a buddy is not recorded', () async {
      await insertDive('guiding', diverRole: 'diveGuide');

      final result = await repository.getSoloVsBuddyCount();

      expect(result.solo, 0);
      expect(result.buddy, 0);
      expect(result.notRecorded, 1);
    });

    test('a recorded buddy wins over a Solo role', () async {
      await insertBuddies(['b1']);
      await insertDive('mixed', diverRole: 'solo');
      await linkBuddy('mixed', 'b1');

      final result = await repository.getSoloVsBuddyCount();

      expect(result.solo, 0);
      expect(result.buddy, 1);
      expect(result.notRecorded, 0);
    });

    test(
      'a placeholder free-text buddy does not outweigh the Solo role',
      () async {
        // Legacy imports wrote placeholders such as "None" into the buddy
        // text; the dive detail page reads those as no buddy, and so does
        // this.
        await insertDive('none', diverRole: 'solo', freeTextBuddy: 'None');
        await insertDive(
          'solo-word',
          diverRole: 'solo',
          freeTextBuddy: ' solo ',
        );

        final result = await repository.getSoloVsBuddyCount();

        expect(result.solo, 2);
        expect(result.buddy, 0);
        expect(result.notRecorded, 0);
      },
    );

    test('a whitespace or placeholder buddy alone is not recorded', () async {
      await insertDive('spaces', freeTextBuddy: '   ');
      await insertDive('n-a', freeTextBuddy: 'n/a');

      final result = await repository.getSoloVsBuddyCount();

      expect(result.solo, 0);
      expect(result.buddy, 0);
      expect(result.notRecorded, 2);
    });

    test('dives sharing one free-text buddy are each counted', () async {
      await insertDive('first', freeTextBuddy: 'Alex');
      await insertDive('second', freeTextBuddy: 'Alex');
      await insertDive('third', freeTextBuddy: 'Alex', diverRole: 'solo');

      final result = await repository.getSoloVsBuddyCount();

      expect(result.buddy, 3);
      expect(result.solo, 0);
      expect(result.notRecorded, 0);
    });

    test(
      'counts a dive with a free-text buddy and linked buddies once',
      () async {
        await insertBuddies(['b1', 'b2']);
        await insertDive('both', freeTextBuddy: 'Alex');
        await linkBuddy('both', 'b1');
        await linkBuddy('both', 'b2');

        final result = await repository.getSoloVsBuddyCount();

        expect(result.solo, 0);
        expect(result.buddy, 1);
      },
    );

    test('scopes the count to the requested diver', () async {
      await insertDiver('me');
      await insertDiver('other');
      await insertBuddies(['b1', 'b2']);
      await insertDive('my-solo', diverId: 'me', diverRole: 'solo');
      await insertDive('my-group', diverId: 'me');
      await linkBuddy('my-group', 'b1');
      await linkBuddy('my-group', 'b2');
      await insertDive('their-group', diverId: 'other');
      await linkBuddy('their-group', 'b1');

      final result = await repository.getSoloVsBuddyCount(diverId: 'me');

      expect(result.solo, 1);
      expect(result.buddy, 1);
    });

    test('respects a tag filter', () async {
      await insertBuddies(['b1', 'b2']);
      await insertDive('tagged-group');
      await linkBuddy('tagged-group', 'b1');
      await linkBuddy('tagged-group', 'b2');
      await insertDive('untagged-solo', diverRole: 'solo');
      await insertDive('untagged-group');
      await linkBuddy('untagged-group', 'b1');
      await db
          .into(db.tags)
          .insert(
            TagsCompanion(
              id: const Value('dry'),
              name: const Value('dry'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await db
          .into(db.diveTags)
          .insert(
            DiveTagsCompanion(
              id: const Value('tagged-group-dry'),
              diveId: const Value('tagged-group'),
              tagId: const Value('dry'),
              createdAt: Value(now),
            ),
          );

      final result = await repository.getSoloVsBuddyCount(
        filter: const DiveFilterState(tagIds: ['dry']),
      );

      expect(result.solo, 0);
      expect(result.buddy, 1);
    });

    test('returns zeros when there are no dives', () async {
      final result = await repository.getSoloVsBuddyCount();

      expect(result.solo, 0);
      expect(result.buddy, 0);
      expect(result.notRecorded, 0);
    });
  });
}
