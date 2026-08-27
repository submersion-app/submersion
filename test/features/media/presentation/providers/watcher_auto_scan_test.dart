import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/media_repair_log_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/watched_folder_repository.dart';
import 'package:submersion/features/media/data/services/repair/media_repair_service.dart';
import 'package:submersion/features/media/data/services/repair/watched_folder_scanner.dart';
import 'package:submersion/features/media/data/services/repair/watched_folder_walk.dart';
import 'package:submersion/features/media/presentation/providers/media_watcher_providers.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

import '../../../../helpers/test_database.dart';

const _emptyWalk = WatchedFolderWalkResult(
  changed: [],
  vanished: {},
  filesSeen: 0,
  listingComplete: true,
  hashBudgetExhausted: false,
);

void main() {
  late AppDatabase db;
  late LocalCacheDatabase cacheDb;
  late WatchedFolderRepository watched;
  late MediaRepairService repair;
  late Directory root;

  setUp(() async {
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    watched = WatchedFolderRepository(database: cacheDb);
    repair = MediaRepairService(
      repository: MediaRepository(),
      queue: MediaTransferQueueRepository(database: cacheDb),
      createBookmark: null,
      writeBookmark: null,
      log: MediaRepairLogRepository(),
    );
    root = await Directory.systemTemp.createTemp('watcher-auto-scan-test');
    expect(db, isNotNull);
  });

  tearDown(() async {
    await cacheDb.close();
    if (root.existsSync()) await root.delete(recursive: true);
    await tearDownTestDatabase();
  });

  /// A container wired to the in-memory databases, whose scanner delegates
  /// its walk to [walk] so no test touches a real tree.
  ProviderContainer containerWith(WatchedFolderWalk walk) {
    final container = ProviderContainer(
      overrides: [
        watchedFolderRepositoryProvider.overrideWithValue(watched),
        watcherScannerProvider.overrideWithValue(
          WatchedFolderScanner(
            watched: watched,
            repair: repair,
            loadMissingRows: () async => const [],
            isAutoApplyEnabled: () async => false,
            walk: walk,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('constructing the provider starts nothing', () async {
    var walks = 0;
    final container = containerWith((_) async {
      walks++;
      return _emptyWalk;
    });
    await watched.addRoot(root.path);

    container.read(watcherAutoScanProvider);
    // The whole point of the reshape: reading the provider is not a trigger.
    // The old Provider<void> ran the scan from its own constructor, so the
    // only way to fire it was ref.watch from MediaSectionPage.build().
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(walks, 0);
  });

  test('run performs a pass when a root is due', () async {
    var walks = 0;
    final container = containerWith((_) async {
      walks++;
      return _emptyWalk;
    });
    await watched.addRoot(root.path);

    await container.read(watcherAutoScanProvider).run();

    expect(walks, 1);
  });

  test('no watched roots costs nothing', () async {
    var walks = 0;
    final container = containerWith((_) async {
      walks++;
      return _emptyWalk;
    });

    await container.read(watcherAutoScanProvider).run();

    expect(walks, 0);
  });

  test('the daily cadence holds a second pass off', () async {
    var walks = 0;
    final container = containerWith((_) async {
      walks++;
      return _emptyWalk;
    });
    await watched.addRoot(root.path);
    await watched.stampScanned(root.path, DateTime.now());

    await container.read(watcherAutoScanProvider).run();

    expect(walks, 0);
  });

  test('a second call joins the pass already running', () async {
    final gate = Completer<void>();
    var walks = 0;
    final container = containerWith((_) async {
      walks++;
      await gate.future;
      return _emptyWalk;
    });
    await watched.addRoot(root.path);

    final auto = container.read(watcherAutoScanProvider);
    final first = auto.run();
    final second = auto.run();
    // A remount -- a tab switch, a route pop -- calls again while the first
    // pass is still walking. Without the guard that is two concurrent walks
    // over the same tree, both writing the same index rows.
    expect(identical(first, second), isTrue);

    gate.complete();
    await Future.wait([first, second]);
    expect(walks, 1);
  });

  test('a finished pass can be run again', () async {
    var walks = 0;
    final container = containerWith((_) async {
      walks++;
      return _emptyWalk;
    });
    await watched.addRoot(root.path);

    final auto = container.read(watcherAutoScanProvider);
    await auto.run();
    // The daily stamp would hold the second pass off, so clear it: what is
    // under test is the guard releasing, not the cadence.
    await cacheDb.customStatement(
      'UPDATE watched_roots SET last_scan_at = NULL',
    );
    await auto.run();

    expect(walks, 2);
  });

  test('a failing pass is swallowed and does not wedge the guard', () async {
    var walks = 0;
    final container = containerWith((_) async {
      walks++;
      throw const FileSystemException('watched root exploded');
    });
    await watched.addRoot(root.path);

    final auto = container.read(watcherAutoScanProvider);
    // Completes normally: a scan problem must never break the section that
    // triggered it.
    await auto.run();
    await auto.run();

    // And a throw must not leave the guard latched shut for the life of the
    // app.
    expect(walks, 2);
  });

  test('kick does not surface the failure to its caller', () async {
    final container = containerWith(
      (_) async => throw const FileSystemException('watched root exploded'),
    );
    await watched.addRoot(root.path);

    container.read(watcherAutoScanProvider).kick();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  });
}
