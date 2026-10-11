import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/proxy_routing.dart';

void main() {
  group('isAlwaysDirectHost', () {
    for (final host in [
      'localhost',
      'LOCALHOST',
      'nas.local',
      'printer.local.',
      '127.0.0.1',
      '127.9.9.9',
      '::1',
      '[::1]',
      '10.1.2.3',
      '172.16.0.1',
      '172.31.255.255',
      '192.168.1.10',
      '169.254.3.4',
      'fd12::1',
      'fe80::1',
    ]) {
      test('$host is direct', () => expect(isAlwaysDirectHost(host), isTrue));
    }
    for (final host in [
      'api.github.com',
      '172.32.0.1',
      '11.0.0.1',
      '8.8.8.8',
      '2001:db8::1',
      'local.example.com',
    ]) {
      test(
        '$host may be proxied',
        () => expect(isAlwaysDirectHost(host), isFalse),
      );
    }
  });

  group('matchesBypass', () {
    test('exact host and subdomain of a plain entry', () {
      expect(matchesBypass('corp.com', ['corp.com']), isTrue);
      expect(matchesBypass('a.corp.com', ['corp.com']), isTrue);
      expect(matchesBypass('notcorp.com', ['corp.com']), isFalse);
    });
    test('wildcard and leading dot entries', () {
      expect(matchesBypass('a.corp.com', ['*.corp.com']), isTrue);
      expect(matchesBypass('corp.com', ['*.corp.com']), isTrue);
      expect(matchesBypass('a.corp.com', ['.corp.com']), isTrue);
      expect(matchesBypass('x.other.com', ['*.corp.com']), isFalse);
    });
    test('star alone bypasses everything', () {
      expect(matchesBypass('anything.com', ['*']), isTrue);
    });
    test('case and trailing dots are ignored', () {
      expect(matchesBypass('A.Corp.COM.', ['corp.com']), isTrue);
      expect(matchesBypass('a.corp.com', [' *.CORP.com ']), isTrue);
    });
    test('CIDR, including the macOS short form', () {
      expect(matchesBypass('100.64.1.2', ['100.64.0.0/10']), isTrue);
      expect(matchesBypass('100.128.0.1', ['100.64.0.0/10']), isFalse);
      expect(matchesBypass('203.0.113.9', ['203.0.113/24']), isTrue);
      expect(matchesBypass('2001:db8::5', ['2001:db8::/32']), isTrue);
    });
    test('<local> matches single-label names only', () {
      expect(matchesBypass('intranet', ['<local>']), isTrue);
      expect(matchesBypass('intranet.corp', ['<local>']), isFalse);
    });
    test('an entry with a port matches on its host part', () {
      expect(matchesBypass('corp.com', ['corp.com:8443']), isTrue);
    });
    test('empty and malformed entries never match', () {
      expect(matchesBypass('a.com', ['', '  ', '1.2.3.4/99', '/8']), isFalse);
    });
  });

  group('defaultShouldProxy', () {
    const proxy = EffectiveProxy(
      kind: ProxyKind.http,
      host: 'p',
      port: 1,
      bypass: ['*.corp'],
      source: ProxySource.system,
    );
    test('direct snapshot never proxies', () {
      expect(
        defaultShouldProxy(
          Uri.parse('https://a.com/'),
          const EffectiveProxy.direct(),
        ),
        isFalse,
      );
    });
    test('public host proxies, LAN and bypass do not', () {
      expect(defaultShouldProxy(Uri.parse('https://a.com/'), proxy), isTrue);
      expect(
        defaultShouldProxy(Uri.parse('http://192.168.1.5/'), proxy),
        isFalse,
      );
      expect(defaultShouldProxy(Uri.parse('https://x.corp/'), proxy), isFalse);
    });
  });
}
