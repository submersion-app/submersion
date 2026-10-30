import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/git/git_http_transport.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git_storage_provider.dart';

import '../../../helpers/git_cli.dart';
import '../../../helpers/git_http_backend_server.dart';
import '../../../helpers/git_test_provider.dart';

Uint8List _bytes(String s) => Uint8List.fromList(s.codeUnits);

/// Holds every push until [hold] completes, while one is set.
class _HeldPushes extends GitHttpTransport {
  _HeldPushes(super.remote);

  Completer<void>? hold;

  /// Holds every ref read until it completes, while set.
  Completer<void>? holdRefs;

  @override
  Future<GitRefAdvertisement> lsRefs(String branch) async {
    final held = holdRefs;
    if (held != null) await held.future;
    return super.lsRefs(branch);
  }

  @override
  Future<void> push({
    required String branch,
    required GitObjectId? oldTip,
    required GitObjectId newTip,
    required Stream<List<int>> pack,
    int packBytes = 0,
  }) async {
    final held = hold;
    if (held != null) await held.future;
    return super.push(
      branch: branch,
      oldTip: oldTip,
      newTip: newTip,
      pack: pack,
      packBytes: packBytes,
    );
  }
}

void main() {
  final skip = skipUnlessGit();

  group('the sync upload budget', () {
    test('grows with the payload', () {
      const base = Duration(seconds: 45);
      expect(GitHttpTransport.deadlineAtLeast(base, 1024), base);
      expect(
        GitHttpTransport.deadlineAtLeast(base, 8 * 1024 * 1024),
        const Duration(seconds: 64),
      );
    });

    test('does not count the wait for push pacing', () async {
      final server = await startGitTestServer(
        requireUser: 'diver',
        requirePassword: 'tok',
      );
      await server.createBareRepo('sync');
      final p = await gitTestProvider(
        server.repoUrl('sync'),
        minPushSpacing: const Duration(seconds: 3),
        maxPacingWait: const Duration(seconds: 3),
        uploadBudget: const Duration(seconds: 2),
      );
      await p.uploadFile(_bytes('a'), 'a.json', folderId: 'Submersion Sync');
      // Paced for about three seconds, then pushed well inside two.
      await p.uploadFile(_bytes('b'), 'b.json', folderId: 'Submersion Sync');
      final names = (await p.listFiles(
        folderId: 'Submersion Sync',
      )).map((f) => f.name).toSet();
      expect(names, {'a.json', 'b.json'});
    }, skip: skip);

    test('runs out as a timeout, since the push may still land', () async {
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
    }, skip: skip);
  });

  group('a flush timeout', () {
    Future<(Directory, _HeldPushes, GitStorageProvider)> setUpHeld() async {
      final server = await startGitTestServer(
        requireUser: 'diver',
        requirePassword: 'tok',
      );
      final repo = await server.createBareRepo('sync');
      final writer = await gitTestProvider(server.repoUrl('sync'));
      await writer.uploadFile(
        _bytes('x'),
        'x.json',
        folderId: 'Submersion Sync',
      );
      late _HeldPushes transport;
      final p = await gitTestProvider(
        server.repoUrl('sync'),
        transportFactory: (config) =>
            transport = _HeldPushes(config.toRemote()),
      );
      await p.listFiles(folderId: 'Submersion Sync');
      return (repo, transport, p);
    }

    test('does not count the wait behind a slow upload', () async {
      final (repo, transport, p) = await setUpHeld();
      final release = transport.hold = Completer<void>();
      final upload = p.uploadFile(
        _bytes('y'),
        'y.json',
        folderId: 'Submersion Sync',
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await p.deleteFile('Submersion Sync/x.json');
      // Room for its own push on a busy runner; the hold outlasts it.
      final flushing = p.flush(timeout: const Duration(seconds: 3));
      // Queued behind the held upload for longer than its timeout.
      await Future<void>.delayed(const Duration(seconds: 4));
      transport.hold = null;
      release.complete();
      await upload;
      await flushing;
      final files = await syncBranchFiles(repo);
      expect(files, contains('Submersion Sync/y.json'));
      expect(files, isNot(contains('Submersion Sync/x.json')));
    }, skip: skip);

    test('with nothing to push, does not wait for a running upload', () async {
      final (_, transport, p) = await setUpHeld();
      final release = transport.hold = Completer<void>();
      final upload = p.uploadFile(
        _bytes('y'),
        'y.json',
        folderId: 'Submersion Sync',
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await p
          .flush(timeout: const Duration(milliseconds: 300))
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => throw StateError('waited for the upload'),
          );
      transport.hold = null;
      release.complete();
      await upload;
    }, skip: skip);

    test('counts opening the branch for its deletes', () async {
      final server = await startGitTestServer(
        requireUser: 'diver',
        requirePassword: 'tok',
      );
      await server.createBareRepo('sync');
      final writer = await gitTestProvider(server.repoUrl('sync'));
      await writer.uploadFile(
        _bytes('x'),
        'x.json',
        folderId: 'Submersion Sync',
      );
      // A new session whose first ref read never answers.
      final p = await gitTestProvider(
        server.repoUrl('sync'),
        transportFactory: (config) =>
            _HeldPushes(config.toRemote())..holdRefs = Completer<void>(),
      );
      await p.deleteFile('Submersion Sync/x.json');
      await expectLater(
        p
            .flush(timeout: const Duration(milliseconds: 200))
            .timeout(
              const Duration(seconds: 2),
              onTimeout: () => throw StateError('the open was not timed'),
            ),
        throwsA(isA<TimeoutException>()),
      );
    }, skip: skip);

    test('runs out once its own push takes too long', () async {
      final (_, transport, p) = await setUpHeld();
      await p.deleteFile('Submersion Sync/x.json');
      transport.hold = Completer<void>();
      await expectLater(
        p.flush(timeout: const Duration(milliseconds: 200)),
        throwsA(isA<TimeoutException>()),
      );
    }, skip: skip);
  });

  test(
    'a device name with brackets or a line break still makes valid commits',
    () async {
      final server = await startGitTestServer(
        requireUser: 'diver',
        requirePassword: 'tok',
      );
      final repo = await server.createBareRepo('sync');
      // Hosts check every pushed object, as GitHub does.
      await runGit(repo, ['config', 'receive.fsckObjects', 'true']);
      final p = await gitTestProvider(
        server.repoUrl('sync'),
        deviceName: 'Eric <work>\nphone',
      );
      await p.uploadFile(_bytes('x'), 'x.json', folderId: 'Submersion Sync');
      final author = await runGit(repo, [
        'log',
        '-1',
        '--format=%an <%ae>',
        'refs/heads/submersion-sync',
      ]);
      expect(author, 'Eric work phone <sync@submersion.invalid>');
    },
    skip: skip,
  );
}
