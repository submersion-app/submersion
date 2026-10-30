import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/parsed_tank_resolver.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';

/// The cylinders left after [dropUnusedOcGases], and the parsed indices it
/// removed.
typedef UnusedOcGasDrop = ({List<TankData> tanks, Set<int> dropped});

/// Removes the cylinders the resolver marked as unused open-circuit gases
/// (`TankData.unusedOcGas`, issue #3668), except those in [keep].
///
/// Callers run it after the bailout transmitter claim, so a transmitter that
/// takes an unused gas's mix has already taken it. A dive is never left with
/// no cylinder: when every tank would go, nothing is dropped. Returns new
/// lists.
UnusedOcGasDrop dropUnusedOcGases(
  List<TankData> tanks, {
  Set<int> keep = const {},
}) {
  bool drops(TankData t) => t.unusedOcGas && !keep.contains(t.index);
  final kept = [
    for (final t in tanks)
      if (!drops(t)) t,
  ];
  if (kept.isEmpty) return (tanks: [...tanks], dropped: const {});
  return (
    tanks: kept,
    dropped: {
      for (final t in tanks)
        if (drops(t)) t.index,
    },
  );
}

/// The parsed indices of unused open-circuit gases whose own stored row (its
/// source index names the gas, so not a row the diver added by hand that
/// reaches the index through the order fallback) the diver [edited], and those
/// whose row holds only what an importer wrote ([importers]). A re-parse keeps
/// the first and lets the claim and the drop treat the second as the
/// computer's own cylinder again.
({Set<int> edited, Set<int> importers}) sortUnusedOcGasRows(
  List<TankData> parsedTanks,
  Map<int, DiveTank> matches, {
  TankPresetEntity? defaultPreset,
}) {
  final edited = <int>{};
  final importers = <int>{};
  for (final tank in parsedTanks) {
    if (!tank.unusedOcGas) continue;
    final row = matches[tank.index];
    if (row == null || row.sourceTankIndex != tank.index) continue;
    unusedOcGasEditedByDiver(row, tank, defaultPreset: defaultPreset)
        ? edited.add(tank.index)
        : importers.add(tank.index);
  }
  return (edited: edited, importers: importers);
}

/// Whether a stored cylinder for an unused open-circuit gas carries anything
/// the diver set, so a re-parse must keep it rather than delete it.
///
/// Wider than the bailout claim's test: deleting is worse than merging, so a
/// hand-entered pressure, a regulator, a trip cylinder or a passport all keep
/// the row. What the importer itself wrote is excused: the role it gave the
/// gas before #2319 ([openCircuitGasRole]), and on a back-gas row the size,
/// working pressure, material and name of the diver's [defaultPreset], but
/// only when all four match it.
bool unusedOcGasEditedByDiver(
  DiveTank row,
  TankData parsed, {
  TankPresetEntity? defaultPreset,
}) {
  final extraRegulators = row.extraRegulatorIds?.trim();
  final carriesDiverData =
      row.tankName != null ||
      row.equipmentId != null ||
      row.startPressure != null ||
      row.endPressure != null ||
      row.regulatorEquipmentId != null ||
      (extraRegulators != null &&
          extraRegulators.isNotEmpty &&
          extraRegulators != '[]') ||
      row.tripCylinderId != null ||
      row.passportId != null;
  if (carriesDiverData) return true;

  if ((row.o2Percent - parsed.o2Percent).abs() > 0.5 ||
      (row.hePercent - parsed.hePercent).abs() > 0.5) {
    return true;
  }

  final parsedRole = parsed.role ?? TankRole.backGas.name;
  if (row.tankRole != parsedRole &&
      row.tankRole != openCircuitGasRole(row.o2Percent)) {
    return true;
  }

  final hasCylinderSpec =
      (row.volume ?? 0) > 0 ||
      row.workingPressure != null ||
      row.tankMaterial != null ||
      row.presetName != null;
  return hasCylinderSpec && !_filledFromPreset(row, defaultPreset);
}

/// Whether [row]'s cylinder spec is exactly what the download wrote from the
/// default tank preset, which it only ever did on a back-gas cylinder.
bool _filledFromPreset(DiveTank row, TankPresetEntity? preset) {
  if (preset == null || row.tankRole != TankRole.backGas.name) return false;
  bool near(double? a, double b) => a != null && (a - b).abs() <= 0.01;
  return near(row.volume, preset.volumeLiters) &&
      near(row.workingPressure, preset.workingPressureBar) &&
      row.tankMaterial == preset.material.name &&
      row.presetName == preset.name;
}
