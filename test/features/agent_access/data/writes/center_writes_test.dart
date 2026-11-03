import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Dive centers and the notes a diver keeps on their rental gear, as the
/// center pages keep them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Future<String> center(Map<String, Object?> fields) async =>
      (await h.run([createOp('centers', fields)])).created.single.id;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('a center is created, edited and deleted, and its dives only lose the '
      'link', () async {
    final id = await center({
      'name': 'Reef Divers',
      'city': 'Dahab',
      'affiliations': ['PADI', 'SSI'],
      'fill_opens_at_min': 480,
      'fill_closes_at_min': 1080,
    });
    await (db.update(db.dives)..where((d) => d.id.equals('d1'))).write(
      DivesCompanion(diveCenterId: Value(id)),
    );

    await h.run([
      updateOp('centers', id, {
        'city': null,
        'affiliations': ['SSI'],
        'is_permanently_closed': true,
      }),
    ]);
    final doc = (await h.one('centers', id))!;
    expect(doc['city'], isNull);
    expect(doc['affiliations'], ['SSI']);
    expect(doc['is_permanently_closed'], isTrue);
    expect(doc['fill_opens_at_min'], 480);

    final plan = await h.preview([deleteOp('centers', id)]);
    expect(plan.items.single.reach.linkedDives, {kDiverA: 1});
    await h.apply(plan);
    expect(await h.one('centers', id), isNull);
    expect((await h.one('dives', 'd1'))!['dive_center'], isNull);
    expect(await h.one('dives', 'd1'), isNotNull);
  });

  test('a center needs both coordinates or neither, and both fill hours or '
      'neither', () async {
    final plan = await h.preview([
      createOp('centers', {'name': 'Half placed', 'latitude': 27.5}),
      createOp('centers', {'name': 'Half open', 'fill_opens_at_min': 480}),
      createOp('centers', {
        'name': 'Whole',
        'latitude': 27.5,
        'longitude': 34.0,
      }),
    ]);

    expect(
      [for (final item in plan.items) item.block?.reason],
      [BlockReason.invalidValue, BlockReason.invalidValue, null],
    );
  });

  test(
    'a gear note belongs to its center and keeps when it was noted',
    () async {
      final centerId = await center({'name': 'Reef Divers'});

      final noteId = (await h.run([
        createOp('center_gear_notes', {
          'center_id': centerId,
          'gear_type': 'wetsuit',
          'size': 'L',
          'verdict': 'avoid',
          'note': 'Runs small',
          'dive_id': 'd1',
        }),
      ])).created.single.id;
      final noted = (await h.one('center_gear_notes', noteId))!['noted_at'];
      expect(noted, isNotNull);

      await h.run([
        updateOp('center_gear_notes', noteId, {'verdict': 'worked'}),
      ]);
      final doc = (await h.one('center_gear_notes', noteId))!;
      expect(doc['center_id'], centerId);
      expect(doc['verdict'], 'worked');
      expect(doc['size'], 'L');
      expect(doc['noted_at'], noted);

      final plan = await h.preview([deleteOp('centers', centerId)]);
      expect(plan.items.single.reach.parts, {'dive_center_gear_notes': 1});
    },
  );
}
