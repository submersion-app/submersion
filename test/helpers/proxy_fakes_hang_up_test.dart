import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/socks5_connector.dart';

import 'fake_socks5_server.dart';
import 'recording_tcp_server.dart';

/// The proxy test fakes must survive a client that hangs up while they are
/// still answering. A test that reads one answer and closes is the common
/// case; a fake whose failed write escapes as an unhandled error fails
/// whichever test is running when it lands. On Linux CI that was a broken
/// pipe from the recording server, in socks5_tunnel_socket_test.dart.
void main() {
  test('the recording server survives a client that hangs up', () async {
    // A large answer keeps the server's writes in flight past the hang-up.
    final target = await RecordingTcpServer.start(
      reply: List<int>.filled(256 * 1024, 7),
    );
    addTearDown(target.close);

    for (var round = 0; round < 60; round++) {
      final client = await Socket.connect(
        InternetAddress.loopbackIPv4,
        target.port,
      );
      // Many requests, one answer read, then hang up at once: the server
      // is still writing the rest when this socket goes away.
      for (var i = 0; i < 50; i++) {
        client.add([i]);
        await client.flush();
      }
      await client.first;
      client.destroy();
    }

    // Long enough for every answer still in flight to hit a closed socket.
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });

  test(
    'a tunnel client that hangs up breaks nothing behind the proxy',
    () async {
      final target = await RecordingTcpServer.start(reply: utf8.encode('ok'));
      final socks = await FakeSocks5Server.start();
      addTearDown(() async {
        await socks.close();
        await target.close();
      });

      for (var round = 0; round < 20; round++) {
        final tunnel = await connectViaSocks5(
          proxyHost: '127.0.0.1',
          proxyPort: socks.port,
          targetHost: 'x.test',
          targetPort: target.port,
        );
        final s = tunnel.asPlainSocket();
        // Answers the proxy relays back after this client has gone.
        for (var i = 0; i < 50; i++) {
          s.add([2]);
          await s.flush();
        }
        s.destroy();
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));
    },
  );
}
