import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Test doubles for the Nominatim HTTP path of `LocationService`.
///
/// The geocoding paths talk to Nominatim through `dart:io HttpClient`, so the
/// only seam that does not require a real socket is [HttpOverrides]. Run the
/// code under test inside [FakeNominatim.run] and every request it makes is
/// captured for assertions.

/// One canned HTTP exchange plus a record of what the service actually sent.
///
/// The geocoding paths talk to Nominatim through `dart:io HttpClient`, so the
/// only seam that does not require a real socket is [HttpOverrides]. Every
/// request the service makes is captured here so the tests can assert on the
/// language the caller asked for (issue #1187), which must reach both the URI
/// and the request headers.
class FakeNominatim {
  FakeNominatim({
    this.statusCode = 200,
    this.body = '{}',
    this.bodyFor,
    this.statusFor,
  });

  final int statusCode;
  final String body;

  /// When set, wins over [body] for the given request.
  final String? Function(Uri uri)? bodyFor;

  /// When set, wins over [statusCode] for the given request.
  final int? Function(Uri uri)? statusFor;

  String bodyForUri(Uri uri) => bodyFor?.call(uri) ?? body;
  int statusForUri(Uri uri) => statusFor?.call(uri) ?? statusCode;

  final List<Uri> requestedUris = <Uri>[];
  final List<Map<String, String>> requestHeaders = <Map<String, String>>[];
  int clientCloseCount = 0;

  Uri get lastUri => requestedUris.last;
  Map<String, String> get lastHeaders => requestHeaders.last;

  /// Run [body] with every `HttpClient` replaced by this fake server.
  Future<T> run<T>(Future<T> Function() action) =>
      HttpOverrides.runZoned<Future<T>>(
        action,
        createHttpClient: (SecurityContext? _) => FakeHttpClient(this),
      );
}

class FakeHttpClient implements HttpClient {
  FakeHttpClient(this._server);

  final FakeNominatim _server;

  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    _server.requestedUris.add(url);
    return FakeHttpClientRequest(url, _server);
  }

  @override
  void close({bool force = false}) => _server.clientCloseCount++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class ThrowingHttpClient implements HttpClient {
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    throw const SocketException('offline');
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeHttpClientRequest implements HttpClientRequest {
  FakeHttpClientRequest(this.uri, this._server);

  final FakeNominatim _server;

  @override
  final Uri uri;

  @override
  final HttpHeaders headers = FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    _server.requestHeaders.add((headers as FakeHttpHeaders).values);
    return FakeHttpClientResponse(
      _server.statusForUri(uri),
      _server.bodyForUri(uri),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeHttpHeaders implements HttpHeaders {
  final Map<String, String> values = <String, String>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name.toLowerCase()] = '$value';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  FakeHttpClientResponse(this.statusCode, this._body);

  @override
  final int statusCode;

  final String _body;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(utf8.encode(_body)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
