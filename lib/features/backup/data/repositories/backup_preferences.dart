import 'dart:convert';
import 'dart:typed_data';

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
  static const String _backupLocationKey = 'backup_location';
  static const String _backupLocationBookmarkKey = 'backup_location_bookmark';
  static const String _backupLocationLabelKey = 'backup_location_label';
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
      cloudBackupEnabled: _prefs.getBool(_cloudBackupEnabledKey) ?? false,
      backupLocation: _prefs.getString(_backupLocationKey),
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

  Future<void> setBackupLocation(String? path) async {
    if (path == null) {
      await _prefs.remove(_backupLocationKey);
      // The bookmark only has meaning paired with a location, so clearing the
      // location (reset to default) must drop the bookmark too -- otherwise a
      // dangling security-scoped bookmark would linger.
      await _prefs.remove(_backupLocationBookmarkKey);
      // The label is likewise meaningless without a location.
      await _prefs.remove(_backupLocationLabelKey);
    } else {
      await _prefs.setString(_backupLocationKey, path);
    }
  }

  /// Persists the security-scoped bookmark bytes for the custom backup
  /// location (Apple platforms), stored as base64. Null removes it.
  Future<void> setBackupLocationBookmark(List<int>? bytes) async {
    if (bytes == null) {
      await _prefs.remove(_backupLocationBookmarkKey);
    } else {
      await _prefs.setString(_backupLocationBookmarkKey, base64Encode(bytes));
    }
  }

  /// Reads the stored backup-location bookmark bytes, or null if none is set.
  Uint8List? getBackupLocationBookmark() {
    final encoded = _prefs.getString(_backupLocationBookmarkKey);
    if (encoded == null) return null;
    return base64Decode(encoded);
  }

  /// Human label for the custom backup location (e.g. the SAF folder's display
  /// name on Android), shown in settings instead of a raw `content://` URI.
  Future<void> setBackupLocationLabel(String? label) async {
    if (label == null) {
      await _prefs.remove(_backupLocationLabelKey);
    } else {
      await _prefs.setString(_backupLocationLabelKey, label);
    }
  }

  String? get backupLocationLabel => _prefs.getString(_backupLocationLabelKey);

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
