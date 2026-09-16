import 'package:submersion/features/statistics/domain/trend_aggregation.dart';

/// Average SAC and bottom time for one water-temperature band (issue #1873).
///
/// [lower] and [upper] follow WaterTempBandCount. [diveCount] is every dive
/// in the band. Each average stands on its own count, since SAC needs tank
/// data and the gas scope: [avgSac] is the mean over [sacDiveCount] dives and
/// [avgBottomMinutes] the mean over [bottomTimeDiveCount] dives. An average
/// is null when no dive in the band has that value, so the band shows a
/// placeholder rather than 0.
typedef WaterTempBandMetrics = ({
  int? lower,
  int? upper,
  int diveCount,
  double? avgSac,
  int sacDiveCount,
  double? avgBottomMinutes,
  int bottomTimeDiveCount,
});

/// Groups per-dive SAC and bottom time into the water-temperature bands.
///
/// [bandByDive] places each dive with a water temperature in a band, as an
/// index into the bands [edges] define. Values for any other dive are
/// ignored, so the averages bin dives exactly as the band counts do. Each
/// dive weighs the same in an average. A bottom time of zero is a missing
/// value, not a 0 min dive. Returns no bands when [bandByDive] is empty,
/// matching the band counts.
List<WaterTempBandMetrics> aggregateWaterTempBandMetrics({
  required List<int> edges,
  required Map<String, int> bandByDive,
  required List<TrendDataPoint> sacPerDive,
  required List<TrendDataPoint> bottomTimePerDive,
}) {
  if (bandByDive.isEmpty) return const [];

  List<double> valuesIn(int band, List<TrendDataPoint> points) => [
    for (final p in points)
      if (bandByDive[p.diveId] == band) p.value,
  ];

  return [
    for (var band = 0; band <= edges.length; band++)
      _bandMetrics(
        lower: band == 0 ? null : edges[band - 1],
        upper: band == edges.length ? null : edges[band],
        diveCount: bandByDive.values.where((b) => b == band).length,
        sacs: valuesIn(band, sacPerDive),
        bottomMinutes: [
          for (final v in valuesIn(band, bottomTimePerDive))
            if (v > 0) v,
        ],
      ),
  ];
}

WaterTempBandMetrics _bandMetrics({
  required int? lower,
  required int? upper,
  required int diveCount,
  required List<double> sacs,
  required List<double> bottomMinutes,
}) => (
  lower: lower,
  upper: upper,
  diveCount: diveCount,
  avgSac: _mean(sacs),
  sacDiveCount: sacs.length,
  avgBottomMinutes: _mean(bottomMinutes),
  bottomTimeDiveCount: bottomMinutes.length,
);

double? _mean(List<double> values) =>
    values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;
