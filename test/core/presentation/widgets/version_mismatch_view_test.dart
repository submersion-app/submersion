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
  // Mirrors StartupWrapper's terminal-screen host exactly: a bare
  // SafeArea > Center with no scrollable of its own. The view has to
  // survive that on its own, or the links overflow off the bottom.
  home: Scaffold(
    body: SafeArea(child: Center(child: child)),
  ),
);

VersionMismatchView buildView(
  UpdateChannel channel, {
  VoidCallback? onDownloadLatest,
  VoidCallback? onOpenBetaBuilds,
  BackupRecord? restoreCandidate,
  VoidCallback? onRestoreBackup,
  StartupRestoreStatus restoreStatus = StartupRestoreStatus.idle,
  String? restoreError,
}) => VersionMismatchView(
  databaseVersion: 154,
  appVersion: 153,
  textColor: Colors.black,
  subtitleColor: Colors.black54,
  onDownloadLatest: onDownloadLatest ?? () {},
  onOpenBetaBuilds: onOpenBetaBuilds ?? () {},
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
    expect(find.byType(OutlinedButton), findsNothing);
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

  testWidgets('does not claim an update is required (issue #1588)', (
    tester,
  ) async {
    await tester.pumpWidget(host(buildView(UpdateChannel.github)));

    // The screen fires most often because a BETA build upgraded the file, in
    // which case no stable update exists to install. Titling it "Update
    // Required" sent the #1568 reporter to reinstall the same build twice.
    expect(find.text('Update Required'), findsNothing);
    expect(find.text('Your Data Is Newer Than This App'), findsOneWidget);
  });

  testWidgets('names the realistic causes rather than assuming staleness', (
    tester,
  ) async {
    await tester.pumpWidget(host(buildView(UpdateChannel.github)));

    expect(find.textContaining('beta build'), findsWidgets);
    expect(find.textContaining('restored'), findsWidgets);
  });

  testWidgets('offers the beta-builds page alongside the stable link', (
    tester,
  ) async {
    await tester.pumpWidget(host(buildView(UpdateChannel.github)));

    // Alongside, not instead of: a newer stable genuinely may exist, and this
    // build has no way to tell which case it is in.
    expect(find.text(VersionMismatchView.latestReleaseUrl), findsOneWidget);
    expect(find.text(VersionMismatchView.betaReleasesUrl), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  testWidgets('the beta action invokes its own callback', (tester) async {
    var betaOpened = false;
    var stableOpened = false;
    await tester.pumpWidget(
      host(
        buildView(
          UpdateChannel.github,
          onDownloadLatest: () => stableOpened = true,
          onOpenBetaBuilds: () => betaOpened = true,
        ),
      ),
    );

    await tester.tap(find.byType(OutlinedButton));
    expect(betaOpened, isTrue);
    expect(stableOpened, isFalse);
  });

  testWidgets('warns that beta builds are pre-release', (tester) async {
    await tester.pumpWidget(host(buildView(UpdateChannel.github)));

    // This screen must not become a second unguarded door onto beta: that
    // unguarded door is what produced #1568 in the first place.
    expect(find.textContaining('pre-release'), findsOneWidget);
  });

  testWidgets('the stable action stays the primary button', (tester) async {
    var stableOpened = false;
    await tester.pumpWidget(
      host(
        buildView(
          UpdateChannel.github,
          onDownloadLatest: () => stableOpened = true,
        ),
      ),
    );

    await tester.tap(find.byType(FilledButton));
    expect(stableOpened, isTrue);
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

  testWidgets('the restore does not displace the stable download as the '
      'primary button', (tester) async {
    // Which route is right depends on facts this build does not have (#1588).
    // Promoting the restore would assert "you want to go back" -- the same
    // guess as "Update Required", pointed the other way.
    var stableOpened = false;
    var betaOpened = false;
    await tester.pumpWidget(
      host(
        buildView(
          UpdateChannel.github,
          onDownloadLatest: () => stableOpened = true,
          onOpenBetaBuilds: () => betaOpened = true,
          restoreCandidate: candidate(),
          onRestoreBackup: () {},
        ),
      ),
    );

    // Targeted by label, not by type: the card's action is a
    // FilledButton.tonal, which IS a FilledButton. That is the point rather
    // than an inconvenience -- tonal renders at lower emphasis than the
    // filled stable button, so the three routes read as
    // stable > restore > beta.
    await tester.ensureVisible(find.text('Check for a Newer Stable Release'));
    await tester.tap(find.text('Check for a Newer Stable Release'));
    expect(stableOpened, isTrue);
    expect(betaOpened, isFalse);
    // Beta stays the single outlined action; the restore lives in its card.
    expect(find.byType(OutlinedButton), findsOneWidget);
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
