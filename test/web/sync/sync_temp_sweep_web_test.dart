@TestOn('browser')
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/compute/compute_worker_client.dart';
import 'package:submersion/core/platform/cross_tab_lock.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_temp_files.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_temp_sweep.dart';

import '../web_test_assets.dart';

/// The launch sweep in a browser: leftover sync temp files in the origin
/// private file system go, unless a sync holds the cross-tab lock, in which
/// case the sweep stands aside for the next launch.
void main() {
  final previousAssetBase = ComputeWorkerClient.assetBase;
  setUpAll(() {
    ComputeWorkerClient.assetBase = kWebTestAssetBase;
  });
  // Put the statics back for whatever file the bundle runs next.
  tearDownAll(() {
    ComputeWorkerClient.assetBase = previousAssetBase;
  });

  Future<String> leftover(String name) async {
    final sink = await SyncTempFiles.create(name);
    await sink.add([1, 2, 3]);
    return sink.close();
  }

  test('clears a leftover base', () async {
    final path = await leftover('ssv1_base_leftover.json');
    await sweepLeftoverSyncTempFiles();
    expect(await SyncTempFiles.exists(path), isFalse);
  });

  test('stands aside while a sync holds the lock', () async {
    final path = await leftover('ssv1_peer_leftover.json');
    final release = Completer<void>();
    final sync = withCrossTabLock(kSyncCrossTabLock, () => release.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sweepLeftoverSyncTempFiles();
    expect(await SyncTempFiles.exists(path), isTrue);
    release.complete();
    await sync;
    await sweepLeftoverSyncTempFiles();
    expect(await SyncTempFiles.exists(path), isFalse);
  });
}
