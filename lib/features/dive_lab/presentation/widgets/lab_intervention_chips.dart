import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_lab/presentation/lab_format.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_add_intervention_sheet.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_chart.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The scenario's interventions as removable chips plus the Add chip.
class LabInterventionChips extends ConsumerWidget {
  const LabInterventionChips({
    super.key,
    required this.diveId,
    required this.inputs,
  });

  final String diveId;
  final LabRequestInputs inputs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final draft = ref.watch(labDraftProvider(diveId));
    final notifier = ref.read(labDraftProvider(diveId).notifier);
    String tankName(String id) => labTankName(inputs.tanks, id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.diveLab_interventions_label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final i in draft.interventions)
              () {
                final label = labInterventionChipLabel(
                  l10n,
                  units,
                  i,
                  tankName,
                );
                return Semantics(
                  button: true,
                  label: l10n.diveLab_chip_remove(label),
                  child: PlanChip(
                    label: label,
                    value: '✕',
                    tint: kLabGhostColor,
                    onTap: () => notifier.removeIntervention(i.kind),
                  ),
                );
              }(),
            PlanChip(
              label: l10n.diveLab_interventions_add,
              value: '+',
              emphasized: true,
              onTap: () => showLabAddInterventionSheet(
                context,
                diveId: diveId,
                inputs: inputs,
              ),
            ),
          ],
        ),
        if (draft.interventions.isEmpty) ...[
          const SizedBox(height: 6),
          Text(
            l10n.diveLab_interventions_none,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ],
    );
  }
}
