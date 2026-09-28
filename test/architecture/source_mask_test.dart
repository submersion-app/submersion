import 'package:flutter_test/flutter_test.dart';

import 'source_mask.dart';

/// Unit tests for the masking that backs `global_state_scanner.dart`.
void main() {
  String mask(String source) => MaskedSource(source).code;

  group('masking', () {
    test('keeps every offset and line break where it was', () {
      const source = "final a = 'one';\n// two\nfinal b = 3;\n";

      final code = mask(source);

      expect(code.length, source.length);
      expect('\n'.allMatches(code).length, '\n'.allMatches(source).length);
      expect(code.indexOf('final b'), source.indexOf('final b'));
    });

    test('blanks a line comment and keeps the code before it', () {
      expect(mask('a = 1; // b = 2;\n'), 'a = 1;          \n');
    });

    test('blanks a block comment across lines', () {
      expect(mask('a /* b\nc */ d'), 'a     \n     d');
    });

    test('blanks the contents of a string and keeps its quotes', () {
      expect(mask("f('x = 1');"), "f('     ');");
      expect(mask('f("x = 1");'), 'f("     ");');
    });

    test('blanks a multi-line string', () {
      expect(mask("a = '''\nx = 1\n''';"), "a = '''\n     \n''';");
    });

    test('an escaped quote does not end the string', () {
      expect(mask(r"f('a\'b'); c"), "f('    '); c");
    });

    test('a raw string ends at the first quote', () {
      expect(mask(r"f(r'\'); c"), "f(r' '); c");
    });

    test('an identifier ending in r does not make a string raw', () {
      expect(mask(r"bar'a\'b'; c"), "bar'    '; c");
    });

    test('keeps the code inside an interpolation', () {
      expect(mask(r"f('a ${b.c} d');"), r"f('  ${b.c}  ');");
    });

    test('a string inside an interpolation is blanked too', () {
      expect(mask(r"f('${m['k']} }');"), r"f('${m[' ']}  ');");
    });

    test('a simple interpolation stays part of the string', () {
      expect(mask(r"f('a $b c');"), "f('      ');");
    });

    test('a quote inside a comment does not open a string', () {
      expect(mask("// don't\na = 1;"), '        \na = 1;');
    });
  });

  group('blocks', () {
    test('a brace inside a string is not a block', () {
      final masked = MaskedSource("void f() { g('}'); }");

      expect(masked.blocks, hasLength(1));
      expect(masked.blocks.single.open, 9);
      expect(masked.blocks.single.close, 19);
    });

    test('enclosing lists the blocks around an offset, innermost first', () {
      const source = 'a() { b() { c; } }';
      final masked = MaskedSource(source);

      final chain = masked.enclosing(source.indexOf('c;'));

      expect(chain.map((block) => block.open), [10, 4]);
    });

    test('an offset outside every block has no enclosing block', () {
      expect(MaskedSource('a; b() { c; }').enclosing(0), isEmpty);
    });

    test('headerOf is the text that introduces a block', () {
      const source = "x; tearDown(() async { y; });";
      final masked = MaskedSource(source);

      expect(masked.headerOf(masked.blocks.single).trim(), 'tearDown(() async');
    });

    test('headerOf reads past a brace inside the argument list', () {
      const source = 'x; test(a, skip: f({b: 1}), () { y; });';
      final masked = MaskedSource(source);
      final body = masked.enclosing(source.indexOf('y;')).first;

      expect(masked.headerOf(body).trim(), 'test(a, skip: f({b: 1}), ()');
    });

    test('statementBefore is the statement up to an offset', () {
      const source = 'x; tearDown(() => a = b);';
      final masked = MaskedSource(source);

      expect(
        masked.statementBefore(source.indexOf('a = b')).trim(),
        'tearDown(() =>',
      );
    });

    test('lineOf counts from one', () {
      final masked = MaskedSource('a;\nb;\nc;');

      expect(masked.lineOf(0), 1);
      expect(masked.lineOf(masked.code.indexOf('c;')), 3);
    });
  });

  test('text keeps strings and drops comments', () {
    final masked = MaskedSource("f('a/b'); // 'c/d'\n");

    expect(masked.text, "f('a/b');         \n");
  });
}
