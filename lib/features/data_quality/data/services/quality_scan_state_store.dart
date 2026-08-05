import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/data_quality/domain/detectors/quality_detector_registry.dart';

/// Device-local scan bookkeeping (deliberately NOT synced): findings sync,
/// so peers do not need to know when this device last scanned.
class QualityScanStateStore {
  QualityScanStateStore(this._prefs);

  final SharedPreferences _prefs;
  static const _kLastFullScanAt = 'quality_last_full_scan_at';
  static const _kDetectorVersions = 'quality_detector_versions';

  DateTime? get lastFullScanAt {
    final ms = _prefs.getInt(_kLastFullScanAt);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Map<String, int> get lastScanDetectorVersions {
    final raw = _prefs.getString(_kDetectorVersions);
    if (raw == null) return const {};
    return (jsonDecode(raw) as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as int),
    );
  }

  /// True when a detector is new or newer than at the last full scan --
  /// drives the passive "new checks available" banner (never an auto-scan).
  bool get hasNewDetectorVersions {
    final last = lastScanDetectorVersions;
    if (lastFullScanAt == null) return false; // never scanned: show scan CTA
    final current = qualityDetectorVersions();
    return current.entries.any((e) => (last[e.key] ?? 0) < e.value);
  }

  Future<void> recordFullScan(DateTime at, Map<String, int> versions) async {
    await _prefs.setInt(_kLastFullScanAt, at.millisecondsSinceEpoch);
    await _prefs.setString(_kDetectorVersions, jsonEncode(versions));
  }
}
