import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Dismissible banner suggesting a geofenced equipment set for the current dive.
class GeofenceSuggestionBanner extends StatelessWidget {
  final String setName;
  final String? locationLabel;
  final VoidCallback onApply;
  final VoidCallback onDismiss;

  const GeofenceSuggestionBanner({
    super.key,
    required this.setName,
    required this.locationLabel,
    required this.onApply,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Icon(
              Icons.place_outlined,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locationLabel != null
                        ? context.l10n.diveLog_edit_geofenceSuggestion_near(
                            locationLabel!,
                          )
                        : context.l10n.diveLog_edit_geofenceSuggestion_title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    context.l10n.diveLog_edit_geofenceSuggestion_body(setName),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onDismiss,
              child: Text(context.l10n.common_action_dismiss),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: onApply,
              child: Text(context.l10n.diveLog_edit_geofenceSuggestion_apply),
            ),
          ],
        ),
      ),
    );
  }
}
