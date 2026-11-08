import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// A site's types, and who a trip or a site is shared with or hidden from,
/// as the site and trip pages keep them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Future<String> make(String entity, Map<String, Object?> values) async =>
      (await h.run([createOp(entity, values)])).created.single.id;

  Map<String, Object?> relate(
    String entity,
    String id,
    String relation, {
    List<String> add = const [],
    List<String> remove = const [],
  }) => {
    ...updateOp(entity, id, {}),
    'relations': {
      relation: {'add': add, 'remove': remove},
    },
  };

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('a site\'s types are replaced', () async {
    final site = await make('sites', {'name': 'Reef'});
    await h.run([
      relate('sites', site, 'types', add: ['reef', 'wall']),
    ]);
    await h.run([
      relate('sites', site, 'types', add: ['wreck'], remove: ['reef']),
    ]);

    final rows = await (db.select(
      db.siteSiteTypes,
    )..where((t) => t.siteId.equals(site))).get();
    expect({for (final r in rows) r.siteTypeId}, {'wall', 'wreck'});
  });

  test('a trip is shared and a site hidden for a profile', () async {
    final trip = await make('trips', {
      'name': 'Trip',
      'start_date': '2024-03-10',
      'end_date': '2024-03-12',
    });
    final site = await make('sites', {'name': 'Reef'});

    await h.run([
      relate('trips', trip, 'shared_with', add: [kDiverB]),
      relate('sites', site, 'shared_with', add: [kDiverB]),
    ]);
    expect(
      await db
          .select(db.tripShares)
          .get()
          .then((s) => [for (final r in s) r.diverId]),
      [kDiverB],
    );

    await h.run([
      relate('sites', site, 'hidden_for', add: [kDiverB]),
    ]);
    final hides = await db.select(db.siteHides).get();
    expect([for (final r in hides) (r.siteId, r.diverId)], [(site, kDiverB)]);

    await h.run([
      relate('sites', site, 'hidden_for', remove: [kDiverB]),
    ]);
    expect(await db.select(db.siteHides).get(), isEmpty);
  });

  test('hiding an unshared site is refused', () async {
    final site = await make('sites', {'name': 'Reef'});

    final plan = await h.preview([
      relate('sites', site, 'hidden_for', add: [kDiverB]),
    ]);
    expect(plan.items.single.block!.reason, BlockReason.invalidValue);

    final own = await h.preview([
      relate('sites', site, 'shared_with', add: [kDiverA]),
    ]);
    expect(own.items.single.block!.reason, BlockReason.invalidValue);
  });

  // The site editor shares a site with everyone, or names profiles once
  // it is not; one op can do both, as a trip's can.
  test('a site is shared with everyone, then with one profile', () async {
    final site = await make('sites', {'name': 'Reef'});

    await h.run([
      updateOp('sites', site, {'is_shared': true}),
    ]);
    expect((await h.one('sites', site))!['is_shared'], true);

    final plan = await h.preview([
      {
        ...relate('sites', site, 'shared_with', add: [kDiverB]),
        'fields': {'is_shared': false},
      },
    ]);
    expect(plan.items.single.block, isNull);
    await h.apply(plan);

    expect((await h.one('sites', site))!['is_shared'], false);
    expect(
      await db
          .select(db.siteShares)
          .get()
          .then((s) => [for (final r in s) r.diverId]),
      [kDiverB],
    );
  });
}
