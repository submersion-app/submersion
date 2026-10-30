import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:submersion/core/text/markdown/notes_markdown.dart';

/// Element tags in document order, depth first, comma separated.
String tags(List<md.Node> nodes) {
  final out = <String>[];
  void walk(md.Node node) {
    if (node is md.Element) {
      out.add(node.tag);
      for (final child in node.children ?? const <md.Node>[]) {
        walk(child);
      }
    }
  }

  nodes.forEach(walk);
  return out.join(',');
}

/// Only the block-level tags.
String blocks(List<md.Node> nodes) =>
    nodes.whereType<md.Element>().map((e) => e.tag).join(',');

void main() {
  group('parseNotesMarkdown', () {
    test('ATX headings of every level parse', () {
      expect(blocks(parseNotesMarkdown('# A\n###### F')), 'h1,h6');
    });

    test('setext headings stay a paragraph', () {
      expect(blocks(parseNotesMarkdown('Second dive\n=====')), 'p');
    });

    test('dashes under text are a rule, not a heading', () {
      expect(blocks(parseNotesMarkdown('Second dive\n-----')), 'p,hr');
    });

    test('indented lines are not a code block', () {
      final nodes = parseNotesMarkdown('a\n\n    indented');
      expect(blocks(nodes), 'p,p');
      expect(nodes.last.textContent.trim(), 'indented');
    });

    test('fenced code is a code block', () {
      expect(blocks(parseNotesMarkdown('```\nx\n```')), 'pre');
    });

    test('raw HTML stays literal text', () {
      final nodes = parseNotesMarkdown('<b>hi</b>');
      expect(blocks(nodes), 'p');
      expect(nodes.single.textContent, '<b>hi</b>');
    });

    test('a block of HTML stays a literal paragraph', () {
      final nodes = parseNotesMarkdown('<div>\nhi\n</div>');
      expect(blocks(nodes), 'p');
      expect(nodes.single.textContent, '<div>\nhi\n</div>');
    });

    test('an image parses as img', () {
      expect(
        tags(parseNotesMarkdown('![reef](https://x.test/a.png)')),
        'p,img',
      );
    });

    test('single line breaks survive inside a paragraph', () {
      expect(
        parseNotesMarkdown('Saw turtle\nSaw shark').single.textContent,
        'Saw turtle\nSaw shark',
      );
    });

    test('Windows line endings parse like Unix ones', () {
      expect(
        parseNotesMarkdown('Saw turtle\r\nSaw shark').single.textContent,
        'Saw turtle\nSaw shark',
      );
    });

    test('bare www and https addresses autolink', () {
      for (final source in ['see www.reef.test', 'see https://reef.test']) {
        expect(tags(parseNotesMarkdown(source)), 'p,a', reason: source);
      }
    });

    test('inline formatting parses', () {
      expect(
        tags(parseNotesMarkdown('**b** *i* _u_ ~~s~~ `c` [l](https://l.test)')),
        'p,strong,em,em,del,code,a',
      );
    });

    test('lists, tasks, quotes and tables parse', () {
      expect(blocks(parseNotesMarkdown('- a\n- b')), 'ul');
      expect(blocks(parseNotesMarkdown('1. a\n2. b')), 'ol');
      expect(tags(parseNotesMarkdown('- [ ] a')), 'ul,li,input');
      expect(blocks(parseNotesMarkdown('> q')), 'blockquote');
      expect(
        blocks(parseNotesMarkdown('| a | b |\n|---|---|\n| 1 | 2 |')),
        'table',
      );
    });

    test('a backslash escape keeps the mark literal', () {
      final nodes = parseNotesMarkdown(r'5 \* 3 \* 2');
      expect(tags(nodes), 'p');
      expect(nodes.single.textContent, '5 * 3 * 2');
    });
  });

  test('isTappableNotesLink allows only http, https and mailto', () {
    expect(isTappableNotesLink('https://a.test'), isTrue);
    expect(isTappableNotesLink('http://a.test'), isTrue);
    expect(isTappableNotesLink('mailto:a@b.test'), isTrue);
    expect(isTappableNotesLink('javascript:alert(1)'), isFalse);
    expect(isTappableNotesLink('file:///etc/passwd'), isFalse);
    expect(isTappableNotesLink('relative/path'), isFalse);
    expect(isTappableNotesLink(null), isFalse);
  });

  test('notesListStart reads where a numbered list starts', () {
    md.Element list(String source) =>
        parseNotesMarkdown(source).single as md.Element;
    expect(notesListStart(list('3. a\n4. b')), 3);
    expect(notesListStart(list('1. a')), 1);
    expect(notesListStart(list('- a')), 1);
  });

  test('notesTaskState finds the box in tight and loose lists', () {
    List<md.Element> items(String source) => [
      for (final n
          in (parseNotesMarkdown(source).single as md.Element).children!)
        n as md.Element,
    ];
    expect(items('- [ ] a\n- [x] b\n- c').map(notesTaskState), [
      false,
      true,
      null,
    ]);
    expect(items('- a\n\n- [x] b').map(notesTaskState), [null, true]);
  });

  test('notesTableRows reads header and body rows', () {
    final table =
        parseNotesMarkdown('| a | b |\n|---|---|\n| 1 | 2 |').single
            as md.Element;
    final rows = notesTableRows(table);
    expect(rows.map((r) => r.header), [true, false]);
    expect(rows.map((r) => r.cells.map((c) => c.textContent).join(',')), [
      'a,b',
      '1,2',
    ]);
  });

  test('appendMarkdownParagraph starts a new paragraph', () {
    expect(appendMarkdownParagraph('', 'x'), 'x');
    expect(appendMarkdownParagraph('- a', 'x'), '- a\n\nx');
  });
}
