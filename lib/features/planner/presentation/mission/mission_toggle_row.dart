import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "Plan as DPV mission": turns the mission on with a starter route and one
/// diver, or, after confirming, off, leaving the generated segments behind
/// as ordinary editable segments.
class MissionToggleRow extends ConsumerWidget {
  const MissionToggleRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final on = ref.watch(
      divePlanNotifierProvider.select((s) => s.mission != null),
    );
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(
        l10n.plannerMission_enable,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      value: on,
      onChanged: (enable) async {
        if (enable) {
          // The mission replaces the plan's segments: ask before a
          // hand-built profile goes.
          // Read before the dialog: the row may be gone when it closes.
          final plan = ref.read(divePlanNotifierProvider);
          final hasSegments = plan.segments.isNotEmpty;
          if (hasSegments &&
              !await _confirm(
                context,
                title: l10n.plannerMission_enableTitle,
                message: l10n.plannerMission_enableMessage,
                confirmLabel: l10n.plannerMission_enableConfirm,
              )) {
            return;
          }
          const uuid = Uuid();
          notifier.enableMission(
            MissionEdits.starter(
              legId: uuid.v4(),
              memberId: uuid.v4(),
              memberName: l10n.plannerMission_team_defaultName(1),
              sacBottom: plan.sacRate,
            ),
          );
          return;
        }
        if (await _confirm(
          context,
          title: l10n.plannerMission_disableTitle,
          message: l10n.plannerMission_disableMessage,
          confirmLabel: l10n.plannerMission_disableConfirm,
        )) {
          notifier.disableMission();
        }
      },
    );
  }

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}
