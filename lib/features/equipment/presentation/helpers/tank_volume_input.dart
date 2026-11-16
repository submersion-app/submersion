import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Liters of water volume per cubic foot of gas at one bar, the ideal-gas
/// factor the tank editor converts with.
const double _litersPerCuft = 28.3168;

/// The text a cylinder volume field starts with, in the diver's [unit]
/// (issue #4494). Imperial divers size cylinders by gas capacity, so cubic
/// feet are shown when a working pressure makes the conversion possible: a
/// known preset's rated figure, else the ideal-gas one. Without a working
/// pressure the field stays in liters, as in the tank editor.
String tankVolumeInputText(
  double liters,
  double? workingPressureBar,
  VolumeUnit unit,
) {
  if (unit == VolumeUnit.cubicFeet && workingPressureBar != null) {
    final rated = TankPresets.matchBySpecs(
      liters,
      workingPressureBar,
    )?.ratedCapacityCuft;
    return formatRoundedForInput(
      rated ?? liters * workingPressureBar / _litersPerCuft,
      1,
    );
  }
  return formatRoundedForInput(
    liters,
    UnitFormatter.tankVolumeLiterDecimals(liters),
  );
}

/// The liters a cylinder volume field holds, or null when it is blank or
/// unreadable. Text the diver left as it started returns [initialLiters]
/// unchanged, so a rounded cubic-feet figure never drifts the stored size.
/// Read with the row's current [workingPressureBar], as
/// [tankVolumeInputText] wrote it.
double? tankVolumeFromInput(
  String text, {
  required String initialText,
  required double initialLiters,
  required double? workingPressureBar,
  required VolumeUnit unit,
}) {
  if (text.trim() == initialText.trim()) return initialLiters;
  final read = readNumber(text, allowNegative: false);
  if (read is! NumberValue) return null;
  final value = read.value;
  if (unit == VolumeUnit.cubicFeet &&
      workingPressureBar != null &&
      workingPressureBar > 0) {
    // A preset's rated figure is read back as that preset's water volume,
    // as the field showed it: the ideal-gas factor would turn a typed
    // "77.4" (an AL80) into 10.6 L instead of 11.1 L.
    return TankPresets.matchByCapacity(
          value,
          workingPressureBar,
        )?.volumeLiters ??
        value * _litersPerCuft / workingPressureBar;
  }
  return value;
}
