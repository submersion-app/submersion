import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'fake_hosts.dart';

/// Whether [host] is this machine: `localhost` or a name under `.localhost`,
/// a loopback address such as 127.0.0.1, ::1 or ::ffff:127.0.0.1 (as text, an
/// IPv6 address possibly in brackets, or as an [InternetAddress]), or a Unix
/// domain socket.
bool isLoopbackHost(Object? host) {
  if (host is InternetAddress) return _isLoopbackAddress(host);
  if (host is! String) return false;
  var name = host.toLowerCase();
  if (name.endsWith('.')) name = name.substring(0, name.length - 1);
  if (name == 'localhost' || name.endsWith('.localhost')) return true;
  if (name.startsWith('[') && name.endsWith(']')) {
    name = name.substring(1, name.length - 1);
  }
  final address = InternetAddress.tryParse(name);
  return address != null && _isLoopbackAddress(address);
}

bool _isLoopbackAddress(InternetAddress address) {
  if (address.type == InternetAddressType.unix) return true;
  if (address.isLoopback) return true;
  // An IPv4 loopback address mapped into IPv6: ::ffff:127.x.y.z.
  final bytes = address.rawAddress;
  return address.type == InternetAddressType.IPv6 &&
      bytes.take(10).every((byte) => byte == 0) &&
      bytes[10] == 0xff &&
      bytes[11] == 0xff &&
      bytes[12] == 127;
}

/// The failure for a test that tried to reach [target] over the network.
StateError networkRefusal(String target) => StateError(
  'A test reached the network: $target. Tests must not depend on the '
  'network: inject a fake client, serve the response from a loopback '
  'HttpServer, or call loadPdfRoboto() for PDF fonts. See "Network, time '
  'limits and fonts" in docs/developer/testing.md.',
);

String _describe(Object? host) =>
    host is InternetAddress ? host.address : '$host';

/// The targets refused since the last [resetNetworkRefusals].
var _refused = const <String>[];

/// Whether the current test is refused the network on purpose.
var _refusalsExpected = false;

/// Records [target] as refused and returns the error to fail the call with.
StateError _refuse(String target) {
  _refused = [..._refused, target];
  return networkRefusal(target);
}

/// Records [target] as refused and returns the error to fail the call with,
/// for another part of the harness (fake_hosts.dart) that refuses a request.
StateError refuseNetwork(String target) => _refuse(target);

/// Starts a test with nothing refused and no refusal expected.
///
/// `test/flutter_test_config.dart` calls this before every test.
void resetNetworkRefusals() {
  _refused = const [];
  _refusalsExpected = false;
}

/// Declares that the current test is refused the network on purpose, as the
/// guard's own tests are, so [expectNoNetworkRefusals] lets it pass.
void expectNetworkRefusals() {
  _refusalsExpected = true;
}

/// Fails if the current test was refused the network and the refusal was
/// caught before it could fail the test.
///
/// Code under test that catches every error turns a refusal into a quiet
/// fallback, so the request would go unnoticed. `test/flutter_test_config.dart`
/// calls this after every test; it starts the next check clean either way.
void expectNoNetworkRefusals() {
  final refused = _refused;
  final expected = _refusalsExpected;
  resetNetworkRefusals();
  if (refused.isEmpty || expected) return;
  fail(
    'Code under this test tried to reach the network, and the refusal was '
    'caught before it could fail the test: ${refused.toSet().join(', ')}. '
    'Fake the service the code calls, or serve the response from a loopback '
    'HttpServer. See "Network, time limits and fonts" in '
    'docs/developer/testing.md.',
  );
}

/// Fails if a refusal was caught since the last test ended: in a setUpAll,
/// while a file declared its tests, or in work an earlier test left running.
/// A per-test check cannot see those, since they belong to no test.
///
/// `test/flutter_test_config.dart` calls this before every test; it starts
/// the test clean either way.
void expectNoNetworkRefusalsBeforeTest() {
  final refused = _refused;
  resetNetworkRefusals();
  if (refused.isEmpty) return;
  fail(
    'Code tried to reach the network before this test started, and the '
    'refusal was caught: ${refused.toSet().join(', ')}. It ran in a setUpAll, '
    'while a file declared its tests, or in work an earlier test left '
    'running. Declare the host with serveFakeHost in setUpAll, or fake the '
    'service. See "Network, time limits and fonts" in '
    'docs/developer/testing.md.',
  );
}

