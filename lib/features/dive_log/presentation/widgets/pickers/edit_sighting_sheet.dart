import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/pickers/sighting_abundance_picker.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Edit sighting sheet
class EditSightingSheet extends StatefulWidget {
  final Sighting sighting;
  final void Function(Sighting) onSave;
  final VoidCallback onDelete;

  const EditSightingSheet({
    super.key,
    required this.sighting,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<EditSightingSheet> createState() => _EditSightingSheetState();
}

class _EditSightingSheetState extends State<EditSightingSheet> {
  late SightingAmount _amount;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _amount = widget.sighting.amount;
    _notesController = TextEditingController(text: widget.sighting.notes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scrolls: the "How many" chips and stepper plus the keyboard for the
    // notes do not fit a small phone's height.
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  localizedSpeciesName(
                    context.l10n,
                    widget.sighting.speciesId,
                    widget.sighting.speciesName,
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  tooltip: context.l10n.diveLog_editSighting_remove,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text(
                          context.l10n.diveLog_editSighting_removeTitle,
                        ),
                        content: Text(
                          context.l10n.diveLog_editSighting_removeConfirm(
                            localizedSpeciesName(
                              context.l10n,
                              widget.sighting.speciesId,
                              widget.sighting.speciesName,
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: Text(context.l10n.common_action_cancel),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              widget.onDelete();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                            child: Text(
                              context.l10n.diveLog_editSighting_remove,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            SightingAbundancePicker(
              value: _amount,
              onChanged: (v) => setState(() => _amount = v),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: context.l10n.diveLog_editSighting_notes,
                hintText: context.l10n.diveLog_editSighting_notesHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                widget.onSave(
                  widget.sighting.copyWith(
                    abundance: _amount.abundance,
                    count: _amount.count,
                    notes: _notesController.text,
                  ),
                );
              },
              child: Text(context.l10n.diveLog_editSighting_save),
            ),
          ],
        ),
      ),
    );
  }
}
