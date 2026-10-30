import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_hello.dart';
import 'package:submersion/core/services/nearby/nearby_link_manager.dart';
import 'package:submersion/core/services/nearby/nearby_peer_store.dart';
import 'package:submersion/core/services/nearby/nearby_session.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';

import 'fake_nearby_sync_engine.dart';
import 'in_memory_nearby_carrier.dart';
import 'memory_nearby_secrets.dart';

/// One device for link manager tests: carrier, fake library, stores and
/// its manager.
class NearbyTestDevice {
  NearbyTestDevice({
    required this.id,
    required this.carrier,
    required this.engine,
    required this.db,
    required this.temp,
  }) : peers = NearbyPeerStore(db),
       cursors = PeerCursorStore(db);

  final String id;
  final InMemoryNearbyCarrier carrier;
  final FakeNearbySyncEngine engine;
  final AppDatabase db;
  final Directory temp;
  final NearbyPeerStore peers;
  final PeerCursorStore cursors;
  final secrets = MemoryNearbySecrets();
  final changes = StreamController<void>.broadcast();
  bool auto = true;
  DateTime now = DateTime.utc(2026, 10, 27, 12);

  /// The manager's retry spacing; set before [manager] is first read.
  Duration retryAfter = Duration.zero;

  /// The manager's pairing nonces, so a test can say which of two twin
  /// pairings is kept; set before [manager] is first read.
  String Function() pairingNonce = NearbySession.newPairingNonce;
  late final NearbyLinkManager manager = NearbyLinkManager(
    carrier: carrier,
    engine: engine,
    secrets: secrets,
    peers: peers,
    cursors: cursors,
    autoSyncEnabled: () => auto,
    tempDir: () async => temp,
    localChanges: changes.stream,
    now: () => now,
    changeDebounce: const Duration(milliseconds: 20),
    retryAfter: retryAfter,
    pairingNonce: pairingNonce,
    // Tests sight devices afresh by refreshing; the in-memory carrier
    // reports a device only when its scan starts.
    scanRestartAfter: Duration.zero,
  );
}

NearbyIdentity nearbyTestIdentity(
  String id, {
  int schema = 320,
  int floor = 308,
  String? epoch = 'epoch-1',
}) => NearbyIdentity(
  deviceId: id,
  deviceName: 'Device $id',
  appVersion: '1.8.4',
  schemaVersion: schema,
  schemaFloor: floor,
  epochId: epoch,
  hasDives: true,
);

/// Lets every in-memory session run to its end.
Future<void> settleNearby() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// Joins device [id] to [hub] with its own in-memory database and temp
/// directory, both gone, with its manager, at the end of the test.
Future<NearbyTestDevice> joinNearbyTestDevice(
  InMemoryNearbyHub hub,
  String id, {
  bool canAdvertise = true,
}) async {
  final db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
  addTearDown(db.close);
  final temp = Directory.systemTemp.createTempSync('nearby_mgr_$id');
  addTearDown(() => temp.deleteSync(recursive: true));
  final marks = {'A': fakeHlc(5, 'A'), 'B': fakeHlc(5, 'B')};
  final d = NearbyTestDevice(
    id: id,
    carrier: hub.join(id, canAdvertise: canAdvertise),
    engine: FakeNearbySyncEngine(
      self: nearbyTestIdentity(id),
      marks: marks,
      tempDir: temp,
    ),
    db: db,
    temp: temp,
  );
  addTearDown(() => d.manager.dispose());
  return d;
}

/// Stores a shared pair secret and a paired-devices row on both. Each pair
/// gets a secret of its own, as a real pairing does: a device paired with
/// two others under one secret could not tell them apart.
Future<void> pairNearbyTestDevices(
  NearbyTestDevice a,
  NearbyTestDevice b,
) async {
  final ids = ([a.id, b.id]..sort()).join('|').codeUnits;
  final secret = Uint8List.fromList(
    List.generate(32, (i) => i < ids.length ? ids[i] : i + 7),
  );
  await a.secrets.store(b.id, secret);
  await b.secrets.store(a.id, secret);
  await a.peers.upsertPaired(
    peerDeviceId: b.id,
    displayName: 'Device ${b.id}',
    pairedAt: 1,
  );
  await b.peers.upsertPaired(
    peerDeviceId: a.id,
    displayName: 'Device ${a.id}',
    pairedAt: 1,
  );
}

Future<void> foregroundNearbyTestDevices(List<NearbyTestDevice> ds) async {
  for (final d in ds) {
    await d.manager.setForeground(true);
  }
  await settleNearby();
}

/// Passes everything to [inner] and counts the connection attempts.
class CountingNearbyCarrier implements NearbyCarrier {
  CountingNearbyCarrier(this.inner, this.onConnect, {this.onStartScanning});

  final InMemoryNearbyCarrier inner;
  final void Function() onConnect;
  final void Function()? onStartScanning;

  @override
  bool get canAdvertise => inner.canAdvertise;

  @override
  Future<void> startAdvertising() => inner.startAdvertising();

  @override
  Future<void> stopAdvertising() => inner.stopAdvertising();

  @override
  Future<void> startScanning() {
    onStartScanning?.call();
    return inner.startScanning();
  }

  @override
  Future<void> stopScanning() => inner.stopScanning();

  @override
  Stream<NearbyPeerSighting> get sightings => inner.sightings;

  @override
  Stream<NearbyEndpoint> get incoming => inner.incoming;

  @override
  Future<NearbyEndpoint> connect(String transportId) {
    onConnect();
    return inner.connect(transportId);
  }

  @override
  Stream<NearbyAvailability> get availability => inner.availability;

  @override
  Future<NearbyAvailability> checkAvailability() => inner.checkAvailability();
}
