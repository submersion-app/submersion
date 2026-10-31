import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DiveProfileEventsCompanion;
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/entities/species_insights.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/presentation/providers/conditions_stats_providers.dart';
import 'package:submersion/features/insights/presentation/providers/equipment_condition_insights_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_focus_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/test_database.dart';

/// One of the ways Insights reads the filtered dives, and how many dives the
/// loaded value counts.
class _FilteredRead<T> {
  const _FilteredRead(this.provider, this.diveCount);

  final ProviderListenable<AsyncValue<T>> provider;
  final int Function(T) diveCount;

  ProviderSubscription<AsyncValue<T>> listen(ProviderContainer container) =>
      container.listen(provider, (_, _) {});

  /// Polls until the loaded value counts [expected] dives, or gives up. A
  /// refresh is debounced by 300 ms, so it is never immediate. Null while
  /// nothing has loaded.
  Future<int?> settle(ProviderContainer container, int expected) async {
    int? count() {
      final value = container.read(provider).value;
      return value == null ? null : diveCount(value);
    }

    for (var i = 0; i < 200; i++) {
      if (count() == expected) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return count();
  }
}

/// Counts the species query, without changing its result.
class _CountingInsightsRepository extends InsightsRepository {
  var speciesCalls = 0;

  @override
  Future<SpeciesInsights> getSpeciesInsights({
    required String speciesId,
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) {
    speciesCalls++;
    return super.getSpeciesInsights(
      speciesId: speciesId,
      diverId: diverId,
      filter: filter,
    );
  }
}

/// The Insights tick follows the tables the active filter reads (issue #3894).
///
/// A plain text search reaches `tags`, `dive_custom_fields` and `dive_types`,
/// so renaming a tag changes which dives match without touching a dive. The
/// Overview and records always followed the filter's tables; the charts took
/// a fixed list and kept showing the old result until their cache expired.
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;
  late TagRepository tags;
  late Tag reef;

  DiveFilterState searchFor(String word) =>
      DiveFilterState(query: TextNode([word]));

  final _FilteredRead<Object?> chart = _FilteredRead(
    depthProgressionTrendProvider,
    (points) => (points as List).length,
  );

  /// Every shape of provider that reads the filter: the shared chart helper,
  /// the two focus providers and the conditions rows that subscribe on their
  /// own, and the dive id set the equipment rankings narrow to.
  final reads = <String, _FilteredRead<Object?>>{
    'a chart through the shared cache helper': chart,
    'the conditions rows': _FilteredRead(
      conditionsRowsProvider,
      (rows) => (rows as List).length,
    ),
    'a focus metric series': _FilteredRead(
      focusMetricSeriesProvider(FocusMetric.avgDepth),
      (points) => (points as List).length,
    ),
    'the focus factor rows': _FilteredRead(
      focusFactorRowsProvider,
      (rows) => (rows as List).length,
    ),
    'the filtered dive ids': _FilteredRead(
      insightsFilteredDiveIdsProvider,
      (ids) => (ids as Set).length,
    ),
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    final diver = await DiverRepository().createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    await prefs.setString(currentDiverIdKey, diver.id);
    for (final (index, id) in const ['tagged', 'untagged'].indexed) {
      await DiveRepository().createDive(
        Dive(
          id: id,
          diverId: diver.id,
          dateTime: DateTime(2026, 1, index + 1),
          maxDepth: 20,
          avgDepth: 12,
        ),
      );
    }
    tags = TagRepository();
    reef = await tags.createTag(
      Tag.create(id: '', name: 'reef', diverId: diver.id),
    );
    await tags.addTagToDive('tagged', reef.id);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer(
    DiveFilterState filter, {
    InsightsRepository? repository,
  }) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        insightsFilterProvider.overrideWith((ref) => filter),
        if (repository != null)
          insightsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  for (final MapEntry(key: name, value: read) in reads.entries) {
    test('$name stops counting a dive when its tag is renamed', () async {
      final container = makeContainer(searchFor('reef'));
      final onScreen = read.listen(container);
      addTearDown(onScreen.close);
      expect(await read.settle(container, 1), 1);

      await tags.updateTag(reef.copyWith(name: 'wreck'));

      expect(
        await read.settle(container, 0),
        0,
        reason: 'renaming the tag writes `tags` and no dive row',
      );
    });
  }

  test('a dive a rename brings into the filter joins the chart', () async {
    final container = makeContainer(searchFor('wreck'));
    final onScreen = chart.listen(container);
    addTearDown(onScreen.close);
    expect(await chart.settle(container, 0), 0);

    await tags.updateTag(reef.copyWith(name: 'wreck'));

    expect(await chart.settle(container, 1), 1);
  });

  test(
    'a chart cached after its page closed is fresh when the page returns',
    () async {
      final container = makeContainer(searchFor('reef'));
      final firstVisit = chart.listen(container);
      expect(await chart.settle(container, 1), 1);
      firstVisit.close();

      await tags.updateTag(reef.copyWith(name: 'wreck'));
      // Past the 300 ms debounce, with the provider held only by its
      // five-minute keepAlive.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      final secondVisit = chart.listen(container);
      addTearDown(secondVisit.close);
      expect(await chart.settle(container, 0), 0);
    },
  );

  test('a chart follows the tables of a filter set after it loaded', () async {
    final container = makeContainer(const DiveFilterState());
    final onScreen = chart.listen(container);
    addTearDown(onScreen.close);
    expect(await chart.settle(container, 2), 2);

    container.read(insightsFilterProvider.notifier).state = searchFor('reef');
    // The filtered load has to land first: a rename racing the rebuild would
    // be read by that query, and pass with no tick at all.
    expect(await chart.settle(container, 1), 1);

    await tags.updateTag(reef.copyWith(name: 'wreck'));

    expect(await chart.settle(container, 0), 0);
  });

  test('a deco stop event alone reaches the deco statistic', () async {
    final _FilteredRead<Object?> deco = _FilteredRead(
      decoObligationStatsProvider,
      (stats) => (stats as ({int decoCount, int noDecoCount, int unknownCount}))
          .decoCount,
    );
    final container = makeContainer(const DiveFilterState());
    final onScreen = deco.listen(container);
    addTearDown(onScreen.close);
    expect(await deco.settle(container, 0), 0);

    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion.insert(
            id: 'stop',
            diveId: 'tagged',
            timestamp: 60,
            eventType: 'decoStopStart',
            createdAt: DateTime(2026).millisecondsSinceEpoch,
          ),
        );

    expect(await deco.settle(container, 1), 1);
  });

  test('the unfiltered species page ignores the Insights filter', () async {
    final repository = _CountingInsightsRepository();
    final container = makeContainer(
      const DiveFilterState(),
      repository: repository,
    );
    final onScreen = container.listen(
      speciesInsightsProvider('species'),
      (_, _) {},
    );
    addTearDown(onScreen.close);
    await container.read(speciesInsightsProvider('species').future);
    expect(repository.speciesCalls, 1);

    container.read(insightsFilterProvider.notifier).state = searchFor('reef');
    await container.pump();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(repository.speciesCalls, 1);
  });
}
