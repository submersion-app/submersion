import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3624: a buddy excluded from the rankings leaves the top buddies
/// list, and the dives with that buddy still count as buddy dives.
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

  /// A buddy on [dives] dives of their own.
  Future<void> buddyWithDives(
    String id, {
    required int dives,
    bool excluded = false,
  }) async {
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion(
            id: Value(id),
            name: Value(id),
            excludedFromRankings: Value(excluded),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (var i = 0; i < dives; i++) {
      final diveId = '$id-$i';
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: Value(diveId),
              diveDateTime: Value(now),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await db
          .into(db.diveBuddies)
          .insert(
            DiveBuddiesCompanion(
              id: Value('$diveId-link'),
              diveId: Value(diveId),
              buddyId: Value(id),
              createdAt: Value(now),
            ),
          );
    }
  }

  test('an excluded buddy is left out, however many dives they have', () async {
    await buddyWithDives('unknown', dives: 5, excluded: true);
    await buddyWithDives('anna', dives: 2);

    final top = await repository.getTopBuddies();

    expect(top.map((b) => b.id), ['anna']);
    expect(top.single.count, 2);
  });

  test(
    'the limit is filled by ranked buddies, not spent on excluded ones',
    () async {
      await buddyWithDives('unknown', dives: 5, excluded: true);
      await buddyWithDives('anna', dives: 3);
      await buddyWithDives('marco', dives: 2);
      await buddyWithDives('sam', dives: 1);

      final top = await repository.getTopBuddies(limit: 2);

      expect(top.map((b) => b.id), ['anna', 'marco']);
    },
  );

  test('a diver whose only buddy is excluded has no top buddy', () async {
    await buddyWithDives('unknown', dives: 5, excluded: true);

    expect(await repository.getTopBuddies(), isEmpty);
  });

  test('dives with an excluded buddy still count as buddy dives', () async {
    await buddyWithDives('unknown', dives: 3, excluded: true);

    final counts = await repository.getSoloVsBuddyCount();

    expect(counts.buddy, 3);
    expect(counts.solo, 0);
    expect(counts.notRecorded, 0);
  });
}
