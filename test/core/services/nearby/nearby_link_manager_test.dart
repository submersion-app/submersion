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
import 'package:submersion/core/services/nearby/nearby_sync_engine.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';

import '../../../support/fake_nearby_sync_engine.dart';
import '../../../support/in_memory_nearby_carrier.dart';

class _Secrets implements NearbyPairSecrets {
  final map = <String, Uint8List>{};

  @override
  Future<Uint8List?> secretFor(String id) async => map[id];

  @override
  Future<void> store(String id, Uint8List s) async => map[id] = s;

  @override
  Future<void> remove(String id) async => map.remove(id);

  @override
  Future<Map<String, Uint8List>> all() async => Map.of(map);
}

/// One device: carrier, fake library, stores and its manager.
class _Device {
  _Device({
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
  final secrets = _Secrets();
  final changes = StreamController<void>.broadcast();
  bool auto = true;
  DateTime now = DateTime.utc(2026, 10, 27, 12);
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
    retryAfter: Duration.zero,
  );
}

NearbyIdentity _id(String id, {int schema = 320, int floor = 308}) =>
    NearbyIdentity(
      deviceId: id,
      deviceName: 'Device $id',
      appVersion: '1.8.4',
      schemaVersion: schema,
      schemaFloor: floor,
      epochId: 'epoch-1',
      hasDives: true,
    );

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late InMemoryNearbyHub hub;

  setUp(() => hub = InMemoryNearbyHub());

