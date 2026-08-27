import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';

/// Fill the physical cylinder attributes a dive computer never reports from
/// the diver's default tank [preset].
///
/// Downloads carry transmitter pressure but almost never cylinder size, which
/// leaves volumetric (L/min) SAC unreachable on every downloaded dive
/// (issue #386). This is the download-side counterpart of the file-import
/// fallback in `import_tank_defaults.dart`, with two deliberate differences:
///
/// - It never fabricates a fill pressure. A download's pressures come from
///   the transmitter, so a non-AI dive stays pressureless rather than gaining
///   a fictitious 200 bar start.
/// - It only touches back-gas cylinders (or ones whose role was not
///   inferred). The default tank describes the diver's usual back gas;
///   stamping its size and label on a deco bottle or a CCR diluent would
///   fabricate a cylinder record and misconvert that segment's SAC.
///
/// A volume the computer did report is left untouched, and no preset label
/// is attached to it; only a missing or zero size is filled. Returns a new
/// list.
List<TankData> applyDefaultPresetToTanks(
  List<TankData> tanks,
  TankPresetEntity preset,
) {
  return tanks.map((tank) {
    final volume = tank.volumeLiters;
    final hasVolume = volume != null && volume > 0;
    final isBackGas = tank.role == null || tank.role == TankRole.backGas.name;
    if (hasVolume || !isBackGas) {
      return tank;
    }
    return TankData(
      index: tank.index,
      o2Percent: tank.o2Percent,
      hePercent: tank.hePercent,
      startPressure: tank.startPressure,
      endPressure: tank.endPressure,
      volumeLiters: preset.volumeLiters,
      workingPressure: tank.workingPressure ?? preset.workingPressureBar,
      material: tank.material ?? preset.material.name,
      presetName: tank.presetName ?? preset.name,
      role: tank.role,
    );
  }).toList();
}
