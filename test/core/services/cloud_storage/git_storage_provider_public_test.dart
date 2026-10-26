import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/deferred_write_provider.dart';
import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';

import '../../../helpers/git_cli.dart';
import '../../../helpers/git_http_backend_server.dart';
import '../../../helpers/git_test_provider.dart';

Uint8List _plain(String s) => Uint8List.fromList(s.codeUnits);

/// Bytes that start like every sealed payload and `.sbe` backup.
Uint8List _sealed(String s) =>
    Uint8List.fromList([...SyncEnvelope.magic, ...s.codeUnits]);

Matcher _refusedAs(GitErrorCode code) =>
    throwsA(isA<GitException>().having((e) => e.code, 'code', code));

void main() {
  final skip = skipUnlessGit();

  group('a public repository', () {
    late GitTestServer server;
    late Directory repo;

    setUp(() async {
      server = await startGitTestServer(
        requireUser: 'diver',
        requirePassword: 'tok',
        anonymousRead: true,
      );
      repo = await server.createBareRepo('open');
    });

    test(
      'refuses a plaintext payload even while the encryption setting is on',
      () async {
        // A locked device has the setting on but no key, so it hands the raw
        // provider plaintext (a library replace, or a sync begun before
        // encryption was turned on).
        final p = await gitTestProvider(
          server.repoUrl('open'),
          encrypted: true,
        );
        await expectLater(
          p.uploadFile(
            _plain('{"dives":[]}'),
            'base.json',
            folderId: 'Submersion Sync',
          ),
          _refusedAs(GitErrorCode.publicRepoUnencrypted),
        );
        expect(
          await syncBranchFiles(repo),
          isNot(contains('Submersion Sync/base.json')),
        );
      },
      skip: skip,
    );

    test('accepts a sealed payload whatever the setting says', () async {
      final p = await gitTestProvider(server.repoUrl('open'));
      await p.uploadFile(
        _sealed('ciphertext'),
        'base.json',
        folderId: 'Submersion Sync',
      );
      expect(
        await syncBranchFiles(repo),
        contains('Submersion Sync/base.json'),
      );
    }, skip: skip);

    test(
      'refuses a plaintext backup file and accepts an encrypted one',
      () async {
        final p = await gitTestProvider(
          server.repoUrl('open'),
          encrypted: true,
        );
        final dir = tempDirForTest('git_public_backup_');
        final plain = File(joinPath(dir, 'submersion_backup_1.db'))
          ..writeAsBytesSync(_plain('SQLite format 3'));
        final sealed = File(joinPath(dir, 'submersion_backup_2.sbe'))
          ..writeAsBytesSync(_sealed('frames'));
        await expectLater(
          p.uploadFileFromPath(
            plain.path,
            'submersion_backup_1.db',
            folderId: 'Submersion Backups',
          ),
          _refusedAs(GitErrorCode.publicRepoUnencrypted),
        );
        await p.uploadFileFromPath(
          sealed.path,
          'submersion_backup_2.sbe',
          folderId: 'Submersion Backups',
        );
        final files = await syncBranchFiles(repo);
        expect(files, contains('Submersion Backups/submersion_backup_2.sbe'));
        expect(
          files,
          isNot(contains('Submersion Backups/submersion_backup_1.db')),
        );
      },
      skip: skip,
    );
  });

  group('pin markers in a public repository (#3503)', () {
    late GitTestServer server;
    late Directory repo;

    setUp(() async {
      server = await startGitTestServer(
        requireUser: 'diver',
        requirePassword: 'tok',
        anonymousRead: true,
      );
      repo = await server.createBareRepo('open');
    });

    test('accepts an empty pin marker: it carries no data', () async {
      final p = await gitTestProvider(server.repoUrl('open'));
      await p.uploadFile(
        Uint8List(0),
        'submersion_backup_2026-10-01_090000__p0123456789abcdef.pin',
        folderId: 'Submersion Backups',
      );
      await flushDeferredWrites(p);
      expect(
        await syncBranchFiles(repo),
        contains(
          'Submersion Backups/'
          'submersion_backup_2026-10-01_090000__p0123456789abcdef.pin',
        ),
      );
    }, skip: skip);

    test('refuses a .pin that is not empty', () async {
      final p = await gitTestProvider(server.repoUrl('open'));
      await expectLater(
        p.uploadFile(
          _plain('secret'),
          'submersion_backup_X__p0123456789abcdef.pin',
          folderId: 'Submersion Backups',
        ),
        _refusedAs(GitErrorCode.publicRepoUnencrypted),
      );
    }, skip: skip);
  });

  test('an unclear answer on whether the repository is public holds plaintext '
      'back, and the next upload asks again', () async {
    final server = await startGitTestServer(
      requireUser: 'diver',
      requirePassword: 'tok',
    );
    final repo = await server.createBareRepo('private');
    // The anonymous probe is the only request without credentials.
    var probeAnswers = false;
    server.beforeServe = (request) =>
        probeAnswers ||
        request.headers.value(HttpHeaders.authorizationHeader) != null;
    final p = await gitTestProvider(server.repoUrl('private'));
    await expectLater(
      p.uploadFile(_plain('a'), 'a.json', folderId: 'Submersion Sync'),
      _refusedAs(GitErrorCode.unreachable),
    );
    expect(
      await syncBranchFiles(repo),
      isNot(contains('Submersion Sync/a.json')),
    );

    probeAnswers = true;
    await p.uploadFile(_plain('a'), 'a.json', folderId: 'Submersion Sync');
    expect(await syncBranchFiles(repo), contains('Submersion Sync/a.json'));
  }, skip: skip);
}
