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

  test('narrows is true for Everyone to a profile and for a removed id', () {
    expect(
      ItemSharing.all.narrows(const ItemSharing(profileIds: {'son'})),
      isTrue,
    );
    expect(
      const ItemSharing(
        profileIds: {'son', 'daughter'},
      ).narrows(const ItemSharing(profileIds: {'son'})),
      isTrue,
    );
    expect(
      const ItemSharing(profileIds: {'son'}).narrows(ItemSharing.none),
      isTrue,
    );
  });

  test('narrows is false for an added id and for Everyone', () {
    expect(
      const ItemSharing(
        profileIds: {'son'},
      ).narrows(const ItemSharing(profileIds: {'son', 'daughter'})),
      isFalse,
    );
    expect(
      const ItemSharing(profileIds: {'son'}).narrows(ItemSharing.all),
      isFalse,
    );
    expect(ItemSharing.none.narrows(ItemSharing.none), isFalse);
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
}
