import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/presentation/providers/conditions_stats_providers.dart';
import 'package:submersion/features/insights/presentation/providers/dive_deco_status_providers.dart';
import 'package:submersion/features/insights/presentation/providers/equipment_condition_insights_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Every Insights card under a filter naming deco waits for the computed
/// verdicts before its first query (#4461), not only the cards built on
/// the shared keep-alive helper.
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<(ProviderContainer, List<int>)> filteredOnDeco() async {
    final writes = <int>[];
    final container = ProviderContainer(
      overrides: [
        ...(await getBaseOverrides()).cast(),
        diveDecoStatusCacheProvider.overrideWith((ref) async {
          writes.add(1);
          return 0;
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(insightsFilterProvider.notifier).state =
        const DiveFilterState(decoOnly: true);
    return (container, writes);
  }

  test('the Conditions card waits for the verdicts', () async {
    final (container, writes) = await filteredOnDeco();
    final sub = container.listen(conditionsRowsProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(conditionsRowsProvider.future);
    expect(writes, hasLength(1));
  });

  test('the equipment condition cards wait for the verdicts', () async {
    final (container, writes) = await filteredOnDeco();
    final sub = container.listen(insightsFilteredDiveIdsProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(insightsFilteredDiveIdsProvider.future);
    expect(writes, hasLength(1));
  });
}
