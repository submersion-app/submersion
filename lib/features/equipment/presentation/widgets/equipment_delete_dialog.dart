import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks before deleting an Equipment item. A dive computer or transmitter
/// item is its device's one entry (issue #3676), so deleting it deletes the
/// device too, and the confirmation says what goes with it.
Future<bool> confirmEquipmentDelete(
  BuildContext context,
  EquipmentType type,
) async {
  final l10n = context.l10n;
  final content = switch (type) {
    EquipmentType.computer => l10n.equipment_deleteDialog_content_computer,
    EquipmentType.transmitter =>
      l10n.equipment_deleteDialog_content_transmitter,
    _ => l10n.equipment_deleteDialog_content,
  };
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.equipment_deleteDialog_title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.equipment_deleteDialog_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(context.l10n.equipment_deleteDialog_confirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
