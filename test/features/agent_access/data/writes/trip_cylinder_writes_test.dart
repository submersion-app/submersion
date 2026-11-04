import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// A trip's cylinder board and its ledger, as the board, the fill sheet and
/// the adjust sheet keep them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  late String tripId;
  const t = kSeedTime;

  Future<String> cylinder(Map<String, Object?> more) async => (await h.run([
    createOp('trip_cylinders', {'trip_id': tripId, 'label': 'AL80', ...more}),
  ])).created.single.id;

  Map<String, Object?> fill(String slot, Map<String, Object?> more) => {
    'trip_cylinder_id': slot,
    'kind': 'fill',
    'pressure_bar': 200.0,
    ...more,
  };

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    tripId = (await h.run([
      createOp('trips', {
        'name': 'Trip',
        'start_date': '2024-03-10',
        'end_date': '2024-03-12',
      }),
    ])).created.single.id;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'own',
            name: 'My AL80',
            type: 'tank',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
  });
  tearDown(() => tearDownTestDatabase());

  test('a cylinder is added, edited, moved and removed', () async {
    final first = await cylinder({'volume_l': 11.1});
    final second = await cylinder({'label': 'HP100'});
    expect((await h.one('trip_cylinders', first))!['volume_l'], 11.1);

    await h.run([
      updateOp('trip_cylinders', second, {'sort_order': 0}),
    ]);
    expect((await h.one('trip_cylinders', second))!['sort_order'], 0);

    await h.run(
      [
        fill(first, {}),
      ].map((f) => createOp('trip_cylinder_events', f)).toList(),
    );
    final plan = await h.preview([deleteOp('trip_cylinders', first)]);
    expect(plan.items.single.reach.parts['trip_cylinder_events'], 1);
    await h.apply(plan);
    expect(await h.one('trip_cylinders', first), isNull);
  });

  test(
    'a fill writes percent from fractions and reads back unchanged',
    () async {
      final slot = await cylinder({});
      final id = (await h.run([
        createOp(
          'trip_cylinder_events',
          fill(slot, {
            'o2_fraction': 0.32,
            'occurred_time': '2024-03-10T08:00:00Z',
          }),
        ),
      ])).created.single.id;
      final doc = (await h.one('trip_cylinder_events', id))!;
      expect(doc['o2_fraction'], 0.32);
      expect(doc['he_fraction'], 0.0);

      final again = await h.preview([
        updateOp('trip_cylinder_events', id, {
          'o2_fraction': doc['o2_fraction'],
          'pressure_bar': doc['pressure_bar'],
        }),
      ]);
      expect(again.unchanged.single.id, id);
    },
  );

  test('the fill sheet\'s limits are kept', () async {
    final slot = await cylinder({});

    final plan = await h.preview([
      createOp('trip_cylinder_events', fill(slot, {'pressure_bar': 0.5})),
      createOp(
        'trip_cylinder_events',
        fill(slot, {'analyzed_he_fraction': 0.2}),
      ),
      createOp(
        'trip_cylinder_events',
        fill(slot, {'o2_fraction': 0.5, 'he_fraction': 0.6}),
      ),
      createOp('trip_cylinder_events', fill(slot, {'currency': 'EUR'})),
    ]);

    for (final item in plan.items) {
      expect(item.block, isNotNull, reason: '${item.values}');
    }
  });

  test('a fill on an own cylinder lists its passport copy', () async {
    final slot = await cylinder({'equipment_id': 'own'});

    final plan = await h.preview([
      createOp('trip_cylinder_events', fill(slot, {})),
    ]);
    expect(plan.items.single.alsoCreates['cylinder_fills'], 1);
    await h.apply(plan);

    expect(await db.select(db.cylinderFills).get(), hasLength(1));
  });

  // TripFillPassportCopier.afterSave rewrites the copy on every save, and
  // writes one (minting the tank's passport id) when there is none yet.
  test('a fill edit lists the passport copy it rewrites or adds', () async {
    final slot = await cylinder({'equipment_id': 'own'});
    final copied = (await h.run([
      createOp('trip_cylinder_events', fill(slot, {})),
    ])).created.single.id;

    final rewrite = await h.preview([
      updateOp('trip_cylinder_events', copied, {'pressure_bar': 210.0}),
    ]);
    expect(rewrite.items.single.alsoChanges, {'cylinder_fills': 1});

    await db.delete(db.cylinderFills).go();
    final add = await h.preview([
      updateOp('trip_cylinder_events', copied, {'pressure_bar': 205.0}),
    ]);
    expect(add.items.single.alsoCreates, {'cylinder_fills': 1});
    await h.apply(add);
    expect(await db.select(db.cylinderFills).get(), hasLength(1));
  });

  // The fill sheet's currency picker stores three upper-case letters.
  test('a fill currency is listed as stored, three letters', () async {
    final slot = await cylinder({});

    final plan = await h.preview([
      createOp(
        'trip_cylinder_events',
        fill(slot, {'cost': 12.0, 'currency': 'eur'}),
      ),
    ]);
    expect(plan.items.single.fields['currency']!.newValue, 'EUR');
    final bad = await h.preview([
      createOp(
        'trip_cylinder_events',
        fill(slot, {'cost': 12.0, 'currency': '1@x'}),
      ),
    ]);
    expect(bad.items.single.block!.reason, BlockReason.invalidValue);
  });

  test('an owned tank already on the board is refused', () async {
    await cylinder({'equipment_id': 'own'});

    final plan = await h.preview([
      createOp('trip_cylinders', {
        'trip_id': tripId,
        'label': 'Again',
        'equipment_id': 'own',
      }),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.duplicateRecord);
  });

  test('an adjustment needs no mix, but helium needs oxygen', () async {
    final slot = await cylinder({});

    final plan = await h.preview([
      createOp('trip_cylinder_events', {
        'trip_cylinder_id': slot,
        'kind': 'adjustment',
        'pressure_bar': 50.0,
      }),
      createOp('trip_cylinder_events', {
        'trip_cylinder_id': slot,
        'kind': 'adjustment',
        'he_fraction': 0.2,
      }),
    ]);

    expect(plan.items.first.block, isNull);
    expect(plan.items.last.block!.reason, BlockReason.invalidValue);
  });
}
