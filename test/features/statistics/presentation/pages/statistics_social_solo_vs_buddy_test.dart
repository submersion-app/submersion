import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_social_page.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_charts.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Issue #1998: a diver who never dived solo, and never entered buddies, was
/// told 73% of their dives were solo. Dives with no buddy and no Solo role are
/// now their own "Not recorded" share.
void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    ({int solo, int buddy, int notRecorded}) counts,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          soloVsBuddyCountProvider.overrideWith((ref) async => counts),
          topBuddiesProvider.overrideWith((ref) async => const []),
          topDiveCentersProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: StatisticsSocialPage(embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Label to rounded percentage for each slice of the pie. The percentages
  /// are painted by the chart, not laid out as text, so they are read from
  /// the widget's data.
  Map<String, int> slices(WidgetTester tester) => {
    for (final s
        in tester
            .widget<DistributionPieChart>(find.byType(DistributionPieChart))
            .data)
      s.label: s.percentage.round(),
  };

  testWidgets('dives with nothing recorded are not called solo', (
    tester,
  ) async {
    await pumpPage(tester, (solo: 0, buddy: 27, notRecorded: 73));

    // The Solo share is still listed, at zero, so the diver can see it.
    expect(slices(tester), {'With Buddy': 27, 'Solo': 0, 'Not recorded': 73});
  });

  testWidgets('shares are taken over every dive, not only recorded ones', (
    tester,
  ) async {
    await pumpPage(tester, (solo: 1, buddy: 3, notRecorded: 6));

    expect(slices(tester), {'With Buddy': 30, 'Solo': 10, 'Not recorded': 60});
  });

  testWidgets('no not recorded share when every dive is accounted for', (
    tester,
  ) async {
    await pumpPage(tester, (solo: 1, buddy: 3, notRecorded: 0));

    expect(slices(tester), {'With Buddy': 75, 'Solo': 25});
  });

  testWidgets('no dives at all still shows the empty state', (tester) async {
    await pumpPage(tester, (solo: 0, buddy: 0, notRecorded: 0));

    expect(find.text('No dive data available'), findsOneWidget);
  });
}
