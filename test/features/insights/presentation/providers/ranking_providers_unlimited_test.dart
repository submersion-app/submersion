import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Answers every ranking with nothing and keeps the limit each was asked
/// for, keyed by query.
class _LimitRecordingRepository extends InsightsRepository {
  final limits = <String, int?>{};

  Future<List<RankingItem>> _record(String query, int? limit) async {
    limits[query] = limit;
    return const [];
  }

  @override
  Future<List<RankingItem>> getTopBuddies({
    String? diverId,
    int? limit = 10,
    DiveFilterState filter = const DiveFilterState(),
  }) => _record('buddies', limit);

  @override
  Future<List<RankingItem>> getTopDiveCenters({
    String? diverId,
    int? limit = 10,
    DiveFilterState filter = const DiveFilterState(),
  }) => _record('centers', limit);

  @override
  Future<List<RankingItem>> getCountriesVisited({
    String? diverId,
    int? limit = 10,
    DiveFilterState filter = const DiveFilterState(),
  }) => _record('countries', limit);

  @override
  Future<List<RankingItem>> getRegionsExplored({
    String? diverId,
    int? limit = 10,
    DiveFilterState filter = const DiveFilterState(),
  }) => _record('regions', limit);

  @override
  Future<List<RankingItem>> getDivesPerTrip({
    String? diverId,
    int? limit = 10,
    DiveFilterState filter = const DiveFilterState(),
  }) => _record('trips', limit);

  @override
  Future<List<RankingItem>> getMostCommonSightings({
    String? diverId,
    int? limit = 10,
    DiveFilterState filter = const DiveFilterState(),
  }) => _record('sightings', limit);

  @override
  Future<List<RankingItem>> getBestSitesForMarineLife({
    String? diverId,
    int? limit = 10,
    DiveFilterState filter = const DiveFilterState(),
  }) => _record('sites', limit);
}

/// Issue #4385: the ranking cards show ten rows and open the rest behind
/// "Show all", so their providers ask the repository for every row.
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  test('every ranking card provider loads the whole ranking', () async {
    final repository = _LimitRecordingRepository();
    final container = ProviderContainer(
      overrides: [
        ...await getBaseOverrides(),
        insightsRepositoryProvider.overrideWithValue(repository),
      ].cast(),
    );
    addTearDown(container.dispose);

    await container.read(topBuddiesProvider.future);
    await container.read(topDiveCentersProvider.future);
    await container.read(countriesVisitedProvider.future);
    await container.read(regionsExploredProvider.future);
    await container.read(divesPerTripProvider.future);
    await container.read(mostCommonSightingsProvider.future);
    await container.read(bestSitesForMarineLifeProvider.future);

    expect(repository.limits, {
      'buddies': null,
      'centers': null,
      'countries': null,
      'regions': null,
      'trips': null,
      'sightings': null,
      'sites': null,
    });
  });
}
