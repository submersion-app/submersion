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
    // Unpadded dates are one token too, so the grammar can refuse them
    // instead of the parser reading a year followed by junk.
    expect(tokenize('2025-3-1').first.kind, TokenKind.word);
    expect(tokenize('2025-3-1').first.text, '2025-3-1');
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

  // Code review (#2773): plain text in the dive search row used to match
  // literally; a hyphen inside a word is part of it, and only a hyphen that
  // starts a term negates it.
  test('a hyphen inside a word is part of the word', () {
    final t = tokenize('Abu-Nuhas U-352 -wreck a -b');
    expect(t.map((x) => (x.kind, x.text)), [
      (TokenKind.word, 'Abu-Nuhas'),
      (TokenKind.word, 'U-352'),
      (TokenKind.symbol, '-'),
      (TokenKind.word, 'wreck'),
      (TokenKind.word, 'a'),
      (TokenKind.symbol, '-'),
      (TokenKind.word, 'b'),
      (TokenKind.end, ''),
    ]);
  });

  test('a number keeps a trailing percent sign', () {
    final t = tokenize('100% 32.5%');
    expect(t[0].kind, TokenKind.number);
    expect(t[0].text, '100%');
    expect(t[1].text, '32.5%');
  });
}
