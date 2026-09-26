import 'dart:convert';
import 'dart:io';

/// Extracts the visible text of a generated PDF so tests can assert on what a
/// diver actually reads, not just on "some bytes came back".
///
/// The `pdf` package writes each page's content stream Flate-compressed, with
/// one text-showing operator per word:
///
/// ```
/// BT /F9 14 Tf 0 Tc 0 3.388 Td [(Total)]TJ ET
/// ```
///
/// [pdfVisibleText] inflates every stream object, pulls the literal strings out
/// of the `[...]TJ` operators in document order, and joins them with single
/// spaces. Word-level tokens mean a phrase such as `Total Dive Time` reassembles
/// exactly, while glyph positioning is ignored.
String pdfVisibleText(List<int> bytes) => pdfTextTokens(bytes).join(' ');

/// Number of pages in the generated PDF.
///
/// Counts `/Type /Page` object headers, ignoring the single `/Type /Pages`
/// tree node. Lets a test assert on pagination (one dive per page, a
/// certification list that spills onto a second sheet) rather than only on
/// the text that came back.
int pdfPageCount(List<int> bytes) =>
    _pageObject.allMatches(latin1.decode(bytes, allowInvalid: true)).length;

/// `/Type /Page` not followed by an `s`, so `/Type /Pages` does not match.
final _pageObject = RegExp(r'/Type\s*/Page(?![s\w])');

/// The individual text tokens of [bytes], in document order.
List<String> pdfTextTokens(List<int> bytes) {
  final tokens = <String>[];
  for (final stream in _streamPayloads(bytes)) {
    for (final match in _showTextArray.allMatches(stream)) {
      for (final literal in _literal.allMatches(match.group(1)!)) {
        final text = _unescape(literal.group(1)!);
        if (text.isNotEmpty) tokens.add(text);
      }
    }
  }
  return tokens;
}

/// The text tokens of [bytes] paired with their baseline height, in document
/// order, so a test can assert on vertical spacing.
///
/// A height is in points from the bottom of the page. The `pdf` package draws
/// a word either with an absolute `Td` or with a relative `Td` inside a
/// `q 1 0 0 1 x y cm ... Q` translation, so this follows `q`/`Q` and `cm`
/// translations and accumulates `Td` offsets within each `BT`. It ignores
/// scaling and rotation, so it only suits plain text pages without charts.
/// Heights from different pages are not comparable.
List<({String text, double y})> pdfTextBaselines(List<int> bytes) {
  final result = <({String text, double y})>[];
  for (final stream in _streamPayloads(bytes)) {
    final stack = <double>[];
    var translateY = 0.0;
    var lineY = 0.0;
    for (final op in _positionOp.allMatches(stream)) {
      if (op.group(1) != null) {
        // Six operands: a b c d e f cm. Only f, the y translation, is kept.
        final f = double.parse(op.group(1)!.trim().split(RegExp(r'\s+')).last);
        translateY += f;
      } else if (op.group(2) != null) {
        lineY += double.parse(op.group(2)!);
      } else if (op.group(3) != null) {
        for (final literal in _literal.allMatches(op.group(3)!)) {
          final text = _unescape(literal.group(1)!);
          if (text.isNotEmpty) result.add((text: text, y: translateY + lineY));
        }
      } else {
        switch (op.group(0)) {
          case 'BT':
            lineY = 0;
          case 'q':
            stack.add(translateY);
          case 'Q':
            if (stack.isNotEmpty) translateY = stack.removeLast();
        }
      }
    }
  }
  return result;
}

/// The text of a PDF whose fonts are embedded as Unicode subsets, decoded once
/// per subset.
///
/// Once PdfFonts loads Roboto, the `pdf` package writes each word as a hex
/// string of indices into that font's subset (`[<00120003>]TJ`) and gives each
/// font a `ToUnicode` map (`<0012> <0047>` pairs) to read them back, which is
/// why [pdfVisibleText] finds nothing. Which font a word was set in is not
/// tracked, so every map decodes every word: one returned string reads as the
/// text set in that font and the rest are noise. Assert with
/// `anyElement(contains(...))`.
List<String> pdfSubsetTexts(List<int> bytes) {
  final streams = _streamPayloads(bytes).toList();
  final maps = [
    for (final stream in streams)
      if (stream.indexOf('beginbfchar') case final at when at >= 0)
        {
          for (final pair in _bfchar.allMatches(stream.substring(at)))
            int.parse(pair.group(1)!, radix: 16): int.parse(
              pair.group(2)!,
              radix: 16,
            ),
        },
  ];
  // One entry per `[...]TJ` array; kerning can split a word across several
  // hex strings inside one array.
  final words = [
    for (final stream in streams)
      for (final array in _showTextArray.allMatches(stream))
        _hexString.allMatches(array.group(1)!).map((h) => h.group(1)!).join(),
  ]..removeWhere((word) => word.isEmpty);
  return [
    for (final map in maps)
      [
        for (final word in words)
          String.fromCharCodes([
            for (var i = 0; i + 4 <= word.length; i += 4)
              map[int.parse(word.substring(i, i + 4), radix: 16)] ?? 0xFFFD,
          ]),
      ].join(' '),
  ];
}

/// One `<index> <code point>` entry of a `ToUnicode` map.
final _bfchar = RegExp(r'<([0-9A-Fa-f]{4})>\s*<([0-9A-Fa-f]{4})>');

/// A PDF hex string, as a Unicode subset font writes text.
final _hexString = RegExp(r'<([0-9A-Fa-f]+)>');

/// `cm` with its six operands, the y operand of `Td`, a `[...]TJ` array, or a
/// bare `BT`, `q` or `Q`.
final _positionOp = RegExp(
  r'((?:-?[\d.]+\s+){6})cm'
  r'|-?[\d.]+\s+(-?[\d.]+)\s+Td'
  r'|\[(.*?)\]\s*TJ'
  r'|\b(?:BT|q|Q)\b',
  dotAll: true,
);

/// `[(word)]TJ` / `[(a) -20 (b)] TJ` text-showing operators.
final _showTextArray = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true);

/// A PDF literal string, honoring backslash escapes.
final _literal = RegExp(r'\(((?:[^()\\]|\\.)*)\)');

String _unescape(String raw) =>
    raw.replaceAll(r'\(', '(').replaceAll(r'\)', ')').replaceAll(r'\\', r'\');

/// Inflates every `stream ... endstream` object, skipping the ones that are not
/// zlib-compressed (images, embedded fonts) rather than failing on them.
Iterable<String> _streamPayloads(List<int> bytes) sync* {
  const begin = [0x73, 0x74, 0x72, 0x65, 0x61, 0x6D]; // 'stream'
  const end = [
    0x65, 0x6E, 0x64, 0x73, 0x74, 0x72, 0x65, 0x61, 0x6D, // 'endstream'
  ];

  var cursor = 0;
  while (true) {
    final open = _indexOf(bytes, begin, cursor);
    if (open < 0) return;
    var start = open + begin.length;
    if (start < bytes.length && bytes[start] == 0x0D) start++;
    if (start < bytes.length && bytes[start] == 0x0A) start++;
    final close = _indexOf(bytes, end, start);
    if (close < 0) return;
    cursor = close + end.length;

    try {
      yield latin1.decode(zlib.decode(bytes.sublist(start, close)));
    } catch (_) {
      // Not a zlib payload (raw image data, an embedded font); nothing to read.
      continue;
    }
  }
}

int _indexOf(List<int> haystack, List<int> needle, int from) {
  outer:
  for (var i = from; i <= haystack.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}
