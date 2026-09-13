import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const imperial = AppSettings(
  depthUnit: DepthUnit.feet,
  temperatureUnit: TemperatureUnit.fahrenheit,
  pressureUnit: PressureUnit.psi,
  volumeUnit: VolumeUnit.cubicFeet,
  weightUnit: WeightUnit.pounds,
  dateFormat: DateFormatPreference.mmddyyyy,
  timeFormat: TimeFormat.twelveHour,
);

const metricDiver = AppSettings(
  dateFormat: DateFormatPreference.ddmmyyyy,
  timeFormat: TimeFormat.twentyFourHour,
);

void main() {
  group('Metric mode keeps the historical format', () {
    const units = CsvExportUnits.metric;

    test('headers', () {
      expect(units.header(CsvColumns.maxDepth), 'Max Depth (m)');
      expect(units.header(CsvColumns.waterTemp), 'Water Temp (°C)');
      expect(units.header(CsvColumns.windSpeed), 'Wind Speed (m/s)');
      expect(units.header(CsvColumns.buoyancy), 'Buoyancy (kg)');
      expect(units.dateHeader('Date'), 'Date');
      expect(units.timeHeader('Time'), 'Time');
    });

    test("values use each column's historical decimals", () {
      expect(units.value(CsvColumns.maxDepth, 30.48), '30.5');
      expect(units.value(CsvColumns.waterTemp, 26.4), '26');
      expect(units.value(CsvColumns.tankVolume, 11.1), '11');
      expect(units.value(CsvColumns.buoyancy, 2.5), '2.5');
      expect(units.value(CsvColumns.maxDepth, null), '');
    });

    test('ISO date and 24-hour time', () {
      final t = DateTime.utc(2025, 3, 15, 9, 5);
      expect(units.date(t), '2025-03-15');
      expect(units.time(t), '09:05');
    });
  });

  group('My units for an imperial diver', () {
    final units = CsvExportUnits.fromSettings(imperial);

    test("headers name the diver's units and formats", () {
      expect(units.header(CsvColumns.maxDepth), 'Max Depth (ft)');
      expect(units.header(CsvColumns.waterTemp), 'Water Temp (°F)');
      expect(units.header(CsvColumns.startPressure), 'Start Pressure (psi)');
      expect(units.header(CsvColumns.tankVolume), 'Tank Volume (cuft)');
      expect(units.header(CsvColumns.windSpeed), 'Wind Speed (kts)');
      expect(units.header(CsvColumns.dryWeight), 'Dry Weight (lbs)');
      expect(units.dateHeader('Date'), 'Date (MM/DD/YYYY)');
      expect(units.timeHeader('Time'), 'Time (12-hour)');
    });

    test('values are converted with the My units decimals', () {
      expect(units.value(CsvColumns.maxDepth, 30.48), '100.0');
      expect(units.value(CsvColumns.waterTemp, 26.4), '80');
      expect(units.value(CsvColumns.startPressure, 206.843), '3000');
      expect(units.value(CsvColumns.buoyancy, 2.5), '5.51');
      expect(units.value(CsvColumns.windSpeed, 4.2), '8.2');
    });

    test('dates and times follow the diver', () {
      final t = DateTime.utc(2025, 3, 15, 14, 30);
      expect(units.date(t), '03/15/2025');
      expect(units.time(t), '2:30 PM');
    });
  });

  test('a metric diver in My units gets km/h wind and 2-decimal kg', () {
    final units = CsvExportUnits.fromSettings(metricDiver);
    expect(units.header(CsvColumns.windSpeed), 'Wind Speed (km/h)');
    expect(units.value(CsvColumns.windSpeed, 4.2), '15.1');
    expect(units.value(CsvColumns.buoyancy, 2.5), '2.50');
    expect(units.dateHeader('Date'), 'Date (DD/MM/YYYY)');
  });

  test("forMode picks metric or the diver's units", () {
    expect(
      CsvExportUnits.forMode(CsvUnitMode.metric, imperial).isMetric,
      isTrue,
    );
    expect(
      CsvExportUnits.forMode(CsvUnitMode.myUnits, imperial).isMetric,
      isFalse,
    );
  });
}
