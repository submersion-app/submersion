import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor_row.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_metric_units.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The group's dives, each opening its dive page.
class FocusDiveList extends StatelessWidget {
  const FocusDiveList({
    super.key,
    required this.members,
    required this.rows,
    required this.metricUnits,
    required this.ranked,
  });

  final List<TrendDataPoint> members;
  final Map<String, FocusFactorRow> rows;
  final FocusMetricUnits metricUnits;

  /// Shows a rank number in front of each row.
  final bool ranked;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final UnitFormatter units = metricUnits.units;
    return Column(
      children: [
        for (var i = 0; i < members.length; i++)
          () {
            final dive = members[i];
            final row = rows[dive.diveId];
            final details = [
              units.formatDate(dive.date),
              if (row?.maxDepth != null) units.formatDepth(row!.maxDepth),
              if (row?.durationMinutes != null)
                l10n.surfaceInterval_format_minutes(
                  row!.durationMinutes!.toStringAsFixed(0),
                ),
            ].join(' · ');
            return ListTile(
              key: ValueKey('focus-dive-${dive.diveId}'),
              contentPadding: EdgeInsets.zero,
              leading: ranked ? Text('${i + 1}') : null,
              title: Text(
                row?.siteName ?? l10n.insights_focus_list_unknownSite,
              ),
              subtitle: Text(details),
              trailing: Text(
                metricUnits.format(dive.value, l10n),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              onTap: () => context.push('/dives/${dive.diveId}'),
            );
          }(),
      ],
    );
  }
}
