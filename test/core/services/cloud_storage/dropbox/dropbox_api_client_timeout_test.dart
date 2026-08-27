import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_api_client.dart';
import 'package:submersion/core/services/cloud_storage/http_timeouts.dart';

/// Request deadlines on the Dropbox transport (#1279).
///
/// The client used to default to a bare `http.Client()`, so a wedged socket
/// parked its request forever -- on the sync path and, through
/// `DropboxMediaObjectStore`, on the media transfer queue, where a single
/// stuck entry froze the sequential drain (#1270).

/// A client that accepts the request and then never answers, or answers its
/// headers and then never sends a body byte.
class _StallingClient extends http.BaseClient {
  _StallingClient({required this.stallBeforeHeaders});

  final bool stallBeforeHeaders;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (stallBeforeHeaders) {
      return Completer<http.StreamedResponse>().future;
    }
    return http.StreamedResponse(
      StreamController<List<int>>().stream,
      200,
      contentLength: 1024,
    );
  }
}

void main() {
  DropboxApiClient clientOver(http.Client transport) => DropboxApiClient(
    getAccessToken: () async => 'token',
    onAccessTokenRejected: () {},
    httpClient: transport,
  );

  DropboxApiClient stalling({required bool beforeHeaders}) => clientOver(
    TimeoutHttpClient(
      _StallingClient(stallBeforeHeaders: beforeHeaders),
      responseTimeout: const Duration(milliseconds: 60),
      uploadTimeout: const Duration(milliseconds: 60),
      idleTimeout: const Duration(milliseconds: 60),
    ),
  );

  test(
    'a response that never arrives surfaces as a reachability error',
    () async {
      await expectLater(
        stalling(beforeHeaders: true).getMetadata('/db.sqlite'),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            'Could not reach Dropbox',
          ),
        ),
      );
    },
  );

  test('a body that stops mid-stream surfaces the same way', () async {
    await expectLater(
      stalling(beforeHeaders: false).download('/db.sqlite'),
      throwsA(isA<CloudStorageException>()),
    );
  });

  test('an upload that stalls gives up instead of hanging', () async {
    await expectLater(
      stalling(beforeHeaders: true).upload('/db.sqlite', Uint8List(8)),
      throwsA(isA<CloudStorageException>()),
    );
  });

  test('the default transport carries deadlines', () {
    // The whole point of #1279: a client nobody handed a transport to must
    // not fall back to a bare http.Client().
    final client = DropboxApiClient(
      getAccessToken: () async => 'token',
      onAccessTokenRejected: () {},
    );
    addTearDown(client.close);

    final transport = client.transport;
    expect(transport, isA<TimeoutHttpClient>());
    expect(
      (transport as TimeoutHttpClient).connectTimeout,
      TimeoutHttpClient.defaultConnectTimeout,
    );
  });

  test('an injected transport is left exactly as the caller built it', () {
    final injected = _StallingClient(stallBeforeHeaders: true);
    final client = clientOver(injected);

    expect(client.transport, same(injected));
  });
}
