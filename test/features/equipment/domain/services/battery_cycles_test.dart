import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/services/battery_cycles.dart';

/// Only gear that runs on a battery counts battery cycles, unless the diver
/// has asked for a cycles clock on it, which opts the item in.
void main() {
  final t = DateTime.utc(2026, 1, 1);
  ServiceKind kind({Map<ExposureUnit, double> intervals = const {}}) =>
      ServiceKind(
        id: 'k',
        name: 'Charge',
        exposureIntervals: intervals,
        createdAt: t,
        updatedAt: t,
      );
  ServiceSchedule schedule({
    Map<ExposureUnit, double> intervals = const {},
    int? dives,
    bool enabled = true,
  }) => ServiceSchedule(
    id: 's',
    equipmentId: 'e',
    serviceKindId: 'k',
    intervalDives: dives,
    exposureIntervals: intervals,
    enabled: enabled,
    createdAt: t,
    updatedAt: t,
  );

  test('every battery-powered type accrues cycles with no schedule', () {
    for (final type in const [
      EquipmentType.battery,
      EquipmentType.light,
      EquipmentType.dpv,
      EquipmentType.computer,
      EquipmentType.transmitter,
      EquipmentType.rebreather,
      EquipmentType.camera,
      EquipmentType.strobe,
    ]) {
      expect(
        accruesBatteryCycles(type: type, schedules: const [], kindsById: {}),
        isTrue,
        reason: type.name,
      );
    }
  });

  test('unpowered gear accrues no cycles', () {
    for (final type in const [
      EquipmentType.bcd,
      EquipmentType.fins,
      EquipmentType.drysuit,
      EquipmentType.regulator,
      EquipmentType.other,
    ]) {
      expect(
        accruesBatteryCycles(type: type, schedules: const [], kindsById: {}),
        isFalse,
        reason: type.name,
      );
    }
  });

  test('a cycles interval on the schedule opts unpowered gear in', () {
    expect(
      accruesBatteryCycles(
        type: EquipmentType.other,
        schedules: [
          schedule(intervals: const {ExposureUnit.cycles: 50}),
        ],
        kindsById: {'k': kind()},
      ),
      isTrue,
    );
  });

  test('a cycles interval inherited from the kind opts it in too', () {
    expect(
      accruesBatteryCycles(
        type: EquipmentType.other,
        schedules: [schedule()],
        kindsById: {
          'k': kind(intervals: const {ExposureUnit.cycles: 50}),
        },
      ),
      isTrue,
    );
  });

  test('a clock the engine would skip does not opt it in', () {
    final cycles = {'k': kind()};
    // Disabled.
    expect(
      accruesBatteryCycles(
        type: EquipmentType.bcd,
        schedules: [
          schedule(intervals: const {ExposureUnit.cycles: 50}, enabled: false),
        ],
        kindsById: cycles,
      ),
      isFalse,
    );
    // Its kind is unknown.
    expect(
      accruesBatteryCycles(
        type: EquipmentType.bcd,
        schedules: [
          schedule(intervals: const {ExposureUnit.cycles: 50}),
        ],
        kindsById: const {},
      ),
      isFalse,
    );
    // Counts dives, not cycles.
    expect(
      accruesBatteryCycles(
        type: EquipmentType.bcd,
        schedules: [schedule(dives: 100)],
        kindsById: cycles,
      ),
      isFalse,
    );
  });
}
