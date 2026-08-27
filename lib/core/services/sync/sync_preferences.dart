import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key holding the last-used cloud provider name. Shared
/// with SyncInitializer (single definition).
const String syncLastProviderPrefsKey = 'sync_last_provider';

/// Prefs-only core of "turn cloud sync off before wiping or replacing the
/// database", callable before any ProviderScope exists (the startup
/// escape hatch runs pre-providers). The running-app path is
/// SyncStateNotifier.disableForDatabaseReset, which additionally cancels
/// in-flight sync timers and signs out the live provider.
Future<void> disableSyncConfigurationInPrefs(SharedPreferences prefs) async {
  await SyncPreferences(prefs).setAutoSyncEnabled(false);
  await prefs.remove(syncLastProviderPrefsKey);
}

/// Stores user preferences for sync behavior.
class SyncPreferences {
  static const String _autoSyncKey = 'sync_auto_enabled';
  static const String _syncOnLaunchKey = 'sync_on_launch';
  static const String _syncOnResumeKey = 'sync_on_resume';
  static const String _encryptionEnabledKey = 'sync_encryption_enabled';

  final SharedPreferences _prefs;

  SyncPreferences(this._prefs);

  bool get autoSyncEnabled => _prefs.getBool(_autoSyncKey) ?? false;
  bool get syncOnLaunch => _prefs.getBool(_syncOnLaunchKey) ?? true;
  bool get syncOnResume => _prefs.getBool(_syncOnResumeKey) ?? true;

  Future<void> setAutoSyncEnabled(bool value) async {
    await _prefs.setBool(_autoSyncKey, value);
  }

  Future<void> setSyncOnLaunch(bool value) async {
    await _prefs.setBool(_syncOnLaunchKey, value);
  }

  Future<void> setSyncOnResume(bool value) async {
    await _prefs.setBool(_syncOnResumeKey, value);
  }

  bool get syncEncryptionEnabled =>
      _prefs.getBool(_encryptionEnabledKey) ?? false;

  Future<void> setSyncEncryptionEnabled(bool value) async {
    await _prefs.setBool(_encryptionEnabledKey, value);
  }
}
