import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_lab/domain/services/branch_state_builder.dart';
import 'package:submersion/features/dive_lab/presentation/lab_format.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Branch readout, slider over the dive and fine steppers.
class LabBranchControls extends ConsumerWidget {
  const LabBranchControls({
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
    final max = inputs.durationSeconds;
    final branch = (draft.branchSeconds ?? 0).clamp(0, max);
    final depth = inputs.depths[branchIndexFor(inputs.timestamps, branch)];

    Widget step(String label, int delta) => OutlinedButton(
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      onPressed: () => notifier.nudgeBranch(delta, maxSeconds: max),
      child: Text(label),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              l10n.diveLab_branch_label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.diveLab_branch_readout(
                formatLabTime(branch),
                units.formatDepth(depth),
              ),
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
        Slider(
          value: branch.toDouble(),
          min: 0,
          max: max <= 0 ? 1 : max.toDouble(),
          onChanged: max <= 0
              ? null
              : (v) => notifier.setBranchSeconds(v.round(), maxSeconds: max),
        ),
        Wrap(
          spacing: 6,
          children: [
            step(l10n.diveLab_branch_minusMinute, -60),
            step(l10n.diveLab_branch_minusTenSeconds, -10),
            step(l10n.diveLab_branch_plusTenSeconds, 10),
            step(l10n.diveLab_branch_plusMinute, 60),
          ],
        ),
      ],
    );
  }
}
