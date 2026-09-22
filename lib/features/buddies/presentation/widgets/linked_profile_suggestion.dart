import 'package:flutter/material.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Inline prompt on the buddy page: "{name} has a profile here. Link this
/// buddy to it?" with Link and Not now.
class LinkedProfileSuggestion extends StatelessWidget {
  final Diver diver;
  final VoidCallback onLink;
  final VoidCallback onDismiss;

  const LinkedProfileSuggestion({
    super.key,
    required this.diver,
    required this.onLink,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.buddies_linkedProfile_suggestion(diver.name),
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDismiss,
                  child: Text(context.l10n.buddies_linkedProfile_notNow),
                ),
                FilledButton.tonal(
                  onPressed: onLink,
                  child: Text(context.l10n.buddies_linkedProfile_link),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
