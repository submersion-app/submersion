import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/services/condition_input_fingerprint.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';

void main() {
  final now = DateTime.utc(2026, 9, 9);
  final samples = [
    EquipmentExposureSample(
      diveId: 'd1',
      date: DateTime.utc(2026, 1, 1),
      durationSeconds: 100,
      updatedAt: 10,
    ),
    EquipmentExposureSample(
      diveId: 'd2',
      date: DateTime.utc(2026, 1, 2),
      durationSeconds: 100,
      updatedAt: 20,
    ),
  ];
  final observation = EquipmentObservation(
    id: 'o1',
    equipmentId: 'reg',
    observedAt: now,
    status: ObservationStatus.ok,
    createdAt: now,
    updatedAt: now,
  );
  final incident = Incident(
    id: 'i1',
    equipmentId: 'reg',
    occurredAt: now,
    category: IncidentCategory.equipment,
    severity: IncidentSeverity.moderate,
    narrative: 'n',
    createdAt: now,
    updatedAt: now,
  );
  final child = EquipmentItem(
    id: 'c1',
    name: 'c1',
    type: EquipmentType.o2Cell,
    parentEquipmentId: 'reg',
    createdAt: now,
    attributes: [
      EquipmentAttribute.curated(
        equipmentId: 'c1',
        key: EquipmentAttrKeys.cellSlot,
        valueNum: 1,
      ),
    ],
  );

  const rebreather = EquipmentItem(
    id: 'ccr',
    name: 'CCR',
    type: EquipmentType.rebreather,
  );
  final regulator = EquipmentItem(
    id: 'reg',
    name: 'Reg',
    type: EquipmentType.regulator,
    createdAt: now,
  );

  EquipmentItem withSlot(EquipmentItem base, int slot) => base.copyWith(
    attributes: [
      EquipmentAttribute.curated(
        equipmentId: base.id,
        key: EquipmentAttrKeys.cellSlot,
        valueNum: slot.toDouble(),
      ),
    ],
  );

  String fp({
    EquipmentItem? item,
    EquipmentItem? parent,
    bool noParent = false,
    Map<String, String>? stamps,
    Set<String>? serials,
    List<EquipmentExposureSample>? s,
    List<EquipmentObservation>? o,
    List<Incident>? i,
    List<EquipmentItem>? c,
    ExposureThresholds? t,
    int version = 1,
    int summaryVersion = 1,
  }) => conditionInputFingerprint(
    item: item ?? regulator,
    parent: noParent ? null : (parent ?? rebreather),
    summaryStamps: stamps ?? const {'d1': '1/10'},
    transmitterSerials: serials ?? const {'ABC'},
    samples: s ?? samples,
    observations: o ?? [observation],
    incidents: i ?? [incident],
    children: c ?? [child],
    thresholds: t ?? ExposureThresholds.defaults,
    engineVersion: version,
    summaryVersion: summaryVersion,
  );

  test('is stable for equal input', () {
    expect(fp(), fp());
    expect(fp(), hasLength(40));
  });

  test('sees every input', () {
    final base = fp();
    expect(fp(s: [samples.first]), isNot(base));
    expect(
      fp(
        s: [
          samples.first,
          EquipmentExposureSample(
            diveId: 'd2',
            date: DateTime.utc(2026, 1, 2),
            durationSeconds: 100,
            updatedAt: 21,
          ),
        ],
      ),
      isNot(base),
    );
    expect(fp(o: const []), isNot(base));
    expect(
      fp(
        o: [observation.copyWith(updatedAt: now.add(const Duration(days: 1)))],
      ),
      isNot(base),
    );
    expect(fp(i: const []), isNot(base));
    expect(fp(c: const []), isNot(base));
    expect(fp(t: const ExposureThresholds(coldWaterC: 5)), isNot(base));
    expect(fp(version: 2), isNot(base));
  });

  group('everything the engine branches on', () {
    // The engine reads the item's type, its parent, its own slot, each
    // child's type and slot, the transmitter serials and each dive's
    // summary row. A marker that misses one serves findings built for a
    // configuration the item no longer has.
    test('the item: type, parent, parent type and slot', () {
      final base = fp();
      expect(
        fp(item: regulator.copyWith(type: EquipmentType.bcd)),
        isNot(base),
      );
      expect(fp(noParent: true), isNot(base));
      expect(
        fp(item: regulator.copyWith(parentEquipmentId: 'other')),
        isNot(base),
      );
      expect(
        fp(parent: rebreather.copyWith(type: EquipmentType.housing)),
        isNot(base),
      );
      expect(fp(item: withSlot(regulator, 2)), isNot(base));
      expect(
        fp(item: withSlot(regulator, 2)),
        isNot(fp(item: withSlot(regulator, 3))),
      );
    });

    test('a child: type and slot', () {
      final base = fp();
      // Retiring a cell changes who occupies its slot.
      expect(fp(c: [child.copyWith(isActive: false)]), isNot(base));
      // A legacy row can change status without touching isActive.
      expect(
        fp(c: [child.copyWith(status: EquipmentStatus.sold)]),
        isNot(base),
      );
      expect(fp(c: [withSlot(child, 2)]), isNot(base));
      expect(fp(c: [child.copyWith(type: EquipmentType.battery)]), isNot(base));
    });

    test('the transmitter serials', () {
      expect(fp(serials: const {'ABC', 'DEF'}), isNot(fp()));
      expect(fp(serials: const {'DEF'}), isNot(fp()));
      expect(fp(serials: const {'DEF', 'ABC'}), fp(serials: {'ABC', 'DEF'}));
    });

    test('a summary row arriving or being recomputed', () {
      // The sweep can write a dive's summary after the item was first
      // reviewed. The dive itself did not change, so without the summary
      // rows here the old marker still matched and served findings built
      // without those readings.
      final base = fp();
      expect(fp(stamps: const {'d1': '1/10', 'd2': '1/20'}), isNot(base));
      expect(fp(stamps: const {'d1': '2/10'}), isNot(base));
      expect(fp(stamps: const {'d1': '1/11'}), isNot(base));
    });
  });

  test('a new sensor summary version restales every item', () {
    // Summaries are recomputed when their own algorithm version rises,
    // even though no dive changed. Without that version here the marker
    // still matches, the engine never re-runs, and every finding stays
    // frozen against readings that have since been recomputed.
    expect(fp(summaryVersion: 2), isNot(fp()));
  });

  test('a link change that moves a reading without touching the dive', () {
    // The transmitter registry rewrites dive_tanks.equipment_id without
    // moving dives.updated_at, so a dive can keep its id and stamp while
    // what it contributes changes (the gas the item breathed, the dive's
    // readings through another link). Each engine-relevant field counts.
    EquipmentExposureSample d2({
      double? contactO2Fraction,
      double? maxDepth,
      double? minTemperature,
      int durationSeconds = 100,
    }) => EquipmentExposureSample(
      diveId: 'd2',
      date: DateTime.utc(2026, 1, 2),
      durationSeconds: durationSeconds,
      maxDepth: maxDepth,
      minTemperature: minTemperature,
      contactO2Fraction: contactO2Fraction,
      updatedAt: 20,
    );
    final base = fp(s: [samples.first, d2()]);
    expect(fp(s: [samples.first, d2(contactO2Fraction: 0.32)]), isNot(base));
    expect(fp(s: [samples.first, d2(maxDepth: 40)]), isNot(base));
    expect(fp(s: [samples.first, d2(minTemperature: 6)]), isNot(base));
    expect(fp(s: [samples.first, d2(durationSeconds: 200)]), isNot(base));
  });

  group('identity, not just counts', () {
    // Deleting one dive and importing another of the same vintage keeps
    // the count and the newest stamp exactly where they were. Hashing
    // only those two would call the item unchanged and serve findings
    // built from a dive that is no longer in the logbook.
    test('a swapped dive of the same vintage restales the item', () {
      final swapped = [
        samples.first,
        EquipmentExposureSample(
          diveId: 'other',
          date: DateTime.utc(2026, 1, 2),
          durationSeconds: 100,
          updatedAt: 20,
        ),
      ];
      expect(fp(s: swapped), isNot(fp()));
    });

    test('a swapped check-in of the same vintage restales the item', () {
      final swapped = EquipmentObservation(
        id: 'other',
        equipmentId: 'reg',
        observedAt: now,
        status: ObservationStatus.ok,
        createdAt: now,
        updatedAt: now,
      );
      expect(fp(o: [swapped]), isNot(fp()));
    });

    test('a swapped incident of the same vintage restales the item', () {
      final swapped = Incident(
        id: 'other',
        equipmentId: 'reg',
        occurredAt: now,
        category: IncidentCategory.equipment,
        severity: IncidentSeverity.moderate,
        narrative: 'n',
        createdAt: now,
        updatedAt: now,
      );
      expect(fp(i: [swapped]), isNot(fp()));
    });

    test('the same input in another order hashes the same', () {
      expect(fp(s: samples.reversed.toList()), fp());
    });
  });
}
