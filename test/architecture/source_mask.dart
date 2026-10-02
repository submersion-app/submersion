/// Dart source prepared for a pattern scan.
///
/// A scan over raw text cannot tell code from a comment or from a string that
/// happens to hold code, such as a test fixture. [MaskedSource.code] blanks
/// both, and keeps every offset and line break where it was, so a match sits
/// on the same line as in the original. Code inside a string interpolation is
/// kept, because it runs.
library;

const _newline = 0x0A;
const _space = 0x20;
const _doubleQuote = 0x22;
const _dollar = 0x24;
const _singleQuote = 0x27;
const _openParen = 0x28;
const _closeParen = 0x29;
const _semicolon = 0x3B;
const _backslash = 0x5C;
const _openBrace = 0x7B;
const _closeBrace = 0x7D;

/// A brace block, by the offsets of its braces.
typedef Block = ({int open, int close});

class MaskedSource {
  MaskedSource(this.source) {
    final masker = _Masker(source)..skipCode(0);
    code = String.fromCharCodes(masker.code);
    text = String.fromCharCodes(masker.text);

    final open = <int>[];
    for (var i = 0; i < code.length; i++) {
      final unit = code.codeUnitAt(i);
      if (unit == _openBrace) {
        open.add(i);
      } else if (unit == _closeBrace && open.isNotEmpty) {
        blocks.add((open: open.removeLast(), close: i));
      }
    }
  }

  final String source;

  /// [source] with comments and the contents of strings blanked.
  late final String code;

  /// [source] with comments blanked and strings kept.
  late final String text;

  /// Every brace block in [code].
  final List<Block> blocks = [];

  /// The 1-based line that holds [offset].
  int lineOf(int offset) {
    var line = 1;
    for (var i = 0; i < offset; i++) {
      if (code.codeUnitAt(i) == _newline) line++;
    }
    return line;
  }

  /// The blocks that contain [offset], innermost first.
  List<Block> enclosing(int offset) {
    final around = [
      for (final block in blocks)
        if (block.open < offset && offset < block.close) block,
    ];
    return around
      ..sort((a, b) => (a.close - a.open).compareTo(b.close - b.open));
  }

  /// The text that introduces [block], back to the statement or block before.
  String headerOf(Block block) =>
      code.substring(_statementStart(block.open), block.open);

  /// The statement that holds [offset], up to [offset].
  String statementBefore(int offset) =>
      code.substring(_statementStart(offset), offset);

  /// Where the statement that reaches [offset] begins.
  ///
  /// Walks back to a `;`, `{` or `}` that is not inside a parenthesis the
  /// statement itself closed, so a brace in an argument list is read past.
  int _statementStart(int offset) {
    var depth = 0;
    for (var i = offset - 1; i >= 0; i--) {
      final unit = code.codeUnitAt(i);
      if (unit == _closeParen) {
        depth++;
      } else if (unit == _openParen) {
        depth--;
      } else if (depth <= 0 &&
          (unit == _semicolon || unit == _openBrace || unit == _closeBrace)) {
        return i + 1;
      }
    }
    return 0;
  }
}

class _Masker {
  _Masker(this.source)
    : code = source.codeUnits.toList(),
      text = source.codeUnits.toList();

  final String source;
  final List<int> code;
  final List<int> text;

  void _blank(List<int> target, int from, int to) {
    for (var i = from; i < to && i < target.length; i++) {
      if (target[i] != _newline) target[i] = _space;
    }
  }

  bool _isIdentifierPart(int unit) =>
      (unit >= 0x30 && unit <= 0x39) ||
      (unit >= 0x41 && unit <= 0x5A) ||
      (unit >= 0x61 && unit <= 0x7A) ||
      unit == 0x5F ||
      unit == _dollar;

  /// Scans code from [from]. With [untilBrace] it stops after the `}` that
  /// closes an interpolation; otherwise it runs to the end.
  int skipCode(int from, {bool untilBrace = false}) {
    final end = source.length;
    var depth = 0;
    var i = from;
    while (i < end) {
      final unit = source.codeUnitAt(i);
      if (source.startsWith('//', i)) {
        final stop = source.indexOf('\n', i);
        final to = stop < 0 ? end : stop;
        _blank(code, i, to);
        _blank(text, i, to);
        i = to;
      } else if (source.startsWith('/*', i)) {
        final stop = source.indexOf('*/', i + 2);
        final to = stop < 0 ? end : stop + 2;
        _blank(code, i, to);
        _blank(text, i, to);
        i = to;
      } else if (unit == _singleQuote || unit == _doubleQuote) {
        i = _skipString(i);
      } else if (unit == _openBrace) {
        depth++;
        i++;
      } else if (unit == _closeBrace) {
        if (untilBrace && depth == 0) return i + 1;
        depth--;
        i++;
      } else {
        i++;
      }
    }
    return end;
  }

  /// Blanks the string whose opening quote is at [at], and returns the offset
  /// after its closing quote.
  int _skipString(int at) {
    final end = source.length;
    final quote = source[at];
    final raw =
        at > 0 &&
        source[at - 1] == 'r' &&
        (at < 2 || !_isIdentifierPart(source.codeUnitAt(at - 2)));
    final triple = source.startsWith(quote * 3, at);
    final close = triple ? quote * 3 : quote;

    var i = at + close.length;
    var from = i;
    while (i < end) {
      final unit = source.codeUnitAt(i);
      if (!raw && unit == _backslash) {
        i += 2;
      } else if (!raw &&
          unit == _dollar &&
          i + 1 < end &&
          source.codeUnitAt(i + 1) == _openBrace) {
        _blank(code, from, i);
        i = skipCode(i + 2, untilBrace: true);
        from = i;
      } else if (source.startsWith(close, i)) {
        _blank(code, from, i);
        return i + close.length;
      } else if (!triple && unit == _newline) {
        // An unterminated string: stop at the line end, as the compiler does.
        _blank(code, from, i);
        return i;
      } else {
        i++;
      }
    }
    _blank(code, from, end);
    return end;
  }
}
