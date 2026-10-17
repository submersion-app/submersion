import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_summary_scene.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_summary_widget.dart';
import 'package:submersion/shared/widgets/summary/summary_pane_switcher.dart';

/// What the Dive sites detail pane shows with no site selected: the chart
/// scene or the data-rich summary, per Settings > Appearance and the pane's
/// corner toggle.
///
/// An empty library defaults to the summary widget, whose Add Site and
/// Import buttons are a new diver's way in. A library still loading is not
/// empty, so the pane never flashes from one view to the other on start.
class SiteSummaryPane extends ConsumerWidget {
  const SiteSummaryPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(sitesWithCountsProvider).value;

    return SummaryPaneSwitcher(
      sectionId: 'sites',
      isEmpty: sites != null && sites.isEmpty,
      scene: (_) => const SiteSummaryScene(),
      details: (_) => const SiteSummaryWidget(),
    );
  }
}
