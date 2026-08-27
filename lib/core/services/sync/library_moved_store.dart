import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/sync/library_moved.dart';

/// SharedPreferences persistence for the "library moved" protocol.
///
/// Two records, both deliberately small and OUTSIDE the database:
/// - the acknowledged-move signature: which move a straggler has already been
///   told about, so the banner does not reappear on every sync;
/// - the pending-cleanup target: the providerId of a backend this device
///   switched away from, whose orphaned files should be deleted once the
///   first sync on the new backend has succeeded (deferred so a failed first
///   sync cannot strand the user with neither copy).
class LibraryMovedStore {
  static const _acknowledgedSignatureKey = 'sync_acknowledged_move_signature';
  static const _pendingCleanupKey = 'sync_pending_old_backend_cleanup';

  final SharedPreferences _prefs;

  LibraryMovedStore(this._prefs);

  /// A move is identified by where it went and when, so a later move by the
  /// same device (or to a different backend) re-notifies rather than being
  /// silently pre-acknowledged.
  static String _signature(LibraryMovedMarker marker) =>
      '${marker.toProviderId}@${marker.movedAt}';

  bool isAcknowledged(LibraryMovedMarker marker) =>
      _prefs.getString(_acknowledgedSignatureKey) == _signature(marker);

  Future<void> acknowledge(LibraryMovedMarker marker) async {
    await _prefs.setString(_acknowledgedSignatureKey, _signature(marker));
  }

  /// The providerId of a backend awaiting cleanup, or null if none.
  String? get pendingCleanup => _prefs.getString(_pendingCleanupKey);

  Future<void> setPendingCleanup(String providerId) async {
    await _prefs.setString(_pendingCleanupKey, providerId);
  }

  Future<void> clearPendingCleanup() async {
    await _prefs.remove(_pendingCleanupKey);
  }
}
