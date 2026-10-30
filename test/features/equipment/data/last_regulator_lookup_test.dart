import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  test('returns the regulator from the newest dive using the preset', () async {
    Future<void> dive(String id, int ms, String preset, String? reg) async {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: ms,
              createdAt: ms,
              updatedAt: ms,
            ),
          );
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(id: 't-$id', diveId: id).copyWith(
              presetName: Value(preset),
              regulatorEquipmentId: Value(reg),
            ),
          );
    }

    // The regulator ids are foreign keys, so the items must exist.
    for (final id in ['reg-a', 'reg-b', 'reg-c']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    await dive('old', 1000, 'al80', 'reg-a');
    await dive('new', 2000, 'al80', 'reg-b');
    await dive('newest-unset', 3000, 'al80', null);
    await dive('other', 4000, 'hp100', 'reg-c');

    final repo = EquipmentRepository();
    expect(await repo.getLastRegulatorsForPreset('al80'), ['reg-b']);
    expect(await repo.getLastRegulatorsForPreset('hp100'), ['reg-c']);
    expect(await repo.getLastRegulatorsForPreset('lp85'), isEmpty);
  });

  test('skips a regulator that has since left the kit (#3210)', () async {
    // Prefilling a new tank with gear retired or sold would put it back in
    // use; the newest pairing still in the kit wins instead.
    Future<void> reg(
      String id, {
      String status = 'active',
      bool active = true,
    }) => db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: 'regulator',
            createdAt: 1,
            updatedAt: 1,
          ).copyWith(status: Value(status), isActive: Value(active)),
        );
    Future<void> dive(String id, int ms, String r) async {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: ms,
              createdAt: ms,
              updatedAt: ms,
            ),
          );
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(id: 't-$id', diveId: id).copyWith(
              presetName: const Value('al80'),
              regulatorEquipmentId: Value(r),
            ),
          );
    }

    await reg('kept');
    await reg('retired', status: 'retired', active: false);
    await reg('sold', status: 'sold', active: false);
    await reg('legacy', active: false);
    await dive('a', 1000, 'kept');
    await dive('b', 2000, 'retired');
    await dive('c', 3000, 'sold');
    await dive('d', 4000, 'legacy');

    final repo = EquipmentRepository();
    expect(await repo.getLastRegulatorsForPreset('al80'), ['kept']);
  });

  group('every regulator on the tank (#3375)', () {
    Future<void> reg(String id, {String status = 'active'}) => db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: 'regulator',
            createdAt: 1,
            updatedAt: 1,
          ).copyWith(
            status: Value(status),
            isActive: Value(status == 'active'),
          ),
        );
    Future<void> dive(String id, int ms, String first, String? extras) async {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: ms,
              createdAt: ms,
              updatedAt: ms,
            ),
          );
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(id: 't-$id', diveId: id).copyWith(
              presetName: const Value('d12'),
              regulatorEquipmentId: Value(first),
              extraRegulatorIds: Value(extras),
            ),
          );
    }

    test('returns the first and the extras, in order', () async {
      await reg('r1');
      await reg('r2');
      await dive('a', 1000, 'r1', '["r2"]');
      expect(await EquipmentRepository().getLastRegulatorsForPreset('d12'), [
        'r1',
        'r2',
      ]);
    });

    test('drops a regulator that has left the kit', () async {
      await reg('r1');
      await reg('r2', status: 'retired');
      await dive('a', 1000, 'r1', '["r2"]');
      expect(await EquipmentRepository().getLastRegulatorsForPreset('d12'), [
        'r1',
      ]);
    });

    test('a tank whose regulators all left the kit falls back to an older '
        'one', () async {
      await reg('r1');
      await reg('r2', status: 'sold');
      await reg('r3', status: 'retired');
      await dive('old', 1000, 'r1', null);
      await dive('new', 2000, 'r2', '["r3"]');
      expect(await EquipmentRepository().getLastRegulatorsForPreset('d12'), [
        'r1',
      ]);
    });

    test('a tank with extras but no first regulator is still read', () async {
      // Normalised on every local write, but a synced row can arrive this
      // way; its extras are still the regulators on that cylinder.
      await reg('r1');
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'a',
              diveDateTime: 1000,
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(id: 't-a', diveId: 'a').copyWith(
              presetName: const Value('d12'),
              extraRegulatorIds: const Value('["r1"]'),
            ),
          );
      expect(await EquipmentRepository().getLastRegulatorsForPreset('d12'), [
        'r1',
      ]);
    });
  });
}
