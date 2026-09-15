import 'package:flutter/material.dart';

import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Tags field on the equipment edit page (issue #1942): the tag input
/// plus a Browse button, both limited to equipment tags. A tag created here
/// applies to equipment; a name already used by a dive or site tag widens
/// that tag instead of creating a second one.
class EquipmentTagsField extends StatelessWidget {
  const EquipmentTagsField({
    super.key,
    required this.selectedTags,
    required this.onTagsChanged,
    this.enabled = true,
  });

  final List<Tag> selectedTags;
  final ValueChanged<List<Tag>> onTagsChanged;

  /// False when the stored tags could not be read. Editing then would save
  /// a set built without them, dropping them.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.sell_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.equipment_edit_tagsLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            // The same picker the dive and site pages open, listing the
            // diver's equipment tags most used first.
            TextButton.icon(
              key: const ValueKey('equipment_edit_tags_browse'),
              onPressed: enabled
                  ? () => showTagPickerSheet(
                      context,
                      selected: selectedTags,
                      onPicked: onTagsChanged,
                      scope: TagScope.equipment,
                    )
                  : null,
              icon: const Icon(Icons.label_outline, size: 18),
              label: Text(l10n.tags_action_browse),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TagInputWidget(
          selectedTags: selectedTags,
          onTagsChanged: onTagsChanged,
          enabled: enabled,
          scope: TagScope.equipment,
        ),
      ],
    );
  }
}
