import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';

/// Formatting for the dive computer's own tissue values. Pure functions so
/// the section widget only lays things out.

/// Placeholder for a start or end value the computer did not report.
const computerTissueMissing = '--';

/// Whole-percent text, e.g. `82%`.
String formatTissuePercent(double value) =>
    '${formatFixedForDisplay(value, 0)}%';

/// OTU is a count; shown whole.
String formatTissueOtu(double value) => formatFixedForDisplay(value, 0);

/// Suunto RGBM factors are unitless multipliers around 1.
String formatRgbmFactor(double value) => formatFixedForDisplay(value, 2);

/// A compartment tension in the diver's pressure unit. Tensions sit around
/// 1 to 4 bar, so bar needs two decimals to tell compartments apart and psi
/// needs one.
String formatTissueTension(UnitFormatter units, double bar) {
  final decimals = units.settings.pressureUnit == PressureUnit.bar ? 2 : 1;
  return units.formatPressure(bar, decimals: decimals);
}

/// Aggregate metrics the snapshot's start/end table can carry.
enum ComputerTissueMetric { n2Load, gf99, surfaceGf, cns, otu }

/// One row of the start/end table, values already formatted; null where
/// that instant did not carry the metric.
typedef ComputerTissueAggregateRow = ({
  ComputerTissueMetric metric,
  String? start,
  String? end,
});

/// The rows of the start/end table, in display order, keeping only metrics
/// at least one instant reported.
List<ComputerTissueAggregateRow> aggregateRows(
  ComputerTissueSnapshot snapshot,
) {
  final rows = <ComputerTissueAggregateRow>[];
  for (final metric in ComputerTissueMetric.values) {
    final start = _format(metric, snapshot.start);
    final end = _format(metric, snapshot.end);
    if (start == null && end == null) continue;
    rows.add((metric: metric, start: start, end: end));
  }
  return List.unmodifiable(rows);
}

String? _format(ComputerTissueMetric metric, ComputerTissueState? state) {
  if (state == null) return null;
  final value = switch (metric) {
    ComputerTissueMetric.n2Load => state.n2LoadPercent,
    ComputerTissueMetric.gf99 => state.gf99Percent,
    ComputerTissueMetric.surfaceGf => state.surfaceGfPercent,
    ComputerTissueMetric.cns => state.cnsPercent,
    ComputerTissueMetric.otu => state.otu,
  };
  if (value == null) return null;
  return metric == ComputerTissueMetric.otu
      ? formatTissueOtu(value)
      : formatTissuePercent(value);
}
