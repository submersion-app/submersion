import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/models/parsed_csv.dart';

void main() {
  group('ParsedCsv', () {
    test('sampleRows returns all rows when fewer than count', () {
      const csv = ParsedCsv(
        headers: ['a', 'b'],
        rows: [
          ['1', '2'],
          ['3', '4'],
        ],
      );
      expect(csv.sampleRows(5), hasLength(2));
    });

    test('sampleRows limits to count', () {
      final csv = ParsedCsv(
        headers: ['a'],
        rows: List.generate(20, (i) => ['$i']),
      );
      expect(csv.sampleRows(5), hasLength(5));
    });

    test('sampleValues extracts non-empty values for column', () {
      const csv = ParsedCsv(
        headers: ['name', 'depth'],
        rows: [
          ['Dive 1', '25.5'],
          ['Dive 2', ''],
          ['Dive 3', '30.0'],
        ],
      );
      expect(csv.sampleValues(1), ['25.5', '30.0']);
    });

    test('isEmpty and isNotEmpty reflect row count', () {
      expect(const ParsedCsv(headers: ['a'], rows: []).isEmpty, isTrue);
      expect(
        const ParsedCsv(
          headers: ['a'],
          rows: [
            ['1'],
          ],
        ).isNotEmpty,
        isTrue,
      );
    });

    test('rowCount returns number of rows', () {
      const csv = ParsedCsv(
        headers: ['a', 'b'],
        rows: [
          ['1', '2'],
          ['3', '4'],
          ['5', '6'],
        ],
      );
      expect(csv.rowCount, 3);
    });

    test('rowCount is 0 for empty rows', () {
      const csv = ParsedCsv(headers: ['a'], rows: []);
      expect(csv.rowCount, 0);
    });

    test('sampleValues skips rows where column index is out of bounds', () {
      const csv = ParsedCsv(
        headers: ['a', 'b', 'c'],
        rows: [
          ['1', '2', '3'],
          ['4', '5'], // column 2 is out of bounds here
          ['7', '8', '9'],
        ],
      );
      // Column index 2: row 0 has '3', row 1 is short, row 2 has '9'.
      expect(csv.sampleValues(2), ['3', '9']);
    });

    test('sampleValues limits to count parameter', () {
      final csv = ParsedCsv(
        headers: ['a'],
        rows: List.generate(20, (i) => ['val$i']),
      );
      final samples = csv.sampleValues(0, 3);
      expect(samples, hasLength(3));
      expect(samples, ['val0', 'val1', 'val2']);
    });

    test('equality: two ParsedCsv with same data are equal', () {
      const csv1 = ParsedCsv(
        headers: ['a', 'b'],
        rows: [
          ['1', '2'],
        ],
      );
      const csv2 = ParsedCsv(
        headers: ['a', 'b'],
        rows: [
          ['1', '2'],
        ],
      );
      expect(csv1, csv2);
      expect(csv1.hashCode, csv2.hashCode);
    });

    test('equality: different headers are not equal', () {
      const csv1 = ParsedCsv(
        headers: ['a'],
        rows: [
          ['1'],
        ],
      );
      const csv2 = ParsedCsv(
        headers: ['b'],
        rows: [
          ['1'],
        ],
      );
      expect(csv1, isNot(csv2));
    });

    test('equality: different rows are not equal', () {
      const csv1 = ParsedCsv(
        headers: ['a'],
        rows: [
          ['1'],
        ],
      );
      const csv2 = ParsedCsv(
        headers: ['a'],
        rows: [
          ['2'],
        ],
      );
      expect(csv1, isNot(csv2));
    });
  });
}
