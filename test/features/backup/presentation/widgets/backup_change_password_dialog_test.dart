import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart'
    show WrongPassphraseException;
import 'package:submersion/features/backup/presentation/widgets/backup_change_password_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Future<void> _open(
  WidgetTester tester, {
  required Future<void> Function(String current, String next) onSubmit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      // Pinned: the assertions match English strings.
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => BackupChangePasswordDialog(onSubmit: onSubmit),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _fill(
  WidgetTester tester, {
  required String current,
  required String next,
  required String confirm,
}) async {
  await tester.enterText(find.byType(TextField).at(0), current);
  await tester.enterText(find.byType(TextField).at(1), next);
  await tester.enterText(find.byType(TextField).at(2), confirm);
}

void main() {
  testWidgets('rejects a too-short new password without calling onSubmit', (
    tester,
  ) async {
    var called = false;
    await _open(
      tester,
      onSubmit: (_, _) async {
        called = true;
      },
    );
    await _fill(tester, current: 'oldpass1', next: 'short', confirm: 'short');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Use at least 8 characters'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('rejects mismatched confirmation without calling onSubmit', (
    tester,
  ) async {
    var called = false;
    await _open(
      tester,
      onSubmit: (_, _) async {
        called = true;
      },
    );
    await _fill(
      tester,
      current: 'oldpass1',
      next: 'newpass12',
      confirm: 'different1',
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('wrong current password shows an inline error and stays open', (
    tester,
  ) async {
    await _open(
      tester,
      onSubmit: (_, _) async => throw const WrongPassphraseException(),
    );
    await _fill(
      tester,
      current: 'wrong',
      next: 'newpass12',
      confirm: 'newpass12',
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect password or recovery code'), findsOneWidget);
    // Dialog is still on screen (its three fields remain).
    expect(find.byType(TextField), findsNWidgets(3));
  });

  testWidgets('a generic failure surfaces its message inline', (tester) async {
    await _open(tester, onSubmit: (_, _) async => throw Exception('boom'));
    await _fill(
      tester,
      current: 'oldpass1',
      next: 'newpass12',
      confirm: 'newpass12',
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('a valid change pops the dialog', (tester) async {
    String? gotCurrent;
    String? gotNext;
    await _open(
      tester,
      onSubmit: (current, next) async {
        gotCurrent = current;
        gotNext = next;
      },
    );
    await _fill(
      tester,
      current: 'oldpass1',
      next: 'newpass12',
      confirm: 'newpass12',
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(gotCurrent, 'oldpass1');
    expect(gotNext, 'newpass12');
    expect(find.byType(BackupChangePasswordDialog), findsNothing);
  });

  testWidgets('Cancel dismisses without submitting', (tester) async {
    var called = false;
    await _open(
      tester,
      onSubmit: (_, _) async {
        called = true;
      },
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(find.byType(BackupChangePasswordDialog), findsNothing);
  });
}
