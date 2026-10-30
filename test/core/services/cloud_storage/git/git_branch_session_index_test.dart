import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/git/git_branch_files.dart';
import 'package:submersion/core/services/cloud_storage/git/git_branch_session.dart';
import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';

import '../../../../helpers/git_cli.dart';
import '../../../../helpers/git_http_backend_server.dart';
import '../../../../helpers/git_test_provider.dart';
import '../../../../helpers/git_test_session.dart';

/// The time [fixedGitEnv] gives every commit made with stock git.
const int _handCommitMs = 1700000000 * 1000;

const String _keep = 'Submersion Sync/keep.json';
const String _added = 'Submersion Sync/added.json';

/// Commits on the branch the way another tool would: [put] writes each
/// path's text (as a symlink when listed in [symlinks]), [remove] drops
/// paths. Returns the new tip.
Future<String> _handCommit(
  Directory repo, {
  Map<String, String> put = const {},
  Set<String> symlinks = const {},
  List<String> remove = const [],
  Map<String, String> commitEnv = const {},
}) async {
  final env = {'GIT_INDEX_FILE': joinPath(tempDirForTest('git_idx_'), 'index')};
  await runGit(repo, ['read-tree', 'refs/heads/$gitTestBranch'], env: env);
  for (final MapEntry(:key, :value) in put.entries) {
    final blob = await runGit(repo, [
      'hash-object',
      '-w',
      '--stdin',
    ], stdin: value);
    final mode = symlinks.contains(key) ? '120000' : '100644';
    await runGit(repo, [
      'update-index',
      '--add',
      '--cacheinfo',
      '$mode,$blob,$key',
    ], env: env);
  }
  // Mode 0 removes the entry; --force-remove would need a work tree.
  for (final path in remove) {
    await runGit(
      repo,
      ['update-index', '--index-info'],
      stdin: '0 ${'0' * 40}\t$path\n',
      env: env,
    );
  }
  final tree = await runGit(repo, ['write-tree'], env: env);
  final tip = await runGit(repo, ['rev-parse', 'refs/heads/$gitTestBranch']);
  final commit = await runGit(repo, [
    'commit-tree',
    tree,
    '-p',
    tip,
    '-m',
    'by hand',
  ], env: commitEnv);
  await runGit(repo, ['update-ref', 'refs/heads/$gitTestBranch', commit]);
  return commit;
}

/// The index the branch tip carries, decoded.
Future<GitIndex> _branchIndex(Directory repo) async => GitIndex.decode(
  Uint8List.fromList(
    utf8.encode(
      await runGit(repo, ['show', 'refs/heads/$gitTestBranch:$kGitIndexPath']),
    ),
  ),
);

Future<String> _blobAt(Directory repo, String path) =>
    runGit(repo, ['rev-parse', 'refs/heads/$gitTestBranch:$path']);

/// A branch Submersion made, holding [_keep] written at 09:30.
Future<(GitTestServer, Directory)> _branchWithKeep() async {
  final server = await startGitTestServer();
  final repo = await server.createBareRepo('sync');
  final s = gitTestSession(
    server.repoUrl('sync'),
    clock: () => DateTime.utc(2026, 10, 18, 9, 30),
  );
  await s.open();
  await s.commit(
    GitChange(puts: {_keep: gitText('keep')}),
    messagePrefix: 'Sync',
  );
  return (server, repo);
}

final int _keepMs = DateTime.utc(2026, 10, 18, 9, 30).millisecondsSinceEpoch;

