import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' hide Incident;
import 'package:submersion/features/safety/data/repositories/incident_repository.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/safety/domain/entities/incident_changes.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late IncidentRepository repo;
  final when = DateTime.utc(2026, 7, 15, 10);

  setUp(() async {
    db = await setUpTestDatabase();
    repo = IncidentRepository();
  });

  tearDown(() => tearDownTestDatabase());

  Future<void> insertDiver(String id) async {
    final now = when.millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value(id),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertDive(String id) async {
    final now = when.millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  test('create, read, update, delete round-trip with tombstone', () async {
    final created = await repo.createIncident(
      occurredAt: when,
      category: IncidentCategory.gasSupply,
      severity: IncidentSeverity.moderate,
      narrative: 'Free-flow at 18 m; switched to buddy octo and ascended.',
      lessonsLearned: 'Service the regulator before cold-water trips.',
    );

    final listed = await repo.getIncidents();
    expect(listed, hasLength(1));
    expect(listed.single.category, IncidentCategory.gasSupply);
    // occurredAt round-trips as a timezone-stable wall-clock UTC value, so the
    // calendar day is identical on every synced device.
    expect(listed.single.occurredAt, when);
    expect(listed.single.occurredAt.isUtc, isTrue);

    await repo.applyIncidentChanges(
      created.id,
      const IncidentChanges(severity: IncidentSeverity.serious),
    );
    expect(
      (await repo.getIncidentById(created.id))!.severity,
      IncidentSeverity.serious,
    );

    await repo.deleteIncident(created.id);
    expect(await repo.getIncidents(), isEmpty);
    final tombstones = await db.select(db.deletionLog).get();
    expect(tombstones.map((t) => t.entityType), contains('incidents'));
  });

  test(
    'getIncidents(diverId:) scopes to that diver and unowned rows',
    () async {
      await insertDiver('diver-1');
      await insertDiver('diver-2');
      // One owned by diver-1, one owned by diver-2, one unowned (diverId null).
      await repo.createIncident(
        occurredAt: when,
        category: IncidentCategory.gasSupply,
        severity: IncidentSeverity.minor,
        narrative: 'Owned by diver-1.',
        diverId: 'diver-1',
      );
      await repo.createIncident(
        occurredAt: when,
        category: IncidentCategory.equipment,
        severity: IncidentSeverity.minor,
        narrative: 'Owned by diver-2.',
        diverId: 'diver-2',
      );
      await repo.createIncident(
        occurredAt: when,
        category: IncidentCategory.other,
        severity: IncidentSeverity.minor,
        narrative: 'Unowned (legacy).',
      );

      final forDiver1 = await repo.getIncidents(diverId: 'diver-1');
      // diver-1's own row plus the unowned row, never diver-2's.
      expect(
        forDiver1.map((i) => i.narrative),
        containsAll(<String>['Owned by diver-1.', 'Unowned (legacy).']),
      );
      expect(
        forDiver1.map((i) => i.narrative),
        isNot(contains('Owned by diver-2.')),
      );
    },
  );

  test('watchChanges emits when the incidents table changes', () async {
    final emissions = repo.watchChanges();
    final firstEmit = emissions.first;

    await repo.createIncident(
      occurredAt: when,
      category: IncidentCategory.planning,
      severity: IncidentSeverity.minor,
      narrative: 'Triggers a table update.',
    );

    // Completes only if the insert drove an emission on the change stream.
    await firstEmit;
  });

  test('dive link survives dive deletion (severed, not cascaded)', () async {
    await insertDive('dive-1');
    final incident = await repo.createIncident(
      occurredAt: when,
      category: IncidentCategory.buoyancy,
      severity: IncidentSeverity.minor,
      narrative: 'Runaway ascent from 5 m caught by buddy.',
      diveId: 'dive-1',
    );
    expect(await repo.getIncidentsForDive('dive-1'), hasLength(1));

    await (db.delete(db.dives)..where((t) => t.id.equals('dive-1'))).go();

    final survived = await repo.getIncidentById(incident.id);
    expect(survived, isNotNull);
    expect(survived!.diveId, isNull);
  });

  group('equipment link (condition phase 3a)', () {
    Future<void> insertEquipment(String id) => db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: 'regulator',
            createdAt: 1,
            updatedAt: 1,
          ),
        );

    test('create stores the item, reads back and lists by item', () async {
      await insertEquipment('reg');
      final created = await repo.createIncident(
        occurredAt: when,
        category: IncidentCategory.equipment,
        severity: IncidentSeverity.moderate,
        narrative: 'Free flow',
        equipmentId: 'reg',
      );
      expect(created.equipmentId, 'reg');
      expect((await repo.getIncidentById(created.id))!.equipmentId, 'reg');
      expect((await repo.getIncidentsForEquipment('reg')).map((i) => i.id), [
        created.id,
      ]);
      expect(await repo.getIncidentsForEquipment('other'), isEmpty);
    });

    test('update can clear the item', () async {
      await insertEquipment('reg');
      final created = await repo.createIncident(
        occurredAt: when,
        category: IncidentCategory.equipment,
        severity: IncidentSeverity.minor,
        narrative: 'n',
        equipmentId: 'reg',
      );
      await repo.applyIncidentChanges(
        created.id,
        const IncidentChanges(equipmentId: (value: null)),
      );
      expect((await repo.getIncidentById(created.id))!.equipmentId, isNull);
    });

    test('deleting the item leaves the incident with no item', () async {
      await insertEquipment('reg');
      final created = await repo.createIncident(
        occurredAt: when,
        category: IncidentCategory.equipment,
        severity: IncidentSeverity.minor,
        narrative: 'n',
        equipmentId: 'reg',
      );
      await (db.delete(db.equipment)..where((t) => t.id.equals('reg'))).go();
      final stored = await repo.getIncidentById(created.id);
      expect(stored, isNotNull);
      expect(stored!.equipmentId, isNull);
    });
  });

  group('the editor\'s writes (issue #4527, phase 4)', () {
    final changeLog = ChangeLogRepository();

    Future<Incident> stored() => repo.createIncident(
      occurredAt: when,
      category: IncidentCategory.gasSupply,
      severity: IncidentSeverity.moderate,
      narrative: 'Free-flow at 18 m.',
      contributingFactors: 'Cold water.',
      lessonsLearned: 'Service the reg.',
    );

    test('createIncident writes the report under the id it is given', () async {
      final created = await repo.createIncident(
        id: 'given-id',
        occurredAt: when,
        category: IncidentCategory.other,
        severity: IncidentSeverity.minor,
        narrative: 'Lost my buddy.',
      );
      expect(created.id, 'given-id');
      expect(
        (await repo.getIncidentById('given-id'))!.narrative,
        'Lost my buddy.',
      );
    });

    test('applyIncidentChanges writes only the fields it is given', () async {
      final incident = await stored();
      final wrote = await repo.applyIncidentChanges(
        incident.id,
        const IncidentChanges(severity: IncidentSeverity.serious),
      );
      expect(wrote, isTrue);
      final back = (await repo.getIncidentById(incident.id))!;
      expect(back.severity, IncidentSeverity.serious);
      expect(back.category, IncidentCategory.gasSupply);
      expect(back.narrative, 'Free-flow at 18 m.');
      expect(back.lessonsLearned, 'Service the reg.');
      expect(back.occurredAt, when);
      expect(
        back.updatedAt.isAfter(incident.updatedAt) ||
            back.updatedAt == incident.updatedAt,
        isTrue,
      );
    });

    test('applyIncidentChanges can clear the item and the lessons', () async {
      await insertDiver('me');
      final incident = await stored();
      await repo.applyIncidentChanges(
        incident.id,
        const IncidentChanges(
          narrative: 'Free-flow at 20 m.',
          lessonsLearned: (value: null),
          equipmentId: (value: null),
        ),
      );
      final back = (await repo.getIncidentById(incident.id))!;
      expect(back.narrative, 'Free-flow at 20 m.');
      expect(back.lessonsLearned, isNull);
      expect(back.contributingFactors, 'Cold water.');
    });

    test('applyIncidentChanges writes the dive link', () async {
      await insertDive('d1');
      final incident = await stored();
      await repo.applyIncidentChanges(
        incident.id,
        const IncidentChanges(diveId: (value: 'd1')),
      );
      expect((await repo.getIncidentById(incident.id))!.diveId, 'd1');
    });

    test(
      'applyIncidentChanges on a report that is gone writes nothing',
      () async {
        final incident = await stored();
        await repo.deleteIncident(incident.id);
        final wrote = await repo.applyIncidentChanges(
          incident.id,
          const IncidentChanges(severity: IncidentSeverity.serious),
        );
        expect(wrote, isFalse);
        expect(await repo.getIncidentById(incident.id), isNull);
      },
    );

    test('deleteIncident is one operation labelled deleted record', () async {
      final incident = await stored();
      await changeLog.settleAll();
      await db.customStatement('DELETE FROM change_log_operations');

      await repo.deleteIncident(incident.id);

      await changeLog.settleAll();
      final rows = await db
          .customSelect('SELECT label FROM change_log_operations')
          .get();
      expect(
        [for (final r in rows) r.read<String?>('label')],
        [ChangeLogLabels.deletedRecord],
      );
    });
  });
}
