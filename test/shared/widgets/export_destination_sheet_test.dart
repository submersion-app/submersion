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
      // Pinned: without this the app resolves against the HOST machine's
      // locales, and it supports 11 of them, so the English assertions below
      // fail for a contributor whose machine is de, fr, es or zh. CI is en_US,
      // so that failure would never show up here.
      locale: const Locale('en'),
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
  bool showDiveContentToggles = false,
}) async {
  Object? result = #pending;
  await tester.pumpWidget(
    MaterialApp(
      // Pinned: without this the app resolves against the HOST machine's
      // locales, and it supports 11 of them, so the English assertions below
      // fail for a contributor whose machine is de, fr, es or zh. CI is en_US,
      // so that failure would never show up here.
      locale: const Locale('en'),
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
                showDiveContentToggles: showDiveContentToggles,
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
    expect((result()! as ExportChoice).options.includeRawData, isTrue);
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
    expect((result()! as ExportChoice).options.includeRawData, isFalse);
  });

  testWidgets('no toggle is offered for formats with no raw bytes', (
    tester,
  ) async {
    final result = await _pumpOptionsHost(tester, showRawDataToggle: false);

    expect(find.byType(CheckboxListTile), findsNothing);

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect((result()! as ExportChoice).options.includeRawData, isTrue);
  });

  testWidgets('the dive content toggles appear only on request', (
    tester,
  ) async {
    await _pumpOptionsHost(tester);

    expect(find.text('Include dive participants'), findsNothing);
    expect(find.text('Include gear'), findsNothing);
  });

  testWidgets('the dive content toggles start checked', (tester) async {
    final result = await _pumpOptionsHost(tester, showDiveContentToggles: true);

    expect(find.text('Include dive participants'), findsOneWidget);
    expect(find.text('Include gear'), findsOneWidget);
    expect(
      tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .map((t) => t.value),
      [true, true, true],
    );

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    final options = (result()! as ExportChoice).options;
    expect(options.includeRawData, isTrue);
    expect(options.includeParticipants, isTrue);
    expect(options.includeGear, isTrue);
  });

  testWidgets('unticking participants and gear carries into the options', (
    tester,
  ) async {
    final result = await _pumpOptionsHost(tester, showDiveContentToggles: true);

    await tester.tap(find.text('Include dive participants'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Include gear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to File'));
    await tester.pumpAndSettle();

    final choice = result()! as ExportChoice;
    expect(choice.destination, ExportDestination.saveToFile);
    expect(choice.options.includeRawData, isTrue);
    expect(choice.options.includeParticipants, isFalse);
    expect(choice.options.includeGear, isFalse);
  });

  testWidgets('the sheet sizes to its content, not the screen', (tester) async {
    // isScrollControlled lifts the 9/16 height cap so the three checkboxes
    // fit on a phone; the scroll view inside must still size to its content,
    // or every export sheet would open full screen.
    await _pumpSheetHost(tester);

    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      tester.getSize(find.byType(SingleChildScrollView)).height,
      lessThan(screenHeight / 2),
    );
  });
}
