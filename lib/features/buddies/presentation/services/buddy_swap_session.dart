import 'dart:async';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/nearby/multipeer/multipeer_nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_card_bridge.dart';
import 'package:submersion/core/services/nearby/nearby_card_host.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_hello.dart';
import 'package:submersion/core/services/nearby/nearby_link_manager.dart';
import 'package:submersion/core/services/nearby/nearby_session.dart';
import 'package:submersion/features/buddies/data/services/buddy_card_nfc.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_codec.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';

/// What the swap screen runs while it is open (issue #3728): looking for
/// divers nearby, answering their requests, and (on Android) presenting
/// the diver's card as an NFC tag.
abstract interface class BuddySwapSession {
  Stream<NearbyCardEvent> get events;

  /// The divers seen lately.
  List<NearbyCardPeer> get peers;

  /// Starts looking. Resolves with the Bluetooth radio's state: anything
  /// but ready means the nearby list cannot work and the screen says why.
  Future<NearbyAvailability> start();

  Future<void> request(NearbyCardPeer peer);

  /// Ends everything; the screen calls it when it closes or the app leaves
  /// the foreground.
  Future<void> stop();
}

/// Within this distance, on iPhone 11 and later, a diver held next to this
/// phone is asked to swap without a tap on their row.
const double holdTogetherMeters = 0.2;

/// The real session: the link manager's card mode over Bluetooth, plus
/// Multipeer on Apple devices and tag sharing on Android.
class NearbyBuddySwapSession implements BuddySwapSession {
  NearbyBuddySwapSession({
    required BuddyCard card,
    required NearbyLinkManager manager,
    required Future<NearbyIdentity> Function() identity,
    required NearbyPairSecrets secrets,
    required BuddyCardNfc nfc,
    MultipeerNearbyCarrier? multipeer,
  }) : _card = card,
       _manager = manager,
       _identity = identity,
       _secrets = secrets,
       _nfc = nfc,
       _multipeer = multipeer;

  static final _log = LoggerService.forClass(NearbyBuddySwapSession);

  final BuddyCard _card;
  final NearbyLinkManager _manager;
  final Future<NearbyIdentity> Function() _identity;
  final NearbyPairSecrets _secrets;
  final BuddyCardNfc _nfc;
  final MultipeerNearbyCarrier? _multipeer;

  NearbyCardHost? _host;
  NearbyCardBridge? _bridge;
  StreamSubscription<MultipeerProximity>? _proximity;
  final _events = StreamController<NearbyCardEvent>.broadcast();
  StreamSubscription<NearbyCardEvent>? _forward;
  final _heldTogether = <String>{};

  @override
  Stream<NearbyCardEvent> get events => _events.stream;

  @override
  List<NearbyCardPeer> get peers => _host?.peers ?? const [];

  /// Starts and stops run one at a time, in the order called: a stop that
  /// arrives while a start is still waiting on the radio runs after it, so
  /// the session always ends in the state last asked for.
  Future<void> _queue = Future.value();

  Future<T> _serially<T>(Future<T> Function() op) {
    final result = _queue.then((_) => op());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  Future<NearbyAvailability> start() => _serially(_start);

  Future<NearbyAvailability> _start() async {
    await _stop();
    // Demo mode (issue #3708): the sample logbook's card goes nowhere and
    // nothing is received, however the swap screen was reached. No radio,
    // no Multipeer, no tag; the screen says nearby swaps are unavailable.
    if (DemoModeGate.instance.isActive) return NearbyAvailability.unsupported;
    final full = BuddyCardCodec.encodeFull(_card);
    final host = NearbyCardHost(
      name: _card.name,
      photo: _card.photo,
      card: () async => full,
    );
    _host = host;
    _forward = host.events.listen(_events.add);
    final availability = await _manager.checkAvailability();
    await _manager.enterCardMode(host);
    final multipeer = _multipeer;
    if (multipeer != null) {
      final bridge = NearbyCardBridge(
        carrier: multipeer,
        host: host,
        identity: _identity,
        secrets: _secrets,
      );
      // Owned before it starts: a start that fails partway (advertising
      // refused) is still stopped by the normal teardown.
      _bridge = bridge;
      if (await bridge.start()) {
        _proximity = multipeer.proximity.listen(_onProximity);
      } else {
        _bridge = null;
      }
    }
    try {
      await _nfc.startSharing(_card);
    } on Object catch (e) {
      _log.info('Buddy card tag sharing did not start: $e');
    }
    return availability;
  }

  /// A diver held next to this phone is asked once, as if their row was
  /// tapped; they still answer on their own phone.
  void _onProximity(MultipeerProximity reading) {
    if (reading.meters > holdTogetherMeters) return;
    final host = _host;
    if (host == null) return;
    final transport = '${_bridge?.prefix ?? 'mpc:'}${reading.transportId}';
    for (final peer in host.peers) {
      if (peer.transportId == transport && _heldTogether.add(peer.swapId)) {
        unawaited(host.request(peer));
      }
    }
  }

  @override
  Future<void> request(NearbyCardPeer peer) async => _host?.request(peer);

  @override
  Future<void> stop() => _serially(_stop);

  Future<void> _stop() async {
    await _proximity?.cancel();
    _proximity = null;
    await _bridge?.stop();
    _bridge = null;
    await _forward?.cancel();
    _forward = null;
    if (_host != null) await _manager.leaveCardMode();
    _host = null;
    _heldTogether.clear();
    try {
      await _nfc.stopSharing();
    } on Object catch (e) {
      _log.info('Buddy card tag sharing did not stop: $e');
    }
  }
}
