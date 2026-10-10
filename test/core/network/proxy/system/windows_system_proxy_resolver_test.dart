import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system/windows_proxy_parser.dart';
import 'package:submersion/core/network/proxy/system/windows_system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

void main() {
  final probe = Uri.parse('https://api.github.com/');

  Future<RawWindowsProxy> slow(String url, RawWindowsProxy config) =>
      Future.delayed(const Duration(seconds: 1), () => config);

  test('a static proxy needs no PAC query', () async {
    var queried = false;
    final r = await WindowsSystemProxyResolver(
      readConfig: () async =>
          const RawWindowsProxy(autoDetect: false, staticProxy: 'p:1'),
      queryPac: (url, config) async {
        queried = true;
        return config;
      },
    ).resolve(probe);
    expect(queried, isFalse);
    expect(r, const SystemProxyFixed(type: ProxyType.http, host: 'p', port: 1));
  });

  test('auto-detect asks WinHTTP about the probe url', () async {
    String? asked;
    final r = await WindowsSystemProxyResolver(
      readConfig: () async => const RawWindowsProxy(autoDetect: true),
      queryPac: (url, config) async {
        asked = url;
        return const RawWindowsProxy(
          autoDetect: true,
          pacAttempted: true,
          pacSucceeded: true,
          pacProxy: 'pac:3128',
        );
      },
    ).resolve(probe);
    expect(asked, 'https://api.github.com/');
    expect(
      r,
      const SystemProxyFixed(
        type: ProxyType.http,
        host: 'pac',
        port: 3128,
        viaPac: true,
      ),
    );
  });

  test('a slow configured PAC url is pacFailed', () async {
    final r = await WindowsSystemProxyResolver(
      readConfig: () async => const RawWindowsProxy(
        autoDetect: false,
        autoConfigUrl: 'http://wpad/p.pac',
      ),
      queryPac: slow,
      timeout: const Duration(milliseconds: 20),
    ).resolve(probe);
    expect(
      r,
      isA<SystemProxyUnavailable>().having(
        (u) => u.reason,
        'reason',
        SystemProxyUnavailableReason.pacFailed,
      ),
    );
  });

  test('a slow auto-detect keeps the static proxy already read', () async {
    final r = await WindowsSystemProxyResolver(
      readConfig: () async =>
          const RawWindowsProxy(autoDetect: true, staticProxy: 'static:8080'),
      queryPac: slow,
      timeout: const Duration(milliseconds: 20),
    ).resolve(probe);
    expect(
      r,
      const SystemProxyFixed(type: ProxyType.http, host: 'static', port: 8080),
    );
  });

  test('a slow auto-detect with nothing else configured is none', () async {
    final r = await WindowsSystemProxyResolver(
      readConfig: () async => const RawWindowsProxy(autoDetect: true),
      queryPac: slow,
      timeout: const Duration(milliseconds: 20),
    ).resolve(probe);
    expect(r, const SystemProxyNone());
  });

  test('a thrown error is platformError', () async {
    final r = await WindowsSystemProxyResolver(
      readConfig: () async => throw StateError('dll'),
    ).resolve(probe);
    expect(
      r,
      isA<SystemProxyUnavailable>().having(
        (u) => u.reason,
        'reason',
        SystemProxyUnavailableReason.platformError,
      ),
    );
  });
}
