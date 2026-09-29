import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_fills_writer.dart';

import 'csv_dives_writer_test.dart' show imperial, rowOf;
import 'csv_test_fixtures.dart';

/// The cylinder fills sheet (cylinder passports phase 5, issue #2339).
void main() {
  test('metric mode writes canonical values and ISO date and time', () {
    final csv = CsvFillsWriter(
      CsvExportUnits.metric,
    ).write(goldenFills(), equipmentById: goldenFillEquipment());
    expect(
      csv.split('\r\n').first,
      'Fill ID,Passport ID,Cylinder,Serial Number,Date,Time,O2 %,He %,'
      'Pressure (bar),Temperature (°C),Filled By,Analyzer,Source,Notes',
    );
    final r = rowOf(csv, 1);
    expect(r['Fill ID'], '3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11');
    expect(r['Passport ID'], 'pp-al80');
    expect(r['Cylinder'], 'AL80');
    expect(r['Serial Number'], '00123');
    expect(r['Date'], '2025-03-15');
    expect(r['Time'], '09:05');
    expect(r['O2 %'], '32');
    expect(r['He %'], '0');
    expect(r['Pressure (bar)'], '206.8');
    expect(r['Temperature (°C)'], '22.0');
    expect(r['Filled By'], 'Blue Hole Dive Center');
    expect(r['Analyzer'], 'Analox O2EII');
    expect(r['Source'], 'manual');
    expect(r['Notes'], 'Topped off after analysis');

    // No linked cylinder and no temperature: empty cells, not "null".
    final unlinked = rowOf(csv, 2);
    expect(unlinked['Cylinder'], '');
    expect(unlinked['Serial Number'], '');
    expect(unlinked['He %'], '45');
    expect(unlinked['Pressure (bar)'], '180.0');
    expect(unlinked['Temperature (°C)'], '');
    expect(unlinked['Source'], 'nfc');
  });

  test(
    'imperial My units converts pressure and temperature and names them',
    () {
      final csv = CsvFillsWriter(
        CsvExportUnits.fromSettings(imperial),
      ).write(goldenFills());
      final r = rowOf(csv, 1);
      expect(r['Date (MM/DD/YYYY)'], '03/15/2025');
      expect(r['Time (12-hour)'], '9:05 AM');
      expect(r['Pressure (psi)'], '3000');
      expect(r['Temperature (°F)'], '72');
      // The passport id and the analysis never change with the units.
      expect(r['Passport ID'], 'pp-al80');
      expect(r['O2 %'], '32');
    },
  );

  test('free text is neutralised against formulas', () {
    final fill = goldenFills().first.copyWith(
      stationName: '=cmd',
      notes: '-deep',
      analyzer: '@box',
    );
    final r = rowOf(CsvFillsWriter(CsvExportUnits.metric).write([fill]), 1);
    expect(r['Filled By'], "'=cmd");
    expect(r['Notes'], "'-deep");
    expect(r['Analyzer'], "'@box");
  });
}
