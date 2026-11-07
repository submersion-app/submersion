import 'dart:async';
import 'dart:io';

/// An [HttpClient] that holds every request it opens until the app's
/// startup proxy lookup settles, then hands it to [_inner] (#4246).
///
/// Launch no longer waits for the lookup before the first frame, but dart:io
/// picks DIRECT or a proxy synchronously when a request is opened, so a
/// request opened before the answer arrived would go out on the wrong route.
/// Opening a request is already asynchronous, which makes it the one place
/// the wait can go: the caller's future just completes a little later, and
/// findProxy then reads the settled snapshot.
///
/// Every setting is passed straight through, so the wait changes nothing
/// but when a request starts. [_pending] returns null once the lookup has
/// settled, after which requests open at once.
class StartupGatedHttpClient implements HttpClient {
  StartupGatedHttpClient(this._inner, this._pending);

  final HttpClient _inner;
  final Future<void>? Function() _pending;

  /// Set by a plain [close] made while requests may still be waiting; the
  /// real client closes once they have opened.
  bool _closing = false;

  Future<HttpClientRequest> _afterStartup(
    Future<HttpClientRequest> Function() open,
  ) {
    if (_closing) {
      return Future.error(StateError('HttpClient is closed'));
    }
    final pending = _pending();
    return pending == null ? open() : pending.then((_) => open());
  }

  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) => _afterStartup(() => _inner.open(method, host, port, path));

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      _afterStartup(() => _inner.openUrl(method, url));

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      _afterStartup(() => _inner.get(host, port, path));

  @override
  Future<HttpClientRequest> getUrl(Uri url) =>
      _afterStartup(() => _inner.getUrl(url));

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      _afterStartup(() => _inner.post(host, port, path));

  @override
  Future<HttpClientRequest> postUrl(Uri url) =>
      _afterStartup(() => _inner.postUrl(url));

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      _afterStartup(() => _inner.put(host, port, path));

  @override
  Future<HttpClientRequest> putUrl(Uri url) =>
      _afterStartup(() => _inner.putUrl(url));

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      _afterStartup(() => _inner.delete(host, port, path));

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) =>
      _afterStartup(() => _inner.deleteUrl(url));

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      _afterStartup(() => _inner.patch(host, port, path));

  @override
  Future<HttpClientRequest> patchUrl(Uri url) =>
      _afterStartup(() => _inner.patchUrl(url));

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      _afterStartup(() => _inner.head(host, port, path));

  @override
  Future<HttpClientRequest> headUrl(Uri url) =>
      _afterStartup(() => _inner.headUrl(url));

  @override
  Duration get idleTimeout => _inner.idleTimeout;
  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? value) => _inner.maxConnectionsPerHost = value;

  @override
  bool get autoUncompress => _inner.autoUncompress;
  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;

  @override
  String? get userAgent => _inner.userAgent;
  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  set authenticate(
    Future<bool> Function(Uri url, String scheme, String? realm)? f,
  ) => _inner.authenticate = f;

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) => _inner.addCredentials(url, realm, credentials);

  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(
      Uri url,
      String? proxyHost,
      int? proxyPort,
    )?
    f,
  ) => _inner.connectionFactory = f;

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  @override
  set authenticateProxy(
    Future<bool> Function(String host, int port, String scheme, String? realm)?
    f,
  ) => _inner.authenticateProxy = f;

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) => _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) => _inner.badCertificateCallback = callback;

  @override
  set keyLog(Function(String line)? callback) => _inner.keyLog = callback;

  /// A plain close lets requests already opened finish, as dart:io's does,
  /// so one still waiting for the startup lookup opens before the real
  /// client closes; requests opened after it are refused. A forced close
  /// goes through at once and fails the waiting requests.
  @override
  void close({bool force = false}) {
    final pending = _pending();
    if (force || pending == null) {
      _inner.close(force: force);
      return;
    }
    _closing = true;
    // Registered after every waiting request's open, so it runs after them.
    unawaited(pending.then((_) => _inner.close()));
  }
}
