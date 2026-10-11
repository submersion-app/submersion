import 'dart:async';
import 'dart:io';

/// A loopback TCP server that records the first bytes a client sends, then
/// optionally answers with [reply]. Lets a test prove a TLS ClientHello
/// (0x16 0x03 ...) arrived through a tunnel without needing a certificate.
class RecordingTcpServer {
  RecordingTcpServer._(this._server);

  final ServerSocket _server;
  final _first = Completer<List<int>>();
  final _clients = <Socket>[];

  int get port => _server.port;
  Future<List<int>> get firstBytes => _first.future;

  static Future<RecordingTcpServer> start({List<int>? reply}) async {
    final server = RecordingTcpServer._(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
    );
    server._server.listen((socket) {
      server._clients.add(socket);
      socket.listen(
        (data) {
          if (!server._first.isCompleted) server._first.complete(data);
          if (reply != null) socket.add(reply);
        },
        onError: (Object _) {},
        cancelOnError: true,
      );
    });
    return server;
  }

  Future<void> close() async {
    for (final c in _clients) {
      c.destroy();
    }
    await _server.close();
  }
}
