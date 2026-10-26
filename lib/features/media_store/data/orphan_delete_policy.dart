import 'package:submersion/core/services/cloud_storage/git_storage_provider.dart';
import 'package:submersion/core/services/sync/peer_sync_snapshot.dart';

/// What the cleanup may do with one unreferenced media store object.
enum OrphanVerdict {
  /// Safe to delete now.
  delete,

  /// Inside the safety wait: a device that has not synced yet may still
  /// reference it.
  wait,

  /// This device is not caught up with its peers, so nothing may be deleted
  /// whatever its age.
  deferred,
}

/// Decides when an unreferenced media store object may be deleted (storage
/// GC design, safety rules).
///
/// An object nothing here references may still be referenced by a row this
/// device has not received yet. Two rules guard against deleting it:
///
/// - **Caught up.** With database sync on, no object is deleted unless the
///   last pull applied every live peer cleanly and came after the last
///   restore. After a Merge restore, rows for media added since the backup
///   come back from peers on that pull; deleting before it would remove
///   objects those rows still need.
/// - **Grace or early delete.** An object older than [grace] may go. One
///   uploaded before every peer last published (plus [skew] for clock
///   differences), and before this device's last pull, may go sooner: the
///   row that referenced it would have reached this device already.
///
/// With sync off this device knows of no peers, so only the grace window
/// applies. With sync on Git it does too: a Git listing time is the writing
/// device's own clock, so a peer whose clock runs fast could claim a publish
/// after an upload it never saw.
class OrphanDeletePolicy {
  const OrphanDeletePolicy({
    required this.now,
    required this.syncEnabled,
    this.snapshot,
    this.currentProviderId,
    this.lastRestoreAt,
    this.grace = defaultGrace,
    this.skew = const Duration(hours: 1),
  });

  /// Sync off: the grace window is the only rule. Today's behaviour.
  const OrphanDeletePolicy.unrestricted(DateTime now)
    : this(now: now, syncEnabled: false);

  /// How long an unreferenced object is kept before it may go, and how old
  /// the last clean pull may be before this device is no longer trusted to
  /// know every row that references the store.
  static const defaultGrace = Duration(days: 7);

  final DateTime now;
  final bool syncEnabled;
  final PeerSyncSnapshot? snapshot;

  /// The sync backend in use now; a snapshot from another backend is not
  /// trusted.
  final String? currentProviderId;
  final DateTime? lastRestoreAt;
  final Duration grace;
  final Duration skew;

  /// False when this device is not caught up, so every verdict is
  /// [OrphanVerdict.deferred]: no clean pull, a pull from another backend,
  /// one older than the grace window (a device that stopped syncing must not
  /// keep deleting on what it knew then), or one from before the last
  /// restore.
  bool get deletesAllowed {
    if (!syncEnabled) return true;
    final s = snapshot;
    if (s == null || !s.caughtUp) return false;
    if (s.providerId != currentProviderId) return false;
    if (s.takenAt.isBefore(now.subtract(grace))) return false;
    final restored = lastRestoreAt;
    return restored == null || s.takenAt.isAfter(restored);
  }

  OrphanVerdict verdictFor(DateTime lastModified) {
    if (!deletesAllowed) return OrphanVerdict.deferred;
    if (lastModified.isBefore(now.subtract(grace))) return OrphanVerdict.delete;
    final s = snapshot;
    // Early delete only when every device that can upload is known and its
    // publishes were applied here: not one whose first publish has no
    // manifest yet, nor a skipped stale-epoch peer.
    if (syncEnabled &&
        s != null &&
        !s.hasUnappliedPeers &&
        currentProviderId != GitStorageProvider.id) {
      final covered = lastModified.add(skew);
      final everyoneSince =
          covered.isBefore(s.takenAt) &&
          s.peers.every((p) => covered.isBefore(p.publishedAt));
      if (everyoneSince) return OrphanVerdict.delete;
    }
    return OrphanVerdict.wait;
  }
}
