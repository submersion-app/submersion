import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A loopback HTTP proxy: CONNECT tunnels and absolute-form forwarding, both
/// to loopback ports only (whatever host the client named), with optional
/// Basic auth ([requireBasic] is the expected `user:pass`).
class FakeHttpProxy {
  FakeHttpProxy._(this._server, this.requireBasic);

  final ServerSocket _server;
  final String? requireBasic;
  final requestLines = <String>[];
  final proxyAuthorizations = <String?>[];
  final _sockets = <Socket>[];

  int get port => _server.port;

  static Future<FakeHttpProxy> start({String? requireBasic}) async {
    final p = FakeHttpProxy._(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
      requireBasic,
    );
    p._server.listen(p._serve);
    return p;
  }

  Future<void> _serve(Socket client) async {
    _sockets.add(client);
    final buf = <int>[];
    final headerDone = Completer<void>();
    late final StreamSubscription<List<int>> sub;
    sub = client.listen(
      (d) {
        buf.addAll(d);
        if (!headerDone.isCompleted &&
            latin1.decode(buf, allowInvalid: true).contains('\r\n\r\n')) {
          sub.pause();
          headerDone.complete();
        }
      },
      onError: (Object _) {},
      onDone: () {
        if (!headerDone.isCompleted) headerDone.completeError('closed');
      },
    );
    try {
      await headerDone.future;
    } catch (_) {
      client.destroy();
      return;
    }
    final text = latin1.decode(buf, allowInvalid: true);
    final end = text.indexOf('\r\n\r\n') + 4;
    final lines = text.substring(0, end - 4).split('\r\n');
    final requestLine = lines.first;
    requestLines.add(requestLine);
    String? auth;
    for (final l in lines.skip(1)) {
      if (l.toLowerCase().startsWith('proxy-authorization:')) {
        auth = l.substring(l.indexOf(':') + 1).trim();
      }
    }
    proxyAuthorizations.add(auth);
    final expected = requireBasic == null
        ? null
        : 'Basic ${base64Encode(utf8.encode(requireBasic!))}';
    if (expected != null && auth != expected) {
      client.add(
        latin1.encode(
          'HTTP/1.1 407 Proxy Authentication Required\r\n'
          'Proxy-Authenticate: Basic realm="test"\r\n'
          'Content-Length: 0\r\nConnection: close\r\n\r\n',
        ),
      );
      await client.flush();
      client.destroy();
      return;
    }
    final parts = requestLine.split(' ');
    final rest = buf.sublist(end);
    final Socket upstream;
    if (parts[0] == 'CONNECT') {
      final targetPort = int.parse(parts[1].split(':').last);
      upstream = await Socket.connect(InternetAddress.loopbackIPv4, targetPort);
      client.add(latin1.encode('HTTP/1.1 200 Connection Established\r\n\r\n'));
    } else {
      final target = Uri.parse(parts[1]);
      upstream = await Socket.connect(
        InternetAddress.loopbackIPv4,
        target.port,
      );
      final origin = target.hasQuery
          ? '${target.path}?${target.query}'
          : target.path;
      upstream.add(
        latin1.encode(text.substring(0, end).replaceFirst(parts[1], origin)),
      );
    }
    _sockets.add(upstream);
    if (rest.isNotEmpty) upstream.add(rest);
    upstream.listen(
      client.add,
      onDone: client.destroy,
      onError: (Object _) => client.destroy(),
    );
    sub
      ..onData(upstream.add)
      ..onDone(upstream.destroy);
    sub.resume();
  }

  Future<void> close() async {
    for (final s in _sockets) {
      s.destroy();
    }
    await _server.close();
  }
}
