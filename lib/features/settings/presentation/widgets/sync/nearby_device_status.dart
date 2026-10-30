import 'package:submersion/core/database/database.dart' show NearbyPeer;
import 'package:submersion/core/services/nearby/nearby_link_manager.dart';
import 'package:submersion/core/services/nearby/nearby_peer_store.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/utils/byte_format.dart';

/// The status dot beside a paired device: synced or syncing, quiet, or
/// needs the diver.
enum NearbyDot { ok, idle, warn }

typedef NearbyDeviceStatus = ({String text, NearbyDot dot});

/// The second line of a paired device's row.
NearbyDeviceStatus nearbyDeviceStatus({
  required AppLocalizations l10n,
  required NearbyPeer peer,
  required NearbyPeerError? error,
  required NearbySyncProgress? progress,
  required DateTime now,
  required String Function(DateTime) formatDate,
}) {
  if (progress != null && !progress.finished && progress.total > 0) {
    return (
      text: l10n.settings_nearby_status_syncing(
        formatBytes(progress.done),
        formatBytes(progress.total),
      ),
      dot: NearbyDot.ok,
    );
  }
  if (error != null) {
    return (
      text: nearbyErrorText(l10n, error),
      dot: error.isLasting ? NearbyDot.warn : NearbyDot.idle,
    );
  }
  final synced = peer.lastSyncedAt;
  if (synced == null) {
    return (text: l10n.settings_nearby_status_never, dot: NearbyDot.idle);
  }
  // A real instant (when the session ran), not a dive's stored wall clock,
  // so it decodes as local time.
  final contactMs = peer.lastSeenAt ?? synced;
  final seen = DateTime.fromMillisecondsSinceEpoch(contactMs);
  if (now.difference(seen) > const Duration(days: 7)) {
    return (
      text: l10n.settings_nearby_status_notSeen(formatDate(seen)),
      dot: NearbyDot.idle,
    );
  }
  final at = DateTime.fromMillisecondsSinceEpoch(synced);
  final ago = now.difference(at);
  final when = ago.inMinutes < 1
      ? l10n.settings_cloudSync_time_justNow
      : ago.inHours < 1
      ? l10n.settings_cloudSync_time_minutesAgo(ago.inMinutes)
      : ago.inDays < 1
      ? l10n.settings_cloudSync_time_hoursAgo(ago.inHours)
      : l10n.settings_cloudSync_time_daysAgo(ago.inDays);
  return (
    text: l10n.settings_nearby_status_synced(when),
    dot: ago < const Duration(days: 1) ? NearbyDot.ok : NearbyDot.idle,
  );
}

String nearbyErrorText(AppLocalizations l10n, NearbyPeerError error) =>
    switch (error) {
      NearbyPeerError.newerApp => l10n.settings_nearby_error_newerApp,
      NearbyPeerError.peerOlderApp => l10n.settings_nearby_error_peerOlderApp,
      NearbyPeerError.differentLibrary =>
        l10n.settings_nearby_error_differentLibrary,
      NearbyPeerError.notPaired => l10n.settings_nearby_error_notPaired,
      NearbyPeerError.applyFailed => l10n.settings_nearby_error_applyFailed,
      NearbyPeerError.bluetoothOff => l10n.settings_nearby_error_bluetoothOff,
      NearbyPeerError.unreachable => l10n.settings_nearby_error_unreachable,
    };
