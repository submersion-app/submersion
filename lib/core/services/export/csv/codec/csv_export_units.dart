import 'package:intl/intl.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_date_formats.dart';
import 'package:submersion/core/services/export/csv/codec/csv_unit.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Which units a CSV export writes.
enum CsvUnitMode {
  /// The active diver's unit, date and time settings, named in each header.
  myUnits,

  /// Canonical metric values and ISO dates: the historical format.
  metric,
}

/// The resolved units of one CSV export. [metric] reproduces the historical
/// output byte for byte; [CsvExportUnits.fromSettings] follows a diver.
class CsvExportUnits {
  const CsvExportUnits._({required this.isMetric, AppSettings? settings})
    : _settings = settings;

  static const metric = CsvExportUnits._(isMetric: true);

  factory CsvExportUnits.fromSettings(AppSettings settings) =>
      CsvExportUnits._(isMetric: false, settings: settings);

  factory CsvExportUnits.forMode(CsvUnitMode mode, AppSettings settings) =>
      mode == CsvUnitMode.metric
      ? metric
      : CsvExportUnits.fromSettings(settings);

  final bool isMetric;
  final AppSettings? _settings;

  // The historical formatters, kept without an explicit locale so Metric
  // mode's bytes cannot change.
  static final _isoDate = DateFormat('yyyy-MM-dd');
  static final _isoTime = DateFormat('HH:mm');

  /// Formatter for the diver's settings; null in Metric mode.
  UnitFormatter? get formatter {
    final settings = _settings;
    return settings == null ? null : UnitFormatter(settings);
  }

  /// The diver's date format; null in Metric mode (ISO).
  DateFormatPreference? get dateFormat => _settings?.dateFormat;

  CsvUnit unitFor(CsvQuantity quantity) {
    final s = _settings;
    if (isMetric || s == null) return CsvUnit.metricFor(quantity);
    return switch (quantity) {
      CsvQuantity.depth =>
        s.depthUnit == DepthUnit.feet ? CsvUnit.feet : CsvUnit.meters,
      CsvQuantity.temperature =>
        s.temperatureUnit == TemperatureUnit.fahrenheit
            ? CsvUnit.fahrenheit
            : CsvUnit.celsius,
      CsvQuantity.pressure =>
        s.pressureUnit == PressureUnit.psi ? CsvUnit.psi : CsvUnit.bar,
      CsvQuantity.volume =>
        s.volumeUnit == VolumeUnit.cubicFeet
            ? CsvUnit.cubicFeet
            : CsvUnit.liters,
      CsvQuantity.weight =>
        s.weightUnit == WeightUnit.pounds ? CsvUnit.pounds : CsvUnit.kilograms,
      // Same rule as UnitFormatter._isMetricWind: wind follows depth.
      CsvQuantity.windSpeed =>
        s.depthUnit == DepthUnit.meters
            ? CsvUnit.kilometersPerHour
            : CsvUnit.knots,
    };
  }

  String header(CsvColumn column) =>
      '${column.base} (${unitFor(column.quantity).symbol})';

  /// [metricValue] written in this export's unit for [column], or '' when
  /// null.
  String value(CsvColumn column, double? metricValue) {
    if (metricValue == null) return '';
    if (isMetric) {
      final decimals = column.metricDecimals;
      return decimals == null
          ? metricValue.toString()
          : metricValue.toStringAsFixed(decimals);
    }
    final unit = unitFor(column.quantity);
    return unit.fromMetric(metricValue).toStringAsFixed(unit.myUnitsDecimals);
  }

  String dateHeader(String base) =>
      isMetric ? base : '$base (${_settings!.dateFormat.displayName})';

  String timeHeader(String base) =>
      isMetric ? base : '$base (${_settings!.timeFormat.displayName})';

  String date(DateTime date) => isMetric
      ? _isoDate.format(date)
      : formatCsvDate(date, _settings!.dateFormat);

  String time(DateTime time) => isMetric
      ? _isoTime.format(time)
      : formatCsvTime(time, _settings!.timeFormat);
}
