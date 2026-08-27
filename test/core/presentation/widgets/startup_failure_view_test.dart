import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/presentation/startup_failure.dart';
import 'package:submersion/core/presentation/widgets/startup_failure_view.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

BackupRecord _preMigrationRecord({
  DateTime? timestamp,
  int fromSchemaVersion = 141,
  int toSchemaVersion = 142,
}) {
  return BackupRecord(
    id: 'rec-1',
    filename: '20260817-120000000-v141-v142.db',
    timestamp: timestamp ?? DateTime.utc(2026, 8, 17, 12),
    sizeBytes: 4 * 1024 * 1024,
    location: BackupLocation.local,
    localPath: '/backups/20260817-120000000-v141-v142.db',
    isAutomatic: true,
    type: BackupType.preMigration,
    fromSchemaVersion: fromSchemaVersion,
    toSchemaVersion: toSchemaVersion,
  );
}

Widget _host({
  required StartupFailureKind kind,
  String details = '',
  BackupRecord? recoveryBackup,
  VoidCallback? onRestoreBackup,
  StartupRestoreStatus restoreStatus = StartupRestoreStatus.idle,
  String? restoreError,
  String? backupsDirectory,
  VoidCallback? onShowBackupsFolder,
  VoidCallback? onViewPreviousReleases,
  VoidCallback? onClose,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      body: StartupFailureView(
        kind: kind,
        details: details,
        textColor: Colors.black87,
        subtitleColor: Colors.black54,
        recoveryBackup: recoveryBackup,
        onRestoreBackup: onRestoreBackup,
        restoreStatus: restoreStatus,
        restoreError: restoreError,
        backupsDirectory: backupsDirectory,
        onShowBackupsFolder: onShowBackupsFolder,
        onViewPreviousReleases: onViewPreviousReleases,
        onClose: onClose ?? () {},
      ),
    ),
  );
}

