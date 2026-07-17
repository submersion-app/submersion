import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/merge_field_extras.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

/// Site group 3: min/max depth rows, difficulty chips row, rating row.
class DiveInfoSection extends StatelessWidget {
  const DiveInfoSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.isEmpty,
    required this.minDepthController,
    required this.maxDepthController,
    required this.depthSymbol,
    required this.difficulty,
    required this.onDifficultyChanged,
    required this.rating,
    required this.onRatingChanged,
    required this.onRatingCleared,
    this.mergeExtras,
    this.difficultyExtras,
    this.ratingExtras,
  });

  final bool expanded;
  final VoidCallback? onToggle;
  final String summary;
  final bool isEmpty;
  final TextEditingController minDepthController;
  final TextEditingController maxDepthController;
  final String depthSymbol;
  final SiteDifficulty? difficulty;
  final ValueChanged<SiteDifficulty?> onDifficultyChanged;
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onRatingCleared;
  final MergeFieldExtras? Function(String key)? mergeExtras;
  final MergeFieldExtras? difficultyExtras;
  final MergeFieldExtras? ratingExtras;

  Widget _depthRow(
    BuildContext context, {
    required String key,
    required String label,
    required TextEditingController controller,
  }) {
    final extras = mergeExtras?.call(key);
    return SuggestionFormRow(
      label: label,
      controller: controller,
      suggestions: const [],
      caption: extras?.sourceLabel,
      trailing: extras == null
          ? null
          : MergeCycleButton(onPressed: extras.onCycle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveSites_edit_group_diveInfo,
      icon: Icons.info_outline,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      emptyInvitation: l10n.diveSites_edit_invite_diveInfo,
      children: [
        _depthRow(
          context,
          key: 'minDepth',
          label: l10n.diveSites_edit_depth_minLabel(depthSymbol),
          controller: minDepthController,
        ),
        _depthRow(
          context,
          key: 'maxDepth',
          label: l10n.diveSites_edit_depth_maxLabel(depthSymbol),
          controller: maxDepthController,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (difficultyExtras != null)
              MergeSourceRow(
                sourceLabel: difficultyExtras!.sourceLabel,
                onCycle: difficultyExtras!.onCycle,
              ),
            FormRow.custom(
              label: l10n.diveSites_edit_section_difficultyLevel,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 4,
                children: SiteDifficulty.values.map((value) {
                  final isSelected = difficulty == value;
                  return ChoiceChip(
                    label: Text(value.displayName),
                    selected: isSelected,
                    visualDensity: VisualDensity.compact,
                    onSelected: (selected) =>
                        onDifficultyChanged(selected ? value : null),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ratingExtras != null)
              MergeSourceRow(
                sourceLabel: ratingExtras!.sourceLabel,
                onCycle: ratingExtras!.onCycle,
              ),
            FormRow.rating(
              label: l10n.diveSites_edit_section_rating,
              value: rating,
              onChanged: onRatingChanged,
              onClear: onRatingCleared,
            ),
          ],
        ),
      ],
    );
  }
}
