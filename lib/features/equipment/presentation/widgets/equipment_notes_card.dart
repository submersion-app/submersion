import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The equipment detail page's Notes card. The page shows it only when the
/// item has notes.
class EquipmentNotesCard extends StatelessWidget {
  final String notes;

  const EquipmentNotesCard({super.key, required this.notes});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notes,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.equipment_detail_notesTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(notes, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
