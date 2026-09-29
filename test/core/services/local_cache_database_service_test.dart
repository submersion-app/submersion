import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';

import '../../helpers/fake_path_provider.dart';
import '../../helpers/temp_dir.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.supportPath);
  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

/// The local cache database runs on its own worker isolate, like the main
/// database, so the local cache sweep's deletes and VACUUM (and every large
/// grid write) never block the UI isolate (issue #1929).
void main() {
  late Directory support;
  final service = LocalCacheDatabaseService.instance;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('local_cache_service_');
    useFakePathProvider(_FakePathProvider(support.path));
    service.resetForTesting();
  });

  tearDown(() async {
    await service.close();
    service.resetForTesting();
    await deleteTempDir(support);
  });

  test('SQLite work runs off the calling isolate', () async {
    await service.initialize();
    final db = service.database;
    // Opens the database before timing, so migrations are not measured.
    await db.customSelect('SELECT 1').get();

    // A periodic timer cannot fire while this isolate is blocked inside a
    // synchronous SQLite call, so a blocked isolate sees exactly zero ticks
    // (it did, before the move to a worker). Any tick at all proves the query
    // ran somewhere else; how many a busy runner delivers is not the point.
    var ticks = 0;
    final timer = Timer.periodic(
      const Duration(milliseconds: 10),
      (_) => ticks++,
    );
    final stopwatch = Stopwatch()..start();
    await db
        .customSelect(
          'WITH RECURSIVE c(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM c '
          'WHERE x < 3000000) SELECT count(*) AS n FROM c',
        )
        .getSingle();
    stopwatch.stop();
    timer.cancel();

    expect(
      ticks,
      greaterThan(0),
      reason: 'a ${stopwatch.elapsedMilliseconds} ms query saw $ticks ticks',
    );
  });

  test(
    'keeps the rollback journal rather than the main database WAL',
    () async {
      // The local cache has one connection, so WAL buys nothing, and a VACUUM
      // under WAL would not shrink the file until a checkpoint.
      await service.initialize();

      final row = await service.database
          .customSelect('PRAGMA journal_mode')
          .getSingle();

      expect(row.read<String>('journal_mode'), 'delete');
    },
  );

  test('persists across a close and a fresh initialize', () async {
    await service.initialize();
    await service.database
        .into(service.database.decoClassificationCache)
        .insert(
          DecoClassificationCacheCompanion.insert(
            diveId: 'd1',
            hadDeco: true,
            inputsHash: 'h',
            computedAt: 0,
          ),
        );

    await service.close();
    expect(() => service.database, throwsStateError);
    await service.initialize();

    final rows = await service.database
        .select(service.database.decoClassificationCache)
        .get();
    expect(rows.map((r) => r.diveId), ['d1']);
    expect(
      File(
        p.join(support.path, 'Submersion', 'submersion_local.db'),
      ).existsSync(),
      isTrue,
    );
  });

  test('VACUUM shrinks the file through the worker', () async {
    await service.initialize();
    final db = service.database;
    final grid = 'x' * 100000;
    await db.batch((b) {
      for (var i = 0; i < 30; i++) {
        b.insert(
          db.bathymetryCache,
          BathymetryCacheCompanion.insert(
            cacheKey: 'k$i',
            centerLat: 0,
            centerLon: 0,
            status: 'ok',
            gridJson: Value(grid),
            fetchedAt: 0,
          ),
        );
      }
    });
    final file = File(
      p.join(support.path, 'Submersion', 'submersion_local.db'),
    );
    final before = await file.length();

    await db.delete(db.bathymetryCache).go();
    await db.customStatement('VACUUM');

    expect(await file.length(), lessThan(before ~/ 4));
  });

  test('close is a no-op before initialize', () async {
    await service.close();
    expect(() => service.database, throwsStateError);
  });

  test('setTestDatabase still injects an in-memory database', () async {
    final injected = LocalCacheDatabase(NativeDatabase.memory());
    service.setTestDatabase(injected);
    expect(service.database, same(injected));
    await injected.close();
    service.resetForTesting();
  });
}
