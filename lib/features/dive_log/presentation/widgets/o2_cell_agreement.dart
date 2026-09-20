import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_cell_readout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_cell_spread.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_band.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Smoothed cell spread (max minus min) for every sample.
///
/// Smoothed because millivolts are whole numbers: without it the ribbon
/// flickers a full millivolt wider and narrower on pure rounding.
List<double?> computeO2CellSpread(
  List<List<int?>> mvCurves,
  List<DiveProfilePoint> profile,
) {
  final window = o2CellSpreadWindowSamples([
    for (final p in profile) p.timestamp,
  ]);
  return smoothO2CellSpread([
    computeO2CellRange(mvCurves),
  ], windowSamples: window).single;
}

/// Cell spread at one sample, for the tooltip. Null when fewer than two cells
/// reported there.
double? o2CellRangeAt(List<double?> spread, int sampleIndex) {
  if (sampleIndex >= spread.length) return null;
  return spread[sampleIndex];
}

/// Colour for one agreement level, traffic-light coded so the verdict reads
/// without decoding a legend. Tight is deliberately quiet despite being
/// green: a healthy rig is in that state for essentially the whole dive, so
/// it must read as background, not as a series demanding attention.
Color agreementColor(O2CellAgreement level) => switch (level) {
  O2CellAgreement.tight => const Color(0xFF66BB6A).withValues(alpha: 0.55),
  O2CellAgreement.drifting => const Color(0xFFFFCA28),
  O2CellAgreement.wide => const Color(0xFFE57373),
};

/// The rug's caption. Held here so the track and the tooltip cannot diverge.
String l10nO2CellSpreadLabel(AppLocalizations l10n) =>
    l10n.diveLog_o2CellSpread_label;

String agreementWord(O2CellAgreement level, AppLocalizations l10n) =>
    switch (level) {
      O2CellAgreement.tight => l10n.diveLog_tooltip_o2CellsTight,
      O2CellAgreement.drifting => l10n.diveLog_tooltip_o2CellsDrifting,
      O2CellAgreement.wide => l10n.diveLog_tooltip_o2CellsWide,
    };

/// "tight (1 mV)" -- a verdict backed by the number, rather than a number the
/// reader has to know how to judge.
String? o2CellAgreementReadout(double? spread, AppLocalizations l10n) {
  if (spread == null) return null;
  final level = o2CellAgreementFor(spread);
  return '${agreementWord(level, l10n)} (${spread.toStringAsFixed(0)} mV)';
}

/// One row per physical cell -- ppO2 when the calibration is trustworthy,
/// the raw output when it is not, both when both are available -- plus the
/// agreement verdict row (#810). Shared by both tooltip layouts so they
/// cannot drift apart; callers must gate this on `_showPpO2 || _showO2CellMv`
/// themselves, since a mobile-vs-desktop caller may need to skip building an
/// empty section wrapper when there is nothing to show.
List<TooltipRow> buildO2CellTooltipRows(
  int spotIndex,
  List<List<double?>>? o2SensorCurves,
  List<List<int?>>? o2CellMvCurves,
  double? spreadAtSpot,
  AppLocalizations l10n,
) {
  final rows = <TooltipRow>[];
  final cellCount = o2CellCount(
    barCurves: o2SensorCurves,
    mvCurves: o2CellMvCurves,
  );
  for (var cell = 0; cell < cellCount; cell++) {
    final readout = formatO2CellReadout(
      bar: valueAtSample(
        curves: o2SensorCurves,
        cell: cell,
        sampleIndex: spotIndex,
      ),
      millivolt: valueAtSample(
        curves: o2CellMvCurves,
        cell: cell,
        sampleIndex: spotIndex,
      ),
      barUnit: l10n.units_pressure_bar,
      millivoltUnit: l10n.units_profileMetric_millivolts,
    );
    if (readout == null) continue;
    rows.add(
      TooltipRow(
        label: '${l10n.diveLog_tooltip_sensor} ${cell + 1}',
        value: readout,
        bulletColor: o2CellColor(cell),
      ),
    );
  }
  final agreement = o2CellAgreementReadout(spreadAtSpot, l10n);
  if (agreement != null) {
    rows.add(
      TooltipRow(
        label: l10nO2CellSpreadLabel(l10n),
        value: agreement,
        bulletColor: agreementColor(o2CellAgreementFor(spreadAtSpot!)),
      ),
    );
  }
  return rows;
}

