import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #1930: the insights queries rethrow a failure rather than answer
/// with an empty result. The quick stats combine three unrelated metrics,
/// and the hero header shows each on its own, so one failed metric must not
/// take the others down with it. A failed metric is unknown (null), not 0.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<DashboardQuickStats> read(_Metric failing) {
    final c = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        insightsRepositoryProvider.overrideWithValue(
          _FakeInsightsRepository(failing),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c.read(dashboardQuickStatsProvider.future);
  }

  test('a failed buddy query keeps the countries and species', () async {
    final stats = await read(_Metric.buddies);
    expect(stats.topBuddyName, isNull);
    expect(stats.topBuddyDiveCount, isNull);
    expect(stats.countriesVisited, 2);
    expect(stats.speciesDiscovered, 7);
  });

  test('a failed countries query is unknown, not 0', () async {
    final stats = await read(_Metric.countries);
    expect(stats.topBuddyName, 'Ana');
    expect(stats.countriesVisited, isNull);
    expect(stats.speciesDiscovered, 7);
  });

  test('a failed species query is unknown, not 0', () async {
    final stats = await read(_Metric.species);
    expect(stats.topBuddyName, 'Ana');
    expect(stats.countriesVisited, 2);
    expect(stats.speciesDiscovered, isNull);
  });
}

enum _Metric { buddies, countries, species }

class _FakeInsightsRepository extends InsightsRepository {
  _FakeInsightsRepository(this.failing);

  final _Metric failing;

  Never _fail() => throw StateError('query failed: ${failing.name}');

  RankingItem _item(String id) => RankingItem(id: id, name: id, count: 3);

  @override
  Future<List<RankingItem>> getTopBuddies({
    String? diverId,
    int limit = 10,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    if (failing == _Metric.buddies) _fail();
    return [_item('Ana')];
  }

  @override
  Future<List<RankingItem>> getCountriesVisited({
    String? diverId,
    int limit = 10,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    if (failing == _Metric.countries) _fail();
    return [_item('Mexico'), _item('Egypt')];
  }

  @override
  Future<int> getUniqueSpeciesCount({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    if (failing == _Metric.species) _fail();
    return 7;
  }
}
