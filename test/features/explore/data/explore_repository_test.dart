import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
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
}
