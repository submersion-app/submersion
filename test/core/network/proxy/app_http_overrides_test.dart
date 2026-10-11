import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/app_http_overrides.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';

import '../../../helpers/fake_http_proxy.dart';
import '../../../helpers/fake_socks5_server.dart';
import '../../../helpers/recording_tcp_server.dart';
import '../../../helpers/self_signed_tls.dart';

/// Tests run every endpoint on loopback, which the production policy always
/// sends direct; this policy proxies everything the snapshot allows.
bool proxyEverything(Uri url, EffectiveProxy p) => !p.isDirect;

EffectiveProxy http(int port, {String? user, String? pass}) => EffectiveProxy(
  kind: ProxyKind.http,
  host: '127.0.0.1',
  port: port,
  username: user,
  password: pass,
  source: ProxySource.manual,
);

EffectiveProxy socks(int port, {String? user, String? pass}) => EffectiveProxy(
  kind: ProxyKind.socks5,
  host: '127.0.0.1',
  port: port,
  username: user,
  password: pass,
  source: ProxySource.manual,
);

HttpClient clientFor(
  EffectiveProxy Function() current, {
  bool everything = true,
}) {
  final overrides = everything
      ? AppHttpOverrides(
          currentProxy: current,
          shouldProxy: proxyEverything,
          fallbackContext: () => null,
        )
      : AppHttpOverrides(currentProxy: current, fallbackContext: () => null);
  final client = overrides.createHttpClient(null)
    ..connectionTimeout = const Duration(seconds: 5);
  addTearDown(() => client.close(force: true));
  return client;
}

