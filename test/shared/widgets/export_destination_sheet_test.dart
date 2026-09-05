import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/export_destination_sheet.dart';

/// Pumps a button that opens the sheet, recording whatever it returns.
///
/// [result] stays at its sentinel until the sheet completes, so a test can tell
/// "not finished" apart from "dismissed with null".
Future<ValueGetter<Object?>> _pumpSheetHost(WidgetTester tester) async {
  Object? result = #pending;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showExportDestinationSheet(
                context,
                title: 'Dive Log CSV',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => result;
}

/// Pumps a host for the richer sheet, which also offers the raw data toggle.
Future<ValueGetter<Object?>> _pumpOptionsHost(
  WidgetTester tester, {
  bool showRawDataToggle = true,
}) async {
  Object? result = #pending;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showExportDestinationSheetWithOptions(
                context,
                title: 'Dive Log UDDF',
                showRawDataToggle: showRawDataToggle,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => result;
}

void main() {
  testWidgets('offers both a save and a share destination', (tester) async {
    await _pumpSheetHost(tester);

    expect(find.text('Dive Log CSV'), findsOneWidget);
    expect(find.text('Save to File'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.byIcon(Icons.save_alt), findsOneWidget);
    expect(find.byIcon(Icons.share), findsOneWidget);
  });

  testWidgets('tapping save returns saveToFile', (tester) async {
    final result = await _pumpSheetHost(tester);

    await tester.tap(find.text('Save to File'));
    await tester.pumpAndSettle();

    expect(result(), ExportDestination.saveToFile);
  });

  testWidgets('tapping share returns share', (tester) async {
    final result = await _pumpSheetHost(tester);

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(result(), ExportDestination.share);
  });

  testWidgets('dismissing the sheet returns null', (tester) async {
    final result = await _pumpSheetHost(tester);

    // Tap the scrim above the sheet to dismiss it.
    await tester.tapAt(const Offset(400, 100));
    await tester.pumpAndSettle();

    expect(result(), isNull);
  });

  testWidgets('the raw data toggle starts checked and rides the choice', (
    tester,
  ) async {
    final result = await _pumpOptionsHost(tester);

    expect(find.text('Include raw dive computer data'), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
      reason: 'it must start checked, matching UddfExportOptions default',
    );

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(result(), isA<ExportChoice>());
    expect((result()! as ExportChoice).destination, ExportDestination.share);
    expect((result()! as ExportChoice).includeRawData, isTrue);
  });

  testWidgets('unchecking the toggle carries through to the choice', (
    tester,
  ) async {
    // The user-facing point of the whole toggle: nothing else asserts that
    // unticking the box actually reaches the export.
    final result = await _pumpOptionsHost(tester);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );

    await tester.tap(find.text('Save to File'));
    await tester.pumpAndSettle();

    expect(
      (result()! as ExportChoice).destination,
      ExportDestination.saveToFile,
    );
    expect((result()! as ExportChoice).includeRawData, isFalse);
  });

  testWidgets('no toggle is offered for formats with no raw bytes', (
    tester,
  ) async {
    final result = await _pumpOptionsHost(tester, showRawDataToggle: false);

    expect(find.byType(CheckboxListTile), findsNothing);

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect((result()! as ExportChoice).includeRawData, isTrue);
  });
}
