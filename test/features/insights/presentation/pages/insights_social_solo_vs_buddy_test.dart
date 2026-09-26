import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/presentation/pages/insights_social_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Issue #1998: a diver who never recorded a buddy was shown as diving solo.
/// Unrecorded dives now get their own Not recorded slice.
void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    required int solo,
    required int buddy,
    required int notRecorded,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          soloVsBuddyCountProvider.overrideWith(
            (ref) async => (solo: solo, buddy: buddy, notRecorded: notRecorded),
          ),
          topBuddiesProvider.overrideWith((ref) async => const []),
          topDiveCentersProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: InsightsSocialPage(embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows unrecorded dives as Not recorded, not Solo', (
    tester,
  ) async {
    await pumpPage(tester, solo: 0, buddy: 27, notRecorded: 73);

    expect(find.text('Not recorded'), findsOneWidget);
    final chart = tester.widget<PieChart>(find.byType(PieChart));
    expect(chart.data.sections.map((s) => s.title), ['27%', '0%', '73%']);
  });

  testWidgets('leaves Not recorded out when every dive is recorded', (
    tester,
  ) async {
    await pumpPage(tester, solo: 1, buddy: 3, notRecorded: 0);

    expect(find.text('Not recorded'), findsNothing);
    expect(find.text('Solo'), findsOneWidget);
    expect(find.text('With Buddy'), findsOneWidget);
  });

  testWidgets('shows a chart when only unrecorded dives exist', (tester) async {
    await pumpPage(tester, solo: 0, buddy: 0, notRecorded: 5);

    expect(find.text('Not recorded'), findsOneWidget);
    expect(find.text('No dive data available'), findsNothing);
  });

  testWidgets('shows the empty state with no dives at all', (tester) async {
    await pumpPage(tester, solo: 0, buddy: 0, notRecorded: 0);

    expect(find.text('No dive data available'), findsOneWidget);
  });
}
