import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/insights/presentation/pages/insights_conditions_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_equipment_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_gas_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_overview_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_profile_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_progression_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_time_patterns_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/providers/observations_providers.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';

import '../../../../helpers/info_sheets.dart';
import '../../../../helpers/l10n_test_helpers.dart';

/// Every Insights card's info icon opens a sheet that builds: each sheet
/// reads the card's live settings when tapped, so a card whose builder reads
/// a provider it cannot reach fails here rather than on a diver's tap.
void main() {
  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    // Tall enough that each page builds every card at once.
    tester.view.physicalSize = const Size(1000, 12000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
        child: localizedMaterialApp(home: Scaffold(body: page)),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  final pages = <String, Widget>{
    'Overview': const InsightsOverviewPage(embedded: true),
    'Time patterns': const InsightsTimePatternsPage(embedded: true),
    'Gas': const InsightsGasPage(embedded: true),
    'Progression': const InsightsProgressionPage(embedded: true),
    'Conditions': const InsightsConditionsPage(embedded: true),
    'Equipment': const InsightsEquipmentPage(embedded: true),
    'Profile': const InsightsProfilePage(embedded: true),
  };

  for (final MapEntry(key: name, value: page) in pages.entries) {
    testWidgets('every info icon on $name opens its sheet', (tester) async {
      await pumpPage(tester, page);

      expect(await openEveryInfoSheet(tester), greaterThan(0));
    });
  }
}
