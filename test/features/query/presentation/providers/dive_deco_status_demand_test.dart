import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/insights/data/dive_filter_sql.dart';
import 'package:submersion/features/insights/presentation/providers/dive_deco_status_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/presentation/providers/query_caches_keeper.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The computed deco cache follows the analysis only while a live filter
/// reads it (#4461), as the service-due cache does (#2365).
void main() {
  QueryNode parse(String text) {
    final parser = QueryParser(
      appQueryRegistry,
      appQueryRegistry.entityFor(QuerySubject.dives),
      ParseContext(
        prefs: kMetricPrefs,
        now: DateTime(2026, 9, 28),
        names: const MapNameResolver({}),
      ),
    );
    return (parser.parse(text) as ParseOk).node!;
  }

  late ProviderContainer container;
  var writerBuilds = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    writerBuilds = 0;
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        diveDecoStatusCacheProvider.overrideWith((ref) async {
          writerBuilds++;
          return 0;
        }),
      ],
    );
    addTearDown(container.dispose);
    container.listen(queryCachesKeeperProvider, (_, _) {});
    await container.pump();
  });

  test('no filter reads the cache, so the writer never runs', () async {
    await container.read(queryCachesKeeperProvider.future);
    expect(
      container.read(queryCacheDemandProvider(kDiveDecoStatusTable)),
      isFalse,
    );
    expect(writerBuilds, 0);
  });

  test('the Deco filter on the dive list starts the writer', () async {
    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      decoOnly: true,
    );
    await container.read(queryCachesKeeperProvider.future);
    expect(
      container.read(queryCacheDemandProvider(kDiveDecoStatusTable)),
      isTrue,
    );
    expect(writerBuilds, 1);
  });

  test('an Insights query naming deco starts the writer', () async {
    container.read(insightsFilterProvider.notifier).state = DiveFilterState(
      query: parse('deco = true'),
    );
    await container.read(queryCachesKeeperProvider.future);
    expect(
      container.read(queryCacheDemandProvider(kDiveDecoStatusTable)),
      isTrue,
    );
    expect(writerBuilds, 1);
  });

  test('the writer is released once no filter reads the cache', () async {
    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      decoOnly: false,
    );
    await container.read(queryCachesKeeperProvider.future);
    expect(container.exists(diveDecoStatusCacheProvider), isTrue);

    container.read(diveFilterProvider.notifier).state = const DiveFilterState();
    await container.read(queryCachesKeeperProvider.future);
    await container.pump();
    // Disposed, not merely idle: it no longer follows dive writes.
    expect(container.exists(diveDecoStatusCacheProvider), isFalse);
  });
}
