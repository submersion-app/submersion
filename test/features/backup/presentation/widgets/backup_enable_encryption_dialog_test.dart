import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_enable_encryption_dialog.dart';

Widget _host(Widget child) => MaterialApp(
  // Pinned: the assertions match English strings.
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('enable flow: form -> recovery gate -> finish', (tester) async {
    var enabled = false;
    var finished = false;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => BackupEnableEncryptionDialog(
                  onEnable: (p) async {
                    enabled = true;
                    return 'alpha-bravo-charlie-delta-echo-foxtrot-golf-hotel';
                  },
                  onFinished: () async {
                    finished = true;
                  },
                ),
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'backuppass1');
    await tester.enterText(find.byType(TextField).at(1), 'backuppass1');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(enabled, isTrue);
    expect(find.textContaining('alpha-bravo'), findsOneWidget);

    // Done is disabled until the saved checkbox is ticked.
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
  });

  testWidgets('an enable failure returns to the form with an inline error', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => BackupEnableEncryptionDialog(
                  onEnable: (p) async => throw Exception('keystore down'),
                  onFinished: () async {},
                ),
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'backuppass1');
    await tester.enterText(find.byType(TextField).at(1), 'backuppass1');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Back on the form (both fields visible) with the error surfaced; no
    // recovery phase, so no checkbox.
    expect(find.textContaining('keystore down'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byType(CheckboxListTile), findsNothing);
  });

  testWidgets('Cancel dismisses the enable dialog', (tester) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => BackupEnableEncryptionDialog(
                  onEnable: (p) async => 'x',
                  onFinished: () async {},
                ),
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(BackupEnableEncryptionDialog), findsNothing);
  });

  testWidgets(
    'a failing onFinished returns to the recovery gate (not a stuck spinner)',
    (tester) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => BackupEnableEncryptionDialog(
                    onEnable: (p) async =>
                        'alpha-bravo-charlie-delta-echo-foxtrot-golf-hotel',
                    onFinished: () async =>
                        throw Exception('prefs write failed'),
                  ),
                ),
                child: const Text('open'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'backuppass1');
      await tester.enterText(find.byType(TextField).at(1), 'backuppass1');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Back on the recovery gate with the code still visible and the error
      // surfaced -- not stranded on a non-poppable spinner.
      expect(find.textContaining('prefs write failed'), findsOneWidget);
      expect(find.textContaining('alpha-bravo'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Done'), findsOneWidget);
    },
  );

  testWidgets('form validates password length and match', (tester) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => BackupEnableEncryptionDialog(
                  onEnable: (p) async => 'x',
                  onFinished: () async {},
                ),
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Too short + mismatch: Continue does not advance to the recovery phase.
    await tester.enterText(find.byType(TextField).at(0), 'short');
    await tester.enterText(find.byType(TextField).at(1), 'different');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    expect(find.text('Passwords do not match'), findsOneWidget);
  });
}
