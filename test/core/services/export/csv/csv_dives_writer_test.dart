import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_dives_writer.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'csv_test_fixtures.dart';

const imperial = AppSettings(
  depthUnit: DepthUnit.feet,
  temperatureUnit: TemperatureUnit.fahrenheit,
  pressureUnit: PressureUnit.psi,
  volumeUnit: VolumeUnit.cubicFeet,
  weightUnit: WeightUnit.pounds,
  dateFormat: DateFormatPreference.mmddyyyy,
  timeFormat: TimeFormat.twelveHour,
);

/// Row [row] of [csv] as a header -> cell map.
Map<String, String> rowOf(String csv, int row) {
  final rows = const CsvToListConverter(
    eol: '\n',
    shouldParseNumbers: false,
  ).convert(csv.replaceAll('\r\n', '\n'));
  final headers = rows.first.cast<String>();
  return {
    for (var i = 0; i < headers.length; i++) headers[i]: '${rows[row][i]}',
  };
}

void main() {
  test('imperial My units converts every unit column and names it', () {
    final csv = CsvDivesWriter(
      CsvExportUnits.fromSettings(imperial),
    ).write(goldenDives());
    final r = rowOf(csv, 1);
    expect(r['Date (MM/DD/YYYY)'], '03/15/2025');
    expect(r['Time (12-hour)'], '9:05 AM');
    expect(r['Max Depth (ft)'], '100.0');
    expect(r['Avg Depth (ft)'], '59.9');
    expect(r['Water Temp (°F)'], '80');
    expect(r['Air Temp (°F)'], '85');
    expect(r['Visibility (ft)'], '69.9');
    expect(r['Start Pressure (psi)'], '3000');
    expect(r['End Pressure (psi)'], '732');
    expect(r['Tank Volume (cuft)'], '77.4');
    expect(r['Working Pressure (psi)'], '3000');
    expect(r['Wind Speed (kts)'], '8.2');
    expect(r['Bottom Time (min)'], '41');
    expect(r['O2 %'], '32');
    expect(r['custom:Formula'], "'=1+1");
  });

  test('Working Pressure appears only in My units', () {
    final metric = CsvDivesWriter(CsvExportUnits.metric).write(goldenDives());
    expect(metric.split('\n').first, isNot(contains('Working Pressure')));
  });

  test('Metric writer keeps the historical headers and values', () {
    final csv = CsvDivesWriter(CsvExportUnits.metric).write(goldenDives());
    expect(rowOf(csv, 1)['Max Depth (m)'], '30.5');
    expect(rowOf(csv, 1)['Date'], '2025-03-15');
  });

  test('free text beginning with a formula character is neutralised', () {
    // Spreadsheets evaluate a cell starting with = + - @ as a formula
    // (CSV injection), so every free-text cell gets the guard quote that
    // custom fields always had. Numbers are never touched.
    final dive = goldenDives().first.copyWith(
      name: '=HYPERLINK("x")',
      notes: '-bring torch',
      buddy: '@ana',
      diveComputerSerial: '+001',
      weatherDescription: '=1+1',
      waterTemp: -1.6,
    );
    final r = rowOf(CsvDivesWriter(CsvExportUnits.metric).write([dive]), 1);
    expect(r['Name'], '\'=HYPERLINK("x")');
    expect(r['Notes'], "'-bring torch");
    expect(r['Buddy'], "'@ana");
    expect(r['Serial Number'], "'+001");
    expect(r['Weather Description'], "'=1+1");
    expect(r['Water Temp (°C)'], '-2');
  });
}
