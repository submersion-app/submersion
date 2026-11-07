import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';

import '../../../../helpers/test_database.dart';
import 'child_write_harness.dart';

class _ReadOnlyStamper extends LibraryEditStamper {
  @override
  Future<bool> mayEdit(String siteId, {String? actingDiverId}) async => false;
}

/// The features a diver places on a site: a wreck, a mooring, an exit.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Future<String> make(String entity, Map<String, Object?> values) async =>
      (await h.run([createOp(entity, values)])).created.single.id;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('a feature is added, edited and removed', () async {
    final site = await make('sites', {'name': 'Reef'});
    final plan = await h.preview([
      createOp('site_features', {
        'site_id': site,
        'latitude': 27.1,
        'longitude': 33.9,
        'name': ' Bow ',
        'bearing_deg': 370,
      }),
    ]);
    final fields = plan.items.single.fields;
    expect(fields['type']!.newValue, 'wreck');
    expect(fields['bearing_deg']!.newValue, 10);
    final id = (await h.apply(plan)).created.single.id;
    final feature = (await h.one('site_features', id))!;
    expect([feature['name'], feature['bearing_deg']], ['Bow', 10.0]);

    await h.run([
      updateOp('site_features', id, {'depth_m': 18.5, 'type': 'mooring'}),
    ]);
    final edited = (await h.one('site_features', id))!;
    expect([edited['depth_m'], edited['type']], [18.5, 'mooring']);
    final moved = await h.preview([
      updateOp('site_features', id, {'latitude': 1.0}),
    ]);
    expect(moved.items.single.block!.reason, BlockReason.notPermitted);

    await h.run([deleteOp('site_features', id)]);
    expect(await h.one('site_features', id), isNull);
  });

  test('a feature on a site the owner may not edit is refused', () async {
    final site = await make('sites', {'name': 'Library reef'});
    final feature = await make('site_features', {
      'site_id': site,
      'latitude': 1.0,
      'longitude': 2.0,
    });
    final readOnly = ChildWriteHarness(
      db,
      catalog: (repos) => WriteCatalog(repos, stamper: _ReadOnlyStamper()),
    );

    final plan = await readOnly.preview([
      createOp('site_features', {
        'site_id': site,
        'latitude': 1.0,
        'longitude': 2.0,
      }),
      updateOp('site_features', feature, {'name': 'Bow'}),
    ]);
    final drop = await readOnly.preview([deleteOp('site_features', feature)]);

    for (final item in [...plan.items, ...drop.items]) {
      expect(item.block!.reason, BlockReason.notPermitted);
    }
  });
}
