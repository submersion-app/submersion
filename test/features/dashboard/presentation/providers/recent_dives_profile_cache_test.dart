import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Serves the recent dives from the real database and counts profile
/// batch reads.
///
/// [DiveRepository]'s only public constructor is a factory, so this delegates
/// rather than extends, forwarding the methods the provider calls.
class _CountingRepository implements DiveRepository {
  _CountingRepository(this._inner);

  final DiveRepository _inner;
  int profileBatches = 0;

  @override
  Stream<void> watchDivesChangesWithBuddyLinks() =>
      _inner.watchDivesChangesWithBuddyLinks();

  @override
  Future<List<DiveSummary>> getDiveSummaries({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    DiveSummaryCursor? cursor,
    int? offset,
    int limit = 50,
    SortState<DiveSortField>? sort,
    Set<String> disabledSafetyRules = const {},
  }) => _inner.getDiveSummaries(diverId: diverId, limit: limit);

  @override
  Future<List<Dive>> getDivesByIdsWithoutSamples(
    List<String> ids, {
    bool offUiIsolate = false,
    int chunkSize = kSeriesIdChunkSize,
  }) => _inner.getDivesByIdsWithoutSamples(ids, offUiIsolate: offUiIsolate);

  @override
  Future<Map<String, List<DiveProfilePoint>>> getBatchProfileSummaries(
    List<String> diveIds, {
    int maxSamples = 120,
  }) async {
    profileBatches++;
    return const {};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
  });

  tearDown(tearDownTestDatabase);

  // Home's recent dives are a table with no mini charts (issue #4824), so
  // loading them must not decode any profile; the dive list loads its own.
  test('recent dives read no profiles', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final repo = _CountingRepository(DiveRepository());
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        diveRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    final recent = await container.read(recentDivesProvider.future);

    expect(recent.map((d) => d.id), ['d1']);
    expect(repo.profileBatches, 0);
  });
}
