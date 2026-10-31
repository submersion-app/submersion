import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

/// Turns a segment's bar/min rate into what the Gas consumption by segment
/// card shows for the lane in view.
///
/// Every rate here is a segment's `sacRate`, in bar/min at surface. An entry
/// reads in volume units only in the RMV lane and only when
/// [volumeFor] knows its cylinder's size; otherwise it stays in pressure
/// units, because a volume borrowed from another cylinder would be wrong.
class SacRateDisplay {
  final UnitFormatter units;
  final GasConsumptionLane lane;

  /// Aligns profile-derived rates with the dive's own, see
  /// `calculateSacNormalizationFactor`.
  final double normalizationFactor;

  /// The cylinder volume (liters) that converts an entry with this tank id.
  final double? Function(String? tankId) volumeFor;

  const SacRateDisplay({
    required this.units,
    required this.lane,
    required this.normalizationFactor,
    required this.volumeFor,
  });

  /// Whether an entry on [tankId] reads in volume units.
  bool readsInVolume(String? tankId) =>
      lane == GasConsumptionLane.rmv && volumeFor(tankId) != null;

  /// The rate with its unit, such as `14.3 L/min`.
  String format(double sacRate, {String? tankId}) {
    final barPerMin = sacRate * normalizationFactor;
    return readsInVolume(tankId)
        ? units.formatRmv(barPerMin * volumeFor(tankId)!)
        : units.formatSac(barPerMin);
  }

  /// The unit a column heading names for entries on [tankIds]: the volume
  /// unit if any of them reads in it.
  String unit(Iterable<String?> tankIds) =>
      tankIds.any(readsInVolume) ? units.rmvSymbol : units.sacSymbol;

  /// The rate for a cell under a heading of [headingUnit]: the bare number,
  /// or the number with its own unit on an entry that reads differently from
  /// its column.
  String cell(double sacRate, {String? tankId, required String headingUnit}) {
    final barPerMin = sacRate * normalizationFactor;
    final inVolume = readsInVolume(tankId);
    if ((inVolume ? units.rmvSymbol : units.sacSymbol) != headingUnit) {
      return format(sacRate, tankId: tankId);
    }
    return inVolume
        ? formatFixedForDisplay(
            units.convertRmv(barPerMin * volumeFor(tankId)!),
            units.rmvDecimals,
          )
        : formatFixedForDisplay(units.convertSac(barPerMin), units.sacDecimals);
  }

  /// The rate on a scale shared with every entry on [among], for sizing bars
  /// and averaging: the displayed volume rate if all of them convert, else
  /// bar/min for all, since the two scales can't be compared.
  double comparable(
    double sacRate, {
    String? tankId,
    required Iterable<String?> among,
  }) {
    final barPerMin = sacRate * normalizationFactor;
    return among.every(readsInVolume)
        ? barPerMin * volumeFor(tankId)!
        : barPerMin;
  }

  /// Formats a [comparable] value for entries on [among].
  String formatComparable(double value, {required Iterable<String?> among}) =>
      among.every(readsInVolume)
      ? units.formatRmv(value)
      : units.formatSac(value);

  /// The duration-weighted mean of [segments], as a [comparable] value.
  double averageRate(List<SacSegment> segments) {
    final tankIds = segments.map((s) => s.tankId);
    final totalSeconds = segments.fold(0, (sum, s) => sum + s.durationSeconds);
    if (totalSeconds <= 0) return 0;
    final weighted = segments.fold(
      0.0,
      (sum, s) =>
          sum +
          comparable(s.sacRate, tankId: s.tankId, among: tankIds) *
              s.durationSeconds,
    );
    return weighted / totalSeconds;
  }

  /// [averageRate] of [segments] with its unit.
  String formatAverage(List<SacSegment> segments) => formatComparable(
    averageRate(segments),
    among: segments.map((s) => s.tankId),
  );
}
