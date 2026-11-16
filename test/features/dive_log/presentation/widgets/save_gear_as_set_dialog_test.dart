import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/save_gear_as_set_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

/// The Save as set dialog shared by the dive form and the dive page's
/// Equipment card (issue #4527, plan 5).
void main() {
  final l = AppLocalizationsEn();

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showSaveGearAsSetDialog(
                  context,
                  topLevelIds: const ['fins'],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Save with no name says so and keeps the dialog', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text(l.diveLog_edit_save));
    await tester.pump();

    expect(
      find.text(l.diveLog_edit_saveAsSetDialog_validation),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('its text controllers go with the dialog', (tester) async {
    await openDialog(tester);
    final name = tester
        .widget<TextField>(
          find.widgetWithText(
            TextField,
            l.diveLog_edit_saveAsSetDialog_setName,
          ),
        )
        .controller!;

    await tester.tap(find.text(l.diveLog_edit_cancel));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(() => name.addListener(() {}), throwsFlutterError);
  });
}
