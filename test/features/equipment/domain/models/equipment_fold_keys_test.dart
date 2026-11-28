import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/models/equipment_fold_keys.dart';

void main() {
  group('fold keys (#4184)', () {
    test('location keys', () {
      expect(locationFoldKey('abc'), 'loc:abc');
      expect(locationFoldKey(null), 'loc:none');
    });

    test('type keys, nested and outermost', () {
      expect(typeFoldKey(EquipmentType.bcd), 'type:bcd');
      expect(
        typeFoldKey(EquipmentType.secondStage, parentKey: 'loc:abc'),
        'loc:abc/type:secondStage',
      );
    });
  });

  group('stored fold keys', () {
    test('malformed raw decodes to empty', () {
      for (final raw in [null, '', '  ', '{', '{"a":1}', '42', 'null']) {
        expect(decodeFoldKeys(raw), isEmpty, reason: '$raw');
      }
    });

    test('non-string entries are skipped, order kept', () {
      expect(decodeFoldKeys('["loc:a", 3, "type:bcd"]'), ['loc:a', 'type:bcd']);
    });

    test('decode keeps unknown keys', () {
      expect(decodeFoldKeys('["future:thing"]'), ['future:thing']);
    });

    test('round trip', () {
      const keys = ['loc:a', 'loc:a/type:bcd'];
      expect(decodeFoldKeys(encodeFoldKeys(keys)), keys);
    });

    test('toggle appends then removes', () {
      expect(toggleFoldKey(['a'], 'b'), ['a', 'b']);
      expect(toggleFoldKey(['a', 'b'], 'a'), ['b']);
    });

    test('toggle never mutates its argument', () {
      final keys = ['a'];
      toggleFoldKey(keys, 'b');
      expect(keys, ['a']);
    });

    test('toggle drops the oldest past the cap', () {
      expect(toggleFoldKey(['a', 'b', 'c'], 'd', cap: 3), ['b', 'c', 'd']);
    });

    test('the default cap is a few hundred keys', () {
      final full = [for (var i = 0; i < kMaxStoredFoldKeys; i++) 'k$i'];
      final next = toggleFoldKey(full, 'new');
      expect(next, hasLength(kMaxStoredFoldKeys));
      expect(next.first, 'k1');
      expect(next.last, 'new');
    });
  });

  group('assembly folds (#5071)', () {
    test('an assembly key names the item', () {
      expect(assemblyFoldKey('x'), 'asm:x');
      expect(isAssemblyFoldKey('asm:x'), isTrue);
      expect(isAssemblyFoldKey('type:bcd'), isFalse);
      expect(isAssemblyFoldKey('loc:none/type:bcd'), isFalse);
    });

    test('a stored assembly key means opened outside a filter', () {
      expect(
        resolveCollapsedKeys(
          ['type:bcd', 'asm:a'],
          ['a', 'b'],
          assembliesStartOpen: false,
        ),
        {'type:bcd', 'asm:b'},
      );
    });

    test('a stored assembly key means folded during a filter', () {
      expect(
        resolveCollapsedKeys(
          ['type:bcd', 'asm:a'],
          ['a', 'b'],
          assembliesStartOpen: true,
        ),
        {'type:bcd', 'asm:a'},
      );
    });

    test('a stored key for an assembly not on the list folds nothing', () {
      expect(
        resolveCollapsedKeys(['asm:gone'], ['a'], assembliesStartOpen: true),
        isEmpty,
      );
    });
  });
}
