import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repair_log_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/watched_folder_repository.dart';
import 'package:submersion/features/media/data/services/repair/media_repair_service.dart';
import 'package:submersion/features/media/data/services/repair/watched_folder_scanner.dart';
import 'package:submersion/features/media/data/services/repair/watched_folder_walk.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('shouldAutoScan', () {
    final now = DateTime(2026, 6, 12, 12);

    test('runs when never scanned', () {
      expect(shouldAutoScan(lastScanAt: null, now: now), isTrue);
    });

    test('holds off inside the daily cadence', () {
      expect(
        shouldAutoScan(
          lastScanAt: now.subtract(const Duration(hours: 2)),
          now: now,
        ),
        isFalse,
      );
    });

    test('runs again after a day', () {
      expect(
        shouldAutoScan(
          lastScanAt: now.subtract(const Duration(days: 2)),
          now: now,
        ),
        isTrue,
      );
    });

    test('a bogus future stamp cannot suppress scanning forever', () {
      expect(
        shouldAutoScan(lastScanAt: now.add(const Duration(days: 3)), now: now),
        isTrue,
      );
    });
  });

  group('WatchedFolderScanner', () {
    late AppDatabase db;
    late LocalCacheDatabase cacheDb;
    late MediaRepository repo;
    late WatchedFolderRepository watched;
    late MediaRepairService repair;
    late Directory root;

    setUp(() async {
      db = await setUpTestDatabase();
      cacheDb = LocalCacheDatabase(NativeDatabase.memory());
      repo = MediaRepository();
      watched = WatchedFolderRepository(database: cacheDb);
      repair = MediaRepairService(
        repository: repo,
        queue: MediaTransferQueueRepository(database: cacheDb),
        createBookmark: null,
        writeBookmark: null,
        log: MediaRepairLogRepository(),
      );
      root = await Directory.systemTemp.createTemp('watcher-test');
      await watched.addRoot(root.path);
      expect(db, isNotNull);
    });

    tearDown(() async {
      await cacheDb.close();
      await root.delete(recursive: true);
      await tearDownTestDatabase();
    });

    Future<String> writeFile(String name, String contents) async {
      final file = File('${root.path}/$name');
      await file.writeAsString(contents);
      return (await sha256OfFile(file)).hash;
    }

    Future<void> seedMissing(String id, String contentHash) async {
      await repo.createMedia(
        MediaItem(
          id: id,
          mediaType: MediaType.photo,
          sourceType: MediaSourceType.localFile,
          filePath: '/gone/$id.jpg',
          localPath: '/gone/$id.jpg',
          originalFilename: '$id.jpg',
          isOrphaned: true,
          takenAt: DateTime(2026, 6, 1),
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 1),
        ),
      );
      await repo.stampContentIdentity(
        id,
        contentHash: contentHash,
        sizeBytes: 4,
      );
    }

    WatchedFolderScanner scanner({
      bool autoApply = true,
      List<MediaItem> Function()? missing,
    }) => WatchedFolderScanner(
      watched: watched,
      repair: repair,
      loadMissingRows: () async => missing?.call() ?? const [],
      isAutoApplyEnabled: () async => autoApply,
    );

    test('first scan indexes every file and hashes each once', () async {
      await writeFile('a.jpg', 'aaaa');
      await writeFile('b.jpg', 'bbbb');

      final report = await scanner().scan(now: DateTime(2026, 6, 12));

      expect(report.filesIndexed, 2);
      expect(report.rehashed, 2);
      final index = await watched.indexForRoot(root.path);
      expect(index.keys.toSet(), {'a.jpg', 'b.jpg'});
      expect(index['a.jpg']!.contentHash, isNotNull);
    });

    test('a second scan re-hashes only files whose stat changed', () async {
      await writeFile('a.jpg', 'aaaa');
      await writeFile('b.jpg', 'bbbb');
      await scanner().scan(now: DateTime(2026, 6, 12));

      await writeFile('b.jpg', 'bbbb-CHANGED-LENGTH');
      final second = await scanner().scan(now: DateTime(2026, 6, 13));

      expect(second.filesIndexed, 2);
      expect(second.rehashed, 1);
    });

    test('a vanished file is pruned from the index', () async {
      await writeFile('a.jpg', 'aaaa');
      await writeFile('gone.jpg', 'zzzz');
      await scanner().scan(now: DateTime(2026, 6, 12));

      await File('${root.path}/gone.jpg').delete();
      await scanner().scan(now: DateTime(2026, 6, 13));

      expect((await watched.indexForRoot(root.path)).keys, ['a.jpg']);
    });

    test('an exact hash match on a missing row is auto-applied', () async {
      final hash = await writeFile('a.jpg', 'aaaa');
      await seedMissing('m1', hash);
      final missing = (await repo.getMediaById('m1'))!;

      final report = await scanner(
        missing: () => [missing],
      ).scan(now: DateTime(2026, 6, 12));

      expect(report.autoRepaired, 1);
      final repaired = (await repo.getMediaById('m1'))!;
      expect(repaired.localPath, '${root.path}/a.jpg');
      expect(repaired.isOrphaned, isFalse);
    });

    test('a missing row with no hash match is left alone', () async {
      await writeFile('a.jpg', 'aaaa');
      await seedMissing('m1', 'HASH-OF-SOMETHING-ELSE');
      final missing = (await repo.getMediaById('m1'))!;

      final report = await scanner(
        missing: () => [missing],
      ).scan(now: DateTime(2026, 6, 12));

      expect(report.autoRepaired, 0);
      expect((await repo.getMediaById('m1'))!.localPath, '/gone/m1.jpg');
    });

    test('autoApply false indexes but repairs nothing', () async {
      final hash = await writeFile('a.jpg', 'aaaa');
      await seedMissing('m1', hash);
      final missing = (await repo.getMediaById('m1'))!;

      final report = await scanner(
        autoApply: false,
        missing: () => [missing],
      ).scan(now: DateTime(2026, 6, 12));

      expect(report.filesIndexed, 1);
      expect(report.autoRepaired, 0);
      expect((await repo.getMediaById('m1'))!.isOrphaned, isTrue);
    });

    test('scanning stamps the root so the cadence gate can hold off', () async {
      await writeFile('a.jpg', 'aaaa');
      await scanner().scan(now: DateTime(2026, 6, 12));
      expect(await watched.lastScanAt(root.path), DateTime(2026, 6, 12));
    });

    test('nested files index under a separator-relative path', () async {
      await Directory('${root.path}/2026/june').create(recursive: true);
      await writeFile('2026/june/a.jpg', 'aaaa');

      await scanner().scan(now: DateTime(2026, 6, 12));

      final index = await watched.indexForRoot(root.path);
      // The relative path must be relative -- a hand-rolled prefix strip
      // yields the whole absolute path on Windows, which then gets written
      // into media.local_path as a healthy pointer to nothing.
      expect(index.keys.single, p.join('2026', 'june', 'a.jpg'));
      expect(p.isRelative(index.keys.single), isTrue);
    });

    test('a root written with a trailing separator still indexes '
        'relatively', () async {
      final trailing = '${root.path}${p.separator}';
      await watched.removeRoot(root.path);
      await watched.addRoot(trailing);
      await writeFile('a.jpg', 'aaaa');

      await scanner().scan(now: DateTime(2026, 6, 12));

      expect((await watched.indexForRoot(trailing)).keys, ['a.jpg']);
    });

    test('an auto-applied repair points at the real file', () async {
      await Directory('${root.path}/2026').create(recursive: true);
      final hash = await writeFile('2026/a.jpg', 'aaaa');
      await seedMissing('m1', hash);
      final missing = (await repo.getMediaById('m1'))!;

      final report = await scanner(
        missing: () => [missing],
      ).scan(now: DateTime(2026, 6, 12));

      expect(report.autoRepaired, 1);
      final repaired = (await repo.getMediaById('m1'))!;
      expect(await File(repaired.localPath!).exists(), isTrue);
    });

    test('a file that vanishes between index and repair is skipped', () async {
      final hash = await writeFile('a.jpg', 'aaaa');
      await seedMissing('m1', hash);
      final missing = (await repo.getMediaById('m1'))!;
      // Index it, then delete the file WITHOUT re-scanning: the index still
      // claims the bytes are there.
      await scanner().scan(now: DateTime(2026, 6, 12));
      await File('${root.path}/a.jpg').delete();

      final report = await scanner(
        missing: () => [missing],
      ).scan(now: DateTime(2026, 6, 13));

      expect(report.autoRepaired, 0);
      // Still missing, and still pointing at its original path.
      final row = (await repo.getMediaById('m1'))!;
      expect(row.isOrphaned, isTrue);
      expect(row.localPath, '/gone/m1.jpg');
    });

    test('auto-apply is resolved when the scan runs, not at build', () async {
      final hash = await writeFile('a.jpg', 'aaaa');
      await seedMissing('m1', hash);
      final missing = (await repo.getMediaById('m1'))!;

      // A gate that only resolves after an await: a scanner that captured a
      // synchronous default would ignore it and repair anyway.
      var enabled = true;
      final built = WatchedFolderScanner(
        watched: watched,
        repair: repair,
        loadMissingRows: () async => [missing],
        isAutoApplyEnabled: () async {
          await Future<void>.delayed(Duration.zero);
          return enabled;
        },
      );
      enabled = false;

      final report = await built.scan(now: DateTime(2026, 6, 12));

      expect(report.autoRepaired, 0);
      expect((await repo.getMediaById('m1'))!.isOrphaned, isTrue);
    });

    test('an unreadable root does not prune the index it could not '
        'list', () async {
      await writeFile('a.jpg', 'aaaa');
      await scanner().scan(now: DateTime(2026, 6, 12));
      expect((await watched.indexForRoot(root.path)).keys, ['a.jpg']);

      // A root that has gone away entirely is skipped before pruning, so
      // yesterday's index survives for when the volume comes back.
      await root.delete(recursive: true);
      await scanner().scan(now: DateTime(2026, 6, 13));

      expect((await watched.indexForRoot(root.path)).keys, ['a.jpg']);
      await root.create(recursive: true);
    });

    group('the walk is delegated, not performed here', () {
      test('the scanner does no filesystem work of its own', () async {
        await writeFile('a.jpg', 'aaaa');
        // A walk that reports a file the scanner can never have seen: if the
        // scanner still listed the root itself, 'a.jpg' would show up in the
        // index alongside (or instead of) this.
        final scanned = <WatchedFolderWalkRequest>[];
        final report = await WatchedFolderScanner(
          watched: watched,
          repair: repair,
          loadMissingRows: () async => const [],
          isAutoApplyEnabled: () async => false,
          walk: (request) async {
            scanned.add(request);
            return const WatchedFolderWalkResult(
              changed: [
                WalkedFile(
                  relativePath: 'from-the-walk.jpg',
                  sizeBytes: 7,
                  mtimeMillis: 1234,
                  contentHash: 'walk-hash',
                ),
              ],
              vanished: {},
              filesSeen: 1,
              listingComplete: true,
              hashBudgetExhausted: false,
            );
          },
        ).scan(now: DateTime(2026, 6, 12));

        expect(scanned.single.rootPath, root.path);
        expect(report.filesIndexed, 1);
        expect(report.rehashed, 1);
        final index = await watched.indexForRoot(root.path);
        expect(index.keys, ['from-the-walk.jpg']);
        expect(index['from-the-walk.jpg']!.contentHash, 'walk-hash');
      });

      test(
        'the stored index is handed to the walk so it can skip hashes',
        () async {
          await writeFile('a.jpg', 'aaaa');
          await scanner().scan(now: DateTime(2026, 6, 12));

          WatchedFolderWalkRequest? seenRequest;
          await WatchedFolderScanner(
            watched: watched,
            repair: repair,
            loadMissingRows: () async => const [],
            isAutoApplyEnabled: () async => false,
            walk: (request) async {
              seenRequest = request;
              return const WatchedFolderWalkResult(
                changed: [],
                vanished: {},
                filesSeen: 1,
                listingComplete: true,
                hashBudgetExhausted: false,
              );
            },
          ).scan(now: DateTime(2026, 6, 13));

          final known = seenRequest!.known['a.jpg']!;
          expect(known.contentHash, isNotNull);
          expect(known.sizeBytes, 4);
        },
      );

      test('the configured hash budget reaches the walk', () async {
        WatchedFolderWalkRequest? seenRequest;
        await WatchedFolderScanner(
          watched: watched,
          repair: repair,
          loadMissingRows: () async => const [],
          isAutoApplyEnabled: () async => false,
          hashBudget: const Duration(seconds: 7),
          walk: (request) async {
            seenRequest = request;
            return const WatchedFolderWalkResult(
              changed: [],
              vanished: {},
              filesSeen: 0,
              listingComplete: true,
              hashBudgetExhausted: false,
            );
          },
        ).scan(now: DateTime(2026, 6, 12));

        expect(seenRequest!.hashBudget, const Duration(seconds: 7));
      });
    });

    group('hash budget', () {
      Future<WatcherScanReport> scanWith(
        WatchedFolderWalkResult result, {
        DateTime? now,
      }) => WatchedFolderScanner(
        watched: watched,
        repair: repair,
        loadMissingRows: () async => const [],
        isAutoApplyEnabled: () async => false,
        walk: (_) async => result,
      ).scan(now: now ?? DateTime(2026, 6, 13));

      test(
        'an exhausted budget still prunes, because the listing was whole',
        () async {
          await writeFile('a.jpg', 'aaaa');
          await writeFile('gone.jpg', 'zzzz');
          await scanner().scan(now: DateTime(2026, 6, 12));

          final report = await scanWith(
            const WatchedFolderWalkResult(
              changed: [],
              vanished: {'gone.jpg'},
              filesSeen: 1,
              listingComplete: true,
              hashBudgetExhausted: true,
            ),
          );

          expect(report.hashBudgetExhausted, isTrue);
          expect((await watched.indexForRoot(root.path)).keys, ['a.jpg']);
        },
      );

      test(
        'an incomplete listing prunes nothing, budget or no budget',
        () async {
          await writeFile('a.jpg', 'aaaa');
          await writeFile('b.jpg', 'bbbb');
          await scanner().scan(now: DateTime(2026, 6, 12));

          await scanWith(
            const WatchedFolderWalkResult(
              changed: [],
              // The walk names 'b.jpg' as vanished, but its listing threw
              // part-way, so that claim is not trustworthy.
              vanished: {'b.jpg'},
              filesSeen: 1,
              listingComplete: false,
              hashBudgetExhausted: false,
            ),
          );

          // 'b.jpg' was never listed, so it must survive: a partial listing
          // that pruned would delete the index rows of files that still exist.
          expect((await watched.indexForRoot(root.path)).keys.toSet(), {
            'a.jpg',
            'b.jpg',
          });
        },
      );

      test('a truncated pass is still stamped, so the cadence holds', () async {
        await scanWith(
          const WatchedFolderWalkResult(
            changed: [],
            vanished: {},
            filesSeen: 0,
            listingComplete: true,
            hashBudgetExhausted: true,
          ),
          now: DateTime(2026, 6, 14),
        );

        expect(await watched.lastScanAt(root.path), DateTime(2026, 6, 14));
      });

      test(
        'a hash the budget denied is written back as null, not left stale',
        () async {
          await writeFile('a.jpg', 'aaaa');
          await scanner().scan(now: DateTime(2026, 6, 12));
          final before = (await watched.indexForRoot(root.path))['a.jpg']!;
          expect(before.contentHash, isNotNull);

          await scanWith(
            const WatchedFolderWalkResult(
              changed: [
                WalkedFile(
                  relativePath: 'a.jpg',
                  sizeBytes: 99,
                  mtimeMillis: 4321,
                  contentHash: null,
                ),
              ],
              vanished: {},
              filesSeen: 1,
              listingComplete: true,
              hashBudgetExhausted: true,
            ),
          );

          final after = (await watched.indexForRoot(root.path))['a.jpg']!;
          // The digest no longer describes the bytes, and auto-repair rewrites
          // media.local_path on an exact hash match -- so it must not survive.
          expect(after.contentHash, isNull);
          expect(after.sizeBytes, 99);
          // Null hashes never match the repair lookup (SQL IN never matches
          // NULL), so the row is inert until it is hashed again.
          expect(await watched.pathsForHashes([before.contentHash!]), isEmpty);
        },
      );
    });
  });
}
