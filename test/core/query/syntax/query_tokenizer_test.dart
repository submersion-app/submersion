import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/syntax/query_tokenizer.dart';

void main() {
  test('splits words, numbers with suffixes, symbols and quotes', () {
    final t = tokenize(
      'depth >= 100ft AND site.country = "Bob\'s \\"Reef\\"" -tag:none (x)',
    );
    expect(t.map((x) => x.kind), [
      TokenKind.word,
      TokenKind.symbol,
      TokenKind.number,
      TokenKind.word,
      TokenKind.word,
      TokenKind.symbol,
      TokenKind.quoted,
      TokenKind.symbol,
      TokenKind.word,
      TokenKind.symbol,
      TokenKind.word,
      TokenKind.symbol,
      TokenKind.word,
      TokenKind.symbol,
      TokenKind.end,
    ]);
    expect(t[2].text, '100ft');
    expect(t[6].text, 'Bob\'s "Reef"');
    expect(t[6].offset, 34);
  });

  test('ISO dates are words, not numbers', () {
    expect(tokenize('2025-03-14').first.kind, TokenKind.word);
    expect(tokenize('2025-03').first.kind, TokenKind.word);
    expect(tokenize('2025').first.kind, TokenKind.number);
  });

  test('two-character operators are one symbol', () {
    final t = tokenize('a != b <= c >= d');
    expect(t.where((x) => x.kind == TokenKind.symbol).map((x) => x.text), [
      '!=',
      '<=',
      '>=',
    ]);
  });

  test('an unterminated quote reports its offset', () {
    expect(
      () => tokenize('site = "Salt'),
      throwsA(isA<TokenizeException>().having((e) => e.offset, 'offset', 7)),
    );
  });
}
