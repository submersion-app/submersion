import 'package:flutter/material.dart';

import 'package:submersion/core/presentation/startup_failure.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How far the in-place restore offered by [StartupFailureView] has got.
enum StartupRestoreStatus { idle, running, failed }

/// The terminal startup failure screen.
///
/// Replaces a single fixed "Database upgrade failed" panel with one that says
/// which *class* of failure happened (see [StartupFailureKind]) and, where the
/// database really was involved, offers a way out instead of only a Close
/// button.
///
/// The recovery routes are gated on [StartupFailureKind.dataIsAtRisk], so a
/// class that provably did not write to the file shows no restore card and no
/// downgrade section. That gating is the point rather than a detail: offering
/// a restore after a lock would invite a diver to overwrite an intact
/// database with an older backup to fix a problem that a relaunch fixes.
///
/// ## Why there is no automatic downgrade
///
/// The guided-downgrade section links to the releases page and explains the
/// manual steps. It deliberately never performs the downgrade, and that is a
/// standing decision rather than an unfinished feature:
///
/// - iOS and Android offer no way to install an older build over a newer one,
///   so an automatic downgrade could only ever be a desktop half-feature.
/// - A supported mechanism that silently moves divers onto older builds is a
///   security liability sitting next to a Sparkle/WinSparkle appcast feed: a
///   maintained path back to known-vulnerable versions.
/// - It would have concealed issue #1129. A Windows build shipped without
///   `sqlcipher.dll`; a silent downgrade would have meant no bug report and a
///   packaging regression reaching every Windows diver for as long as it went
///   unnoticed. The loud failure is what got it diagnosed and fixed the same
///   day.
/// - Once a migration commits, the older app cannot open the newer file, so a
///   downgrade needs a database restore anyway, and the existing restore UI
///   explains that trade-off better than a silent action could.
class StartupFailureView extends StatelessWidget {
  const StartupFailureView({
    super.key,
    required this.kind,
    required this.details,
    required this.textColor,
    required this.subtitleColor,
    required this.onClose,
    this.recoveryBackup,
    this.onRestoreBackup,
    this.restoreStatus = StartupRestoreStatus.idle,
    this.restoreError,
    this.backupsDirectory,
    this.onShowBackupsFolder,
    this.onViewPreviousReleases,
  });

  /// Where the diver can pick an earlier build. Deliberately the releases
  /// index, not `/latest`. The version-mismatch screen owns "get the newest
  /// one"; this screen's question is "which one was I on before?".
  ///
  /// Owned here so the address rendered as the manual fallback and the address
  /// the button opens cannot drift apart, matching
  /// `VersionMismatchView.latestReleaseUrl`.
  static const String previousReleasesUrl =
      'https://github.com/submersion-app/submersion/releases';

  final StartupFailureKind kind;

  /// Raw error text, shown under a "technical details" label. May be empty.
  final String details;

  final Color textColor;
  final Color subtitleColor;
  final VoidCallback onClose;

  /// A backup found on disk that the diver could swap in, or null when there
  /// is none. Ignored for [StartupFailureKind.engineUnavailable]: no restore
  /// can fix a build that cannot open a database in the first place.
  final BackupRecord? recoveryBackup;

  final VoidCallback? onRestoreBackup;
  final StartupRestoreStatus restoreStatus;
  final String? restoreError;

  /// Filesystem path where backups are kept, shown so the diver can reach
  /// them by hand. The startup screen runs before the router and the database,
  /// so backup *settings* are genuinely unreachable from here; the path plus
  /// [onShowBackupsFolder] is what can honestly be offered instead.
  final String? backupsDirectory;

  /// Opens [backupsDirectory] in the system file manager. Null on platforms
  /// with no such concept.
  final VoidCallback? onShowBackupsFolder;

  /// Opens [previousReleasesUrl]. Only surfaced for a failed migration, the
  /// one class where an older app genuinely is an answer.
  final VoidCallback? onViewPreviousReleases;

  bool get _canRestore =>
      kind.dataIsAtRisk && recoveryBackup != null && onRestoreBackup != null;

  bool get _canDowngrade =>
      kind == StartupFailureKind.migrationFailed &&
      onViewPreviousReleases != null;

  ({IconData icon, Color color}) get _badge => switch (kind) {
    // Orange, not red: an engine failure never touched the diver's data.
    StartupFailureKind.engineUnavailable => (
      icon: Icons.extension_off_outlined,
      color: Colors.orange,
    ),
    StartupFailureKind.dataUnreadable => (
      icon: Icons.broken_image_outlined,
      color: Colors.red,
    ),
    // Orange, like the engine failure and for the same reason: a lock means
    // the database was never written to.
    StartupFailureKind.databaseBusy => (
      icon: Icons.lock_clock,
      color: Colors.orange,
    ),
    StartupFailureKind.migrationFailed || StartupFailureKind.unknown => (
      icon: Icons.error_outline,
      color: Colors.red,
    ),
  };

  String _title(BuildContext context) => switch (kind) {
    StartupFailureKind.engineUnavailable =>
      context.l10n.startup_engineUnavailable_title,
    StartupFailureKind.migrationFailed =>
      context.l10n.startup_migrationFailed_title,
    StartupFailureKind.dataUnreadable =>
      context.l10n.startup_dataUnreadable_title,
    StartupFailureKind.databaseBusy => context.l10n.startup_databaseBusy_title,
    StartupFailureKind.unknown => context.l10n.startup_error_title,
  };

