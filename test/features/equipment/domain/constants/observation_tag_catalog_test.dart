import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/observation_tag_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';

void main() {
  test('every type ends with other and has no duplicates', () {
    for (final type in EquipmentType.values) {
      final tags = observationTagsFor(type);
      expect(tags.last, ObservationTag.other, reason: type.name);
      expect(tags.toSet().length, tags.length, reason: type.name);
    }
  });

  test('the spec groups are honoured', () {
    expect(observationTagsFor(EquipmentType.regulator), [
      ObservationTag.freeFlow,
      ObservationTag.hardBreathing,
      ObservationTag.wetBreathing,
      ObservationTag.leak,
      ObservationTag.hoseDamage,
      ObservationTag.other,
    ]);
    expect(observationTagsFor(EquipmentType.drysuit), [
      ObservationTag.leakNeck,
      ObservationTag.leakWrist,
      ObservationTag.leakZip,
      ObservationTag.leakBoot,
      ObservationTag.leakValve,
      ObservationTag.leakSeam,
      ObservationTag.other,
    ]);
    expect(observationTagsFor(EquipmentType.hood), [
      ObservationTag.tear,
      ObservationTag.seamFailure,
      ObservationTag.other,
    ]);
    expect(observationTagsFor(EquipmentType.transmitter), [
      ObservationTag.dropout,
      ObservationTag.batteryLow,
      ObservationTag.other,
    ]);
    expect(observationTagsFor(EquipmentType.o2Cell), [
      ObservationTag.slowResponse,
      ObservationTag.erratic,
      ObservationTag.other,
    ]);
    expect(observationTagsFor(EquipmentType.mask), [
      ObservationTag.strapBroke,
      ObservationTag.leak,
      ObservationTag.other,
    ]);
    expect(observationTagsFor(EquipmentType.weights), [ObservationTag.other]);
  });

  test('every tag is offered for at least one type', () {
    final offered = {
      for (final type in EquipmentType.values) ...observationTagsFor(type),
    };
    expect(offered, ObservationTag.values.toSet());
  });
}
