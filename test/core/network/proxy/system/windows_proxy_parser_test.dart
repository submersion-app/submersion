import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system/windows_proxy_parser.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

void main() {
  group('pickWindowsProxy', () {
    test('plain host:port is http', () {
      expect(pickWindowsProxy('proxy:8080'), (
        type: ProxyType.http,
        host: 'proxy',
        port: 8080,
      ));
    });
    test('per-scheme list prefers https, then http, then socks', () {
      expect(pickWindowsProxy('http=a:1;https=b:2;socks=c:3'), (
        type: ProxyType.http,
        host: 'b',
        port: 2,
      ));
      expect(pickWindowsProxy('http=a:1 socks=c:3'), (
        type: ProxyType.http,
        host: 'a',
        port: 1,
      ));
      expect(pickWindowsProxy('socks=c:3'), (
        type: ProxyType.socks5,
        host: 'c',
        port: 3,
      ));
    });
    test('scheme prefix and missing port', () {
      expect(pickWindowsProxy('http://proxy:3128'), (
        type: ProxyType.http,
        host: 'proxy',
        port: 3128,
      ));
      expect(pickWindowsProxy('proxy'), (
        type: ProxyType.http,
        host: 'proxy',
        port: 80,
      ));
      expect(pickWindowsProxy(''), isNull);
    });
  });

  group('parseWindowsProxy', () {
    test('static proxy with bypass list', () {
      final r = parseWindowsProxy(
        const RawWindowsProxy(
          autoDetect: false,
          staticProxy: 'proxy:8080',
          staticBypass: '<local>;*.corp',
        ),
      );
      expect(
        r,
        const SystemProxyFixed(
          type: ProxyType.http,
          host: 'proxy',
          port: 8080,
          bypass: ['<local>', '*.corp'],
        ),
      );
    });
    test('nothing configured is none', () {
      expect(
        parseWindowsProxy(const RawWindowsProxy(autoDetect: false)),
        const SystemProxyNone(),
      );
    });
    test('PAC success is viaPac', () {
      final r = parseWindowsProxy(
        const RawWindowsProxy(
          autoDetect: true,
          pacAttempted: true,
          pacSucceeded: true,
          pacProxy: 'pac:3128',
        ),
      );
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
    test('PAC saying direct is none', () {
      expect(
        parseWindowsProxy(
          const RawWindowsProxy(
            autoDetect: true,
            pacAttempted: true,
            pacSucceeded: true,
          ),
        ),
        const SystemProxyNone(),
      );
    });
    test('auto-detect failing with no WPAD server is none (home PCs)', () {
      expect(
        parseWindowsProxy(
          const RawWindowsProxy(
            autoDetect: true,
            pacAttempted: true,
            pacSucceeded: false,
          ),
        ),
        const SystemProxyNone(),
      );
    });
    test('a configured PAC url failing is pacFailed, unless a static proxy '
        'exists', () {
      expect(
        parseWindowsProxy(
          const RawWindowsProxy(
            autoDetect: false,
            autoConfigUrl: 'http://wpad/p.pac',
            pacAttempted: true,
            pacSucceeded: false,
          ),
        ),
        isA<SystemProxyUnavailable>().having(
          (u) => u.reason,
          'reason',
          SystemProxyUnavailableReason.pacFailed,
        ),
      );
      expect(
        parseWindowsProxy(
          const RawWindowsProxy(
            autoDetect: false,
            autoConfigUrl: 'http://wpad/p.pac',
            pacAttempted: true,
            pacSucceeded: false,
            staticProxy: 's:1',
          ),
        ),
        const SystemProxyFixed(type: ProxyType.http, host: 's', port: 1),
      );
    });
  });
}
