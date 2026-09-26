import 'package:meta/meta.dart';

enum TokenKind { word, quoted, number, symbol, end }

@immutable
class Token {
  final TokenKind kind;

  /// For [TokenKind.quoted], the unescaped content; otherwise the raw text.
  final String text;
  final int offset;

  /// Source length, so a quoted token spans its quotes and escapes.
  final int length;
  const Token(this.kind, this.text, this.offset, this.length);
  @override
  String toString() => '$kind($text)@$offset';
}

class TokenizeException implements Exception {
  final String message;
  final int offset;
  const TokenizeException(this.message, this.offset);
  @override
  String toString() => 'TokenizeException($message @$offset)';
}

/// ISO-looking dates, padded or not, are ONE word token, so the date
/// grammar decides their validity; otherwise `2025-3-1` would read as the
/// number 2025 followed by two negated terms.
final RegExp _isoDate = RegExp(r'^\d{4}-\d{1,2}(-\d{1,2})?(?![\w.])');
final RegExp _number = RegExp(r'^\d+(\.\d+)?[A-Za-z]*');
const _twoCharSymbols = {'!=', '<=', '>='};
const _oneCharSymbols = {
  '(',
  ')',
  '[',
  ']',
  ',',
  ':',
  '~',
  '-',
  '&',
  '|',
  '=',
  '<',
  '>',
};

bool _isWordChar(String c) =>
    c.trim().isNotEmpty && !_oneCharSymbols.contains(c) && c != '"' && c != '!';

/// Splits query text into tokens. Throws [TokenizeException] (with the
/// offset) on an unterminated quote or a character no token accepts; the
/// parser turns that into a positioned failure.
List<Token> tokenize(String input) {
  final out = <Token>[];
  var i = 0;
  while (i < input.length) {
    final c = input[i];
    if (c.trim().isEmpty) {
      i++;
      continue;
    }
    if (c == '"') {
      final buf = StringBuffer();
      var j = i + 1;
      var closed = false;
      while (j < input.length) {
        final d = input[j];
        if (d == '\\' && j + 1 < input.length) {
          buf.write(input[j + 1]);
          j += 2;
          continue;
        }
        if (d == '"') {
          closed = true;
          j++;
          break;
        }
        buf.write(d);
        j++;
      }
      if (!closed) throw TokenizeException('unterminated quote', i);
      out.add(Token(TokenKind.quoted, buf.toString(), i, j - i));
      i = j;
      continue;
    }
    final rest = input.substring(i);
    if (i + 2 <= input.length &&
        _twoCharSymbols.contains(input.substring(i, i + 2))) {
      out.add(Token(TokenKind.symbol, input.substring(i, i + 2), i, 2));
      i += 2;
      continue;
    }
    if (_oneCharSymbols.contains(c)) {
      out.add(Token(TokenKind.symbol, c, i, 1));
      i++;
      continue;
    }
    final iso = _isoDate.firstMatch(rest);
    if (iso != null) {
      out.add(Token(TokenKind.word, iso[0]!, i, iso[0]!.length));
      i += iso[0]!.length;
      continue;
    }
    final number = _number.firstMatch(rest);
    if (number != null) {
      out.add(Token(TokenKind.number, number[0]!, i, number[0]!.length));
      i += number[0]!.length;
      continue;
    }
    var j = i;
    while (j < input.length && _isWordChar(input[j])) {
      j++;
    }
    if (j == i) throw TokenizeException('unexpected character "$c"', i);
    out.add(Token(TokenKind.word, input.substring(i, j), i, j - i));
    i = j;
  }
  out.add(Token(TokenKind.end, '', input.length, 0));
  return out;
}
