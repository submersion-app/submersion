import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/bidi_isolate.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_band.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// One stretch of the net buoyancy line that stays on one side of neutral
/// (issue #4593). Consecutive runs on opposite sides share their crossing
/// point, interpolated to exactly 0 kg, so the line has no break where its
/// colour changes.
@immutable
class BuoyancyRun {
  /// True for the buoyant side (net above 0); false for the heavy side. A
  /// run that never leaves 0 counts as buoyant.
  final bool buoyant;

  /// Points in (seconds, kilograms), in time order.
  final List<({double t, double kg})> points;

  const BuoyancyRun({required this.buoyant, required this.points});
}

/// Smallest span of the buoyancy axis, in kilograms, so a dive that stays
/// near neutral is not stretched into noise.
const double _minAxisSpanKg = 1.0;

/// Padding added above and below the data, as a fraction of its span.
const double _axisPadFraction = 0.1;

/// The value range the buoyancy line is drawn against, in kilograms.
///
/// Always contains 0, so the neutral rule is on the plot even for a dive
/// that is heavy throughout. Null when fewer than two finite values exist.
({double min, double max})? buoyancyAxisRange(List<double?> curveKg) {
  // One pass with no copy: the chart asks for this on every analysis rebuild.
  var count = 0;
  var lo = 0.0;
  var hi = 0.0;
  for (final v in curveKg) {
    if (v == null || !v.isFinite) continue;
    count++;
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  if (count < 2) return null;
  final pad = (hi - lo) * _axisPadFraction;
  lo -= pad;
  hi += pad;
  final span = hi - lo;
  if (span < _minAxisSpanKg) {
    final extra = (_minAxisSpanKg - span) / 2;
    lo -= extra;
    hi += extra;
  }
  return (min: lo, max: hi);
}

/// Splits the net buoyancy curve into runs of one side of neutral.
///
/// [curveKg] and [timestamps] are parallel. A null or non-finite value ends
/// the current run and leaves a gap. A value of exactly 0 belongs to the run
/// it sits in; a run that starts at 0 takes the side it moves to. Runs with
/// fewer than two points draw nothing and are dropped.
List<BuoyancyRun> buoyancySignRuns(
  List<double?> curveKg,
  List<int> timestamps,
) {
  final runs = <BuoyancyRun>[];
  var points = <({double t, double kg})>[];
  bool? side;

  void close() {
    if (points.length >= 2) {
      runs.add(BuoyancyRun(buoyant: side ?? true, points: points));
    }
    points = [];
    side = null;
  }

  final n = math.min(curveKg.length, timestamps.length);
  for (var i = 0; i < n; i++) {
    final kg = curveKg[i];
    if (kg == null || !kg.isFinite) {
      close();
      continue;
    }
    final t = timestamps[i].toDouble();
    final valueSide = kg > 0 ? true : (kg < 0 ? false : null);
    if (valueSide != null && side != null && valueSide != side) {
      final prev = points.last;
      final tc = prev.t + (t - prev.t) * (0 - prev.kg) / (kg - prev.kg);
      final crossing = (t: tc, kg: 0.0);
      if (prev != crossing) points.add(crossing);
      close();
      points.add(crossing);
    }
    side ??= valueSide;
    points.add((t: t, kg: kg));
  }
  close();
  return runs;
}

/// [picked] (sample indices the decimation kept, ascending) with the first
/// index of every gap in [curveKg] added, so the line still breaks there. A
/// gap is a missing or non-finite value, as [buoyancySignRuns] reads it.
/// Only the first [length] samples (the drawn profile's) are scanned.
///
/// Decimation sees gaps as 0 and keeps each bucket's extremes; a gap between
/// a heavy and a buoyant sample is neither, and dropping it would bridge the
/// missing data.
List<int> keepBuoyancyGaps(
  List<int> picked,
  List<double?> curveKg, {
  int? length,
}) {
  bool isGap(int i) => !(curveKg[i]?.isFinite ?? false);
  final n = math.min(curveKg.length, length ?? curveKg.length);
  final gapStarts = <int>[
    for (var i = 0; i < n; i++)
      if (isGap(i) && (i == 0 || !isGap(i - 1))) i,
  ];
  if (gapStarts.isEmpty) return picked;
  return ({...picked, ...gapStarts}.toList()..sort());
}

/// One chart bar per run, mapped into [band] against [range], buoyant runs in
/// [buoyant] and heavy runs in [heavy]. No fill: the depth trace stays
/// uncovered.
List<LineChartBarData> buildBuoyancyLines({
  required List<BuoyancyRun> runs,
  required MetricBand band,
  required ({double min, double max}) range,
  required Color buoyant,
  required Color heavy,
}) => [
  for (final run in runs)
    LineChartBarData(
      spots: [
        for (final p in run.points)
          FlSpot(p.t, -band.map(p.kg, range.min, range.max)),
      ],
      isCurved: false,
      color: run.buoyant ? buoyant : heavy,
      // A touch wider than the other metric lines, so the two colours read
      // at a glance.
      barWidth: 1.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
    ),
];

/// The dashed neutral rule (0 kg) across [minX]..[maxX], drawn while the
/// buoyancy line is shown.
LineChartBarData buildNeutralRule({
  required MetricBand band,
  required ({double min, double max}) range,
  required double minX,
  required double maxX,
  required Color color,
}) {
  final y = -band.map(0, range.min, range.max);
  return LineChartBarData(
    spots: [FlSpot(minX, y), FlSpot(maxX, y)],
    isCurved: false,
    color: color,
    barWidth: 0.75,
    dashArray: const [4, 3],
    dotData: const FlDotData(show: false),
  );
}

/// The tooltip value for a net buoyancy of [kg]: one decimal in the diver's
/// weight unit, signed, with the side named in words so colour is never the
/// only cue ("+0.9 kg buoyant", "-2.4 kg heavy", "0.0 kg neutral").
///
/// In right-to-left text ([direction]) the value is isolated, so bidi
/// reordering cannot move its sign to the far end of the number.
String formatBuoyancyReadout(
  double kg,
  UnitFormatter units,
  AppLocalizations l10n, {
  TextDirection direction = TextDirection.ltr,
}) {
  final display = units.convertWeight(kg);
  final rounded = double.parse(display.toStringAsFixed(1));
  if (rounded == 0) {
    return l10n.diveLog_buoyancy_readout_neutral(
      isolateForDirection(
        '${formatFixedForDisplay(0, 1)} ${units.weightSymbol}',
        direction,
      ),
    );
  }
  final number = formatFixedForDisplay(rounded, 1);
  final value = isolateForDirection(
    '${rounded > 0 ? '+' : ''}$number ${units.weightSymbol}',
    direction,
  );
  return rounded > 0
      ? l10n.diveLog_buoyancy_readout_buoyant(value)
      : l10n.diveLog_buoyancy_readout_heavy(value);
}
