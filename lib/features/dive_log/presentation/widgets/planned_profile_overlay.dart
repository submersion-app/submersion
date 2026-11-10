import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A dive's linked plan as its profile chart draws it (#4215).
///
/// [available] is whether the dive has a linked plan at all, which is what
/// puts the plan's switch in the chart options; [overlay] is the plan's line,
/// null while that switch is off.
typedef PlannedProfileForChart = ({
  ChartSourceOverlay? overlay,
  bool available,
});

/// The linked plan's overlay for [diveId], for every surface that draws a
/// dive's profile (the dive details card and the full screen page), so the
/// two cannot disagree about whether the plan shows or what it is called.
///
/// The plan is named "Plan" here rather than after itself: the legend reads
/// each overlay as `Depth · <name>`, and beside `Depth · <computer>` a plan
/// named after its own depth and date reads as a second depth source.
PlannedProfileForChart watchPlannedProfileForChart(
  BuildContext context,
  WidgetRef ref,
  String diveId,
) {
  // `.value` keeps the previous plan on screen while the provider reloads
  // behind a detail change tick, like the chart's other async inputs (#1468).
  final planned = ref.watch(
    plannedProfileOverlayProvider(diveId).select((a) => a.value),
  );
  if (planned == null) return (overlay: null, available: false);
  final show = ref.watch(
    profileLegendProvider.select((s) => s.showPlannedProfile),
  );
  return (
    overlay: show
        ? planned.copyWith(name: context.l10n.diveLog_legend_label_plan)
        : null,
    available: true,
  );
}
