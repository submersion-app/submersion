import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// A set record from a peer on a build before v229 has no `showFigure` key.
/// Both receive paths fill the gap before `fromJson` runs, so such a record
/// applies instead of being rejected: from the set this device already holds
/// (#2553), or with the column's default (off) for a set new here.
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

  Future<void> forgetSet() =>
      (db.delete(db.equipmentSets)..where((t) => t.id.equals('s1'))).go();

  test('a single older record keeps the figure this device set', () async {
    await serializer.upsertRecord('equipmentSets', await olderPeerRecord());
    expect(await storedShowFigure(), isTrue);
  });

  test('a batch of older records keeps the figure this device set', () async {
    await serializer.upsertRecords('equipmentSets', [await olderPeerRecord()]);
    expect(await storedShowFigure(), isTrue);
  });

  test('a single older record new here applies with the figure off', () async {
    final record = await olderPeerRecord();
    await forgetSet();
    await serializer.upsertRecord('equipmentSets', record);
    expect(await storedShowFigure(), isFalse);
  });

  test(
    'a batch of older records new here applies with the figure off',
    () async {
      final record = await olderPeerRecord();
      await forgetSet();
      await serializer.upsertRecords('equipmentSets', [record]);
      expect(await storedShowFigure(), isFalse);
    },
  );
}
