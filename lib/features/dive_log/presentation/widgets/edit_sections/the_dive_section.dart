import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Group 1 of the dive form: always expanded, owns the core facts.
/// Rows: dive number, entry, exit, surface interval, max depth, avg depth,
/// bottom time, runtime, site, then site extras and the profile block.
class TheDiveSection extends StatelessWidget {
  const TheDiveSection({
    super.key,
    required this.depthSymbol,
    required this.nameController,
    required this.maxDepthController,
    required this.avgDepthController,
    required this.bottomTimeController,
    required this.runtimeController,
    required this.diveNumberController,
    required this.entryText,
    required this.onEditEntry,
    required this.exitText,
    required this.onEditExit,
    required this.siteName,
    required this.onPickSite,
    this.onClearSite,
    this.maxDepthSuggestion,
    this.avgDepthSuggestion,
    this.bottomTimeSuggestion,
    this.runtimeSuggestion,
    this.surfaceIntervalRow,
    this.siteExtras,
    this.profileChild,
  });

  final String depthSymbol;
  final TextEditingController nameController;
  final TextEditingController maxDepthController;
  final TextEditingController avgDepthController;
  final TextEditingController bottomTimeController;
  final TextEditingController runtimeController;
  final TextEditingController diveNumberController;
  final String entryText;
  final VoidCallback onEditEntry;
  final String? exitText;
  final VoidCallback onEditExit;
  final String? siteName;
  final VoidCallback onPickSite;
  final VoidCallback? onClearSite;
  final ProfileSuggestion? maxDepthSuggestion;
  final ProfileSuggestion? avgDepthSuggestion;
  final ProfileSuggestion? bottomTimeSuggestion;
  final ProfileSuggestion? runtimeSuggestion;

  /// Surface interval display row (provider-backed), when editing.
  final Widget? surfaceIntervalRow;

  /// Location status, selected-site caption and photo-GPS banner from the
  /// old site section.
  final Widget? siteExtras;

  /// Existing profile block (points count, outlier chip, edit/draw
  /// buttons), stripped of its Card wrapper.
  final Widget? profileChild;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveLog_edit_group_theDive,
      expanded: true,
      onToggle: null,
      children: [
        FormRow.text(
          label: l10n.diveLog_edit_label_diveName,
          controller: nameController,
          placeholder: l10n.diveLog_edit_diveNamePlaceholder,
        ),
        FormRow.text(
          label: l10n.diveLog_edit_label_diveNumber,
          controller: diveNumberController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          placeholder: l10n.diveLog_edit_row_notSet,
        ),
        FormRow.picker(
          label: l10n.diveLog_edit_row_entry,
          value: entryText,
          onTap: onEditEntry,
        ),
        FormRow.picker(
          label: l10n.diveLog_edit_row_exit,
          value: exitText,
          placeholder: l10n.diveLog_edit_row_notSet,
          onTap: onEditExit,
        ),
        ?surfaceIntervalRow,
        FormRow.text(
          label: l10n.diveLog_edit_label_maxDepth,
          controller: maxDepthController,
          suffixText: depthSymbol,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
          ],
          profileSuggestion: maxDepthSuggestion,
        ),
        FormRow.text(
          label: l10n.diveLog_edit_label_avgDepth,
          controller: avgDepthController,
          suffixText: depthSymbol,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
          ],
          profileSuggestion: avgDepthSuggestion,
        ),
        FormRow.text(
          label: l10n.diveLog_edit_label_bottomTime,
          controller: bottomTimeController,
          suffixText: 'min',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          profileSuggestion: bottomTimeSuggestion,
        ),
        FormRow.text(
          label: l10n.diveLog_edit_label_runtime,
          controller: runtimeController,
          suffixText: 'min',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          placeholder: l10n.diveLog_edit_row_notSet,
          profileSuggestion: runtimeSuggestion,
        ),
        FormRow.picker(
          label: l10n.diveLog_edit_row_site,
          value: siteName,
          placeholder: l10n.diveLog_edit_row_addSite,
          onTap: onPickSite,
          onClear: siteName == null ? null : onClearSite,
        ),
        ?siteExtras,
        ?profileChild,
      ],
    );
  }
}
