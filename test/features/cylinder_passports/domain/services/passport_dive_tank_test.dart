import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_dive_tank.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

  test('copies the tag spec and names the matching preset', () {
    final tank = tankFromPassport(
      const CylinderPassportPayload(
        passportId: id,
        name: 'Club AL80',
        volumeL: 11.1,
        workingPressureBar: 207,
        material: TankMaterial.aluminum,
      ),
      mix: const GasMix(o2: 32),
    );
    expect(tank.name, 'Club AL80');
    expect(tank.volume, 11.1);
    expect(tank.workingPressure, 207);
    expect(tank.material, TankMaterial.aluminum);
    expect(tank.presetName, 'al80');
    expect(tank.gasMix.o2, 32);
    expect(tank.role, TankRole.backGas);
  });

  test('an identity-only tag leaves every spec open, air by default', () {
    final tank = tankFromPassport(
      const CylinderPassportPayload(passportId: id),
    );
    expect(tank.volume, isNull);
    expect(tank.workingPressure, isNull);
    expect(tank.material, isNull);
    expect(tank.presetName, isNull);
    expect(tank.gasMix, const GasMix());
  });
}
