import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/conflicts/word_diff.dart';

String joined(List<DiffSpan> spans) => spans.map((s) => s.text).join();
List<String> unique(List<DiffSpan> spans) => [
  for (final s in spans)
    if (s.unique) s.text.trim(),
];

void main() {
  group('tokenizeForDiff', () {
    test('splits words, whitespace and punctuation and loses nothing', () {
      const text = 'Saw a turtle, near the wall.';
      final tokens = tokenizeForDiff(text);
      expect(tokens.join(), text);
      expect(tokens, contains('turtle'));
      expect(tokens, contains(','));
    });

    test('makes each CJK character its own token', () {
      expect(tokenizeForDiff('看到海龟'), ['看', '到', '海', '龟']);
    });

    test('keeps RTL words whole', () {
      expect(tokenizeForDiff('رأيت سلحفاة'), ['رأيت', ' ', 'سلحفاة']);
    });
  });

  group('diffWords', () {
    test('marks the words only on each side', () {
      final diff = diffWords(
        'Saw a turtle near the wall.',
        'Saw two turtles near the wall and a ray.',
      )!;
      expect(joined(diff.local), 'Saw a turtle near the wall.');
      expect(joined(diff.remote), 'Saw two turtles near the wall and a ray.');
      expect(unique(diff.local), ['a turtle']);
      expect(unique(diff.remote), ['two turtles', 'and a ray']);
    });

    test('marks nothing for identical text', () {
      final diff = diffWords('Same text.', 'Same text.')!;
      expect(diff.hasUniqueWords, isFalse);
    });

    test('marks nothing when only whitespace differs', () {
      final diff = diffWords('One two\nthree', 'One  two three')!;
      expect(diff.hasUniqueWords, isFalse);
    });

    test('an empty side marks the whole other side', () {
      final diff = diffWords('', 'Only here')!;
      expect(diff.local, isEmpty);
      expect(unique(diff.remote), ['Only here']);
    });

    test('marks single CJK characters', () {
      final diff = diffWords('看到海龟', '看到两只海龟')!;
      expect(unique(diff.remote), ['两只']);
      expect(diff.local.every((s) => !s.unique), isTrue);
    });

    test('gives up past the token limit', () {
      final big = List.filled(kWordDiffTokenLimit, 'w').join(' ');
      expect(diffWords(big, '$big extra'), isNull);
    });
  });
}