void main() {
  group('titles are class-specific', () {
    testWidgets('an engine failure does not claim the upgrade failed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(kind: StartupFailureKind.engineUnavailable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Database upgrade failed'), findsNothing);
      expect(find.textContaining("build can't open"), findsOneWidget);
    });

    testWidgets('only the migration class says the upgrade failed', (
      tester,
    ) async {
      await tester.pumpWidget(_host(kind: StartupFailureKind.migrationFailed));
      await tester.pumpAndSettle();

      expect(find.text('Database upgrade failed'), findsOneWidget);
    });

    testWidgets('unreadable data gets its own title', (tester) async {
      await tester.pumpWidget(_host(kind: StartupFailureKind.dataUnreadable));
      await tester.pumpAndSettle();

      expect(find.text('Database upgrade failed'), findsNothing);
      expect(find.textContaining('could not be read'), findsOneWidget);
    });

    testWidgets('a locked database does not claim the upgrade failed', (
      tester,
    ) async {
      await tester.pumpWidget(_host(kind: StartupFailureKind.databaseBusy));
      await tester.pumpAndSettle();

      expect(find.text('Database upgrade failed'), findsNothing);
      expect(find.textContaining('was busy'), findsOneWidget);
    });

    testWidgets('an unclassified failure gets a neutral title', (tester) async {
      await tester.pumpWidget(_host(kind: StartupFailureKind.unknown));
      await tester.pumpAndSettle();

      expect(find.text('Database upgrade failed'), findsNothing);
      expect(find.text('Submersion could not start'), findsOneWidget);
    });
  });

  group('the data-at-risk answer differs by class', () {
    testWidgets('an engine failure says the database was never opened', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(kind: StartupFailureKind.engineUnavailable),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('never opened'), findsOneWidget);
      expect(find.textContaining('no data is at risk'), findsOneWidget);
    });

    testWidgets('an engine failure says a restore cannot help', (tester) async {
      await tester.pumpWidget(
        _host(kind: StartupFailureKind.engineUnavailable),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('will not help'), findsOneWidget);
    });

    testWidgets('an engine failure never offers a restore, even when a '
        'backup was passed in', (tester) async {
      // Defence in depth: the wrapper does not wire the restore for this
      // class, and the view refuses it too. Restoring cannot fix a build.
      await tester.pumpWidget(
        _host(
          kind: StartupFailureKind.engineUnavailable,
          recoveryBackup: _preMigrationRecord(),
          onRestoreBackup: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Restore this backup'), findsNothing);
    });
  });

  group('a lock offers no destructive way out', () {
    testWidgets('never offers a restore, even when a backup was passed in', (
      tester,
    ) async {
      // The whole reason this class exists. SQLITE_BUSY means the write never
      // started, so the database on disk is intact and NEWER than any backup.
      // Offering a restore here asks the diver to throw away good dives to
      // fix a problem that relaunching fixes.
      await tester.pumpWidget(
        _host(
          kind: StartupFailureKind.databaseBusy,
          recoveryBackup: _preMigrationRecord(),
          onRestoreBackup: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Restore this backup'), findsNothing);
    });

    testWidgets('never offers a downgrade', (tester) async {
      // An older build cannot help either: nothing about the schema failed.
      await tester.pumpWidget(
        _host(
          kind: StartupFailureKind.databaseBusy,
          onViewPreviousReleases: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(StartupFailureView.previousReleasesUrl), findsNothing);
    });

    testWidgets('says nothing was changed and gives the one fix', (
      tester,
    ) async {
      await tester.pumpWidget(_host(kind: StartupFailureKind.databaseBusy));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing was changed'), findsOneWidget);
      expect(find.textContaining('open it again'), findsOneWidget);
    });
  });

  group('technical details', () {
    testWidgets('are shown when present', (tester) async {
      await tester.pumpWidget(
        _host(
          kind: StartupFailureKind.unknown,
          details: "Invalid argument(s): Couldn't resolve native function",
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining("Couldn't resolve native function"),
        findsOneWidget,
      );
    });

    testWidgets('are omitted when empty', (tester) async {
      await tester.pumpWidget(_host(kind: StartupFailureKind.unknown));
      await tester.pumpAndSettle();

      expect(find.byType(SelectableText), findsNothing);
    });
  });

  group('backup recovery route', () {
    testWidgets('surfaces the backup and its schema span', (tester) async {
      await tester.pumpWidget(
        _host(
          kind: StartupFailureKind.migrationFailed,
          recoveryBackup: _preMigrationRecord(),
          onRestoreBackup: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Restore this backup'), findsOneWidget);
      expect(find.textContaining('v141'), findsOneWidget);
      expect(find.textContaining('v142'), findsOneWidget);
    });

    testWidgets('restore button invokes the callback', (tester) async {
      var restored = false;
      await tester.pumpWidget(
        _host(
          kind: StartupFailureKind.dataUnreadable,
          recoveryBackup: _preMigrationRecord(),
          onRestoreBackup: () => restored = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore this backup'));
      expect(restored, isTrue);
    });

    testWidgets('a running restore shows progress instead of the button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          kind: StartupFailureKind.migrationFailed,
          recoveryBackup: _preMigrationRecord(),
          onRestoreBackup: () {},
          restoreStatus: StartupRestoreStatus.running,
        ),
      );
      await tester.pump();

      expect(find.text('Restore this backup'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('a failed restore says the live database was left alone', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          kind: StartupFailureKind.migrationFailed,
          recoveryBackup: _preMigrationRecord(),
          onRestoreBackup: () {},
          restoreStatus: StartupRestoreStatus.failed,
          restoreError: 'disk full',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('left exactly as it was'), findsOneWidget);
      expect(find.textContaining('disk full'), findsOneWidget);
      // Still retryable.
      expect(find.text('Restore this backup'), findsOneWidget);
    });

    testWidgets('nothing is offered when there is no backup', (tester) async {
      await tester.pumpWidget(_host(kind: StartupFailureKind.migrationFailed));
      await tester.pumpAndSettle();

      expect(find.text('Restore this backup'), findsNothing);
    });
  });

  group('backups folder route', () {
    testWidgets('shows the folder path', (tester) async {
      await tester.pumpWidget(
        _host(
          kind: StartupFailureKind.migrationFailed,
          backupsDirectory: '/Users/diver/Documents/Submersion/Backups',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('/Users/diver/Documents/Submersion/Backups'),
        findsOneWidget,
      );
    });

    testWidgets('the reveal action is only offered when wired', (tester) async {
      await tester.pumpWidget(
        _host(
          kind: StartupFailureKind.migrationFailed,
          backupsDirectory: '/backups',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Show backup folder'), findsNothing);
    });

    testWidgets('the reveal action invokes its callback', (tester) async {
      var shown = false;
      await tester.pumpWidget(
        _host(
          kind: StartupFailureKind.migrationFailed,
          backupsDirectory: '/backups',
          onShowBackupsFolder: () => shown = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show backup folder'));
      expect(shown, isTrue);
    });
  });

  group('guided downgrade', () {
    testWidgets('is offered for a failed migration', (tester) async {
      await tester.pumpWidget(
        _host(
          kind: StartupFailureKind.migrationFailed,
          onViewPreviousReleases: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('View previous releases'), findsOneWidget);
      expect(find.textContaining('does not downgrade itself'), findsOneWidget);
      expect(
        find.textContaining(StartupFailureView.previousReleasesUrl),
        findsOneWidget,
      );
    });

    testWidgets('invokes its callback', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        _host(
          kind: StartupFailureKind.migrationFailed,
          onViewPreviousReleases: () => opened = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('View previous releases'));
      expect(opened, isTrue);
    });

    testWidgets('is not offered for an engine failure, where an older app '
        'is not the answer', (tester) async {
      await tester.pumpWidget(
        _host(
          kind: StartupFailureKind.engineUnavailable,
          onViewPreviousReleases: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('View previous releases'), findsNothing);
    });
  });

  testWidgets('close is always available', (tester) async {
    for (final kind in StartupFailureKind.values) {
      var closed = false;
      await tester.pumpWidget(_host(kind: kind, onClose: () => closed = true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Close'));
      expect(closed, isTrue, reason: 'close must work for $kind');
    }
  });

  testWidgets('the screen scrolls so no route is unreachable on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        kind: StartupFailureKind.migrationFailed,
        details: 'a very long technical detail line',
        recoveryBackup: _preMigrationRecord(),
        onRestoreBackup: () {},
        backupsDirectory: '/backups',
        onShowBackupsFolder: () {},
        onViewPreviousReleases: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
