import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/safety/data/repositories/incident_repository.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';

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

    await repo.updateIncident(
      created.copyWith(severity: IncidentSeverity.serious),
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
}
