import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_departed_status.dart';

EquipmentItem _item(EquipmentStatus status, {bool isActive = true}) =>
    EquipmentItem(
      id: 'e',
      name: 'Reg',
      type: EquipmentType.regulator,
      status: status,
      isActive: isActive,
    );

void main() {
  group('hasLeftKit (#3210)', () {
    test('retired and sold gear has left the kit', () {
      expect(_item(EquipmentStatus.retired, isActive: false).hasLeftKit, true);
      expect(_item(EquipmentStatus.sold, isActive: false).hasLeftKit, true);
    });

    test('a legacy row retired by one marker only has left it too', () {
      // Older rows carry one of the two markers (#636).
      expect(_item(EquipmentStatus.retired).hasLeftKit, true);
      expect(_item(EquipmentStatus.active, isActive: false).hasLeftKit, true);
    });

    test('gear in the kit has not, lost and loaned gear included', () {
      for (final status in [
        EquipmentStatus.active,
        EquipmentStatus.spare,
        EquipmentStatus.needsService,
        EquipmentStatus.inService,
        EquipmentStatus.loaned,
        EquipmentStatus.lost,
      ]) {
        expect(_item(status).hasLeftKit, false, reason: status.name);
      }
    });

    test('wishlist gear never joined the kit, so it has not left it', () {
      expect(_item(EquipmentStatus.wanted, isActive: false).hasLeftKit, false);
    });
  });

  group('effectiveStatus (#3210)', () {
    test('a legacy row retired by isActive alone reads Retired', () {
      expect(
        _item(EquipmentStatus.active, isActive: false).effectiveStatus,
        EquipmentStatus.retired,
      );
    });

    test('gear in the kit keeps its stored status', () {
      expect(
        _item(EquipmentStatus.spare).effectiveStatus,
        EquipmentStatus.spare,
      );
      expect(_item(EquipmentStatus.lost).effectiveStatus, EquipmentStatus.lost);
    });

    test('agrees with the departed badge wherever that names a status', () {
      for (final status in EquipmentStatus.values) {
        for (final isActive in [true, false]) {
          final item = _item(status, isActive: isActive);
          final badge = departedStatusOf(item);
          if (badge == null) continue;
          expect(
            item.effectiveStatus,
            badge,
            reason: '${status.name}, isActive $isActive',
          );
        }
      }
    });
  });
}
