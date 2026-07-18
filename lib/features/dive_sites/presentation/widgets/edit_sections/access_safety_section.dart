import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/merge_field_extras.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

/// Site group 4: access notes, mooring number, parking, hazards — plain
/// merge-capable rows (inner icon headers and helper texts removed).
class AccessSafetySection extends StatelessWidget {
  const AccessSafetySection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.isEmpty,
    required this.accessNotesController,
    required this.mooringNumberController,
    required this.parkingInfoController,
    required this.hazardsController,
    this.mergeExtras,
  });

  final bool expanded;
  final VoidCallback? onToggle;
  final String summary;
  final bool isEmpty;
  final TextEditingController accessNotesController;
  final TextEditingController mooringNumberController;
  final TextEditingController parkingInfoController;
  final TextEditingController hazardsController;
  final MergeFieldExtras? Function(String key)? mergeExtras;

  Widget _row(
    BuildContext context, {
    required String key,
    required String label,
    required TextEditingController controller,
    String? placeholder,
    int maxLines = 1,
  }) {
    final extras = mergeExtras?.call(key);
    return SuggestionFormRow(
      label: label,
      controller: controller,
      suggestions: const [],
      placeholder: placeholder,
      maxLines: maxLines,
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
      label: l10n.diveSites_edit_group_accessSafety,
      icon: Icons.shield_outlined,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      emptyInvitation: l10n.diveSites_edit_invite_accessSafety,
      children: [
        _row(
          context,
          key: 'accessNotes',
          label: l10n.diveSites_edit_access_accessNotes_label,
          controller: accessNotesController,
          placeholder: l10n.diveSites_edit_access_accessNotes_hint,
          maxLines: 3,
        ),
        _row(
          context,
          key: 'mooringNumber',
          label: l10n.diveSites_edit_access_mooringNumber_label,
          controller: mooringNumberController,
          placeholder: l10n.diveSites_edit_access_mooringNumber_hint,
        ),
        _row(
          context,
          key: 'parkingInfo',
          label: l10n.diveSites_edit_access_parkingInfo_label,
          controller: parkingInfoController,
          placeholder: l10n.diveSites_edit_access_parkingInfo_hint,
          maxLines: 2,
        ),
        _row(
          context,
          key: 'hazards',
          label: l10n.diveSites_edit_hazards_label,
          controller: hazardsController,
          placeholder: l10n.diveSites_edit_hazards_hint,
          maxLines: 3,
        ),
      ],
    );
  }
}
