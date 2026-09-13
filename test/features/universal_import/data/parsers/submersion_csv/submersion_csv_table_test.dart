import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_unit.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_csv_table.dart';

SubmersionCsvTable _table(String csv) =>
    SubmersionCsvTable.parse(Uint8List.fromList(utf8.encode(csv)));

void main() {
  test('reads cells by base name and converts by the header unit', () {
    final t = _table(
      '\u{FEFF}Max Depth (ft),Water Temp (°F),Serial Number\r\n'
      '100.0,80,00123\r\n',
    );
    final row = t.rows.single;
    expect(t.quantity(row, CsvColumns.maxDepth), closeTo(30.48, 1e-5));
    expect(t.quantity(row, CsvColumns.waterTemp), closeTo(26.667, 1e-3));
    // Numbers are not parsed by the CSV reader, so leading zeros survive.
    expect(t.text(row, 'serial number'), '00123');
    expect(t.unitOf(CsvColumns.maxDepth), CsvUnit.feet);
  });

  test('a header with no unit is metric, a blank cell is null', () {
    final t = _table('Max Depth (m),Date\n,2025-03-15\n');
    expect(t.quantity(t.rows.single, CsvColumns.maxDepth), isNull);
    expect(t.unitOf(CsvColumns.maxDepth), CsvUnit.meters);
    expect(t.date(t.rows.single, 'Date'), DateTime.utc(2025, 3, 15));
  });

  test('dates and times read with the header format', () {
    final t = _table(
      '"Date (MMM D, YYYY)",Time (12-hour)\n"Mar 5, 2025",2:07 PM\n',
    );
    expect(t.dateFormatOf('Date'), DateFormatPreference.mmmDYYYY);
    expect(t.date(t.rows.single, 'Date'), DateTime.utc(2025, 3, 5));
    expect(t.time(t.rows.single, 'Time'), (hour: 14, minute: 7));
  });

  test('custom columns are unsanitized, blank values dropped', () {
    final t = _table(
      "Notes,custom:Boat,custom:Formula,custom:Empty\nx,Sea Dog,'=1+1,\n",
    );
    expect(t.customCells(t.rows.single), [
      (key: 'Boat', value: 'Sea Dog'),
      (key: 'Formula', value: '=1+1'),
    ]);
  });

  test('a unit that does not fit the column is reported, not converted', () {
    final t = _table('Max Depth (psi)\n10\n');
    expect(t.quantity(t.rows.single, CsvColumns.maxDepth), isNull);
    expect(t.unreadableUnitColumns([CsvColumns.maxDepth]), ['Max Depth (psi)']);
  });

  test('blank lines are skipped', () {
    expect(_table('Name\nA\n\n,\nB\n').rows.length, 2);
  });
}