  Future<_Device> device(String id, {bool canAdvertise = true}) async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    final temp = Directory.systemTemp.createTempSync('nearby_mgr_$id');
    addTearDown(() => temp.deleteSync(recursive: true));
    final marks = {'A': fakeHlc(5, 'A'), 'B': fakeHlc(5, 'B')};
    final d = _Device(
      id: id,
      carrier: hub.join(id, canAdvertise: canAdvertise),
      engine: FakeNearbySyncEngine(self: _id(id), marks: marks, tempDir: temp),
      db: db,
      temp: temp,
    );
    addTearDown(() => d.manager.dispose());
    return d;
  }

  /// Stores a shared pair secret and a paired-devices row on both.
  Future<void> pair(_Device a, _Device b) async {
    final secret = Uint8List.fromList(List.generate(32, (i) => i + 7));
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

  Future<void> foreground(List<_Device> ds) async {
    for (final d in ds) {
      await d.manager.setForeground(true);
    }
    await _settle();
  }

  test('two paired managers in foreground sync once on discovery', () async {
    final a = await device('A');
    final b = await device('B');
    await pair(a, b);
    await foreground([a, b]);

    expect(a.engine.recordedAcks, hasLength(1));
    expect(b.engine.recordedAcks, hasLength(1));
    expect((await a.peers.get('B'))!.lastError, isNull);
    expect((await b.peers.get('A'))!.lastError, isNull);
    expect((await a.peers.get('B'))!.lastSeenAt, isNotNull);
  });

  test('simultaneous connects keep exactly one session', () async {
    final a = await device('A');
    final b = await device('B');
    await pair(a, b);
    // Both scan and advertise, so each finds and connects to the other.
    await Future.wait([
      a.manager.setForeground(true),
      b.manager.setForeground(true),
    ]);
    await _settle();
    expect(a.engine.recordedAcks, hasLength(1));
    expect(b.engine.recordedAcks, hasLength(1));
    expect(a.engine.recordedApplied, hasLength(1));
    expect(b.engine.recordedApplied, hasLength(1));
  });

  test('no re-sync within the cooldown without a change', () async {
    final a = await device('A');
    final b = await device('B');
    await pair(a, b);
    await foreground([a, b]);
    // A fresh sighting (the scan restarts) inside the cooldown.
    await a.manager.refresh();
    await b.manager.refresh();
    await _settle();
    expect(a.engine.recordedAcks, hasLength(1));

    // Past the cooldown it syncs again.
    a.now = a.now.add(const Duration(minutes: 11));
    b.now = b.now.add(const Duration(minutes: 11));
    await a.manager.refresh();
    await b.manager.refresh();
    await _settle();
    expect(a.engine.recordedAcks, hasLength(2));
  });

  test(
    'a local change re-syncs after the debounce despite the cooldown',
    () async {
      final a = await device('A');
      final b = await device('B');
      await pair(a, b);
      await foreground([a, b]);
      expect(a.engine.recordedAcks, hasLength(1));

      a.changes.add(null);
      await _settle();
      expect(a.engine.recordedAcks, hasLength(2));
    },
  );

  test('an unpaired device is dropped outside pairing mode', () async {
    final a = await device('A');
    final b = await device('B');
    final c = await device('C');
    await pair(a, c); // A and B know each other not at all.
    await pair(b, c);
    await a.manager.setForeground(true);
    await b.manager.setForeground(true);
    await _settle();
    expect(a.engine.recordedAcks.where((r) => r.peer == 'B'), isEmpty);
    expect(b.engine.recordedAcks.where((r) => r.peer == 'A'), isEmpty);
    expect(await a.peers.get('B'), isNull);
  });

  test('pairing mode offers one pairing to both, with the same code, and '
      'confirming on both pairs and syncs', () async {
    final a = await device('A');
    final b = await device('B');
    final aOffers = <List<NearbyPairingHandle>>[];
    final bOffers = <List<NearbyPairingHandle>>[];
    a.manager.pendingPairings.listen(aOffers.add);
    b.manager.pendingPairings.listen(bOffers.add);
    await a.manager.setForeground(true);
    await b.manager.setForeground(true);
    await a.manager.enterPairingMode();
    await b.manager.enterPairingMode();
    await _settle();

    final aHandle = aOffers.last.single;
    final bHandle = bOffers.last.single;
    expect(aHandle.peer.deviceId, 'B');
    expect(bHandle.peer.deviceId, 'A');
    expect(aHandle.code, bHandle.code);

    await Future.wait([aHandle.confirm(), bHandle.confirm()]);
    await _settle();
    expect(await a.secrets.secretFor('B'), isNotNull);
    expect((await a.peers.get('B'))!.displayName, 'Device B');
    expect((await b.peers.get('A'))!.displayName, 'Device A');
    expect(a.engine.recordedAcks.where((r) => r.peer == 'B'), isNotEmpty);
    expect(aOffers.last, isEmpty);
  });

  test('rejecting a pairing stores nothing on either device', () async {
    final a = await device('A');
    final b = await device('B');
    final aOffers = <List<NearbyPairingHandle>>[];
    final bOffers = <List<NearbyPairingHandle>>[];
    a.manager.pendingPairings.listen(aOffers.add);
    b.manager.pendingPairings.listen(bOffers.add);
    await a.manager.setForeground(true);
    await b.manager.setForeground(true);
    await a.manager.enterPairingMode();
    await b.manager.enterPairingMode();
    await _settle();
    final aConfirm = aOffers.last.single.confirm();
    await bOffers.last.single.reject();
    await expectLater(aConfirm, throwsA(isA<NearbyPairingRejected>()));
    expect(await a.secrets.all(), isEmpty);
    expect(await b.secrets.all(), isEmpty);
    expect(await a.peers.all(), isEmpty);
  });

  test(
    'a failed session records the error on the row; success clears it',
    () async {
      final a = await device('A');
      final b = await device('B');
      await pair(a, b);
      a.engine.self = _id('A', schema: 340, floor: 335);
      // B is now behind A's floor: it cannot read A's rows.
      a.engine.marks = {'A': fakeHlc(9, 'A'), 'B': fakeHlc(5, 'B')};
      a.engine.delta = fakeTagsPayload([('x', fakeHlc(9, 'A'))]);
      await foreground([a, b]);
      expect(
        b.peers.errorOf((await b.peers.get('A'))!),
        NearbyPeerError.newerApp,
      );
      expect(
        a.peers.errorOf((await a.peers.get('B'))!),
        NearbyPeerError.peerOlderApp,
      );

      // B updates; the next session clears both.
      b.engine.self = _id('B', schema: 340, floor: 308);
      a.engine.self = _id('A', schema: 340, floor: 308);
      final outcome = await b.manager.syncNow('A');
      await _settle();
      expect(outcome, isNotNull);
      expect((await b.peers.get('A'))!.lastError, isNull);
      expect((await a.peers.get('B'))!.lastError, isNull);
    },
  );

  test('Bluetooth off marks every row and nothing connects', () async {
    final a = await device('A');
    final b = await device('B');
    await pair(a, b);
    hub.setAvailability('A', NearbyAvailability.bluetoothOff);
    await a.manager.setForeground(true);
    await _settle();
    expect(a.carrier.isScanning, isFalse);
    expect(
      a.peers.errorOf((await a.peers.get('B'))!),
      NearbyPeerError.bluetoothOff,
    );

    hub.setAvailability('A', NearbyAvailability.ready);
    await _settle();
    expect(a.carrier.isScanning, isTrue);
    expect((await a.peers.get('B'))!.lastError, isNull);
  });

  test('unpair removes the secret, the row and the cursor', () async {
    final a = await device('A');
    final b = await device('B');
    await pair(a, b);
    await a.cursors.upsert(
      peerDeviceId: 'B',
      provider: nearbyCursorProvider,
      lastSeqApplied: 0,
      appliedHlcHigh: fakeHlc(1, 'B'),
    );
    await a.cursors.upsert(
      peerDeviceId: 'B',
      provider: 'icloud',
      lastSeqApplied: 3,
    );
    await a.manager.unpair('B');
    expect(await a.secrets.secretFor('B'), isNull);
    expect(await a.peers.get('B'), isNull);
    expect(await a.cursors.get('B', nearbyCursorProvider), isNull);
    expect(await a.cursors.get('B', 'icloud'), isNotNull);
  });

  test('nothing scans with auto sync off and no pairing mode', () async {
    final a = await device('A');
    final b = await device('B');
    await pair(a, b);
    a.auto = false;
    await a.manager.setForeground(true);
    expect(a.carrier.isScanning, isFalse);
    expect(a.carrier.isAdvertising, isFalse);

    await a.manager.enterPairingMode();
    expect(a.carrier.isScanning, isTrue);
    await a.manager.leavePairingMode();
    expect(a.carrier.isScanning, isFalse);
  });

  test(
    'a Linux device only scans, and still syncs with an advertiser',
    () async {
      final linux = await device('A', canAdvertise: false);
      final phone = await device('B');
      await pair(linux, phone);
      await foreground([linux, phone]);
      expect(linux.carrier.isAdvertising, isFalse);
      expect(linux.engine.recordedAcks, hasLength(1));
    },
  );

  test('backgrounding stops the radio', () async {
    final a = await device('A');
    final b = await device('B');
    await pair(a, b);
    await a.manager.setForeground(true);
    expect(a.carrier.isScanning, isTrue);
    await a.manager.setForeground(false);
    expect(a.carrier.isScanning, isFalse);
    expect(a.carrier.isAdvertising, isFalse);
  });
}
