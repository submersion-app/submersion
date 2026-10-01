import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';

/// Who may delete or hide a shared trip or site (issue #2594).
void main() {
  group('canDestroySharedItem', () {
    test('the owner may', () {
      expect(canDestroySharedItem(ownerId: 'a', activeDiverId: 'a'), isTrue);
    });
    test('another profile may not', () {
      expect(canDestroySharedItem(ownerId: 'a', activeDiverId: 'b'), isFalse);
    });
    test('anyone may destroy an ownerless item', () {
      expect(canDestroySharedItem(ownerId: null, activeDiverId: 'b'), isTrue);
    });
    test('a caller naming no profile may', () {
      expect(canDestroySharedItem(ownerId: 'a', activeDiverId: null), isTrue);
    });
  });

  group('canHideSharedItem', () {
    test('another profile may hide a shared item', () {
      expect(
        canHideSharedItem(ownerId: 'a', isShared: true, activeDiverId: 'b'),
        isTrue,
      );
    });
    test('the owner may not hide its own item', () {
      expect(
        canHideSharedItem(ownerId: 'a', isShared: true, activeDiverId: 'a'),
        isFalse,
      );
    });
    test('an unshared item is never hidden', () {
      expect(
        canHideSharedItem(ownerId: 'a', isShared: false, activeDiverId: 'b'),
        isFalse,
      );
    });
    test('an ownerless item is never hidden', () {
      expect(
        canHideSharedItem(ownerId: null, isShared: true, activeDiverId: 'b'),
        isFalse,
      );
    });
    test('no active profile hides nothing', () {
      expect(
        canHideSharedItem(ownerId: 'a', isShared: true, activeDiverId: null),
        isFalse,
      );
    });
  });

  test('exactly one action applies to any owned shared item', () {
    for (final active in ['a', 'b']) {
      final destroy = canDestroySharedItem(ownerId: 'a', activeDiverId: active);
      final hide = canHideSharedItem(
        ownerId: 'a',
        isShared: true,
        activeDiverId: active,
      );
      expect(destroy != hide, isTrue, reason: 'active $active');
    }
  });

  test(
    'splitForBulkDelete deletes owned and ownerless, hides others\' shared',
    () {
      final items = [
        (id: 'mine', owner: 'a', shared: true),
        (id: 'theirs', owner: 'b', shared: true),
        (id: 'legacy', owner: null, shared: true),
      ];
      final split = splitForBulkDelete(
        items,
        ownerOf: (i) => i.owner,
        isSharedOf: (i) => i.shared,
        activeDiverId: 'a',
      );
      expect(split.destroy.map((i) => i.id), ['mine', 'legacy']);
      expect(split.hide.map((i) => i.id), ['theirs']);
    },
  );
}
