import 'dart:math';

import 'package:submersion/core/services/export/csv/codec/csv_text.dart';

/// The O2 and He cells of a gas mix: percent at one decimal, trailing zeros
/// removed, so a whole mix still reads `32` and `0`.
///
/// Rounding each gas on its own can lift the pair past 100 % (10.25 and 89.75
/// become 10.3 and 89.8), which reads back as a gas with negative nitrogen
/// (issue #4007). Helium gives way, so the cells never total more than 100:
/// oxygen is the number a diver analyzes and plans around.
({String o2, String he}) gasPercentCells(double o2, double he) {
  final o2Tenths = _tenths(o2);
  return (
    o2: trimFixed(o2Tenths / 10, 1),
    he: trimFixed(min(_tenths(he), max(0, 1000 - o2Tenths)) / 10, 1),
  );
}

/// [percent] in whole tenths, rounded the way the cell would show it.
int _tenths(double percent) =>
    (double.parse(percent.toStringAsFixed(1)) * 10).round();
