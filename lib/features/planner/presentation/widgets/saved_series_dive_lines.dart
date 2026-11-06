import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/utils/saved_plan_rows.dart';
import 'package:submersion/features/planner/presentation/plan_link_actions.dart';
import 'package:submersion/features/planner/presentation/widgets/planned_dive_icon.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What a saved plans row says under its name: the dive count for a series,
/// and how many have been dived once any have, then the depth and runtime,
/// in the diver's own units. A plan's link badge is left to the caller,
/// since a series shows one on each dive instead.
String savedPlanRowSubtitle(
  BuildContext context,
  SavedPlanRow row,
  UnitFormatter units,
) {
  final depth = row.maxDepth;
  final runtime = row.runtimeSeconds;
  // Dived: linked to an entry still in the log that is no longer planned.
  final dived = row.dives
      .where(
        (d) =>
            d.linkedDiveId != null &&
            d.linkedDiveExists &&
            !d.linkedDiveIsPlanned,
      )
      .length;
  return [
    if (row.showsDives)
      dived == 0
          ? context.l10n.plannerSeries_saved_diveCount(row.dives.length)
          : context.l10n.plannerSeries_saved_divedCount(
              dived,
              row.dives.length,
            ),
    if (depth != null) units.formatDepth(depth),
    if (runtime != null) '${(runtime / 60).ceil()}′',
  ].join(' · ');
}

/// The dives of a saved series, each a line under its row that opens the
/// series on that dive (issue #3565). Each carries what it was dived as, and
/// with [linkActions] its own Link and Unlink: a link is one dive's, never
/// the series'. A dive in the log opens its entry there through [onOpenInLog]
/// (issue #3565).
class SavedSeriesDiveLines extends ConsumerWidget {
  const SavedSeriesDiveLines({
    super.key,
    required this.row,
    required this.units,
    required this.onOpen,
    required this.onOpenInLog,
    this.linkActions = false,
  });

  final SavedPlanRow row;
  final UnitFormatter units;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onOpenInLog;
  final bool linkActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, dive) in row.dives.indexed)
            ListTile(
              key: ValueKey('savedSeriesDive_${dive.id}'),
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: const PlannedDiveIcon(size: 20),
              title: Text(dive.diveName ?? seriesDiveLetter(index)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      if (dive.maxDepth != null)
                        units.formatDepth(dive.maxDepth!),
                      if (dive.runtimeSeconds != null)
                        '${(dive.runtimeSeconds! / 60).ceil()}′',
                    ].join(' · '),
                  ),
                  if (planLinkBadge(context.l10n, dive, units)
                      case final badge?)
                    PlanLinkBadge(
                      label: badge,
                      onOpen: switch (dive.linkedDiveId) {
                        final id? => () => onOpenInLog(id),
                        null => null,
                      },
                    ),
                ],
              ),
              trailing: linkActions ? _LinkMenu(dive: dive) : null,
              onTap: () => onOpen(dive.id),
            ),
        ],
      ),
    );
  }
}

/// Link, Change and Unlink for one dive of a series.
class _LinkMenu extends ConsumerWidget {
  const _LinkMenu({required this.dive});

  final DivePlanSummary dive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'link') {
          logFailure(
            pickDiveAndLink(context, ref, planId: dive.id),
            SavedSeriesDiveLines,
            'link plan to dive',
          );
        } else if (value == 'unlink') {
          logFailure(
            unlinkPlanWithConfirm(context, ref, planId: dive.id),
            SavedSeriesDiveLines,
            'unlink plan',
          );
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'link',
          child: Text(
            dive.linkedDiveId == null
                ? l10n.plannerCanvas_link_action
                : l10n.plannerCanvas_link_changeAction,
          ),
        ),
        if (dive.linkedDiveId != null)
          PopupMenuItem(
            value: 'unlink',
            child: Text(l10n.plannerCanvas_unlink_action),
          ),
      ],
    );
  }
}

/// A linked plan's mark: what it was dived as. A linked plan is read as saved,
/// so an edit changes the comparison, and this is how the diver knows. With
/// [onOpen] it opens the linked dive in the log (issue #3565), the planned
/// entry or the dived one.
class PlanLinkBadge extends StatelessWidget {
  const PlanLinkBadge({super.key, required this.label, this.onOpen});

  final String label;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final badge = _badge(color, theme);
    if (onOpen == null) return badge;
    return Tooltip(
      message: context.l10n.plannerSeries_openInLog,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onOpen,
        child: badge,
      ),
    );
  }

  Widget _badge(Color color, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
