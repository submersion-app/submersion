import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_departed_status.dart';

void main() {
  EquipmentItem item(EquipmentStatus status, {bool isActive = true}) =>
      EquipmentItem(
        id: 'x',
        name: 'x',
        type: EquipmentType.regulator,
        status: status,
        isActive: isActive,
      );

  test('sold gear keeps its own status, though it is also inactive', () {
    expect(
      departedStatusOf(item(EquipmentStatus.sold, isActive: false)),
      EquipmentStatus.sold,
    );
  });

  test('retired gear reads as retired', () {
    expect(
      departedStatusOf(item(EquipmentStatus.retired, isActive: false)),
      EquipmentStatus.retired,
    );
    // A legacy row can carry status=retired with isActive still true (#636).
    expect(
      departedStatusOf(item(EquipmentStatus.retired)),
      EquipmentStatus.retired,
    );
  });

  test('a legacy inactive row with a live status reads as retired', () {
    expect(
      departedStatusOf(item(EquipmentStatus.active, isActive: false)),
      EquipmentStatus.retired,
    );
  });

  test('gear still in the kit has no departed status', () {
    expect(departedStatusOf(item(EquipmentStatus.active)), isNull);
    expect(departedStatusOf(item(EquipmentStatus.needsService)), isNull);
  });
}
