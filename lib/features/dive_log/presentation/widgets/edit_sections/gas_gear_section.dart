import 'package:flutter/material.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_append_row.dart';
import 'package:submersion/shared/widgets/forms/form_overline.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Group 2 of the dive form: dive mode row, CCR/SCR panels, tank rows,
/// equipment and weights. Interiors are page-provided slots; this widget
/// owns only the group chrome and composition.
class GasGearSection extends StatelessWidget {
  const GasGearSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.modeChild,
    required this.tanks,
    required this.onAddTank,
    required this.addTankLabel,
    required this.equipmentChild,
    required this.weightChild,
    this.rebreatherPanel,
    this.showTankControls = true,
    this.errorCount = 0,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String summary;

  /// Dive-mode row (+ description caption) built by the page.
  final Widget modeChild;
  final List<Widget> tanks;
  final VoidCallback onAddTank;
  final String addTankLabel;
  final Widget equipmentChild;
  final Widget weightChild;

  /// CcrSettingsPanel / ScrSettingsPanel when the mode requires one.
  final Widget? rebreatherPanel;

  /// False for gauge dives, which log depth and time only.
  final bool showTankControls;

  final int errorCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveLog_edit_group_gasGear,
      icon: MdiIcons.divingScubaTank,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      emptyInvitation: l10n.diveLog_edit_invite_gasGear,
      errorCount: errorCount,
      children: [
        modeChild,
        ?rebreatherPanel,
        if (showTankControls)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormOverline(label: l10n.diveLog_edit_overline_tanks),
              ...tanks,
              FormAppendRow(label: addTankLabel, onTap: onAddTank),
            ],
          ),
        equipmentChild,
        weightChild,
      ],
    );
  }
}
