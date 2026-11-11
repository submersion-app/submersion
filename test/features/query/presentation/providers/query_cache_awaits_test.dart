import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/dive_filter_sql.dart';
import 'package:submersion/features/insights/presentation/providers/dive_deco_status_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_cache_awaits.dart';

/// A query run outside a provider's build (a rule run, an agent's query)
/// prepares the engine-verdict caches it reads, but only for the profile
/// whose verdicts they hold (#4461).
void main() {
  Future<(Ref, List<int>)> refCountingDecoWrites() async {
    final writes = <int>[];
    final container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        diveDecoStatusCacheProvider.overrideWith((ref) async {
          writes.add(1);
          return 0;
        }),
      ],
    );
    addTearDown(container.dispose);
    final probe = Provider((ref) => ref);
    return (container.read(probe), writes);
  }

  test('brings the deco cache up to date for the active profile', () async {
    final (ref, writes) = await refCountingDecoWrites();
    await prepareQueryCachesFor(ref, 'me', {kDiveDecoStatusTable});
    expect(writes, hasLength(1));
  });

  test('never runs the active diver\'s writer for another profile', () async {
    // Another profile's verdicts come from a pass pinned to its own settings
    // (see dive_deco_status_cache_test); a query reading no deco needs none.
    final (ref, writes) = await refCountingDecoWrites();
    await prepareQueryCachesFor(ref, 'other', {'dives'});
    expect(writes, isEmpty);
  });

  group('a pass the keeper holds', () {
    // The writer's value is the input-write count its pass began from.
    late ProviderContainer container;
    late Ref ref;
    var builds = 0;

    setUp(() {
      builds = 0;
      container = ProviderContainer(
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
          diveDecoStatusCacheProvider.overrideWith((ref) async {
            builds++;
            return ref.read(diveDecoInputWritesProvider);
          }),
        ],
      );
      addTearDown(container.dispose);
      final keeper = container.listen(diveDecoStatusCacheProvider, (_, _) {});
      addTearDown(keeper.close);
      ref = container.read(Provider((ref) => ref));
    });

    test('is reused while no input was written since it began', () async {
      await prepareQueryCachesFor(ref, 'me', {kDiveDecoStatusTable});
      await prepareQueryCachesFor(ref, 'me', {kDiveDecoStatusTable});
      expect(builds, 1);
    });

    test('is re-run when an input was written after it began', () async {
      await prepareQueryCachesFor(ref, 'me', {kDiveDecoStatusTable});
      // A dive write the debounced tick has not yet acted on.
      container.read(diveDecoInputWritesProvider.notifier).state++;
      await prepareQueryCachesFor(ref, 'me', {kDiveDecoStatusTable});
      expect(builds, 2);
    });
  });

  test('runs no analysis for a query that reads no cache', () async {
    final (ref, writes) = await refCountingDecoWrites();
    await prepareQueryCachesFor(ref, 'me', {'dives'});
    expect(writes, isEmpty);
  });
}
