import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/test_database.dart';
import '../../query/dive_query_fixture.dart';

/// The repository compiles the filter once per call (#2365) and derives
/// its `readsFrom` and change tick from the tables that query touched.
void main() {
  late AppDatabase db;
  late DiveRepository repo;
  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
    repo = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  final noWeights = DiveFilterState(
    query: ConditionNode(FieldPath(['weights']), QueryOp.isEmpty, null),
  );

  test(
    'the list, the count, the ordered ids and the id set agree on a query axis',
    () async {
      final list = (await repo.getDiveSummaries(
        diverId: 'me',
        filter: noWeights,
      )).map((s) => s.id).toSet();
      final count = await repo.getDiveCount(diverId: 'me', filter: noWeights);
      final ordered = (await repo.getOrderedDiveIds(
        diverId: 'me',
        filter: noWeights,
      )).toSet();
      final ids = await repo.getDiveIdsMatching(noWeights, diverId: 'me');
      // d2 carries only the legacy weight scalar, which counts as an entry.
      expect(list, {'d3', 'd4'});
      expect(count, 2);
      expect(ordered, list);
      expect(ids, list);
    },
  );

  test('the old axes still narrow the list', () async {
    const f = DiveFilterState(noBuddyOnly: true, minDepth: 20);
    expect(
      (await repo.getDiveSummaries(
        diverId: 'me',
        filter: f,
      )).map((s) => s.id).toSet(),
      {'d3'},
    );
  });

  test('watchTables emits on a write to a named table only', () async {
    final events = <void>[];
    final sub = repo.watchTables({'dive_weights'}).listen(events.add);
    await db
        .into(db.diveWeights)
        .insert(
          DiveWeightsCompanion.insert(
            id: 'w9',
            diveId: 'd3',
            weightType: 'belt',
            amountKg: 1,
            createdAt: 0,
          ),
        );
    await Future<void>.delayed(DiveRepository.changeTickDebounce * 2);
    expect(events, hasLength(1));
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(id: 'tg', name: 'x', createdAt: 0, updatedAt: 0),
        );
    await Future<void>.delayed(DiveRepository.changeTickDebounce * 2);
    expect(events, hasLength(1));
    await sub.cancel();
  });

  test('watchTables rejects an unknown table', () {
    expect(() => repo.watchTables({'nope'}), throwsArgumentError);
  });

  test('the list tick tables are named once and all resolve', () {
    expect(
      repo.tablesNamed(DiveRepository.diveListTickTables).length,
      DiveRepository.diveListTickTables.length,
    );
    expect(DiveRepository.diveListTickTables, contains('dives'));
    expect(DiveRepository.diveListTickTables, contains('dive_tags'));
  });
}
