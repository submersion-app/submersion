import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/start_session_sheet.dart';

void main() {
  final set = EquipmentSet(
    id: 's1',
    name: 'Rig',
    equipmentIds: const ['reg', 'wish'],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('a session checks the set members the diver owns (#2025)', () {
    const all = [
      EquipmentItem(id: 'reg', name: 'Reg', type: EquipmentType.regulator),
      EquipmentItem(
        id: 'wish',
        name: 'Dream wing',
        type: EquipmentType.bcd,
        status: EquipmentStatus.wanted,
        isActive: false,
      ),
      EquipmentItem(id: 'other', name: 'Fins', type: EquipmentType.fins),
    ];

    expect(sessionSetGear(all, set).map((g) => g.id), ['reg']);
  });
}