void main() {
  late HttpServer target;

  setUp(() async {
    target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    target.listen(
      (r) => r.response
        ..write('ok ${r.uri.path}')
        ..close(),
    );
  });
  tearDown(() => target.close(force: true));

  Future<String> get(HttpClient c, String url) async {
    final res = await (await c.getUrl(Uri.parse(url))).close();
    return res.transform(utf8.decoder).join();
  }

  group('proxyDirective', () {
    test(
      'direct',
      () => expect(proxyDirective(const EffectiveProxy.direct()), 'DIRECT'),
    );
    test('host and port, IPv6 bracketed', () {
      expect(proxyDirective(http(8080)), 'PROXY 127.0.0.1:8080');
      expect(
        proxyDirective(
          const EffectiveProxy(
            kind: ProxyKind.http,
            host: '::1',
            port: 3128,
            source: ProxySource.manual,
          ),
        ),
        'PROXY [::1]:3128',
      );
    });
    test('credentials are embedded as user:pass@', () {
      expect(
        proxyDirective(http(1, user: 'ann', pass: 'p@:x')),
        'PROXY ann:p@:x@127.0.0.1:1',
      );
    });
    test('a socks5 snapshot is DIRECT for dart:io', () {
      expect(proxyDirective(socks(1080)), 'DIRECT');
    });
  });

  group('findProxyFromEnvironment', () {
    // Asked on every request by a client built before the overrides were
    // installed, as in an FMTC download isolate: dart:io's default findProxy
    // is HttpClient.findProxyFromEnvironment, which defers to the overrides.
    final url = Uri.parse('https://tile.example.test/1/2/3.png');

    AppHttpOverrides overridesFor(EffectiveProxy proxy) => AppHttpOverrides(
      currentProxy: () => proxy,
      fallbackContext: () => null,
    );

    test('answers with the HTTP proxy directive, ignoring the environment', () {
      expect(
        overridesFor(
          http(3128, user: 'ann', pass: 'pw'),
        ).findProxyFromEnvironment(url, {'https_proxy': 'other:1'}),
        'PROXY ann:pw@127.0.0.1:3128',
      );
    });

    test('is DIRECT with no proxy set', () {
      expect(
        overridesFor(
          const EffectiveProxy.direct(),
        ).findProxyFromEnvironment(url, {'https_proxy': 'other:1'}),
        'DIRECT',
      );
    });

    test('is DIRECT for a host the routing policy keeps direct', () {
      expect(
        overridesFor(
          socks(1080),
        ).findProxyFromEnvironment(Uri.parse('http://127.0.0.1:8080/'), null),
        'DIRECT',
      );
    });

    test('refuses a SOCKS5 proxy, which such a client cannot use, rather '
        'than going direct', () {
      expect(
        () => overridesFor(socks(1080)).findProxyFromEnvironment(url, null),
        throwsA(
          isA<HttpException>().having(
            (e) => e.message,
            'message',
            contains('SOCKS5'),
          ),
        ),
      );
    });
  });

  test('direct snapshot reaches the target without a proxy', () async {
    final c = clientFor(() => const EffectiveProxy.direct());
    expect(await get(c, 'http://127.0.0.1:${target.port}/a'), 'ok /a');
  });

  test('http proxy forwards plain http with Basic credentials containing @ '
      'and :', () async {
    final proxy = await FakeHttpProxy.start(requireBasic: 'ann:p@:x');
    addTearDown(proxy.close);
    final c = clientFor(() => http(proxy.port, user: 'ann', pass: 'p@:x'));
    expect(await get(c, 'http://example.test:${target.port}/b'), 'ok /b');
    expect(
      proxy.requestLines.single,
      startsWith('GET http://example.test:${target.port}/b'),
    );
  });

  test('https goes through CONNECT with credentials up front', () async {
    final proxy = await FakeHttpProxy.start(requireBasic: 'ann:pw');
    addTearDown(proxy.close);
    final hello = await RecordingTcpServer.start();
    addTearDown(hello.close);
    final c = clientFor(() => http(proxy.port, user: 'ann', pass: 'pw'));
    // The recorder never completes a TLS handshake, so the request fails,
    // but only after the ClientHello crossed the tunnel.
    final request = c.getUrl(Uri.parse('https://example.test:${hello.port}/'));
    final first = await hello.firstBytes;
    expect(first.take(2), [0x16, 0x03]);
    expect(
      proxy.requestLines.single,
      'CONNECT example.test:${hello.port} HTTP/1.1',
    );
    request.ignore();
  });

  test('socks5 carries plain http to the target', () async {
    final s = await FakeSocks5Server.start(username: 'ann', password: 'pw');
    addTearDown(s.close);
    final c = clientFor(() => socks(s.port, user: 'ann', pass: 'pw'));
    expect(await get(c, 'http://example.test:${target.port}/c'), 'ok /c');
    expect(s.requests.single.host, 'example.test');
  });

  test('socks5 starts TLS for https inside the tunnel', () async {
    final s = await FakeSocks5Server.start();
    addTearDown(s.close);
    final hello = await RecordingTcpServer.start();
    addTearDown(hello.close);
    final c = clientFor(() => socks(s.port));
    final request = c.getUrl(Uri.parse('https://example.test:${hello.port}/'));
    expect((await hello.firstBytes).take(2), [0x16, 0x03]);
    expect(s.requests.single.host, 'example.test');
    request.ignore();
  });

  test('a snapshot change applies to the next connection on the same '
      'client', () async {
    final proxy = await FakeHttpProxy.start();
    addTearDown(proxy.close);
    var current = const EffectiveProxy.direct();
    final c = clientFor(() => current);
    expect(await get(c, 'http://127.0.0.1:${target.port}/1'), 'ok /1');
    expect(proxy.requestLines, isEmpty);
    current = http(proxy.port);
    // A different host key, so no pooled direct connection is reused.
    expect(await get(c, 'http://example.test:${target.port}/2'), 'ok /2');
    expect(proxy.requestLines, hasLength(1));
  });

  test('the production policy keeps loopback direct even with a proxy '
      'set', () async {
    final proxy = await FakeHttpProxy.start();
    addTearDown(proxy.close);
    final c = clientFor(() => http(proxy.port), everything: false);
    expect(await get(c, 'http://127.0.0.1:${target.port}/d'), 'ok /d');
    expect(proxy.requestLines, isEmpty);
  });

  test('an explicit SecurityContext wins over the fallback', () {
    var asked = false;
    final c = AppHttpOverrides(
      currentProxy: () => const EffectiveProxy.direct(),
      fallbackContext: () {
        asked = true;
        return null;
      },
    ).createHttpClient(SecurityContext(withTrustedRoots: true));
    addTearDown(() => c.close(force: true));
    expect(asked, isFalse);
  });

  test('no explicit context asks the fallback', () {
    var asked = false;
    final c = AppHttpOverrides(
      currentProxy: () => const EffectiveProxy.direct(),
      fallbackContext: () {
        asked = true;
        return null;
      },
    ).createHttpClient(null);
    addTearDown(() => c.close(force: true));
    expect(asked, isTrue);
  });

  group('bad certificate callback', () {
    late SelfSignedTls tls;
    late HttpServer secure;

    setUpAll(() async => tls = await SelfSignedTls.generate());

    setUp(() async {
      secure = await tls.serve();
      addTearDown(() => secure.close(force: true));
    });

    Future<String> get(HttpClient client) async {
      final request = await client.getUrl(
        Uri.parse('https://127.0.0.1:${secure.port}/'),
      );
      final response = await request.close();
      return response.transform(utf8.decoder).join();
    }

    test(
      'a direct connection consults the callback set for the client',
      () async {
        final client = clientFor(() => const EffectiveProxy.direct());
        final seen = <String>[];
        AppHttpOverrides.setBadCertificateCallback(client, (cert, host, port) {
          seen.add('$host:$port');
          return true;
        });
        expect(await get(client), 'ok');
        expect(seen, ['127.0.0.1:${secure.port}']);
      },
    );

    test('a rejecting callback fails the handshake', () async {
      final client = clientFor(() => const EffectiveProxy.direct());
      AppHttpOverrides.setBadCertificateCallback(client, (_, _, _) => false);
      await expectLater(get(client), throwsA(isA<HandshakeException>()));
    });
  });
}
