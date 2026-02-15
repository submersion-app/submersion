import 'package:shared_preferences/shared_preferences.dart';

class UpdatePreferences {
  final SharedPreferences _prefs;

  static const _keyAutoUpdateEnabled = 'auto_update_enabled';
  static const _keyLastCheckTime = 'auto_update_last_check';
  static const _keyCheckIntervalHours = 'auto_update_check_interval_hours';

  UpdatePreferences(this._prefs);

  bool get autoUpdateEnabled => _prefs.getBool(_keyAutoUpdateEnabled) ?? true;

  Future<void> setAutoUpdateEnabled(bool value) =>
      _prefs.setBool(_keyAutoUpdateEnabled, value);

  DateTime? get lastCheckTime {
    final millis = _prefs.getInt(_keyLastCheckTime);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setLastCheckTime(DateTime time) =>
      _prefs.setInt(_keyLastCheckTime, time.millisecondsSinceEpoch);

  int get checkIntervalHours => _prefs.getInt(_keyCheckIntervalHours) ?? 4;

  Future<void> setCheckIntervalHours(int hours) =>
      _prefs.setInt(_keyCheckIntervalHours, hours);

  bool get isDueForCheck {
    final last = lastCheckTime;
    if (last == null) return true;
    final elapsed = DateTime.now().difference(last);
    return elapsed.inHours >= checkIntervalHours;
  }
}
