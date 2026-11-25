import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Answers the countries ranking with [count] rows, or throws, and keeps the
/// limit it was asked for.
class _CountriesRepository extends InsightsRepository {
  _CountriesRepository({this.count = 0, this.fail = false});

  final int count;
  final bool fail;
  int? askedLimit = -1;

  @override
  Future<List<RankingItem>> getCountriesVisited({
    String? diverId,
    int? limit = 10,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    askedLimit = limit;
    if (fail) throw StateError('query failed');
    return [
      for (var i = 0; i < count; i++)
        RankingItem(id: 'c$i', name: 'Country $i', count: 1),
    ];
  }
}

/// The welcome banner's countries stat (issue #5003).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<ProviderContainer> containerWith(InsightsRepository repo) async {
    final container = ProviderContainer(
      overrides: [
        ...await getBaseOverrides(),
        insightsRepositoryProvider.overrideWithValue(repo),
      ].cast(),
    );
    addTearDown(container.dispose);
    return container;
  }

  test('counts every country, past the ranking default of 10', () async {
    final repo = _CountriesRepository(count: 14);
    final container = await containerWith(repo);

    expect(await container.read(homeCountriesVisitedProvider.future), 14);
    expect(repo.askedLimit, isNull);
  });

  test('a failed query reads as no count, not an error', () async {
    final container = await containerWith(_CountriesRepository(fail: true));

    expect(await container.read(homeCountriesVisitedProvider.future), isNull);
  });
}
