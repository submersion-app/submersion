import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/database.dart' show NearbyPeer;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/nearby/ble/ble_nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_link_manager.dart';
import 'package:submersion/core/services/nearby/nearby_pair_store.dart';
import 'package:submersion/core/services/nearby/nearby_peer_store.dart';
import 'package:submersion/core/services/nearby/nearby_session.dart';
import 'package:submersion/core/services/nearby/nearby_sync_engine.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_temp_dir.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

/// Nearby Bluetooth sync between a diver's own devices (issue #3731).

// no-tick: a store handle; its rows are read through nearbyPeersProvider,
// which watches the table.
final nearbyPeerStoreProvider = Provider<NearbyPeerStore>(
  (ref) => NearbyPeerStore(DatabaseService.instance.database),
);

final nearbyPairSecretsProvider = Provider<NearbyPairSecrets>(
  (ref) => SecureNearbyPairStore(),
);

final nearbyCarrierProvider = Provider<NearbyCarrier>((ref) {
  final carrier = BleNearbyCarrier();
  ref.onDispose(carrier.dispose);
  return carrier;
});

/// False where this device can only scan (Linux).
final nearbyCanAdvertiseProvider = Provider<bool>(
  (ref) => ref.watch(nearbyCarrierProvider).canAdvertise,
);

// no-tick: an adapter over the sync engine; nothing renders from it.
final nearbySyncEngineProvider = Provider<NearbySyncEngine>((ref) {
  final db = DatabaseService.instance.database;
  return DatabaseNearbySyncEngine(
    syncService: () => ref.read(syncServiceProvider),
    serializer: ref.watch(syncDataSerializerProvider),
    syncRepository: ref.watch(syncRepositoryProvider),
    peerCursors: PeerCursorStore(db),
    publishStates: PublishStateStore(db),
    peers: ref.watch(nearbyPeerStoreProvider),
    epochStore: ref.watch(libraryEpochStoreProvider),
    database: db,
  );
});

Future<Directory> _nearbyTempDir() async {
  final dir = Directory(p.join((await resolveSyncTempDir()).path, 'nearby'));
  await dir.create(recursive: true);
  return dir;
}

// no-tick: a long-lived service; screens read its streams through the
// providers below and the peers table through nearbyPeersProvider.
final nearbyLinkManagerProvider = Provider<NearbyLinkManager>((ref) {
  final manager = NearbyLinkManager(
    carrier: ref.watch(nearbyCarrierProvider),
    engine: ref.watch(nearbySyncEngineProvider),
    secrets: ref.watch(nearbyPairSecretsProvider),
    peers: ref.watch(nearbyPeerStoreProvider),
    cursors: PeerCursorStore(DatabaseService.instance.database),
    autoSyncEnabled: () => ref.read(syncPreferencesProvider).nearbyAutoEnabled,
    tempDir: _nearbyTempDir,
    localChanges: SyncEventBus.changes,
  );
  ref.onDispose(manager.dispose);
  return manager;
});

final nearbyPeersProvider = StreamProvider<List<NearbyPeer>>(
  (ref) => ref.watch(nearbyPeerStoreProvider).watchAll(),
);

/// The running transfer per peer device id; a peer drops out when its
/// session ends.
final nearbyProgressProvider = StreamProvider<Map<String, NearbySyncProgress>>((
  ref,
) async* {
  final manager = ref.watch(nearbyLinkManagerProvider);
  var current = const <String, NearbySyncProgress>{};
  yield current;
  await for (final event in manager.progress) {
    current = {
      for (final entry in current.entries)
        if (entry.key != event.peerDeviceId) entry.key: entry.value,
      if (!event.finished) event.peerDeviceId: event,
    };
    yield current;
  }
});

/// Pairings waiting for the diver while the pairing page is open.
final nearbyPendingPairingsProvider = StreamProvider<List<NearbyPairingOffer>>((
  ref,
) async* {
  final manager = ref.watch(nearbyLinkManagerProvider);
  yield manager.currentPairings;
  yield* manager.pendingPairings;
});
