import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';

/// Asks for a name and a description, then saves the gear [topLevelIds] as
/// an equipment set of the active diver's, at once: a set is a record of
/// its own. Shared by the dive form and the dive page's Equipment card,
/// where it outlives a cancelled sitting (issue #4527).
void showSaveGearAsSetDialog(
  BuildContext context, {
  required List<String> topLevelIds,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => _SaveGearAsSetDialog(topLevelIds: topLevelIds),
  );
}

/// The dialog itself: it owns its text fields, which go with it.
class _SaveGearAsSetDialog extends ConsumerStatefulWidget {
  const _SaveGearAsSetDialog({required this.topLevelIds});

  final List<String> topLevelIds;

  @override
  ConsumerState<_SaveGearAsSetDialog> createState() =>
      _SaveGearAsSetDialogState();
}

class _SaveGearAsSetDialogState extends ConsumerState<_SaveGearAsSetDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.diveLog_edit_saveAsSetDialog_validation),
        ),
      );
      return;
    }

    try {
      final set = EquipmentSet(
        id: '',
        name: name,
        description: _descriptionController.text.trim(),
        equipmentIds: widget.topLevelIds,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Route through the notifier so the set is stamped with the active
      // diver id. Calling the repository directly leaves diverId null,
      // orphaning the set from the diver-scoped list (it silently "doesn't
      // save"). addSet also refreshes the list providers.
      await ref.read(equipmentSetListNotifierProvider.notifier).addSet(set);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.diveLog_edit_saveAsSetDialog_success(name),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.diveLog_edit_saveAsSetDialog_error(e.toString()),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.diveLog_edit_saveAsSetDialog_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.diveLog_edit_saveAsSetDialog_content(
              widget.topLevelIds.length,
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: context.l10n.diveLog_edit_saveAsSetDialog_setName,
              hintText: context.l10n.diveLog_edit_saveAsSetDialog_setNameHint,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          MarkdownNotesField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: context.l10n.diveLog_edit_saveAsSetDialog_description,
              hintText:
                  context.l10n.diveLog_edit_saveAsSetDialog_descriptionHint,
              border: const OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.diveLog_edit_cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(context.l10n.diveLog_edit_save),
        ),
      ],
    );
  }
}
