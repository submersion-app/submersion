import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/merge_field_extras.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/enum_multi_picker_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

/// The merge page's Access & safety group: access notes, mooring number,
/// parking and hazards, as plain rows that take merge extras.
class AccessSafetySection extends StatelessWidget {
  const AccessSafetySection({
    super.key,
    required this.accessNotesController,
    required this.mooringNumberController,
    required this.parkingInfoController,
    required this.hazardsController,
    required this.entryMethods,
    required this.exitMethods,
    required this.onEntryMethodChanged,
    required this.onExitMethodChanged,
    this.mergeExtras,
    this.entryMethodExtras,
    this.exitMethodExtras,
  });

  final TextEditingController accessNotesController;
  final TextEditingController mooringNumberController;
  final TextEditingController parkingInfoController;
  final TextEditingController hazardsController;
  final MergeFieldExtras? Function(String key)? mergeExtras;

  /// Every way in and out the site offers (issue #2054); empty exits mean
  /// "same as entry".
  final List<EntryMethod> entryMethods;
  final List<EntryMethod> exitMethods;
  final ValueChanged<List<EntryMethod>> onEntryMethodChanged;
  final ValueChanged<List<EntryMethod>> onExitMethodChanged;

  /// Dedicated merge affordances for the two enum rows. These cannot go
  /// through [mergeExtras], which resolves through the page's
  /// text-controller candidate map and returns null for an enum field.
  final MergeFieldExtras? entryMethodExtras;
  final MergeFieldExtras? exitMethodExtras;

  Widget _row(
    BuildContext context, {
    required String key,
    required String label,
    required TextEditingController controller,
    String? placeholder,
    int maxLines = 1,
    bool markdown = false,
  }) {
    final extras = mergeExtras?.call(key);
    return SuggestionFormRow(
      label: label,
      controller: controller,
      suggestions: const [],
      placeholder: placeholder,
      maxLines: maxLines,
      markdown: markdown,
      caption: extras?.sourceLabel,
      trailing: extras == null
          ? null
          : MergeCycleButton(onPressed: extras.onCycle),
    );
  }

  Widget _methodRow(
    BuildContext context, {
    required String label,
    required List<EntryMethod> value,
    required ValueChanged<List<EntryMethod>> onChanged,
    required MergeFieldExtras? extras,
  }) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (extras != null)
          MergeSourceRow(
            sourceLabel: extras.sourceLabel,
            onCycle: extras.onCycle,
          ),
        EnumMultiPickerRow<EntryMethod>(
          label: label,
          value: value,
          values: EntryMethod.values,
          displayName: (v) => v.localizedName(l10n),
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveSites_edit_group_accessSafety,
      icon: Icons.shield_outlined,
      expanded: true,
      onToggle: null,
      children: [
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
          key: 'accessNotes',
          label: l10n.diveSites_edit_access_accessNotes_label,
          controller: accessNotesController,
          placeholder: l10n.diveSites_edit_access_accessNotes_hint,
          maxLines: 3,
          markdown: true,
        ),
        _methodRow(
          context,
          label: l10n.diveSites_edit_access_entryMethod_label,
          value: entryMethods,
          onChanged: onEntryMethodChanged,
          extras: entryMethodExtras,
        ),
        _methodRow(
          context,
          label: l10n.diveSites_edit_access_exitMethod_label,
          value: exitMethods,
          onChanged: onExitMethodChanged,
          extras: exitMethodExtras,
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
