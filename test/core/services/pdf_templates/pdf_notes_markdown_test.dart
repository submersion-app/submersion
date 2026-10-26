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
}
