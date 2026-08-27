import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_conditions_page.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  /// Pumps the conditions page with a fixed distribution, so the label mapping
  /// can be asserted without touching a database.
  Future<void> pumpWithSegments(
    WidgetTester tester,
    List<DistributionSegment> segments,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          visibilityDistributionProvider.overrideWith((ref) async => segments),
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

  DistributionSegment seg(String label, int count, double pct) =>
      DistributionSegment(label: label, count: count, percentage: pct);

  testWidgets('renders calibrated band keys as localized adjectives', (
    tester,
  ) async {
    await pumpWithSegments(tester, [
      seg('excellent', 3, 50),
      seg('good', 3, 50),
    ]);

    expect(find.textContaining('Excellent'), findsWidgets);
    expect(find.textContaining('Good'), findsWidgets);
    // The raw repository keys must never reach the screen.
    expect(find.text('excellent'), findsNothing);
  });

  testWidgets('renders a legacy key as its range, marked pre-measurement', (
    tester,
  ) async {
    await pumpWithSegments(tester, [seg('legacy_moderate', 2, 100)]);

    expect(find.textContaining('before measurement'), findsWidgets);
    expect(find.text('legacy_moderate'), findsNothing);
  });

  testWidgets('keeps legacy and calibrated segments distinct', (tester) async {
    await pumpWithSegments(tester, [
      seg('good', 1, 50),
      seg('legacy_moderate', 1, 50),
    ]);

    expect(find.textContaining('Good'), findsWidgets);
    expect(find.textContaining('before measurement'), findsWidgets);
  });

  testWidgets('renders an empty distribution without throwing', (tester) async {
    await pumpWithSegments(tester, const []);
    expect(find.byType(StatisticsConditionsPage), findsOneWidget);
  });
}
