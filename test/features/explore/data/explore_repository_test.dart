import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/explore/data/explore_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  Future<void> site(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: Value('Site $id'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<void> dive(
    String id,
    String? siteId, {
    bool excluded = false,
    double? depth,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
          siteId: Value(siteId),
          excludedFromStats: Value(excluded),
          maxDepth: Value(depth),
        ),
      );

  test('counts dives per site under the filter and the stats scope', () async {
    await site('a');
    await site('b');
    await dive('1', 'a', depth: 30);
    await dive('2', 'a', depth: 10);
    await dive('3', 'b', depth: 30);
    await dive('4', 'a', depth: 30, excluded: true);
    await dive('5', null, depth: 30);
    final rows = await ExploreRepository().diveCountBySite(
      const DiveFilterState(minDepth: 20),
    );
    expect(rows.map((r) => (r.siteId, r.name, r.count)), [
      ('a', 'Site a', 1),
      ('b', 'Site b', 1),
    ]);
  });

  test('legacy buddy texts are the diver\'s sentence-only buddies', () async {
    Future<void> legacy(String id, String? buddy, {String? diverId}) => db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
            diverId: Value(diverId),
            buddy: Value(buddy),
          ),
        );
    for (final id in ['me', 'other']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    await legacy('1', 'Bob', diverId: 'me');
    await legacy('2', 'Bob', diverId: 'me');
    await legacy('3', 'Al', diverId: 'me');
    await legacy('4', '', diverId: 'me');
    await legacy('5', null, diverId: 'me');
    await legacy('6', 'Zed', diverId: 'other');

    final mine = await ExploreRepository().legacyBuddyNames(diverId: 'me');
    expect(mine.map((e) => e.label), ['Al', 'Bob']);
    for (final e in mine) {
      expect(e.subject, QuerySubject.buddies);
      expect(e.target, NameTarget.legacyBuddyName);
      expect(e.ids, isEmpty);
      expect(e.rank, 1);
      expect(e.primary, isFalse);
    }
    final everyone = await ExploreRepository().legacyBuddyNames();
    expect(everyone.map((e) => e.label), ['Al', 'Bob', 'Zed']);
  });
}
