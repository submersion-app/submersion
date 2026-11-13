import 'dart:ui';

import 'package:submersion/core/utils/minutes_seconds.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_palette.dart';
import 'package:submersion/features/dive_log/presentation/widgets/deco_stop_band.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart'
    show TooltipRow;
import 'package:submersion/features/dive_log/presentation/widgets/profile_cursor_tooltip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// What the pinned strip's last slot shows at the cursor: the no-deco limit,
/// the current stop once in deco, or nothing known.
///
/// Read from the same `DecoStatus` the deco status card reads, so the strip
/// always agrees with that card (issue #4423).
sealed class DecoSlot {
  const DecoSlot();
}

class NdlSlot extends DecoSlot {
  const NdlSlot(this.ndlSeconds);

  final int ndlSeconds;
}

class StopSlot extends DecoSlot {
  const StopSlot({required this.depthMeters, required this.durationSeconds});

  final double depthMeters;
  final int durationSeconds;
}

class UnknownDecoSlot extends DecoSlot {
  const UnknownDecoSlot();
}

/// The values the pinned profile strip shows at one cursor position, in
/// metric and unformatted.
class PinnedStripValues {
  const PinnedStripValues({
    required this.runtimeSeconds,
    required this.depthMeters,
    required this.ppO2Bar,
    required this.deco,
    this.ceilingMeters,
  });

  final int runtimeSeconds;
  final double? depthMeters;
  final double? ppO2Bar;
  final DecoSlot deco;

  /// The ceiling at the cursor, from the analysis the chart draws; null when
  /// it is not known there.
  final double? ceilingMeters;
}

/// The strip's values at [cursorIndex], or null when there is no cursor.
///
/// [cursorIndex] indexes [chartProfile], the series the chart draws (the
/// active source's own points, #543), and the analysis curves are read at the
/// same index. A value is read straight from that index rather than looked up
/// by time, so two samples sharing a timestamp cannot swap.
PinnedStripValues? pinnedStripValuesAt({
  required List<DiveProfilePoint> chartProfile,
  required ProfileAnalysis? analysis,
  required int? cursorIndex,
}) {
  final i = cursorIndex;
  if (i == null || i < 0 || i >= chartProfile.length) return null;
  final point = chartProfile[i];

  T? curveAt<T>(List<T>? curve) =>
      (curve != null && i < curve.length) ? curve[i] : null;

  return PinnedStripValues(
    runtimeSeconds: point.timestamp,
    depthMeters: point.depth,
    ppO2Bar: curveAt(analysis?.ppO2Curve) ?? point.ppO2,
    deco: _decoSlotAt(analysis, i),
    ceilingMeters: curveAt(analysis?.ceilingCurve),
  );
}

/// The deco slot at [index]. NDL is read from the analysis's NDL curve, the
/// one the strip draws its NDL line from (which carries the computer's own
/// NDL where the dive has one), so the readout follows the line; the stop is
/// read from the model's status, the only source of a stop's duration.
DecoSlot _decoSlotAt(ProfileAnalysis? analysis, int index) {
  final curve = analysis?.ndlCurve;
  final ndl = curve != null && index < curve.length ? curve[index] : null;
  if (ndl != null && ndl > 0) return NdlSlot(ndl);
  final statuses = analysis?.decoStatuses;
  if (statuses == null || index >= statuses.length) {
    return const UnknownDecoSlot();
  }
  final status = statuses[index];
  if (!status.inDeco) {
    // Zero is the limit reached, still no deco (inDeco is NDL below zero).
    // Only a curve in deco where the model is not leaves no stop to show.
    if (ndl == null) return NdlSlot(status.ndlSeconds);
    return ndl >= 0 ? NdlSlot(ndl) : const UnknownDecoSlot();
  }
  if (status.decoStops.isEmpty) return const UnknownDecoSlot();
  final stop = status.decoStops.first;
  return StopSlot(
    depthMeters: stop.depthMeters,
    durationSeconds: stop.durationSeconds,
  );
}

const _missing = '--';

/// The pinned strip's tooltip rows at one cursor position (issue #4509):
/// Time, Depth and ppO2, then NDL, or the deco stop and ceiling in deco.
///
/// Labels are the full chart's tooltip labels, and each bullet is the colour
/// the strip draws that line in: [palette], the diver's chart colours, or
/// the defaults without one.
List<TooltipRow> pinnedStripTooltipRows(
  PinnedStripValues values,
  UnitFormatter units,
  AppLocalizations l10n, {
  ProfileMetricPalette? palette,
}) {
  Color colorOf(ProfileMetric metric) =>
      palette?.colorOf(metric) ?? metric.defaultColor!;
  final ppO2 = values.ppO2Bar;
  final ceiling = values.ceilingMeters;
  return [
    TooltipRow(
      label: l10n.diveLog_tooltip_time,
      value: formatMinutesSeconds(values.runtimeSeconds),
      bulletColor: tooltipTextColor.withValues(alpha: 0.5),
    ),
    TooltipRow(
      label: l10n.diveLog_tooltip_depth,
      value: units.formatDepth(values.depthMeters),
      bulletColor: colorOf(ProfileMetric.depth),
    ),
    TooltipRow(
      label: l10n.diveLog_tooltip_ppO2,
      // With its unit, as the full chart's tooltip reads it.
      value: ppO2 == null
          ? _missing
          : '${ppO2.toStringAsFixed(2)} ${l10n.units_pressure_bar}',
      bulletColor: colorOf(ProfileMetric.ppO2),
    ),
    ...switch (values.deco) {
      NdlSlot(:final ndlSeconds) => [
        TooltipRow(
          label: l10n.diveLog_tooltip_ndl,
          // Past 99 minutes is the analysis's "no limit" range (999 at the
          // surface), so it reads as more than 99 rather than a literal
          // figure.
          value: l10n.diveLog_deco_minutesValue(
            ndlSeconds > 99 * 60 ? '>99' : '${ndlSeconds ~/ 60}',
          ),
          bulletColor: colorOf(ProfileMetric.ndl),
        ),
      ],
      // Rounded up, as the deco status card's stop chips are.
      StopSlot(:final depthMeters, :final durationSeconds) => [
        TooltipRow(
          label: l10n.diveLog_tooltip_decoStop,
          value:
              '${units.formatDepth(depthMeters, decimals: 0)} · '
              '${l10n.diveLog_deco_minutesValue('${(durationSeconds / 60).ceil()}')}',
          bulletColor: decoStopBandColor,
        ),
        TooltipRow(
          label: l10n.diveLog_tooltip_ceiling,
          value: ceiling == null ? _missing : units.formatDepth(ceiling),
          bulletColor: colorOf(ProfileMetric.ceiling),
        ),
      ],
      UnknownDecoSlot() => [
        TooltipRow(
          label: l10n.diveLog_tooltip_ndl,
          value: _missing,
          bulletColor: colorOf(ProfileMetric.ndl),
        ),
      ],
    },
  ];
}
