// Issue #4535: the Keep backups picker, with Keep all and a typed count.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_retention_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  /// Opens the picker with [selected] current; the returned getter checks
  /// the picker closed and hands back what it returned.
  Future<int? Function()> open(WidgetTester tester, int selected) async {
    int? result;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        // Pinned: the English assertions below need an English build.
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showBackupRetentionDialog(
                context,
                selected: selected,
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () {
      expect(closed, isTrue, reason: 'the picker must have closed');
      return result;
    };
  }

  bool checked(WidgetTester tester, String label) =>
      tester.widget<ListTile>(find.widgetWithText(ListTile, label)).selected;

  Finder save() => find.widgetWithText(FilledButton, 'Save');
  bool saveEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(save()).onPressed != null;

  Future<void> openCustom(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('the list keeps today\'s choices', (tester) async {
    await open(tester, 10);
    for (final n in backupRetentionChoices) {
      expect(find.widgetWithText(ListTile, '$n'), findsOneWidget);
    }
    expect(backupRetentionChoices, [5, 10, 15, 20, 30]);
  });

  testWidgets('tapping a number returns it', (tester) async {
    final result = await open(tester, 10);
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    expect(result(), 20);
  });

  testWidgets('Keep all returns the sentinel', (tester) async {
    final result = await open(tester, 10);
    await tester.tap(find.text('Keep all'));
    await tester.pumpAndSettle();
    expect(result(), BackupSettings.keepAllRetentionCount);
  });

  testWidgets('Keep all is checked when every backup is kept', (tester) async {
    await open(tester, BackupSettings.keepAllRetentionCount);
    expect(checked(tester, 'Keep all'), isTrue);
    expect(checked(tester, '30'), isFalse);
    expect(find.text('Custom number…'), findsOneWidget);
  });

  testWidgets('a typed count shows on the checked custom row', (tester) async {
    await open(tester, 365);
    expect(checked(tester, 'Custom: 365'), isTrue);
    expect(checked(tester, 'Keep all'), isFalse);
    expect(find.text('Custom number…'), findsNothing);
  });

  testWidgets('a typed count equal to a list value checks that row', (
    tester,
  ) async {
    await open(tester, 20);
    expect(checked(tester, '20'), isTrue);
    expect(checked(tester, 'Custom number…'), isFalse);
  });

  testWidgets('Custom number saves the typed count', (tester) async {
    final result = await open(tester, 10);
    await openCustom(tester, 'Custom number…');
    expect(find.text('Keep how many backups?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '365');
    await tester.pump();
    await tester.tap(save());
    await tester.pumpAndSettle();
    expect(result(), 365);
  });

  testWidgets('a leading zero is read as the number', (tester) async {
    final result = await open(tester, 10);
    await openCustom(tester, 'Custom number…');
    await tester.enterText(find.byType(TextField), '0365');
    await tester.pump();
    await tester.tap(save());
    await tester.pumpAndSettle();
    expect(result(), 365);
  });

  testWidgets('the field starts with the current typed count', (tester) async {
    await open(tester, 365);
    await openCustom(tester, 'Custom: 365');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '365',
    );
  });

  testWidgets('the field starts empty under Keep all', (tester) async {
    await open(tester, BackupSettings.keepAllRetentionCount);
    await openCustom(tester, 'Custom number…');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(saveEnabled(tester), isFalse);
  });

  for (final bad in ['', '0', '10000']) {
    testWidgets('"$bad" cannot be saved', (tester) async {
      await open(tester, 10);
      await openCustom(tester, 'Custom number…');
      await tester.enterText(find.byType(TextField), '5');
      await tester.pump();
      await tester.enterText(find.byType(TextField), bad);
      await tester.pump();
      expect(saveEnabled(tester), isFalse);
      expect(find.text('Enter a number from 1 to 9999'), findsOneWidget);
    });
  }

  testWidgets('letters are not accepted', (tester) async {
    await open(tester, 10);
    await openCustom(tester, 'Custom number…');
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('Cancel in the custom dialog returns nothing', (tester) async {
    final result = await open(tester, 10);
    await openCustom(tester, 'Custom number…');
    await tester.enterText(find.byType(TextField), '365');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
