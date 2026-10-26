import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/text/markdown/notes_plain_text.dart';

void main() {
  group('markdownToPlainText', () {
    test('drops inline marks', () {
      expect(
        markdownToPlainText('Viz was **great**, *maybe* ~~20~~ `25` m'),
        'Viz was great, maybe 20 25 m',
      );
    });

    test('a heading keeps its words', () {
      expect(markdownToPlainText('# Descent\nViz good'), 'Descent\nViz good');
    });

    test('bullets become dash lines', () {
      expect(markdownToPlainText('- a\n- b'), '- a\n- b');
      expect(markdownToPlainText('* a\n+ b'), '- a\n- b');
    });

    test('numbered items keep their numbers from the start', () {
      expect(markdownToPlainText('3. a\n4. b'), '3. a\n4. b');
    });

    test('nested lists indent', () {
      expect(markdownToPlainText('- a\n  - b'), '- a\n  - b');
    });

    test('task items show their box', () {
      expect(
        markdownToPlainText('- [ ] fins\n- [x] mask'),
        '[ ] fins\n[x] mask',
      );
    });

    test('a task in a loose list keeps its box', () {
      expect(markdownToPlainText('- loose\n\n- [x] done'), '- loose\n[x] done');
    });

    test('a link shows its text and address', () {
      expect(
        markdownToPlainText('[shop](https://s.test)'),
        'shop (https://s.test)',
      );
    });

    test('a bare address shows once', () {
      expect(markdownToPlainText('https://s.test'), 'https://s.test');
    });

    test('an image shows like a link', () {
      expect(
        markdownToPlainText('![reef](https://x.test/a.png)'),
        'reef (https://x.test/a.png)',
      );
      expect(
        markdownToPlainText('![](https://x.test/a.png)'),
        'https://x.test/a.png',
      );
    });

    test('a quote drops its mark', () {
      expect(markdownToPlainText('> quoted'), 'quoted');
    });

    test('a table joins its cells', () {
      expect(
        markdownToPlainText('| a | b |\n|---|---|\n| 1 | 2 |'),
        'a | b\n1 | 2',
      );
    });

    test('a code block keeps its lines', () {
      expect(markdownToPlainText('```\nx = 1\ny = 2\n```'), 'x = 1\ny = 2');
    });

    test('a rule becomes a dashed line', () {
      expect(markdownToPlainText('a\n\n---\n\nb'), 'a\n---\nb');
    });

    test('HTML stays as typed', () {
      expect(markdownToPlainText('<u>x</u>'), '<u>x</u>');
    });

    test('single line breaks survive', () {
      expect(
        markdownToPlainText('Saw turtle\nSaw shark'),
        'Saw turtle\nSaw shark',
      );
    });

    test('an escaped mark shows the mark', () {
      expect(markdownToPlainText(r'5 \* 3'), '5 * 3');
    });

    test('paragraphs are separated by one line', () {
      expect(markdownToPlainText('a\n\nb'), 'a\nb');
    });

    test('empty stays empty', () {
      expect(markdownToPlainText(''), '');
      expect(markdownToPlainText('  \n '), '');
    });
  });
}
