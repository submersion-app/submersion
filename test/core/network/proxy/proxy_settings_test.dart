import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';

void main() {
  test('defaults are system mode with no manual proxy', () {
    const s = ProxySettings.defaults;
    expect(s.mode, ProxyMode.system);
    expect(s.type, ProxyType.http);
    expect(s.host, '');
    expect(s.port, isNull);
    expect(s.username, '');
    expect(s.hasManualProxy, isFalse);
  });

  test('hasManualProxy needs a host and a port in range', () {
    const base = ProxySettings.defaults;
    expect(base.copyWith(host: 'p', port: 8080).hasManualProxy, isTrue);
    expect(base.copyWith(host: ' ', port: 8080).hasManualProxy, isFalse);
    expect(base.copyWith(host: 'p', port: 0).hasManualProxy, isFalse);
    expect(base.copyWith(host: 'p', port: 65536).hasManualProxy, isFalse);
  });

  test('copyWith can clear the port and compares by value', () {
    final a = ProxySettings.defaults.copyWith(host: 'p', port: 1);
    expect(a.copyWith(clearPort: true).port, isNull);
    expect(a, ProxySettings.defaults.copyWith(host: 'p', port: 1));
    expect(
      a.hashCode,
      ProxySettings.defaults.copyWith(host: 'p', port: 1).hashCode,
    );
  });
}
