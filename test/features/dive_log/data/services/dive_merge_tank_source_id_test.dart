import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_uncombine_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// Issue #2716: the data source a tank row came from survives combining two
/// sequential file imports that name no computer, undoing that, and
/// separating the combined dive again. Foreign keys stay ON, so a source
/// restored after the tank that names it fails.
void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late DiveMergeService merge;
  late DiveUncombineService uncombine;

  /// A file import as the importer leaves it: the dive and its tank first,
  /// then the source row, which claims the tank.
  Future<void> seedImport(String id, DateTime entry, double o2) async {
    await diveRepo.createDive(
      domain.Dive(
        id: id,
        diverId: null,
        dateTime: entry,
        entryTime: entry,
        runtime: const Duration(minutes: 30),
        maxDepth: 12,
        tanks: [
          domain.DiveTank(
            id: 'tank-$id',
            volume: 11.1,
            gasMix: domain.GasMix(o2: o2),
          ),
        ],
        profile: const [
          domain.DiveProfilePoint(timestamp: 0, depth: 0),
          domain.DiveProfilePoint(timestamp: 900, depth: 12),
          domain.DiveProfilePoint(timestamp: 1800, depth: 0),
        ],
      ),
    );
    await diveRepo.saveComputerReading(
      DiveDataSourcesCompanion.insert(
        id: 'src-$id',
        diveId: id,
        importedAt: DateTime.utc(2026, 7, 1),
        createdAt: DateTime.utc(2026, 7, 1),
      ).copyWith(
        isPrimary: const Value(true),
        sourceFileName: Value('$id.csv'),
      ),
    );
  }

  /// Each tank of [diveId] by its gas, with the file its source came from.
  Future<Map<double, String?>> tankFiles(String diveId) async {
    final sources = {
      for (final s in await (db.select(
        db.diveDataSources,
      )..where((s) => s.diveId.equals(diveId))).get())
        s.id: s.sourceFileName,
    };
    return {
      for (final t in await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals(diveId))).get())
        t.o2Percent: sources[t.sourceId],
    };
  }

  setUp(() async {
    db = await setUpTestDatabase();
    diveRepo = DiveRepository();
    merge = DiveMergeService(diveRepo);
    uncombine = DiveUncombineService(diveRepo);
    await seedImport('a', DateTime.utc(2026, 7, 1, 9), 32);
    await seedImport('b', DateTime.utc(2026, 7, 1, 10), 50);
  });

  tearDown(tearDownTestDatabase);

  test('the imports claim their own tanks', () async {
    expect(await tankFiles('a'), {32.0: 'a.csv'});
    expect(await tankFiles('b'), {50.0: 'b.csv'});
  });

  test('combining keeps each tank on its own file\'s source', () async {
    final mergedId = (await merge.apply(['a', 'b'])).mergedDive.id;
    expect(await tankFiles(mergedId), {32.0: 'a.csv', 50.0: 'b.csv'});
  });

  test('undoing the combine restores each tank\'s source', () async {
    final outcome = await merge.apply(['a', 'b']);
    await merge.undo(outcome.snapshot);
    expect(await tankFiles('a'), {32.0: 'a.csv'});
    expect(await tankFiles('b'), {50.0: 'b.csv'});
  });

  test('separating hands the restored tank its dive\'s source', () async {
    // A pressure series is what makes separating take a tank along.
    for (final id in ['a', 'b']) {
      await TankPressureSeriesRepository().insertSeries(
        diveId: id,
        tankId: 'tank-$id',
        sourceId: 'src-$id',
        samples: const [TankPressureSample(timestamp: 60, pressure: 180)],
        now: 0,
      );
    }
    final mergedId = (await merge.apply(['a', 'b'])).mergedDive.id;
    final restored = await uncombine.separate(diveId: mergedId);

    // The later segment's dive: its tank on its own file's source.
    expect(await tankFiles(restored.single), {50.0: 'b.csv'});
    // The kept dive: the first file's tank keeps its source; the other
    // file's tank, left behind, let go of a source that left.
    expect(await tankFiles(mergedId), {32.0: 'a.csv', 50.0: null});
  });
}
