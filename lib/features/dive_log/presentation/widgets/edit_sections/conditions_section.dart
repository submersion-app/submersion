import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Group 3 of the dive form. Water/air temperature lead as ordinary rows
/// (the hero strip is retired); the environment and weather row lists are
/// page-provided and spread into the section so dividers separate rows.
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
        FormRow.text(
          label: l10n.diveLog_edit_label_waterTemp,
          controller: waterTempController,
          suffixText: temperatureSymbol,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
          ],
        ),
        FormRow.text(
          label: l10n.diveLog_edit_label_airTemp,
          controller: airTempController,
          suffixText: temperatureSymbol,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
          ],
        ),
        ...environmentRows,
        ...weatherRows,
      ],
    );
  }
}
