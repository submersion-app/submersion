import 'package:submersion/core/services/export/csv/codec/csv_unit.dart';

/// One unit-bearing column of a Submersion CSV export, declared once so the
/// exporter and the importer agree on its name and quantity.
class CsvColumn {
  const CsvColumn(this.base, this.quantity, {required this.metricDecimals});

  /// Header text before the unit suffix.
  final String base;

  final CsvQuantity quantity;

  /// Decimals the Metric export has always used for this column. Null means
  /// the value was written with `double.toString()`, which Metric mode keeps.
  final int? metricDecimals;
}

/// Every unit-bearing column the dives, sites and equipment exports write.
abstract final class CsvColumns {
  static const maxDepth = CsvColumn(
    'Max Depth',
    CsvQuantity.depth,
    metricDecimals: 1,
  );
  static const avgDepth = CsvColumn(
    'Avg Depth',
    CsvQuantity.depth,
    metricDecimals: 1,
  );
  static const waterTemp = CsvColumn(
    'Water Temp',
    CsvQuantity.temperature,
    metricDecimals: 0,
  );
  static const airTemp = CsvColumn(
    'Air Temp',
    CsvQuantity.temperature,
    metricDecimals: 0,
  );
  static const visibility = CsvColumn(
    'Visibility',
    CsvQuantity.depth,
    metricDecimals: 1,
  );
  static const startPressure = CsvColumn(
    'Start Pressure',
    CsvQuantity.pressure,
    metricDecimals: 1,
  );
  static const endPressure = CsvColumn(
    'End Pressure',
    CsvQuantity.pressure,
    metricDecimals: 1,
  );

  /// Physical volume in litres, or rated gas capacity when the unit is cuft
  /// (see `tank_capacity.dart`).
  static const tankVolume = CsvColumn(
    'Tank Volume',
    CsvQuantity.volume,
    metricDecimals: 0,
  );

  /// My units only: lets the importer turn a rated cuft back into litres.
  static const workingPressure = CsvColumn(
    'Working Pressure',
    CsvQuantity.pressure,
    metricDecimals: 1,
  );
  static const windSpeed = CsvColumn(
    'Wind Speed',
    CsvQuantity.windSpeed,
    metricDecimals: 1,
  );
  static const buoyancy = CsvColumn(
    'Buoyancy',
    CsvQuantity.weight,
    metricDecimals: null,
  );
  static const dryWeight = CsvColumn(
    'Dry Weight',
    CsvQuantity.weight,
    metricDecimals: null,
  );
}
