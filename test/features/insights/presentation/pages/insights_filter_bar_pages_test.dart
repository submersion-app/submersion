import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/presentation/pages/insights_geographic_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_marine_life_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_observations_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_overview_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_profile_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_social_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_time_patterns_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/providers/observations_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/insights_filter_action.dart';
import 'package:submersion/features/insights/presentation/widgets/insights_filter_bar.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';

/// Every page the Insights filter narrows has to say so where it stands: on a
/// phone it is a page of its own, away from the landing page's bar (#3479).
void main() {
  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          insightsFilterProvider.overrideWith(
            (ref) => const DiveFilterState(favoritesOnly: true),
          ),
          filteredDiveStatisticsProvider.overrideWith(
            (ref) async => DiveStatistics(
              totalDives: 5,
              totalTimeSeconds: 0,
              maxDepth: 0,
              avgMaxDepth: 0,
              totalSites: 0,
            ),
          ),
          savedQueryLoadsProvider('dives').overrideWith((ref) async => []),
          observationsProvider.overrideWith((ref) async => []),
        ],
        child: localizedMaterialApp(home: page),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  final scoped = <String, (Widget, Widget)>{
    'Overview': (
      const InsightsOverviewPage(),
      const Scaffold(body: InsightsOverviewPage(embedded: true)),
    ),
    'Social': (
      const InsightsSocialPage(),
      const Scaffold(body: InsightsSocialPage(embedded: true)),
    ),
    'Geographic': (
      const InsightsGeographicPage(),
      const Scaffold(body: InsightsGeographicPage(embedded: true)),
    ),
    'Marine life': (
      const InsightsMarineLifePage(),
      const Scaffold(body: InsightsMarineLifePage(embedded: true)),
    ),
    'Time patterns': (
      const InsightsTimePatternsPage(),
      const Scaffold(body: InsightsTimePatternsPage(embedded: true)),
    ),
    'Profile': (
      const InsightsProfilePage(),
      const Scaffold(body: InsightsProfilePage(embedded: true)),
    ),
  };

  for (final MapEntry(key: name, value: (standalone, embedded))
      in scoped.entries) {
    testWidgets('$name shows the bar and the filter action on its own', (
      tester,
    ) async {
      await pumpPage(tester, standalone);

      expect(find.byType(InsightsFilterBar), findsOneWidget);
      expect(find.byType(InsightsFilterAction), findsOneWidget);
    });

    testWidgets('$name leaves both to the list beside it when embedded', (
      tester,
    ) async {
      await pumpPage(tester, embedded);

      expect(find.byType(InsightsFilterBar), findsNothing);
      expect(find.byType(InsightsFilterAction), findsNothing);
    });
  }

  testWidgets('Observations has no selector: the filter does not reach it', (
    tester,
  ) async {
    await pumpPage(tester, const InsightsObservationsPage());

    expect(find.byType(InsightsFilterBar), findsNothing);
    expect(find.byType(InsightsFilterAction), findsNothing);
    expect(
      find.text(
        'Observations use your whole log, so the filter does not apply to '
        'them',
      ),
      findsOneWidget,
    );
  });
}
