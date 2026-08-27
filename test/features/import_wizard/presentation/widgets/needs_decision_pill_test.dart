import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/needs_decision_pill.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _pump(ColorScheme colorScheme) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: NeedsDecisionPill(colorScheme: colorScheme)),
  );
}

void main() {
  testWidgets('renders localized text and warning icon', (tester) async {
    await tester.pumpWidget(_pump(const ColorScheme.light()));
    expect(find.text('Needs decision'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });
}
