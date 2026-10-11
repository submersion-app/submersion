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

  final EffectiveProxy Function() _currentProxy;
  final ProxyRoutingPolicy _shouldProxy;
  final SecurityContext? Function() _fallbackContext;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final effectiveContext = context ?? _fallbackContext();
    final client = super.createHttpClient(effectiveContext);
    client.findProxy = (url) {
      final proxy = _currentProxy();
      if (proxy.kind != ProxyKind.http || !_shouldProxy(url, proxy)) {
        return 'DIRECT';
      }
      return proxyDirective(proxy);
    };
    client.connectionFactory = (url, proxyHost, proxyPort) =>
        _connect(url, proxyHost, proxyPort, effectiveContext);
    return client;
  }

  Future<ConnectionTask<Socket>> _connect(
    Uri url,
    String? proxyHost,
    int? proxyPort,
    SecurityContext? context,
  ) {
    // An HTTP proxy: a plain socket to it; dart:io speaks to the proxy and
    // runs the CONNECT tunnel and TLS itself.
    if (proxyHost != null && proxyPort != null) {
      return Socket.startConnect(proxyHost, proxyPort);
    }
    final secure = url.isScheme('https');
    final port = url.hasPort ? url.port : (secure ? 443 : 80);
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
        );
      }();
      return Future.value(
        ConnectionTask.fromSocket(socket, () => cancelled = true),
      );
    }
    // Direct: exactly what dart:io does without a factory.
    return secure
        ? SecureSocket.startConnect(url.host, port, context: context)
        : Socket.startConnect(url.host, port);
  }
}
