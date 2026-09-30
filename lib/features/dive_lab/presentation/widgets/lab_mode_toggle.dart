import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Replay / Re-plan; locked to Re-plan while a path-changing intervention
/// is in the scenario.
class LabModeToggle extends ConsumerWidget {
  const LabModeToggle({super.key, required this.diveId});

  final String diveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final draft = ref.watch(labDraftProvider(diveId));
    final notifier = ref.read(labDraftProvider(diveId).notifier);
    final forced = draft.modeForced;
    final mode = draft.effectiveMode;
    final hint = forced
        ? l10n.diveLab_mode_forced
        : (mode == ScenarioMode.replay
              ? l10n.diveLab_mode_replayHint
              : l10n.diveLab_mode_replanHint);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<ScenarioMode>(
          segments: [
            ButtonSegment(
              value: ScenarioMode.replay,
              label: Text(l10n.diveLab_mode_replay),
            ),
            ButtonSegment(
              value: ScenarioMode.replan,
              label: Text(l10n.diveLab_mode_replan),
            ),
          ],
          selected: {mode},
          showSelectedIcon: false,
          onSelectionChanged: forced ? null : (s) => notifier.setMode(s.first),
        ),
        const SizedBox(height: 4),
        Text(
          hint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
