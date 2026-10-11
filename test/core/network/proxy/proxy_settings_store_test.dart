import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/proxy_settings_store.dart';

import '../../../support/fake_keychain_storage.dart';

void main() {
  late InMemoryKeychain keychain;

  Future<ProxySettingsStore> store([
    Map<String, Object> prefs = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(prefs);
    return ProxySettingsStore(
      await SharedPreferences.getInstance(),
      storage: keychain,
    );
  }

  setUp(() => keychain = InMemoryKeychain());

  test('empty prefs load the defaults', () async {
    expect((await store()).load(), ProxySettings.defaults);
  });

  test('save then load round-trips every field', () async {
    final s = await store();
    const saved = ProxySettings(
      mode: ProxyMode.manual,
      type: ProxyType.socks5,
      host: 'socks.example',
      port: 1080,
      username: 'ann',
    );
    await s.save(saved);
    expect(s.load(), saved);
  });

  test('a cleared port is removed, not stored as zero', () async {
    final s = await store({'network_proxy_port': 8080});
    await s.save(ProxySettings.defaults);
    expect(s.load().port, isNull);
  });

  test('values from a newer version load as safe defaults', () async {
    final s = await store({
      'network_proxy_mode': 'pac-only',
      'network_proxy_type': 'quic',
      'network_proxy_port': 70000,
    });
    final loaded = s.load();
    expect(loaded.mode, ProxyMode.system);
    expect(loaded.type, ProxyType.http);
    expect(loaded.port, isNull);
  });

  test('the password lives in secure storage only', () async {
    final s = await store();
    await s.savePassword('hunter2');
    expect(await s.loadPassword(), 'hunter2');
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      expect(prefs.get(key), isNot('hunter2'));
    }
    await s.savePassword('');
    expect(await s.loadPassword(), isNull);
  });
}
