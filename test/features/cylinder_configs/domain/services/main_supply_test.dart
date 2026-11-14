import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/domain/services/main_supply.dart';

/// Which cylinders are a diver's main gas supply, the place a new dive's
/// starter tank holds (issue #4525).
void main() {
  final t = DateTime(2026, 11, 1);
  CylinderConfigItem cylinder(TankRole role) => CylinderConfigItem(
    id: role.name,
    configId: 'c',
    tankRole: role,
    createdAt: t,
    updatedAt: t,
  );

  test('back gas, twin sets, sidemount and the rebreather pair are main '
      'supply', () {
    for (final role in [
      TankRole.backGas,
      TankRole.twinSet,
      TankRole.sidemountLeft,
      TankRole.sidemountRight,
      TankRole.diluent,
      TankRole.oxygenSupply,
    ]) {
      expect(bringsMainSupply([cylinder(role)]), isTrue, reason: role.name);
    }
  });

  test('stages, deco, bailout, pony and suit inflation are not', () {
    for (final role in [
      TankRole.stage,
      TankRole.deco,
      TankRole.bailout,
      TankRole.pony,
      TankRole.suitInflation,
    ]) {
      expect(bringsMainSupply([cylinder(role)]), isFalse, reason: role.name);
    }
    expect(bringsMainSupply(const []), isFalse);
  });

  test('every role is classified one way or the other', () {
    // A role added later must be placed deliberately.
    expect(mainSupplyRoles.length + 5, TankRole.values.length);
  });

  test('one main cylinder among others is enough', () {
    expect(
      bringsMainSupply([cylinder(TankRole.deco), cylinder(TankRole.backGas)]),
      isTrue,
    );
  });
}
