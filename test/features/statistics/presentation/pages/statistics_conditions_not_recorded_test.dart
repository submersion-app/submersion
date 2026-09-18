import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_conditions_page.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Issue #1998: dives with no water type or entry method are shown as their
/// own "Not recorded" share rather than being left out of the chart.
void main() {
  const notRecorded = DistributionSegment.notRecordedKey;

  DistributionSegment seg(String label, int count, double pct) =>
      DistributionSegment(label: label, count: count, percentage: pct);

  Future<void> pumpPage(
    WidgetTester tester, {
    List<DistributionSegment> waterType = const [],
    List<DistributionSegment> entryMethod = const [],
  }) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          waterTypeDistributionProvider.overrideWith((ref) async => waterType),
          entryMethodDistributionProvider.overrideWith(
            (ref) async => entryMethod,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: StatisticsConditionsPage(embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The colour of the legend swatch beside [label] in a pie chart legend.
  Color? legendSwatchColor(WidgetTester tester, String label) {
    final row = find.ancestor(of: find.text(label), matching: find.byType(Row));
    final swatch = tester
        .widgetList<Container>(
          find.descendant(of: row.first, matching: find.byType(Container)),
        )
        .firstWhere((c) => c.decoration is BoxDecoration);
    return (swatch.decoration! as BoxDecoration).color;
  }

  testWidgets('water type shows the not recorded share in grey', (
    tester,
  ) async {
    await pumpPage(
      tester,
      waterType: [
        seg('salt', 8, 40),
        seg('fresh', 11, 55),
        seg(notRecorded, 1, 5),
      ],
    );

    expect(find.text('Not recorded'), findsOneWidget);
    expect(legendSwatchColor(tester, 'Not recorded'), Colors.grey.shade400);
  });

  testWidgets('brackish water no longer reuses the salt water colour', (
    tester,
  ) async {
    // The palette had two colours, so a third water type wrapped around.
    await pumpPage(
      tester,
      waterType: [
        seg('salt', 2, 50),
        seg('fresh', 1, 25),
        seg('brackish', 1, 25),
      ],
    );

    final salt = legendSwatchColor(tester, 'Salt Water');
    final brackish = legendSwatchColor(tester, 'Brackish');
    expect(brackish, isNot(salt));
  });

  testWidgets('entry method shows the not recorded share', (tester) async {
    await pumpPage(
      tester,
      entryMethod: [seg('shore', 3, 60), seg(notRecorded, 2, 40)],
    );

    expect(find.textContaining('Not recorded'), findsWidgets);
  });
}
