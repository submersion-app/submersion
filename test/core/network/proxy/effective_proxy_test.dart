import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

void main() {
  const manual = ProxySettings(
    mode: ProxyMode.manual,
    type: ProxyType.socks5,
    host: ' socks.example ',
    port: 1080,
    username: 'ann',
  );

  test('none mode is direct whatever the system says', () {
    final p = EffectiveProxy.resolve(
      settings: manual.copyWith(mode: ProxyMode.none),
      system: const SystemProxyFixed(type: ProxyType.http, host: 'h', port: 1),
    );
    expect(p.kind, ProxyKind.direct);
    expect(p.source, ProxySource.none);
  });

  test('manual mode uses the trimmed manual proxy and password', () {
    final p = EffectiveProxy.resolve(settings: manual, password: 'pw');
    expect(p.kind, ProxyKind.socks5);
    expect(p.host, 'socks.example');
    expect(p.port, 1080);
    expect(p.username, 'ann');
    expect(p.password, 'pw');
    expect(p.bypass, isEmpty);
    expect(p.source, ProxySource.manual);
  });

  test('manual mode without a usable proxy is direct', () {
    final p = EffectiveProxy.resolve(
      settings: manual.copyWith(clearPort: true),
    );
    expect(p.isDirect, isTrue);
    expect(p.source, ProxySource.manual);
  });

  test('manual credentials are dropped when they fail the transport rules', () {
    final p = EffectiveProxy.resolve(
      settings: manual.copyWith(type: ProxyType.http),
      password: 'a;b',
    );
    expect(p.username, isNull);
    expect(p.password, isNull);
  });

  test('system fixed maps type, bypass and PAC source', () {
    final p = EffectiveProxy.resolve(
      settings: ProxySettings.defaults,
      system: const SystemProxyFixed(
        type: ProxyType.http,
        host: 'proxy.corp',
        port: 8080,
        bypass: ['*.corp'],
        viaPac: true,
      ),
    );
    expect(p.kind, ProxyKind.http);
    expect(p.endpoint, 'proxy.corp:8080');
    expect(p.bypass, ['*.corp']);
    expect(p.source, ProxySource.systemPac);
  });

  test('system credentials the directive cannot carry are dropped', () {
    for (final (user, pass) in [
      ('ann', null),
      ('ann', 'a;b'),
      ('ann', ' pw'),
      ('a:b', 'pw'),
    ]) {
      final p = EffectiveProxy.resolve(
        settings: ProxySettings.defaults,
        system: SystemProxyFixed(
          type: ProxyType.http,
          host: 'h',
          port: 1,
          username: user,
          password: pass,
        ),
      );
      expect(p.username, isNull, reason: '$user/$pass');
      expect(p.password, isNull, reason: '$user/$pass');
      expect(p.kind, ProxyKind.http);
    }
    final ok = EffectiveProxy.resolve(
      settings: ProxySettings.defaults,
      system: const SystemProxyFixed(
        type: ProxyType.http,
        host: 'h',
        port: 1,
        username: 'ann',
        password: 'p@ss',
      ),
    );
    expect(ok.username, 'ann');
    expect(ok.password, 'p@ss');
  });

  test('system none, unavailable and not-yet-known are direct', () {
    for (final system in <SystemProxyResult?>[
      null,
      const SystemProxyNone(),
      const SystemProxyUnavailable(SystemProxyUnavailableReason.pacFailed),
    ]) {
      final p = EffectiveProxy.resolve(
        settings: ProxySettings.defaults,
        system: system,
      );
      expect(p.isDirect, isTrue, reason: '$system');
      expect(p.source, ProxySource.system);
    }
  });

  test('endpoint brackets IPv6 and toString never shows the password', () {
    final p = EffectiveProxy.resolve(
      settings: manual.copyWith(host: '::1', type: ProxyType.socks5),
      password: 'hunter2',
    );
    expect(p.endpoint, '[::1]:1080');
    expect(p.toString(), isNot(contains('hunter2')));
    expect(p.toString(), isNot(contains('ann')));
  });
}
