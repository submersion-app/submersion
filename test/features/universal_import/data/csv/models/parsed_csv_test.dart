import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/models/parsed_csv.dart';

void main() {
  group('ParsedCsv', () {
    test('sampleRows returns all rows when fewer than count', () {
      final csv = ParsedCsv(
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
      final csv = ParsedCsv(
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
        ParsedCsv(
          headers: ['a'],
          rows: [
            ['1'],
          ],
        ).isNotEmpty,
        isTrue,
      );
    });
  });
}
