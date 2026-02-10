import 'package:flutter/material.dart';

/// Dialog shown during database migration
class MigrationProgressDialog extends StatelessWidget {
  final String message;

  const MigrationProgressDialog({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$message. Please do not close the app.',
      liveRegion: true,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExcludeSemantics(child: CircularProgressIndicator()),
            const SizedBox(height: 24),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please do not close the app',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
