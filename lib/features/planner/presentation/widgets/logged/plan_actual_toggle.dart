import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Switches a dive of the series that has been dived between what happened
/// and its plan (issue #3565). The plan shows locked in the normal planner:
/// it is the record of what was planned. Nothing for a dive still only
/// planned, or a followed dive picked in the series bar.
class PlanActualToggle extends ConsumerWidget {
  const PlanActualToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actual = ref.watch(selectedDiveActualProvider);
    if (actual == null || ref.watch(viewedLoggedDiveIdProvider) != null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final showPlan = ref.watch(showPlanOfDivedProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SegmentedButton<bool>(
        key: const Key('planActualToggle'),
        segments: [
          ButtonSegment(
            value: false,
            label: Text(l10n.plannerSeries_view_actual),
          ),
          ButtonSegment(value: true, label: Text(l10n.plannerSeries_view_plan)),
        ],
        selected: {showPlan},
        showSelectedIcon: false,
        onSelectionChanged: (selection) =>
            ref.read(showPlanOfDivedProvider.notifier).state = selection.first,
      ),
    );
  }
}
