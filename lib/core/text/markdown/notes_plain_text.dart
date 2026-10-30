import 'package:markdown/markdown.dart' as md;

import 'package:submersion/core/text/markdown/notes_markdown.dart';

/// A Markdown note as plain words, for places that cannot draw formatting:
/// list subtitles, table cells, Excel and the CSVs Submersion cannot read
/// back. Marks go, structure stays readable: headings keep their words,
/// bullets become `- item`, numbered items keep their numbers, tasks show
/// `[ ]` or `[x]`, links show `text (address)`.
String markdownToPlainText(String source) {
  if (source.trim().isEmpty) return '';
  final cached = _cache.remove(source);
  if (cached != null) return _cache[source] = cached;
  final plain = _blocks(
    parseNotesMarkdown(source),
    indent: '',
  ).join('\n').trim();
  if (_cache.length >= _cacheSize) _cache.remove(_cache.keys.first);
  return _cache[source] = plain;
}

/// Recent results, least recently used first: list rows and table cells ask
/// for the same notes on every rebuild, and parsing is the costly part.
final _cache = <String, String>{};
const _cacheSize = 256;

List<String> _blocks(List<md.Node> nodes, {required String indent}) {
  final lines = <String>[];
  for (final node in nodes) {
    if (node is md.Text) {
      final text = node.text.trim();
      if (text.isNotEmpty) lines.add('$indent$text');
      continue;
    }
    if (node is! md.Element) continue;
    switch (node.tag) {
      case 'ul':
      case 'ol':
        lines.addAll(_list(node, indent: indent));
      case 'blockquote':
        lines.addAll(_blocks(node.children ?? const [], indent: indent));
      case 'pre':
        final code = node.textContent.replaceFirst(RegExp(r'\n$'), '');
        lines.addAll(code.split('\n').map((line) => '$indent$line'));
      case 'hr':
        lines.add('$indent---');
      case 'table':
        lines.addAll(_table(node).map((row) => '$indent$row'));
      default:
        final text = _inline(node.children ?? const []);
        if (text.trim().isNotEmpty) lines.add('$indent$text');
    }
  }
  return lines;
}

List<String> _list(md.Element list, {required String indent}) {
  final ordered = list.tag == 'ol';
  var number = notesListStart(list);
  final lines = <String>[];
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
    final nested = <md.Element>[];
    for (final child in children) {
      if (child is md.Element && (child.tag == 'ul' || child.tag == 'ol')) {
        nested.add(child);
      } else if (!(child is md.Element && child.tag == 'input')) {
        own.add(child);
      }
    }
    final text = _blocks(own, indent: '').join('\n');
    lines.add('$indent$marker $text'.trimRight());
    for (final sub in nested) {
      lines.addAll(_list(sub, indent: '$indent  '));
    }
  }
  return lines;
}

List<String> _table(md.Element table) => [
  for (final row in notesTableRows(table))
    [
      for (final cell in row.cells) _inline(cell.children ?? const []).trim(),
    ].join(' | '),
];

String _inline(List<md.Node> nodes) {
  final out = StringBuffer();
  for (final node in nodes) {
    if (node is md.Text) {
      out.write(node.text);
    } else if (node is md.Element) {
      switch (node.tag) {
        case 'br':
          out.write('\n');
        case 'a':
          out.write(
            _linkText(
              _inline(node.children ?? const []),
              node.attributes['href'],
            ),
          );
        case 'img':
          out.write(
            _linkText(node.attributes['alt'] ?? '', node.attributes['src']),
          );
        default:
          out.write(_inline(node.children ?? const []));
      }
    }
  }
  return out.toString();
}

/// `text (address)`, or just the address when the text adds nothing.
String _linkText(String text, String? href) {
  if (href == null || href.isEmpty) return text;
  if (text.isEmpty ||
      text == href ||
      'http://$text' == href ||
      'https://$text' == href ||
      'mailto:$text' == href) {
    return text.isEmpty ? href : text;
  }
  return '$text ($href)';
}
