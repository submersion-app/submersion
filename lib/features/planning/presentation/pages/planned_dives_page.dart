import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/presentation/widgets/saved_plans_list.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The full saved-plans list as its own page: the phone-width counterpart of
/// the desktop detail pane's "Saved plans" section (issue #3551). A phone
/// has no detail pane to show that content in, so the hub's own row for it
/// opens this page instead; both render the same [SavedPlansList] and share
/// its sort state.
class PlannedDivesPage extends ConsumerWidget {
  const PlannedDivesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.planning_summary_savedPlans),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: l10n.planning_plannedDives_sortTooltip,
            onPressed: () => openSavedPlansSortSheet(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [SavedPlansList()],
      ),
    );
  }
}
