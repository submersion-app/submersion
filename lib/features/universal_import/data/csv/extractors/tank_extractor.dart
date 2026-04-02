import 'package:uuid/uuid.dart';

/// Extracts tank records from a transformed CSV row.
///
/// Two strategies are tried in order:
/// 1. Numbered groups: tankVolume_1..6 with matching pressure/gas fields.
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
      final volume = row['tankVolume_$i'];
      final start = row['startPressure_$i'];
      final end = row['endPressure_$i'];
      final o2 = row['o2Percent_$i'];
      final he = row['hePercent_$i'];

      // A numbered tank group requires at least a volume to be meaningful.
      // Pressure-only entries without a volume are incomplete (e.g. Subsurface
      // sometimes splits data across column groups) and are skipped.
      if (_toDouble(volume) == null) continue;

      tanks.add(
        _buildTank(
          diveId: diveId,
          order: tanks.length,
          volume: _toDouble(volume),
          startPressure: _toDouble(start),
          endPressure: _toDouble(end),
          o2Percent: _toDouble(o2),
          hePercent: _toDouble(he),
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
        hePercent: null,
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
    return {
      'id': _uuid.v4(),
      'diveId': diveId,
      'volume': volume,
      'startPressure': startPressure,
      'endPressure': endPressure,
      'o2Percent': o2Percent ?? 21.0,
      'hePercent': hePercent ?? 0.0,
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
