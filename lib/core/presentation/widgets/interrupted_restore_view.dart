import 'package:flutter/material.dart';

import 'package:submersion/core/presentation/startup_restore_status.dart';
import 'package:submersion/core/services/restore_journal.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Startup screen shown when an earlier restore stopped with the diver's
/// previous database still aside (issue #1901).
///
/// Shown BEFORE anything is opened: a missing live file would otherwise be
/// created fresh and empty, and a rejected one would route to the
/// version-mismatch screen, neither of which describes what happened.
///
/// Recovery is the primary action because the aside copy is the database
/// the diver was using before the restore. Keeping what is there now is
/// offered only when something is there; with an empty live path it would
/// mean an empty library. Neither action deletes a database file.
class InterruptedRestoreView extends StatelessWidget {
  const InterruptedRestoreView({
    super.key,
    required this.interrupted,
    required this.textColor,
    required this.subtitleColor,
    required this.onRecover,
    required this.onKeepCurrent,
    required this.onClose,
    this.status = StartupRestoreStatus.idle,
    this.error,
  });

  final InterruptedRestore interrupted;
  final Color textColor;
  final Color subtitleColor;
  final VoidCallback onRecover;
  final VoidCallback onKeepCurrent;
  final VoidCallback onClose;
  final StartupRestoreStatus status;
  final String? error;

  /// Formatted through [MaterialLocalizations], like StartupRestoreCard: the
  /// diver's saved locale is not readable yet, so the resolved system locale
  /// the splash MaterialApp carries is the only source of formatting.
  static String _formatStartedAt(BuildContext context, DateTime startedAt) {
    final local = startedAt.toLocal();
    final l = MaterialLocalizations.of(context);
    final date = l.formatMediumDate(local);
    final time = l.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date $time';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final running = status == StartupRestoreStatus.running;
    final bodyStyle = TextStyle(fontSize: 14, color: subtitleColor);
    final captionStyle = TextStyle(fontSize: 12, color: subtitleColor);
    final startedAt = interrupted.startedAt;

    // Scrolls itself, exactly as VersionMismatchView does: StartupWrapper
    // hosts terminal screens in a bare SafeArea > Center.
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restore_page, size: 64, color: Colors.orange),
            const SizedBox(height: 24),
            Text(
              l10n.startup_interruptedRestore_title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              startedAt == null
                  ? l10n.startup_interruptedRestore_body
                  : l10n.startup_interruptedRestore_bodyWithDate(
                      _formatStartedAt(context, startedAt),
                    ),
              style: bodyStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('interruptedRestore_recover'),
              onPressed: running ? null : onRecover,
              child: Text(l10n.startup_interruptedRestore_recoverAction),
            ),
            if (interrupted.liveExists) ...[
              const SizedBox(height: 8),
              Text(
                l10n.startup_interruptedRestore_recoverNote,
                style: captionStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                key: const ValueKey('interruptedRestore_keep'),
                onPressed: running ? null : onKeepCurrent,
                child: Text(l10n.startup_interruptedRestore_keepAction),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.startup_interruptedRestore_keepNote,
                style: captionStyle,
                textAlign: TextAlign.center,
              ),
            ],
            if (running) ...[
              const SizedBox(height: 16),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
            if (status == StartupRestoreStatus.failed) ...[
              const SizedBox(height: 16),
              Text(
                l10n.startup_interruptedRestore_failed,
                style: bodyStyle,
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
            const SizedBox(height: 8),
            TextButton(
              onPressed: running ? null : onClose,
              child: Text(l10n.common_action_close),
            ),
          ],
        ),
      ),
    );
  }
}
