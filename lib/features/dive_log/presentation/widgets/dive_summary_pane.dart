import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_summary_scene.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_summary_widget.dart';
import 'package:submersion/features/insights/presentation/providers/career_totals_provider.dart';
import 'package:submersion/shared/widgets/summary/summary_pane_switcher.dart';

/// What the Dives detail pane shows with no dive selected: the water column
/// scene or the data-rich summary, per Settings > Appearance and the pane's
/// corner toggle.
///
/// An empty log defaults to the summary widget, whose Log Manually and
/// Import buttons are a new diver's way in. A log still loading is not
/// empty, so the pane never flashes from one view to the other on start.
class DiveSummaryPane extends ConsumerWidget {
  const DiveSummaryPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(diveStatisticsProvider).value;
    final career = ref.watch(careerTotalsProvider).value;
    final isEmpty =
        stats != null &&
        career != null &&
        stats.totalDives == 0 &&
        career.combinedDives == 0;

    return SummaryPaneSwitcher(
      sectionId: 'dives',
      isEmpty: isEmpty,
      scene: (_) => const DiveSummaryScene(),
      details: (_) => const DiveSummaryWidget(),
    );
  }
}
