/// Nearby Bluetooth sync bookkeeping (issue #3731).
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

/// The devices this one is paired with for nearby sync. Device-local and
/// never synced: a pairing belongs to two devices, not to the library.
///
/// No column is named `hlc` on purpose: the sync registration guard treats
/// any such table as synced.
@DataClassName('NearbyPeer')
class NearbyPeers extends Table {
  TextColumn get peerDeviceId => text()();

  /// The name the peer gave in its hello, or the diver's rename.
  TextColumn get displayName => text()();

  IntColumn get pairedAt => integer()();

  IntColumn get lastSyncedAt => integer().nullable()();

  /// The last time a session with this peer opened, successful or not.
  /// Tombstone garbage collection stops waiting for a peer silent longer
  /// than the cloud retirement period.
  IntColumn get lastSeenAt => integer().nullable()();

  /// The highest clock of this device's rows the peer reported applying:
  /// what the peer has of mine. Holds tombstones back until the peer has
  /// them.
  TextColumn get peerAppliedHlcHigh => text().nullable()();

  /// A `NearbyPeerError` name, or null after a clean session.
  TextColumn get lastError => text().nullable()();

  /// The full copy being received from this peer, for resuming after a
  /// dropped link: its id, the last part written, and when it was offered.
  TextColumn get resumeBaseId => text().nullable()();

  IntColumn get resumePartIndex => integer().nullable()();

  IntColumn get resumeOfferedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {peerDeviceId};
}
