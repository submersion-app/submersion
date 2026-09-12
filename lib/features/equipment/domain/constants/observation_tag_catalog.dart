import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';

/// The tags a check-in offers for one equipment type, in display order,
/// always ending with `other`. Mirrors the spec's table; near relatives
/// (stages, hoses, wings, strobes, instruments, base layers, housings)
/// get their parent type's group so a diver who logs them separately still
/// sees the right words. A type the spec does not name gets `other` only.
List<ObservationTag> observationTagsFor(EquipmentType type) {
  final specific = switch (type) {
    EquipmentType.regulator ||
    EquipmentType.firstStage ||
    EquipmentType.secondStage ||
    EquipmentType.hose => const [
      ObservationTag.freeFlow,
      ObservationTag.hardBreathing,
      ObservationTag.wetBreathing,
      ObservationTag.leak,
      ObservationTag.hoseDamage,
    ],
    EquipmentType.bcd || EquipmentType.wing => const [
      ObservationTag.inflatorStuck,
      ObservationTag.inflatorSlow,
      ObservationTag.bladderLeak,
      ObservationTag.dumpLeak,
    ],
    EquipmentType.drysuit => const [
      ObservationTag.leakNeck,
      ObservationTag.leakWrist,
      ObservationTag.leakZip,
      ObservationTag.leakBoot,
      ObservationTag.leakValve,
      ObservationTag.leakSeam,
    ],
    EquipmentType.wetsuit ||
    EquipmentType.undersuit ||
    EquipmentType.baselayer ||
    EquipmentType.rashGuard ||
    EquipmentType.hood ||
    EquipmentType.gloves ||
    EquipmentType.boots => const [
      ObservationTag.tear,
      ObservationTag.seamFailure,
    ],
    EquipmentType.light || EquipmentType.strobe => const [
      ObservationTag.dim,
      ObservationTag.died,
      ObservationTag.flooded,
      ObservationTag.switchFault,
    ],
    EquipmentType.computer || EquipmentType.instrument => const [
      ObservationTag.batteryLow,
      ObservationTag.screenFault,
      ObservationTag.connectionFault,
    ],
    EquipmentType.transmitter => const [
      ObservationTag.dropout,
      ObservationTag.batteryLow,
    ],
    EquipmentType.rebreather => const [
      ObservationTag.cellWarning,
      ObservationTag.loopLeak,
      ObservationTag.solenoidFault,
      ObservationTag.scrubberBreakthrough,
    ],
    EquipmentType.o2Cell => const [
      ObservationTag.slowResponse,
      ObservationTag.erratic,
    ],
    EquipmentType.battery => const [
      ObservationTag.died,
      ObservationTag.lowCapacity,
    ],
    EquipmentType.dpv => const [
      ObservationTag.died,
      ObservationTag.flooded,
      ObservationTag.propFault,
    ],
    EquipmentType.fins || EquipmentType.mask || EquipmentType.snorkel => const [
      ObservationTag.strapBroke,
      ObservationTag.leak,
    ],
    EquipmentType.camera ||
    EquipmentType.housing => const [ObservationTag.flooded],
    _ => const <ObservationTag>[],
  };
  return [...specific, ObservationTag.other];
}
