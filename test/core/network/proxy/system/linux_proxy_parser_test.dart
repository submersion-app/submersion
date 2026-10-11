import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system/linux_proxy_parser.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

void main() {
  group('parseProxyEnvironment', () {
    test(
      'no variables is null',
      () => expect(parseProxyEnvironment({}), isNull),
    );
    test('https_proxy wins, lowercase before uppercase', () {
      final r = parseProxyEnvironment({
        'HTTPS_PROXY': 'http://upper:1',
        'https_proxy': 'http://lower:2',
        'http_proxy': 'http://plain:3',
      });
      expect(
        r,
        const SystemProxyFixed(type: ProxyType.http, host: 'lower', port: 2),
      );
    });
    test('falls back to http_proxy then all_proxy', () {
      expect(
        parseProxyEnvironment({'http_proxy': 'proxy:3128'}),
        const SystemProxyFixed(type: ProxyType.http, host: 'proxy', port: 3128),
      );
      expect(
        parseProxyEnvironment({'ALL_PROXY': 'socks5h://s:1080'}),
        const SystemProxyFixed(type: ProxyType.socks5, host: 's', port: 1080),
      );
    });
    test('credentials, default ports and no_proxy', () {
      final r = parseProxyEnvironment({
        'https_proxy': 'http://ann:p%40ss@corp',
        'no_proxy': 'localhost, .corp ,10.0.0.0/8',
      });
      expect(
        r,
        const SystemProxyFixed(
          type: ProxyType.http,
          host: 'corp',
          port: 80,
          bypass: ['localhost', '.corp', '10.0.0.0/8'],
          username: 'ann',
          password: 'p@ss',
        ),
      );
      expect(
        parseProxyEnvironment({'all_proxy': 'socks5://s'}),
        const SystemProxyFixed(type: ProxyType.socks5, host: 's', port: 1080),
      );
    });
    test('a bad percent escape skips to the next variable', () {
      expect(
        parseProxyEnvironment({
          'https_proxy': 'http://ann:%FF@bad:1',
          'http_proxy': 'http://good:2',
        }),
        const SystemProxyFixed(type: ProxyType.http, host: 'good', port: 2),
      );
    });
    test('a port outside 1 to 65535 skips to the next variable', () {
      final r = parseProxyEnvironment({
        'https_proxy': 'http://a:0',
        'HTTPS_PROXY': 'http://b:65536',
        'http_proxy': 'http://c:8080',
      });
      expect(r, isA<SystemProxyFixed>().having((f) => f.host, 'host', 'c'));
    });

    test('an unusable value is ignored', () {
      expect(parseProxyEnvironment({'https_proxy': 'ftp://x:1'}), isNull);
      expect(parseProxyEnvironment({'https_proxy': '  '}), isNull);
    });
  });

  test('gvariant strings and lists', () {
    expect(parseGVariantString("'manual'\n"), 'manual');
    expect(parseGVariantString(null), isNull);
    expect(parseGVariantStringList("['localhost', '127.0.0.0/8', '::1']"), [
      'localhost',
      '127.0.0.0/8',
      '::1',
    ]);
    expect(parseGVariantStringList('@as []'), isEmpty);
  });
}
