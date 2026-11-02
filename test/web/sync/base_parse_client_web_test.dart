@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/compute/compute_worker_client.dart';
import 'package:submersion/core/services/sync/changeset_log/base_parse_client.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_temp_files.dart';

import '../web_test_assets.dart';

/// The browser's base parse client over the compute worker: a fixture base
/// written to OPFS, pass one for the scalars and deletions, pass two for
/// two tables in batches, then dispose.
void main() {
  setUpAll(() {
    ComputeWorkerClient.assetBase = kWebTestAssetBase;
  });

  final doc = {
    'exportedAt': 1700000000123,
    'deletions': {
      'dives': [
        {'id': 'gone', 'deletedAt': 4},
      ],
    },
    'data': {
      'dives': [
        for (var i = 0; i < 1203; i++) {'id': 'd$i', 'maxDepth': i},
      ],
      'tanks': [
        {'id': 't1', 'diveId': 'd0'},
      ],
      'sites': [
        {'id': 's1'},
      ],
    },
  };

  test('reads scalars, then streams the requested tables in batches', () async {
    final sink = await SyncTempFiles.create('ssv1_peer_base.json');
    await sink.add(utf8.encode(jsonEncode(doc)));
    final path = await sink.close();
    addTearDown(() => SyncTempFiles.delete(path));

    final progress = <int>[];
    final client = await BaseParseClient.spawn(
      path,
      onProgress: (bytes, total) => progress.add(bytes),
    );
    final scalars = await client.readScalarsAndDeletions();
    expect(scalars.exportedAt, 1700000000123);
    expect(scalars.deletions.single.table, 'dives');
    expect(scalars.deletions.single.row['id'], 'gone');

    client.startDataRows({'dives', 'tanks'});
    var rows = 0;
    var batches = 0;
    while (true) {
      final batch = await client.nextDataBatch();
      if (batch == null) break;
      batches++;
      rows += batch.length;
      expect(
        batch.every((r) => r.table == 'dives' || r.table == 'tanks'),
        isTrue,
      );
    }
    expect(rows, 1204);
    expect(batches, greaterThanOrEqualTo(3));
    expect(progress, isNotEmpty);
    await client.dispose();
  });
}
