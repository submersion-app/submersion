import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Liters of gas in one cubic foot, the ideal gas figure the tank editor
/// uses to turn a rated capacity back into water volume.
const double _litersPerCuft = 28.3168;

bool _imperialSize(UnitFormatter units) =>
    units.settings.volumeUnit == VolumeUnit.cubicFeet;

/// A working pressure for a text field in the diver's pressure unit.
String cylinderWorkingPressureForInput(UnitFormatter units, double? bar) =>
    bar == null ? '' : formatRoundedForInput(units.convertPressure(bar), 0);

/// A cylinder size for a text field: liters of water in metric, rated gas
/// capacity in cuft in imperial ([ratedCuft] when the preset names one,
/// else the ideal gas figure from the working pressure). Empty when the
/// size cannot be stated in the diver's unit.
String cylinderSizeForInput(
  UnitFormatter units, {
  double? liters,
  double? workingPressureBar,
  double? ratedCuft,
}) {
  if (liters == null) return '';
  if (!_imperialSize(units)) return formatRoundedForInput(liters, 1);
  if (ratedCuft != null) return formatRoundedForInput(ratedCuft, 0);
  if (workingPressureBar == null || workingPressureBar <= 0) return '';
  return formatRoundedForInput(liters * workingPressureBar / _litersPerCuft, 0);
}

/// Reads a size and a working pressure typed in the diver's units back to
/// liters and bar. Blank fields are unknown; unreadable or non-positive
/// numbers set [invalid]. In imperial a chosen [preset] supplies the water
/// volume, because a rated cuft figure cannot be reversed exactly; without
/// one a cuft size needs the working pressure, and [needsPressure] is set
/// rather than dropping the typed size.
({
  double? volumeLiters,
  double? workingPressureBar,
  bool invalid,
  bool needsPressure,
})
cylinderSpecsFromInput(
  UnitFormatter units, {
  required String sizeText,
  required String workingPressureText,
  TankPresetEntity? preset,
}) {
  // A size or pressure must be positive; blank means unknown.
  bool bad(NumberRead r) => switch (r) {
    NumberValue(:final value) => value <= 0,
    NumberBlank() => false,
    NumberInvalid() => true,
  };
  double? valueOf(NumberRead r) => r is NumberValue ? r.value : null;
  final sizeRead = readNumber(sizeText);
  final wpRead = readNumber(workingPressureText);
  final size = valueOf(sizeRead);
  final wpDisplay = valueOf(wpRead);
  if (bad(sizeRead) || bad(wpRead)) {
    return (
      volumeLiters: null,
      workingPressureBar: null,
      invalid: true,
      needsPressure: false,
    );
  }
  final wpBar = wpDisplay == null ? null : units.pressureToBar(wpDisplay);
  double? liters;
  if (size != null) {
    if (!_imperialSize(units)) {
      liters = size;
    } else if (preset != null) {
      liters = preset.volumeLiters;
    } else if (wpBar != null) {
      liters = size * _litersPerCuft / wpBar;
    }
  }
  return (
    volumeLiters: liters,
    workingPressureBar: wpBar,
    invalid: false,
    needsPressure: size != null && liters == null,
  );
}
