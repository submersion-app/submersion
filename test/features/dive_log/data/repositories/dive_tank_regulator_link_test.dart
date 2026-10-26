import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
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

  group('extra regulators (#3375)', () {
    Future<List<String>> regulators(int n) async => [
      for (var i = 1; i <= n; i++)
        (await EquipmentRepository().createEquipment(
          EquipmentItem(id: '', name: 'Reg $i', type: EquipmentType.regulator),
        )).id,
    ];

    Future<Map<String, Object?>> storedTank(String id) async =>
        (await DatabaseService.instance.database
                .customSelect(
                  'SELECT regulator_equipment_id, extra_regulator_ids '
                  'FROM dive_tanks WHERE id = ?',
                  variables: [Variable.withString(id)],
                )
                .getSingle())
            .data;

    test('extra regulators survive create, read and update', () async {
      final regs = await regulators(3);
      final repo = DiveRepository();
      await repo.createDive(
        createTestDiveWithBottomTime(
          id: 'd1',
        ).copyWith(tanks: [const DiveTank(id: 't1').withRegulators(regs)]),
      );

      final loaded = (await repo.getDiveById('d1'))!;
      expect(loaded.tanks.single.regulatorIds, regs);

      await repo.updateDive(
        loaded.copyWith(
          tanks: [loaded.tanks.single.copyWith(startPressure: 200)],
        ),
      );
      final updated = (await repo.getDiveById('d1'))!;
      expect(updated.tanks.single.regulatorIds, regs);

      await repo.updateDive(
        updated.copyWith(
          tanks: [
            updated.tanks.single.withRegulators([regs.first]),
          ],
        ),
      );
      expect((await repo.getDiveById('d1'))!.tanks.single.regulatorIds, [
        regs.first,
      ]);
      expect((await storedTank('t1'))['extra_regulator_ids'], isNull);
    });

    test('a write normalises the list', () async {
      final regs = await regulators(3);
      final repo = DiveRepository();
      await repo.createDive(
        createTestDiveWithBottomTime(id: 'd1').copyWith(
          tanks: [
            DiveTank(id: 't1', extraRegulatorIds: [regs[1], regs[1], regs[2]]),
          ],
        ),
      );

      final tank = (await repo.getDiveById('d1'))!.tanks.single;
      expect(tank.regulatorEquipmentId, regs[1]);
      expect(tank.extraRegulatorIds, [regs[2]]);
      expect(await storedTank('t1'), {
        'regulator_equipment_id': regs[1],
        'extra_regulator_ids': '["${regs[2]}"]',
      });
    });

    test('a tank added on update stores its extras', () async {
      final regs = await regulators(2);
      final repo = DiveRepository();
      await repo.createDive(createTestDiveWithBottomTime(id: 'd1'));
      final dive = (await repo.getDiveById('d1'))!;
      await repo.updateDive(
        dive.copyWith(
          tanks: [const DiveTank(id: 't-new').withRegulators(regs)],
        ),
      );
      expect((await repo.getDiveById('d1'))!.tanks.single.regulatorIds, regs);
    });
  });
}
