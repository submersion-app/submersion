import 'package:http/http.dart' as http;

/// A transport with the real [http.IOClient] lifecycle: every request after
/// [close] throws, exactly as an authenticator's client does once a re-auth
/// has torn it down.
///
/// `MockClient` cannot model this on its own. It does not override `close`,
/// so it inherits `BaseClient`'s no-op and a "closed" MockClient keeps
/// answering requests - which would let a captured-client bug pass a test
/// silently. Wrap the fake in one of these and close the wrapper instead.
class RevocableClient extends http.BaseClient {
  RevocableClient(this._inner);

  final http.Client _inner;
  bool _closed = false;

  bool get isClosed => _closed;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (_closed) {
      throw http.ClientException(
        'HTTP request failed. Client is already closed.',
        request.url,
      );
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _closed = true;
    _inner.close();
  }
}
