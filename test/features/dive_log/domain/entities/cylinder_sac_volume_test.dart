import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// [CylinderSac.sacVolume] converts the bar/min rate to L/min (issue #828).
///
/// Both sides are referenced to 1 bar now, so the conversion is a plain
/// multiplication by cylinder size. It used to divide by the standard
/// atmosphere as well, which silently shaved 1.3% off every per-cylinder
/// L/min readout while the dive's headline SAC used a different reference.
void main() {
  group('CylinderSac.sacVolume', () {
    test('is the bar/min rate times the cylinder size', () {
      const cylinder = CylinderSac(
        tankId: 't1',
        tankName: 'AL80',
        gasMix: GasMix(o2: 21.0, he: 0.0),
        role: TankRole.backGas,
        tankVolume: 12.0,
        sacRate: 1.5,
        order: 0,
      );
      expect(cylinder.sacVolume, closeTo(18.0, 1e-9));
    });

    test('is null without a rate or a cylinder size', () {
      const noVolume = CylinderSac(
        tankId: 't1',
        tankName: 'AL80',
        gasMix: GasMix(o2: 21.0, he: 0.0),
        role: TankRole.backGas,
        sacRate: 1.5,
        order: 0,
      );
      expect(noVolume.sacVolume, isNull);

      const noRate = CylinderSac(
        tankId: 't1',
        tankName: 'AL80',
        gasMix: GasMix(o2: 21.0, he: 0.0),
        role: TankRole.backGas,
        tankVolume: 12.0,
        order: 0,
      );
      expect(noRate.sacVolume, isNull);
    });
  });
}
