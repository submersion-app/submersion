import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/watched_folder_repository.dart';

void main() {
  late LocalCacheDatabase cacheDb;
  late WatchedFolderRepository repo;

  setUp(() {
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    repo = WatchedFolderRepository(database: cacheDb);
  });
  tearDown(() => cacheDb.close());

  test('roots round-trip and removal prunes the index', () async {
    await repo.addRoot('/nas/Dives');
    expect(await repo.getRoots(), ['/nas/Dives']);

    await repo.upsertIndexed(
      const IndexedFile(
        rootPath: '/nas/Dives',
        relativePath: '2026/a.jpg',
        sizeBytes: 4,
        mtimeMillis: 1,
        contentHash: 'H',
      ),
    );

    await repo.removeRoot('/nas/Dives');
    expect(await repo.getRoots(), isEmpty);
    expect(await repo.indexForRoot('/nas/Dives'), isEmpty);
  });

  test('upsert replaces by (root, relativePath) and pathsForHashes maps '
      'absolutes', () async {
    await repo.upsertIndexed(
      const IndexedFile(
        rootPath: '/r',
        relativePath: 'a.jpg',
        sizeBytes: 4,
        mtimeMillis: 1,
        contentHash: 'OLD',
      ),
    );
    await repo.upsertIndexed(
      const IndexedFile(
        rootPath: '/r',
        relativePath: 'a.jpg',
        sizeBytes: 9,
        mtimeMillis: 2,
        contentHash: 'NEW',
      ),
    );

    final index = await repo.indexForRoot('/r');
    expect(index, hasLength(1));
    expect(index['a.jpg']!.sizeBytes, 9);
    expect(await repo.pathsForHashes({'NEW'}), {'NEW': '/r/a.jpg'});
  });

  test('pathsForHashes returns only the hashes asked for', () async {
    await repo.upsertIndexed(
      const IndexedFile(
        rootPath: '/r',
        relativePath: 'a.jpg',
        sizeBytes: 4,
        mtimeMillis: 1,
        contentHash: 'WANTED',
      ),
    );
    await repo.upsertIndexed(
      const IndexedFile(
        rootPath: '/r',
        relativePath: 'b.jpg',
        sizeBytes: 4,
        mtimeMillis: 1,
        contentHash: 'IGNORED',
      ),
    );

    expect(await repo.pathsForHashes({'WANTED'}), {'WANTED': '/r/a.jpg'});
    expect(await repo.pathsForHashes(const <String>[]), isEmpty);
  });

  test('pathsForHashes chunks past SQLite bound-variable limits', () async {
    // One IN(...) per 900 values; 2,500 forces three statements.
    await repo.upsertIndexed(
      const IndexedFile(
        rootPath: '/r',
        relativePath: 'found.jpg',
        sizeBytes: 4,
        mtimeMillis: 1,
        contentHash: 'H-2400',
      ),
    );

    final hashes = [for (var i = 0; i < 2500; i++) 'H-$i'];
    expect(await repo.pathsForHashes(hashes), {'H-2400': '/r/found.jpg'});
  });

  test('deleteIndexed chunks past SQLite bound-variable limits', () async {
    for (var i = 0; i < 2500; i++) {
      await repo.upsertIndexed(
        IndexedFile(
          rootPath: '/r',
          relativePath: 'f$i.jpg',
          sizeBytes: 1,
          mtimeMillis: 1,
        ),
      );
    }
    await repo.upsertIndexed(
      const IndexedFile(
        rootPath: '/r',
        relativePath: 'keep.jpg',
        sizeBytes: 1,
        mtimeMillis: 1,
      ),
    );

    await repo.deleteIndexed('/r', [for (var i = 0; i < 2500; i++) 'f$i.jpg']);
    expect((await repo.indexForRoot('/r')).keys, ['keep.jpg']);
  });

  test('deleteIndexed drops rows whose file vanished', () async {
    await repo.upsertIndexed(
      const IndexedFile(
        rootPath: '/r',
        relativePath: 'keep.jpg',
        sizeBytes: 1,
        mtimeMillis: 1,
      ),
    );
    await repo.upsertIndexed(
      const IndexedFile(
        rootPath: '/r',
        relativePath: 'gone.jpg',
        sizeBytes: 1,
        mtimeMillis: 1,
      ),
    );

    await repo.deleteIndexed('/r', {'gone.jpg'});
    expect((await repo.indexForRoot('/r')).keys, ['keep.jpg']);
  });

  test('stampScanned records the cadence timestamp', () async {
    await repo.addRoot('/r');
    expect(await repo.lastScanAt('/r'), isNull);
    await repo.stampScanned('/r', DateTime(2026, 6, 12));
    expect(await repo.lastScanAt('/r'), DateTime(2026, 6, 12));
  });

  test('fresh cache database has both v9 tables', () async {
    final names = await cacheDb
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    final set = names.map((r) => r.read<String>('name')).toSet();
    expect(set, containsAll(['watched_roots', 'watched_folder_index']));
  });
}
