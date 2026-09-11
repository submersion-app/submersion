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

/// A check-in's dive link and an incident's gear link are synced fields that
/// SQLite clears by itself (ON DELETE SET NULL) when the dive or the item is
/// deleted. That write moves no clock and stages nothing, so a peer keeps the
/// stale link and can carry it back. The delete paths clear and stage them.
void main() {
  late EquipmentItem reg;

  setUp(() async {
    await setUpTestDatabase();
    reg = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<List<String>> pending(String entityType) async {
    final db = DatabaseService.instance.database;
    final rows = await db.select(db.syncRecords).get();
    return [
      for (final r in rows)
        if (r.entityType == entityType && r.syncStatus == 'pending') r.recordId,
    ];
  }

  Future<EquipmentObservation> checkInOn(String diveId) async {
    final observation = await EquipmentObservationRepository().create(
      equipmentId: reg.id,
      diveId: diveId,
      observedAt: DateTime.utc(2026, 3, 1),
      status: ObservationStatus.ok,
      now: DateTime.utc(2026, 3, 1),
    );
    await SyncRepository().clearAllSyncRecords();
    return observation;
  }

  for (final bulk in [false, true]) {
    test('deleting a dive (${bulk ? 'bulk' : 'single'}) clears and stages '
        'its check-ins', () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );
      final observation = await checkInOn('d1');

      if (bulk) {
        await DiveRepository().bulkDeleteDives(['d1']);
      } else {
        await DiveRepository().deleteDive('d1');
      }

      final after = (await EquipmentObservationRepository().getForEquipment(
        reg.id,
      )).single;
      expect(after.diveId, isNull, reason: 'it stays, as a bench note');
      expect(after.updatedAt.isAfter(observation.updatedAt), isTrue);
      expect(await pending('equipmentObservations'), [observation.id]);
    });
  }

  test('deleting gear clears and stages the incidents that name it', () async {
    final incident = await IncidentRepository().createIncident(
      occurredAt: DateTime.utc(2026, 3, 1),
      category: IncidentCategory.equipment,
      severity: IncidentSeverity.minor,
      narrative: 'Free-flow at 18 m.',
      equipmentId: reg.id,
    );
    await SyncRepository().clearAllSyncRecords();

    await EquipmentRepository().deleteEquipment(reg.id);

    final after = (await IncidentRepository().getIncidentById(incident.id))!;
    expect(after.equipmentId, isNull, reason: 'the incident itself stays');
    expect(after.updatedAt.isAfter(incident.updatedAt), isTrue);
    expect(await pending('incidents'), [incident.id]);
  });
}
