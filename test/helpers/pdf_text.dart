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
