import 'package:flutter/material.dart';

import 'package:submersion/core/presentation/startup_restore_status.dart';
import 'package:submersion/core/presentation/widgets/startup_restore_card.dart';
import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Startup screen shown when the database on disk was written by a newer
/// version of the app than the one running (schema `user_version` exceeds
/// [appVersion]). The database has not been opened or modified at this point;
/// the only safe paths forward are running a build that understands the file
/// or restoring an older backup.
///
/// The screen deliberately does not name a cause. A build at schema N seeing a
/// file at schema N+k cannot tell whether a newer *stable* release wrote it or
/// a *beta* build did: every version constant it ships was frozen when it was
/// compiled. Asserting "Update Required" guessed, and guessed wrong for the
/// common case, sending the #1568 reporter to reinstall the same build twice
/// (#1588). Both destinations are therefore offered, with the causes stated
/// plainly so the diver can pick the one that matches their situation.
///
/// A third route appears when a pre-upgrade safety copy this build can open
/// is found on disk: [restoreCandidate] (#1589). It is listed first because
/// it is the only one that works without leaving the app, and on a store
/// build, where an update may still be in review, the only one that works at
/// all. It does NOT displace the stable download as the primary button: which
/// route is right depends on facts this build does not have, and asserting
/// "you want to go back" would be the same guess in the other direction.
///
/// The restore is offered only when a candidate has been found AND validated
/// by the caller. An offer that fails the same way the database just did
/// would repeat the dead end this screen exists to end.
class VersionMismatchView extends StatelessWidget {
  const VersionMismatchView({
    super.key,
    required this.databaseVersion,
    required this.appVersion,
    required this.textColor,
    required this.subtitleColor,
    required this.onDownloadLatest,
    required this.onOpenBetaBuilds,
    required this.onClose,
    this.channelOverride,
    this.restoreCandidate,
    this.onRestoreBackup,
    this.restoreStatus = StartupRestoreStatus.idle,
    this.restoreError,
  });

  /// Canonical download location, shown on screen and opened by the button.
  ///
  /// Deliberately owned here rather than passed in: the view renders this exact
  /// string as the manual fallback, and the caller launches the same constant,
  /// so the displayed address and the opened address cannot drift apart.
  static const String latestReleaseUrl =
      'https://github.com/submersion-app/submersion/releases/latest';

  /// Where the per-merge beta builds live. Deliberately the releases index
  /// rather than `/latest`: the diver needs the build that matches their
  /// file's schema, which is not necessarily the newest one.
  ///
  /// Owned here for the same no-drift reason as [latestReleaseUrl].
  static const String betaReleasesUrl =
      'https://github.com/submersion-app/beta-builds/releases';

  final int databaseVersion;
  final int appVersion;
  final Color textColor;
  final Color subtitleColor;

  /// Opens [latestReleaseUrl]. Kept the primary action: a newer stable may
  /// genuinely exist, and it is the destination that cannot make things worse.
  final VoidCallback onDownloadLatest;

  /// Opens [betaReleasesUrl]. Secondary and captioned as pre-release on
  /// purpose. An unguarded route onto beta is what stranded the #1568
  /// reporter, so this screen must not become a second one.
  final VoidCallback onOpenBetaBuilds;

  final VoidCallback onClose;

  /// Test seam: UpdateChannelConfig.current reads a compile-time constant,
  /// which a test binary cannot vary.
  final UpdateChannel? channelOverride;

  /// A pre-upgrade safety copy this build can open, or null when the registry
  /// holds none (never taken, already pruned, or every surviving copy is
  /// itself too new). Null hides the whole restore route rather than showing
  /// a button that cannot work.
  final BackupRecord? restoreCandidate;

  final VoidCallback? onRestoreBackup;
  final StartupRestoreStatus restoreStatus;
  final String? restoreError;

  @override
  Widget build(BuildContext context) {
    // A store build cannot act on a GitHub download link, and its update
    // arrives on the store's schedule (possibly still in review), so it gets
    // a different instruction and no download affordances (issue #1089).
    final channel = channelOverride ?? UpdateChannelConfig.current;
    final isStore = UpdateChannelConfig.isStoreChannel(channel);
    final canRestore = restoreCandidate != null && onRestoreBackup != null;

    final bodyStyle = TextStyle(fontSize: 14, color: subtitleColor);
    final captionStyle = TextStyle(fontSize: 12, color: subtitleColor);

    // Scrolls itself, exactly as StartupFailureView does. StartupWrapper hosts
    // the terminal screens in a bare SafeArea > Center, so a short window or a
    // large text scale would otherwise clip the copy below the fold, hiding
    // the very links this screen exists to offer.
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Not Icons.update: that glyph is the visual half of the "you are
            // behind, install the update" claim this screen no longer makes.
            const Icon(Icons.sync_problem, size: 64, color: Colors.orange),
            const SizedBox(height: 24),
            Text(
              context.l10n.startup_versionMismatch_title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.startup_versionMismatch_body(
                databaseVersion,
                appVersion,
              ),
              style: bodyStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Shown on every channel: TestFlight and Play testing tracks are
            // beta channels too, so a store build can land here the same way.
            Text(
              context.l10n.startup_versionMismatch_causes,
              style: bodyStyle,
              textAlign: TextAlign.center,
            ),
            if (canRestore) ...[
              const SizedBox(height: 24),
              StartupRestoreCard(
                record: restoreCandidate!,
                title: context.l10n.startup_versionMismatch_restore_title,
                body: context.l10n.startup_versionMismatch_restore_body,
                warning: context.l10n.startup_versionMismatch_restore_warning,
                actionLabel: context.l10n.startup_failure_restoreAction,
                onRestore: onRestoreBackup!,
                status: restoreStatus,
                error: restoreError,
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              isStore
                  ? context.l10n.startup_versionMismatch_storeInstructions
                  : context.l10n.startup_versionMismatch_instructions,
              style: bodyStyle,
              textAlign: TextAlign.center,
            ),
            if (!isStore) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onDownloadLatest,
                child: Text(context.l10n.startup_versionMismatch_download),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onOpenBetaBuilds,
                child: Text(context.l10n.startup_versionMismatch_betaAction),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.startup_versionMismatch_betaNote,
                style: captionStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.startup_versionMismatch_manualLink,
                style: captionStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              SelectableText(
                latestReleaseUrl,
                style: captionStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              SelectableText(
                betaReleasesUrl,
                style: captionStyle,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: onClose,
              child: Text(context.l10n.common_action_close),
            ),
          ],
        ),
      ),
    );
  }
}
