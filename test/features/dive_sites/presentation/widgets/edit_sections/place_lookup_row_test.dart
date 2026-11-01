import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/place_lookup_row.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _label = 'Look up from coordinates';
const _hint = 'Add coordinates in Location to use this.';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool isBusy,
    required VoidCallback? onLookup,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PlaceLookupRow(isBusy: isBusy, onLookup: onLookup),
        ),
      ),
    );
  }

  TextButton button(WidgetTester tester) =>
      tester.widget<TextButton>(find.widgetWithText(TextButton, _label));

  testWidgets('runs the lookup when pressed', (tester) async {
    var pressed = 0;
    await pump(tester, isBusy: false, onLookup: () => pressed++);

    await tester.tap(find.text(_label));

    expect(pressed, 1);
    expect(find.text(_hint), findsNothing);
  });

  testWidgets('explains itself when there is nothing to look up', (
    tester,
  ) async {
    await pump(tester, isBusy: false, onLookup: null);

    expect(button(tester).onPressed, isNull);
    expect(find.text(_hint), findsOneWidget);
  });

  testWidgets('shows a spinner instead of the hint while busy', (tester) async {
    await pump(tester, isBusy: true, onLookup: null);

    expect(button(tester).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(_hint), findsNothing);
  });

  testWidgets('cannot be pressed twice while a lookup runs', (tester) async {
    await pump(tester, isBusy: true, onLookup: () {});

    expect(button(tester).onPressed, isNull);
  });
}
