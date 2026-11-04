import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/presentation/planner_navigation.dart';
import 'package:submersion/features/planner/presentation/providers/plan_log_links.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shown above the header of a planned dive (issue #2002): awaiting dive
/// computer data, with the promote action for a dive made without one, and
/// the way back to the plan it came from while that plan exists (#3565).
class PlannedDiveBanner extends ConsumerWidget {
  final String diveId;
  final VoidCallback onMarkLogged;

  const PlannedDiveBanner({
    super.key,
    required this.diveId,
    required this.onMarkLogged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final planId = ref.watch(planForLoggedDiveProvider(diveId)).value;
    return Card(
      color: scheme.tertiaryContainer,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        // The actions sit under the text: beside it, two of them leave the
        // text no room at phone width.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.event_available_outlined,
                  color: scheme.onTertiaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.diveLog_planned_bannerTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                      Text(
                        context.l10n.diveLog_planned_bannerBody,
                        style: TextStyle(color: scheme.onTertiaryContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              children: [
                TextButton(
                  onPressed: onMarkLogged,
                  child: Text(context.l10n.diveLog_detail_menu_markLogged),
                ),
                if (planId != null)
                  TextButton(
                    onPressed: () => openSavedPlanInPlanner(context, planId),
                    child: Text(context.l10n.diveLog_planned_openInPlanner),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