void main() {
  final skip = skipUnlessGit();

  group('files the index does not describe', () {
    test('a hand-added file is listed with the tip time and no size', () async {
      final (server, repo) = await _branchWithKeep();
      await _handCommit(repo, put: {_added: 'added!'});
      final snap = await gitTestSession(server.repoUrl('sync')).open();
      final entry = snap.index.entries[_added]!;
      expect(entry.blobId.hex, await _blobAt(repo, _added));
      expect(entry.size, isNull);
      expect(entry.modifiedMs, _handCommitMs);
      // What the index already knew is kept as it was.
      expect(snap.index.entries[_keep]!.size, 4);
      expect(snap.index.entries[_keep]!.modifiedMs, _keepMs);
    }, skip: skip);

    test('a file from a rebased commit takes the time it landed', () async {
      final (server, repo) = await _branchWithKeep();
      await _handCommit(
        repo,
        put: {_added: 'added!'},
        commitEnv: {'GIT_AUTHOR_DATE': '1600000000 +0000'},
      );
      final snap = await gitTestSession(server.repoUrl('sync')).open();
      expect(snap.index.entries[_added]!.modifiedMs, _handCommitMs);
    }, skip: skip);

    test('reading a hand-added file learns its size, and the next commit '
        'keeps it', () async {
      final (server, repo) = await _branchWithKeep();
      await _handCommit(repo, put: {_added: 'added!'});
      final s = gitTestSession(server.repoUrl('sync'));
      await s.open();
      expect(utf8.decode(await s.readFile(_added)), 'added!');
      expect(s.current!.index.entries[_added]!.size, 6);
      await s.commit(
        GitChange(puts: {'Submersion Sync/other.json': gitText('x')}),
        messagePrefix: 'Sync',
      );
      final stored = (await _branchIndex(repo)).entries[_added]!;
      expect(stored.size, 6);
      expect(stored.modifiedMs, _handCommitMs);
    }, skip: skip);

    test(
      'a hand-added file keeps its first time across later commits',
      () async {
        final (server, repo) = await _branchWithKeep();
        await _handCommit(repo, put: {_added: 'added!'});
        final s = gitTestSession(server.repoUrl('sync'));
        await s.open();
        await s.commit(
          GitChange(puts: {'Submersion Sync/other.json': gitText('x')}),
          messagePrefix: 'Sync',
        );
        final stored = (await _branchIndex(repo)).entries[_added]!;
        expect(stored.size, isNull);
        expect(stored.modifiedMs, _handCommitMs);
        final again = await gitTestSession(server.repoUrl('sync')).open();
        expect(again.index.entries[_added]!.modifiedMs, _handCommitMs);
      },
      skip: skip,
    );

    test('a hand-added file can be deleted', () async {
      final (server, repo) = await _branchWithKeep();
      await _handCommit(repo, put: {_added: 'added!'});
      final s = gitTestSession(server.repoUrl('sync'));
      final snap = await s.open();
      await s.commit(
        GitChange(deletes: {_added: snap.index.entries[_added]!.blobId}),
        messagePrefix: 'Sync',
      );
      final files = await runGit(repo, [
        'ls-tree',
        '-r',
        '--name-only',
        'refs/heads/$gitTestBranch',
      ]);
      expect(files.split('\n'), isNot(contains(_added)));
    }, skip: skip);

    test('a file deleted by hand leaves the index', () async {
      final (server, repo) = await _branchWithKeep();
      await _handCommit(repo, remove: [_keep]);
      final s = gitTestSession(server.repoUrl('sync'));
      final snap = await s.open();
      expect(snap.index.entries, isNot(contains(_keep)));
      await s.commit(
        GitChange(puts: {'Submersion Sync/other.json': gitText('x')}),
        messagePrefix: 'Sync',
      );
      expect((await _branchIndex(repo)).entries, isNot(contains(_keep)));
    }, skip: skip);

    test(
      'a file edited by hand takes the new blob, the tip time and no size',
      () async {
        final (server, repo) = await _branchWithKeep();
        await _handCommit(repo, put: {_keep: 'edited by hand'});
        final s = gitTestSession(server.repoUrl('sync'));
        final snap = await s.open();
        final entry = snap.index.entries[_keep]!;
        expect(entry.blobId.hex, await _blobAt(repo, _keep));
        expect(entry.size, isNull);
        expect(entry.modifiedMs, _handCommitMs);
        expect(utf8.decode(await s.readFile(_keep)), 'edited by hand');
      },
      skip: skip,
    );

    test(
      'only regular files are indexed, and none of Submersion\'s own',
      () async {
        final (server, repo) = await _branchWithKeep();
        await _handCommit(
          repo,
          put: {'Submersion Sync/link.json': _keep},
          symlinks: {'Submersion Sync/link.json'},
        );
        final snap = await gitTestSession(server.repoUrl('sync')).open();
        expect(snap.index.entries.keys, [_keep]);
      },
      skip: skip,
    );

    test('the provider lists a hand-added file with no size', () async {
      final (server, repo) = await _branchWithKeep();
      await _handCommit(repo, put: {_added: 'added!'});
      final p = await gitTestProvider(server.repoUrl('sync'));
      final files = await p.listFiles(
        folderId: await p.getOrCreateSyncFolder(),
      );
      final added = files.singleWhere((f) => f.id == _added);
      expect(added.sizeBytes, isNull);
      expect(added.modifiedTime.millisecondsSinceEpoch, _handCommitMs);
      expect((await p.getFileInfo(_added))!.sizeBytes, isNull);
    }, skip: skip);
  });

  group('an index that cannot be read', () {
    for (final (name, content) in [
      ('corrupt', '{not json'),
      ('missing', null),
      (
        'with a malformed entry',
        '{"version":1,"files":{"$_keep":'
            '{"blob":"${'0' * 40}","size":"4","mtime":1}}}',
      ),
    ]) {
      test('a $name index is rebuilt from the tree', () async {
        final (server, repo) = await _branchWithKeep();
        if (content == null) {
          await _handCommit(repo, remove: [kGitIndexPath]);
        } else {
          await _handCommit(repo, put: {kGitIndexPath: content});
        }
        final s = gitTestSession(server.repoUrl('sync'));
        final snap = await s.open();
        final entry = snap.index.entries[_keep]!;
        expect(entry.blobId.hex, await _blobAt(repo, _keep));
        expect(entry.modifiedMs, _handCommitMs);
        // The next commit writes the rebuilt index back, file and all.
        await s.commit(
          GitChange(puts: {'Submersion Sync/other.json': gitText('x')}),
          messagePrefix: 'Sync',
        );
        expect(
          (await _branchIndex(repo)).entries.keys,
          unorderedEquals([_keep, 'Submersion Sync/other.json']),
        );
      }, skip: skip);
    }

    test('an index from a newer version stops the session', () async {
      final (server, repo) = await _branchWithKeep();
      await _handCommit(repo, put: {kGitIndexPath: '{"version":2,"files":{}}'});
      await expectLater(
        gitTestSession(server.repoUrl('sync')).open(),
        throwsA(
          isA<GitException>().having(
            (e) => e.code,
            'code',
            GitErrorCode.indexUnreadable,
          ),
        ),
      );
    }, skip: skip);
  });
}
