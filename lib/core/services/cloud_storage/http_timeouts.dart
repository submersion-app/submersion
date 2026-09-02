import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// An [http.Client] decorator that gives every request a deadline (#1279).
///
/// A bare `http.Client()` has none. On Dart IO it leaves
/// `HttpClient.connectionTimeout` null, so a TCP connect to an unreachable
/// endpoint waits on the OS default -- minutes on some Windows configurations
/// -- and it adds no response or read deadline at all, so a socket that
/// connects and then wedges parks its request forever. The media transfer
/// queue is sequential and single-flight, so one such request used to freeze
/// the whole drain (#1270).
///
/// Wrap a transport in this and both halves are covered: [overSockets] bounds
/// a connection that never establishes, and [send] bounds one that establishes
/// and then goes quiet.
///
/// `S3ApiClient` applies the same four deadlines inline rather than through
/// this wrapper. It interleaves them with its own SigV4 retry loop, which
/// classifies `TimeoutException` as a retryable transport fault and replays
/// the request; unpicking that is a change to a well-covered path with no
/// behaviour to gain. The constants here are deliberately its constants.
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient(
    this._inner, {
    this.responseTimeout = defaultResponseTimeout,
    this.uploadTimeout = defaultUploadTimeout,
    this.idleTimeout = defaultIdleTimeout,
    this.connectTimeout,
  });

  /// A wrapper over a fresh IO transport whose TCP connect is bounded too.
  ///
  /// This is the constructor callers want unless they are decorating a client
  /// somebody else built (an OAuth refreshing client, say), which cannot have
  /// its socket layer reconfigured after the fact.
  factory TimeoutHttpClient.overSockets({
    Duration connectTimeout = defaultConnectTimeout,
    Duration responseTimeout = defaultResponseTimeout,
    Duration uploadTimeout = defaultUploadTimeout,
    Duration idleTimeout = defaultIdleTimeout,
  }) => TimeoutHttpClient(
    IOClient(HttpClient()..connectionTimeout = connectTimeout),
    responseTimeout: responseTimeout,
    uploadTimeout: uploadTimeout,
    idleTimeout: idleTimeout,
    connectTimeout: connectTimeout,
  );

  /// How long to wait for the TCP connection itself.
  static const Duration defaultConnectTimeout = Duration(seconds: 15);

  /// How long to wait for a response's status and headers on a request that
  /// carries no meaningful body. Covers TLS setup and the server's own think
  /// time.
  static const Duration defaultResponseTimeout = Duration(seconds: 30);

  /// The same deadline for a request that CARRIES a body.
  ///
  /// Separate and far more generous, because `Client.send` does not complete
  /// until the body has been written: for a PUT the "wait for a response"
  /// window contains the whole upload. A media chunk is 8 MiB, which at
  /// 110 kbps takes ten minutes, and killing a transfer that was making
  /// progress is exactly the failure mode that left large first syncs failing
  /// nine times in ten (#942). Ten minutes still bounds a socket that has
  /// genuinely wedged, which is all this needs to do.
  static const Duration defaultUploadTimeout = Duration(minutes: 10);

  /// How long a response body may go without delivering a single byte.
  ///
  /// Deliberately an IDLE gap rather than a total budget: a legitimate 8 MiB
  /// download over a weak mobile link takes minutes and must not be killed,
  /// while a connection that has stopped delivering is dead regardless of how
  /// little it had left to send.
  static const Duration defaultIdleTimeout = Duration(seconds: 30);

  /// Above this many declared body bytes a request is treated as an upload.
  ///
  /// A Dropbox RPC POSTs a few dozen bytes of JSON; writing that is not a
  /// transfer, and a wedged one should fail on the seconds-scale response
  /// deadline rather than sit for the ten minutes a real multi-megabyte
  /// upload is allowed. 64 KiB is comfortably above every control-plane body
  /// the app sends and far below the smallest chunk it uploads.
  static const int uploadBodyThresholdBytes = 64 * 1024;

  /// Methods that do not carry a body, used to classify a request whose
  /// length is unknown until it is written.
  static const Set<String> _bodilessMethods = {'GET', 'HEAD', 'DELETE'};

  final http.Client _inner;

  /// Deadline for a response's status and headers, on a request with no
  /// meaningful body.
  final Duration responseTimeout;

  /// The same deadline for a request whose body has to be written first.
  final Duration uploadTimeout;

  /// Longest gap the response body may go without delivering a byte.
  final Duration idleTimeout;

  /// Connect deadline configured on the transport this wrapper owns, or null
  /// when the inner client came from the caller and its socket layer is not
  /// ours to configure.
  final Duration? connectTimeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner
        .send(request)
        .timeout(_carriesUpload(request) ? uploadTimeout : responseTimeout);
    return http.StreamedResponse(
      response.stream.timeout(idleTimeout),
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

  /// Whether [request] should get the generous body-carrying deadline.
  ///
  /// A declared length settles it. When there is none the method decides,
  /// because googleapis' own `RequestImpl` never sets `contentLength` --
  /// upload or not -- so a length-only rule would put every Drive upload on
  /// the short response deadline and start killing healthy transfers.
  static bool _carriesUpload(http.BaseRequest request) {
    final length = request.contentLength;
    if (length != null) return length > uploadBodyThresholdBytes;
    return !_bodilessMethods.contains(request.method.toUpperCase());
  }
}
