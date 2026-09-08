import 'package:flutter/material.dart';

import 'package:submersion/core/presentation/startup_restore_status.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The backup a startup screen is offering, with whatever the restore attempt
/// is currently doing.
///
/// Shared by the terminal failure screen and the schema-mismatch screen. The
/// two ask for a restore for different reasons and say different things about
/// it, so the wording is passed in; the parts that must not differ (how the
/// backup identifies itself, what a failure looks like, what happens to the
/// button while a restore runs) live here.
class StartupRestoreCard extends StatelessWidget {
  const StartupRestoreCard({
    super.key,
    required this.record,
    required this.title,
    required this.actionLabel,
    required this.onRestore,
    required this.status,
    required this.error,
    required this.textColor,
    required this.subtitleColor,
    this.body,
    this.warning,
  });

  final BackupRecord record;
  final String title;
  final String actionLabel;
  final VoidCallback onRestore;
  final StartupRestoreStatus status;
  final String? error;
  final Color textColor;
  final Color subtitleColor;

  /// Optional lead-in shown above the backup's own details.
  final String? body;

  /// Optional consequence the diver has to weigh before accepting, rendered
  /// last and emphasised. Used by the schema-mismatch screen, where accepting
  /// means going back to an older database.
  final String? warning;

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
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                style: TextStyle(fontSize: 13, color: subtitleColor),
                textAlign: TextAlign.center,
              ),
            ],
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
            if (warning != null) ...[
              const SizedBox(height: 12),
              Text(
                warning!,
                style: TextStyle(
                  fontSize: 13,
                  color: subtitleColor,
                  fontWeight: FontWeight.w500,
                ),
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
                child: Text(actionLabel),
              ),
          ],
        ),
      ),
    );
  }
}
