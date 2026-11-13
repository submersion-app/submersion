import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Shown when a Garmin download found no dives after the ones already
/// downloaded (issue #4223), with a way to read every activity again, such
/// as one skipped last time.
class GarminNothingNewCard extends StatelessWidget {
  const GarminNothingNewCard({super.key, required this.onDownloadAll});

  final VoidCallback? onDownloadAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.universalImport_info_garminNoNewDives,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onDownloadAll,
              child: Text(
                context.l10n.universalImport_action_garminDownloadAll,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
