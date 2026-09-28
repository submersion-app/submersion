import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The strip above the equipment edit form in the master-detail pane: the
/// title, Cancel and Save. The page owns the discard prompt and the save,
/// and hands them in as [onCancel] and [onSave].
class EquipmentEditEmbeddedHeader extends StatelessWidget {
  final bool isEditing;

  /// While a save runs, Save shows a spinner and cannot be pressed.
  final bool isLoading;

  final VoidCallback onCancel;
  final VoidCallback onSave;

  const EquipmentEditEmbeddedHeader({
    super.key,
    required this.isEditing,
    required this.isLoading,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              isEditing ? Icons.edit : Icons.add,
              size: 20,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEditing
                  ? context.l10n.equipment_edit_embeddedHeader_editTitle
                  : context.l10n.equipment_edit_embeddedHeader_newTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: onCancel,
            child: Text(
              context.l10n.equipment_edit_embeddedHeader_cancelButton,
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: isEditing
                ? context.l10n.equipment_edit_embeddedHeader_saveTooltip_edit
                : context.l10n.equipment_edit_embeddedHeader_saveTooltip_new,
            child: FilledButton(
              onPressed: isLoading ? null : onSave,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(context.l10n.equipment_edit_embeddedHeader_saveButton),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks whether to throw away the edit form's unsaved changes. Resolves
/// true to discard, false (or null when dismissed) to keep editing.
Future<bool?> showEquipmentDiscardDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.equipment_edit_discardDialog_title),
      content: Text(context.l10n.equipment_edit_discardDialog_content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.equipment_edit_discardDialog_keepEditing),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.equipment_edit_discardDialog_discard),
        ),
      ],
    ),
  );
}
