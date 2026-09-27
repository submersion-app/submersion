import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/equipment_ownership.dart';

/// The one ownership rule every surface applies (issue #2046).
void main() {
  EquipmentItem item(String? owner) => EquipmentItem(
    id: 'x',
    diverId: owner,
    name: 'x',
    type: EquipmentType.bcd,
  );

  group('canDeleteEquipment', () {
    test('the owner can, a sharee cannot', () {
      expect(canDeleteEquipment(item('bill'), 'bill'), isTrue);
      expect(canDeleteEquipment(item('bill'), 'anna'), isFalse);
    });

    test('an ownerless item or no diver at all deletes as before sharing', () {
      expect(canDeleteEquipment(item(null), 'anna'), isTrue);
      expect(canDeleteEquipment(item('bill'), null), isTrue);
    });
  });

  group('canShareEquipment', () {
    test('only the owner manages shares', () {
      expect(canShareEquipment(item('bill'), 'bill'), isTrue);
      expect(canShareEquipment(item('bill'), 'anna'), isFalse);
    });

    test('an ownerless item or an unknown diver cannot be shared', () {
      expect(canShareEquipment(item(null), 'bill'), isFalse);
      expect(canShareEquipment(item('bill'), null), isFalse);
    });
  });

  group('isSetMemberUsableBy', () {
    bool usable(String? owner, String? diver, {bool shared = false}) =>
        isSetMemberUsableBy(
          ownerId: owner,
          diverId: diver,
          sharedWithDiver: shared,
        );

    test('own, ownerless and shared members apply', () {
      expect(usable('anna', 'anna'), isTrue);
      expect(usable(null, 'anna'), isTrue);
      expect(usable('bill', 'anna', shared: true), isTrue);
    });

    test("another profile's unshared member is skipped", () {
      expect(usable('bill', 'anna'), isFalse);
    });

    test('with no active diver every member applies', () {
      expect(usable('bill', null), isTrue);
    });
  });
}
