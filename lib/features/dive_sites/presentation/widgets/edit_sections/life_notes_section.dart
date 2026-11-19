import 'package:flutter/material.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/merge_field_extras.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_empty_row.dart';
import 'package:submersion/shared/widgets/forms/form_overline.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

/// The merge page's Life & notes group: expected marine life (overline and
/// chips) and the notes row. A merge keeps each site's sharing, so it has
/// no sharing row.
class LifeNotesSection extends StatelessWidget {
  const LifeNotesSection({
    super.key,
    required this.species,
    required this.onAddSpecies,
    required this.onRemoveSpecies,
    required this.notesController,
    this.mergeExtras,
  });

  final List<Species> species;
  final VoidCallback onAddSpecies;
  final ValueChanged<Species> onRemoveSpecies;
  final TextEditingController notesController;

  final MergeFieldExtras? Function(String key)? mergeExtras;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final notesExtras = mergeExtras?.call('notes');
    return FormSection(
      label: l10n.diveSites_edit_group_lifeNotes,
      icon: Icons.menu_book_outlined,
      expanded: true,
      onToggle: null,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormOverline(
              label: l10n.diveSites_edit_section_expectedMarineLife,
              actions: [
                FormOverlineAction(
                  label: l10n.diveSites_edit_marineLife_addButton,
                  icon: Icons.add,
                  onPressed: onAddSpecies,
                ),
              ],
            ),
            if (species.isEmpty)
              FormEmptyRow(label: l10n.diveSites_edit_marineLife_empty)
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: species.map((s) {
                    return Chip(
                      avatar: Icon(
                        MdiIcons.fish,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      label: Text(s.localizedCommonName(l10n)),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => onRemoveSpecies(s),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
        SuggestionFormRow(
          label: l10n.diveSites_edit_field_notes_label,
          controller: notesController,
          suggestions: const [],
          placeholder: l10n.diveSites_edit_field_notes_hint,
          maxLines: 4,
          markdown: true,
          caption: notesExtras?.sourceLabel,
          trailing: notesExtras == null
              ? null
              : MergeCycleButton(onPressed: notesExtras.onCycle),
        ),
      ],
    );
  }
}
