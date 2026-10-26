import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/git/git_branch_session.dart';
import 'package:submersion/core/services/cloud_storage/git/git_http_transport.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_remote.dart';

import '../../../../helpers/git_cli.dart';
import '../../../../helpers/git_http_backend_server.dart';
import '../../../../helpers/git_test_session.dart';

/// Holds the next fetch until [release] completes, after saying so.
class _HeldFetchTransport extends GitHttpTransport {
  _HeldFetchTransport(super.remote);

  Completer<void>? _release;
  final Completer<void> reached = Completer<void>();

  Completer<void> holdNextFetch() => _release = Completer<void>();

  @override
  Future<void> fetch(
    List<GitObjectId> wants,
    GitObjectStore into, {
    int depth = 1,
    bool blobless = false,
    Set<GitObjectId> haves = const {},
  }) async {
    final release = _release;
    _release = null;
    if (release != null) {
      reached.complete();
      await release.future;
    }
    return super.fetch(
      wants,
      into,
      depth: depth,
      blobless: blobless,
      haves: haves,
    );
  }
}

void main() {
  final skip = skipUnlessGit();

  test('a slow refresh does not undo a commit that landed meanwhile', () async {
    final server = await startGitTestServer();
    await server.createBareRepo('sync');
    final transport = _HeldFetchTransport(
      GitRemote(cloneUrl: server.repoUrl('sync'), username: 'u', token: 't'),
    );
    final s = gitTestSession(server.repoUrl('sync'), transport: transport);
    await s.open();
    final peer = gitTestSession(server.repoUrl('sync'));
    await peer.open();
    await peer.commit(
      GitChange(puts: {'Submersion Sync/peer.json': gitText('peer')}),
      messagePrefix: 'Sync',
    );

    // A listing starts reading the peer's tip and stalls in its fetch.
    final release = transport.holdNextFetch();
    final slow = s.refresh();
    await transport.reached.future;
    // The sync commits meanwhile: stale, refreshed, landed on top.
    await s.commit(
      GitChange(puts: {'Submersion Sync/mine.json': gitText('mine')}),
      messagePrefix: 'Sync',
    );
    final landed = s.current!.tip;

    release.complete();
    final seen = await slow;
    expect(s.current!.tip, landed);
    expect(seen.tip, landed);
    expect(
      s.current!.index.entries.keys,
      containsAll(['Submersion Sync/peer.json', 'Submersion Sync/mine.json']),
    );
  }, skip: skip);
}
