import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/presentation/startup_restore_status.dart';
import 'package:submersion/core/presentation/widgets/dive_log_unavailable_view.dart';
import 'package:submersion/core/services/dive_log_availability.dart';
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

const folder = '/Users/diver/Library/Mobile Documents/Submersion';

const tryAgainKey = ValueKey('diveLogUnavailable_tryAgain');

DiveLogUnavailableView buildView({
  DiveLogAvailability availability = DiveLogAvailability.missing,
  List<String>? pressed,
  bool busy = false,
  StartupRestoreStatus restoreStatus = StartupRestoreStatus.idle,
  String? restoreError,
}) {
  void record(String name) => pressed?.add(name);
  return DiveLogUnavailableView(
    availability: availability,
    folderPath: folder,
    textColor: Colors.black,
    subtitleColor: Colors.black54,
    onTryAgain: () => record('tryAgain'),
    onUseAnotherFolder: () => record('anotherFolder'),
    onRestoreFromFile: () => record('restore'),
    onStartNew: () => record('startNew'),
    onClose: () => record('close'),
    busy: busy,
    restoreStatus: restoreStatus,
    restoreError: restoreError,
  );
}

void main() {
  group('a dive log still in iCloud', () {
    testWidgets('says where it is and that nothing was changed', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(buildView(availability: DiveLogAvailability.inICloudOnly)),
      );

      expect(find.text('Your dive log is still in iCloud'), findsOneWidget);
      expect(find.textContaining(folder), findsOneWidget);
      expect(find.textContaining('nothing has been changed'), findsOneWidget);
    });

    testWidgets('offers only the routes that leave the folder alone', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(buildView(availability: DiveLogAvailability.inICloudOnly)),
      );

      expect(find.byKey(tryAgainKey), findsOneWidget);
      expect(find.text('Use a dive log in another folder'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      // Writing a new or restored file beside an iCloud placeholder leaves
      // iCloud two dive logs to reconcile, so neither is offered here.
      expect(find.text('Start a new dive log in this folder'), findsNothing);
      expect(find.text('Restore from a backup file'), findsNothing);
    });
  });

  group('a dive log missing from its folder', () {
    testWidgets('names the file and the folder it expected', (tester) async {
      await tester.pumpWidget(host(buildView()));

      expect(find.text('Your dive log was not found'), findsOneWidget);
      expect(
        find.textContaining('there is no submersion.db there now'),
        findsOneWidget,
      );
      expect(find.textContaining(folder), findsOneWidget);
    });

    testWidgets('offers every route, the empty dive log last', (tester) async {
      await tester.pumpWidget(host(buildView()));

      final labels = [
        'Use a dive log in another folder',
        'Restore from a backup file',
        'Start a new dive log in this folder',
      ];
      final tops = [
        for (final label in labels) tester.getTopLeft(find.text(label)).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
      expect(find.byKey(tryAgainKey), findsOneWidget);
    });
  });

  testWidgets('each button reports its own action', (tester) async {
    final pressed = <String>[];
    await tester.pumpWidget(host(buildView(pressed: pressed)));

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();
    }

    await tap(find.byKey(tryAgainKey));
    await tap(find.text('Use a dive log in another folder'));
    await tap(find.text('Restore from a backup file'));
    await tap(find.text('Start a new dive log in this folder'));
    await tap(find.text('Close'));

    expect(pressed, [
      'tryAgain',
      'anotherFolder',
      'restore',
      'startNew',
      'close',
    ]);
  });

  testWidgets('while a route is running, no button answers, Close '
      'included: quitting mid-restore would strand a half-swapped file', (
    tester,
  ) async {
    final pressed = <String>[];
    await tester.pumpWidget(host(buildView(pressed: pressed, busy: true)));

    for (final finder in [
      find.byKey(tryAgainKey),
      find.text('Use a dive log in another folder'),
      find.text('Restore from a backup file'),
      find.text('Start a new dive log in this folder'),
      find.text('Close'),
    ]) {
      await tester.ensureVisible(finder);
      await tester.tap(finder, warnIfMissed: false);
      await tester.pump();
    }
    expect(pressed, isEmpty);
  });

  testWidgets('a restore in flight also holds the routes', (tester) async {
    final pressed = <String>[];
    await tester.pumpWidget(
      host(
        buildView(
          pressed: pressed,
          restoreStatus: StartupRestoreStatus.running,
        ),
      ),
    );

    for (final finder in [find.byKey(tryAgainKey), find.text('Close')]) {
      await tester.ensureVisible(finder);
      await tester.tap(finder, warnIfMissed: false);
      await tester.pump();
    }

    expect(pressed, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a restore that failed says so, with its error', (tester) async {
    await tester.pumpWidget(
      host(
        buildView(
          restoreStatus: StartupRestoreStatus.failed,
          restoreError: 'disk full',
        ),
      ),
    );

    expect(
      find.text(
        'The backup could not be restored. Your dive log has been left '
        'exactly as it was.',
      ),
      findsOneWidget,
    );
    expect(find.text('disk full'), findsOneWidget);
  });
}
