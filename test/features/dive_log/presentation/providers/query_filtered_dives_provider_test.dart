import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../query/dive_query_fixture.dart';

/// The entity-backed views narrow the hydrated list by the compiled query's
/// id set, and refresh when a table the query read is written (#2365).
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
    container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier()..state = 'me',
        ),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  /// Polls the provider until it holds [expected] (an AsyncValue keeps its
  /// previous data while a refresh is in flight, so the first loaded value
  /// after a write may still be the old one), returning the last value
  /// either way.
  Future<Set<String>> filteredIds(Set<String> expected) async {
    Set<String>? last;
    for (var i = 0; i < 80; i++) {
      final v = container.read(filteredDivesProvider);
      if (v.hasValue) {
        last = v.value!.map((d) => d.id).toSet();
        if (last.length == expected.length && last.containsAll(expected)) {
          return last;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    return last ?? fail('filteredDivesProvider never loaded');
  }

  test('no filter: every dive, no id query', () async {
    expect(
      await filteredIds(QueryFixtureIds.mine.toSet()),
      QueryFixtureIds.mine.toSet(),
    );
    expect(
      container
          .read(
            queryFilteredDiveIdsProvider(container.read(diveFilterProvider)),
          )
          .value,
      isNull,
    );
  });

  test('a typed query narrows the list', () async {
    container.read(diveFilterProvider.notifier).state = DiveFilterState(
      query: ConditionNode(const FieldPath(['weights']), QueryOp.isEmpty, null),
    );
    expect(await filteredIds({'d2', 'd3', 'd4'}), {'d2', 'd3', 'd4'});
  });

  test('a write to a touched table refreshes the id set', () async {
    container.read(diveFilterProvider.notifier).state = DiveFilterState(
      query: ConditionNode(const FieldPath(['weights']), QueryOp.isEmpty, null),
    );
    expect(await filteredIds({'d2', 'd3', 'd4'}), {'d2', 'd3', 'd4'});
    await db
        .into(db.diveWeights)
        .insert(
          DiveWeightsCompanion.insert(
            id: 'w3',
            diveId: 'd3',
            weightType: 'belt',
            amountKg: 2,
            createdAt: 0,
          ),
        );
    await Future<void>.delayed(DiveRepository.changeTickDebounce * 3);
    expect(await filteredIds({'d2', 'd4'}), {'d2', 'd4'});
  });
}
