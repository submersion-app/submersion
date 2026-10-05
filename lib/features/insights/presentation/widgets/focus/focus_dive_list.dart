import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor_row.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_factor_labels.dart';
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
    return Column(
      children: [
        for (var i = 0; i < members.length; i++)
          _FocusDiveRow(
            key: ValueKey('focus-dive-${members[i].diveId}'),
            dive: members[i],
            row: rows[members[i].diveId],
            metricUnits: metricUnits,
            rank: ranked ? i + 1 : null,
          ),
      ],
    );
  }
}

/// One dive in the group: its site, date, depth and duration, and its value
/// of the metric. Tapping opens the dive.
class _FocusDiveRow extends StatelessWidget {
  const _FocusDiveRow({
    super.key,
    required this.dive,
    required this.row,
    required this.metricUnits,
    required this.rank,
  });

  final TrendDataPoint dive;
  final FocusFactorRow? row;
  final FocusMetricUnits metricUnits;

  /// Shown in front of the row in a ranked group; null otherwise.
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = metricUnits.units;
    final maxDepth = row?.maxDepth;
    final minutes = row?.durationMinutes;
    final details = [
      units.formatDate(dive.date),
      if (maxDepth != null) units.formatDepth(maxDepth),
      if (minutes != null)
        focusNumericValue(FocusFactorId.duration, minutes, units, l10n),
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: rank == null ? null : Text('$rank'),
      title: Text(row?.siteName ?? l10n.insights_focus_list_unknownSite),
      subtitle: Text(details),
      trailing: Text(
        metricUnits.format(dive.value, l10n),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      onTap: () => context.push('/dives/${dive.diveId}'),
    );
  }
}
