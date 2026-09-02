import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// What the GPS log shows before the first track exists.
///
/// The single grey sentence this replaces told a diver nothing about why the
/// page was there; the feature description already shipped for the tools hub,
/// so the empty state reuses it rather than adding a second explanation.
class GpsLogEmptyState extends StatelessWidget {
  const GpsLogEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.route_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.gpsLogger_noTracks,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tools_gpsLogger_description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
