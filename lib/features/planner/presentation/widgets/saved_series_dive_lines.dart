import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/utils/saved_plan_rows.dart';
import 'package:submersion/features/planner/presentation/widgets/planned_dive_icon.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What a saved plans row says under its name: the dive count for a series,
/// then the depth and runtime. The diver's own units.
String savedPlanRowSubtitle(
  BuildContext context,
  SavedPlanRow row,
  UnitFormatter units,
) {
  final depth = row.maxDepth;
  final runtime = row.runtimeSeconds;
  return [
    if (row.showsDives)
      context.l10n.plannerSeries_saved_diveCount(row.dives.length),
    if (depth != null) units.formatDepth(depth),
    if (runtime != null) '${(runtime / 60).ceil()}′',
  ].join(' · ');
}

/// The dives of a saved series, each a line under its row that opens the
/// series on that dive (issue #3565).
class SavedSeriesDiveLines extends StatelessWidget {
  const SavedSeriesDiveLines({
    super.key,
    required this.row,
    required this.units,
    required this.onOpen,
  });

  final SavedPlanRow row;
  final UnitFormatter units;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
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
              subtitle: Text(
                [
                  if (dive.startDateTime != null)
                    units.formatDateTimeBullet(dive.startDateTime),
                  if (dive.maxDepth != null) units.formatDepth(dive.maxDepth!),
                  if (dive.runtimeSeconds != null)
                    '${(dive.runtimeSeconds! / 60).ceil()}′',
                ].join(' · '),
              ),
              onTap: () => onOpen(dive.id),
            ),
        ],
      ),
    );
  }
}
