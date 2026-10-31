import 'package:shared_preferences/shared_preferences.dart';

/// How long this device keeps its change log. Per device, like the log.
class ChangeLogPreferences {
  ChangeLogPreferences(this._prefs);

  static const retentionKey = 'change_log_retention_months';
  static const defaultRetentionMonths = 12;

  /// The choices offered, with 0 meaning forever.
  static const retentionChoices = [3, 6, 12, 0];

  final SharedPreferences _prefs;

  int get retentionMonths =>
      _prefs.getInt(retentionKey) ?? defaultRetentionMonths;

  Future<void> setRetentionMonths(int months) =>
      _prefs.setInt(retentionKey, months);
}
