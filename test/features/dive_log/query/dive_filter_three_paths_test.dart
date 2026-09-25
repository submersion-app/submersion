import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

import '../../../helpers/test_database.dart';
import 'dive_query_fixture.dart';

/// Statistics, the paginated list and the id query select the same dives
/// for every kind of axis, because all three compile the same tree.
void main() {
  late AppDatabase db;
  late DiveRepository repo;
  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
    repo = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> statistics(DiveFilterState f) async {
    final s = buildFilteredDiveIdSubquery(f);
    final sql = s.subquery.isEmpty
        ? 'SELECT id FROM dives WHERE diver_id = ?'
        : 'SELECT id FROM dives WHERE diver_id = ? AND id IN (${s.subquery})';
    final rows = await db
        .customSelect(
          sql,
          variables: [
            const Variable<String>('me'),
            ...s.params.map((p) => Variable(p)),
          ],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  final cases = <String, DiveFilterState>{
    'empty': const DiveFilterState(),
    'legacy axes': DiveFilterState(
      startDate: DateTime(2025, 1, 1),
      noBuddyOnly: true,
      minDepth: 10,
    ),
    'deco (SQL-only before)': const DiveFilterState(decoOnly: false),
    'typed presence': DiveFilterState(
      query: ConditionNode(const FieldPath(['weights']), QueryOp.isEmpty, null),
    ),
    'typed three hops': DiveFilterState(
      query: ConditionNode(
        const FieldPath(['buddies', 'certifications', 'level']),
        QueryOp.eq,
        const StringValue('rescue'),
      ),
    ),
    'typed text': const DiveFilterState(query: TextNode(['manta'])),
  };

  for (final e in cases.entries) {
    test('three paths agree: ${e.key}', () async {
      final list = (await repo.getDiveSummaries(
        diverId: 'me',
        filter: e.value,
      )).map((s) => s.id).toSet();
      final count = await repo.getDiveCount(diverId: 'me', filter: e.value);
      final ids = await repo.getDiveIdsMatching(e.value, diverId: 'me');
      final stats = await statistics(e.value);
      expect(count, list.length, reason: e.key);
      expect(ids, list, reason: e.key);
      expect(stats, list, reason: e.key);
    });
  }
}
