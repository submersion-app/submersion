@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/compute/compute_worker_client.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_temp_files.dart';

import '../web_test_assets.dart';

/// The browser's sync temp files: written and read back through the compute
/// worker's OPFS jobs.
void main() {
  setUpAll(() {
    ComputeWorkerClient.assetBase = kWebTestAssetBase;
  });

  test('a 3 MiB file written in chunks reads back byte for byte', () async {
    final chunk = Uint8List.fromList(
      List.generate(1 << 20, (i) => (i * 31) & 0xff),
    );
    final sink = await SyncTempFiles.create('ssv1_base_web.json');
    for (var i = 0; i < 3; i++) {
      await sink.add(chunk);
    }
    await sink.writeAt(0, [7, 7, 7]);
    final path = await sink.close();
    expect(path, 'opfs://submersion-sync-tmp/ssv1_base_web.json');
    expect(await SyncTempFiles.exists(path), isTrue);
    expect(await SyncTempFiles.length(path), 3 << 20);
    expect(await SyncTempFiles.read(path, 0, 4), [7, 7, 7, chunk[3]]);
    var total = 0;
    var mismatch = false;
    await for (final piece in SyncTempFiles.openRead(path)) {
      for (var i = 0; i < piece.length; i++) {
        final expected = total + i < 3 ? 7 : chunk[(total + i) % chunk.length];
        if (piece[i] != expected) mismatch = true;
      }
      total += piece.length;
    }
    expect(total, 3 << 20);
    expect(mismatch, isFalse);
    await SyncTempFiles.delete(path);
    expect(await SyncTempFiles.exists(path), isFalse);
  });
}
