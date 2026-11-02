import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/storage/scratch_sweep.dart';
import 'package:submersion/features/media_store/data/media_cache_index_sweep.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late MediaCacheStore store;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('media_cache_index_sweep');
    store = MediaCacheStore(database: db, root: root);
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  /// One live entry and one whose file the OS has taken.
  Future<void> partlyPurge() async {
    Future<File> put(String key) async {
      final staged = await store.stagingFile();
      await staged.writeAsBytes([1], flush: true);
      return store.put(key, MediaCacheKind.thumb, staged);
    }

    await put('aa'.padRight(64, '0'));
    await (await put('bb'.padRight(64, '0'))).delete();
  }

  Future<int> rows() async =>
      (await db.select(db.mediaCacheEntries).get()).length;

  MediaCacheIndexSweep sweep({bool osManagesCaches = true}) =>
      MediaCacheIndexSweep(
        osManagesCaches: () async => osManagesCaches,
        store: () async => store,
      );

  test('drops dead rows and reports nothing reclaimed', () async {
    await partlyPurge();

    final report = await sweep().run(dryRun: false);

    expect(await rows(), 1);
    expect(report.filesDeleted, ScratchSweepReport.empty.filesDeleted);
    expect(report.bytesReclaimed, 0);
  });

  test('a dry run changes nothing and opens no store', () async {
    await partlyPurge();

    final report = await MediaCacheIndexSweep(
      osManagesCaches: () async => true,
      store: () async => fail('a measurement must not open the store'),
    ).run(dryRun: true);

    expect(await rows(), 2);
    expect(report.isEmpty, isTrue);
  });

  test('does nothing where the OS does not manage the caches', () async {
    await partlyPurge();

    final report = await MediaCacheIndexSweep(
      osManagesCaches: () async => false,
      store: () async => fail('desktop must gain no work'),
    ).run(dryRun: false);

    expect(await rows(), 2);
    expect(report.isEmpty, isTrue);
  });

  test('a failure reaches the caller so the coordinator retries', () async {
    final failing = MediaCacheIndexSweep(
      osManagesCaches: () async => true,
      store: () async => throw StateError('no cache database'),
    );

    await expectLater(failing.run(dryRun: false), throwsStateError);
  });
}
