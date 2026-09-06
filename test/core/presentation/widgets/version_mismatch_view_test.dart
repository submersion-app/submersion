import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/presentation/startup_restore_status.dart';
import 'package:submersion/core/presentation/widgets/version_mismatch_view.dart';
import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget host(Widget child) => MaterialApp(
  // Pinned: flutter_test forwards the HOST machine's locale list, so an
  // unpinned MaterialApp resolves to a translated UI on a non-English dev
  // machine and every English assertion below finds nothing.
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  // Mirrors how StartupWrapper hosts this screen: centred, with no scroll
  // of its own. The view supplies its own scrolling.
  home: Scaffold(body: Center(child: child)),
);

VersionMismatchView buildView(
  UpdateChannel channel, {
  BackupRecord? restoreCandidate,
  VoidCallback? onRestoreBackup,
  StartupRestoreStatus restoreStatus = StartupRestoreStatus.idle,
  String? restoreError,
}) => VersionMismatchView(
  databaseVersion: 154,
  appVersion: 153,
  textColor: Colors.black,
  subtitleColor: Colors.black54,
  onDownloadLatest: () {},
  onClose: () {},
  channelOverride: channel,
  restoreCandidate: restoreCandidate,
  onRestoreBackup: onRestoreBackup,
  restoreStatus: restoreStatus,
  restoreError: restoreError,
);

BackupRecord candidate() => BackupRecord(
  id: 'b1',
  filename: '20260817-120000000-v141-v142.db',
  timestamp: DateTime.utc(2026, 8, 17, 12),
  sizeBytes: 2048,
  location: BackupLocation.local,
  localPath: '/backups/20260817-120000000-v141-v142.db',
  type: BackupType.preMigration,
  fromSchemaVersion: 141,
  toSchemaVersion: 142,
);

void main() {
  testWidgets('store channel hides the GitHub download affordances', (
    tester,
  ) async {
    await tester.pumpWidget(host(buildView(UpdateChannel.appstore)));

    // A store user cannot act on a GitHub link, so neither the button nor
    // the raw URL should be offered (issue #1089).
    expect(find.byType(FilledButton), findsNothing);
    expect(find.textContaining('github.com'), findsNothing);
    expect(find.textContaining('app store'), findsOneWidget);
  });

  testWidgets('github channel keeps the download button and URL', (
    tester,
  ) async {
    await tester.pumpWidget(host(buildView(UpdateChannel.github)));

    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text(VersionMismatchView.latestReleaseUrl), findsOneWidget);
  });

  testWidgets('no restore is offered when there is no usable copy', (
    tester,
  ) async {
    // A button that fails the same way the database just did would repeat
    // exactly the dead end this screen is being fixed for (issue #1589).
    await tester.pumpWidget(host(buildView(UpdateChannel.github)));

    expect(find.text('Restore this backup'), findsNothing);
    expect(find.textContaining('pre-upgrade backup'), findsNothing);
  });

  testWidgets('a usable copy is offered, named, and warns about the newer '
      'file', (tester) async {
    var restored = 0;
    await tester.pumpWidget(
      host(
        buildView(
          UpdateChannel.github,
          restoreCandidate: candidate(),
          onRestoreBackup: () => restored++,
        ),
      ),
    );

    expect(find.text('Restore your pre-upgrade backup'), findsOneWidget);
    // The schema pair, so the diver can see WHICH upgrade is being undone.
    expect(find.textContaining('v141'), findsOneWidget);
    expect(find.textContaining('only in the newer file'), findsOneWidget);

    await tester.ensureVisible(find.text('Restore this backup'));
    await tester.tap(find.text('Restore this backup'));
    expect(restored, 1);
  });

  testWidgets('a store build is still offered the restore', (tester) async {
    // A store install cannot act on a GitHub download link, which is exactly
    // why the local copy is the only route out for it.
    await tester.pumpWidget(
      host(
        buildView(
          UpdateChannel.appstore,
          restoreCandidate: candidate(),
          onRestoreBackup: () {},
        ),
      ),
    );

    expect(find.text('Restore this backup'), findsOneWidget);
    expect(find.textContaining('github.com'), findsNothing);
  });

  testWidgets('a running restore replaces the button with progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        buildView(
          UpdateChannel.github,
          restoreCandidate: candidate(),
          onRestoreBackup: () {},
          restoreStatus: StartupRestoreStatus.running,
        ),
      ),
    );

    expect(find.text('Restore this backup'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a failed restore keeps the diver here with the reason', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        buildView(
          UpdateChannel.github,
          restoreCandidate: candidate(),
          onRestoreBackup: () {},
          restoreStatus: StartupRestoreStatus.failed,
          restoreError: 'swap failed',
        ),
      ),
    );

    expect(find.textContaining('left exactly as it was'), findsOneWidget);
    expect(find.textContaining('swap failed'), findsOneWidget);
    expect(find.text('Restore this backup'), findsOneWidget);
  });
}
