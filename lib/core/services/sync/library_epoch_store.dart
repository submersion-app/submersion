import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/sync/library_epoch.dart';

/// SharedPreferences persistence for the library epoch protocol.
///
/// Two records, both deliberately OUTSIDE the database:
/// - the last-accepted marker mirror: the database copy rewinds on restore,
///   the mirror survives and re-anchors it (same pattern as the device-id
///   sentinel in SyncInitializer);
/// - the pending-replace intent: a Replace restore's cloud side must retry
///   until it lands, across restarts, while merging stays fenced off.
class LibraryEpochStore {
  static const _lastAcceptedMarkerKey = 'sync_last_accepted_epoch_marker';
  static const _pendingReplaceKey = 'sync_pending_replace_marker';

  final SharedPreferences _prefs;

  LibraryEpochStore(this._prefs);

  LibraryEpochMarker? get lastAcceptedMarker =>
      _decode(_prefs.getString(_lastAcceptedMarkerKey));

  String? get lastAcceptedEpochId => lastAcceptedMarker?.epochId;

  Future<void> setLastAccepted(LibraryEpochMarker? marker) async {
    if (marker == null) {
      await _prefs.remove(_lastAcceptedMarkerKey);
    } else {
      await _prefs.setString(
        _lastAcceptedMarkerKey,
        jsonEncode(marker.toJson()),
      );
    }
  }

  LibraryEpochMarker? get pendingReplace =>
      _decode(_prefs.getString(_pendingReplaceKey));

  Future<void> setPendingReplace(LibraryEpochMarker marker) async {
    await _prefs.setString(_pendingReplaceKey, jsonEncode(marker.toJson()));
  }

  Future<void> clearPendingReplace() async {
    await _prefs.remove(_pendingReplaceKey);
  }

  /// Wipe both epoch records. Used by the comprehensive local sync repair: the
  /// last-accepted marker is the only local sync state a DB reset does not
  /// touch (it lives in SharedPreferences), so a wedge that survives Reset
  /// needs this cleared for a true reinstall-equivalent.
  Future<void> clear() async {
    await _prefs.remove(_lastAcceptedMarkerKey);
    await _prefs.remove(_pendingReplaceKey);
  }

  LibraryEpochMarker? _decode(String? raw) {
    if (raw == null) return null;
    try {
      return LibraryEpochMarker.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }
}
