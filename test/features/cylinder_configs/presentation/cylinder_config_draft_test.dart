import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/tank_capacity.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/presentation/pages/cylinder_config_draft.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The cylinder configuration editor's draft (issue #4527, phase 4): the
/// form as the diver sees it, so a value shown in other units and typed
/// back never reads as a change.
void main() {
  const imperial = UnitFormatter(
    AppSettings(
      volumeUnit: VolumeUnit.cubicFeet,
      pressureUnit: PressureUnit.psi,
    ),
  );
  final now = DateTime.utc(2026, 11, 22);

  CylinderConfigItem item({
    String id = 'i1',
    double? volumeL = 11.1,
    double? workingPressureBar = 207,
    double? mod,
  }) => CylinderConfigItem(
    id: id,
    configId: 'c1',
    label: 'Bailout 1',
    tankRole: TankRole.bailout,
    volumeL: volumeL,
    workingPressureBar: workingPressureBar,
    o2Percent: 21,
    hePercent: 35,
    decoSwitchDepth: mod,
    createdAt: now,
    updatedAt: now,
  );

  test('a row of 11.1 L at 207 bar reads as cuft and psi, whole', () {
    final row = cylinderRowDraft(item(), imperial);

    expect(row.volume, '77');
    expect(row.pressure, '3002');
    expect(row.o2, '21');
    expect(row.he, '35');
    expect(row.label, 'Bailout 1');
    expect(row.mod, '');
  });

  test('a row whose volume is typed back from cuft is equal to its start', () {
    final start = cylinderRowDraft(item(), imperial);
    final typedBack = item(volumeL: volumeLitersFromCapacity(77, 207));

    expect(cylinderRowDraft(typedBack, imperial), start);
  });

  test('a row with a MOD set by hand shows it in the diver depth unit', () {
    final row = cylinderRowDraft(item(mod: 21), imperial);

    expect(row.mod, isNotEmpty);
    expect(row.mod, isNot(cylinderRowDraft(item(mod: 22), imperial).mod));
  });

  test('drafts differing only in row order are not equal', () {
    final a = cylinderRowDraft(item(id: 'a'), imperial);
    final b = cylinderRowDraft(item(id: 'b'), imperial);

    expect(
      CylinderConfigDraft(name: 'n', rows: [a, b]),
      isNot(CylinderConfigDraft(name: 'n', rows: [b, a])),
    );
    expect(
      CylinderConfigDraft(name: 'n', rows: [a, b]),
      CylinderConfigDraft(name: 'n', rows: [a, b]),
    );
  });

  test('drafts differing in unit are not equal', () {
    expect(
      const CylinderConfigDraft(name: 'n', equipmentId: 'rb-1', rows: []),
      isNot(const CylinderConfigDraft(name: 'n', rows: [])),
    );
  });
}
