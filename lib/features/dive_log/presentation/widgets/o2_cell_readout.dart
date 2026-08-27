/// Tooltip formatting for individual CCR O2 cells.
///
/// A cell can report a partial pressure, a raw millivolt output, or both. The
/// millivolt-only case is issue #810: the computer logged a factory-default
/// calibration, so libdivecomputer withholds the conversion rather than anchor
/// it to a placeholder, and only the measurement survives.
library;

import 'package:flutter/material.dart';

/// Per-cell colours, shared by the chart lines and the tooltip bullets so the
/// two can never disagree about which cell is which.
///
/// One ordered ramp rather than unrelated hues: every entry sits at the same
/// Material weight (300), so the cells read as members of one set while staying
/// far enough apart on the wheel to be told apart where the lines overlap.
const List<Color> kO2CellColors = [
  Color(0xFF4DD0E1), // Cyan 300
  Color(0xFF4DB6AC), // Teal 300
  Color(0xFFAED581), // Light Green 300
  Color(0xFFFFF176), // Yellow 300
  Color(0xFFFFB74D), // Orange 300
  Color(0xFFE57373), // Red 300
];

/// Colour for a zero-based cell index, wrapping if a device ever reports more
/// cells than the palette holds.
Color o2CellColor(int cell) => kO2CellColors[cell % kO2CellColors.length];

/// One tooltip row's value for a single cell, or null when the cell reported
/// nothing at this sample.
///
/// [barUnit]/[millivoltUnit] default to the raw symbols so existing callers
/// and tests keep working; pass the localized strings (`l10n.units_pressure_bar`,
/// `l10n.units_profileMetric_millivolts`) from a `BuildContext` when available.
String? formatO2CellReadout({
  required double? bar,
  required int? millivolt,
  String barUnit = 'bar',
  String millivoltUnit = 'mV',
}) {
  if (bar == null && millivolt == null) return null;
  if (bar == null) return '$millivolt $millivoltUnit';
  if (millivolt == null) return '${bar.toStringAsFixed(2)} $barUnit';
  return '${bar.toStringAsFixed(2)} $barUnit ($millivolt $millivoltUnit)';
}

/// How many physical cells to render rows for: the two curve sets can differ in
/// length when one carries a cell the other does not.
int o2CellCount({
  required List<List<double?>>? barCurves,
  required List<List<int?>>? mvCurves,
}) {
  final bars = barCurves?.length ?? 0;
  final mvs = mvCurves?.length ?? 0;
  return bars > mvs ? bars : mvs;
}

/// Reads one cell's value at one sample, tolerating curve sets that are shorter
/// than the cell index or the sample index.
T? valueAtSample<T>({
  required List<List<T?>>? curves,
  required int cell,
  required int sampleIndex,
}) {
  if (curves == null || cell >= curves.length) return null;
  final curve = curves[cell];
  if (sampleIndex >= curve.length) return null;
  return curve[sampleIndex];
}
