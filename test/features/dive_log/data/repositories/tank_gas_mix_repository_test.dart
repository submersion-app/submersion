import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_gas_mix_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;

import '../../../../helpers/test_database.dart';

/// Issue #4714: cylinder mixes stored 100 times too high by older imports.
void main() {
  late AppDatabase db;
  late SyncRepository sync;
  late TankGasMixRepository repo;

  Future<void> dive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: 1,
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  Future<void> tank(String id, String diveId, double o2, [double he = 0]) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion.insert(
          id: id,
          diveId: diveId,
        ).copyWith(o2Percent: Value(o2), hePercent: Value(he)),
      );

  Future<DiveTank> row(String id) =>
      (db.select(db.diveTanks)..where((t) => t.id.equals(id))).getSingle();

  Future<Set<(String, String)>> pending() async => {
    for (final r in await sync.getPendingRecords()) (r.entityType, r.recordId),
  };

  setUp(() async {
    db = await setUpTestDatabase();
    sync = SyncRepository();
    repo = TankGasMixRepository();
    await dive('d1');
    await dive('d2');
  });

  tearDown(tearDownTestDatabase);

  test('lists the cylinders whose mix no gas can have', () async {
    await tank('ean32', 'd1', 32);
    await tank('stored', 'd1', 3200);
    await tank('trimix', 'd2', 2100, 3500);
    await tank('overfull', 'd2', 60, 50);
    await tank('negative', 'd2', -1);
    await tank('full', 'd2', 21, 79);

    final found = await repo.impossibleMixes();

    expect(
      {for (final m in found) m.tankId: (m.diveId, m.mix)},
      {
        'stored': ('d1', const GasMix(o2: 3200)),
        'trimix': ('d2', const GasMix(o2: 2100, he: 3500)),
        'overfull': ('d2', const GasMix(o2: 60, he: 50)),
        'negative': ('d2', const GasMix(o2: -1)),
      },
    );
  });

  test('an infinite share is past every bound', () async {
    // SQLite stores infinity, and NaN only as NULL, which the columns refuse.
    await tank('inf', 'd1', double.infinity);
    await tank('negInf', 'd2', 21, double.negativeInfinity);

    final found = await repo.impossibleMixes();

    expect({for (final m in found) m.tankId}, {'inf', 'negInf'});
    expect(await repo.divesWithImpossibleMixes(), {'d1', 'd2'});
  });

  test('names each dive holding such a cylinder once', () async {
    await tank('a', 'd1', 3200);
    await tank('b', 'd1', 2100, 3500);
    await tank('ok', 'd2', 32);

    expect(await repo.divesWithImpossibleMixes(), {'d1'});
  });

  test('reads one cylinder by its dive', () async {
    await tank('stored', 'd1', 3200);

    final found = await repo.tankMix(diveId: 'd1', tankId: 'stored');

    expect(found?.mix, const GasMix(o2: 3200));
    expect(await repo.tankMix(diveId: 'd2', tankId: 'stored'), isNull);
    expect(await repo.tankMix(diveId: 'd1', tankId: 'gone'), isNull);
  });

  test('writes each mix with a new clock, for every device', () async {
    await tank('a', 'd1', 3200);
    await tank('b', 'd1', 2100, 3500);
    await tank('c', 'd2', 5000);
    await tank('untouched', 'd2', 3200);
    final before = await row('a');

    await repo.setGasMixes([
      (diveId: 'd1', tankId: 'a', mix: const GasMix(o2: 32)),
      (diveId: 'd1', tankId: 'b', mix: const GasMix(o2: 21, he: 35)),
      (diveId: 'd2', tankId: 'c', mix: const GasMix(o2: 50)),
    ]);

    final a = await row('a');
    expect((a.o2Percent, a.hePercent), (32.0, 0.0));
    expect(a.hlc, isNotNull);
    expect(a.hlc, isNot(before.hlc));
    final b = await row('b');
    expect((b.o2Percent, b.hePercent), (21.0, 35.0));
    expect((await row('untouched')).o2Percent, 3200.0);
    // A cylinder's peers apply the write only with its clock moved, so each
    // row and each dive is marked, never only the dive (#1769).
    expect(await pending(), {
      ('diveTanks', 'a'),
      ('diveTanks', 'b'),
      ('diveTanks', 'c'),
      ('dives', 'd1'),
      ('dives', 'd2'),
    });
    final dives = await db.select(db.dives).get();
    expect(dives.every((d) => d.updatedAt > 1), isTrue);
  });

  test('writes a whole logbook of cylinders, past any batch size', () async {
    // The reported logbook held 841 such cylinders.
    const count = 1200;
    final mixes = [
      for (var i = 0; i < count; i++)
        (
          diveId: i.isEven ? 'd1' : 'd2',
          tankId: 't$i',
          mix: GasMix(o2: [21.0, 32.0, 36.0][i % 3]),
        ),
    ];
    for (final m in mixes) {
      await tank(m.tankId, m.diveId, m.mix.o2 * 100);
    }

    await repo.setGasMixes(mixes);

    final rows = {for (final t in await db.select(db.diveTanks).get()) t.id: t};
    for (final m in mixes) {
      expect(rows[m.tankId]!.o2Percent, m.mix.o2, reason: m.tankId);
      expect(rows[m.tankId]!.hlc, isNotNull, reason: m.tankId);
    }
    final marked = await pending();
    expect(marked.where((p) => p.$1 == 'diveTanks'), hasLength(count));
    expect(marked, containsAll({('dives', 'd1'), ('dives', 'd2')}));
  });

  test('an empty list writes nothing', () async {
    await tank('a', 'd1', 3200);

    await repo.setGasMixes(const []);

    expect(await pending(), isEmpty);
    expect((await row('a')).o2Percent, 3200.0);
  });
}
