import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/text/markdown/notes_markdown.dart';

const _blockGap = 4.0;
const _markerWidth = 14.0;
const _nestIndent = 12.0;
const _linkColor = PdfColors.blue800;
const _muted = PdfColors.grey700;

/// A Markdown note for a PDF section with room to grow (#3683): one widget
/// per block, each able to break across pages, so a long note never throws
/// "Widget won't fit into the page" (#2056). Links are clickable in the PDF
/// when they are web or mail links.
List<pw.Widget> notesMarkdownPdfBlocks(
  String source, {
  required pw.TextStyle style,
}) {
  if (source.trim().isEmpty) return const [];
  final builder = _PdfNotesBuilder(style);
  return [
    for (final node in parseNotesMarkdown(source))
      if (builder.block(node, style) case final widget?)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: _blockGap),
          child: widget,
        ),
  ];
}

/// A Markdown note squeezed into a template's capped notes line: inline
/// styling (bold, italic, strikethrough, code, links) in one rich text of at
/// most [maxLines] lines. Blocks are flattened to lines the way plain words
/// are: headings keep their words, bullets become `- item`.
pw.Widget notesMarkdownPdfInline(
  String source, {
  required pw.TextStyle style,
  required int maxLines,
}) {
  final builder = _PdfNotesBuilder(style);
  final spans = <pw.InlineSpan>[];
  for (final node in parseNotesMarkdown(source)) {
    final line = builder.flatLine(node, style);
    if (line.isEmpty) continue;
    if (spans.isNotEmpty) spans.add(pw.TextSpan(text: '\n', style: style));
    spans.addAll(line);
  }
  return pw.RichText(
    text: pw.TextSpan(children: spans, style: style),
    maxLines: maxLines,
  );
}

/// Monospace for code, when the built-in Courier can draw it: Courier only
/// knows Latin-1, and a Latin-language PDF theme has no fallback font, so
/// code holding any other character (a Hungarian ő, Chinese, Arabic) keeps the
/// theme font rather than printing as boxes.
pw.TextStyle _codeStyle(String text, pw.TextStyle style) =>
    text.runes.every((rune) => rune < 0x100)
    ? style.copyWith(font: pw.Font.courier())
    : style;

class _PdfNotesBuilder {
  _PdfNotesBuilder(this.base);

  final pw.TextStyle base;

  pw.Widget? block(md.Node node, pw.TextStyle style, {int depth = 0}) {
    if (node is md.Text) {
      return node.text.trim().isEmpty ? null : _rich([node], style);
    }
    if (node is! md.Element) return null;
    final children = node.children ?? const <md.Node>[];
    final size = style.fontSize ?? 10;
    switch (node.tag) {
      case 'h1':
        return _rich(children, _heading(style, size + 4));
      case 'h2':
        return _rich(children, _heading(style, size + 2));
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return _rich(children, _heading(style, size));
      case 'ul':
      case 'ol':
        return _list(node, style, depth: depth);
      case 'blockquote':
        final quoteStyle = style.copyWith(
          color: _muted,
          fontStyle: pw.FontStyle.italic,
        );
        return pw.Padding(
          padding: const pw.EdgeInsets.only(left: 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [for (final child in children) ?block(child, quoteStyle)],
          ),
        );
      case 'pre':
        return pw.Container(
          padding: const pw.EdgeInsets.all(4),
          color: PdfColors.grey200,
          // Spans, so a code block taller than a page breaks across sheets
          // instead of failing the export (#2056).
          child: pw.Text(
            node.textContent.replaceFirst(RegExp(r'\n$'), ''),
            style: _codeStyle(node.textContent, style),
            overflow: pw.TextOverflow.span,
          ),
        );
      case 'hr':
        return pw.Divider(color: PdfColors.grey400, thickness: 0.5);
      case 'table':
        return _table(node, style);
      default:
        return _rich(children, style);
    }
  }

  pw.TextStyle _heading(pw.TextStyle style, double size) =>
      style.copyWith(fontSize: size, fontWeight: pw.FontWeight.bold);

  pw.Widget _rich(List<md.Node> nodes, pw.TextStyle style) => pw.RichText(
    text: pw.TextSpan(children: inline(nodes, style)),
    overflow: pw.TextOverflow.span,
  );

