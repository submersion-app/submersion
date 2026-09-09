import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  test('the regulator link survives create, read and update', () async {
    final reg = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'Apeks', type: EquipmentType.regulator),
    );
    final repo = DiveRepository();
    final dive = createTestDiveWithBottomTime(id: 'd1').copyWith(
      tanks: [
        DiveTank(
          id: 't1',
          gasMix: const GasMix(o2: 50),
          regulatorEquipmentId: reg.id,
        ),
      ],
    );
    await repo.createDive(dive);

    final loaded = await repo.getDiveById('d1');
    expect(loaded!.tanks.single.regulatorEquipmentId, reg.id);

    // An edit that rebuilds the tank keeps the link.
    await repo.updateDive(
      loaded.copyWith(
        tanks: [loaded.tanks.single.copyWith(startPressure: 200)],
      ),
    );
    expect(
      (await repo.getDiveById('d1'))!.tanks.single.regulatorEquipmentId,
      reg.id,
    );

    // And an explicit clear removes it.
    final cleared = (await repo.getDiveById('d1'))!;
    await repo.updateDive(
      cleared.copyWith(
        tanks: [cleared.tanks.single.copyWith(clearRegulatorEquipmentId: true)],
      ),
    );
    expect(
      (await repo.getDiveById('d1'))!.tanks.single.regulatorEquipmentId,
      isNull,
    );
  });
}
