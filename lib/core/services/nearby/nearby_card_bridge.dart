import 'dart:async';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/nearby/nearby_card_host.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_hello.dart';
import 'package:submersion/core/services/nearby/nearby_session.dart';

/// Runs buddy card swaps over a carrier the link manager does not own
/// (issue #3728): Apple's Multipeer Connectivity, which is faster than
/// Bluetooth between Apple devices but never carries a logbook sync.
///
/// Its transport ids reach the [NearbyCardHost] with [prefix] in front, so
/// the host dials each diver over the carrier that saw them.
class NearbyCardBridge {
  NearbyCardBridge({
    required NearbyCarrier carrier,
    required NearbyCardHost host,
    required Future<NearbyIdentity> Function() identity,
    required NearbyPairSecrets secrets,
    this.prefix = 'mpc:',
  }) : _carrier = carrier,
       _host = host,
       _identity = identity,
       _secrets = secrets;

  static final _log = LoggerService.forClass(NearbyCardBridge);

  final NearbyCarrier _carrier;
  final NearbyCardHost _host;
  final Future<NearbyIdentity> Function() _identity;
  final NearbyPairSecrets _secrets;
  final String prefix;
  final _subs = <StreamSubscription<Object?>>[];
  bool _running = false;

  /// Starts advertising and looking; false when the carrier is not usable
  /// here.
  Future<bool> start() async {
    if (_running) return true;
    if (await _carrier.checkAvailability() != NearbyAvailability.ready) {
      return false;
    }
    _running = true;
    _host.attachCarrier(prefix, _dial);
    _subs
      ..add(
        _carrier.sightings.listen(
          (s) => _host.onSighting('$prefix${s.transportId}'),
        ),
      )
      ..add(_carrier.incoming.listen((e) => unawaited(_accept(e))));
    await _carrier.startAdvertising();
    await _carrier.startScanning();
    return true;
  }

  Future<NearbyCardChannel> _dial(String transportId) async {
    final identity = await _identity();
    final endpoint = await _carrier.connect(
      transportId.substring(prefix.length),
    );
    try {
      return await NearbySession(
        endpoint: endpoint,
        identity: identity,
        secrets: _secrets,
      ).openCard();
    } on Object {
      // The session closes its link on a refusal or a timeout; anything
      // else would leave it open, and a peer may hold only one.
      await endpoint.close();
      rethrow;
    }
  }

  Future<void> _accept(NearbyEndpoint endpoint) async {
    try {
      final incoming = await NearbySession(
        endpoint: endpoint,
        identity: await _identity(),
        secrets: _secrets,
      ).accept(allowPairing: false, allowCard: true);
      if (incoming is NearbyIncomingCard) {
        _host.onIncoming(incoming.channel);
      } else {
        await endpoint.close();
      }
    } on Object catch (e) {
      _log.info('Card session over $prefix refused: $e');
      await endpoint.close();
    }
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _host.attachCarrier(prefix, null);
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await _carrier.stopScanning();
    await _carrier.stopAdvertising();
  }
}
