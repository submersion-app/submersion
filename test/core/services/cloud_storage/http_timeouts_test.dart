import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:submersion/core/services/cloud_storage/http_timeouts.dart';

/// Request deadlines for the non-S3 cloud transports (#1279).
///
/// `S3ApiClient` was the only transport in the app with deadlines. Dropbox and
/// Google Drive both fell back to a bare `http.Client()`, which on Dart IO
/// leaves `HttpClient.connectionTimeout` null and adds no response or read
/// deadline at all, so a socket that connected and then wedged parked its
/// request forever. In the media pipeline that showed up as a queue entry
/// stuck in `transferring` (#1270).
///
/// [TimeoutHttpClient] is the shared piece: a decorator any client can be
/// wrapped in, so the deadline policy lives in one place rather than being
/// re-derived per transport.

/// A client that accepts the request and then never answers, or answers its
/// headers and then never sends a body byte.
class _StallingClient extends http.BaseClient {
  _StallingClient({required this.stallBeforeHeaders});

  final bool stallBeforeHeaders;
  final List<http.BaseRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
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

class _EchoClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream<List<int>>.value(const [7]),
        200,
        contentLength: 1,
        headers: const {'x-echo': 'yes'},
        reasonPhrase: 'OK',
      );

  @override
  void close() => closed = true;
}

/// A request whose length is unknown until it is written, which is what
/// googleapis' own `RequestImpl` produces for every call it makes.
class _UnsizedRequest extends http.BaseRequest {
  _UnsizedRequest(super.method, super.url);

  @override
  http.ByteStream finalize() {
    super.finalize();
    return const http.ByteStream(Stream<List<int>>.empty());
  }
}

void main() {
  TimeoutHttpClient wrap(
    http.Client inner, {
    Duration response = const Duration(milliseconds: 60),
    Duration upload = const Duration(milliseconds: 400),
    Duration idle = const Duration(milliseconds: 60),
  }) => TimeoutHttpClient(
    inner,
    responseTimeout: response,
    uploadTimeout: upload,
    idleTimeout: idle,
  );

  http.Request get(String url) => http.Request('GET', Uri.parse(url));

  test('a response that never arrives gives up instead of hanging', () async {
    final client = wrap(_StallingClient(stallBeforeHeaders: true));

    await expectLater(
      client.send(get('https://example.test/a')),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('a body that stops mid-stream gives up instead of hanging', () async {
    final client = wrap(_StallingClient(stallBeforeHeaders: false));

    final streamed = await client.send(get('https://example.test/a'));

    await expectLater(
      streamed.stream.toBytes(),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('an upload gets its own, far longer deadline', () async {
    // `Client.send` does not complete until the body has been written, so for
    // a PUT the "wait for a response" window contains the whole upload. An
    // 8 MiB chunk on a weak link legitimately takes minutes, and killing one
    // that was making progress is the failure mode the S3 client's own
    // deadlines were tuned to avoid (#942).
    final client = wrap(
      _StallingClient(stallBeforeHeaders: true),
      response: const Duration(milliseconds: 1),
      upload: const Duration(milliseconds: 300),
    );
    final request = http.Request('PUT', Uri.parse('https://example.test/a'))
      ..bodyBytes = Uint8List(TimeoutHttpClient.uploadBodyThresholdBytes + 1);

    final started = DateTime.now();
    await expectLater(client.send(request), throwsA(isA<TimeoutException>()));

    expect(
      DateTime.now().difference(started),
      greaterThan(const Duration(milliseconds: 150)),
      reason: 'the upload must not be cut off by the read deadline',
    );
  });

  test('a small POST body stays on the short response deadline', () async {
    // A Dropbox RPC carries a few dozen bytes of JSON. Writing that is not an
    // upload, so a wedged one must fail in seconds, not in the ten minutes a
    // real multi-megabyte transfer is allowed.
    final client = wrap(
      _StallingClient(stallBeforeHeaders: true),
      response: const Duration(milliseconds: 60),
      upload: const Duration(seconds: 30),
    );
    final request = http.Request('POST', Uri.parse('https://example.test/a'))
      ..body = '{"path":"/x"}';

    await expectLater(client.send(request), throwsA(isA<TimeoutException>()));
  });

  test('an unsized non-GET request is treated as an upload', () async {
    // googleapis' RequestImpl never sets contentLength, upload or not, so a
    // length-only rule would put a multi-megabyte Drive upload on the 30s
    // response deadline and start killing healthy transfers.
    final client = wrap(
      _StallingClient(stallBeforeHeaders: true),
      response: const Duration(milliseconds: 1),
      upload: const Duration(milliseconds: 300),
    );

    final started = DateTime.now();
    await expectLater(
      client.send(_UnsizedRequest('POST', Uri.parse('https://example.test/a'))),
      throwsA(isA<TimeoutException>()),
    );

    expect(
      DateTime.now().difference(started),
      greaterThan(const Duration(milliseconds: 150)),
    );
  });

  test('an unsized GET stays on the short response deadline', () async {
    final client = wrap(
      _StallingClient(stallBeforeHeaders: true),
      response: const Duration(milliseconds: 60),
      upload: const Duration(seconds: 30),
    );

    await expectLater(
      client.send(_UnsizedRequest('GET', Uri.parse('https://example.test/a'))),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('a prompt response passes through untouched', () async {
    final client = wrap(_EchoClient());

    final streamed = await client.send(get('https://example.test/a'));

    expect(streamed.statusCode, 200);
    expect(streamed.contentLength, 1);
    expect(streamed.headers['x-echo'], 'yes');
    expect(streamed.reasonPhrase, 'OK');
    expect(await streamed.stream.toBytes(), Uint8List.fromList([7]));
  });

  test('closing the wrapper closes the client underneath it', () {
    final inner = _EchoClient();

    wrap(inner).close();

    expect(inner.closed, isTrue);
  });

  test('the socket-backed factory bounds the TCP connect itself', () {
    // The deadlines above bound a socket that connects and then stalls. A
    // bare http.Client() leaves HttpClient.connectionTimeout null, so one
    // that never connects waits on the OS default -- minutes on some Windows
    // configurations.
    final client = TimeoutHttpClient.overSockets(
      connectTimeout: const Duration(seconds: 3),
    );
    addTearDown(client.close);

    expect(client.connectTimeout, const Duration(seconds: 3));
  });

  test('the defaults match the deadlines the S3 client settled on', () {
    expect(
      TimeoutHttpClient.defaultConnectTimeout,
      const Duration(seconds: 15),
    );
    expect(
      TimeoutHttpClient.defaultResponseTimeout,
      const Duration(seconds: 30),
    );
    expect(TimeoutHttpClient.defaultUploadTimeout, const Duration(minutes: 10));
    expect(TimeoutHttpClient.defaultIdleTimeout, const Duration(seconds: 30));
  });
}
