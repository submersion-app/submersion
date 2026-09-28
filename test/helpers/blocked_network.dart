import 'dart:io';

/// Whether [host] is this machine: `localhost`, or a loopback address such as
/// 127.0.0.1 or ::1, as text (an IPv6 address may be in brackets) or as an
/// [InternetAddress].
bool isLoopbackHost(Object? host) {
  if (host is InternetAddress) return host.isLoopback;
  if (host is! String) return false;
  var name = host.toLowerCase();
  if (name.endsWith('.')) name = name.substring(0, name.length - 1);
  if (name == 'localhost') return true;
  if (name.startsWith('[') && name.endsWith(']')) {
    name = name.substring(1, name.length - 1);
  }
  return InternetAddress.tryParse(name)?.isLoopback ?? false;
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

/// Real [HttpClient]s that can only reach this machine.
///
/// HttpClient asks findProxy for every request's URL before it opens a
/// connection, and turns a throw there into that request's error. Refusing
/// there leaves TLS, certificates and everything else about the client as
/// they are.
class BlockedNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..findProxy = (uri) {
        if (!isLoopbackHost(uri.host)) throw networkRefusal('$uri');
        return 'DIRECT';
      };
  }
}

/// Sockets that can only reach this machine.
///
/// Covers `Socket.connect` and `Socket.startConnect`. A secure socket connects
/// below this hook, so an HTTPS request is refused by
/// [BlockedNetworkHttpOverrides] instead.
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
      return Future.error(networkRefusal('${_describe(host)}:$port'));
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
      return Future.error(networkRefusal('${_describe(host)}:$port'));
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
