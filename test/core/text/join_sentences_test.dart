import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/text/join_sentences.dart';

void main() {
  group('joinSentences', () {
    test('adds a full stop and a space between Latin sentences', () {
      expect(
        joinSentences(['Diver deleted', 'Gear kept.'], 'en'),
        'Diver deleted. Gear kept.',
      );
    });

    test('keeps a sentence\'s own stop and adds only a space', () {
      expect(joinSentences(['Done!', 'Next.'], 'de'), 'Done! Next.');
      expect(joinSentences(['هل؟', 'نعم'], 'ar'), 'هل؟ نعم');
    });

    // #4833: a Latin ". " inside Japanese text reads as a typo.
    test('ends a Japanese sentence with 。 and no space', () {
      expect(
        joinSentences(['ダイバーを削除しました', '器材を引き継ぎました。'], 'ja'),
        'ダイバーを削除しました。器材を引き継ぎました。',
      );
    });

    test('Chinese and Japanese add nothing after their own stop', () {
      expect(joinSentences(['完成。', '下一步'], 'zh'), '完成。下一步');
      expect(joinSentences(['本当？', 'はい'], 'ja'), '本当？はい');
    });

    test('a sentence ending in a Latin unit still gets 。 in Japanese', () {
      expect(
        joinSentences(['10:00に満潮、1.2 m', '16:00に干潮'], 'ja'),
        '10:00に満潮、1.2 m。16:00に干潮',
      );
    });

    test('an ASCII full stop also ends a Japanese sentence', () {
      expect(
        joinSentences(['CSV\u306a\u3069etc.', '\u5b8c\u4e86'], 'ja'),
        'CSV\u306a\u3069etc.\u5b8c\u4e86',
      );
    });

    test('a region or script suffix still picks the language', () {
      expect(joinSentences(['完成', '下一步'], 'zh_Hans'), '完成。下一步');
    });

    test('one or no sentence comes back as it is', () {
      expect(joinSentences(['Only one'], 'en'), 'Only one');
      expect(joinSentences(const [], 'en'), '');
    });
  });
}
