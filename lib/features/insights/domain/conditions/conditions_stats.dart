import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/features/insights/domain/conditions/condition_bands.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_row.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';

/// Dives per value of a categorical condition, in the enum's natural order
/// (calm to severe, clockwise compass), categories with no dive left out.
class CategoryStat<T extends Enum> {
  const CategoryStat({
    required this.counts,
    required this.recorded,
    this.diveIdsByValue = const {},
    this.unrecordedDiveIds = const [],
  });

  final List<({T value, int count})> counts;

  /// The dives behind each entry of [counts] (issue #3805).
  final Map<T, List<String>> diveIdsByValue;

  /// The dives with no value for this field.
  final List<String> unrecordedDiveIds;

  /// Dives with this field recorded: the first number of the coverage line.
  final int recorded;

  bool get isEmpty => recorded == 0;
}

/// Dives per band of a numeric condition, every band included.
class BandStat {
  const BandStat({
    required this.bands,
    required this.recorded,
    this.diveIdsByBand = const [],
    this.unrecordedDiveIds = const [],
  });

  final List<BandCount> bands;

  /// The dives behind each band, parallel to [bands] (issue #3805).
  final List<List<String>> diveIdsByBand;

  /// The dives with no value for this field.
  final List<String> unrecordedDiveIds;
  final int recorded;

  bool get isEmpty => recorded == 0;
}

/// Every statistic on the Conditions tab that comes from the condition
/// columns (issue #3118), built in one pass over the in-scope dives.
class ConditionsStats {
  const ConditionsStats({
    required this.totalDives,
    required this.airTempTrend,
    required this.airTemp,
    required this.cloudCover,
    required this.precipitation,
    required this.windSpeed,
    required this.windDirection,
    required this.humidity,
    required this.surfacePressure,
    required this.currentStrength,
    required this.currentDirection,
    required this.swellHeight,
    required this.altitude,
    required this.exitMethod,
  });

  /// [rows] holds every in-scope dive, recorded or not, so its length is the
  /// coverage line's denominator. Bands are binned in [units].
  factory ConditionsStats.fromRows(
    List<ConditionsRow> rows,
    ConditionsUnits units,
  ) {
    CategoryStat<T> category<T extends Enum>(
      List<T> order,
      T? Function(ConditionsRow) pick,
    ) {
      final diveIds = <T, List<String>>{};
      final unrecorded = <String>[];
      for (final r in rows) {
        final value = pick(r);
        if (value == null) {
          unrecorded.add(r.diveId);
        } else {
          (diveIds[value] ??= []).add(r.diveId);
        }
      }
      return CategoryStat<T>(
        counts: [
          for (final value in order)
            if (diveIds[value] case final ids?)
              (value: value, count: ids.length),
        ],
        recorded: rows.length - unrecorded.length,
        diveIdsByValue: diveIds,
        unrecordedDiveIds: unrecorded,
      );
    }

    BandStat band(
      double? Function(ConditionsRow) pick,
      List<double> edges,
      int decimals,
    ) {
      final values = <double>[];
      final diveIds = [for (var i = 0; i <= edges.length; i++) <String>[]];
      final unrecorded = <String>[];
      for (final r in rows) {
        final value = pick(r);
        if (value == null) {
          unrecorded.add(r.diveId);
        } else {
          values.add(value);
          diveIds[bandIndexOf(value, edges, decimals: decimals)].add(r.diveId);
        }
      }
      return BandStat(
        bands: countIntoBands(values, edges, decimals: decimals),
        recorded: values.length,
        diveIdsByBand: diveIds,
        unrecordedDiveIds: unrecorded,
      );
    }

    final metric = units.isMetric;
    final trend = [
      for (final r in rows)
        if (r.airTemp case final celsius?)
          TrendDataPoint(date: r.dateTime, value: celsius, diveId: r.diveId),
    ]..sort((a, b) => a.date.compareTo(b.date));

    return ConditionsStats(
      totalDives: rows.length,
      airTempTrend: List.unmodifiable(trend),
      airTemp: band(
        (r) => r.airTemp == null
            ? null
            : TemperatureUnit.celsius.convert(r.airTemp!, units.temperature),
        airTempBandEdges(units.temperature),
        1,
      ),
      cloudCover: category(CloudCover.values, (r) => r.cloudCover),
      precipitation: category(Precipitation.values, (r) => r.precipitation),
      windSpeed: band(
        (r) => r.windSpeed == null
            ? null
            : windSpeedForDisplay(r.windSpeed!, metric: metric),
        windSpeedBandEdges(metric: metric),
        0,
      ),
      windDirection: category(CurrentDirection.values, (r) => r.windDirection),
      humidity: band((r) => r.humidity, humidityBandEdges, 0),
      surfacePressure: band(
        (r) => r.surfacePressure == null
            ? null
            : surfacePressureForDisplay(r.surfacePressure!, metric: metric),
        surfacePressureBandEdges(metric: metric),
        metric ? 0 : 2,
      ),
      currentStrength: category(
        CurrentStrength.values,
        (r) => r.currentStrength,
      ),
      currentDirection: category(
        CurrentDirection.values,
        (r) => r.currentDirection,
      ),
      swellHeight: band(
        (r) => r.swellHeight == null
            ? null
            : DepthUnit.meters.convert(r.swellHeight!, units.depth),
        swellHeightBandEdges(units.depth),
        1,
      ),
      altitude: category(
        AltitudeGroup.values,
        (r) =>
            r.altitude == null ? null : AltitudeGroup.fromAltitude(r.altitude),
      ),
      exitMethod: category(EntryMethod.values, (r) => r.exitMethod),
    );
  }

  final int totalDives;

  /// Air temperature per dive in Celsius, by date; formatted at display time.
  final List<TrendDataPoint> airTempTrend;
  final BandStat airTemp;
  final CategoryStat<CloudCover> cloudCover;
  final CategoryStat<Precipitation> precipitation;
  final BandStat windSpeed;
  final CategoryStat<CurrentDirection> windDirection;
  final BandStat humidity;
  final BandStat surfacePressure;
  final CategoryStat<CurrentStrength> currentStrength;
  final CategoryStat<CurrentDirection> currentDirection;
  final BandStat swellHeight;
  final CategoryStat<AltitudeGroup> altitude;
  final CategoryStat<EntryMethod> exitMethod;
}
