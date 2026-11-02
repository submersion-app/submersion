import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/safety/data/repositories/incident_repository.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// A near-miss links to the check-in that recorded the fault. Each way that
/// link ends keeps the report, clears the link, and stages the report so a
/// peer cannot carry the old link back: ON DELETE SET NULL alone moves no
/// clock.
void main() {
  late EquipmentItem reg;
  late EquipmentObservationRepository observations;
  late IncidentRepository incidents;

  setUp(() async {
    await setUpTestDatabase();
    observations = EquipmentObservationRepository();
    incidents = IncidentRepository();
    reg = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<List<String>> pendingIncidents() async {
    final db = DatabaseService.instance.database;
    final rows = await db.select(db.syncRecords).get();
    return [
      for (final r in rows)
        if (r.entityType == 'incidents' && r.syncStatus == 'pending')
          r.recordId,
    ];
  }

  Future<EquipmentObservation> issue({String? diveId}) => observations.create(
    equipmentId: reg.id,
    diveId: diveId,
    observedAt: DateTime.utc(2026, 3, 1),
    status: ObservationStatus.issue,
    issueTags: const [ObservationTag.freeFlow],
  );

  Future<Incident> linkedTo(EquipmentObservation observation) async {
    final incident = await incidents.createIncident(
      occurredAt: DateTime.utc(2026, 3, 1),
      category: IncidentCategory.equipment,
      severity: IncidentSeverity.moderate,
      narrative: 'Free flow',
      equipmentId: reg.id,
      observationId: observation.id,
    );
    await SyncRepository().clearAllSyncRecords();
    return incident;
  }

  test('a report stores and reads back its check-in', () async {
    final observation = await issue();
    final incident = await linkedTo(observation);

    final read = await incidents.getIncidentById(incident.id);
    expect(read!.observationId, observation.id);
  });

  test('updating a report can set and clear the link', () async {
    final observation = await issue();
    final incident = await incidents.createIncident(
      occurredAt: DateTime.utc(2026, 3, 1),
      category: IncidentCategory.equipment,
      severity: IncidentSeverity.minor,
      narrative: 'Free flow',
      equipmentId: reg.id,
    );

    await incidents.updateIncident(
      incident.copyWith(observationId: observation.id),
    );
    expect(
      (await incidents.getIncidentById(incident.id))!.observationId,
      observation.id,
    );

    final linked = (await incidents.getIncidentById(incident.id))!;
    await incidents.updateIncident(linked.copyWith(clearObservationId: true));
    expect(
      (await incidents.getIncidentById(incident.id))!.observationId,
      isNull,
    );
  });

  test(
    'deleting the check-in keeps the report, clears and stages it',
    () async {
      final observation = await issue();
      final incident = await linkedTo(observation);
      final before = (await incidents.getIncidentById(incident.id))!.updatedAt;

      await observations.delete(observation.id);

      final after = (await incidents.getIncidentById(incident.id))!;
      expect(after.observationId, isNull);
      expect(after.equipmentId, reg.id);
      expect(after.updatedAt.isAfter(before), isTrue);
      expect(await pendingIncidents(), [incident.id]);
    },
  );

  test(
    'saving the check-in as OK keeps the report, clears and stages it',
    () async {
      final observation = await issue();
      final incident = await linkedTo(observation);

      await observations.update(
        observation.copyWith(status: ObservationStatus.ok),
      );

      final after = (await incidents.getIncidentById(incident.id))!;
      expect(after.observationId, isNull);
      expect(await pendingIncidents(), [incident.id]);
    },
  );

  test('editing an issue check-in leaves the link alone', () async {
    final observation = await issue();
    final incident = await linkedTo(observation);

    await observations.update(observation.copyWith(note: 'Serviced since'));

    final after = (await incidents.getIncidentById(incident.id))!;
    expect(after.observationId, observation.id);
    expect(await pendingIncidents(), isEmpty);
  });

  test('deleting the item keeps the report and clears both links', () async {
    final observation = await issue();
    final incident = await linkedTo(observation);

    await EquipmentRepository().deleteEquipment(reg.id);

    final after = (await incidents.getIncidentById(incident.id))!;
    expect(after.equipmentId, isNull);
    expect(after.observationId, isNull);
    expect(await pendingIncidents(), [incident.id]);
  });

  test('deleting the dive keeps the link', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final observation = await issue(diveId: 'd1');
    final incident = await linkedTo(observation);

    await DiveRepository().deleteDive('d1');

    final after = (await incidents.getIncidentById(incident.id))!;
    expect(after.observationId, observation.id);
  });

  test('deleting the report leaves the check-in', () async {
    final observation = await issue();
    final incident = await linkedTo(observation);

    await incidents.deleteIncident(incident.id);

    expect(await observations.getById(observation.id), isNotNull);
  });

  test('getIncidentsForEquipment carries the link', () async {
    final observation = await issue();
    final incident = await linkedTo(observation);

    final read = await incidents.getIncidentsForEquipment(reg.id);
    expect(read.single.id, incident.id);
    expect(read.single.observationId, observation.id);
  });
}
