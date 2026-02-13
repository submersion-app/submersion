import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';

/// Persists backup settings and history to SharedPreferences.
///
/// Backup metadata is stored outside the SQLite database intentionally:
/// restoring an old backup would overwrite the current backup history
/// if it lived in the database being restored.
class BackupPreferences {
  static const String _enabledKey = 'backup_enabled';
  static const String _frequencyKey = 'backup_frequency';
  static const String _retentionCountKey = 'backup_retention_count';
  static const String _lastBackupTimeKey = 'backup_last_time';
  static const String _cloudBackupEnabledKey = 'backup_cloud_enabled';
  static const String _historyKey = 'backup_history';

  final SharedPreferences _prefs;

  BackupPreferences(this._prefs);

  // ===========================================================================
  // Settings
  // ===========================================================================

  BackupSettings getSettings() {
    final lastBackupMs = _prefs.getInt(_lastBackupTimeKey);
    return BackupSettings(
      enabled: _prefs.getBool(_enabledKey) ?? false,
      frequency: _parseFrequency(_prefs.getString(_frequencyKey)),
      retentionCount: _prefs.getInt(_retentionCountKey) ?? 10,
      lastBackupTime: lastBackupMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastBackupMs)
          : null,
      cloudBackupEnabled: _prefs.getBool(_cloudBackupEnabledKey) ?? true,
    );
  }

  Future<void> setEnabled(bool value) async {
    await _prefs.setBool(_enabledKey, value);
  }

  Future<void> setFrequency(BackupFrequency frequency) async {
    await _prefs.setString(_frequencyKey, frequency.name);
  }

  Future<void> setRetentionCount(int count) async {
    await _prefs.setInt(_retentionCountKey, count);
  }

  Future<void> setLastBackupTime(DateTime time) async {
    await _prefs.setInt(_lastBackupTimeKey, time.millisecondsSinceEpoch);
  }

  Future<void> setCloudBackupEnabled(bool value) async {
    await _prefs.setBool(_cloudBackupEnabledKey, value);
  }

  // ===========================================================================
  // History
  // ===========================================================================

  List<BackupRecord> getHistory() {
    final json = _prefs.getString(_historyKey);
    if (json == null || json.isEmpty) return [];

    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => BackupRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addRecord(BackupRecord record) async {
    final history = getHistory();
    final updated = [record, ...history];
    await _saveHistory(updated);
  }

  Future<void> removeRecord(String recordId) async {
    final history = getHistory();
    final updated = history.where((r) => r.id != recordId).toList();
    await _saveHistory(updated);
  }

  Future<void> updateRecord(BackupRecord record) async {
    final history = getHistory();
    final updated = history.map((r) => r.id == record.id ? record : r).toList();
    await _saveHistory(updated);
  }

  Future<void> setHistory(List<BackupRecord> records) async {
    await _saveHistory(records);
  }

  Future<void> _saveHistory(List<BackupRecord> records) async {
    final json = jsonEncode(records.map((r) => r.toJson()).toList());
    await _prefs.setString(_historyKey, json);
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  BackupFrequency _parseFrequency(String? value) {
    if (value == null) return BackupFrequency.weekly;
    return BackupFrequency.values.asNameMap()[value] ?? BackupFrequency.weekly;
  }
}
