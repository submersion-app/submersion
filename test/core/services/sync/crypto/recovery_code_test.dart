import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/crypto/eff_short_wordlist.dart';
import 'package:submersion/core/services/sync/crypto/recovery_code.dart';

void main() {
  group('RecoveryCode', () {
    test('wordlist integrity: 1296 unique lowercase words', () {
      expect(effShortWordlist.length, 1296);
      expect(effShortWordlist.toSet().length, 1296);
      for (final w in effShortWordlist) {
        // The canonical EFF list includes one hyphenated word (yo-yo).
        // Hyphens are safe: normalize() collapses separator runs, so the
        // derived secret is identical however the user re-enters it.
        expect(w, matches(RegExp(r'^[a-z\-]+$')));
      }
    });

    test('generate returns 8 wordlist words joined by hyphens', () {
      final code = RecoveryCode.generate();
      final words = code.split('-');
      expect(words.length, 8);
      for (final w in words) {
        expect(effShortWordlist.contains(w), isTrue, reason: w);
      }
    });

    test('two generated codes differ', () {
      expect(RecoveryCode.generate(), isNot(RecoveryCode.generate()));
    });

    test('normalize is tolerant of case, spaces, and separators', () {
      expect(
        RecoveryCode.normalize('  Acid ACORN\tacre -  act\nadd age aid aim '),
        'acid-acorn-acre-act-add-age-aid-aim',
      );
      expect(
        RecoveryCode.normalize('acid-acorn-acre-act-add-age-aid-aim'),
        'acid-acorn-acre-act-add-age-aid-aim',
      );
    });
  });
}
