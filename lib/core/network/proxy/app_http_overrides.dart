import 'dart:async';
import 'dart:io';

import 'package:submersion/core/network/app_security_context.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/proxy_routing.dart';
import 'package:submersion/core/network/proxy/socks5_connector.dart';

/// The dart:io proxy directive for [proxy]: `DIRECT`, or
/// `PROXY [user:pass@]host:port`.
///
/// Credentials go in the directive because it is the only way dart:io
/// authenticates a CONNECT tunnel (HTTPS through an HTTP proxy): it sends
/// them as Basic, up front, and never calls `authenticateProxy` for a tunnel.
/// checkProxyCredentials rejects the values this format cannot carry.
String proxyDirective(EffectiveProxy proxy) {
  if (proxy.kind != ProxyKind.http) return 'DIRECT';
  final user = proxy.username;
  final auth = user == null ? '' : '$user:${proxy.password ?? ''}@';
  return 'PROXY $auth${proxy.endpoint}';
}

/// The app's one hook into every HttpClient the Dart VM creates: flutter_map
/// and FMTC tiles, NetworkImage, and every package:http client included.
/// Overrides are per isolate, so a spawned isolate has none until
/// ensureIsolateHttpOverrides installs them there.
///
/// It keeps the Windows trust fix (the platform-trusted SecurityContext from
/// [appSecurityContext], which Dart's bundled BoringSSL cannot otherwise
/// read) and routes each connection by the proxy snapshot [currentProxy]
/// returns at connection time, so a settings or network change reaches
/// long-lived clients on their next connection.
///
/// HTTP proxies use dart:io's own forwarding and CONNECT tunnels via
/// findProxy. SOCKS5 has no dart:io support, so findProxy says DIRECT and the
/// connectionFactory opens the tunnel itself, adding TLS for https.
class AppHttpOverrides extends HttpOverrides {
  AppHttpOverrides({
    required EffectiveProxy Function() currentProxy,
    ProxyRoutingPolicy shouldProxy = defaultShouldProxy,
    SecurityContext? Function() fallbackContext = appSecurityContext,
  }) : _currentProxy = currentProxy,
       _shouldProxy = shouldProxy,
       _fallbackContext = fallbackContext;

  /// Per-client certificate checks set with [setBadCertificateCallback].
  static final Expando<BadCertificateCallback> _badCertificateCallbacks =
      Expando('badCertificateCallback');

  /// Lets [client] accept a certificate that fails normal verification
  /// when [callback] returns true.
  ///
  /// `HttpClient.badCertificateCallback` alone is not enough here: dart:io
  /// consults it only when it opens the TLS socket itself, and this class's
  /// connection factory opens the socket for direct and SOCKS5 connections.
  /// The callback is stored for the factory as well as set on the client,
  /// which still covers the HTTP-proxy path, where dart:io runs TLS through
  /// the CONNECT tunnel, and clients this class did not create.
  static void setBadCertificateCallback(
    HttpClient client,
    BadCertificateCallback callback,
  ) {
    client.badCertificateCallback = callback;
    _badCertificateCallbacks[client] = callback;
  }

  final EffectiveProxy Function() _currentProxy;
  final ProxyRoutingPolicy _shouldProxy;
  final SecurityContext? Function() _fallbackContext;

  /// The proxy snapshot new connections use right now.
  EffectiveProxy get currentProxy => _currentProxy();

  /// The dart:io directive for [url] under [proxy]. SOCKS5 is DIRECT here:
  /// the connection factory opens that tunnel, not dart:io.
  String _directiveFor(Uri url, EffectiveProxy proxy) {
    if (proxy.kind != ProxyKind.http || !_shouldProxy(url, proxy)) {
      return 'DIRECT';
    }
    return proxyDirective(proxy);
  }

  /// The proxy for a client this class did not create.
  ///
  /// Every client from [createHttpClient] has its own findProxy, so this is
  /// reached by clients built before these overrides were installed, which
  /// is how FMTC's download isolates build theirs (#3269): dart:io's default
  /// findProxy is [HttpClient.findProxyFromEnvironment], which defers here on
  /// every request. The app's proxy settings replace the environment's.
  ///
  /// Such a client has no connection factory, so it cannot open a SOCKS5
  /// tunnel. The request is refused rather than sent around the proxy the
  /// user chose.
  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) {
    final proxy = _currentProxy();
    if (proxy.kind == ProxyKind.socks5 && _shouldProxy(url, proxy)) {
      throw HttpException(
        'This connection cannot use the SOCKS5 proxy, so it was not made',
        uri: url,
      );
    }
    return _directiveFor(url, proxy);
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final effectiveContext = context ?? _fallbackContext();
    final client = super.createHttpClient(effectiveContext);
    client.findProxy = (url) => _directiveFor(url, _currentProxy());
    client.connectionFactory = (url, proxyHost, proxyPort) =>
        _connect(url, proxyHost, proxyPort, effectiveContext, client);
    return client;
  }

  Future<ConnectionTask<Socket>> _connect(
    Uri url,
    String? proxyHost,
    int? proxyPort,
    SecurityContext? context,
    HttpClient client,
  ) {
    // An HTTP proxy: a plain socket to it; dart:io speaks to the proxy and
    // runs the CONNECT tunnel and TLS itself.
    if (proxyHost != null && proxyPort != null) {
      return Socket.startConnect(proxyHost, proxyPort);
    }
    final secure = url.isScheme('https');
    final port = url.hasPort ? url.port : (secure ? 443 : 80);
    final check = _badCertificateCallbacks[client];
    final onBadCertificate = check == null
        ? null
        : (X509Certificate cert) => check(cert, url.host, port);
    final proxy = _currentProxy();
    if (proxy.kind == ProxyKind.socks5 && _shouldProxy(url, proxy)) {
      var cancelled = false;
      final socket = () async {
        final tunnel = await connectViaSocks5(
          proxyHost: proxy.host,
          proxyPort: proxy.port,
          targetHost: url.host,
          targetPort: port,
          username: proxy.username,
          password: proxy.password,
        );
        if (cancelled) {
          tunnel.socket.destroy();
          throw const SocketException('Connection cancelled');
        }
        if (!secure) return tunnel.asPlainSocket();
        if (tunnel.hasEarlyData) {
          tunnel.socket.destroy();
          throw const Socks5Exception(
            Socks5Failure.protocolError,
            detail: 'The server sent data before the TLS handshake',
          );
        }
        // SecureSocket.secure detaches the raw socket, and dart:io offers no
        // public handle to it, so a cancel during this handshake cannot
        // close the tunnel: a stalled TLS server holds it until it gives up.
        return SecureSocket.secure(
          tunnel.socket,
          host: url.host,
          context: context,
          onBadCertificate: onBadCertificate,
        );
      }();
      return Future.value(
        ConnectionTask.fromSocket(socket, () => cancelled = true),
      );
    }
    // Direct: exactly what dart:io does without a factory.
    return secure
        ? SecureSocket.startConnect(
            url.host,
            port,
            context: context,
            onBadCertificate: onBadCertificate,
          )
        : Socket.startConnect(url.host, port);
  }
}
