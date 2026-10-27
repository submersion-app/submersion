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
import 'package:submersion/core/services/nearby/nearby_sync_protocol.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';

import '../../../helpers/global_test_defaults.dart';
import '../../../support/fake_nearby_sync_engine.dart';
import '../../../support/in_memory_nearby_carrier.dart';
import '../../../support/memory_nearby_secrets.dart';

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
  final secrets = MemoryNearbySecrets();
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
    expect(aHandle.peerName, 'Device B');
    expect(bHandle.peerName, 'Device A');
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

  test(
    'with Bluetooth still off a refresh does not rewrite the rows',
    () async {
      final a = await device('A');
      final b = await device('B');
      await pair(a, b);
      hub.setAvailability('A', NearbyAvailability.bluetoothOff);
      await a.manager.setForeground(true);
      await _settle();
      var emissions = 0;
      final sub = a.peers.watchAll().listen((_) => emissions++);
      addTearDown(sub.cancel);
      await _settle();
      final settled = emissions;
      for (var i = 0; i < 3; i++) {
        await a.manager.refresh();
      }
      await _settle();
      expect(emissions, settled);
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
    expect(a.secrets.revokedMap.keys, [
      'B',
    ], reason: 'kept aside to tell B it is unpaired');
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

  test(
    'pairing with a device on another library is reported, not offered',
    () async {
      final a = await device('A');
      final b = await device('B');
      b.engine.self = const NearbyIdentity(
        deviceId: 'B',
        deviceName: 'Device B',
        appVersion: '1.8.4',
        schemaVersion: 320,
        schemaFloor: 308,
        epochId: 'epoch-2',
        hasDives: true,
      );
      final refusals = <NearbyErrorCode>[];
      a.manager.pairingRefusals.listen(refusals.add);
      b.manager.pairingRefusals.listen(refusals.add);
      await a.manager.setForeground(true);
      await b.manager.setForeground(true);
      await a.manager.enterPairingMode();
      await b.manager.enterPairingMode();
      await _settle();
      expect(refusals, contains(NearbyErrorCode.differentLibrary));
      expect(a.manager.currentPairings, isEmpty);
      expect(b.manager.currentPairings, isEmpty);
    },
  );

  test('checkAvailability reports the radio state', () async {
    final a = await device('A');
    expect(await a.manager.checkAvailability(), NearbyAvailability.ready);
    hub.setAvailability('A', NearbyAvailability.unauthorized);
    expect(
      await a.manager.checkAvailability(),
      NearbyAvailability.unauthorized,
    );
  });

  group('review fixes', () {
    test(
      'two sessions from one peer finishing together run only once',
      () async {
        final a = await device('A');
        final b = await device('B');
        await pair(a, b);
        a.engine.identityDelay = const Duration(milliseconds: 20);
        await a.manager.setForeground(true);
        // B, driven by hand, opens two sessions to A at the same moment.
        Future<NearbySyncOutcome> one() async {
          final endpoint = await b.carrier.connect('A');
          final channel = await NearbySession(
            endpoint: endpoint,
            identity: b.engine.self,
            secrets: b.secrets,
          ).openSync();
          return NearbySyncProtocol(
            channel: channel,
            engine: b.engine,
            peers: b.peers,
            tempDir: () async => b.temp,
          ).run();
        }

        await Future.wait([one(), one()]);
        await _settle();
        expect(
          a.engine.recordedApplied,
          hasLength(1),
          reason: 'the second session was closed before it synced',
        );
      },
    );

    test('a peer that unpaired this device is shown as such, even unmet '
        'in this run', () async {
      final a = await device('A');
      final b = await device('B');
      await pair(a, b);
      // B unpairs A while A is not around; A's manager never met B's radio.
      await b.secrets.revoke('A');
      await b.peers.remove('A');
      // Another real pairing keeps B's radio on.
      await b.peers.upsertPaired(
        peerDeviceId: 'C',
        displayName: 'C',
        pairedAt: 1,
      );
      await b.secrets.store('C', Uint8List(32));
      await foreground([a, b]);
      expect(
        a.peers.errorOf((await a.peers.get('B'))!),
        NearbyPeerError.notPaired,
      );
      expect(a.engine.recordedApplied, isEmpty);
    });

    test('Sync now works with the automatic switch off', () async {
      final a = await device('A');
      final b = await device('B');
      await pair(a, b);
      a.auto = false;
      await b.manager.setForeground(true);
      await a.manager.setForeground(true);
      expect(a.carrier.isScanning, isFalse);
      final outcome = await a.manager.syncNow('B');
      expect(outcome, isNotNull);
      expect(outcome!.error, isNull);
      expect(a.engine.recordedAcks.where((r) => r.peer == 'B'), isNotEmpty);
      await _settle();
      expect(a.carrier.isScanning, isFalse, reason: 'off again after');
    });

    test('Sync now gives up when the peer is nowhere near', () async {
      final a = await device('A');
      final b = await device('B');
      await pair(a, b);
      a.auto = false;
      final manager = NearbyLinkManager(
        carrier: a.carrier,
        engine: a.engine,
        secrets: a.secrets,
        peers: a.peers,
        cursors: a.cursors,
        autoSyncEnabled: () => false,
        tempDir: () async => a.temp,
        syncNowTimeout: const Duration(milliseconds: 100),
      );
      addTearDown(manager.dispose);
      await manager.setForeground(true);
      expect(await manager.syncNow('B'), isNull);
    });

    test('a stranger is not dialled again on every sighting', () async {
      final a = await device('A');
      final stranger = await device('S');
      final c = await device('C');
      await pair(a, c);
      await pair(stranger, c); // so the stranger runs its radio too
      var dials = 0;
      final counting = _CountingCarrier(a.carrier, () => dials++);
      final manager = NearbyLinkManager(
        carrier: counting,
        engine: a.engine,
        secrets: a.secrets,
        peers: a.peers,
        cursors: a.cursors,
        autoSyncEnabled: () => true,
        tempDir: () async => a.temp,
        retryAfter: Duration.zero,
      );
      addTearDown(manager.dispose);
      await stranger.manager.setForeground(true);
      await manager.setForeground(true);
      await _settle();
      final first = dials;
      expect(first, greaterThan(0));
      for (var i = 0; i < 3; i++) {
        await manager.refresh();
        await _settle();
      }
      expect(dials, first, reason: 'left alone after refusing');
    });

    test(
      'a secret without a paired-devices row is dropped once per run',
      () async {
        final a = await device('A');
        await a.secrets.store('ghost', Uint8List(32));
        await a.peers.upsertPaired(
          peerDeviceId: 'B',
          displayName: 'B',
          pairedAt: 1,
        );
        await a.secrets.store('B', Uint8List(32));
        await a.manager.setForeground(true);
        expect(await a.secrets.secretFor('ghost'), isNull);
        expect(await a.secrets.secretFor('B'), isNotNull);
      },
    );

    test('a paired row with no secret here (a restored or copied database) '
        'is dropped with its cursor', () async {
      final a = await device('A');
      await a.peers.upsertPaired(
        peerDeviceId: 'old-phone',
        displayName: 'Old phone',
        pairedAt: 1,
      );
      await a.cursors.upsert(
        peerDeviceId: 'old-phone',
        provider: 'nearby',
        lastSeqApplied: 0,
        appliedHlcHigh: fakeHlc(3, 'old-phone'),
      );
      await a.peers.upsertPaired(
        peerDeviceId: 'B',
        displayName: 'B',
        pairedAt: 2,
      );
      await a.secrets.store('B', Uint8List(32));
      await a.manager.setForeground(true);
      expect(await a.peers.get('old-phone'), isNull);
      expect(await a.peers.get('B'), isNotNull);
      expect(await a.cursors.get('old-phone', 'nearby'), isNull);
    });

    test(
      'while sealed (the sample logbook is open) the radio stays off and '
      'no pair secret is dropped, though the sample has no paired rows',
      () async {
        final a = await device('A');
        // The real library's pairing: its secret is in secure storage, which
        // the sample logbook shares, but its row is in the real database.
        await a.secrets.store('B', Uint8List(32));
        DemoModeGate.instance.debugActive = true;
        addTearDown(applyGlobalTestDefaults);
        final manager = a.manager;
        await manager.setForeground(true);
        await manager.enterPairingMode();
        await _settle();
        expect(a.carrier.isScanning, isFalse);
        expect(a.carrier.isAdvertising, isFalse);
        expect(await a.secrets.secretFor('B'), isNotNull);

        applyGlobalTestDefaults(); // the sample logbook is closed again
        await manager.refresh();
        expect(a.carrier.isScanning, isTrue, reason: 'on once unsealed');
      },
    );

    Future<void> until(bool Function() done) async {
      for (var i = 0; i < 300 && !done(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    test('a local change made while a session ran is synced right after it, '
        'not a cooldown later', () async {
      final a = await device('A');
      final b = await device('B');
      await pair(a, b);
      a.engine.identityDelay = const Duration(milliseconds: 80);
      b.engine.identityDelay = const Duration(milliseconds: 80);
      await a.manager.setForeground(true);
      await b.manager.setForeground(true);
      await until(() => a.manager.state == NearbyLinkState.syncing);
      a.now = a.now.add(const Duration(seconds: 1));
      a.changes.add(null); // the debounce fires while the session runs
      await until(() => a.engine.recordedAcks.isNotEmpty);
      expect(a.engine.recordedAcks, hasLength(1));
      await _settle();
      await a.manager.refresh(); // sighted again
      await until(() => a.engine.recordedAcks.length > 1);
      expect(a.engine.recordedAcks, hasLength(2));
    });

    test('Sync now during a running session reports that session', () async {
      final a = await device('A');
      final b = await device('B');
      await pair(a, b);
      a.engine.identityDelay = const Duration(milliseconds: 80);
      b.engine.identityDelay = const Duration(milliseconds: 80);
      await a.manager.setForeground(true);
      await b.manager.setForeground(true);
      await until(() => a.manager.state == NearbyLinkState.syncing);
      expect(a.manager.state, NearbyLinkState.syncing);
      final outcome = await a.manager.syncNow('B');
      expect(outcome, isNotNull);
      expect(outcome!.error, isNull);
    });

    test('backgrounding ends a running session without calling it a '
        'failure', () async {
      final a = await device('A');
      final b = await device('B');
      await pair(a, b);
      a.engine.identityDelay = const Duration(milliseconds: 80);
      b.engine.identityDelay = const Duration(milliseconds: 80);
      await a.manager.setForeground(true);
      await b.manager.setForeground(true);
      await until(() => a.manager.state == NearbyLinkState.syncing);
      await a.manager.setForeground(false);
      expect(a.manager.state, isNot(NearbyLinkState.syncing));
      await _settle();
      final row = (await a.peers.get('B'))!;
      expect(row.lastSyncedAt, isNull);
      expect(a.peers.errorOf(row), isNull);
      expect(a.engine.recordedAcks, isEmpty);
    });

    test('a handshake that finishes after backgrounding runs no '
        'session', () async {
      final a = await device('A');
      final b = await device('B');
      await pair(a, b);
      a.engine.identityDelay = const Duration(milliseconds: 80);
      b.engine.identityDelay = const Duration(milliseconds: 80);
      await a.manager.setForeground(true);
      await b.manager.setForeground(true);
      await a.manager.setForeground(false);
      await _settle();
      expect((await a.peers.get('B'))!.lastSyncedAt, isNull);
      expect(a.engine.recordedAcks, isEmpty);
    });

    test('a session is stamped synced only at its end', () async {
      final a = await device('A');
      final b = await device('B');
      await pair(a, b);
      await foreground([a, b]);
      expect((await a.peers.get('B'))!.lastSyncedAt, isNotNull);
      expect((await b.peers.get('A'))!.lastSyncedAt, isNotNull);
    });
  });
}

/// Passes everything to [inner] and counts the connection attempts.
class _CountingCarrier implements NearbyCarrier {
  _CountingCarrier(this.inner, this.onConnect);

  final InMemoryNearbyCarrier inner;
  final void Function() onConnect;

  @override
  bool get canAdvertise => inner.canAdvertise;

  @override
  Future<void> startAdvertising() => inner.startAdvertising();

  @override
  Future<void> stopAdvertising() => inner.stopAdvertising();

  @override
  Future<void> startScanning() => inner.startScanning();

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
