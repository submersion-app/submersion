import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A dive tank describing the cylinder a tag names (spec section 9, "Use on
/// a dive"). A copy, never a link: the dive records what was breathed, and
/// nothing on the tank points back at the tag. The id is left for the dive
/// edit page to assign.
DiveTank tankFromPassport(
  CylinderPassportPayload tag, {
  GasMix mix = const GasMix(),
}) {
  final volume = tag.volumeL;
  final workingPressure = tag.workingPressureBar?.toDouble();
  final preset = volume != null && workingPressure != null
      ? TankPresets.matchBySpecs(volume, workingPressure)
      : null;
  return DiveTank(
    id: '',
    name: tag.name,
    volume: volume,
    workingPressure: workingPressure,
    gasMix: mix,
    material: tag.material,
    presetName: preset?.name,
  );
}
