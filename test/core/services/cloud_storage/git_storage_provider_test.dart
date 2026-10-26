import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/cloud_storage/git/git_config.dart';
import 'package:submersion/core/services/cloud_storage/git/git_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/core/services/cloud_storage/git_storage_provider.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';

import '../../../helpers/git_cli.dart';
import '../../../helpers/git_http_backend_server.dart';
import '../../../helpers/git_test_provider.dart';
import '../../../support/fake_keychain_storage.dart';

Uint8List _bytes(String s) => Uint8List.fromList(s.codeUnits);

void main() {
  final skip = skipUnlessGit();

  group('gitCommitIdentityFor', () {
    test('uses the device name when sync is not encrypted', () {
      final id = gitCommitIdentityFor(
        deviceId: gitTestDeviceId,
        deviceName: "Eric's iPhone",
        encrypted: false,
      );
      expect(id.name, "Eric's iPhone");
      expect(id.messageLabel, "Eric's iPhone");
    });

    test('keeps the device name out of the repository under encryption', () {
      final id = gitCommitIdentityFor(
        deviceId: gitTestDeviceId,
        deviceName: "Eric's iPhone",
        encrypted: true,
      );
      expect(id.name, 'Submersion 1234abcd');
      expect(id.messageLabel, 'Submersion 1234abcd');
    });

    test('falls back to the short device id when there is no name', () {
      final id = gitCommitIdentityFor(
        deviceId: gitTestDeviceId,
        deviceName: null,
        encrypted: false,
      );
      expect(id.name, 'Submersion 1234abcd');
    });
  });

  group('against git http-backend', () {
    test(
      'an uploaded file is listed by another device with size and time',
      () async {
        final server = await startGitTestServer(
          requireUser: 'diver',
          requirePassword: 'tok',
        );
        await server.createBareRepo('sync');
        final writer = await gitTestProvider(server.repoUrl('sync'));
        final folder = await writer.getOrCreateSyncFolder();
        expect(folder, 'Submersion Sync');
        final before = DateTime.now().toUtc();
        final result = await writer.uploadFile(
          _bytes('{"x":1}'),
          'ssv1.a.cs.1.json',
          folderId: folder,
        );
        expect(result.fileId, 'Submersion Sync/ssv1.a.cs.1.json');

        final reader = await gitTestProvider(server.repoUrl('sync'));
        final files = await reader.listFiles(
          folderId: await reader.getOrCreateSyncFolder(),
        );
        final file = files.single;
        expect(file.name, 'ssv1.a.cs.1.json');
        expect(file.sizeBytes, 7);
        expect(
          file.modifiedTime.isAfter(
            before.subtract(const Duration(seconds: 1)),
          ),
          isTrue,
        );
        expect(
          String.fromCharCodes(await reader.downloadFile(file.id)),
          '{"x":1}',
        );
        expect(
          await reader.listFiles(folderId: folder, namePattern: 'nope'),
          isEmpty,
        );
      },
      skip: skip,
    );

    test(
      'deleteFile pushes nothing, hides the file at once, and flush pushes one commit',
      () async {
        final server = await startGitTestServer(
          requireUser: 'diver',
          requirePassword: 'tok',
        );
        final repo = await server.createBareRepo('sync');
        final p = await gitTestProvider(server.repoUrl('sync'));
        final folder = await p.getOrCreateSyncFolder();
        final ids = <String>[];
        for (var i = 0; i < 10; i++) {
          ids.add(
            (await p.uploadFile(
              _bytes('$i'),
              'f$i.json',
              folderId: folder,
            )).fileId,
          );
        }
        await p.listFiles(folderId: folder);
        final count = await syncBranchCommits(repo);
        for (final id in ids) {
          await p.deleteFile(id);
        }
        expect(await syncBranchCommits(repo), count);
        expect(await p.fileExists(ids.first), isFalse);
        expect(await p.listFiles(folderId: folder), isEmpty);
        await p.flush();
        expect(await syncBranchCommits(repo), count + 1);
        final files = await runGit(repo, [
          'ls-tree',
          '-r',
          '--name-only',
          'refs/heads/$kDefaultGitBranch',
        ]);
        expect(files, isNot(contains('Submersion Sync/')));
      },
      skip: skip,
    );

    test('pending deletes ride along in the next upload\'s commit', () async {
      final server = await startGitTestServer(
        requireUser: 'diver',
        requirePassword: 'tok',
      );
      final repo = await server.createBareRepo('sync');
      final p = await gitTestProvider(server.repoUrl('sync'));
      final folder = await p.getOrCreateSyncFolder();
      final old = await p.uploadFile(
        _bytes('old'),
        'old.json',
        folderId: folder,
      );
      await p.listFiles(folderId: folder);
      final count = await syncBranchCommits(repo);
      await p.deleteFile(old.fileId);
      await p.uploadFile(_bytes('new'), 'new.json', folderId: folder);
      expect(await syncBranchCommits(repo), count + 1);
      final names = (await p.listFiles(folderId: folder)).map((f) => f.name);
      expect(names, ['new.json']);
    }, skip: skip);

    test('the quiet period flushes deletes on its own', () async {
      final server = await startGitTestServer(
        requireUser: 'diver',
        requirePassword: 'tok',
      );
      final repo = await server.createBareRepo('sync');
      final p = await gitTestProvider(
        server.repoUrl('sync'),
        deleteQuietPeriod: const Duration(milliseconds: 50),
      );
      final folder = await p.getOrCreateSyncFolder();
      final f = await p.uploadFile(_bytes('x'), 'x.json', folderId: folder);
      await p.listFiles(folderId: folder);
      final count = await syncBranchCommits(repo);
      await p.deleteFile(f.fileId);
      for (var i = 0; i < 100 && await syncBranchCommits(repo) == count; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(await syncBranchCommits(repo), count + 1);
    }, skip: skip);

    test('a backup streams from disk and is committed as a backup', () async {
      final server = await startGitTestServer(
        requireUser: 'diver',
        requirePassword: 'tok',
      );
      final repo = await server.createBareRepo('sync');
      final p = await gitTestProvider(server.repoUrl('sync'));
      final dir = tempDirForTest('git_backup_');
      final r = Random(1);
      final file = File(joinPath(dir, 'submersion_backup_1.db'))
        ..writeAsBytesSync(
          List.generate(3 * 1024 * 1024, (_) => r.nextInt(256)),
        );
      final backups = await p.createFolder('Submersion Backups');
      expect(backups, 'Submersion Backups');
      final up = await p.uploadFileFromPath(
        file.path,
        'submersion_backup_1.db',
        folderId: backups,
      );
      expect(up.fileId, 'Submersion Backups/submersion_backup_1.db');
      final subject = await runGit(repo, [
        'log',
        '-1',
        '--format=%s',
        'refs/heads/$kDefaultGitBranch',
      ]);
      expect(subject, startsWith('Backup from '));
      final listed = await p.listFiles(folderId: backups);
      expect(listed.single.sizeBytes, 3 * 1024 * 1024);
      final out = File(joinPath(dir, 'restored.db'));
      await p.downloadToFile(up.fileId, out.path);
      expect(out.lengthSync(), 3 * 1024 * 1024);
    }, skip: skip);

    test('a public repository refuses unencrypted writes', () async {
      final server = await startGitTestServer(
        requireUser: 'diver',
        requirePassword: 'tok',
        anonymousRead: true,
      );
      final repo = await server.createBareRepo('open');
      final plain = await gitTestProvider(server.repoUrl('open'));
      await expectLater(
        plain.uploadFile(_bytes('x'), 'x.json', folderId: 'Submersion Sync'),
        throwsA(
          isA<GitException>().having(
            (e) => e.code,
            'code',
            GitErrorCode.publicRepoUnencrypted,
          ),
        ),
      );
      // Turning encryption on must still be possible: the keyslot file holds
      // only a wrapped key, so it may land while sync is unencrypted.
      await plain.uploadFile(
        _bytes('{"slots":[]}'),
        'submersion_keyslots.json',
        folderId: 'Submersion Sync',
      );
      final files = await runGit(repo, [
        'ls-tree',
        '-r',
        '--name-only',
        'refs/heads/$kDefaultGitBranch',
      ]);
      expect(files, contains('Submersion Sync/submersion_keyslots.json'));
      expect(files, isNot(contains('Submersion Sync/x.json')));
      final sealed = await gitTestProvider(
        server.repoUrl('open'),
        encrypted: true,
      );
      await sealed.uploadFile(
        Uint8List.fromList([...SyncEnvelope.magic, 1]),
        'x.json',
        folderId: 'Submersion Sync',
      );
      expect(await syncBranchCommits(repo), greaterThanOrEqualTo(2));
      expect(await sealed.isPubliclyReadable(), isTrue);
    }, skip: skip);

    test(
      'a history reset is known to every provider for that repository',
      () async {
        final server = await startGitTestServer(
          requireUser: 'diver',
          requirePassword: 'tok',
        );
        await server.createBareRepo('reset');
        final p = await gitTestProvider(server.repoUrl('reset'));
        await p.uploadFile(_bytes('x'), 'x.json', folderId: 'Submersion Sync');
        final config = (await p.loadConfig())!;
        expect(GitStorageProvider.lastKnownResetFor(config), isNull);
        await p.resetHistoryNow();
        // The tile reads this, and the active sync provider is a different
        // instance (one per account) from the settings singleton.
        expect(GitStorageProvider.lastKnownResetFor(config), isNotNull);
        expect(
          p.lastKnownResetAt,
          GitStorageProvider.lastKnownResetFor(config),
        );
      },
      skip: skip,
    );

    test('commits under encryption carry no device name', () async {
      final server = await startGitTestServer(
        requireUser: 'diver',
        requirePassword: 'tok',
      );
      final repo = await server.createBareRepo('sync');
      final p = await gitTestProvider(server.repoUrl('sync'), encrypted: true);
      await p.uploadFile(_bytes('x'), 'x.json', folderId: 'Submersion Sync');
      final log = await runGit(repo, [
        'log',
        '--format=%an|%s',
        'refs/heads/$kDefaultGitBranch',
      ]);
      expect(log, isNot(contains('Eric')));
      expect(
        log,
        contains('Submersion 1234abcd|Sync from Submersion 1234abcd'),
      );
    }, skip: skip);
  });

  group('testConnection', () {
    test(
      'an empty repository: the branch will be created and become default',
      () async {
        final server = await startGitTestServer(
          requireUser: 'diver',
          requirePassword: 'tok',
        );
        await server.createBareRepo('empty');
        final p = await gitTestProvider(server.repoUrl('empty'));
        final report = await p.testConnection(
          GitConfig(
            repoUrl: server.repoUrl('empty').toString(),
            username: 'diver',
            token: 'tok',
          ),
        );
        expect(report.branchExists, isFalse);
        expect(report.willBecomeDefault, isTrue);
        expect(report.isPublic, isFalse);
      },
      skip: skip,
    );

    test(
      'a branch with other content is refused and nothing is written',
      () async {
        final server = await startGitTestServer(
          requireUser: 'diver',
          requirePassword: 'tok',
        );
        final repo = await server.createBareRepo('mine', withMainCommit: true);
        final p = await gitTestProvider(server.repoUrl('mine'));
        await expectLater(
          p.testConnection(
            GitConfig(
              repoUrl: server.repoUrl('mine').toString(),
              username: 'diver',
              token: 'tok',
              branch: 'main',
            ),
          ),
          throwsA(
            isA<GitException>().having(
              (e) => e.code,
              'code',
              GitErrorCode.branchHasOtherContent,
            ),
          ),
        );
        expect(
          await runGit(repo, ['rev-list', '--count', 'refs/heads/main']),
          '1',
        );
      },
      skip: skip,
    );

    test('a wrong token is unauthorized', () async {
      final server = await startGitTestServer(
        requireUser: 'diver',
        requirePassword: 'right',
      );
      await server.createBareRepo('private');
      final p = await gitTestProvider(server.repoUrl('private'));
      await expectLater(
        p.testConnection(
          GitConfig(
            repoUrl: server.repoUrl('private').toString(),
            username: 'diver',
            token: 'wrong',
          ),
        ),
        throwsA(
          isA<GitException>().having(
            (e) => e.code,
            'code',
            GitErrorCode.unauthorized,
          ),
        ),
      );
    }, skip: skip);

    test('an invalid config is refused before any request', () async {
      final p = GitStorageProvider(
        store: GitCredentialsStore(storage: InMemoryKeychain()),
      );
      addTearDown(p.dispose);
      await expectLater(
        p.testConnection(
          GitConfig(
            repoUrl: 'http://github.com/a/b',
            username: 'diver',
            token: 'tok',
          ),
        ),
        throwsA(
          isA<GitException>().having(
            (e) => e.code,
            'code',
            GitErrorCode.invalidConfig,
          ),
        ),
      );
    });
  });

  test('without a saved config the provider is not authenticated', () async {
    final p = GitStorageProvider(
      store: GitCredentialsStore(storage: InMemoryKeychain()),
    );
    addTearDown(p.dispose);
    expect(await p.isAuthenticated(), isFalse);
    await expectLater(
      p.authenticate(),
      throwsA(
        isA<GitException>().having(
          (e) => e.code,
          'code',
          GitErrorCode.invalidConfig,
        ),
      ),
    );
    expect(p.providerId, 'git');
    expect(p.providerName, 'Git');
  });

  group('review fixes', () {
    test('an upload replaces a pending delete of the same path', () async {
      final server = await startGitTestServer(
        requireUser: 'diver',
        requirePassword: 'tok',
      );
      await server.createBareRepo('sync');
      final p = await gitTestProvider(server.repoUrl('sync'));
      final up = await p.uploadFile(
        _bytes('one'),
        'epoch.json',
        folderId: 'Submersion Sync',
      );
      await p.listFiles(folderId: 'Submersion Sync');
      await p.deleteFile(up.fileId);
      await p.uploadFile(
        _bytes('two'),
        'epoch.json',
        folderId: 'Submersion Sync',
      );
      final reader = await gitTestProvider(server.repoUrl('sync'));
      expect(String.fromCharCodes(await reader.downloadFile(up.fileId)), 'two');
    }, skip: skip);

    test(
      'a refused history reset neither fails the flush nor goes unseen',
      () async {
        final server = await startGitTestServer(
          requireUser: 'diver',
          requirePassword: 'tok',
        );
        final repo = await server.createBareRepo('sync');
        final p = await gitTestProvider(
          server.repoUrl('sync'),
          resetThresholdBytes: 1,
        );
        final up = await p.uploadFile(
          _bytes('x' * 100),
          'x.json',
          folderId: 'Submersion Sync',
        );
        await p.listFiles(folderId: 'Submersion Sync');
        await runGit(repo, ['config', 'receive.denyNonFastForwards', 'true']);
        final changed = <String>[];
        final sub = GitStorageProvider.resetRecords.changes.listen(changed.add);
        addTearDown(sub.cancel);
        await p.deleteFile(up.fileId);
        await p.flush();
        final config = (await p.loadConfig())!;
        expect(GitStorageProvider.resetRefusedFor(config), isTrue);
        // The Cloud sync page follows these changes while it is open.
        await pumpEventQueue();
        expect(changed, contains(gitNaturalKey(config)));
        final files = await runGit(repo, [
          'ls-tree',
          '-r',
          '--name-only',
          'refs/heads/$kDefaultGitBranch',
        ]);
        expect(files, isNot(contains('Submersion Sync/x.json')));
      },
      skip: skip,
    );

    test('a backup is not cut off by the sync upload budget', () async {
      final server = await startGitTestServer(
        requireUser: 'diver',
        requirePassword: 'tok',
      );
      await server.createBareRepo('sync');
      final p = await gitTestProvider(
        server.repoUrl('sync'),
        uploadBudget: const Duration(microseconds: 1),
      );
      await expectLater(
        p.uploadFile(_bytes('x'), 'x.json', folderId: 'Submersion Sync'),
        throwsA(isA<TimeoutException>()),
      );
      final up = await p.uploadFile(
        _bytes('backup'),
        'submersion_backup_1.db',
        folderId: 'Submersion Backups',
      );
      expect(up.fileId, 'Submersion Backups/submersion_backup_1.db');
    }, skip: skip);
  });

  group('review round 1', () {
    test('a fresh provider deletes a file it has never listed', () async {
      final server = await startGitTestServer(
        requireUser: 'diver',
        requirePassword: 'tok',
      );
      final repo = await server.createBareRepo('sync');
      final writer = await gitTestProvider(server.repoUrl('sync'));
      final up = await writer.uploadFile(
        _bytes('old backup'),
        'submersion_backup_1.db',
        folderId: 'Submersion Backups',
      );
      // Backup pruning deletes by id without listing, on whichever provider
      // instance the account resolves to.
      final fresh = await gitTestProvider(server.repoUrl('sync'));
      await fresh.deleteFile(up.fileId);
      await fresh.flush();
      final files = await runGit(repo, [
        'ls-tree',
        '-r',
        '--name-only',
        'refs/heads/$kDefaultGitBranch',
      ]);
      expect(files, isNot(contains('submersion_backup_1.db')));
    }, skip: skip);

    test('a file with a pending delete is not downloadable', () async {
      final server = await startGitTestServer(
        requireUser: 'diver',
        requirePassword: 'tok',
      );
      await server.createBareRepo('sync');
      final p = await gitTestProvider(server.repoUrl('sync'));
      final up = await p.uploadFile(
        _bytes('x'),
        'x.json',
        folderId: 'Submersion Sync',
      );
      await p.listFiles(folderId: 'Submersion Sync');
      await p.deleteFile(up.fileId);
      await expectLater(
        p.downloadFile(up.fileId),
        throwsA(
          isA<GitException>().having(
            (e) => e.code,
            'code',
            GitErrorCode.notFound,
          ),
        ),
      );
    }, skip: skip);
  });

  test(
    'only the sync folder keyslot file may land unencrypted on a public repo',
    () async {
      final server = await startGitTestServer(
        requireUser: 'diver',
        requirePassword: 'tok',
        anonymousRead: true,
      );
      await server.createBareRepo('open');
      final plain = await gitTestProvider(server.repoUrl('open'));
      await expectLater(
        plain.uploadFile(
          _bytes('plain backup'),
          'submersion_keyslots.json',
          folderId: 'Submersion Backups',
        ),
        throwsA(
          isA<GitException>().having(
            (e) => e.code,
            'code',
            GitErrorCode.publicRepoUnencrypted,
          ),
        ),
      );
    },
    skip: skip,
  );

  test(
    'a provider refuses plain http unless loopback http is allowed',
    () async {
      final p = GitStorageProvider(
        store: GitCredentialsStore(storage: InMemoryKeychain()),
      );
      addTearDown(p.dispose);
      await expectLater(
        p.testConnection(
          GitConfig(repoUrl: 'http://127.0.0.1:9/r', username: 'd', token: 't'),
        ),
        throwsA(
          isA<GitException>().having(
            (e) => e.code,
            'code',
            GitErrorCode.invalidConfig,
          ),
        ),
      );
    },
  );
}
