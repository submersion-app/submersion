import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3895: Top Buddies counts dives, so a buddy linked to one dive under
/// two roles has one dive, not two.
void main() {
  late AppDatabase db;
  late InsightsRepository repository;

  Future<void> insertDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: 1,
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  Future<void> insertBuddy(String id, String name) => db
      .into(db.buddies)
      .insert(
        BuddiesCompanion.insert(id: id, name: name, createdAt: 1, updatedAt: 1),
      );

  Future<void> link(String id, String diveId, String buddyId, String role) => db
      .into(db.diveBuddies)
      .insert(
        DiveBuddiesCompanion.insert(
          id: id,
          diveId: diveId,
          buddyId: buddyId,
          role: Value(role),
          createdAt: 1,
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
    await insertBuddy('sam', 'Sam');
    await insertBuddy('ken', 'Ken');
  });
  tearDown(tearDownTestDatabase);

  test('one buddy linked twice to a dive has one dive', () async {
    await insertDive('d1');
    await link('link1', 'd1', 'sam', 'buddy');
    await link('link2', 'd1', 'sam', 'instructor');

    final ranking = await repository.getTopBuddies();

    expect(ranking.map((r) => (r.id, r.count)), [('sam', 1)]);
  });

  test('a second link cannot lift a buddy over more shared dives', () async {
    for (final id in ['d1', 'd2', 'd3']) {
      await insertDive(id);
      await link('ken-$id', id, 'ken', 'buddy');
    }
    for (final id in ['d1', 'd2']) {
      await link('sam-$id-a', id, 'sam', 'buddy');
      await link('sam-$id-b', id, 'sam', 'instructor');
    }

    final ranking = await repository.getTopBuddies();

    expect(ranking.map((r) => (r.id, r.count)), [('ken', 3), ('sam', 2)]);
  });
}
