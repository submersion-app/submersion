import 'package:flutter/material.dart';

import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_overline.dart';

/// The tags row inside a FormSection: an overline with a Browse action over
/// the tag input, padded as one section row. Shared by the dive and site
/// edit forms so the two stay alike (issue #3578).
class TagFormBlock extends StatelessWidget {
  const TagFormBlock({
    super.key,
    required this.label,
    required this.selectedTags,
    required this.onTagsChanged,
    required this.scope,
  });

  final String label;
  final List<Tag> selectedTags;

  /// Called for both typed tags and tags picked in the Browse sheet.
  final ValueChanged<List<Tag>> onTagsChanged;

  /// Which tags are suggested and browsed, and what a new tag applies to.
  final TagScope scope;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Browse opens the previously-used-tag picker, most used first, so
        // tagging stays consistent without recalling earlier spellings.
        FormOverline(
          label: label,
          actions: [
            FormOverlineAction(
              label: context.l10n.tags_action_browse,
              icon: Icons.label_outline,
              onPressed: () => showTagPickerSheet(
                context,
                selected: selectedTags,
                onPicked: onTagsChanged,
                scope: scope,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: TagInputWidget(
            selectedTags: selectedTags,
            onTagsChanged: onTagsChanged,
            scope: scope,
          ),
        ),
      ],
    );
  }
}
