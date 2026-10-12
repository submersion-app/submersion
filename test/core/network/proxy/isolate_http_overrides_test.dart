import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/app_http_overrides.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/isolate_http_overrides.dart';

import '../../../helpers/blocked_network.dart';
import '../../../helpers/fake_http_proxy.dart';
import '../../../helpers/fake_socks5_server.dart';

EffectiveProxy _proxy(ProxyKind kind, int port) => EffectiveProxy(
  kind: kind,
  host: '127.0.0.1',
  port: port,
  source: ProxySource.manual,
);

/// GETs [url] in a fresh isolate the way an FMTC download thread does: the
/// client exists before any app code runs there, and the overrides are
/// installed afterwards (from the tile provider) with [proxy].
///
/// Returns the body, or `error: <exception>` when the request fails.
/// Top-level so the closure sent to the isolate captures only its arguments.
Future<String> _getWithEarlyClient(EffectiveProxy proxy, String url) =>
    Isolate.run(() async {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      ensureIsolateHttpOverrides(proxy);
      try {
        final response = await (await client.getUrl(Uri.parse(url))).close();
        return await response.transform(utf8.decoder).join();
      } catch (e) {
        return 'error: $e';
      } finally {
        client.close(force: true);
      }
    });

/// The same, with the client created after the overrides are installed (the
/// FMTC manager's sea-tile probe, which builds its client per call).
Future<String> _getWithLateClient(EffectiveProxy proxy, String url) =>
    Isolate.run(() async {
      ensureIsolateHttpOverrides(proxy);
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      try {
        final response = await (await client.getUrl(Uri.parse(url))).close();
        return await response.transform(utf8.decoder).join();
      } catch (e) {
        return 'error: $e';
      } finally {
        client.close(force: true);
      }
    });

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

  test('a client built before the install still goes through the HTTP '
      'proxy', () async {
    final proxy = await FakeHttpProxy.start();
    addTearDown(proxy.close);

    final body = await _getWithEarlyClient(
      _proxy(ProxyKind.http, proxy.port),
      'http://example.test:${target.port}/tile',
    );

    expect(body, 'ok /tile');
    expect(
      proxy.requestLines.single,
      startsWith('GET http://example.test:${target.port}/tile'),
    );
  });

  test('a client built before the install refuses a SOCKS5 proxy instead '
      'of going direct', () async {
    final socks = await FakeSocks5Server.start();
    addTearDown(socks.close);

    final body = await _getWithEarlyClient(
      _proxy(ProxyKind.socks5, socks.port),
      'http://example.test:${target.port}/tile',
    );

    expect(body, startsWith('error: '));
    expect(body, contains('SOCKS5'));
    expect(socks.requests, isEmpty);
  });

  test('a client built before the install still connects direct when no '
      'proxy is set', () async {
    final body = await _getWithEarlyClient(
      const EffectiveProxy.direct(),
      'http://127.0.0.1:${target.port}/tile',
    );

    expect(body, 'ok /tile');
  });

  test('a client built after the install gets the full overrides, SOCKS5 '
      'included', () async {
    final socks = await FakeSocks5Server.start();
    addTearDown(socks.close);

    final body = await _getWithLateClient(
      _proxy(ProxyKind.socks5, socks.port),
      'http://example.test:${target.port}/probe',
    );

    expect(body, 'ok /probe');
    expect(socks.requests.single.host, 'example.test');
  });

  group('currentAppProxy', () {
    test('is the snapshot the app overrides route by', () {
      final proxy = _proxy(ProxyKind.http, 3128);
      final current = HttpOverrides.runWithHttpOverrides(
        currentAppProxy,
        AppHttpOverrides(
          currentProxy: () => proxy,
          fallbackContext: () => null,
        ),
      );

      expect(current, proxy);
    });

    test('is direct under overrides that are not the app\'s', () {
      expect(currentAppProxy(), const EffectiveProxy.direct());
    });
  });

  test('installs AppHttpOverrides in an isolate that has none', () async {
    final installed = await Isolate.run(() {
      ensureIsolateHttpOverrides(const EffectiveProxy.direct());
      return HttpOverrides.current is AppHttpOverrides;
    });

    expect(installed, isTrue);
  });

  test('keeps the overrides an isolate already has', () {
    // The test isolate runs under the blocked-network overrides, as the app's
    // main isolate runs under its own: neither may be replaced.
    ensureIsolateHttpOverrides(const EffectiveProxy.direct());

    expect(HttpOverrides.current, same(blockedNetworkHttpOverrides));
  });
}
