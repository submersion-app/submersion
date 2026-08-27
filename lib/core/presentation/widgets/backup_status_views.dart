import 'package:flutter/material.dart';

import 'package:submersion/features/backup/domain/exceptions/backup_failed_exception.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shown while PreMigrationBackupService copies the live database.
class BackingUpView extends StatelessWidget {
  const BackingUpView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            semanticsLabel: context.l10n.startup_backup_semanticsLabel,
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.startup_backup_title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(context.l10n.startup_backup_body, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Shown when the pre-migration backup fails. Offers Retry and Quit.
class BackupFailedView extends StatelessWidget {
  final BackupFailedException error;
  final VoidCallback onRetry;
  final VoidCallback onQuit;

  const BackupFailedView({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.startup_backupFailed_title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(error.userMessage, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            context.l10n.startup_backupFailed_body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
            child: Text(context.l10n.common_action_retry),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onQuit,
            child: Text(context.l10n.startup_backupFailed_quit),
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            title: Text(context.l10n.startup_backupFailed_technicalDetails),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  error.technicalDetails,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
