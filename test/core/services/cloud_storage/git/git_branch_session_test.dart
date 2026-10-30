import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/git/git_branch_files.dart';
import 'package:submersion/core/services/cloud_storage/git/git_branch_session.dart';
import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/core/services/cloud_storage/git/git_http_transport.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_remote.dart';

import '../../../../helpers/git_cli.dart';
import '../../../../helpers/git_http_backend_server.dart';
import '../../../../helpers/git_test_session.dart';

/// A push that reaches the server and then loses its reply.
class _LostReplyTransport extends GitHttpTransport {
  _LostReplyTransport(super.remote);

  bool loseNextReply = false;

  @override
  Future<void> push({
    required String branch,
    required GitObjectId? oldTip,
    required GitObjectId newTip,
    required Stream<List<int>> pack,
    int packBytes = 0,
  }) async {
    await super.push(
      branch: branch,
      oldTip: oldTip,
      newTip: newTip,
      pack: pack,
      packBytes: packBytes,
    );
    if (loseNextReply) {
      loseNextReply = false;
      throw GitException(
        'Could not reach 127.0.0.1.',
        code: GitErrorCode.unreachable,
        host: '127.0.0.1',
      );
    }
  }
}

void main() {
  final skip = skipUnlessGit();

  test(
    'open() on an empty repository creates the branch and its root files',
    () async {
      final server = await startGitTestServer();
      final repo = await server.createBareRepo('empty');
      final snap = await gitTestSession(server.repoUrl('empty')).open();
      expect(snap.isDefaultBranch, isTrue);
      expect(snap.index.entries, isEmpty);
      final files = await runGit(repo, [
        'ls-tree',
        '-r',
        '--name-only',
        'refs/heads/$gitTestBranch',
      ]);
      expect(
        files.split('\n'),
        unorderedEquals([kGitReadmePath, kGitMetaPath, kGitIndexPath]),
      );
      // Another device adopts the branch rather than creating a second one.
      final again = await gitTestSession(server.repoUrl('empty')).open();
      expect(again.tip, snap.tip);
    },
    skip: skip,
  );

  test(
    'open() refuses a branch with other content and leaves it untouched',
    () async {
      final server = await startGitTestServer();
      final repo = await server.createBareRepo('mine', withMainCommit: true);
      final before = await runGit(repo, ['rev-parse', 'refs/heads/main']);
      await expectLater(
        gitTestSession(server.repoUrl('mine'), branch: 'main').open(),
        throwsA(
          isA<GitException>().having(
            (e) => e.code,
            'code',
            GitErrorCode.branchHasOtherContent,
          ),
        ),
      );
      expect(await runGit(repo, ['rev-parse', 'refs/heads/main']), before);
      expect(
        await runGit(repo, ['rev-list', '--count', 'refs/heads/main']),
        '1',
      );
    },
    skip: skip,
  );

  test(
    'a committed file is listed by a fresh session with size and time',
    () async {
      final server = await startGitTestServer();
      await server.createBareRepo('sync');
      final writer = gitTestSession(
        server.repoUrl('sync'),
        clock: () => DateTime.utc(2026, 10, 18, 9, 30),
      );
      await writer.open();
      await writer.commit(
        GitChange(
          puts: {'Submersion Sync/ssv1.a.cs.1.json': gitText('{"x":1}')},
        ),
        messagePrefix: 'Sync',
      );
      final reader = gitTestSession(server.repoUrl('sync'));
      final snap = await reader.open();
      final entry = snap.index.entries['Submersion Sync/ssv1.a.cs.1.json']!;
      expect(entry.size, 7);
      expect(
        entry.modifiedMs,
        DateTime.utc(2026, 10, 18, 9, 30).millisecondsSinceEpoch,
      );
      expect(
        utf8.decode(await reader.readFile('Submersion Sync/ssv1.a.cs.1.json')),
        '{"x":1}',
      );
    },
    skip: skip,
  );

  test('two devices committing at once both land', () async {
    final server = await startGitTestServer();
    final repo = await server.createBareRepo('sync');
    final a = gitTestSession(server.repoUrl('sync'));
    await a.open();
    final b = gitTestSession(server.repoUrl('sync'));
    await b.open();
    await a.commit(
      GitChange(puts: {'Submersion Sync/a.json': gitText('a')}),
      messagePrefix: 'Sync',
    );
    // b still believes the old tip; its push is stale and must be rebuilt.
    await b.commit(
      GitChange(puts: {'Submersion Sync/b.json': gitText('b')}),
      messagePrefix: 'Sync',
    );
    final files = await runGit(repo, [
      'ls-tree',
      '-r',
      '--name-only',
      'refs/heads/$gitTestBranch',
    ]);
    expect(files, contains('Submersion Sync/a.json'));
    expect(files, contains('Submersion Sync/b.json'));
  }, skip: skip);

  test(
    'a delete is dropped when a peer rewrote the file since it was listed',
    () async {
      final server = await startGitTestServer();
      await server.createBareRepo('sync');
      const path = 'Submersion Sync/submersion_library_epoch.json';
      final a = gitTestSession(server.repoUrl('sync'));
      await a.open();
      await a.commit(
        GitChange(puts: {path: gitText('epoch 1')}),
        messagePrefix: 'Sync',
      );
      final b = gitTestSession(server.repoUrl('sync'));
      final seen = (await b.open()).index.entries[path]!.blobId;
      await a.commit(
        GitChange(puts: {path: gitText('epoch 2')}),
        messagePrefix: 'Sync',
      );
      await b.commit(GitChange(deletes: {path: seen}), messagePrefix: 'Sync');
      final fresh = gitTestSession(server.repoUrl('sync'));
      await fresh.open();
      expect(utf8.decode(await fresh.readFile(path)), 'epoch 2');
    },
    skip: skip,
  );

  test(
    'a push whose reply is lost is recognised as landed, not repeated',
    () async {
      final server = await startGitTestServer();
      final repo = await server.createBareRepo('sync');
      final transport = _LostReplyTransport(
        GitRemote(cloneUrl: server.repoUrl('sync'), username: 'u', token: 't'),
      );
      final s = gitTestSession(server.repoUrl('sync'), transport: transport);
      await s.open();
      final before = int.parse(
        await runGit(repo, [
          'rev-list',
          '--count',
          'refs/heads/$gitTestBranch',
        ]),
      );
      transport.loseNextReply = true;
      await s.commit(
        GitChange(puts: {'Submersion Sync/x.json': gitText('x')}),
        messagePrefix: 'Sync',
      );
      final after = int.parse(
        await runGit(repo, [
          'rev-list',
          '--count',
          'refs/heads/$gitTestBranch',
        ]),
      );
      expect(after, before + 1);
    },
    skip: skip,
  );

  test('a due history reset leaves one commit with the same files', () async {
    final server = await startGitTestServer();
    final repo = await server.createBareRepo('sync');
    final s = gitTestSession(server.repoUrl('sync'), resetThresholdBytes: 1024);
    await s.open();
    final big = 'x' * 2000;
    await s.commit(
      GitChange(puts: {'Submersion Sync/old.json': gitText(big)}),
      messagePrefix: 'Sync',
    );
    final oldId = s.current!.index.entries['Submersion Sync/old.json']!.blobId;
    await s.commit(
      GitChange(
        puts: {'Submersion Sync/keep.json': gitText('keep')},
        deletes: {'Submersion Sync/old.json': oldId},
      ),
      messagePrefix: 'Sync',
    );
    expect(s.current!.meta.deletedBytesSinceReset, greaterThanOrEqualTo(2000));
    final filesBefore = await runGit(repo, [
      'ls-tree',
      '-r',
      '--name-only',
      'refs/heads/$gitTestBranch',
    ]);
    expect(await s.resetHistoryIfDue(), isTrue);
    expect(
      await runGit(repo, ['rev-list', '--count', 'refs/heads/$gitTestBranch']),
      '1',
    );
    expect(
      await runGit(repo, [
        'ls-tree',
        '-r',
        '--name-only',
        'refs/heads/$gitTestBranch',
      ]),
      filesBefore,
    );
    expect(s.current!.meta.deletedBytesSinceReset, 0);
    expect(s.current!.meta.lastResetAtMs, isNotNull);
    expect(await s.resetHistoryIfDue(), isFalse);
  }, skip: skip);

  test(
    'a forced reset that races a peer commit is rebuilt on the new tip',
    () async {
      final server = await startGitTestServer();
      final repo = await server.createBareRepo('sync');
      final a = gitTestSession(server.repoUrl('sync'));
      await a.open();
      final b = gitTestSession(server.repoUrl('sync'));
      await b.open();
      await b.commit(
        GitChange(puts: {'Submersion Sync/peer.json': gitText('p')}),
        messagePrefix: 'Sync',
      );
      // Asked for (a privacy purge), so it must not be dropped.
      expect(await a.resetHistoryIfDue(force: true), isTrue);
      final files = await runGit(repo, [
        'ls-tree',
        '-r',
        '--name-only',
        'refs/heads/$gitTestBranch',
      ]);
      expect(files, contains('Submersion Sync/peer.json'));
      expect(
        await runGit(repo, [
          'rev-list',
          '--count',
          'refs/heads/$gitTestBranch',
        ]),
        '1',
      );
    },
    skip: skip,
  );

  test('a forced reset with nothing to drop pushes nothing', () async {
    final server = await startGitTestServer();
    final repo = await server.createBareRepo('sync');
    final s = gitTestSession(server.repoUrl('sync'));
    await s.open();
    await s.commit(
      GitChange(puts: {'Submersion Sync/x.json': gitText('x')}),
      messagePrefix: 'Sync',
    );
    expect(await s.resetHistoryIfDue(force: true), isTrue);
    final tip = await runGit(repo, ['rev-parse', 'refs/heads/$gitTestBranch']);
    // A second purge right after (a wipe, then a library replace).
    expect(await s.resetHistoryIfDue(force: true), isFalse);
    expect(await runGit(repo, ['rev-parse', 'refs/heads/$gitTestBranch']), tip);
  }, skip: skip);

  test(
    'a due reset that races a peer commit waits for the next sync',
    () async {
      final server = await startGitTestServer();
      await server.createBareRepo('sync');
      final a = gitTestSession(server.repoUrl('sync'), resetThresholdBytes: 1);
      await a.open();
      await a.commit(
        GitChange(puts: {'Submersion Sync/mine.json': gitText('m')}),
        messagePrefix: 'Sync',
      );
      final b = gitTestSession(server.repoUrl('sync'));
      await b.open();
      await b.commit(
        GitChange(puts: {'Submersion Sync/peer.json': gitText('p')}),
        messagePrefix: 'Sync',
      );
      expect(await a.resetHistoryIfDue(), isFalse);
    },
    skip: skip,
  );

  test('a change that alters nothing makes no commit', () async {
    final server = await startGitTestServer();
    final repo = await server.createBareRepo('sync');
    final s = gitTestSession(server.repoUrl('sync'));
    await s.open();
    await s.commit(
      GitChange(puts: {'Submersion Sync/x.json': gitText('x')}),
      messagePrefix: 'Sync',
    );
    final count = await runGit(repo, [
      'rev-list',
      '--count',
      'refs/heads/$gitTestBranch',
    ]);
    await s.commit(
      GitChange(puts: {'Submersion Sync/x.json': gitText('x')}),
      messagePrefix: 'Sync',
    );
    expect(
      await runGit(repo, ['rev-list', '--count', 'refs/heads/$gitTestBranch']),
      count,
    );
  }, skip: skip);

  test('a put and a delete of the same path keep the new file', () async {
    final server = await startGitTestServer();
    await server.createBareRepo('sync');
    const path = 'Submersion Sync/submersion_library_epoch.json';
    final s = gitTestSession(server.repoUrl('sync'));
    await s.open();
    await s.commit(
      GitChange(puts: {path: gitText('epoch 1')}),
      messagePrefix: 'Sync',
    );
    final old = s.current!.index.entries[path]!.blobId;
    await s.commit(
      GitChange(puts: {path: gitText('epoch 2')}, deletes: {path: old}),
      messagePrefix: 'Sync',
    );
    final fresh = gitTestSession(server.repoUrl('sync'));
    await fresh.open();
    expect(utf8.decode(await fresh.readFile(path)), 'epoch 2');
  }, skip: skip);

  test(
    'a reset the host refuses as a non-fast-forward is protectedBranch',
    () async {
      final server = await startGitTestServer();
      final repo = await server.createBareRepo('sync');
      final s = gitTestSession(server.repoUrl('sync'));
      await s.open();
      // Something to drop, or the reset would not be pushed at all.
      await s.commit(
        GitChange(puts: {'Submersion Sync/x.json': gitText('x')}),
        messagePrefix: 'Sync',
      );
      await runGit(repo, ['config', 'receive.denyNonFastForwards', 'true']);
      await expectLater(
        s.resetHistoryIfDue(force: true),
        throwsA(
          isA<GitException>().having(
            (e) => e.code,
            'code',
            GitErrorCode.protectedBranch,
          ),
        ),
      );
    },
    skip: skip,
  );

  test('a too-large refusal names the size of the file', () async {
    final server = await startGitTestServer();
    final repo = await server.createBareRepo('sync');
    final s = gitTestSession(server.repoUrl('sync'));
    await s.open();
    await server.refusePushes(repo, 'GH001: Large files detected.');
    await expectLater(
      s.commit(
        GitChange(puts: {'Submersion Backups/b.db': gitText('x' * 5000)}),
        messagePrefix: 'Backup',
      ),
      throwsA(
        isA<GitException>()
            .having((e) => e.code, 'code', GitErrorCode.tooLarge)
            .having((e) => e.sizeBytes, 'sizeBytes', 5000),
      ),
    );
  }, skip: skip);

  test(
    'a host without filter still follows a peer, commit after commit',
    () async {
      final server = await startGitTestServer(allowFilter: false);
      await server.createBareRepo('sync');
      final a = gitTestSession(server.repoUrl('sync'));
      await a.open();
      final b = gitTestSession(server.repoUrl('sync'));
      await b.open();
      for (var i = 0; i < 3; i++) {
        await a.commit(
          GitChange(
            puts: {'Submersion Sync/f$i.json': gitText('v$i ${'x' * 3000}')},
          ),
          messagePrefix: 'Sync',
        );
        await b.refresh();
        expect(
          utf8.decode(await b.readFile('Submersion Sync/f$i.json')),
          startsWith('v$i '),
        );
      }
    },
    skip: skip,
  );

  test('a host without filter sends only what a peer changed', () async {
    final server = await startGitTestServer(allowFilter: false);
    await server.createBareRepo('sync');
    final a = gitTestSession(server.repoUrl('sync'));
    await a.open();
    final r = Random(7);
    final big = List.generate(
      200000,
      (_) => r.nextInt(16).toRadixString(16),
    ).join();
    await a.commit(
      GitChange(puts: {'Submersion Backups/b.db': gitText(big)}),
      messagePrefix: 'Backup',
    );
    final b = gitTestSession(server.repoUrl('sync'));
    await b.open();
    server.fetchResponseBytes.clear();
    await a.commit(
      GitChange(puts: {'Submersion Sync/small.json': gitText('{"x":1}')}),
      messagePrefix: 'Sync',
    );
    await b.refresh();
    final fetched = server.fetchResponseBytes.fold<int>(0, (a, b) => a + b);
    // The unchanged 200 KB backup must not travel again.
    expect(fetched, lessThan(20000));
    expect(
      utf8.decode(await b.readFile('Submersion Sync/small.json')),
      '{"x":1}',
    );
  }, skip: skip);

  test('a host without filter can send a peer edit of a file this device '
      'uploaded', () async {
    final server = await startGitTestServer(allowFilter: false);
    await server.createBareRepo('sync');
    final a = gitTestSession(server.repoUrl('sync'));
    await a.open();
    final r = Random(11);
    final original = List.generate(
      60000,
      (_) => r.nextInt(16).toRadixString(16),
    ).join();
    await a.commit(
      GitChange(puts: {'Submersion Sync/f.json': gitText(original)}),
      messagePrefix: 'Sync',
    );
    final b = gitTestSession(server.repoUrl('sync'));
    await b.open();
    final edited = 'x${original.substring(1)}';
    await b.commit(
      GitChange(puts: {'Submersion Sync/f.json': gitText(edited)}),
      messagePrefix: 'Sync',
    );
    // a never stored the blob it uploaded, so a delta against it would be
    // unreadable here.
    await a.refresh();
    expect(utf8.decode(await a.readFile('Submersion Sync/f.json')), edited);
  }, skip: skip);

  test(
    'a delta against an upload this device did not keep is fetched whole',
    () async {
      final server = await startGitTestServer(allowFilter: false);
      await server.createBareRepo('sync');
      final a = gitTestSession(server.repoUrl('sync'));
      await a.open();
      final r = Random(12);
      final original = List.generate(
        60000,
        (_) => r.nextInt(16).toRadixString(16),
      ).join();
      // Streamed from disk, so not copied into the store.
      final file = File(joinPath(tempDirForTest('git_up_'), 'b.db'))
        ..writeAsStringSync(original);
      await a.commit(
        GitChange(puts: {'Submersion Backups/b.db': GitPut.file(file)}),
        messagePrefix: 'Backup',
      );
      final b = gitTestSession(server.repoUrl('sync'));
      await b.open();
      final edited = 'y${original.substring(1)}';
      await b.commit(
        GitChange(puts: {'Submersion Backups/b.db': gitText(edited)}),
        messagePrefix: 'Backup',
      );
      await a.refresh();
      expect(utf8.decode(await a.readFile('Submersion Backups/b.db')), edited);
    },
    skip: skip,
  );

  test('a commit Submersion cannot parse is a Git error', () async {
    final server = await startGitTestServer();
    final repo = await server.createBareRepo('sync');
    await gitTestSession(server.repoUrl('sync')).open();
    final tree = await runGit(repo, [
      'rev-parse',
      'refs/heads/$gitTestBranch^{tree}',
    ]);
    // No author line: written by another tool, or damaged.
    final commit = await runGit(repo, [
      'hash-object',
      '-t',
      'commit',
      '-w',
      '--literally',
      '--stdin',
    ], stdin: 'tree $tree\n\nno author\n');
    await runGit(repo, ['update-ref', 'refs/heads/$gitTestBranch', commit]);
    await expectLater(
      gitTestSession(server.repoUrl('sync')).open(),
      throwsA(
        isA<GitException>().having(
          (e) => e.code,
          'code',
          GitErrorCode.unexpected,
        ),
      ),
    );
  }, skip: skip);
}
