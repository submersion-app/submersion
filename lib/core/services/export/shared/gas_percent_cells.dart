import 'dart:math';

import 'package:submersion/core/services/export/csv/codec/csv_text.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The O2 and He cells of a gas mix: percent at one decimal, trailing zeros
/// removed, so a whole mix still reads `32` and `0`.
///
/// Rounding each gas on its own can lift the pair past 100 % (10.25 and 89.75
/// become 10.3 and 89.8), which reads back as a gas with negative nitrogen
/// (issue #4007). Helium gives way, so the cells never total more than 100:
/// oxygen is the number a diver analyzes and plans around.
({String o2, String he}) gasPercentCells(double o2, double he) {
  final o2Shown = _oneDecimal(o2);
  return (
    o2: trimFixed(o2Shown, 1),
    he: trimFixed(min(_oneDecimal(he), max(0.0, 100 - o2Shown)), 1),
  );
}

/// [gasPercentCells] for [mix], or null when there is no mix.
({String o2, String he})? gasMixCells(GasMix? mix) =>
    mix == null ? null : gasPercentCells(mix.o2, mix.he);

double _oneDecimal(double percent) => double.parse(percent.toStringAsFixed(1));
