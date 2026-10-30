import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/core/services/cloud_storage/git/git_http_transport.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_objects.dart';
import 'package:submersion/core/services/cloud_storage/git/git_remote.dart';
import 'package:submersion/core/services/cloud_storage/git/pack_writer.dart';
import 'package:submersion/core/services/cloud_storage/http_timeouts.dart';

import '../../../../helpers/git_cli.dart';
import '../../../../helpers/git_http_backend_server.dart';

/// A commit holding one file, plus the pack that carries its new objects.
({GitObjectId commit, GitObjectId blob, List<PackEntrySource> pack}) _commit(
  String fileText, {
  GitObjectId? parent,
}) {
  final blob = Uint8List.fromList(utf8.encode(fileText));
  final blobId = hashGitObject(GitObjectType.blob, blob);
  final tree = encodeTree([
    GitTreeEntry(name: 'data.json', mode: kGitModeFile, id: blobId),
  ]);
  final treeId = hashGitObject(GitObjectType.tree, tree);
  final commit = GitCommit(
    tree: treeId,
    parents: [?parent],
    authorName: 'Submersion 1234abcd',
    authorEmail: 'sync@submersion.invalid',
    when: DateTime.utc(2026, 10, 18),
    message: 'Sync from Submersion 1234abcd',
  ).encode();
  return (
    commit: hashGitObject(GitObjectType.commit, commit),
    blob: blobId,
    pack: [
      PackEntrySource.bytes(GitObjectType.blob, blob),
      PackEntrySource.bytes(GitObjectType.tree, tree),
      PackEntrySource.bytes(GitObjectType.commit, commit),
    ],
  );
}

GitHttpTransport _transport(
  Uri url, {
  String username = 'diver',
  String token = 'secret',
}) {
  final t = GitHttpTransport(
    GitRemote(cloneUrl: url, username: username, token: token),
  );
  addTearDown(t.close);
  return t;
}

Matcher _gitError(GitErrorCode code) =>
    throwsA(isA<GitException>().having((e) => e.code, 'code', code));

