@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/compute/compute_protocol.dart';
import 'package:submersion/core/platform/compute/compute_worker_client.dart';
import 'package:submersion/core/platform/zlib/platform_zlib.dart';

import '../web_test_assets.dart';

/// The compiled worker on corrupt deflate data: the vectors
/// platform_zlib_test.dart feeds the pure inflater on the VM, posted to
/// compute_worker.js, so a build flag that drops a bounds check shows here
/// as garbage or a hang instead of the error the app expects.
void main() {
  final previousAssetBase = ComputeWorkerClient.assetBase;
  setUpAll(() {
    ComputeWorkerClient.assetBase = kWebTestAssetBase;
  });
  // Put the statics back for whatever file the bundle runs next.
  tearDownAll(() {
    ComputeWorkerClient.assetBase = previousAssetBase;
  });

  Future<Object?> inflate(List<int> bytes, {int maxBytes = 4096}) =>
      ComputeWorkerClient.instance.call(ComputeJob.inflateBounded, {
        'bytes': Uint8List.fromList(bytes),
        'maxBytes': maxBytes,
        'framing': 'zlib',
      });

  test('a valid stream inflates in the worker', () async {
    final plain = Uint8List.fromList(List.generate(10000, (i) => i % 7));
    final packed = PlatformZlib.deflate(plain);
    expect(await inflate(packed, maxBytes: 20000), plain);
  });

  test('a back-reference before the start is a format error', () async {
    await expectLater(
      inflate([0x78, 0x9c, 0x03, 0x02, 0x00, 0x00, 0x00, 0x00, 0x01]),
      throwsA(isA<ZlibFormatException>()),
    );
  });

  test('a block producing output without input stops at the cap', () async {
    await expectLater(
      inflate([0x78, 0x9c, 0x05, 0, 0, 0, 0, 0, 0, 0]),
      throwsA(isA<ZlibBoundExceeded>()),
    );
  });

  test('a reserved block type is a format error', () async {
    await expectLater(
      inflate([0x78, 0x9c, 0x07, 0x00, 0, 0, 0, 0]),
      throwsA(isA<ZlibFormatException>()),
    );
  });

  test('garbage is a format error', () async {
    await expectLater(
      inflate(List.generate(64, (i) => (i * 97 + 13) & 0xff)),
      throwsA(isA<ZlibFormatException>()),
    );
  });
}
