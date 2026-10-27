import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_link_manager.dart';

import '../../../support/fake_nearby_sync_engine.dart';
import '../../../support/in_memory_nearby_carrier.dart';
import '../../../support/nearby_link_harness.dart';

/// Holds every availability check until [gate] opens.
class _GatedAvailability extends CountingNearbyCarrier {
  _GatedAvailability(InMemoryNearbyCarrier inner, this.gate)
    : super(inner, () {});

  final Future<void> gate;

  /// Completes once a check is waiting on [gate].
  final reached = Completer<void>();

  @override
  Future<NearbyAvailability> checkAvailability() async {
    if (!reached.isCompleted) reached.complete();
    await gate;
    return inner.checkAvailability();
  }
}

/// What the link does around its own end and the pairing page's (issue
/// #3731).
void main() {
  late InMemoryNearbyHub hub;

  setUp(() => hub = InMemoryNearbyHub());

  Future<NearbyTestDevice> device(String id) => joinNearbyTestDevice(hub, id);

  test('a handshake that finishes after dispose runs no session', () async {
    final a = await device('A');
    final b = await device('B');
    await pairNearbyTestDevices(a, b);
    a.engine.identityDelay = const Duration(milliseconds: 80);
    b.engine.identityDelay = const Duration(milliseconds: 80);
    await a.manager.setForeground(true);
    await b.manager.setForeground(true);
    await a.manager.dispose();
    for (var i = 0; i < 3; i++) {
      await settleNearby();
    }
    expect(a.engine.recordedAcks, isEmpty);
    expect(a.engine.recordedApplied, isEmpty);
  });

  test('dispose stops a radio that a refresh in flight turns on', () async {
    final a = await device('A');
    final b = await device('B');
    await pairNearbyTestDevices(a, b);
    final gate = Completer<void>();
    final carrier = _GatedAvailability(a.carrier, gate.future);
    final manager = NearbyLinkManager(
      carrier: carrier,
      engine: a.engine,
      secrets: a.secrets,
      peers: a.peers,
      cursors: a.cursors,
      autoSyncEnabled: () => true,
      tempDir: () async => a.temp,
    );
    final started = manager.setForeground(true);
    await carrier.reached.future;
    final disposed = manager.dispose();
    gate.complete();
    await started;
    await disposed;
    expect(a.carrier.isScanning, isFalse);
    expect(a.carrier.isAdvertising, isFalse);
  });

  test('a pairing this diver confirmed still completes after they leave '
      'the pairing page', () async {
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
    await settleNearby();

    final aConfirm = aOffers.last.single.confirm();
    await pumpEventQueue();
    await a.manager.leavePairingMode(); // the diver went back
    await expectLater(
      Future.wait([aConfirm, bOffers.last.single.confirm()]),
      completes,
    );
    await settleNearby();
    expect(await a.peers.get('B'), isNotNull);
    expect(await b.peers.get('A'), isNotNull);
  });

  test('reopening the pairing page shows a confirmed pairing as such, once, '
      'and a second tap confirms nothing twice', () async {
    final a = await device('A');
    final b = await device('B');
    final bOffers = <List<NearbyPairingHandle>>[];
    b.manager.pendingPairings.listen(bOffers.add);
    await a.manager.setForeground(true);
    await b.manager.setForeground(true);
    await a.manager.enterPairingMode();
    await b.manager.enterPairingMode();
    await settleNearby();

    final aConfirm = a.manager.currentPairings.single.confirm();
    await pumpEventQueue();
    await a.manager.leavePairingMode();
    await a.manager.enterPairingMode(); // the diver came back
    await settleNearby();
    final shown = a.manager.currentPairings;
    expect(shown, hasLength(1));
    expect(shown.single.confirming, isTrue);
    expect(b.manager.currentPairings, hasLength(1), reason: 'no second card');

    final again = shown.single.confirm();
    await expectLater(
      Future.wait([aConfirm, again, bOffers.last.single.confirm()]),
      completes,
    );
    await settleNearby();
    expect(await a.peers.get('B'), isNotNull);
    expect(await b.peers.get('A'), isNotNull);
  });

  test('a session replaced by its twin does not end the progress the twin '
      'is reporting', () async {
    final a = await device('A');
    final b = await device('B');
    await pairNearbyTestDevices(a, b);
    // A holds a writer B has never heard of, so A's half of every session
    // is a full copy that takes a while to prepare: B's session is still
    // running when A's own dial, which lands later, replaces it.
    a.engine
      ..marks = {...a.engine.marks, 'Z': fakeHlc(5, 'Z')}
      ..fullContent = '{}'
      ..exportDelay = const Duration(milliseconds: 300);
    final manager = NearbyLinkManager(
      carrier: _SlowConnect(a.carrier),
      engine: a.engine,
      secrets: a.secrets,
      peers: a.peers,
      cursors: a.cursors,
      autoSyncEnabled: () => true,
      tempDir: () async => a.temp,
      retryAfter: Duration.zero,
    );
    addTearDown(manager.dispose);
    final finished = <String>[];
    manager.progress.listen((p) {
      if (p.finished) finished.add(p.peerDeviceId);
    });
    await b.manager.setForeground(true);
    await manager.setForeground(true);
    for (var i = 0; i < 6; i++) {
      await settleNearby();
    }
    expect(a.engine.recordedAcks, hasLength(1));
    expect(finished, ['B']);
  });
}

/// Connects only after a pause, so a peer's own connection lands first.
class _SlowConnect extends CountingNearbyCarrier {
  _SlowConnect(InMemoryNearbyCarrier inner) : super(inner, () {});

  @override
  Future<NearbyEndpoint> connect(String transportId) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return inner.connect(transportId);
  }
}
