import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_link_manager.dart';
import 'package:submersion/core/services/nearby/nearby_peer_store.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';

import '../../../helpers/global_test_defaults.dart';
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

  test('a pairing this diver confirmed gives way to its twin on both '
      'devices, so the two still pair', () async {
    final a = await device('A');
    final b = await device('B');
    // B's nonce is the lower, so the pairing B starts is the one both keep.
    a.pairingNonce = () => 'nonce-z';
    b.pairingNonce = () => 'nonce-a';
    // Only A can connect at first: A's pairing is the one the divers see.
    b.carrier.refuseConnects = true;
    await a.manager.setForeground(true);
    await b.manager.setForeground(true);
    await a.manager.enterPairingMode();
    await b.manager.enterPairingMode();
    await settleNearby();
    final first = a.manager.currentPairings.single.confirm().then(
      (_) => 'paired',
      onError: (Object _) => 'replaced',
    );
    await pumpEventQueue();

    // B now meets A from its own side.
    b.carrier.refuseConnects = false;
    await b.manager.refresh();
    await settleNearby();
    expect(await first, 'replaced');
    final onA = a.manager.currentPairings.single;
    final onB = b.manager.currentPairings.single;
    expect(onA.code, onB.code, reason: 'one pairing, on both screens');
    await expectLater(Future.wait([onA.confirm(), onB.confirm()]), completes);
    await settleNearby();
    expect(await a.peers.get('B'), isNotNull);
    expect(await b.peers.get('A'), isNotNull);
  });

  test('a session cut short by a lost link is tried again at the next '
      'sighting, not after the cooldown', () async {
    final a = await device('A');
    final b = await device('B');
    await pairNearbyTestDevices(a, b);
    // A holds a writer B has never heard of: its half is a full copy, and
    // the link drops part way through it.
    a.engine
      ..marks = {...a.engine.marks, 'Z': fakeHlc(5, 'Z')}
      ..fullContent = incompressibleJson(40000);
    hub.cutAfterBytes('A', 20000);
    await foregroundNearbyTestDevices([a, b]);
    expect(b.engine.appliedFiles, isEmpty, reason: 'the link dropped');

    hub.heal('A');
    await a.manager.refresh();
    await b.manager.refresh();
    await settleNearby();
    expect(b.engine.appliedFiles, hasLength(1));
  });

  test('unpairing the device a Sync now is looking for ends that Sync now '
      'and turns the radio off', () async {
    final a = await device('A');
    final b = await device('B');
    await pairNearbyTestDevices(a, b);
    a.auto = false; // only the Sync now wants the radio
    await a.manager.setForeground(true);
    final looking = a.manager.syncNow('B'); // B is not open: never found
    await pumpEventQueue();
    expect(a.carrier.isScanning, isTrue);

    await a.manager.unpair('B');
    final outcome = await looking.timeout(const Duration(seconds: 2));
    expect(outcome?.error, NearbyPeerError.notPaired);
    expect(a.carrier.isScanning, isFalse);
  });

  test('a peer that fails the same way every time is tried again only a '
      'few times before it waits out the cooldown', () async {
    final a = await device('A');
    final b = await device('B');
    await pairNearbyTestDevices(a, b);
    // A holds a writer B has never heard of but cannot write the copy (a
    // full disk), so every session fails; B sees only its link drop.
    a.engine
      ..marks = {...a.engine.marks, 'Z': fakeHlc(5, 'Z')}
      ..fullContent = null;
    var links = 0;
    for (final d in [a, b]) {
      final sub = d.carrier.incoming.listen((_) => links++);
      addTearDown(sub.cancel);
    }
    await foregroundNearbyTestDevices([a, b]);
    final counts = <int>[];
    for (var i = 0; i < 8; i++) {
      await a.manager.refresh();
      await b.manager.refresh();
      await settleNearby();
      counts.add(links);
    }
    expect(counts.first, greaterThan(1), reason: 'retried at first');
    expect(counts.last, counts[counts.length - 3], reason: 'then it waits');
  });

  test('with the automatic switch off, a paired device that dials in while '
      'Sync now looks for another one runs no session', () async {
    final a = await device('A');
    final b = await device('B');
    final c = await device('C');
    await pairNearbyTestDevices(a, b);
    await pairNearbyTestDevices(a, c);
    a.auto = false;
    a.carrier.refuseConnects = true; // only B's dial can reach A
    await a.manager.setForeground(true);
    unawaited(a.manager.syncNow('C')); // C is not open: never found
    await pumpEventQueue();
    await b.manager.setForeground(true); // B sees A advertising and dials
    await settleNearby();
    expect(a.engine.recordedApplied, isEmpty);
    expect((await a.peers.get('B'))!.lastSyncedAt, isNull);
  });

  test('unpairing a device mid-session tells a Sync now waiting on that '
      'session it was unpaired, not that it is out of range', () async {
    final a = await device('A');
    final b = await device('B');
    await pairNearbyTestDevices(a, b);
    a.engine
      ..marks = {...a.engine.marks, 'Z': fakeHlc(5, 'Z')}
      ..fullContent = '{}'
      ..exportDelay = const Duration(milliseconds: 300);
    await a.manager.setForeground(true);
    await b.manager.setForeground(true);
    for (var i = 0; i < 50; i++) {
      if (a.manager.state == NearbyLinkState.syncing) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(a.manager.state, NearbyLinkState.syncing);

    final outcome = a.manager.syncNow('B');
    await a.manager.unpair('B');
    expect((await outcome)?.error, NearbyPeerError.notPaired);
  });

  test('a device is seen as soon as its session starts, not only when a '
      'long copy ends', () async {
    final a = await device('A');
    final b = await device('B');
    await pairNearbyTestDevices(a, b);
    a.engine
      ..marks = {...a.engine.marks, 'Z': fakeHlc(5, 'Z')}
      ..fullContent = '{}'
      ..exportDelay = const Duration(milliseconds: 300);
    await foregroundNearbyTestDevices([a, b]);
    for (var i = 0; i < 50; i++) {
      if (a.manager.state == NearbyLinkState.syncing) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(a.manager.state, NearbyLinkState.syncing);
    expect((await a.peers.get('B'))!.lastSeenAt, isNotNull);
  });

  test('entering demo mode ends a running session before the sample '
      'logbook opens', () async {
    final a = await device('A');
    final b = await device('B');
    await pairNearbyTestDevices(a, b);
    a.engine
      ..marks = {...a.engine.marks, 'Z': fakeHlc(5, 'Z')}
      ..fullContent = '{}'
      ..exportDelay = const Duration(milliseconds: 300);
    await foregroundNearbyTestDevices([a, b]);
    for (var i = 0; i < 50; i++) {
      if (a.manager.state == NearbyLinkState.syncing) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(a.manager.state, NearbyLinkState.syncing);

    DemoModeGate.instance.debugActive = true;
    addTearDown(applyGlobalTestDefaults);
    await a.manager.refresh();
    expect(a.manager.state, isNot(NearbyLinkState.syncing));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await settleNearby();
    expect(b.engine.recordedApplied, isEmpty, reason: 'nothing was sent');
  });

  test('unpairing a device removes the copies kept for it', () async {
    final a = await device('A');
    final b = await device('B');
    await pairNearbyTestDevices(a, b);
    // A's full copy for B is cut off part way, so A keeps it for a resume.
    a.engine
      ..marks = {...a.engine.marks, 'Z': fakeHlc(5, 'Z')}
      ..fullContent = incompressibleJson(40000);
    hub.cutAfterBytes('A', 20000);
    await foregroundNearbyTestDevices([a, b]);
    List<String> keptForB() => [
      for (final f in a.temp.listSync())
        if (p.basename(f.path).startsWith('nearby-out-B')) p.basename(f.path),
    ];
    expect(keptForB(), isNotEmpty);

    await a.manager.unpair('B');
    expect(keptForB(), isEmpty);
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
