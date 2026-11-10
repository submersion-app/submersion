import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/pages/insights_social_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Issue #4385: Top Dive Buddies and Top Dive Centers showed five rows and
/// "and 5 more" whatever the real total was. Each card now shows ten and
/// opens the rest behind "Show all".
void main() {
  List<RankingItem> ranking(String prefix, int n) => [
    for (var i = 0; i < n; i++)
      RankingItem(id: '$prefix$i', name: '$prefix $i', count: 100 - i),
  ];

  Future<void> pumpPage(
    WidgetTester tester, {
    required int buddies,
    required int centers,
  }) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          soloVsBuddyCountProvider.overrideWith(
            (ref) async => (solo: 0, buddy: 0, notRecorded: 0),
          ),
          topBuddiesProvider.overrideWith(
            (ref) async => ranking('Buddy', buddies),
          ),
          topDiveCentersProvider.overrideWith(
            (ref) async => ranking('Center', centers),
          ),
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

  testWidgets('each card shows ten rows and Show all, not a count', (
    tester,
  ) async {
    await pumpPage(tester, buddies: 23, centers: 14);

    expect(find.text('Buddy 9'), findsOneWidget);
    expect(find.text('Buddy 10'), findsNothing);
    expect(find.text('Center 9'), findsOneWidget);
    expect(find.text('Center 10'), findsNothing);
    expect(find.text('Show all'), findsNWidgets(2));
    expect(find.textContaining(RegExp(r'and \d+ more')), findsNothing);
  });

  testWidgets('Show all opens the whole buddy ranking', (tester) async {
    await pumpPage(tester, buddies: 23, centers: 3);

    expect(find.text('Show all'), findsOneWidget);
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();

    expect(find.text('Buddy 22'), findsOneWidget);
    expect(find.text('Show less'), findsOneWidget);
  });
}