void main() {
  final skip = skipUnlessGit();

  group('against git http-backend', () {
    test('ls-refs on an empty repository reports no branches', () async {
      final server = await startGitTestServer();
      await server.createBareRepo('empty');
      final refs = await _transport(
        server.repoUrl('empty'),
      ).lsRefs('submersion-sync');
      expect(refs.protocolVersion, 2);
      expect(refs.branchTip, isNull);
      expect(refs.isEmpty, isTrue);
    }, skip: skip);

    test('ls-refs reports HEAD\'s branch on a repository with main', () async {
      final server = await startGitTestServer();
      await server.createBareRepo('mine', withMainCommit: true);
      final refs = await _transport(server.repoUrl('mine')).lsRefs('main');
      expect(refs.headSymref, 'refs/heads/main');
      expect(refs.branchTip, isNotNull);
      expect(refs.isEmpty, isFalse);
    }, skip: skip);

    test('a push creates the branch that stock git then sees', () async {
      final server = await startGitTestServer();
      final repo = await server.createBareRepo('sync');
      final t = _transport(server.repoUrl('sync'));
      final c = _commit('{"a":1}\n');
      await t.push(
        branch: 'submersion-sync',
        oldTip: null,
        newTip: c.commit,
        pack: writePack(c.pack),
      );
      expect((await t.lsRefs('submersion-sync')).branchTip, c.commit);
      expect(
        await runGit(repo, ['rev-parse', 'refs/heads/submersion-sync']),
        c.commit.hex,
      );
    }, skip: skip);

    test('a push from a stale tip is rejected as staleTip', () async {
      final server = await startGitTestServer();
      await server.createBareRepo('sync');
      final t = _transport(server.repoUrl('sync'));
      final first = _commit('{"a":1}\n');
      await t.push(
        branch: 'submersion-sync',
        oldTip: null,
        newTip: first.commit,
        pack: writePack(first.pack),
      );
      final second = _commit('{"a":2}\n', parent: first.commit);
      await t.push(
        branch: 'submersion-sync',
        oldTip: first.commit,
        newTip: second.commit,
        pack: writePack(second.pack),
      );
      // A device that still believes the tip is `first`.
      final stale = _commit('{"a":3}\n', parent: first.commit);
      await expectLater(
        t.push(
          branch: 'submersion-sync',
          oldTip: first.commit,
          newTip: stale.commit,
          pack: writePack(stale.pack),
        ),
        _gitError(GitErrorCode.staleTip),
      );
    }, skip: skip);

    test(
      'a blobless fetch brings commit and tree, fetchBlobs the blob',
      () async {
        final server = await startGitTestServer();
        await server.createBareRepo('sync');
        final t = _transport(server.repoUrl('sync'));
        final c = _commit('{"a":1}\n');
        await t.push(
          branch: 'submersion-sync',
          oldTip: null,
          newTip: c.commit,
          pack: writePack(c.pack),
        );
        final store = MemoryGitObjectStore();
        await t.fetch([c.commit], store, blobless: true);
        expect(await store.has(c.commit), isTrue);
        expect(await store.has(c.blob), isFalse);
        await t.fetchBlobs([c.blob], store);
        expect(utf8.decode((await store.get(c.blob))!.body), '{"a":1}\n');
      },
      skip: skip,
    );

    test('a blobless fetch falls back when the server has no filter', () async {
      final server = await startGitTestServer(allowFilter: false);
      await server.createBareRepo('sync');
      final t = _transport(server.repoUrl('sync'));
      final c = _commit('{"a":1}\n');
      await t.push(
        branch: 'submersion-sync',
        oldTip: null,
        newTip: c.commit,
        pack: writePack(c.pack),
      );
      expect((await t.lsRefs('submersion-sync')).supportsFilter, isFalse);
      final store = MemoryGitObjectStore();
      await t.fetch([c.commit], store, blobless: true);
      expect(await store.has(c.commit), isTrue);
      expect(await store.has(c.blob), isTrue);
    }, skip: skip);

    test('protocol v0 servers still list, fetch and push', () async {
      final server = await startGitTestServer(protocolV2: false);
      await server.createBareRepo('old', withMainCommit: true);
      final t = _transport(server.repoUrl('old'));
      final refs = await t.lsRefs('submersion-sync');
      expect(refs.protocolVersion, 0);
      expect(refs.headSymref, 'refs/heads/main');
      expect(refs.branchTip, isNull);
      final c = _commit('{"v0":true}\n');
      await t.push(
        branch: 'submersion-sync',
        oldTip: null,
        newTip: c.commit,
        pack: writePack(c.pack),
      );
      final store = MemoryGitObjectStore();
      await t.fetch([c.commit], store);
      expect(await store.has(c.blob), isTrue);
      expect((await t.lsRefs('submersion-sync')).branchTip, c.commit);
    }, skip: skip);

    test('a wrong token is unauthorized; the right one may push', () async {
      final server = await startGitTestServer(
        requireUser: 'diver',
        requirePassword: 'right',
      );
      await server.createBareRepo('private');
      await expectLater(
        _transport(server.repoUrl('private'), token: 'wrong').lsRefs('x'),
        _gitError(GitErrorCode.unauthorized),
      );
      await _transport(
        server.repoUrl('private'),
        token: 'right',
      ).checkPushAccess();
    }, skip: skip);

    test(
      'isPubliclyReadable tells a public repository from a private one',
      () async {
        final public = await startGitTestServer(
          requireUser: 'diver',
          requirePassword: 'right',
          anonymousRead: true,
        );
        await public.createBareRepo('open');
        expect(
          await _transport(
            public.repoUrl('open'),
            token: 'right',
          ).isPubliclyReadable(),
          isTrue,
        );
        final private = await startGitTestServer(
          requireUser: 'diver',
          requirePassword: 'right',
        );
        await private.createBareRepo('closed');
        expect(
          await _transport(
            private.repoUrl('closed'),
            token: 'right',
          ).isPubliclyReadable(),
          isFalse,
        );
      },
      skip: skip,
    );
  });

  group('not a Git server', () {
    test('an address that serves a web page is notGit', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) {
        request.response
          ..headers.contentType = ContentType.html
          ..write('<html>hello</html>');
        request.response.close();
      });
      await expectLater(
        _transport(
          Uri.parse('http://127.0.0.1:${server.port}/r.git'),
        ).lsRefs('x'),
        _gitError(GitErrorCode.notGit),
      );
    });

    test('a closed port is unreachable, naming the host', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close(force: true);
      await expectLater(
        _transport(Uri.parse('http://127.0.0.1:$port/r.git')).lsRefs('x'),
        throwsA(
          isA<GitException>()
              .having((e) => e.code, 'code', GitErrorCode.unreachable)
              .having((e) => e.host, 'host', '127.0.0.1'),
        ),
      );
    });
  });

  group('push failures', () {
    test(
      'a push whose request cannot be sent fails instead of hanging',
      () async {
        final server = await startGitTestServer();
        await server.createBareRepo('sync');
        final remote = GitRemote(
          cloneUrl: server.repoUrl('sync'),
          username: 'u',
          token: 't',
        );
        final t = GitHttpTransport(remote, client: _PostRefused(http.Client()));
        addTearDown(t.close);
        final c = _commit('{"a":1}\n');
        await expectLater(
          t
              .push(
                branch: 'submersion-sync',
                oldTip: null,
                newTip: c.commit,
                pack: writePack(c.pack),
              )
              .timeout(const Duration(seconds: 20)),
          _gitError(GitErrorCode.unreachable),
        );
      },
      skip: skip,
    );

    Future<GitException> refusedWith(String hookMessage) async {
      final server = await startGitTestServer();
      final repo = await server.createBareRepo('sync');
      await server.refusePushes(repo, hookMessage);
      final c = _commit('{"a":1}\n');
      try {
        await _transport(server.repoUrl('sync')).push(
          branch: 'submersion-sync',
          oldTip: null,
          newTip: c.commit,
          pack: writePack(c.pack),
        );
      } on GitException catch (e) {
        return e;
      }
      fail('the push was not refused');
    }

    test('a host size limit explained by its hook is tooLarge', () async {
      final e = await refusedWith(
        'GH001: Large files detected. You may want to try Git Large File Storage.',
      );
      expect(e.code, GitErrorCode.tooLarge);
    }, skip: skip);

    for (final wording in [
      'GitLab: You are attempting to check in one or more files which exceed '
          'the 100MiB limit',
      'File "b.db" is larger than the allowed size of 100 MiB',
      'Your repository has exceeded its size limit',
    ]) {
      test('a size limit worded "$wording" is tooLarge', () async {
        final e = await refusedWith(wording);
        expect(e.code, GitErrorCode.tooLarge);
      }, skip: skip);
    }

    test('a protected branch explained by its hook is protectedBranch', () async {
      final e = await refusedWith(
        'You are not allowed to force push code to a protected branch on this project.',
      );
      expect(e.code, GitErrorCode.protectedBranch);
    }, skip: skip);

    test('an unexpected refusal is not mistaken for a stale tip', () async {
      final e = await refusedWith(
        'An unexpected error occurred on the server.',
      );
      expect(e.code, GitErrorCode.server);
      expect(e.serverReason, contains('unexpected error'));
    }, skip: skip);
  });
  test(
    'a malformed Git reply to an anonymous request is not read as private',
    () async {
      // The host served the advertisement without credentials; that its
      // framing is off says nothing about who may read it.
      final client = MockClient(
        (request) async => http.Response(
          '001e# service=git-upload-pack\n0009xyz\n',
          200,
          headers: {
            'content-type': 'application/x-git-upload-pack-advertisement',
          },
        ),
      );
      final t = GitHttpTransport(
        GitRemote(
          cloneUrl: Uri.parse('https://git.example.net/you/r.git'),
          username: 'u',
          token: 't',
        ),
        client: client,
      );
      addTearDown(t.close);
      await expectLater(
        t.checkPubliclyReadable(),
        _gitError(GitErrorCode.unexpected),
      );
      expect(await t.isPubliclyReadable(), isNull);
    },
  );

  GitHttpTransport mockTransport(MockClientHandler handler) {
    final t = GitHttpTransport(
      GitRemote(
        cloneUrl: Uri.parse('https://git.example.net/you/r.git'),
        username: 'u',
        token: 't',
      ),
      client: MockClient(handler),
    );
    addTearDown(t.close);
    return t;
  }

  test('a host without shallow support is not sent shallow lines', () async {
    String? fetchBody;
    final t = mockTransport((request) async {
      if (request.method == 'GET') {
        return http.Response(
          '000eversion 2\n0011fetch=filter\n000cls-refs\n0000',
          200,
          headers: {
            'content-type': 'application/x-git-upload-pack-advertisement',
          },
        );
      }
      fetchBody = request.body;
      return http.Response('', 500);
    });
    final have = GitObjectId.fromHex('1' * 40);
    await expectLater(
      t.fetch(
        [GitObjectId.fromHex('2' * 40)],
        MemoryGitObjectStore(),
        haves: {have},
      ),
      _gitError(GitErrorCode.server),
    );
    expect(fetchBody, isNot(contains('shallow ')));
  });

  test('a receive-pack advertisement missing its flush is refused', () async {
    String pkt(String line) =>
        '${(line.length + 4).toRadixString(16).padLeft(4, '0')}$line';
    final nul = String.fromCharCode(0);
    final service = pkt('# service=git-receive-pack\n');
    final ref = pkt('${'1' * 40} refs/heads/main${nul}report-status\n');
    final t = mockTransport(
      (request) async => http.Response(
        '$service${ref}0000',
        200,
        headers: {
          'content-type': 'application/x-git-receive-pack-advertisement',
        },
      ),
    );
    await expectLater(t.checkPushAccess(), _gitError(GitErrorCode.unexpected));
  });

  group('push deadlines', () {
    test('grow with the pack past the upload deadline', () {
      expect(
        GitHttpTransport.pushDeadlineFor(1024),
        TimeoutHttpClient.defaultUploadTimeout,
      );
      expect(
        GitHttpTransport.pushDeadlineFor(150 * 1024 * 1024),
        const Duration(seconds: 1200),
      );
    });

    test(
      'a push that misses its deadline is stopped and never lands',
      () async {
        final server = await startGitTestServer();
        final repo = await server.createBareRepo('sync');
        final t = GitHttpTransport(
          GitRemote(
            cloneUrl: server.repoUrl('sync'),
            username: 'diver',
            token: 'secret',
          ),
          pushDeadline: (_) => const Duration(milliseconds: 500),
        );
        addTearDown(t.close);
        final r = Random(4);
        final big = _commit(
          List.generate(
            4 * 1024 * 1024,
            (_) => r.nextInt(16).toRadixString(16),
          ).join(),
        );
        // The body stalls after its first chunk, as on a slow link, so the
        // deadline passes while it is still being sent; it resumes only
        // after the push has given up.
        final resume = Completer<void>();
        Stream<List<int>> stalled(Stream<List<int>> pack) async* {
          var first = true;
          await for (final chunk in pack) {
            if (!first) await resume.future;
            first = false;
            yield chunk;
          }
        }

        await expectLater(
          t.push(
            branch: 'submersion-sync',
            oldTip: null,
            newTip: big.commit,
            pack: stalled(writePack(big.pack)),
          ),
          _gitError(GitErrorCode.unreachable),
        );
        resume.complete();
        // A push that kept streaming would now finish and land.
        for (
          var i = 0;
          i < 40 &&
              !server.requests.any(
                (r) => r.startsWith('POST') && r.endsWith('/git-receive-pack'),
              );
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await server.idle();
        expect(await runGit(repo, ['for-each-ref', 'refs/heads/']), isEmpty);
      },
      skip: skip,
    );
  });
}

/// Refuses every POST without reading its body, as a dropped connection
/// between discovery and the push does.
class _PostRefused extends http.BaseClient {
  _PostRefused(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.method == 'POST') {
      return Future.error(http.ClientException('Connection refused'));
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
