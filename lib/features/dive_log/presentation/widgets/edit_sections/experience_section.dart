import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Group 6: rating, marine life (existing list as slot), notes, tags
/// (existing TagInputWidget as slot).
class ExperienceSection extends StatelessWidget {
  const ExperienceSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.isEmpty,
    required this.rating,
    required this.onRatingChanged,
    required this.notesController,
    required this.notesPlaceholder,
    required this.sightingsChild,
    required this.tagsChild,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String summary;
  final bool isEmpty;
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final TextEditingController notesController;
  final String notesPlaceholder;
  final Widget sightingsChild;
  final Widget tagsChild;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveLog_edit_group_experience,
      icon: Icons.star_outline,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      emptyInvitation: l10n.diveLog_edit_invite_experience,
      children: [
        FormRow.rating(
          label: l10n.diveLog_edit_section_rating,
          value: rating,
          onChanged: onRatingChanged,
        ),
        sightingsChild,
        FormRow.text(
          label: l10n.diveLog_edit_section_notes,
          controller: notesController,
          placeholder: notesPlaceholder,
          maxLines: 5,
        ),
        tagsChild,
      ],
    );
  }
}
