import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dialog shown during database migration
class MigrationProgressDialog extends StatelessWidget {
  final String message;

  const MigrationProgressDialog({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final doNotCloseText = context.l10n.settings_migrationProgress_doNotClose;
    return Semantics(
      label: '$message. $doNotCloseText',
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
              doNotCloseText,
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
