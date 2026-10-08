import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/services/location_status_offer.dart';

void main() {
  const statuses = EquipmentStatus.values;

  test('a service shop offers In Service except from In Service, '
      'Retired or Sold', () {
    for (final status in statuses) {
      final expected =
          {
            EquipmentStatus.inService,
            EquipmentStatus.retired,
            EquipmentStatus.sold,
            EquipmentStatus.wanted,
          }.contains(status)
          ? null
          : EquipmentStatus.inService;
      expect(
        offeredStatusAfterMove(EquipmentLocationKind.serviceShop, status),
        expected,
        reason: status.name,
      );
    }
  });

  test(
    'a person offers Loaned Out except from Loaned Out, Retired or Sold',
    () {
      for (final status in statuses) {
        final expected =
            {
              EquipmentStatus.loaned,
              EquipmentStatus.retired,
              EquipmentStatus.sold,
              EquipmentStatus.wanted,
            }.contains(status)
            ? null
            : EquipmentStatus.loaned;
        expect(
          offeredStatusAfterMove(EquipmentLocationKind.person, status),
          expected,
          reason: status.name,
        );
      }
    },
  );

  test('storage offers Active only from In Service, Loaned Out or Lost', () {
    for (final status in statuses) {
      final expected =
          {
            EquipmentStatus.inService,
            EquipmentStatus.loaned,
            EquipmentStatus.lost,
          }.contains(status)
          ? EquipmentStatus.active
          : null;
      expect(
        offeredStatusAfterMove(EquipmentLocationKind.storage, status),
        expected,
        reason: status.name,
      );
    }
  });

  test('other and no location offer nothing', () {
    for (final status in statuses) {
      expect(
        offeredStatusAfterMove(EquipmentLocationKind.other, status),
        isNull,
      );
      expect(offeredStatusAfterMove(null, status), isNull);
    }
  });

  test('wanted gear is not owned yet, so no move offers it a status', () {
    for (final kind in [...EquipmentLocationKind.values, null]) {
      expect(
        offeredStatusAfterMove(kind, EquipmentStatus.wanted),
        isNull,
        reason: '$kind',
      );
    }
  });
}
