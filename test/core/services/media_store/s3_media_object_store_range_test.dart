import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/media_store/s3_media_object_store.dart';

/// The chunked-download loop's termination guarantee (#1175).
///
/// `getFile` advanced its cursor by `range.bytes.length`. A server that
/// answers a Range request with an empty body -- a misbehaving proxy, an
/// object truncated between the HEAD and the GET, an S3-compatible
/// implementation that ignores the Range header on a zero-byte read -- leaves
/// the cursor where it was, so `while (received < total)` re-issued the exact
/// same request forever. Each pass awaits, so the isolate keeps turning and
/// the app never crashes; it just downloads nothing, at full speed, until the
/// user kills it.
class _EmptyRangeClient extends S3ApiClient {
  _EmptyRangeClient({required this.objectSize})
    : super(
        S3Config(
          endpoint: 'http://localhost:9000',
          bucket: 'test-bucket',
          accessKeyId: 'AK',
          secretAccessKey: 'SK',
        ),
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

  final int objectSize;
  int rangeCalls = 0;

  @override
  Future<S3ObjectInfo?> headObject(String key) async => S3ObjectInfo(
    key: key,
    lastModified: DateTime.utc(2026),
    size: objectSize,
  );

  @override
  Future<({Uint8List bytes, int totalLength})> getObjectRange(
    String key, {
    required int start,
    required int endInclusive,
  }) async {
    rangeCalls++;
    return (bytes: Uint8List(0), totalLength: objectSize);
  }
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('s3_range_test');
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('an empty range response fails instead of looping forever', () async {
    // Larger than downloadChunkBytes, so getFile takes the chunked branch.
    final client = _EmptyRangeClient(objectSize: 32 * 1024 * 1024);
    final store = S3MediaObjectStore(client: client, keyPrefix: '');
    final destination = File('${root.path}${Platform.pathSeparator}out.bin');

    await expectLater(
      store.getFile('smv1/objects/abc', destination),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.kind,
          'kind',
          // Retryable: a bad answer from the network path, not a permanent
          // property of the object.
          MediaStoreErrorKind.transient,
        ),
      ),
    );
    expect(
      client.rangeCalls,
      lessThan(5),
      reason: 'the loop must stop at the first chunk that makes no progress',
    );
  });
}
