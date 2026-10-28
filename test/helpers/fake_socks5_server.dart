import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// One CONNECT request the fake server received.
class FakeSocksRequest {
  FakeSocksRequest(this.atyp, this.host, this.port);

  /// RFC 1928 address type: 1 IPv4, 3 domain name, 4 IPv6.
  final int atyp;
  final String host;
  final int port;
}

/// A loopback SOCKS5 server (RFC 1928, optional RFC 1929 auth). Accepted
/// CONNECTs are piped to the requested port on loopback, whatever host the
/// client named, so tests never leave this machine.
class FakeSocks5Server {
  FakeSocks5Server._(
    this._server,
    this.username,
    this.password,
    this.replyCode,
  );

  final ServerSocket _server;
  final String? username;
  final String? password;
  final int replyCode;
  final requests = <FakeSocksRequest>[];
  final _sockets = <Socket>[];

  int get port => _server.port;

  static Future<FakeSocks5Server> start({
    String? username,
    String? password,
    int replyCode = 0,
  }) async {
    final s = FakeSocks5Server._(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
      username,
      password,
      replyCode,
    );
    s._server.listen(s._serve);
    return s;
  }

  Future<void> _serve(Socket client) async {
    _sockets.add(client);
    // A client that hangs up while the fake is still replying makes later
    // writes fail; those failures are expected in hang-up tests.
    unawaited(client.done.catchError((Object _) {}));
    final buf = <int>[];
    final it = StreamIterator(client);
    Future<List<int>> need(int n) async {
      while (buf.length < n) {
        if (!await it.moveNext()) throw StateError('closed');
        buf.addAll(it.current);
      }
      final out = buf.sublist(0, n);
      buf.removeRange(0, n);
      return out;
    }

    try {
      final greeting = await need(2);
      final methods = await need(greeting[1]);
      final wantAuth = username != null;
      final method = wantAuth ? 2 : 0;
      if (!methods.contains(method)) {
        client.add([5, 0xff]);
        await client.flush();
        client.destroy();
        return;
      }
      client.add([5, method]);
      if (wantAuth) {
        await need(1);
        final user = utf8.decode(await need((await need(1))[0]));
        final pass = utf8.decode(await need((await need(1))[0]));
        final ok = user == username && pass == password;
        client.add([1, ok ? 0 : 1]);
        if (!ok) {
          await client.flush();
          client.destroy();
          return;
        }
      }
      final head = await need(4);
      final atyp = head[3];
      final String host;
      if (atyp == 1) {
        host = InternetAddress.fromRawAddress(
          Uint8List.fromList(await need(4)),
        ).address;
      } else if (atyp == 4) {
        host = InternetAddress.fromRawAddress(
          Uint8List.fromList(await need(16)),
        ).address;
      } else {
        host = utf8.decode(await need((await need(1))[0]));
      }
      final pb = await need(2);
      final port = pb[0] << 8 | pb[1];
      requests.add(FakeSocksRequest(atyp, host, port));
      if (replyCode != 0) {
        client.add([5, replyCode, 0, 1, 0, 0, 0, 0, 0, 0]);
        await client.flush();
        client.destroy();
        return;
      }
      final upstream = await Socket.connect(InternetAddress.loopbackIPv4, port);
      _sockets.add(upstream);
      unawaited(upstream.done.catchError((Object _) {}));
      client.add([5, 0, 0, 1, 127, 0, 0, 1, 0, 0]);
      if (buf.isNotEmpty) upstream.add(buf);
      upstream.listen(
        (data) {
          // A write to a client that already hung up fails on `done` (caught
          // above); one after close throws StateError here instead.
          try {
            client.add(data);
          } on StateError {
            client.destroy();
            upstream.destroy();
          }
        },
        onDone: client.destroy,
        onError: (Object _) => client.destroy(),
      );
      unawaited(() async {
        try {
          while (await it.moveNext()) {
            upstream.add(it.current);
          }
        } catch (_) {}
        upstream.destroy();
      }());
    } catch (_) {
      client.destroy();
    }
  }

  Future<void> close() async {
    for (final s in _sockets) {
      s.destroy();
    }
    await _server.close();
  }
}
