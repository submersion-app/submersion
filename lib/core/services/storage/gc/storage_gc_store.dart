import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/storage/gc/cloud_usage_measure.dart';

/// What one cleanup reclaimed in an area, and when.
class AreaResult {
  const AreaResult({
    required this.bytes,
    required this.items,
    required this.at,
  });

  final int bytes;
  final int items;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'bytes': bytes,
    'items': items,
    'at': at.millisecondsSinceEpoch,
  };

  factory AreaResult.fromJson(Map<String, Object?> json) => AreaResult(
    bytes: json['bytes']! as int,
    items: json['items']! as int,
    at: DateTime.fromMillisecondsSinceEpoch(json['at']! as int),
  );
}

/// Device-local state of the storage cleanup (storage GC design, Coordinator).
///
/// Everything here describes this device: when it last swept its own disk,
/// what it last measured and reclaimed in the cloud, and whether a restore is
/// still waiting for its cleanup run. None of it is news to a peer, so it
/// lives in SharedPreferences rather than a synced table, like the scratch
/// sweep's stamp.
class StorageGcStore {
  StorageGcStore(this._prefs);

  final SharedPreferences _prefs;

  static const _lastDeviceRunKey = 'storage_gc_last_device_run_ms';
  static const _lastCloudMeasureKey = 'storage_gc_last_cloud_measure_ms';
  static const _lastCloudAttemptKey = 'storage_gc_last_cloud_attempt_ms';
  static const _lastDeviceAttemptKey = 'storage_gc_last_device_attempt_ms';
  static const _lastRestoreKey = 'storage_gc_last_restore_ms';
  static const _postRestorePendingKey = 'storage_gc_post_restore_pending_ms';
  static const _postRestoreCloudKey = 'storage_gc_post_restore_cloud_pending';
  static const _lastDeviceResultKey = 'storage_gc_last_device_result';
  static const _lastCloudResultKey = 'storage_gc_last_cloud_result';
  static const _cloudUsageKey = 'storage_gc_cloud_usage';

  /// Records a finished restore: its time, which the cloud delete policy
  /// compares the next pull against, and the two flags that force a
  /// post-restore run of the device and cloud parts.
  ///
  /// Throws when any of the three writes does not persist, so the restore
  /// stops before the database is replaced instead of running unguarded.
  static Future<void> markRestored(SharedPreferences prefs, DateTime at) async {
    final saved = [
      await prefs.setInt(_lastRestoreKey, at.millisecondsSinceEpoch),
      await prefs.setInt(_postRestorePendingKey, at.millisecondsSinceEpoch),
      await prefs.setBool(_postRestoreCloudKey, true),
    ];
    if (saved.contains(false)) {
      throw StateError('The restore marker for storage cleanup was not saved');
    }
  }

  /// A delete guard for a cloud sweep: true until a restore records itself
  /// after this call. The sweep judged orphans against the database it
  /// started with, and [markRestored] runs before the swap replaces it.
  static bool Function() restoreGuard(SharedPreferences prefs) {
    final at = prefs.getInt(_lastRestoreKey);
    return () => prefs.getInt(_lastRestoreKey) == at;
  }

  DateTime? get lastDeviceRun => _time(_lastDeviceRunKey);
  DateTime? get lastCloudMeasure => _time(_lastCloudMeasureKey);

  /// The last automatic cloud attempt, whatever it achieved: the throttle
  /// that keeps a deferred sweep from re-listing the store on every resume.
  DateTime? get lastCloudAttempt => _time(_lastCloudAttemptKey);

  /// The last automatic device pass, whatever it achieved: the throttle that
  /// keeps a failing pass from walking every folder on each resume.
  DateTime? get lastDeviceAttempt => _time(_lastDeviceAttemptKey);

  DateTime? get lastRestoreAt => _time(_lastRestoreKey);
  DateTime? get postRestorePendingSince => _time(_postRestorePendingKey);
  bool get postRestoreCloudPending =>
      _prefs.getBool(_postRestoreCloudKey) ?? false;

  AreaResult? get lastDeviceResult =>
      _json(_lastDeviceResultKey, AreaResult.fromJson);
  AreaResult? get lastCloudResult =>
      _json(_lastCloudResultKey, AreaResult.fromJson);
  CloudUsage? get cloudUsage => _json(_cloudUsageKey, CloudUsage.fromJson);

  Future<void> setLastDeviceRun(DateTime at) => _setTime(_lastDeviceRunKey, at);
  Future<void> setLastCloudMeasure(DateTime at) =>
      _setTime(_lastCloudMeasureKey, at);
  Future<void> setLastCloudAttempt(DateTime at) =>
      _setTime(_lastCloudAttemptKey, at);
  Future<void> setLastDeviceAttempt(DateTime at) =>
      _setTime(_lastDeviceAttemptKey, at);
  Future<void> clearPostRestorePending() =>
      _prefs.remove(_postRestorePendingKey);
  Future<void> setPostRestoreCloudPending(bool pending) =>
      _prefs.setBool(_postRestoreCloudKey, pending);
  Future<void> setLastDeviceResult(AreaResult r) =>
      _prefs.setString(_lastDeviceResultKey, jsonEncode(r.toJson()));
  Future<void> setLastCloudResult(AreaResult r) =>
      _prefs.setString(_lastCloudResultKey, jsonEncode(r.toJson()));
  Future<void> setCloudUsage(CloudUsage u) =>
      _prefs.setString(_cloudUsageKey, jsonEncode(u.toJson()));

  DateTime? _time(String key) {
    final ms = _prefs.getInt(key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> _setTime(String key, DateTime at) =>
      _prefs.setInt(key, at.millisecondsSinceEpoch);

  T? _json<T>(String key, T Function(Map<String, Object?>) decode) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return decode(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      // A value this build cannot read is treated as never recorded.
      return null;
    }
  }
}
