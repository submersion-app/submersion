import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// Persists [ProxySettings] in SharedPreferences (device-local, never synced)
/// and the manual password in the platform keychain.
///
/// Reading tolerates anything a newer app version might have written: an
/// unknown mode or type, or a port out of range, falls back to the default
/// rather than failing startup.
class ProxySettingsStore {
  ProxySettingsStore(this._prefs, {FlutterSecureStorage? storage})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage());

  final SharedPreferences _prefs;
  final FallbackSecureStorage _storage;

  static const modeKey = 'network_proxy_mode';
  static const typeKey = 'network_proxy_type';
  static const hostKey = 'network_proxy_host';
  static const portKey = 'network_proxy_port';
  static const usernameKey = 'network_proxy_username';
  static const passwordKey = 'network_proxy_password';

  ProxySettings load() {
    final port = _prefs.getInt(portKey);
    return ProxySettings(
      mode:
          _byName(ProxyMode.values, _prefs.getString(modeKey)) ??
          ProxySettings.defaults.mode,
      type:
          _byName(ProxyType.values, _prefs.getString(typeKey)) ??
          ProxySettings.defaults.type,
      host: _prefs.getString(hostKey) ?? '',
      port: port != null && port >= 1 && port <= 65535 ? port : null,
      username: _prefs.getString(usernameKey) ?? '',
    );
  }

  Future<void> save(ProxySettings settings) async {
    await _prefs.setString(modeKey, settings.mode.name);
    await _prefs.setString(typeKey, settings.type.name);
    await _prefs.setString(hostKey, settings.host);
    final port = settings.port;
    if (port == null) {
      await _prefs.remove(portKey);
    } else {
      await _prefs.setInt(portKey, port);
    }
    await _prefs.setString(usernameKey, settings.username);
  }

  Future<String?> loadPassword() async {
    final value = await _storage.read(key: passwordKey);
    return value == null || value.isEmpty ? null : value;
  }

  /// Stores [password], or deletes it when null or empty.
  Future<void> savePassword(String? password) =>
      password == null || password.isEmpty
      ? _storage.delete(key: passwordKey)
      : _storage.write(key: passwordKey, value: password);

  static T? _byName<T extends Enum>(List<T> values, String? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
