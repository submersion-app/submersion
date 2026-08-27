import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/widgets/sync_maintenance_progress_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #1032: the destructive Troubleshoot Sync actions ran for minutes in
/// silence, so the user assumed a hang and killed the app mid-wipe. These tests
/// pin the three properties that prevent that: it reports, it refuses to be
/// dismissed, and it always goes away when the work stops.
void main() {
  /// Pumps a page with a button that runs [task] behind the progress dialog.
  Future<void> pumpRunner(
    WidgetTester tester,
    Future<void> Function(SyncMaintenanceReporter report) task, {
    void Function(Object error)? onError,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                try {
                  await runWithSyncMaintenanceProgress<void>(
                    context: context,
                    title: 'Wiping sync data',
                    task: task,
                  );
                } catch (e) {
                  onError?.call(e);
                }
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the phase and a real file count as work advances', (
    tester,
  ) async {
    late SyncMaintenanceReporter report;
    final gate = Completer<void>();
    await pumpRunner(tester, (r) async {
      report = r;
      await gate.future;
    });

    await tester.tap(find.text('go'));
    await tester.pump();

    expect(
      find.text('Preparing...'),
      findsOneWidget,
      reason: 'the listing that fixes the total is itself a round trip',
    );

    report(3, 412, 'Deleting');
    await tester.pump();
    expect(find.text('Deleting - 3 of 412 files'), findsOneWidget);

    // A phase with nothing countable (the full-library republish) must not
    // leave a finished-looking bar on screen.
    report(0, 0, 'Publishing library');
    await tester.pump();
    expect(find.text('Publishing library'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('tells the user not to close the app', (tester) async {
    final gate = Completer<void>();
    await pumpRunner(tester, (r) => gate.future);
    await tester.tap(find.text('go'));
    await tester.pump();

    expect(find.textContaining('Keep the app open'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('refuses to pop while the work is running', (tester) async {
    final gate = Completer<void>();
    await pumpRunner(tester, (r) => gate.future);
    await tester.tap(find.text('go'));
    await tester.pump();

    // Android back / predictive back while a wipe is half done would leave the
    // backend in the exact half-cleared state issue #1032 reports.
    //
    // Assert on the dialog still being mounted, not on maybePop's return: a
    // PopScope that BLOCKS a pop still reports true (the request was consumed
    // rather than bubbled to the system), so the return value cannot tell
    // "popped" from "refused".
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    // pump, never pumpAndSettle: the bar is indeterminate here and animates
    // forever, so settling can only time out.
    await tester.pump();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Keep the app open'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('does not return before the dialog has been popped', (
    tester,
  ) async {
    // Callers show their result snackbar the moment this returns, so the pop
    // must have been issued first. Note this is the route's completion, not
    // the end of its exit transition -- a dialog route completes at pop time,
    // which is why the docstring no longer claims "fully closed".
    final gate = Completer<void>();
    var returned = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await runWithSyncMaintenanceProgress<void>(
                  context: context,
                  title: 'Wiping sync data',
                  task: (r) => gate.future,
                );
                returned = true;
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump();
    expect(returned, isFalse, reason: 'the task has not finished');
    expect(find.byType(AlertDialog), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    expect(returned, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('closes and rethrows when the task fails', (tester) async {
    Object? seen;
    await pumpRunner(
      tester,
      (r) async => throw StateError('provider offline'),
      onError: (e) => seen = e,
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(
      find.byType(AlertDialog),
      findsNothing,
      reason:
          'a thrown task must never strand the user behind a barrier that '
          'cannot be dismissed',
    );
    expect(seen, isA<StateError>());
  });
}
