import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/equipment/presentation/helpers/tank_volume_input.dart';

void main() {
  group('tankVolumeInputText', () {
    test('metric shows liters', () {
      expect(tankVolumeInputText(11.1, 206.843, VolumeUnit.liters), '11.1');
    });

    test('imperial shows the rated cubic feet of a known preset', () {
      expect(tankVolumeInputText(11.1, 206.843, VolumeUnit.cubicFeet), '77.4');
    });

    test('imperial with no working pressure falls back to liters', () {
      expect(tankVolumeInputText(11.1, null, VolumeUnit.cubicFeet), '11.1');
    });
  });

  group('tankVolumeFromInput', () {
    test('unchanged text keeps the original liters exactly', () {
      expect(
        tankVolumeFromInput(
          '77.4',
          initialText: '77.4',
          initialLiters: 11.1,
          workingPressureBar: 206.843,
          unit: VolumeUnit.cubicFeet,
        ),
        11.1,
      );
    });

    test('a changed imperial figure converts with the working pressure', () {
      expect(
        tankVolumeFromInput(
          '100',
          initialText: '77.4',
          initialLiters: 11.1,
          workingPressureBar: 207,
          unit: VolumeUnit.cubicFeet,
        ),
        closeTo(100 * 28.3168 / 207, 1e-9),
      );
    });

    test('a typed rated figure reads back as that preset', () {
      expect(
        tankVolumeFromInput(
          '77.4',
          initialText: '',
          initialLiters: 0,
          workingPressureBar: 206.843,
          unit: VolumeUnit.cubicFeet,
        ),
        11.1,
      );
    });

    test('metric reads liters', () {
      expect(
        tankVolumeFromInput(
          '12',
          initialText: '11.1',
          initialLiters: 11.1,
          workingPressureBar: 232,
          unit: VolumeUnit.liters,
        ),
        12,
      );
    });

    test('imperial with no working pressure reads liters', () {
      expect(
        tankVolumeFromInput(
          '12',
          initialText: '11.1',
          initialLiters: 11.1,
          workingPressureBar: null,
          unit: VolumeUnit.cubicFeet,
        ),
        12,
      );
    });

    test('blank or unreadable text is null', () {
      for (final text in ['', 'abc']) {
        expect(
          tankVolumeFromInput(
            text,
            initialText: '11.1',
            initialLiters: 11.1,
            workingPressureBar: null,
            unit: VolumeUnit.liters,
          ),
          isNull,
        );
      }
    });
  });
}
