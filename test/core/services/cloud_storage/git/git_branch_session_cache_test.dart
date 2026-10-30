import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/git/git_branch_session.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';

import '../../../../helpers/git_cli.dart';
import '../../../../helpers/git_delegating_store.dart';
import '../../../../helpers/git_http_backend_server.dart';
import '../../../../helpers/git_test_session.dart';

String _randomHex(int length, int seed) {
  final r = Random(seed);
  return List.generate(length, (_) => r.nextInt(16).toRadixString(16)).join();
}

void main() {
  final skip = skipUnlessGit();

  test(
    'a fetch larger than the store bound keeps the tip it fetched',
    () async {
      // Without filter support every blob travels with the tip.
      final server = await startGitTestServer(allowFilter: false);
      await server.createBareRepo('sync');
      final peer = gitTestSession(server.repoUrl('sync'));
      await peer.open();
      await peer.commit(
        GitChange(
          puts: {
            for (var i = 0; i < 3; i++)
              'Submersion Sync/f$i.json': gitText(_randomHex(3000, i)),
          },
        ),
        messagePrefix: 'Sync',
      );
      final s = gitTestSession(
        server.repoUrl('sync'),
        store: FileGitObjectStore(tempDirForTest('git_store_'), maxBytes: 4096),
      );
      final snap = await s.open();
      expect(snap.index.entries, hasLength(3));
      await s.commit(
        GitChange(puts: {'Submersion Sync/mine.json': gitText('mine')}),
        messagePrefix: 'Sync',
      );
      expect(
        utf8.decode(await s.readFile('Submersion Sync/f1.json')),
        _randomHex(3000, 1),
      );
    },
    skip: skip,
  );

  test('objects the store lost are fetched again', () async {
    final server = await startGitTestServer();
    await server.createBareRepo('sync');
    final peer = gitTestSession(server.repoUrl('sync'));
    await peer.open();
    await peer.commit(
      GitChange(puts: {'Submersion Sync/peer.json': gitText('peer')}),
      messagePrefix: 'Sync',
    );
    final dir = tempDirForTest('git_store_');
    final s = gitTestSession(
      server.repoUrl('sync'),
      store: FileGitObjectStore(dir),
    );
    await s.open();
    // Another store on the same directory evicted everything.
    for (final entity in dir.listSync()) {
      entity.deleteSync(recursive: true);
    }
    expect(utf8.decode(await s.readFile('Submersion Sync/peer.json')), 'peer');
    for (final entity in dir.listSync()) {
      entity.deleteSync(recursive: true);
    }
    await s.commit(
      GitChange(puts: {'Submersion Sync/mine.json': gitText('mine')}),
      messagePrefix: 'Sync',
    );
    final fresh = gitTestSession(server.repoUrl('sync'));
    expect((await fresh.open()).index.entries.keys, hasLength(2));
  }, skip: skip);

  test(
    "a large download does not push the branch's trees out of the store",
    () async {
      final server = await startGitTestServer();
      await server.createBareRepo('sync');
      final peer = gitTestSession(server.repoUrl('sync'));
      await peer.open();
      final big = _randomHex(200000, 9);
      await peer.commit(
        GitChange(puts: {'Submersion Backups/b.db': gitText(big)}),
        messagePrefix: 'Backup',
      );
      final s = gitTestSession(
        server.repoUrl('sync'),
        store: FileGitObjectStore(
          tempDirForTest('git_store_'),
          maxBytes: 64 * 1024,
        ),
      );
      await s.open();
      expect(utf8.decode(await s.readFile('Submersion Backups/b.db')), big);
      await s.commit(
        GitChange(puts: {'Submersion Sync/mine.json': gitText('mine')}),
        messagePrefix: 'Sync',
      );
      expect(s.current!.index.entries, hasLength(2));
    },
    skip: skip,
  );

  test('the store is back within its bound after the next commit', () async {
    final server = await startGitTestServer();
    await server.createBareRepo('sync');
    final peer = gitTestSession(server.repoUrl('sync'));
    await peer.open();
    await peer.commit(
      GitChange(
        puts: {'Submersion Backups/b.db': gitText(_randomHex(200000, 3))},
      ),
      messagePrefix: 'Backup',
    );
    final dir = tempDirForTest('git_store_');
    final s = gitTestSession(
      server.repoUrl('sync'),
      store: FileGitObjectStore(dir, maxBytes: 64 * 1024),
    );
    await s.open();
    await s.readFile('Submersion Backups/b.db');
    await s.commit(
      GitChange(puts: {'Submersion Sync/x.json': gitText('x')}),
      messagePrefix: 'Sync',
    );
    final onDisk = dir
        .listSync(recursive: true)
        .whereType<File>()
        .fold<int>(0, (sum, f) => sum + f.lengthSync());
    expect(onDisk, lessThanOrEqualTo(64 * 1024));
  }, skip: skip);

  test(
    'a cache that fails to trim does not fail a commit that landed',
    () async {
      final server = await startGitTestServer();
      final repo = await server.createBareRepo('sync');
      final s = gitTestSession(server.repoUrl('sync'), store: _TrimFails());
      await s.open();
      await s.commit(
        GitChange(puts: {'Submersion Sync/x.json': gitText('x')}),
        messagePrefix: 'Sync',
      );
      expect(
        await runGit(repo, [
          'ls-tree',
          '-r',
          '--name-only',
          'refs/heads/$gitTestBranch',
        ]),
        contains('Submersion Sync/x.json'),
      );
    },
    skip: skip,
  );
}

/// A store whose disk cannot be scanned when it is trimmed.
final class _TrimFails extends DelegatingGitObjectStore {
  _TrimFails() : super(MemoryGitObjectStore());

  @override
  Future<void> trim({Future<Set<GitObjectId>> Function()? keep}) async {
    throw const FileSystemException('cannot list the cache');
  }
}
