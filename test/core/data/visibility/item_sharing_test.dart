import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/item_sharing.dart';

/// Who a trip or site is shared with (issue #2151).
void main() {
  test('everyone wins over profile ids', () {
    const both = ItemSharing(everyone: true, profileIds: {'son'});
    expect(both, ItemSharing.all);
    expect(both.profileIds, isEmpty);
    expect(both.reaches('daughter'), isTrue);
  });

  test('equal profile sets are equal sharings', () {
    expect(
      const ItemSharing(profileIds: {'son', 'daughter'}),
      const ItemSharing(profileIds: {'daughter', 'son'}),
    );
    expect(
      const ItemSharing(profileIds: {'son'}).hashCode,
      const ItemSharing(profileIds: {'son'}).hashCode,
    );
  });

  test('isShared is false only for nobody', () {
    expect(ItemSharing.none.isShared, isFalse);
    expect(ItemSharing.all.isShared, isTrue);
    expect(const ItemSharing(profileIds: {'son'}).isShared, isTrue);
  });

  test('reaches only the chosen profiles', () {
    const sharing = ItemSharing(profileIds: {'son'});
    expect(sharing.reaches('son'), isTrue);
    expect(sharing.reaches('daughter'), isFalse);
  });

  const everyone = {'son', 'daughter'};

  test('narrowsAmong is true when a profile that sees it now would not', () {
    expect(
      ItemSharing.all.narrowsAmong(
        const ItemSharing(profileIds: {'son'}),
        everyone,
      ),
      isTrue,
    );
    expect(
      const ItemSharing(
        profileIds: {'son', 'daughter'},
      ).narrowsAmong(const ItemSharing(profileIds: {'son'}), everyone),
      isTrue,
    );
    expect(
      const ItemSharing(
        profileIds: {'son'},
      ).narrowsAmong(ItemSharing.none, everyone),
      isTrue,
    );
  });

  test('narrowsAmong is false for an added id, for Everyone, and for every '
      'current profile by name', () {
    expect(
      const ItemSharing(profileIds: {'son'}).narrowsAmong(
        const ItemSharing(profileIds: {'son', 'daughter'}),
        everyone,
      ),
      isFalse,
    );
    expect(
      const ItemSharing(
        profileIds: {'son'},
      ).narrowsAmong(ItemSharing.all, everyone),
      isFalse,
    );
    expect(
      ItemSharing.all.narrowsAmong(
        const ItemSharing(profileIds: {'son', 'daughter'}),
        everyone,
      ),
      isFalse,
    );
    expect(ItemSharing.none.narrowsAmong(ItemSharing.none, everyone), isFalse);
  });

  test('without drops the owner', () {
    expect(
      const ItemSharing(profileIds: {'me', 'son'}).without('me'),
      const ItemSharing(profileIds: {'son'}),
    );
    expect(ItemSharing.all.without('me'), ItemSharing.all);
    expect(
      const ItemSharing(profileIds: {'son'}).without(null),
      const ItemSharing(profileIds: {'son'}),
    );
  });

  test('plus adds profiles, and Everyone absorbs them', () {
    expect(
      const ItemSharing(
        profileIds: {'son'},
      ).plus(const ItemSharing(profileIds: {'daughter'})),
      const ItemSharing(profileIds: {'son', 'daughter'}),
    );
    expect(
      ItemSharing.all.plus(const ItemSharing(profileIds: {'son'})),
      ItemSharing.all,
    );
    expect(
      const ItemSharing(profileIds: {'son'}).plus(ItemSharing.all),
      ItemSharing.all,
    );
  });

  test('isSharedWithAnyone reads the flag or a share row', () {
    expect(
      isSharedWithAnyone(id: 't1', everyone: true, namedShares: const {}),
      isTrue,
    );
    expect(
      isSharedWithAnyone(id: 't1', everyone: false, namedShares: const {'t1'}),
      isTrue,
    );
    expect(
      isSharedWithAnyone(id: 't1', everyone: false, namedShares: const {'t2'}),
      isFalse,
    );
  });
}
