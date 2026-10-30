import 'dart:math';

/// A transmitter that loses its link: runs of [pressures] removed so the
/// gaps total about [gapFraction] of the dive. Each gap is far longer than
/// three sample intervals (what the app counts as a dropout), and the first
/// and last readings stay.
List<(int, double)> withDropouts(
  List<(int, double)> pressures, {
  required double gapFraction,
  required Random random,
}) {
  if (pressures.length < 20) return pressures;
  final span = pressures.last.$1 - pressures.first.$1;
  const gaps = 3;
  final gapSeconds = span * gapFraction / gaps;
  final cut = <(int, int)>[];
  for (var g = 0; g < gaps; g++) {
    // Spread through the middle of the dive, clear of the ends.
    final centre =
        pressures.first.$1 +
        span * (0.2 + 0.25 * g + random.nextDouble() * 0.05);
    cut.add((
      (centre - gapSeconds / 2).round(),
      (centre + gapSeconds / 2).round(),
    ));
  }
  return [
    for (final p in pressures)
      if (!cut.any((c) => p.$1 > c.$1 && p.$1 < c.$2)) p,
  ];
}

/// A galvanic cell's output in millivolts at [ppO2] bar, for a cell of
/// [gainMvPerBar] (healthy cells give about 50 mV per bar of oxygen).
int cellMv(double ppO2, double gainMvPerBar) => (ppO2 * gainMvPerBar).round();

/// How a dive's three cells read: a healthy loop reports the real readings;
/// a drifting cell 2 reads low across the dive; a divergent cell 3 reads
/// 0.15 bar high through the middle third of the dive.
List<double>? cellReadings(
  List<double>? cells,
  double progress, {
  bool drifting2 = false,
  bool divergent3 = false,
}) {
  if (cells == null) return null;
  return [
    for (var i = 0; i < cells.length; i++)
      switch (i) {
        1 when drifting2 => _round(cells[i] * 0.88),
        2
            when divergent3 &&
                progress > 0.3 &&
                progress < 0.65 &&
                cells[i] > 0.6 =>
          _round(cells[i] + 0.15),
        _ => cells[i],
      },
  ];
}

double _round(double v) => (v * 100).roundToDouble() / 100;
