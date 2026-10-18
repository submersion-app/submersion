import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/computer_recorded_tank.dart';

/// Whether [tank] is still only a gas from the dive computer's gas list,
/// exactly as the importer made it (issue #3307): the computer recorded it,
/// no transmitter or pressure series is on it, and the diver has added no
/// size, name, preset or gear. Such a cylinder stands for a gas, not a physical
/// cylinder, so merging it into the transmitter that carried that gas loses
/// nothing anyone recorded.
bool isAsImportedGasCylinder(
  DiveTank tank, {
  required bool hasPressureSeries,
}) =>
    isComputerRecordedTank(tank) &&
    !hasPressureSeries &&
    tank.transmitterSerial == null &&
    tank.equipmentId == null &&
    tank.volume == null &&
    tank.name == null &&
    tank.presetName == null;
