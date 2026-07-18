/// Tuning constants for fleet-acked tombstone GC and device retirement.
/// See docs/superpowers/specs/2026-07-16-tombstone-gc-device-retirement-design.md.
class SyncLiveness {
  SyncLiveness._();

  /// A device whose manifest is older than this is retired by any live peer.
  static const int retirementPeriodMillis = 365 * 24 * 60 * 60 * 1000;

  /// A sync that publishes nothing still rewrites the manifest when it is
  /// older than this, so a read-mostly device stays provably live.
  static const int heartbeatMaxAgeMillis = 7 * 24 * 60 * 60 * 1000;

  /// Tombstones younger than this are never GC'd regardless of acks (covers
  /// in-flight device joins, twin splits, and backend listing lag).
  static const int gcFloorMillis = 30 * 24 * 60 * 60 * 1000;
}
