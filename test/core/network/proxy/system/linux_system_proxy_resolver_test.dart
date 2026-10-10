import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system/linux_system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

void main() {
  final probe = Uri.parse('https://api.github.com/');

  GSettingsReader gsettings(Map<String, String> values) =>
      (schema, key) async => values['$schema $key'];

  test('environment wins over gsettings', () async {
    final r = await LinuxSystemProxyResolver(
      environment: {'https_proxy': 'http://env:1'},
      gsettings: gsettings({'org.gnome.system.proxy mode': "'manual'"}),
    ).resolve(probe);
    expect((r as SystemProxyFixed).host, 'env');
  });

  test('gnome manual prefers https, then socks', () async {
    final r = await LinuxSystemProxyResolver(
      environment: const {},
      gsettings: gsettings({
        'org.gnome.system.proxy mode': "'manual'",
        'org.gnome.system.proxy.https host': "''",
        'org.gnome.system.proxy.https port': '0',
        'org.gnome.system.proxy.socks host': "'s'",
        'org.gnome.system.proxy.socks port': '1080',
        'org.gnome.system.proxy ignore-hosts': "['localhost']",
      }),
    ).resolve(probe);
    expect(
      r,
      const SystemProxyFixed(
        type: ProxyType.socks5,
        host: 's',
        port: 1080,
        bypass: ['localhost'],
      ),
    );
  });

  test('a gnome port above 65535 is skipped', () async {
    final r = await LinuxSystemProxyResolver(
      environment: const {},
      gsettings: gsettings({
        'org.gnome.system.proxy mode': "'manual'",
        'org.gnome.system.proxy.https host': "'h'",
        'org.gnome.system.proxy.https port': '70000',
      }),
    ).resolve(probe);
    expect(r, const SystemProxyNone());
  });

  test('gnome auto is pacUnsupported', () async {
    expect(
      await LinuxSystemProxyResolver(
        environment: const {},
        gsettings: gsettings({'org.gnome.system.proxy mode': "'auto'"}),
      ).resolve(probe),
      const SystemProxyUnavailable(SystemProxyUnavailableReason.pacUnsupported),
    );
  });

  test('a failing gsettings read is a platform error', () async {
    final r = await LinuxSystemProxyResolver(
      environment: const {},
      gsettings: (schema, key) async => throw StateError('dbus'),
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

  test('gnome none and missing gsettings are none', () async {
    expect(
      await LinuxSystemProxyResolver(
        environment: const {},
        gsettings: gsettings({'org.gnome.system.proxy mode': "'none'"}),
      ).resolve(probe),
      const SystemProxyNone(),
    );
    expect(
      await LinuxSystemProxyResolver(
        environment: const {},
        gsettings: gsettings({}),
      ).resolve(probe),
      const SystemProxyNone(),
    );
  });
}
