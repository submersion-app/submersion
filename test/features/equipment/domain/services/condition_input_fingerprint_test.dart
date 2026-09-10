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

  String fp({
    List<EquipmentExposureSample>? s,
    List<EquipmentObservation>? o,
    List<Incident>? i,
    List<EquipmentItem>? c,
    ExposureThresholds? t,
    int version = 1,
    int summaryVersion = 1,
  }) => conditionInputFingerprint(
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

  test('a new sensor summary version restales every item', () {
    // Summaries are recomputed when their own algorithm version rises,
    // even though no dive changed. Without that version here the marker
    // still matches, the engine never re-runs, and every finding stays
    // frozen against readings that have since been recomputed.
    expect(fp(summaryVersion: 2), isNot(fp()));
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
