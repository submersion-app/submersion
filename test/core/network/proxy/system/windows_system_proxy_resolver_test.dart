import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system/windows_proxy_parser.dart';
import 'package:submersion/core/network/proxy/system/windows_system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

void main() {
  final probe = Uri.parse('https://api.github.com/');

  test('passes the probe url and parses the answer', () async {
    String? asked;
    final r = await WindowsSystemProxyResolver(
      query: (url) async {
        asked = url;
        return const RawWindowsProxy(autoDetect: false, staticProxy: 'p:1');
      },
    ).resolve(probe);
    expect(asked, 'https://api.github.com/');
    expect(r, const SystemProxyFixed(type: ProxyType.http, host: 'p', port: 1));
  });

  test('a slow WinHTTP answer is pacFailed after the timeout', () async {
    final r = await WindowsSystemProxyResolver(
      query: (_) => Future.delayed(
        const Duration(seconds: 1),
        () => const RawWindowsProxy(autoDetect: false),
      ),
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

  test('a thrown error is platformError', () async {
    final r = await WindowsSystemProxyResolver(
      query: (_) async => throw StateError('dll'),
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
