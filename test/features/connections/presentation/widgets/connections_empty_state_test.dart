import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_empty_state.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Future<void> _pump(
  WidgetTester tester, {
  required bool hasAnyDives,
  bool allDivesExcluded = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ConnectionsEmptyState(
          view: ConnectionsViewState.initial,
          hasAnyDives: hasAnyDives,
          allDivesExcluded: allDivesExcluded,
        ),
      ),
    ),
  );
}

void main() {
  const noDives =
      'No dives yet. Connections appear once your log has dives in it.';
  const allExcluded = 'All your dives are excluded from statistics';

  testWidgets('an empty logbook is told it has no dives', (tester) async {
    await _pump(tester, hasAnyDives: false);

    expect(find.text(noDives), findsOneWidget);
    expect(find.text(allExcluded), findsNothing);
  });

  testWidgets('a fully excluded logbook is told why nothing shows', (
    tester,
  ) async {
    await _pump(tester, hasAnyDives: false, allDivesExcluded: true);

    expect(find.text(allExcluded), findsOneWidget);
    expect(find.text(noDives), findsNothing);
  });
}
