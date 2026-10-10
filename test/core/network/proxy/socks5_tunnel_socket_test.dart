import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/socks5_connector.dart';

import '../../../helpers/fake_socks5_server.dart';
import '../../../helpers/recording_tcp_server.dart';
import '../../../helpers/socks5_matchers.dart';

/// A loopback server that answers the SOCKS5 greeting with [greeting], then
/// the CONNECT with [reply] (when given).
Future<ServerSocket> scriptedSocks(
  List<int> greeting, {
  List<int>? reply,
}) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((client) {
    // The connector hangs up on a bad answer; a write racing that reset
    // fails on done, which is not this test's concern.
    unawaited(client.done.catchError((Object _) {}));
    var step = 0;
    client.listen((_) {
      if (step == 0) {
        client.add(greeting);
        if (reply == null) unawaited(client.close());
      } else if (step == 1 && reply != null) {
        client.add(reply);
      }
      step++;
    }, onError: (Object _) {});
  });
  return server;
}

void main() {
  Future<Socks5Tunnel> connect(int port) => connectViaSocks5(
    proxyHost: '127.0.0.1',
    proxyPort: port,
    targetHost: 'x.test',
    targetPort: 1,
  );

  group('the plain tunnel socket', () {
    late RecordingTcpServer target;
    late FakeSocks5Server socks;

    setUp(() async {
      target = await RecordingTcpServer.start(reply: utf8.encode('ok'));
      socks = await FakeSocks5Server.start();
    });
    tearDown(() async {
      await socks.close();
      await target.close();
    });

    test('passes writes, options and addresses to the real socket', () async {
      final tunnel = await connectViaSocks5(
        proxyHost: '127.0.0.1',
        proxyPort: socks.port,
        targetHost: 'x.test',
        targetPort: target.port,
      );
      final s = tunnel.asPlainSocket();
      expect(s.encoding, utf8);
      s.encoding = latin1;
      expect(s.encoding, latin1);
      s
        ..write('a')
        ..writeAll(['b', 'c'], '-')
        ..writeCharCode(0x64)
        ..writeln('e')
        ..add(utf8.encode('f'));
      await s.addStream(Stream.value(utf8.encode('g')));
      await s.flush();
      expect(utf8.decode(await target.firstBytes), startsWith('a'));
      expect(s.setOption(SocketOption.tcpNoDelay, true), isTrue);
      expect(s.port, tunnel.socket.port);
      expect(s.remotePort, socks.port);
      expect(s.address, tunnel.socket.address);
      expect(s.remoteAddress.isLoopback, isTrue);
      final reply = await s.first;
      expect(utf8.decode(reply), 'ok');
      expect(() => s.listen(null), throwsStateError);
      // dart:io sockets refuse errors written into them; the tunnel passes
      // the call through, so it refuses too.
      expect(() => s.addError(StateError('x')), throwsA(anything));
      await s.close().catchError((Object _) {});
      s.destroy();
    });
  });

  test('a greeting with the wrong version is a protocol error', () async {
    final server = await scriptedSocks([4, 0]);
    addTearDown(server.close);
    await expectLater(
      connect(server.port),
      throwsSocks5(Socks5Failure.protocolError),
    );
  });

  test('an unknown auth method is a protocol error', () async {
    final server = await scriptedSocks([5, 9]);
    addTearDown(server.close);
    await expectLater(
      connect(server.port),
      throwsSocks5(Socks5Failure.protocolError),
    );
  });

  test('a proxy that hangs up mid-handshake is a protocol error', () async {
    final server = await scriptedSocks([5]);
    addTearDown(server.close);
    await expectLater(
      connect(server.port),
      throwsSocks5(Socks5Failure.protocolError),
    );
  });

  test('a reply with the wrong version is a protocol error', () async {
    final server = await scriptedSocks([5, 0], reply: [4, 0, 0, 1]);
    addTearDown(server.close);
    await expectLater(
      connect(server.port),
      throwsSocks5(Socks5Failure.protocolError),
    );
  });

  test('a reply with an unknown address type is a protocol error', () async {
    final server = await scriptedSocks([5, 0], reply: [5, 0, 0, 9]);
    addTearDown(server.close);
    await expectLater(
      connect(server.port),
      throwsSocks5(Socks5Failure.protocolError),
    );
  });

  test('a reply naming a domain or an IPv6 address is accepted', () async {
    final name = utf8.encode('proxy.test');
    for (final reply in [
      [5, 0, 0, 3, name.length, ...name, 0, 80],
      [5, 0, 0, 4, ...List.filled(16, 0), 0, 80],
    ]) {
      final server = await scriptedSocks([5, 0], reply: reply);
      final tunnel = await connect(server.port);
      tunnel.socket.destroy();
      await server.close();
    }
  });

  test('bytes that arrive with the reply reach the tunnel\'s reader', () async {
    final server = await scriptedSocks(
      [5, 0],
      reply: [5, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0x42, 0x43],
    );
    addTearDown(server.close);
    final tunnel = await connect(server.port);
    expect(tunnel.hasEarlyData, isTrue);
    final s = tunnel.asPlainSocket();
    expect(await s.first, [0x42, 0x43]);
    s.destroy();
  });

  test('toString names the failure', () {
    expect(
      const Socks5Exception(Socks5Failure.authRejected).toString(),
      contains('authRejected'),
    );
  });
}
