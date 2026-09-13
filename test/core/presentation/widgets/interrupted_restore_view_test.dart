import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/presentation/startup_restore_status.dart';
import 'package:submersion/core/presentation/widgets/interrupted_restore_view.dart';
import 'package:submersion/core/services/restore_journal.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget host(Widget child) => MaterialApp(
  // Pinned: flutter_test forwards the HOST machine's locale list, so an
  // unpinned MaterialApp resolves to a translated UI on a non-English dev
  // machine and every English assertion below finds nothing.
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  // Mirrors StartupWrapper's terminal-screen host: a bare SafeArea > Center.
  home: Scaffold(
    body: SafeArea(child: Center(child: child)),
  ),
);

InterruptedRestoreView buildView({
  InterruptedRestore interrupted = const InterruptedRestore(
    startedAt: null,
    liveExists: true,
  ),
  VoidCallback? onRecover,
  VoidCallback? onKeepCurrent,
  StartupRestoreStatus status = StartupRestoreStatus.idle,
  String? error,
}) => InterruptedRestoreView(
  interrupted: interrupted,
  textColor: Colors.black,
  subtitleColor: Colors.black54,
  onRecover: onRecover ?? () {},
  onKeepCurrent: onKeepCurrent ?? () {},
  onClose: () {},
  status: status,
  error: error,
);

const recoverKey = ValueKey('interruptedRestore_recover');
const keepKey = ValueKey('interruptedRestore_keep');

void main() {
  testWidgets('offers both choices when a file is at the live path', (
    tester,
  ) async {
    await tester.pumpWidget(host(buildView()));

    expect(find.text('A restore did not finish'), findsOneWidget);
    expect(find.byKey(recoverKey), findsOneWidget);
    expect(find.byKey(keepKey), findsOneWidget);
    expect(
      find.text(
        'The file that is in its place now is kept beside it, not deleted.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Your previous dive log is kept as a file in the database folder.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('offers only recovery when the live path is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        buildView(
          interrupted: const InterruptedRestore(
            startedAt: null,
            liveExists: false,
          ),
        ),
      ),
    );

    expect(find.byKey(recoverKey), findsOneWidget);
    expect(find.byKey(keepKey), findsNothing);
    expect(find.textContaining('kept beside it'), findsNothing);
  });

  testWidgets('names the day the restore started when it is known', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        buildView(
          // Noon UTC stays on the same calendar day in any host time zone
          // within twelve hours of UTC.
          interrupted: InterruptedRestore(
            startedAt: DateTime.utc(2026, 9, 13, 12),
            liveExists: true,
          ),
        ),
      ),
    );

    expect(find.textContaining('restoring a backup on '), findsOneWidget);
    expect(find.textContaining('Sep 13'), findsOneWidget);
  });

  testWidgets('says nothing about a date when it is unknown', (tester) async {
    await tester.pumpWidget(host(buildView()));

    expect(
      find.text(
        'Submersion was restoring a backup when it stopped. Your dive log '
        'from before that restore is still on this device, and this version '
        'can open it.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('each action calls back', (tester) async {
    var recovered = 0;
    var kept = 0;
    await tester.pumpWidget(
      host(
        buildView(onRecover: () => recovered++, onKeepCurrent: () => kept++),
      ),
    );

    await tester.ensureVisible(find.byKey(recoverKey));
    await tester.tap(find.byKey(recoverKey));
    await tester.ensureVisible(find.byKey(keepKey));
    await tester.tap(find.byKey(keepKey));

    expect(recovered, 1);
    expect(kept, 1);
  });

  testWidgets('disables both actions while one runs', (tester) async {
    await tester.pumpWidget(
      host(buildView(status: StartupRestoreStatus.running)),
    );

    expect(
      tester.widget<FilledButton>(find.byKey(recoverKey)).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byKey(keepKey)).onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the failure and the error text', (tester) async {
    await tester.pumpWidget(
      host(
        buildView(
          status: StartupRestoreStatus.failed,
          error: 'FileSystemException: locked',
        ),
      ),
    );

    expect(
      find.text(
        'Recovery did not complete. Nothing was deleted; both files are '
        'still on this device.',
      ),
      findsOneWidget,
    );
    expect(find.text('FileSystemException: locked'), findsOneWidget);
  });
}
