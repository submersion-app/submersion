import 'package:flutter/material.dart';

import 'package:submersion/core/presentation/startup_restore_status.dart';
import 'package:submersion/core/presentation/widgets/startup_restore_card.dart';
import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Startup screen shown when the database on disk was written by a newer
/// version of the app than the one running (schema `user_version` exceeds
/// [appVersion]). The database has not been opened or modified at this point.
///
/// Two ways forward, and which one is primary depends on what is on disk:
///
/// - Update the app, which is the only route when the newer database is the
///   one the diver wants to keep.
/// - Restore the safety copy taken before that upgrade, offered as
///   [restoreCandidate] when one exists that THIS build can open. It is the
///   primary action when present, because it is the only one that works
///   without leaving the app -- and on a store build, where an update may
///   still be in review, the only one that works at all (issue #1589).
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

  final int databaseVersion;
  final int appVersion;
  final Color textColor;
  final Color subtitleColor;
  final VoidCallback onDownloadLatest;
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

    // Scrollable like StartupFailureView, and for the same reason: the host
    // centres this content without a scroll of its own, and the restore card
    // makes the screen tall enough to overflow a short window.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.update, size: 64, color: Colors.orange),
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
            style: TextStyle(fontSize: 14, color: subtitleColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            isStore
                ? context.l10n.startup_versionMismatch_storeInstructions
                : context.l10n.startup_versionMismatch_instructions,
            style: TextStyle(fontSize: 14, color: subtitleColor),
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
          if (!isStore) ...[
            const SizedBox(height: 24),
            // Demoted to an outlined button when a restore is on offer: the
            // two are alternatives, and only one of them can be primary.
            if (canRestore)
              OutlinedButton(
                onPressed: onDownloadLatest,
                child: Text(context.l10n.startup_versionMismatch_download),
              )
            else
              FilledButton(
                onPressed: onDownloadLatest,
                child: Text(context.l10n.startup_versionMismatch_download),
              ),
            const SizedBox(height: 12),
            Text(
              context.l10n.startup_versionMismatch_manualLink,
              style: TextStyle(fontSize: 12, color: subtitleColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            SelectableText(
              latestReleaseUrl,
              style: TextStyle(fontSize: 12, color: subtitleColor),
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
    );
  }
}
