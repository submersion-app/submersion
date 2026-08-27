import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';

/// Request deadlines (#1175).
///
/// `S3ApiClient` was built on a bare `http.Client()`, whose underlying
/// `HttpClient` has no connect, response or read deadline. A stalled socket to
/// the S3 endpoint therefore parked its request FOREVER. Nothing above caps
/// concurrency on the store read path, so a media grid opens one such request
/// per visible tile: the gallery filled with permanent shimmer and the app
/// looked hung. `_sendWithRetry` already treats `TimeoutException` as a
/// retryable transport fault -- there was simply nothing that could produce
/// one.
S3Config config() => S3Config(
  endpoint: 'http://nas.local:9000',
  bucket: 'dive-sync',
  accessKeyId: 'ak',
  secretAccessKey: 'sk',
);

/// A client that accepts the request and then never answers, or answers its
/// headers and then never sends a body byte.
class _StallingClient extends http.BaseClient {
  _StallingClient({required this.stallBeforeHeaders});

  final bool stallBeforeHeaders;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (stallBeforeHeaders) {
      // Never completes: a half-open socket after the request was written.
      return Completer<http.StreamedResponse>().future;
    }
    // Headers arrive, then the body stream goes quiet forever.
    return http.StreamedResponse(
      StreamController<List<int>>().stream,
      200,
      contentLength: 1024,
    );
  }
}

void main() {
  S3ApiClient clientWith(_StallingClient stub) => S3ApiClient(
    config(),
    httpClient: stub,
    now: () => DateTime.utc(2026, 6, 9, 12),
    retryDelay: Duration.zero,
    maxAttempts: 2,
    responseTimeout: const Duration(milliseconds: 60),
    idleTimeout: const Duration(milliseconds: 60),
  );

  test('a response that never arrives gives up instead of hanging', () async {
    final client = clientWith(_StallingClient(stallBeforeHeaders: true));

    await expectLater(
      client.getObject('smv1/objects/abc'),
      throwsA(isA<CloudStorageException>()),
    );
  });

  test('a body that stops mid-stream gives up instead of hanging', () async {
    final client = clientWith(_StallingClient(stallBeforeHeaders: false));

    await expectLater(
      client.getObject('smv1/objects/abc'),
      throwsA(isA<CloudStorageException>()),
    );
  });

  test('an upload gets its own, far longer deadline', () async {
    // `Client.send` does not complete until the body has been written, so for
    // a PUT the "wait for a response" window contains the whole upload. An
    // 8 MiB multipart part on a weak link legitimately takes minutes, and
    // killing a part that was making progress is the failure mode that left
    // large first syncs failing nine times in ten (#942). A stalled upload
    // must still eventually give up -- just on a different clock.
    final stub = _StallingClient(stallBeforeHeaders: true);
    final client = S3ApiClient(
      config(),
      httpClient: stub,
      now: () => DateTime.utc(2026, 6, 9, 12),
      retryDelay: Duration.zero,
      maxAttempts: 1,
      // A read would be killed at 1ms; the upload must outlive it.
      responseTimeout: const Duration(milliseconds: 1),
      uploadTimeout: const Duration(milliseconds: 400),
      idleTimeout: const Duration(milliseconds: 400),
    );

    final started = DateTime.now();
    await expectLater(
      client.putObject('smv1/objects/abc', Uint8List.fromList([1, 2, 3])),
      throwsA(isA<CloudStorageException>()),
    );
    expect(
      DateTime.now().difference(started),
      greaterThan(const Duration(milliseconds: 200)),
      reason: 'the upload must not be cut off by the read deadline',
    );
  });

  test('a prompt response is unaffected by the deadlines', () async {
    final client = S3ApiClient(
      config(),
      httpClient: _EchoClient(),
      now: () => DateTime.utc(2026, 6, 9, 12),
      retryDelay: Duration.zero,
      responseTimeout: const Duration(milliseconds: 60),
      idleTimeout: const Duration(milliseconds: 60),
    );

    expect(await client.getObject('smv1/objects/abc'), Uint8List.fromList([7]));
  });
}

class _EchoClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream<List<int>>.value(const [7]),
        200,
        contentLength: 1,
      );
}
