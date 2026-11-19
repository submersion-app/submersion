import 'package:flutter/widgets.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_avelo_lines.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_buoyancy_line.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The chart readout's rows for the Avelo lines (issue #4664), one per line
/// [shown] says is drawn, read from [point], the sample under the cursor.
/// A sample the computer left blank reads '-'.
List<TooltipRow> aveloReadoutRows({
  required DiveProfilePoint? point,
  required bool Function(ProfileRightAxisMetric metric) shown,
  required AppLocalizations l10n,
  required UnitFormatter units,
  required TextDirection direction,
  required Color Function(ProfileMetric metric) colorOf,
}) => [
  for (final metric in aveloLineMetrics)
    if (shown(metric))
      switch (metric) {
        ProfileRightAxisMetric.aveloBuoyancy => TooltipRow(
          label: l10n.diveLog_legend_label_aveloBuoyancy,
          value: switch (point?.aveloBuoyancy) {
            final kg? => formatBuoyancyReadout(
              kg,
              units,
              l10n,
              direction: direction,
            ),
            null => '-',
          },
          bulletColor: colorOf(ProfileMetric.aveloBuoyancy),
          metric: metric,
        ),
        ProfileRightAxisMetric.aveloGasRemaining => TooltipRow(
          label: l10n.diveLog_legend_label_aveloGasRemaining,
          value: switch (point?.aveloGasRemaining) {
            final percent? => '$percent%',
            null => '-',
          },
          bulletColor: colorOf(ProfileMetric.aveloGasRemaining),
          metric: metric,
        ),
        _ => TooltipRow(
          label: l10n.diveLog_legend_label_computerRmv,
          value: switch (point?.computerRmv) {
            final rmv? => units.formatRmv(rmv),
            null => '-',
          },
          bulletColor: colorOf(ProfileMetric.computerRmv),
          metric: metric,
        ),
      },
];
