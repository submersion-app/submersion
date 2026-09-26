import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Group 3 of the dive form. An auto-fill action row leads, then water/air
/// temperature as ordinary rows (the hero strip is retired); the top,
/// environment and weather row lists are page-provided and spread into the
/// section so dividers separate rows.
class ConditionsSection extends StatelessWidget {
  const ConditionsSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.isEmpty,
    required this.temperatureSymbol,
    required this.waterTempController,
    required this.airTempController,
    required this.environmentRows,
    required this.weatherRows,
    this.topRows = const [],
    this.errorCount = 0,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String summary;
  final bool isEmpty;
  final String temperatureSymbol;
  final TextEditingController waterTempController;
  final TextEditingController airTempController;
  final List<Widget> environmentRows;
  final List<Widget> weatherRows;

  /// Rows pinned above the temperature fields (the auto-fill action overline).
  final List<Widget> topRows;
  final int errorCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveLog_edit_group_conditions,
      icon: Icons.waves,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      emptyInvitation: l10n.diveLog_edit_invite_conditions,
      errorCount: errorCount,
      children: [
        ...topRows,
        FormRow.text(
          label: l10n.diveLog_edit_label_waterTemp,
          controller: waterTempController,
          suffixText: temperatureSymbol,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          // Signed, since water and air can be below zero. The validator
          // reports text left unreadable instead of it saving as 0 (#1900).
          inputFormatters: numberInputFormatters(allowNegative: true),
          inputValidator: numberValidator(context),
        ),
        FormRow.text(
          label: l10n.diveLog_edit_label_airTemp,
          controller: airTempController,
          suffixText: temperatureSymbol,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          // Signed, since water and air can be below zero. The validator
          // reports text left unreadable instead of it saving as 0 (#1900).
          inputFormatters: numberInputFormatters(allowNegative: true),
          inputValidator: numberValidator(context),
        ),
        ...environmentRows,
        ...weatherRows,
      ],
    );
  }
}
