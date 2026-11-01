import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/table_editor/domain/paste_parser.dart';

/// Clipboard text from a spreadsheet: rows on newlines, cells on tabs.
void main() {
  test(
    'parsePasteText splits rows and tabs and drops the trailing newline',
    () {
      final block = parsePasteText('a\tb\nc\td\n');

      expect(block.rows, [
        ['a', 'b'],
        ['c', 'd'],
      ]);
      expect(block.columnCount, 2);
      expect(block.isSingleValue, isFalse);
    },
  );

  test('Windows line endings are rows too', () {
    expect(parsePasteText('1\r\n2\r\n').rows, [
      ['1'],
      ['2'],
    ]);
  });

  test('a single value with no tab or newline is a single value', () {
    final block = parsePasteText('6,5');

    expect(block.isSingleValue, isTrue);
    expect(block.rows, [
      ['6,5'],
    ]);
  });

  test('an empty cell inside a row is kept as empty text', () {
    expect(parsePasteText('a\t\tc').rows, [
      ['a', '', 'c'],
    ]);
  });

  test('empty text has no rows', () {
    expect(parsePasteText('').rows, isEmpty);
    expect(parsePasteText('\n').rows, isEmpty);
  });

  test(
    'a quoted cell keeps its newline and tab, and a doubled quote is one',
    () {
      final block = parsePasteText(
        '1\t"first line\nsecond\tpart"\n2\t"say ""hi"""\n',
      );

      expect(block.rows, [
        ['1', 'first line\nsecond\tpart'],
        ['2', 'say "hi"'],
      ]);
    },
  );
}