  pw.Widget _list(md.Element list, pw.TextStyle style, {required int depth}) {
    final ordered = list.tag == 'ol';
    var number = notesListStart(list);
    final rows = <pw.Widget>[];
    for (final item in list.children ?? const <md.Node>[]) {
      if (item is! md.Element) continue;
      final children = item.children ?? const <md.Node>[];
      final marker = switch (notesTaskState(item)) {
        true => '[x]',
        false => '[ ]',
        null => ordered ? '$number.' : '-',
      };
      number++;
      final own = <md.Node>[];
      final nested = <pw.Widget>[];
      for (final child in children) {
        if (child is md.Element && child.tag == 'input') {
          continue;
        } else if (child is md.Element &&
            (child.tag == 'ul' || child.tag == 'ol' || child.tag == 'p')) {
          if (child.tag == 'p') {
            // A loose item's paragraphs each start a line.
            if (own.isNotEmpty) own.add(md.Text('\n'));
            own.addAll(child.children ?? const []);
          } else {
            nested.add(_list(child, style, depth: depth + 1));
          }
        } else {
          own.add(child);
        }
      }
      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: marker.length > 2 ? _markerWidth + 6 : _markerWidth,
              child: pw.Text(marker, style: style),
            ),
            pw.Expanded(
              child: pw.RichText(
                text: pw.TextSpan(children: inline(own, style)),
              ),
            ),
          ],
        ),
      );
      rows.addAll(nested);
    }
    return pw.Padding(
      padding: pw.EdgeInsets.only(left: depth * _nestIndent),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  pw.Widget _table(md.Element table, pw.TextStyle style) => pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    children: [
      for (final row in notesTableRows(table))
        pw.TableRow(
          children: [
            for (final cell in row.cells)
              pw.Padding(
                padding: const pw.EdgeInsets.all(3),
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: inline(
                      cell.children ?? const [],
                      row.header
                          ? style.copyWith(fontWeight: pw.FontWeight.bold)
                          : style,
                    ),
                  ),
                ),
              ),
          ],
        ),
    ],
  );

  /// One block as a single line of spans, for the capped inline output.
  List<pw.InlineSpan> flatLine(md.Node node, pw.TextStyle style) {
    if (node is md.Text) {
      return node.text.trim().isEmpty ? const [] : inline([node], style);
    }
    if (node is! md.Element) return const [];
    final children = node.children ?? const <md.Node>[];
    switch (node.tag) {
      case 'ul':
      case 'ol':
        final ordered = node.tag == 'ol';
        var number = notesListStart(node);
        final spans = <pw.InlineSpan>[];
        for (final item in children) {
          if (item is! md.Element) continue;
          if (spans.isNotEmpty) {
            spans.add(pw.TextSpan(text: '\n', style: style));
          }
          final marker = switch (notesTaskState(item)) {
            true => '[x]',
            false => '[ ]',
            null => ordered ? '$number.' : '-',
          };
          number++;
          spans.add(pw.TextSpan(text: '$marker ', style: style));
          var paragraphs = 0;
          for (final child in item.children ?? const <md.Node>[]) {
            if (child is md.Element && child.tag == 'p') {
              if (paragraphs++ > 0) {
                spans.add(pw.TextSpan(text: '\n', style: style));
              }
              spans.addAll(inline(child.children ?? const [], style));
            } else if (child is md.Element &&
                (child.tag == 'ul' ||
                    child.tag == 'ol' ||
                    child.tag == 'input')) {
              continue;
            } else {
              spans.addAll(inline([child], style));
            }
          }
        }
        return spans;
      case 'pre':
        return [pw.TextSpan(text: node.textContent.trim(), style: style)];
      case 'hr':
        return const [];
      case 'table':
        final rows = [
          for (final row in notesTableRows(node))
            row.cells.map((cell) => cell.textContent.trim()).join(' | '),
        ];
        return [pw.TextSpan(text: rows.join('\n'), style: style)];
      case 'blockquote':
        final spans = <pw.InlineSpan>[];
        for (final child in children) {
          spans.addAll(flatLine(child, style));
        }
        return spans;
      default:
        return inline(children, style);
    }
  }

  List<pw.InlineSpan> inline(List<md.Node> nodes, pw.TextStyle style) {
    final spans = <pw.InlineSpan>[];
    for (final node in nodes) {
      if (node is md.Text) {
        spans.add(pw.TextSpan(text: node.text, style: style));
        continue;
      }
      if (node is! md.Element) continue;
      final children = node.children ?? const <md.Node>[];
      switch (node.tag) {
        case 'strong':
          spans.addAll(
            inline(children, style.copyWith(fontWeight: pw.FontWeight.bold)),
          );
        case 'em':
          spans.addAll(
            inline(children, style.copyWith(fontStyle: pw.FontStyle.italic)),
          );
        case 'del':
          spans.addAll(
            inline(
              children,
              style.copyWith(decoration: pw.TextDecoration.lineThrough),
            ),
          );
        case 'code':
          spans.add(
            pw.TextSpan(
              text: node.textContent,
              style: _codeStyle(node.textContent, style),
            ),
          );
        case 'br':
          spans.add(pw.TextSpan(text: '\n', style: style));
        case 'a':
          spans.addAll(_link(children, node.attributes['href'], style));
        case 'img':
          final src = node.attributes['src'];
          final alt = node.attributes['alt'] ?? '';
          spans.addAll(
            _link([md.Text(alt.isEmpty ? (src ?? '') : alt)], src, style),
          );
        default:
          spans.addAll(inline(children, style));
      }
    }
    return spans;
  }

  List<pw.InlineSpan> _link(
    List<md.Node> children,
    String? href,
    pw.TextStyle style,
  ) {
    if (!isTappableNotesLink(href)) return inline(children, style);
    return [
      pw.TextSpan(
        children: inline(
          children,
          style.copyWith(
            color: _linkColor,
            decoration: pw.TextDecoration.underline,
          ),
        ),
        annotation: pw.AnnotationUrl(href!),
      ),
    ];
  }
}
