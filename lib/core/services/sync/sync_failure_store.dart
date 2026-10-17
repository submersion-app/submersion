import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/settings/domain/data_health/sync_health.dart';

/// The last failed sync attempt, kept in SharedPreferences so Settings >
/// Data health (#3390, #3394) can still show it after a restart, when the
/// in-memory sync status starts as idle. A successful sync clears it.
class SyncFailureStore {
  static const _key = 'sync_last_failure';

  final SharedPreferences _prefs;

  SyncFailureStore(this._prefs);

  SyncFailureRecord? get last {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return SyncFailureRecord(
        providerId: json['providerId'] as String,
        at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
        kind: SyncFailureKind.values.byName(json['kind'] as String),
        message: json['message'] as String,
      );
    } catch (_) {
      // A record this build cannot read is no failure worth showing.
      return null;
    }
  }

  Future<void> record(SyncFailureRecord failure) async {
    await _prefs.setString(
      _key,
      jsonEncode({
        'providerId': failure.providerId,
        'at': failure.at.millisecondsSinceEpoch,
        'kind': failure.kind.name,
        'message': failure.message,
      }),
    );
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
