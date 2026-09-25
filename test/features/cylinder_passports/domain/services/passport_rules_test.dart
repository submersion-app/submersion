import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_rules.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

void main() {
  final now = DateTime(2026, 9, 25);

  ServiceClockStatus clock(ServiceClockSeverity severity) => ServiceClockStatus(
    schedule: ServiceSchedule(
      id: 's',
      equipmentId: 'eq',
      serviceKindId: 'o2-clean',
      createdAt: now,
      updatedAt: now,
    ),
    kind: ServiceKind(
      id: 'o2-clean',
      name: 'O2 clean',
      createdAt: now,
      updatedAt: now,
    ),
    anchor: DateTime(2026, 1, 1),
    severity: severity,
    now: now,
  );

  ServiceRecord record(String kindId, DateTime date) => ServiceRecord(
    id: 'r-$kindId-${date.millisecondsSinceEpoch}',
    equipmentId: 'eq',
    serviceCategory: ServiceCategory.inspection,
    serviceKindId: kindId,
    serviceDate: date,
    createdAt: date,
    updatedAt: date,
  );

  group('recordedServiceDate', () {
    test('a clock with no record and no baseline has no service date', () {
      // The clock itself anchors on the creation date; that is a reminder
      // baseline, never a fact to print.
      expect(
        recordedServiceDate(
          clock: clock(ServiceClockSeverity.ok),
          records: const [],
        ),
        isNull,
      );
    });

    test('the newest record of the kind is the service date', () {
      expect(
        recordedServiceDate(
          clock: clock(ServiceClockSeverity.ok),
          records: [
            record('o2-clean', DateTime(2025, 5, 1)),
            record('o2-clean', DateTime(2026, 2, 1)),
            record('hydro', DateTime(2026, 8, 1)),
          ],
        ),
        DateTime(2026, 2, 1),
      );
    });

    test('a baseline the diver set is a service date', () {
      final c = clock(ServiceClockSeverity.ok);
      final withBaseline = ServiceClockStatus(
        schedule: c.schedule.copyWith(
          anchorDate: DateTime(2024, 3, 1),
          anchorSetAt: now,
        ),
        kind: c.kind,
        anchor: DateTime(2024, 3, 1),
        severity: c.severity,
        now: now,
      );
      expect(
        recordedServiceDate(clock: withBaseline, records: const []),
        DateTime(2024, 3, 1),
      );
    });

    test('no clock, no date', () {
      expect(recordedServiceDate(clock: null, records: const []), isNull);
    });
  });

  group('o2CleanWarning', () {
    test('boundary of the high-O2 threshold', () {
      expect(
        o2CleanWarning(
          newestO2Percent: 40.0,
          o2CleanClock: null,
          highO2Fraction: 0.40,
        ),
        O2CleanWarning.none,
      );
      expect(
        o2CleanWarning(
          newestO2Percent: 40.5,
          o2CleanClock: null,
          highO2Fraction: 0.40,
        ),
        O2CleanWarning.untracked,
      );
    });

    test('overdue clock warns, current clock does not', () {
      expect(
        o2CleanWarning(
          newestO2Percent: 50,
          o2CleanClock: clock(ServiceClockSeverity.overdue),
          highO2Fraction: 0.40,
        ),
        O2CleanWarning.overdue,
      );
      expect(
        o2CleanWarning(
          newestO2Percent: 50,
          o2CleanClock: clock(ServiceClockSeverity.dueSoon),
          highO2Fraction: 0.40,
        ),
        O2CleanWarning.none,
      );
    });

    test('no fill, no warning', () {
      expect(
        o2CleanWarning(
          newestO2Percent: null,
          o2CleanClock: null,
          highO2Fraction: 0.40,
        ),
        O2CleanWarning.none,
      );
    });
  });

  group('tagIsStale', () {
    final tag = CylinderPassportPayload(
      passportId: 'p',
      writtenOn: DateTime(2026, 1, 10),
      volumeL: 12,
      workingPressureBar: 232,
      material: TankMaterial.steel,
    );

    test('a service anchored after the write date is stale', () {
      expect(tagIsStale(tag: tag, hydroAnchor: DateTime(2026, 3, 1)), isTrue);
      expect(tagIsStale(tag: tag, vipAnchor: DateTime(2025, 12, 1)), isFalse);
    });

    test('a spec that differs is stale, within tolerance is not', () {
      expect(tagIsStale(tag: tag, volumeL: 12.04), isFalse);
      expect(tagIsStale(tag: tag, volumeL: 15), isTrue);
      expect(tagIsStale(tag: tag, workingPressureBar: 300), isTrue);
      expect(tagIsStale(tag: tag, material: TankMaterial.aluminum), isTrue);
    });

    test('unknown facts on either side never make it stale', () {
      expect(tagIsStale(tag: tag), isFalse);
      expect(
        tagIsStale(
          tag: const CylinderPassportPayload(passportId: 'p'),
          hydroAnchor: DateTime(2026, 3, 1),
          volumeL: 15,
        ),
        isFalse,
      );
    });
  });

  group('payloadForItem', () {
    test('copies the spec, prefers the identifier as the name', () {
      const item = EquipmentItem(
        id: 'eq',
        name: 'Faber 12',
        type: EquipmentType.tank,
        serialNumber: 'F123',
        attributes: [
          EquipmentAttribute(
            id: 'a1',
            equipmentId: 'eq',
            key: EquipmentAttrKeys.identifier,
            valueText: 'S12-A',
          ),
          EquipmentAttribute(
            id: 'a2',
            equipmentId: 'eq',
            key: EquipmentAttrKeys.volumeL,
            valueNum: 12,
          ),
          EquipmentAttribute(
            id: 'a3',
            equipmentId: 'eq',
            key: EquipmentAttrKeys.workingPressureBar,
            valueNum: 232,
          ),
          EquipmentAttribute(
            id: 'a4',
            equipmentId: 'eq',
            key: EquipmentAttrKeys.tankMaterial,
            valueText: 'steel',
          ),
          EquipmentAttribute(
            id: 'a5',
            equipmentId: 'eq',
            key: 'valve_type',
            valueText: 'convertible',
          ),
        ],
      );
      final p = payloadForItem(
        item: item,
        passportId: 'p',
        writtenOn: now,
        hydroAnchor: DateTime(2024, 6, 14),
        o2Clean: true,
      );
      expect(p.name, 'S12-A');
      expect(p.serial, 'F123');
      expect(p.volumeL, 12);
      expect(p.workingPressureBar, 232);
      expect(p.material, TankMaterial.steel);
      expect(p.valve, PassportValve.convertible);
      expect(p.lastHydro, DateTime(2024, 6, 14));
      expect(p.lastVip, isNull);
      expect(p.o2Clean, isTrue);
      expect(p.writtenOn, now);
    });
  });
}
