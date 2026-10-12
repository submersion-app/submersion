import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/icons/submersion_icons.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';

void main() {
  group('TankRole.icon', () {
    test('each role gets the glyph for how that cylinder is carried', () {
      expect(TankRole.backGas.icon, SubmersionIcons.tankBackGas);
      expect(TankRole.sidemountLeft.icon, SubmersionIcons.tankSidemountLeft);
      expect(TankRole.sidemountRight.icon, SubmersionIcons.tankSidemountRight);
      expect(TankRole.stage.icon, SubmersionIcons.tankSlung);
      expect(TankRole.deco.icon, SubmersionIcons.tankSlung);
      expect(TankRole.bailout.icon, SubmersionIcons.tankSlung);
      expect(TankRole.pony.icon, SubmersionIcons.tankPony);
      expect(TankRole.diluent.icon, SubmersionIcons.tankRebreather);
      expect(TankRole.oxygenSupply.icon, SubmersionIcons.tankRebreather);
    });

    test('the two sidemount sides are told apart', () {
      expect(TankRole.sidemountLeft.icon, isNot(TankRole.sidemountRight.icon));
    });

    test('every role glyph comes from the drawn equipment font', () {
      for (final role in TankRole.values) {
        expect(
          role.icon.fontFamily,
          SubmersionIcons.fontFamily,
          reason: role.name,
        );
      }
    });
  });
}
