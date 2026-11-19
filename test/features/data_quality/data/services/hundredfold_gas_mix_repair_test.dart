import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/features/change_log/data/services/change_log_settler.dart';
import 'package:submersion/features/data_quality/data/services/hundredfold_gas_mix_repair.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/global_test_defaults.dart';
import '../../../../helpers/test_database.dart';

/// Issue #4714: on launch, cylinder mixes older imports stored 100 times too
/// high are divided back, through writes every other device takes.
void main() {
  late AppDatabase db;
  late HundredfoldGasMixRepair repair;

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

  Future<Map<String, GasMix>> mixes() async => {
    for (final t in await db.select(db.diveTanks).get())
      t.id: GasMix(o2: t.o2Percent, he: t.hePercent),
  };

  setUp(() async {
    db = await setUpTestDatabase();
    // The repair queues a rescan of what it changed; keep it out of tests.
    QualityScanScheduler.enabled = false;
    repair = HundredfoldGasMixRepair();
    for (final id in ['d1', 'd2', 'd3']) {
      await dive(id);
    }
  });
  tearDown(() {
    applyGlobalTestDefaults();
    return tearDownTestDatabase();
  });

  test('divides every mix dividing explains, and only those', () async {
    await tank('ean32', 'd1', 3200);
    await tank('trimix', 'd1', 2100, 3500);
    await tank('air', 'd2', 2100);
    await tank('fine', 'd2', 50);
    await tank('overfull', 'd3', 60, 50);
    await tank('tooLittle', 'd3', 150);

    final changed = await repair.rescaleAll();

    expect(changed, {'d1', 'd2'});
    expect(await mixes(), {
      'ean32': const GasMix(o2: 32),
      'trimix': const GasMix(o2: 21, he: 35),
      'air': const GasMix(),
      'fine': const GasMix(o2: 50),
      // Left for the impossible gas mix finding: dividing explains neither.
      'overfull': const GasMix(o2: 60, he: 50),
      'tooLittle': const GasMix(o2: 150),
    });
  });

  test('a second launch finds nothing to do', () async {
    await tank('ean32', 'd1', 3200);
    await repair.rescaleAll();

    expect(await repair.rescaleAll(), isEmpty);
    expect((await mixes())['ean32'], const GasMix(o2: 32));
  });

  test('a logbook with no impossible mix is left alone', () async {
    await tank('ean32', 'd1', 32);

    expect(await repair.rescaleAll(), isEmpty);
    final dives = await db.select(db.dives).get();
    expect(dives.every((d) => d.updatedAt == 1), isTrue);
  });

  test('files the repair as one automatic quality repair', () async {
    await insertDiver(db, 'diver');
    await tank('ean32', 'd1', 3200);
    await tank('air', 'd2', 2100);
    await ChangeLogSettler(db).settle();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');

    await repair.rescaleAll();

    await ChangeLogSettler(db).settle();
    final operation = (await db.select(db.changeLogOperations).get()).single;
    expect(operation.source, ChangeLogSource.automatic.name);
    expect(operation.label, ChangeLogLabels.qualityRepair);
  });
}
