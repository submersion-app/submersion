import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/cloud_storage/git/git_branch_session.dart';
import 'package:submersion/core/services/cloud_storage/git/git_http_transport.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_remote.dart';
import 'package:submersion/core/services/cloud_storage/git/pack_reader.dart';

import '../../../../helpers/git_cli.dart';
import '../../../../helpers/git_http_backend_server.dart';
import '../../../../helpers/git_recording_store.dart';
import '../../../../helpers/git_test_session.dart';

const int _mb = 1024 * 1024;

/// A file of [length] random bytes from [seed], with [patch] (if any)
/// written over it at [patchAt].
File _backupFile(int length, int seed, {int patchAt = 0, int patch = 0}) {
  final r = Random(seed);
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = r.nextInt(256);
  }
  final pr = Random(seed + 1000);
  for (var i = 0; i < patch; i++) {
    bytes[patchAt + i] = pr.nextInt(256);
  }
  final file = File(p.join(tempDirForTest('git_backup_').path, 'backup.db'))
    ..writeAsBytesSync(bytes);
  return file;
}

/// What of a reply a healthy download has yet to spool: the side-band framing
/// and the one packet the reader may be part way through.
const int _unspooledSlack = 128 * 1024;

/// Holds fetch replies back: after [threshold] bytes of one, nothing more
/// arrives until a pack file in [spool] holds them, to show the reply goes to
/// disk as it streams rather than into memory first.
///
/// The reply is cut into small pieces so it stops at [threshold] and not past
/// it. A socket read can hand over many MB at once, so a look at the file as
/// a chunk arrives sees the disk that far behind, however healthy the
/// download.
final class _SpoolWatchingClient extends http.BaseClient {
  _SpoolWatchingClient(this._inner, this._spool, this._threshold);

  static const int _pieceBytes = 64 * 1024;

  final http.Client _inner;
  final Directory _spool;
  final int _threshold;

  /// The most of a reply that was on disk while the rest was held back.
  int spooledWhileStreaming = 0;

  int get _largestSpool => [
    for (final f in _spool.listSync().whereType<File>()) f.lengthSync(),
  ].fold(0, max);

  /// Long enough for any disk, and short of the transport's idle timeout, so
  /// a reply that never reaches the disk fails on the file and not the wait.
  Future<void> _awaitSpool() async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (_largestSpool < _threshold - _unspooledSlack &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    spooledWhileStreaming = max(spooledWhileStreaming, _largestSpool);
  }

  Stream<List<int>> _heldBack(Stream<List<int>> reply) async* {
    var delivered = 0;
    var held = false;
    await for (final chunk in reply) {
      for (var at = 0; at < chunk.length; at += _pieceBytes) {
        final piece = chunk.sublist(at, min(at + _pieceBytes, chunk.length));
        yield piece;
        delivered += piece.length;
        if (!held && delivered >= _threshold) {
          held = true;
          await _awaitSpool();
        }
      }
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    return http.StreamedResponse(
      _heldBack(response.stream),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}

Future<Digest> _sha1Of(File file) => sha1.bind(file.openRead()).first;

void main() {
  final skip = skipUnlessGit();

  ({
    GitBranchSession session,
    RecordingGitObjectStore store,
    _SpoolWatchingClient client,
    Directory spool,
  })
  restoringSession(Uri url, {required int watchAt}) {
    final spool = tempDirForTest('git_spool_');
    final client = _SpoolWatchingClient(http.Client(), spool, watchAt);
    final transport = GitHttpTransport(
      GitRemote(cloneUrl: url, username: 'u', token: 't'),
      client: client,
      spoolDirectory: spool,
    );
    final store = RecordingGitObjectStore(
      FileGitObjectStore(tempDirForTest('git_restore_store_')),
    );
    return (
      session: gitTestSession(url, transport: transport, store: store),
      store: store,
      client: client,
      spool: spool,
    );
  }

  test(
    'restores a backup of tens of MB without ever holding it whole',
    () async {
      final server = await startGitTestServer();
      await server.createBareRepo('sync');
      final backup = _backupFile(24 * _mb, 1);
      final peer = gitTestSession(server.repoUrl('sync'));
      await peer.open();
      await peer.commit(
        GitChange(puts: {'Submersion Backups/backup.db': GitPut.file(backup)}),
        messagePrefix: 'Backup',
      );

      final r = restoringSession(server.repoUrl('sync'), watchAt: 16 * _mb);
      await r.session.open();
      final restored = File(
        p.join(tempDirForTest('git_restored_').path, 'backup.db'),
      );
      await r.session.readFileTo('Submersion Backups/backup.db', restored);

      expect(await _sha1Of(restored), await _sha1Of(backup));
      expect(r.store.createdSizes, contains(24 * _mb));
      expect(
        r.store.largestWholeBody,
        lessThanOrEqualTo(kGitInMemoryObjectLimit),
      );
      expect(r.store.largestWriterChunk, lessThanOrEqualTo(_mb));
      expect(r.store.largestReaderChunk, lessThanOrEqualTo(_mb));
      // Two thirds of the reply was on disk before the last third arrived.
      expect(
        r.client.spooledWhileStreaming,
        greaterThanOrEqualTo(16 * _mb - _unspooledSlack),
      );
      expect(r.spool.listSync(), isEmpty);
      expect(File('${restored.path}.part').existsSync(), isFalse);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a large backup that arrives as a delta is rebuilt on disk',
    () async {
      // Without filters every blob comes with the tip, and stock git sends
      // the second of two near-identical backups as a delta of the first.
      final server = await startGitTestServer(allowFilter: false);
      await server.createBareRepo('sync');
      final first = _backupFile(12 * _mb, 2);
      final second = _backupFile(12 * _mb, 2, patchAt: 6 * _mb, patch: 4096);
      final peer = gitTestSession(server.repoUrl('sync'));
      await peer.open();
      await peer.commit(
        GitChange(
          puts: {
            'Submersion Backups/a/backup.db': GitPut.file(first),
            'Submersion Backups/b/backup.db': GitPut.file(second),
          },
        ),
        messagePrefix: 'Backup',
      );

      final r = restoringSession(server.repoUrl('sync'), watchAt: 8 * _mb);
      await r.session.open();
      // Opened while the fetched pack was read, before any file is copied
      // out (which opens each blob too).
      final openedByFetch = List.of(r.store.openedLengths);
      final dir = tempDirForTest('git_restored_');
      for (final (name, source) in [('a', first), ('b', second)]) {
        final restored = File(p.join(dir.path, '$name.db'));
        await r.session.readFileTo(
          'Submersion Backups/$name/backup.db',
          restored,
        );
        expect(await _sha1Of(restored), await _sha1Of(source), reason: name);
      }

      // A 12 MB base was opened to rebuild the other from the delta.
      expect(openedByFetch, contains(12 * _mb));
      // The reply is about 12 MB, the second backup being a small delta.
      expect(
        r.client.spooledWhileStreaming,
        greaterThanOrEqualTo(8 * _mb - _unspooledSlack),
      );
      expect(
        r.store.largestWholeBody,
        lessThanOrEqualTo(kGitInMemoryObjectLimit),
      );
      expect(r.store.largestWriterChunk, lessThanOrEqualTo(_mb));
      expect(r.store.largestReaderChunk, lessThanOrEqualTo(_mb));
      expect(r.spool.listSync(), isEmpty);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
