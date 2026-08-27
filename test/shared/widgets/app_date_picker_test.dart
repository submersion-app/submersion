import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

void main() {
  Future<DateTime? Function()> pumpPickerButton(
    WidgetTester tester,
    DateFormatPreference format,
  ) async {
    DateTime? picked;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                picked = await showAppDatePicker(
                  context: context,
                  dateFormat: format,
                  initialDate: DateTime(2026, 1, 15),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
              },
              child: const Text('pick'),
            ),
          ),
        ),
      ),
    );
    return () => picked;
  }

  testWidgets('manual entry accepts the configured day-first format (#765)', (
    tester,
  ) async {
    final picked = await pumpPickerButton(
      tester,
      DateFormatPreference.ddmmyyyy,
    );

    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();

    // Switch the picker to manual input mode.
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    // 31 January in day-first notation: invalid under en-US parsing
    // (month 31), valid under the configured DD/MM/YYYY.
    await tester.enterText(find.byType(TextField), '31/01/2026');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(picked(), DateTime(2026, 1, 31));
  });

  testWidgets('manual entry hint shows the configured format', (tester) async {
    await pumpPickerButton(tester, DateFormatPreference.ddmmyyyyDots);

    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('dd.mm.yyyy'), findsOneWidget);
  });

  testWidgets('manual entry accepts a day-first text-month preference', (
    tester,
  ) async {
    final picked = await pumpPickerButton(
      tester,
      DateFormatPreference.dMMMYYYY,
    );

    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    // D MMM YYYY has no compact input analogue, so the picker falls back to
    // the day-first numeric locale (en-GB): 31/01 parses, 31 is not a month.
    await tester.enterText(find.byType(TextField), '31/01/2026');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(picked(), DateTime(2026, 1, 31));
  });

  Future<DateTimeRange? Function()> pumpRangePickerButton(
    WidgetTester tester,
    DateFormatPreference format,
  ) async {
    DateTimeRange? picked;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                picked = await showAppDateRangePicker(
                  context: context,
                  dateFormat: format,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
              },
              child: const Text('pick'),
            ),
          ),
        ),
      ),
    );
    return () => picked;
  }

  testWidgets('range manual entry accepts the configured day-first format', (
    tester,
  ) async {
    final picked = await pumpRangePickerButton(
      tester,
      DateFormatPreference.ddmmyyyy,
    );

    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    // Day-first notation: 31 is not a valid month, so these only parse when
    // the picker honors DD/MM/YYYY.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '31/01/2026');
    await tester.enterText(fields.at(1), '02/02/2026');
    await tester.pumpAndSettle();

    // Input mode confirms with the OK label; the calendar mode uses Save.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(picked()?.start, DateTime(2026, 1, 31));
    expect(picked()?.end, DateTime(2026, 2, 2));
  });

  testWidgets('range manual entry hints show the configured format', (
    tester,
  ) async {
    await pumpRangePickerButton(tester, DateFormatPreference.ddmmyyyyDots);

    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    // One hint per field (start and end).
    expect(find.text('dd.mm.yyyy'), findsNWidgets(2));
  });

  // Every preference must map to a picker locale and a hint; a missing switch
  // arm would throw when the dialog builds.
  for (final format in DateFormatPreference.values) {
    testWidgets('opens the picker for ${format.name}', (tester) async {
      await pumpPickerButton(tester, format);

      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // Numeric preferences advertise their own pattern as the hint; the
      // text-month ones defer to Material's default.
      final usesOwnHint =
          format != DateFormatPreference.mmmDYYYY &&
          format != DateFormatPreference.dMMMYYYY;
      expect(
        find.text(format.displayName.toLowerCase()),
        usesOwnHint ? findsOneWidget : findsNothing,
      );

      // The picker locale also localizes the dialog chrome, so the cancel
      // label is not always English (de for the dotted preference).
      final cancelLabel = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      ).cancelButtonLabel;
      await tester.tap(find.text(cancelLabel));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
    });
  }
}