/// Real [HttpClient]s that can only reach this machine.
///
/// HttpClient asks findProxy for every request's URL before it opens a
/// connection, and turns a throw there into that request's error. Refusing
/// there leaves TLS, certificates and everything else about the client as
/// they are.
class BlockedNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _RoutingHttpClient(super.createHttpClient(context));
}

/// The proxy lookup every client uses: loopback goes direct, anything else is
/// refused. [chosen] is a lookup the caller set, which still gets its say for
/// loopback.
String Function(Uri) _guardedProxy([String Function(Uri)? chosen]) => (uri) {
  if (!isLoopbackHost(uri.host)) throw _refuse('$uri');
  return chosen?.call(uri) ?? 'DIRECT';
};

/// A real [HttpClient] that answers declared fake hosts (fake_hosts.dart) from
/// memory, and otherwise can only reach this machine. A caller that sets its
/// own findProxy cannot lift the refusal.
class _RoutingHttpClient implements HttpClient {
  _RoutingHttpClient(this._inner) {
    _inner.findProxy = _guardedProxy();
  }

  final HttpClient _inner;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      isFakeHost(url.host)
      ? Future.value(FakeHostClientRequest(method, url))
      : _inner.openUrl(method, url);

  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) {
    // Built from parts, not a string, so an IPv6 host needs no brackets.
    final target = Uri.parse(path);
    return openUrl(
      method,
      Uri(
        scheme: 'http',
        host: host,
        port: port,
        path: target.path,
        query: target.hasQuery ? target.query : null,
      ),
    );
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      open('GET', host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      open('POST', host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      open('PUT', host, port, path);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      open('DELETE', host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      open('PATCH', host, port, path);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      open('HEAD', host, port, path);

  @override
  set findProxy(String Function(Uri url)? f) =>
      _inner.findProxy = _guardedProxy(f);

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
  set authenticateProxy(
    Future<bool> Function(String host, int port, String scheme, String? realm)?
    f,
  ) => _inner.authenticateProxy = f;

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
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) => _inner.badCertificateCallback = callback;

  @override
  set keyLog(Function(String line)? callback) => _inner.keyLog = callback;

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) => _inner.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) => _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  void close({bool force = false}) => _inner.close(force: force);
}

/// Sockets that can only reach this machine.
///
/// Covers `Socket.connect` and `Socket.startConnect`. A secure socket connects
/// below this hook, so an HTTPS request is refused by
/// [BlockedNetworkHttpOverrides] instead, and a TLS socket opened directly with
/// `SecureSocket.connect` is not refused at all; nothing in lib/ opens one.
final class BlockedNetworkIOOverrides extends IOOverrides {
  @override
  Future<Socket> socketConnect(
    host,
    int port, {
    sourceAddress,
    int sourcePort = 0,
    Duration? timeout,
  }) {
    if (!isLoopbackHost(host)) {
      return Future.error(_refuse('${_describe(host)}:$port'));
    }
    return super.socketConnect(
      host,
      port,
      sourceAddress: sourceAddress,
      sourcePort: sourcePort,
      timeout: timeout,
    );
  }

  @override
  Future<ConnectionTask<Socket>> socketStartConnect(
    host,
    int port, {
    sourceAddress,
    int sourcePort = 0,
  }) {
    if (!isLoopbackHost(host)) {
      return Future.error(_refuse('${_describe(host)}:$port'));
    }
    return super.socketStartConnect(
      host,
      port,
      sourceAddress: sourceAddress,
      sourcePort: sourcePort,
    );
  }
}

/// The instances the harness installs. The global-state snapshot compares by
/// identity, so the same objects are installed every time.
final blockedNetworkHttpOverrides = BlockedNetworkHttpOverrides();
final blockedNetworkIOOverrides = BlockedNetworkIOOverrides();
