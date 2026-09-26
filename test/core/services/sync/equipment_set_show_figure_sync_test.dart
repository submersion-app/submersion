import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// A set record from a peer on a build before v229 has no `showFigure` key.
/// Both receive paths fill it with the column's default (off) before
/// `fromJson` runs, so such a record applies instead of being rejected.
void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipmentSets)
        .insert(
          EquipmentSetsCompanion.insert(
            id: 's1',
            name: 'Reef set',
            showFigure: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Map<String, dynamic>> olderPeerRecord() async {
    final exported = await serializer.fetchRecord('equipmentSets', 's1');
    expect(exported, isNotNull);
    expect(exported!['showFigure'], isTrue);
    return Map<String, dynamic>.from(exported)..remove('showFigure');
  }

  Future<bool> storedShowFigure() async => (await (db.select(
    db.equipmentSets,
  )..where((t) => t.id.equals('s1'))).getSingle()).showFigure;

  test('a single older record applies with the figure off', () async {
    await serializer.upsertRecord('equipmentSets', await olderPeerRecord());
    expect(await storedShowFigure(), isFalse);
  });

  test('a batch of older records applies with the figure off', () async {
    await serializer.upsertRecords('equipmentSets', [await olderPeerRecord()]);
    expect(await storedShowFigure(), isFalse);
  });
}
