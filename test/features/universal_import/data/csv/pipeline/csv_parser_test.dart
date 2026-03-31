import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_parser.dart';

Uint8List _toBytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  late CsvParser parser;

  setUp(() {
    parser = const CsvParser();
  });

  group('CsvParser', () {
    test('parses basic CSV with CRLF line endings', () {
      final bytes = _toBytes('Name,Depth\r\nDive 1,25.5\r\nDive 2,30.0\r\n');
      final result = parser.parse(bytes);

      expect(result.headers, ['Name', 'Depth']);
      expect(result.rows, hasLength(2));
      expect(result.rows[0], ['Dive 1', '25.5']);
      expect(result.rows[1], ['Dive 2', '30.0']);
    });

    test('parses CSV with LF line endings (fixes #59)', () {
      final bytes = _toBytes('Name,Depth\nDive 1,25.5\nDive 2,30.0\n');
      final result = parser.parse(bytes);

      expect(result.headers, ['Name', 'Depth']);
      expect(result.rows, hasLength(2));
    });

    test('parses CSV with bare CR line endings', () {
      final bytes = _toBytes('Name,Depth\rDive 1,25.5\rDive 2,30.0\r');
      final result = parser.parse(bytes);

      expect(result.headers, ['Name', 'Depth']);
      expect(result.rows, hasLength(2));
    });

    test('handles quoted fields with commas', () {
      final bytes = _toBytes('Name,Buddy\nDive 1,", Kiyan Griffin"\n');
      final result = parser.parse(bytes);

      expect(result.rows[0][1], ', Kiyan Griffin');
    });

    test('handles quoted fields with newlines', () {
      final bytes = _toBytes('Name,Notes\nDive 1,"Line 1\nLine 2"\n');
      final result = parser.parse(bytes);

      expect(result.rows, hasLength(1));
      expect(result.rows[0][1], contains('Line 1'));
    });

    test('skips empty rows', () {
      final bytes = _toBytes('Name,Depth\n\nDive 1,25.5\n\n\nDive 2,30.0\n');
      final result = parser.parse(bytes);

      expect(result.rows, hasLength(2));
    });

    test('throws on empty file', () {
      expect(
        () => parser.parse(Uint8List(0)),
        throwsA(isA<CsvParseException>()),
      );
    });

    test('throws on headers only with no data', () {
      final bytes = _toBytes('Name,Depth\n');
      expect(() => parser.parse(bytes), throwsA(isA<CsvParseException>()));
    });

    test('handles malformed UTF-8 gracefully', () {
      final bytes = Uint8List.fromList([
        ...utf8.encode('Name,Depth\n'),
        0xFF,
        0xFE,
        ...utf8.encode(',25.5\n'),
      ]);
      final result = parser.parse(bytes);
      expect(result.headers, ['Name', 'Depth']);
    });

    test('trims whitespace from headers', () {
      final bytes = _toBytes(' Name , Depth \nDive 1,25.5\n');
      final result = parser.parse(bytes);

      expect(result.headers, ['Name', 'Depth']);
    });

    test('handles Subsurface dive list CSV format', () {
      final bytes = _toBytes(
        'dive number,date,time,duration [min],sac [l/min],maxdepth [m],avgdepth [m]\n'
        '1,2025-09-20,07:44:37,0:42,40.115,2.41,1.58\n',
      );
      final result = parser.parse(bytes);

      expect(result.headers.first, 'dive number');
      expect(result.headers.last, 'avgdepth [m]');
      expect(result.rows, hasLength(1));
    });

    test('handles mixed CRLF and CR line endings', () {
      // Mix of \r\n and bare \r in the same file.
      final bytes = _toBytes('Name,Depth\r\nDive 1,25.5\rDive 2,30.0\r\n');
      final result = parser.parse(bytes);

      expect(result.headers, ['Name', 'Depth']);
      expect(result.rows, hasLength(2));
    });

    test('CsvParseException.toString includes message', () {
      const exception = CsvParseException('test error');
      expect(exception.toString(), 'CsvParseException: test error');
    });

    test('throws CsvParseException for whitespace-only rows after header', () {
      final bytes = _toBytes('Name,Depth\n  ,  \n   ,   \n');
      expect(() => parser.parse(bytes), throwsA(isA<CsvParseException>()));
    });

    test('throws on content with only whitespace (non-empty bytes)', () {
      // Bytes are non-empty but content after normalization produces no rows.
      final bytes = _toBytes('   \n   \n');
      expect(() => parser.parse(bytes), throwsA(isA<CsvParseException>()));
    });

    test('handles row with cell value null via cell.toString()', () {
      // Test that rows with cells that are all whitespace are skipped.
      final bytes = _toBytes('A,B\n , \nX,Y\n');
      final result = parser.parse(bytes);
      // The whitespace-only row should be skipped, leaving only the X,Y row.
      expect(result.rows, hasLength(1));
      expect(result.rows[0], ['X', 'Y']);
    });
  });
}
