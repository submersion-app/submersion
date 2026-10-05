import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/year_play_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/year_play_pill.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget child, {
  ({int first, int last})? span = (first: 2019, last: 2024),
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        connectionsYearSpanProvider.overrideWith((ref) async => span),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

void main() {
  testWidgets('the pill plays, shows the growing range, and pauses', (
    tester,
  ) async {
    final c = await _pump(tester, const YearPlayPill());
    expect(find.text('Years 2019 to 2024'), findsOneWidget);
    expect(find.byTooltip('Play years'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('year-play-button')));
    await tester.pump();
    expect(c.read(yearPlayProvider), 2019);
    expect(find.text('Years 2019 to 2019'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('year-play-button')));
    await tester.pump();
    expect(c.read(yearPlayProvider), isNull);
    expect(find.byTooltip('Play years'), findsOneWidget);
  });

  testWidgets('the pill hides on a one-year log or no dives', (tester) async {
    await _pump(tester, const YearPlayPill(), span: (first: 2024, last: 2024));
    expect(find.byKey(const ValueKey('year-play-pill')), findsNothing);
    await _pump(tester, const YearPlayPill(), span: null);
    expect(find.byKey(const ValueKey('year-play-pill')), findsNothing);
  });
}