  String _body(BuildContext context) => switch (kind) {
    StartupFailureKind.engineUnavailable =>
      context.l10n.startup_engineUnavailable_body,
    StartupFailureKind.migrationFailed =>
      context.l10n.startup_migrationFailed_body,
    StartupFailureKind.dataUnreadable =>
      context.l10n.startup_dataUnreadable_body,
    StartupFailureKind.databaseBusy => context.l10n.startup_databaseBusy_body,
    StartupFailureKind.unknown => context.l10n.startup_error_body,
  };

  @override
  Widget build(BuildContext context) {
    final badge = _badge;
    final bodyStyle = TextStyle(fontSize: 14, color: subtitleColor);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badge.icon, size: 64, color: badge.color),
          const SizedBox(height: 24),
          Text(
            _title(context),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(_body(context), style: bodyStyle, textAlign: TextAlign.center),
          if (kind == StartupFailureKind.engineUnavailable) ...[
            const SizedBox(height: 12),
            Text(
              context.l10n.startup_engineUnavailable_guidance,
              style: bodyStyle,
              textAlign: TextAlign.center,
            ),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              context.l10n.startup_failure_technicalDetails,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              details,
              style: TextStyle(
                fontSize: 12,
                color: subtitleColor,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (_canRestore) ...[
            const SizedBox(height: 24),
            _RecoveryBackupCard(
              record: recoveryBackup!,
              onRestore: onRestoreBackup!,
              status: restoreStatus,
              error: restoreError,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
          ],
          if (backupsDirectory != null) ...[
            const SizedBox(height: 20),
            Text(
              context.l10n.startup_failure_backupsFolder,
              style: TextStyle(fontSize: 12, color: subtitleColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            SelectableText(
              backupsDirectory!,
              style: TextStyle(
                fontSize: 12,
                color: subtitleColor,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
            if (onShowBackupsFolder != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onShowBackupsFolder,
                icon: const Icon(Icons.folder_open, size: 18),
                label: Text(context.l10n.startup_failure_showBackupsFolder),
              ),
            ],
          ],
          if (_canDowngrade) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              context.l10n.startup_failure_downgrade_title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.startup_failure_downgrade_body,
              style: bodyStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onViewPreviousReleases,
              child: Text(context.l10n.startup_failure_downgrade_action),
            ),
            const SizedBox(height: 8),
            // The same manual fallback VersionMismatchView offers: if the
            // button cannot reach a browser, the address is still readable.
            SelectableText(
              previousReleasesUrl,
              style: TextStyle(fontSize: 12, color: subtitleColor),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onClose,
            child: Text(context.l10n.common_action_close),
          ),
        ],
      ),
    );
  }
}

/// The offered backup, with whatever the restore attempt is currently doing.
class _RecoveryBackupCard extends StatelessWidget {
  const _RecoveryBackupCard({
    required this.record,
    required this.onRestore,
    required this.status,
    required this.error,
    required this.textColor,
    required this.subtitleColor,
  });

  final BackupRecord record;
  final VoidCallback onRestore;
  final StartupRestoreStatus status;
  final String? error;
  final Color textColor;
  final Color subtitleColor;

  /// Formatted through [MaterialLocalizations] rather than `intl` directly:
  /// this screen renders before the diver's saved locale is readable, so the
  /// only sensible source of formatting is the resolved system locale that
  /// the splash [MaterialApp] already carries.
  String _taken(BuildContext context) {
    final local = record.timestamp.toLocal();
    final l = MaterialLocalizations.of(context);
    final date = l.formatMediumDate(local);
    final time = l.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date $time';
  }

  @override
  Widget build(BuildContext context) {
    final captionStyle = TextStyle(fontSize: 12, color: subtitleColor);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.startup_failure_backupAvailable_title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.startup_failure_backupAvailable_taken(
                _taken(context),
              ),
              style: captionStyle,
              textAlign: TextAlign.center,
            ),
            if (record.type == BackupType.preMigration &&
                record.fromSchemaVersion != null &&
                record.toSchemaVersion != null) ...[
              const SizedBox(height: 4),
              Text(
                context.l10n.startup_failure_backupAvailable_preMigration(
                  record.fromSchemaVersion!,
                  record.toSchemaVersion!,
                ),
                style: captionStyle,
                textAlign: TextAlign.center,
              ),
            ],
            if (status == StartupRestoreStatus.failed) ...[
              const SizedBox(height: 12),
              Text(
                context.l10n.startup_failure_restoreFailed,
                style: captionStyle,
                textAlign: TextAlign.center,
              ),
              if (error != null && error!.isNotEmpty) ...[
                const SizedBox(height: 4),
                SelectableText(
                  error!,
                  style: TextStyle(
                    fontSize: 12,
                    color: subtitleColor,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
            const SizedBox(height: 16),
            if (status == StartupRestoreStatus.running)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.startup_failure_restoring,
                    style: captionStyle,
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            else
              FilledButton.tonal(
                onPressed: onRestore,
                child: Text(context.l10n.startup_failure_restoreAction),
              ),
          ],
        ),
      ),
    );
  }
}
