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

  /// Widest measure the prose and the card may take, including the outer
  /// padding. About 75 characters at body size: this screen is hosted in a
  /// bare Center with no width limit of its own, so on a desktop window the
  /// copy used to run 150 characters per line, which is what made it hard
  /// to read no matter how few words it had.
  static const double maxContentWidth = 520;

  @override
  Widget build(BuildContext context) {
    // A store build cannot act on a GitHub download link, and its update
    // arrives on the store's schedule (possibly still in review), so it gets
    // a different instruction and no download affordances (issue #1089).
    final channel = channelOverride ?? UpdateChannelConfig.current;
    final isStore = UpdateChannelConfig.isStoreChannel(channel);
    final canRestore = restoreCandidate != null && onRestoreBackup != null;
    final l10n = context.l10n;

    final bodyStyle = TextStyle(
      fontSize: 14,
      height: 1.4,
      color: subtitleColor,
    );
    final captionStyle = TextStyle(fontSize: 12, color: subtitleColor);

    // Scrolls itself, exactly as StartupFailureView does. StartupWrapper hosts
    // the terminal screens in a bare SafeArea > Center, so a short window or a
    // large text scale would otherwise clip the copy below the fold, hiding
    // the very links this screen exists to offer.
    //
    // Prose is left-aligned inside the capped column; only the icon, title,
    // buttons and Close stay centred. Centred multi-line paragraphs give the
    // eye no fixed left edge to return to, which compounds the long-line
    // problem the width cap solves.
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Not Icons.update: that glyph is the visual half of the "you
                // are behind, install the update" claim this screen no longer
                // makes.
                const Icon(Icons.sync_problem, size: 56, color: Colors.orange),
                const SizedBox(height: 20),
                Text(
                  l10n.startup_versionMismatch_title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.startup_versionMismatch_body(
                    databaseVersion,
                    appVersion,
                  ),
                  style: bodyStyle,
                ),
                const SizedBox(height: 16),
                // Shown on every channel: TestFlight and Play testing tracks
                // are beta channels too, so a store build can land here the
                // same way.
                Text(
                  l10n.startup_versionMismatch_causes_lead,
                  style: bodyStyle,
                ),
                const SizedBox(height: 4),
                _Cause(
                  l10n.startup_versionMismatch_cause_beta,
                  style: bodyStyle,
                ),
                _Cause(
                  l10n.startup_versionMismatch_cause_restored,
                  style: bodyStyle,
                ),
                _Cause(
                  l10n.startup_versionMismatch_cause_shared,
                  style: bodyStyle,
                ),
                const SizedBox(height: 16),
                Text(
                  isStore
                      ? l10n.startup_versionMismatch_storeInstructions
                      : l10n.startup_versionMismatch_instructions,
                  style: bodyStyle,
                ),
                if (canRestore) ...[
                  const SizedBox(height: 16),
                  StartupRestoreCard(
                    record: restoreCandidate!,
                    title: l10n.startup_versionMismatch_restore_title,
                    warning: l10n.startup_versionMismatch_restore_warning,
                    actionLabel: l10n.startup_failure_restoreAction,
                    onRestore: onRestoreBackup!,
                    status: restoreStatus,
                    error: restoreError,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                  ),
                ],
                if (!isStore) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: FilledButton(
                      onPressed: onDownloadLatest,
                      child: Text(l10n.startup_versionMismatch_download),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: OutlinedButton(
                      onPressed: onOpenBetaBuilds,
                      child: Text(l10n.startup_versionMismatch_betaAction),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.startup_versionMismatch_betaNote,
                    style: captionStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.startup_versionMismatch_manualLink,
                    style: captionStyle,
                  ),
                  const SizedBox(height: 2),
                  SelectableText(latestReleaseUrl, style: captionStyle),
                  SelectableText(betaReleasesUrl, style: captionStyle),
                ],
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: onClose,
                    child: Text(l10n.common_action_close),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the likely causes, as a bulleted line. A list scans in a glance
/// where the same three causes as a sentence did not.
class _Cause extends StatelessWidget {
  const _Cause(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('\u2022', style: style),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
