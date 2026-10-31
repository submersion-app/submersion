import 'package:uuid/uuid.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Extracts tank records from a transformed CSV row.
///
/// Two strategies are tried in order:
/// 1. Numbered groups: tankVolume_1..6 with matching pressure/gas fields, any
///    of which may be missing. A cylinder of unknown size has a null volume.
/// 2. Flat fallback: single-tank fields (startPressure, endPressure, etc.).
class TankExtractor {
  final Uuid _uuid;

  const TankExtractor({Uuid uuid = const Uuid()}) : _uuid = uuid;

  /// Extract all tanks from [row], associating each with [diveId].
  ///
  /// Returns an empty list when no tank data is present.
  List<Map<String, dynamic>> extract(Map<String, dynamic> row, String diveId) {
    final numbered = _extractNumbered(row, diveId);
    if (numbered.isNotEmpty) return numbered;
    return _extractFlat(row, diveId);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _extractNumbered(
    Map<String, dynamic> row,
    String diveId,
  ) {
    final tanks = <Map<String, dynamic>>[];

    for (var i = 1; i <= 6; i++) {
      final volume = _toDouble(row['tankVolume_$i']);
      final start = _toDouble(row['startPressure_$i']);
      final end = _toDouble(row['endPressure_$i']);
      final o2 = _toDouble(row['o2Percent_$i']);
      final he = _toDouble(row['hePercent_$i']);

      // A group is a cylinder as soon as it records anything about one. A
      // missing size rules out volume-based consumption, not the measured
      // pressures or the gas (#3930). A zero records nothing: it is how an
      // unused group can read, and the importer treats a zero size as unknown
      // too.
      final recordsCylinder = [
        volume,
        start,
        end,
        o2,
        he,
      ].any((value) => value != null && value > 0);
      if (!recordsCylinder) continue;

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

  List<Map<String, dynamic>> _extractFlat(
    Map<String, dynamic> row,
    String diveId,
  ) {
    final start = row['startPressure'];
    final end = row['endPressure'];
    final volume = row['tankVolume'];
    final o2 = row['o2Percent'];

    if (start == null && end == null && volume == null && o2 == null) {
      return const [];
    }

    return [
      _buildTank(
        diveId: diveId,
        order: 0,
        volume: _toDouble(volume),
        startPressure: _toDouble(start),
        endPressure: _toDouble(end),
        o2Percent: _toDouble(o2),
        hePercent: _toDouble(row['hePercent']),
      ),
    ];
  }

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

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
