import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';

/// How far apart two volumes, in litres, may be and still be one cylinder: a
/// size sent back through a unit conversion lands a hair off the stored one.
const double _volumeToleranceLiters = 0.005;

/// How far apart two working pressures, in bar, may be and still be one
/// cylinder: 3000 psi typed back is 206.8427 bar against a stored 206.843.
const double _pressureToleranceBar = 0.05;

/// Whether a cylinder of [volumeLiters] at [workingPressureBar] is the one of
/// [otherVolumeLiters] at [otherWorkingPressureBar]. A manufacturer's rated
/// capacity belongs to one volume at one pressure, so it holds while this is
/// true and goes once it is not (issue #800).
bool isSameCylinderSize(
  double volumeLiters,
  double workingPressureBar,
  double otherVolumeLiters,
  double otherWorkingPressureBar,
) =>
    (volumeLiters - otherVolumeLiters).abs() < _volumeToleranceLiters &&
    (workingPressureBar - otherWorkingPressureBar).abs() <
        _pressureToleranceBar;

/// The diver's own preset named [presetName] in [presets], when a cylinder of
/// [volumeLiters] at [workingPressureBar] is still that preset's size. A
/// built-in preset never answers: those resolve by name alone.
TankPresetEntity? ownPresetFor(
  String? presetName,
  double? volumeLiters,
  double? workingPressureBar,
  List<TankPresetEntity>? presets,
) {
  if (presetName == null ||
      volumeLiters == null ||
      workingPressureBar == null ||
      presets == null) {
    return null;
  }
  return presets
      .where(
        (p) =>
            !p.isBuiltIn &&
            p.name == presetName &&
            isSameCylinderSize(
              p.volumeLiters,
              p.workingPressureBar,
              volumeLiters,
              workingPressureBar,
            ),
      )
      .firstOrNull;
}
