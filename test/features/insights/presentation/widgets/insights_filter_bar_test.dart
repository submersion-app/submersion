import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/insights_filter_bar.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  testWidgets('tapping clear resets the statistics filter', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          insightsFilterProvider.overrideWith(
            (ref) => const DiveFilterState(favoritesOnly: true),
          ),
          // InsightsFilterBar also watches filteredDiveStatisticsProvider
          // for the matching-dive count. That provider normally resolves
          // through the dive repository + DatabaseService, which isn't set
          // up in this widget test, so it is overridden directly with a
          // fixed value (matching the pattern used in
          // insights_overview_page_test.dart).
          filteredDiveStatisticsProvider.overrideWith(
            (ref) async => DiveStatistics(
              totalDives: 5,
              totalTimeSeconds: 0,
              maxDepth: 0,
              avgMaxDepth: 0,
              totalSites: 0,
            ),
          ),
        ],
        child: localizedMaterialApp(
          home: const Scaffold(body: InsightsFilterBar()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(InsightsFilterBar)),
    );
    expect(container.read(insightsFilterProvider).hasActiveFilters, true);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(container.read(insightsFilterProvider).hasActiveFilters, false);
  });
}
