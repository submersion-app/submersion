import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Gear check-ins, as the check-in sheet keeps them: ok or an issue with
/// the item type's tags, an optional dive, and the findings refreshed after.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  late List<Set<String>> refreshed;
  const t = kSeedTime;

  Map<String, Object?> checkIn(Map<String, Object?> more) => {
    'equipment_id': 'reg',
    ...more,
  };

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    refreshed = [];
    h = ChildWriteHarness(
      db,
      catalog: (repositories) => WriteCatalog(
        repositories,
        refreshFindings: (ids) => refreshed.add(ids.toSet()),
      ),
    );
    await h.seed();
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'reg',
            name: 'Regulator',
            type: 'regulator',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
  });
  tearDown(() => tearDownTestDatabase());

  test('an observation is logged, edited and deleted', () async {
    final id = (await h.run([
      createOp(
        'equipment_observations',
        checkIn({
          'status': 'issue',
          'issue_tags': ['freeFlow'],
          'note': ' Second stage ',
        }),
      ),
    ])).created.single.id;
    final doc = (await h.one('equipment_observations', id))!;
    expect(doc['issue_tags'], ['freeFlow']);
    expect(doc['note'], 'Second stage');
    expect(doc['diver_id'], kDiverA);

    await h.run([
      updateOp('equipment_observations', id, {
        'status': 'ok',
        'issue_tags': <String>[],
      }),
    ]);
    expect((await h.one('equipment_observations', id))!['status'], 'ok');

    await h.run([deleteOp('equipment_observations', id)]);
    expect(await h.one('equipment_observations', id), isNull);
  });

  // The sheet offers only the item type's tags, and an issue needs one.
  test('an issue needs a tag of the item\'s type', () async {
    final plan = await h.preview([
      createOp('equipment_observations', checkIn({'status': 'issue'})),
      createOp(
        'equipment_observations',
        checkIn({
          'status': 'issue',
          'issue_tags': ['leakNeck'],
        }),
      ),
      createOp(
        'equipment_observations',
        checkIn({
          'status': 'ok',
          'issue_tags': ['freeFlow'],
        }),
      ),
    ]);

    for (final item in plan.items) {
      expect(item.block!.reason, BlockReason.invalidValue);
    }
  });

  test('observed_time defaults to the dive\'s end, listed', () async {
    final plan = await h.preview([
      createOp(
        'equipment_observations',
        checkIn({'status': 'ok', 'dive_id': 'd1'}),
      ),
    ]);

    final observed = plan.items.single.fields['observed_time']!;
    expect(observed.newValue, '2024-03-14T09:30:00.000Z');
    expect(observed.indirect, isTrue);
  });

  test('turning an issue to ok lists the incident it unlinks', () async {
    final id = (await h.run([
      createOp(
        'equipment_observations',
        checkIn({
          'status': 'issue',
          'issue_tags': ['leak'],
        }),
      ),
    ])).created.single.id;
    await db
        .into(db.incidents)
        .insert(
          IncidentsCompanion.insert(
            id: 'near-miss',
            occurredAt: t,
            category: 'equipment',
            severity: 'minor',
            narrative: 'Free flow at depth',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
            observationId: Value(id),
          ),
        );

    final plan = await h.preview([
      updateOp('equipment_observations', id, {
        'status': 'ok',
        'issue_tags': <String>[],
      }),
    ]);

    expect(plan.items.single.alsoChanges, {'incidents': 1});
  });

  test('the findings refresh runs once per item', () async {
    await h.run([
      createOp('equipment_observations', checkIn({'status': 'ok'})),
      createOp('equipment_observations', checkIn({'status': 'ok'})),
    ]);

    expect(refreshed, [
      {'reg'},
    ]);
  });
}
