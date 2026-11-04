import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_logged_dive_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Under the chart for a logged dive picked in the series bar (issue #3565),
/// in the planned dive's status chips' place: its runtime and depth, and the
/// warnings its safety review raised.
class LoggedDiveStatusChips extends ConsumerWidget {
  const LoggedDiveStatusChips({super.key, required this.onWarningsTap});

  /// Shows the warnings in the results.
  final VoidCallback onWarningsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logged = ref.watch(viewedLoggedDiveProvider);
    if (logged == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final dive = ref.watch(diveProvider(logged.id)).value;
    final findings = ref.watch(viewedLoggedDiveFindingsProvider);
    // The measured runtime, as the dive log reports it: never the bottom
    // time a dive with no runtime falls back to for time windows (#3304).
    final runtime = dive?.measuredRuntime;
    final depth = dive?.maxDepth ?? logged.maxDepth;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        PlanChip(
          label: l10n.divePlanner_label_runtime,
          value: runtime == null ? '--' : '${runtime.inMinutes}′',
          emphasized: true,
        ),
        if (depth != null)
          PlanChip(
            label: l10n.plannerSeries_maxDepth,
            value: units.formatDepth(depth, decimals: 0),
          ),
        if (findings.isNotEmpty)
          PlanChip(
            label: l10n.plannerCanvas_chip_issues(findings.length),
            tint: Theme.of(context).colorScheme.tertiary,
            onTap: onWarningsTap,
          ),
      ],
    );
  }
}
