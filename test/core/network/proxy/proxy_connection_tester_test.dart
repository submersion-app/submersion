import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/proxy_connection_tester.dart';

import '../../../helpers/fake_http_proxy.dart';
import '../../../helpers/fake_socks5_server.dart';
import '../../../helpers/recording_tcp_server.dart';

/// Every endpoint is on loopback, which production routing sends direct.
bool proxyEverything(Uri url, EffectiveProxy p) => !p.isDirect;

EffectiveProxy httpProxy(int port, {String? user, String? pass}) =>
    EffectiveProxy(
      kind: ProxyKind.http,
      host: '127.0.0.1',
      port: port,
      username: user,
      password: pass,
      source: ProxySource.manual,
    );

EffectiveProxy socksProxy(int port, {String? user, String? pass}) =>
    EffectiveProxy(
      kind: ProxyKind.socks5,
      host: '127.0.0.1',
      port: port,
      username: user,
      password: pass,
      source: ProxySource.manual,
    );

void main() {
  late HttpServer target;

  setUp(() async {
    target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    target.listen(
      (r) => r.response
        ..statusCode = 204
        ..close(),
    );
  });
  tearDown(() => target.close(force: true));

  ProxyConnectionTester tester({Uri? url, Duration? timeout}) =>
      ProxyConnectionTester(
        probeUrl: url ?? Uri.parse('http://example.test:${target.port}/'),
        timeout: timeout ?? const Duration(seconds: 5),
        shouldProxy: proxyEverything,
      );

  Future<int> closedPort() async {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = s.port;
    await s.close();
    return port;
  }

  test('failure details never carry proxy credentials', () {
    expect(
      redactProxyCredentials(
        'Invalid proxy configuration PROXY ann:s3cret@host:8080',
      ),
      'Invalid proxy configuration PROXY ***@host:8080',
    );
    expect(
      redactProxyCredentials('PROXY ab;cd:secret@host:8080'),
      'PROXY ***@host:8080',
    );
    expect(redactProxyCredentials('plain message'), 'plain message');
  });

  test('direct success', () async {
    final o = await tester(
      url: Uri.parse('http://127.0.0.1:${target.port}/'),
    ).run(const EffectiveProxy.direct());
    expect(o, isA<ProxyTestSuccess>());
  });

  test('success through an http proxy names it', () async {
    final p = await FakeHttpProxy.start();
    addTearDown(p.close);
    final o = await tester().run(httpProxy(p.port));
    expect(
      o,
      isA<ProxyTestSuccess>().having((s) => s.via.port, 'port', p.port),
    );
  });

  test('success through a socks5 proxy', () async {
    final s = await FakeSocks5Server.start();
    addTearDown(s.close);
    expect(await tester().run(socksProxy(s.port)), isA<ProxyTestSuccess>());
  });

  test('a 407 is authRejected, for plain http and for a tunnel', () async {
    final p = await FakeHttpProxy.start(requireBasic: 'ann:right');
    addTearDown(p.close);
    expect(
      await tester().run(httpProxy(p.port, user: 'ann', pass: 'wrong')),
      isA<ProxyTestAuthRejected>(),
    );
    final hello = await RecordingTcpServer.start();
    addTearDown(hello.close);
    expect(
      await tester(
        url: Uri.parse('https://example.test:${hello.port}/'),
      ).run(httpProxy(p.port)),
      isA<ProxyTestAuthRejected>(),
    );
  });

  test('a closed proxy port is unreachable, for http and socks5', () async {
    final port = await closedPort();
    expect(
      await tester().run(httpProxy(port)),
      isA<ProxyTestUnreachable>().having(
        (u) => u.endpoint,
        'endpoint',
        '127.0.0.1:$port',
      ),
    );
    expect(await tester().run(socksProxy(port)), isA<ProxyTestUnreachable>());
  });

  test('a socks5 wrong password is authRejected', () async {
    final s = await FakeSocks5Server.start(username: 'a', password: 'b');
    addTearDown(s.close);
    expect(
      await tester().run(socksProxy(s.port, user: 'a', pass: 'x')),
      isA<ProxyTestAuthRejected>(),
    );
  });

  test('a TLS handshake failure is tlsFailure', () async {
    final garbage = await RecordingTcpServer.start(
      reply: List.filled(64, 0x41),
    );
    addTearDown(garbage.close);
    final o = await tester(
      url: Uri.parse('https://127.0.0.1:${garbage.port}/'),
    ).run(const EffectiveProxy.direct());
    expect(o, isA<ProxyTestTlsFailure>());
  });

  test('no answer in time is timeout', () async {
    final silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final held = <Socket>[];
    silent.listen(held.add);
    addTearDown(() async {
      for (final s in held) {
        s.destroy();
      }
      await silent.close();
    });
    final o = await tester(
      url: Uri.parse('http://127.0.0.1:${silent.port}/'),
      timeout: const Duration(milliseconds: 200),
    ).run(const EffectiveProxy.direct());
    expect(o, isA<ProxyTestTimeout>());
  });

  test('a direct connection refused is failed with a detail', () async {
    final port = await closedPort();
    final o = await tester(
      url: Uri.parse('http://127.0.0.1:$port/'),
    ).run(const EffectiveProxy.direct());
    expect(o, isA<ProxyTestFailed>());
  });
}
