import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show DivePlanSummary;
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
    if (row.hasSeveralDives)
      context.l10n.plannerSeries_saved_diveCount(row.dives.length),
    if (depth != null) units.formatDepth(depth),
    if (runtime != null) '${(runtime / 60).ceil()}′',
  ].join(' · ');
}

/// The dives of a saved plan, each a line under its row that opens the plan on
/// that dive (issue #3565). A dive in the log links to it there. One that has
/// been dived shows the solid diver, what happened, and what was planned.
class SavedSeriesDiveLines extends ConsumerWidget {
  const SavedSeriesDiveLines({
    super.key,
    required this.row,
    required this.units,
    required this.onOpen,
    required this.onOpenInLog,
  });

  final SavedPlanRow row;
  final UnitFormatter units;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onOpenInLog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final logged = [
      for (final dive in row.dives)
        switch (dive.linkedDiveId) {
          final id? => ref.watch(diveProvider(id)).value,
          null => null,
        },
    ];
    final dived = logged.where((d) => d != null && !d.isPlanned).length;

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dived > 0 && row.hasSeveralDives)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, bottom: 4),
              child: Text(
                l10n.plannerSeries_saved_dived(dived, row.dives.length),
                key: ValueKey('savedSeriesDived_${row.plan.id}'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          for (final (index, dive) in row.dives.indexed)
            _line(context, dive, index, logged[index]),
        ],
      ),
    );
  }

  String _figures(DateTime? start, double? depth, int? seconds) => [
    if (start != null) units.formatDateTimeBullet(start),
    if (depth != null) units.formatDepth(depth),
    if (seconds != null) '${(seconds / 60).ceil()}′',
  ].join(' · ');

  Widget _line(
    BuildContext context,
    DivePlanSummary dive,
    int index,
    Dive? logged,
  ) {
    final l10n = context.l10n;
    final letter = seriesDiveLetter(index);
    final planned = _figures(
      dive.startDateTime,
      dive.maxDepth,
      dive.runtimeSeconds,
    );
    final isDived = logged != null && !logged.isPlanned;
    final number = logged?.diveNumber;
    final divedName = (logged?.name?.isNotEmpty ?? false)
        ? logged!.name!
        : number != null
        ? '#$number'
        : letter;
    return ListTile(
      key: ValueKey('savedSeriesDive_${dive.id}'),
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: isDived
          ? const Icon(Icons.scuba_diving, size: 20)
          : const PlannedDiveIcon(size: 20),
      title: Text(isDived ? divedName : dive.diveName ?? letter),
      subtitle: Text(
        isDived
            ? [
                _figures(
                  logged.effectiveEntryTime,
                  logged.maxDepth,
                  logged.effectiveRuntime?.inSeconds,
                ),
                if (planned.isNotEmpty)
                  l10n.plannerSeries_saved_planned(planned),
              ].join('\n')
            : planned,
      ),
      trailing: logged == null
          ? null
          : IconButton(
              icon: const Icon(Icons.open_in_new, size: 18),
              tooltip: l10n.plannerSeries_openInLog,
              onPressed: () => onOpenInLog(logged.id),
            ),
      onTap: () => onOpen(dive.id),
    );
  }
}