/// Depth, in the band's units, at which the agreement rug sits.
double o2CellRugDepth(MetricBand band) => band.top + band.span * 0.985;

/// A faint full-width groove behind the rug, captioned with what it is.
///
/// Without it the rug is a bare mark: a healthy dive draws one quiet segment
/// and nothing distinguishes "checked, and the cells agreed" from "this line
/// is left over from something". The groove shows the readout is present and
/// the caption says what is being read.
List<HorizontalLine> buildO2CellRugTrack(
  MetricBand band,
  ColorScheme colorScheme, {
  required bool showO2CellMv,
  required List<List<int?>>? o2CellMvCurves,
  required AppLocalizations l10n,
}) {
  if (!showO2CellMv) return const [];
  if (o2CellMvCurves == null) return const [];

  return [
    HorizontalLine(
      y: -o2CellRugDepth(band),
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.18),
      strokeWidth: 3,
      label: HorizontalLineLabel(
        show: true,
        alignment: Alignment.topLeft,
        padding: const EdgeInsets.only(left: 4, bottom: 2),
        style: TextStyle(
          fontSize: 9,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        labelResolver: (_) => l10nO2CellSpreadLabel(l10n),
      ),
    ),
  ];
}

/// Cell agreement over time, as a strip pinned to the bottom edge of the plot.
///
/// Not an object floating in the chart's vertical space: that space belongs to
/// depth, so anything drawn in it has no anchor the eye can use and reads as a
/// slab. A rug on the edge costs no depth range, competes with nothing, and
/// encodes the whole dive's agreement in a band you read left to right.
///
/// One segment per run rather than per sample, so a steady dive is a single
/// bar however long it is.
List<LineChartBarData> buildO2CellRug(
  MetricBand band,
  List<List<int?>>? mvCurves,
  List<DiveProfilePoint> profile,
  List<double?> Function(List<List<int?>>) o2CellSpread,
) {
  if (mvCurves == null) return const [];

  final spread = o2CellSpread(mvCurves);
  final runs = o2CellAgreementRuns(spread);
  if (runs.isEmpty) return const [];

  final y = -o2CellRugDepth(band);
  final lastSample = profile.length - 1;

  final bars = <LineChartBarData>[];
  for (final run in runs) {
    if (run.startIndex > lastSample) continue;
    final from = profile[run.startIndex].timestamp.toDouble();
    final to = profile[run.endIndex.clamp(0, lastSample)].timestamp.toDouble();
    bars.add(
      LineChartBarData(
        // A run of one sample would be a zero-length line and draw nothing,
        // so give it the width of one sampling interval.
        spots: [FlSpot(from, y), FlSpot(to > from ? to : from + 1, y)],
        isCurved: false,
        color: agreementColor(run.level),
        // Exception marking: a wide gap is drawn heavier so it is visible
        // without hunting for a colour change.
        barWidth: run.level == O2CellAgreement.tight ? 3 : 6,
        isStrokeCapRound: false,
        dotData: const FlDotData(show: false),
      ),
    );
  }
  return bars;
}

/// Per-cell millivolt lines, drawn alongside the agreement rug: the rug
/// reads the whole dive at a glance, the lines give the detail behind it.
/// On an absolute scale the ppO2 swing dominates and the disagreement
/// between cells is invisible, which is why the rug exists at all.
List<LineChartBarData> buildO2CellMvLines(
  MetricBand band,
  List<List<int?>>? mvCurves,
  List<DiveProfilePoint> profile,
  ({double min, double max})? range,
  List<int> Function(List<int?>) decimatedNullableCurveIndices,
) {
  if (mvCurves == null) return const [];
  if (range == null || range.max <= range.min) return const [];

  final lines = <LineChartBarData>[];
  for (var cell = 0; cell < mvCurves.length; cell++) {
    final curve = mvCurves[cell];
    final spots = <FlSpot>[];
    for (final i in decimatedNullableCurveIndices(curve)) {
      final mv = curve[i]!;
      spots.add(
        FlSpot(
          profile[i].timestamp.toDouble(),
          -band.map(
            mv.toDouble().clamp(range.min, range.max),
            range.min,
            range.max,
          ),
        ),
      );
    }
    if (spots.isEmpty) continue;
    lines.add(
      LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.2,
        color: o2CellColor(cell),
        barWidth: 1.5,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
      ),
    );
  }
  return lines;
}
