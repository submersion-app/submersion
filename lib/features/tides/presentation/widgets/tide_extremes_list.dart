import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_chart_colors.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The highs and lows around a dive, one per row, in time order.
///
/// [extremes] carry times already mapped to the clock they are shown in (the
/// dive site's wall clock). A time on a different day from [day] is prefixed
/// with its weekday, since the window around a dive spans two dates.
///
/// Two columns when there is room, read down the first and then the second.
class TideExtremesList extends StatelessWidget {
  const TideExtremesList({
    super.key,
    required this.extremes,
    required this.units,
    required this.day,
  });

  final List<TideExtreme> extremes;
  final UnitFormatter units;

  /// The dive's own date, in the same clock as [extremes].
  final DateTime day;

  /// At this width and beyond the rows are split into two columns.
  static const double twoColumnWidth = 440;

  @override
  Widget build(BuildContext context) {
    if (extremes.isEmpty) return const SizedBox.shrink();
    final rows = [for (final extreme in extremes) _row(context, extreme)];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < twoColumnWidth || rows.length < 2) {
          return Column(mainAxisSize: MainAxisSize.min, children: rows);
        }
        final firstColumn = (rows.length + 1) ~/ 2;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: rows.sublist(0, firstColumn),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: rows.sublist(firstColumn),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(BuildContext context, TideExtreme extreme) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final colors = TideChartColors.of(context);
    final isHigh = extreme.type == TideExtremeType.high;
    final color = isHigh ? colors.high : colors.low;

    final time = DateFormat(
      units.settings.timeFormat.pattern,
    ).format(extreme.time);
    final onDiveDay =
        extreme.time.year == day.year &&
        extreme.time.month == day.month &&
        extreme.time.day == day.day;
    final when = onDiveDay
        ? time
        : '${DateFormat('EEE').format(extreme.time)} $time';
    final height = units.formatDepth(extreme.heightMeters, decimals: 2);

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              isHigh ? l10n.tides_label_high : l10n.tides_label_low,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$when · $height',
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
