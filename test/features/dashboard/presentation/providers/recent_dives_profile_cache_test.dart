import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

const _point = [DiveProfilePoint(timestamp: 0, depth: 10)];

/// Serves the recent dives from the real database and holds the profile
/// batch open until [release] completes.
///
/// [DiveRepository]'s only public constructor is a factory, so this delegates
/// rather than extends, forwarding the methods the provider calls.
class _GatedProfileRepository implements DiveRepository {
  _GatedProfileRepository(this._inner);

  final DiveRepository _inner;
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();

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
  Future<Dive?> getDiveById(String id) => _inner.getDiveById(id);

  @override
  Future<Map<String, List<DiveProfilePoint>>> getBatchProfileSummaries(
    List<String> diveIds, {
    int maxSamples = 120,
  }) async {
    started.complete();
    await release.future;
    return {for (final id in diveIds) id: _point};
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

  test('recent dives keep the dive list\'s profiles that land while their '
      'own batch runs (#3506)', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final repo = _GatedProfileRepository(DiveRepository());
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        diveRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    final recent = container.read(recentDivesProvider.future);
    await repo.started.future;
    // A dive list page's profiles land while the dashboard's batch runs.
    container.read(batchProfileCacheProvider.notifier).state = {
      ...container.read(batchProfileCacheProvider),
      'listed-dive': _point,
    };
    repo.release.complete();
    await recent;

    expect(
      container.read(batchProfileCacheProvider).keys.toSet(),
      {'d1', 'listed-dive'},
      reason:
          'the dashboard must merge into the cache as it is now, not write '
          'back the snapshot it read before awaiting',
    );
  });
}
