import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Group 2 of the dive form: dive mode, CCR/SCR panels, tank cards,
/// equipment and weights. Interiors are page-provided slots; this widget
/// owns only the group chrome and composition.
class GasGearSection extends StatelessWidget {
  const GasGearSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.modeSelector,
    required this.tankCards,
    required this.onAddTank,
    required this.addTankLabel,
    required this.equipmentChild,
    required this.weightChild,
    this.rebreatherPanel,
    this.errorCount = 0,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String summary;
  final Widget modeSelector;
  final List<Widget> tankCards;
  final VoidCallback onAddTank;
  final String addTankLabel;
  final Widget equipmentChild;
  final Widget weightChild;

  /// CcrSettingsPanel / ScrSettingsPanel when the mode requires one.
  final Widget? rebreatherPanel;
  final int errorCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return FormSection(
      label: l10n.diveLog_edit_group_gasGear,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      emptyInvitation: l10n.diveLog_edit_invite_gasGear,
      errorCount: errorCount,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: modeSelector,
        ),
        ?rebreatherPanel,
        Column(children: tankCards),
        InkWell(
          onTap: onAddTank,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                '+ $addTankLabel',
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        equipmentChild,
        weightChild,
      ],
    );
  }
}
