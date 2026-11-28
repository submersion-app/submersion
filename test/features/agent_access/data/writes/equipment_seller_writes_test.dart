import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// An agent sees who sold a gear item and cannot break the link by
/// accident (issue #5140): the links are not agent-writable, an unrelated
/// edit keeps them, and a retailer the agent rewrites is a typed seller.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Future<String> created(Map<String, Object?> fields) async =>
      (await h.run([createOp('equipment', fields)])).created.single.id;

  Future<Map<String, Object?>> doc(String id) async =>
      (await h.one('equipment', id))!;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    await db.customStatement(
      'INSERT INTO buddies (id, diver_id, name, created_at, updated_at) '
      "VALUES ('anna', '$kDiverA', 'Anna Berg', 0, 0)",
    );
  });
  tearDown(() => tearDownTestDatabase());

  /// An item bought from Anna, as the Seller field saves it.
  Future<String> boughtFromAnna() async {
    final id = await created({
      'name': 'Apeks XTX50',
      'type': 'regulator',
      'attributes': [
        {'key': 'retailer', 'value_text': 'Anna Berg'},
      ],
    });
    await db.customStatement(
      "UPDATE equipment SET seller_buddy_id = 'anna' WHERE id = ?",
      [id],
    );
    return id;
  }

  test('the document names the seller links', () async {
    final id = await boughtFromAnna();
    final item = await doc(id);
    expect(item['seller_buddy_id'], 'anna');
    expect(item['seller_dive_center_id'], isNull);
  });

  test('an unrelated edit keeps the seller', () async {
    final id = await boughtFromAnna();
    await h.run([
      updateOp('equipment', id, {'notes': 'Serviced'}),
    ]);
    expect((await doc(id))['seller_buddy_id'], 'anna');
  });

  test('a rewritten retailer is a typed seller', () async {
    final id = await boughtFromAnna();
    await h.run([
      updateOp('equipment', id, {
        'attributes': [
          {'key': 'retailer', 'value_text': 'Lars Holm'},
        ],
      }),
    ]);
    final item = await doc(id);
    expect(item['seller_buddy_id'], isNull);
    expect(
      [
        for (final a in item['attributes']! as List)
          if ((a as Map)['key'] == 'retailer') a['value_text'],
      ],
      ['Lars Holm'],
    );
  });
}
