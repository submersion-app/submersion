import 'package:shared_preferences/shared_preferences.dart';

/// Stores user preferences for sync behavior.
class SyncPreferences {
  static const String _autoSyncKey = 'sync_auto_enabled';
  static const String _syncOnLaunchKey = 'sync_on_launch';
  static const String _syncOnResumeKey = 'sync_on_resume';

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
}
