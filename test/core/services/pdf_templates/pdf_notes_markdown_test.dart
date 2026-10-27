import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/services/pdf_templates/pdf_notes_markdown.dart';

import '../../../helpers/pdf_text.dart';

void main() {
  const style = pw.TextStyle(fontSize: 10);

  Future<List<int>> render(List<pw.Widget> widgets) {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(build: (_) => widgets));
    return doc.save();
  }

  test('block output has one widget per block', () {
    expect(
      notesMarkdownPdfBlocks('# H\n\npara\n\n- a\n- b', style: style),
      hasLength(3),
    );
  });

  test('empty notes give no widgets', () {
    expect(notesMarkdownPdfBlocks('  ', style: style), isEmpty);
  });

  test('formatted text prints without its marks', () async {
    final bytes = await render(
      notesMarkdownPdfBlocks(
        '# Wreck\nViz **great**\n\n- turtle\n\n1. o-ring\n\n[shop](https://s.test)',
        style: style,
      ),
    );
    final text = pdfVisibleText(bytes);
    expect(text, contains('Wreck'));
    expect(text, contains('great'));
    expect(text, contains('turtle'));
    expect(text, contains('o-ring'));
    expect(text, contains('shop'));
    expect(text, isNot(contains('**')));
    expect(text, isNot(contains('#')));
  });

  test('single line breaks survive', () async {
    final bytes = await render(
      notesMarkdownPdfBlocks('LineOne\nLineTwo', style: style),
    );
    final lines = pdfTextBaselines(bytes);
    final one = lines.firstWhere((t) => t.text.contains('LineOne')).y;
    final two = lines.firstWhere((t) => t.text.contains('LineTwo')).y;
    expect(one, isNot(two));
  });

  test('a long formatted note spans pages', () async {
    final note = List.generate(
      200,
      (i) => '- item **$i** of a list',
    ).join('\n');
    final bytes = await render(notesMarkdownPdfBlocks(note, style: style));
    expect(pdfPageCount(bytes), greaterThan(1));
  });

  test('one very long paragraph spans pages', () async {
    final note = List.generate(400, (i) => 'Sentence *$i* here.').join(' ');
    final bytes = await render(notesMarkdownPdfBlocks(note, style: style));
    expect(pdfPageCount(bytes), greaterThan(1));
  });

  test('every construct renders without throwing', () async {
    const note =
        '# H1\n## H2\n### H3\n\ntext **b** *i* ~~s~~ `c`\n\n> quote\n\n'
        '```\ncode\n```\n\n---\n\n- [ ] task\n- [x] done\n\n'
        '| a | b |\n|---|---|\n| 1 | 2 |\n\n![reef](https://x.test/a.png)\n\n'
        '<u>html</u>';
    final bytes = await render(notesMarkdownPdfBlocks(note, style: style));
    expect(pdfVisibleText(bytes), contains('html'));
  });

  test('inline output keeps the cap and the marks are gone', () async {
    final widget = notesMarkdownPdfInline(
      '# Plan\n**bring** torch',
      style: style,
      maxLines: 2,
    );
    expect(widget, isA<pw.RichText>());
    expect((widget as pw.RichText).maxLines, 2);
    final text = pdfVisibleText(await render([widget]));
    expect(text, contains('bring'));
    expect(text, isNot(contains('**')));
  });

  test('inline output keeps table cells apart', () async {
    final widget = notesMarkdownPdfInline(
      '| a | b |\n|---|---|\n| 1 | 2 |',
      style: style,
      maxLines: 3,
    );
    expect((widget as pw.RichText).text.toPlainText(), 'a | b\n1 | 2');
  });

  test('inline output flattens lists, code and quotes to lines', () {
    final widget = notesMarkdownPdfInline(
      '- a\n- [x] b\n  - nested\n\n3. c\n\n```\ncode\n```\n\n> q ~~s~~\n\n---',
      style: style,
      maxLines: 9,
    );
    expect(
      (widget as pw.RichText).text.toPlainText(),
      '- a\n[x] b\n3. c\ncode\nq s',
    );
  });

  test('inline output keeps a loose list item and a hard break', () {
    final widget = notesMarkdownPdfInline(
      '- a\n\n- b\n\nline  \nbreak',
      style: style,
      maxLines: 9,
    );
    expect((widget as pw.RichText).text.toPlainText(), '- a\n- b\nline\nbreak');
  });

  test('nested, loose and task lists render in the block output', () async {
    final bytes = await render(
      notesMarkdownPdfBlocks(
        '- outer\n  - inner\n\n- loose\n\n- [ ] task\n\nline  \nbreak ~~old~~',
        style: style,
      ),
    );
    final text = pdfVisibleText(bytes);
    for (final word in ['outer', 'inner', 'loose', '[ ]', 'task', 'old']) {
      expect(text, contains(word), reason: word);
    }
  });

  test('a code block taller than a page spans pages', () async {
    final code = List.generate(300, (i) => 'log line $i').join('\n');
    final bytes = await render(
      notesMarkdownPdfBlocks('```\n$code\n```', style: style),
    );
    expect(pdfPageCount(bytes), greaterThan(1));
  });

  test('a loose list item keeps its paragraphs apart', () async {
    const note = '- Check o-ring\n\n  Replace if cracked';
    final inlineText =
        (notesMarkdownPdfInline(note, style: style, maxLines: 4) as pw.RichText)
            .text
            .toPlainText();
    expect(inlineText, '- Check o-ring\nReplace if cracked');
    final blockText = pdfVisibleText(
      await render(notesMarkdownPdfBlocks(note, style: style)),
    );
    expect(blockText, isNot(contains('o-ringReplace')));
    expect(blockText, contains('Replace'));
  });

  test('code outside Latin-1 keeps the theme font', () {
    pw.TextStyle? codeStyle(String source, String text) {
      final spans = <pw.InlineSpan>[];
      void walk(pw.InlineSpan span) {
        spans.add(span);
        if (span is pw.TextSpan) span.children?.forEach(walk);
      }

      walk(
        (notesMarkdownPdfInline(source, style: style, maxLines: 3)
                as pw.RichText)
            .text,
      );
      return spans
          .whereType<pw.TextSpan>()
          .firstWhere((s) => s.text == text)
          .style;
    }

    expect(codeStyle('`abc`', 'abc')?.font, isNotNull);
    expect(codeStyle('`ellenőrző`', 'ellenőrző')?.font, isNull);

    final block =
        notesMarkdownPdfBlocks('```\n日志\n```', style: style).single
            as pw.Padding;
    final text = (block.child! as pw.Container).child! as pw.Text;
    expect((text.text as pw.TextSpan).style?.font, isNull);
  });
}
