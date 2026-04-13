import 'package:flutter/material.dart';

import 'package:submersion/features/backup/domain/exceptions/backup_failed_exception.dart';

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
          const CircularProgressIndicator(semanticsLabel: 'Backing up'),
          const SizedBox(height: 24),
          Text(
            'Backing up your data',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            "We're saving a copy of your dive log before updating your database.",
            textAlign: TextAlign.center,
          ),
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
            "Couldn't back up your data",
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(error.userMessage, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
            "Your dive log hasn't changed — we didn't update it. Free up space (or fix the issue) and try again.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          const SizedBox(height: 8),
          TextButton(onPressed: onQuit, child: const Text('Quit')),
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text('Technical details'),
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
