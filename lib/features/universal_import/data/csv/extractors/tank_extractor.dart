import 'package:uuid/uuid.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Extracts tank records from a transformed CSV row.
///
/// A row holds up to six numbered groups, tankVolume_1..6 with matching
/// pressure and gas fields, any of which may be missing. A cylinder of unknown
/// size has a null volume. The unnumbered fields (startPressure, tankVolume,
/// etc.) are the first group under another name, and supply only what its
/// numbered fields leave out.
class TankExtractor {
  final Uuid _uuid;

  const TankExtractor({Uuid uuid = const Uuid()}) : _uuid = uuid;

  /// Extract all tanks from [row], associating each with [diveId].
  ///
  /// Returns an empty list when no tank data is present.
  List<Map<String, dynamic>> extract(Map<String, dynamic> row, String diveId) {
    final tanks = <Map<String, dynamic>>[];

    for (var i = 1; i <= 6; i++) {
      double? reading(String field) =>
          _reading(row['${field}_$i']) ??
          (i == 1 ? _reading(row[field]) : null);

      final volume = reading('tankVolume');
      final start = reading('startPressure');
      final end = reading('endPressure');
      final o2 = reading('o2Percent');
      final he = reading('hePercent');

      // A group is a cylinder as soon as it records anything about one. A
      // missing size rules out volume-based consumption, not the measured
      // pressures or the gas (#3930).
      if (volume == null &&
          start == null &&
          end == null &&
          o2 == null &&
          he == null) {
        continue;
      }

      tanks.add(
        _buildTank(
          diveId: diveId,
          order: tanks.length,
          volume: volume,
          startPressure: start,
          endPressure: end,
          o2Percent: o2,
          hePercent: he,
        ),
      );
    }

    return tanks;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildTank({
    required String diveId,
    required int order,
    double? volume,
    double? startPressure,
    double? endPressure,
    double? o2Percent,
    double? hePercent,
  }) {
    final o2 = o2Percent ?? 21.0;
    final he = hePercent ?? 0.0;
    return {
      'id': _uuid.v4(),
      'diveId': diveId,
      'volume': volume,
      'startPressure': startPressure,
      'endPressure': endPressure,
      'o2Percent': o2,
      'hePercent': he,
      // The importer builds the tank's gas from this key alone (#1814).
      'gasMix': GasMix(o2: o2, he: he),
      'order': order,
    };
  }

  /// [value] as a number, or null when it records nothing. A zero is how an
  /// unused group or an unknown reading can read: no cylinder has a zero size
  /// and no gas has no oxygen, so it must not reach the tank as a measurement.
  double? _reading(dynamic value) {
    final number = _toDouble(value);
    return number != null && number > 0 ? number : null;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
