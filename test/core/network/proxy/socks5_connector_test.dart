import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/socks5_connector.dart';

import '../../../helpers/fake_socks5_server.dart';
import '../../../helpers/recording_tcp_server.dart';
import '../../../helpers/socks5_matchers.dart';

void main() {
  late RecordingTcpServer target;

  setUp(() async {
    target = await RecordingTcpServer.start(reply: utf8.encode('pong'));
  });
  tearDown(() => target.close());

  Future<String> roundTrip(Socks5Tunnel t) async {
    final s = t.asPlainSocket();
    s.add(utf8.encode('ping'));
    final reply = await s.first;
    s.destroy();
    return utf8.decode(reply);
  }

  test('no-auth CONNECT by hostname tunnels bytes', () async {
    final socks = await FakeSocks5Server.start();
    addTearDown(socks.close);
    final t = await connectViaSocks5(
      proxyHost: '127.0.0.1',
      proxyPort: socks.port,
      targetHost: 'example.test',
      targetPort: target.port,
    );
    expect(await roundTrip(t), 'pong');
    expect(socks.requests.single.atyp, 3);
    expect(socks.requests.single.host, 'example.test');
    expect(utf8.decode(await target.firstBytes), 'ping');
  });

  test('IPv4 and IPv6 literals use address types 1 and 4', () async {
    final socks = await FakeSocks5Server.start();
    addTearDown(socks.close);
    final a = await connectViaSocks5(
      proxyHost: '127.0.0.1',
      proxyPort: socks.port,
      targetHost: '127.0.0.1',
      targetPort: target.port,
    );
    a.socket.destroy();
    final b = await connectViaSocks5(
      proxyHost: '127.0.0.1',
      proxyPort: socks.port,
      targetHost: '[::1]',
      targetPort: target.port,
    );
    b.socket.destroy();
    expect(socks.requests.map((r) => r.atyp), [1, 4]);
    expect(socks.requests.last.host, '::1');
  });

  test('username and password authenticate', () async {
    final socks = await FakeSocks5Server.start(
      username: 'ann',
      password: 'p:@;w',
    );
    addTearDown(socks.close);
    final t = await connectViaSocks5(
      proxyHost: '127.0.0.1',
      proxyPort: socks.port,
      targetHost: 'x.test',
      targetPort: target.port,
      username: 'ann',
      password: 'p:@;w',
    );
    expect(await roundTrip(t), 'pong');
  });

  test('wrong password is authRejected', () async {
    final socks = await FakeSocks5Server.start(
      username: 'ann',
      password: 'right',
    );
    addTearDown(socks.close);
    await expectLater(
      connectViaSocks5(
        proxyHost: '127.0.0.1',
        proxyPort: socks.port,
        targetHost: 'x.test',
        targetPort: target.port,
        username: 'ann',
        password: 'wrong',
      ),
      throwsSocks5(Socks5Failure.authRejected),
    );
  });

  test('a server that wants auth from a client without any is '
      'noAcceptableAuth', () async {
    final socks = await FakeSocks5Server.start(username: 'ann', password: 'x');
    addTearDown(socks.close);
    await expectLater(
      connectViaSocks5(
        proxyHost: '127.0.0.1',
        proxyPort: socks.port,
        targetHost: 'x.test',
        targetPort: target.port,
      ),
      throwsSocks5(Socks5Failure.noAcceptableAuth),
    );
  });

  test('reply codes map to failures', () async {
    const codes = {
      1: Socks5Failure.generalFailure,
      2: Socks5Failure.notAllowed,
      3: Socks5Failure.networkUnreachable,
      4: Socks5Failure.hostUnreachable,
      5: Socks5Failure.connectionRefused,
      6: Socks5Failure.ttlExpired,
      7: Socks5Failure.commandNotSupported,
      8: Socks5Failure.addressTypeNotSupported,
      9: Socks5Failure.protocolError,
    };
    for (final entry in codes.entries) {
      final socks = await FakeSocks5Server.start(replyCode: entry.key);
      await expectLater(
        connectViaSocks5(
          proxyHost: '127.0.0.1',
          proxyPort: socks.port,
          targetHost: 'x.test',
          targetPort: 1,
        ),
        throwsSocks5(entry.value),
        reason: 'reply ${entry.key}',
      );
      await socks.close();
    }
  });

  test('an unreachable proxy is proxyUnreachable', () async {
    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    await expectLater(
      connectViaSocks5(
        proxyHost: '127.0.0.1',
        proxyPort: port,
        targetHost: 'x.test',
        targetPort: 1,
      ),
      throwsSocks5(Socks5Failure.proxyUnreachable),
    );
  });

  test('a hostname over 255 bytes fails before connecting', () async {
    await expectLater(
      connectViaSocks5(
        proxyHost: '127.0.0.1',
        proxyPort: 1,
        targetHost: 'a' * 256,
        targetPort: 1,
      ),
      throwsSocks5(Socks5Failure.hostnameTooLong),
    );
  });

  test('a proxy that never answers the handshake times out', () async {
    final silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final held = <Socket>[];
    silent.listen(held.add);
    addTearDown(() async {
      for (final s in held) {
        s.destroy();
      }
      await silent.close();
    });
    await expectLater(
      connectViaSocks5(
        proxyHost: '127.0.0.1',
        proxyPort: silent.port,
        targetHost: 'x.test',
        targetPort: 1,
        handshakeTimeout: const Duration(milliseconds: 100),
      ),
      throwsSocks5(Socks5Failure.handshakeTimeout),
    );
  });

  test('a Socks5Exception is a SocketException', () {
    expect(
      const Socks5Exception(Socks5Failure.generalFailure),
      isA<SocketException>(),
    );
  });
}
