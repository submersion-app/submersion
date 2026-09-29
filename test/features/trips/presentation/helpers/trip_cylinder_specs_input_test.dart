import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_specs_input.dart';

void main() {
  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(
    AppSettings(
      pressureUnit: PressureUnit.psi,
      volumeUnit: VolumeUnit.cubicFeet,
    ),
  );
  final al80 = TankPresetEntity.fromBuiltIn(TankPresets.byName('al80')!);

  group('for input', () {
    test('metric shows liters and bar', () {
      expect(
        cylinderSizeForInput(metric, liters: 11.1, workingPressureBar: 207),
        '11.1',
      );
      expect(cylinderWorkingPressureForInput(metric, 207), '207');
    });

    test('imperial shows rated capacity and psi', () {
      // 11.1 L at 207 bar is 81.1 cuft by the ideal gas rule.
      expect(
        cylinderSizeForInput(imperial, liters: 11.1, workingPressureBar: 207),
        '81',
      );
      expect(
        cylinderSizeForInput(
          imperial,
          liters: 11.1,
          workingPressureBar: 207,
          ratedCuft: 77,
        ),
        '77',
      );
      expect(
        cylinderWorkingPressureForInput(imperial, 207),
        imperial.convertPressure(207).round().toString(),
      );
    });

    test('nothing known shows empty fields', () {
      expect(cylinderSizeForInput(metric), '');
      expect(cylinderSizeForInput(imperial, liters: 11.1), '');
      expect(cylinderWorkingPressureForInput(metric, null), '');
    });
  });

  group('from input', () {
    test('metric reads liters and bar', () {
      final r = cylinderSpecsFromInput(
        metric,
        sizeText: '11.1',
        workingPressureText: '207',
      );
      expect(r.invalid, isFalse);
      expect(r.volumeLiters, 11.1);
      expect(r.workingPressureBar, 207);
    });

    test('imperial converts capacity back through the working pressure', () {
      final r = cylinderSpecsFromInput(
        imperial,
        sizeText: '80',
        workingPressureText: '3000',
      );
      final bar = imperial.pressureToBar(3000);
      expect(r.workingPressureBar, closeTo(bar, 1e-9));
      expect(r.volumeLiters, closeTo(80 * 28.3168 / bar, 1e-9));
    });

    test('imperial with a preset takes the preset water volume', () {
      final r = cylinderSpecsFromInput(
        imperial,
        sizeText: '77',
        workingPressureText: '3000',
        preset: al80,
      );
      expect(r.volumeLiters, al80.volumeLiters);
    });

    test('an imperial size with no working pressure asks for one', () {
      final r = cylinderSpecsFromInput(
        imperial,
        sizeText: '80',
        workingPressureText: '',
      );
      expect(r.needsPressure, isTrue);
      expect(r.volumeLiters, isNull);
      expect(
        cylinderSpecsFromInput(
          imperial,
          sizeText: '80',
          workingPressureText: '',
          preset: al80,
        ).needsPressure,
        isFalse,
      );
      expect(
        cylinderSpecsFromInput(
          metric,
          sizeText: '11.1',
          workingPressureText: '',
        ).needsPressure,
        isFalse,
      );
    });

    test('blank fields are unknown, not invalid', () {
      final r = cylinderSpecsFromInput(
        metric,
        sizeText: ' ',
        workingPressureText: '',
      );
      expect(r.invalid, isFalse);
      expect(r.volumeLiters, isNull);
      expect(r.workingPressureBar, isNull);
    });

    test('unreadable or non-positive numbers are invalid', () {
      expect(
        cylinderSpecsFromInput(
          metric,
          sizeText: 'abc',
          workingPressureText: '207',
        ).invalid,
        isTrue,
      );
      expect(
        cylinderSpecsFromInput(
          metric,
          sizeText: '11.1',
          workingPressureText: '0',
        ).invalid,
        isTrue,
      );
    });
  });
}
