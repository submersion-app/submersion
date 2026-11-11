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

  test('leaves it alone for another profile, whose verdicts it does not '
      'hold', () async {
    final (ref, writes) = await refCountingDecoWrites();
    await prepareQueryCachesFor(ref, 'other', {kDiveDecoStatusTable});
    expect(writes, isEmpty);
  });

  test('runs no analysis for a query that reads no cache', () async {
    final (ref, writes) = await refCountingDecoWrites();
    await prepareQueryCachesFor(ref, 'me', {'dives'});
    expect(writes, isEmpty);
  });
}
