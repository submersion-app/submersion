import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/data_quality/data/services/quality_context_builder.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';

import '../../../helpers/test_database.dart';

/// The scan context carries other profiles' dives that share gear with the
/// scanned one (issue #2853).
void main() {
  late AppDatabase db;
  final ten = DateTime.utc(2026, 5, 1, 10).millisecondsSinceEpoch;
  const minute = 60 * 1000;

  Future<void> addDiver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion.insert(id: id, name: id, createdAt: 1, updatedAt: 1),
      );

  Future<void> addItem(String id, {String? host, bool active = true}) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: 'Item $id',
          type: 'other',
          createdAt: 1,
          updatedAt: 1,
          diverId: const Value('bill'),
          parentEquipmentId: Value(host),
          isActive: Value(active),
        ),
      );

  Future<void> addDive(String id, String? diver, int entryMs) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: Value(diver),
          diveDateTime: entryMs,
          createdAt: 1,
          updatedAt: 1,
          entryTime: Value(entryMs),
          runtime: const Value(40 * 60),
        ),
      );

  Future<void> wear(String dive, String item) => db
      .into(db.diveEquipment)
      .insert(DiveEquipmentCompanion.insert(diveId: dive, equipmentId: item));

  Future<DiveQualityContext> contextFor(String diveId) async =>
      (await QualityContextBuilder().buildAll([diveId])).single;

  setUp(() async {
    db = await setUpTestDatabase();
    await addDiver('bill');
    await addDiver('anna');
    await addItem('light');
    await addDive('b1', 'bill', ten);
    await addDive('a1', 'anna', ten + 10 * minute);
    await wear('b1', 'light');
    await wear('a1', 'light');
  });

  tearDown(tearDownTestDatabase);

  test("another profile's overlapping dive with the same item", () async {
    final ctx = await contextFor('b1');
    final o = ctx.sharedGearOverlaps.single;
    expect(o.otherDiveId, 'a1');
    expect(o.otherDiverId, 'anna');
    expect(o.otherDiverName, 'anna');
    expect(o.thisDiverName, 'bill');
    expect(o.otherEntry, DateTime.utc(2026, 5, 1, 10, 10));
    expect(o.otherEntry.isUtc, isTrue);
    expect(o.otherExit, DateTime.utc(2026, 5, 1, 10, 50));
    final item = o.items.single;
    expect(item.equipmentId, 'light');
    expect(item.name, 'Item light');
    expect(item.thisLinkKinds, {'gearList'});
    expect(item.otherLinkKinds, {'gearList'});
  });

  test('a dive of the same profile is not included', () async {
    await addDive('b2', 'bill', ten + 5 * minute);
    await wear('b2', 'light');
    final ctx = await contextFor('b1');
    expect(ctx.sharedGearOverlaps.map((o) => o.otherDiveId), ['a1']);
  });

  test('a dive with no profile is never paired', () async {
    await addDive('n1', null, ten + 5 * minute);
    await wear('n1', 'light');
    expect(
      (await contextFor('b1')).sharedGearOverlaps.map((o) => o.otherDiveId),
      ['a1'],
    );
    expect((await contextFor('n1')).sharedGearOverlaps, isEmpty);
  });

  test('a dive outside the neighbour window is not included', () async {
    await addDive('a2', 'anna', ten + 3 * 24 * 60 * minute);
    await wear('a2', 'light');
    expect(
      (await contextFor('b1')).sharedGearOverlaps.map((o) => o.otherDiveId),
      ['a1'],
    );
  });

  test('installed parts and hosts travel with the item', () async {
    await addItem('reg');
    await addItem('hose', host: 'reg');
    await addItem('oldHose', host: 'reg', active: false);
    await wear('b1', 'reg');
    await wear('a1', 'reg');
    await wear('b1', 'hose');
    await wear('a1', 'hose');
    final items = {
      for (final i in (await contextFor('b1')).sharedGearOverlaps.single.items)
        i.equipmentId: i,
    };
    expect(items['reg']!.installedPartIds, ['hose']);
    expect(items['hose']!.hostIds, contains('reg'));
  });

  test('every way an item is on a dive is recorded', () async {
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 't1',
            diveId: 'b1',
            equipmentId: const Value('light'),
          ),
        );
    final item = (await contextFor('b1')).sharedGearOverlaps.single.items.single;
    expect(item.thisLinkKinds, {'gearList', 'tankCylinder'});
    expect(item.otherLinkKinds, {'gearList'});
  });

  test('a single-profile library loads nothing', () async {
    await (db.delete(db.dives)..where((d) => d.id.equals('a1'))).go();
    await (db.delete(db.divers)..where((d) => d.id.equals('anna'))).go();
    expect((await contextFor('b1')).sharedGearOverlaps, isEmpty);
  });
}
