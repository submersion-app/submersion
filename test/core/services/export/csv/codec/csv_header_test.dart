import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_header.dart';

void main() {
  test('splits a unit suffix', () {
    final h = CsvHeader.parse('Max Depth (ft)');
    expect(h.base, 'Max Depth');
    expect(h.suffix, 'ft');
    expect(h.key, 'max depth');
  });

  test('splits a date format suffix that contains a comma', () {
    final h = CsvHeader.parse('Date (MMM D, YYYY)');
    expect(h.base, 'Date');
    expect(h.suffix, 'MMM D, YYYY');
  });

  test('a header with no suffix keeps its whole text', () {
    expect(CsvHeader.parse(' O2 % ').base, 'O2 %');
    expect(CsvHeader.parse('O2 %').suffix, isNull);
  });

  test('only a trailing group is a suffix', () {
    final h = CsvHeader.parse('Humidity (%)');
    expect(h.base, 'Humidity');
    expect(h.suffix, '%');
  });
}
