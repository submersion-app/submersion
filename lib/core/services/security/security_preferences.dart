import 'package:shared_preferences/shared_preferences.dart';

/// Typed access to the App Security settings.
///
/// [appLockTimeoutMinutes]: 0 = lock immediately on background,
/// -1 = never re-lock, otherwise minutes in background before re-lock.
class SecurityPreferences {
  static const String appLockEnabledKey = 'app_lock_enabled';
  static const String dbEncryptionEnabledKey = 'db_encryption_enabled';
  static const String appLockTimeoutMinutesKey = 'app_lock_timeout_minutes';
  static const String appLockBiometricsEnabledKey =
      'app_lock_biometrics_enabled';

  final SharedPreferences _prefs;

  SecurityPreferences(this._prefs);

  bool get appLockEnabled => _prefs.getBool(appLockEnabledKey) ?? false;
  Future<void> setAppLockEnabled(bool value) =>
      _prefs.setBool(appLockEnabledKey, value);

  bool get dbEncryptionEnabled =>
      _prefs.getBool(dbEncryptionEnabledKey) ?? false;
  Future<void> setDbEncryptionEnabled(bool value) =>
      _prefs.setBool(dbEncryptionEnabledKey, value);

  int get appLockTimeoutMinutes => _prefs.getInt(appLockTimeoutMinutesKey) ?? 5;
  Future<void> setAppLockTimeoutMinutes(int value) =>
      _prefs.setInt(appLockTimeoutMinutesKey, value);

  bool get appLockBiometricsEnabled =>
      _prefs.getBool(appLockBiometricsEnabledKey) ?? true;
  Future<void> setAppLockBiometricsEnabled(bool value) =>
      _prefs.setBool(appLockBiometricsEnabledKey, value);
}
