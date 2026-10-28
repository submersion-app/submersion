import 'dart:async';

import 'package:flutter/services.dart';

import 'package:submersion/core/services/nearby/nearby_carrier.dart';

/// How close a nearby Apple device is, from ultra-wideband ranging.
typedef MultipeerProximity = ({String transportId, double meters});

/// Apple's Multipeer Connectivity as a nearby carrier (issue #3728): the
/// faster, Bluetooth plus direct Wi-Fi path between Apple devices, used only
/// for buddy card swaps. Native code lives in `MultipeerHandler.swift` on
/// iOS and macOS.
///
/// One method channel both ways. Dart calls `isSupported`, `advertise`,
/// `browse`, `connect`, `send` and `close`; native calls `onEvent` with a
/// map whose `type` is `found`, `lost`, `incoming`, `data`, `closed` or
/// `proximity`.
class MultipeerNearbyCarrier implements NearbyCarrier {
  MultipeerNearbyCarrier({
    MethodChannel channel = const MethodChannel('app.submersion/multipeer'),
  }) : _channel = channel {
    _channel.setMethodCallHandler(_onCall);
  }

  final MethodChannel _channel;
  final _sightings = StreamController<NearbyPeerSighting>.broadcast();
  final _incoming = StreamController<NearbyEndpoint>.broadcast();
  final _availability = StreamController<NearbyAvailability>.broadcast();
  final _proximity = StreamController<MultipeerProximity>.broadcast();
  final _ends = <String, _MultipeerEnd>{};

  @override
  bool get canAdvertise => true;

  Stream<MultipeerProximity> get proximity => _proximity.stream;

  @override
  Stream<NearbyPeerSighting> get sightings => _sightings.stream;

  @override
  Stream<NearbyEndpoint> get incoming => _incoming.stream;

  @override
  Stream<NearbyAvailability> get availability => _availability.stream;

  @override
  Future<NearbyAvailability> checkAvailability() async {
    final supported = await _channel.invokeMethod<bool>('isSupported');
    return supported == true
        ? NearbyAvailability.ready
        : NearbyAvailability.unsupported;
  }

  @override
  Future<void> startAdvertising() => _channel.invokeMethod('advertise', true);

  @override
  Future<void> stopAdvertising() => _channel.invokeMethod('advertise', false);

  @override
  Future<void> startScanning() => _channel.invokeMethod('browse', true);

  @override
  Future<void> stopScanning() => _channel.invokeMethod('browse', false);

  @override
  Future<NearbyEndpoint> connect(String transportId) async {
    try {
      await _channel.invokeMethod('connect', {'peerId': transportId});
    } on PlatformException catch (e) {
      throw NearbyConnectFailed(e.message ?? e.code);
    }
    return _open(transportId, isInitiator: true);
  }

  _MultipeerEnd _open(String peerId, {required bool isInitiator}) {
    _ends.remove(peerId)?._closeLocally();
    final end = _MultipeerEnd(this, peerId, isInitiator);
    _ends[peerId] = end;
    return end;
  }

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method != 'onEvent') return null;
    final event = call.arguments;
    if (event is! Map) return null;
    final peerId = event['peerId'];
    if (peerId is! String) return null;
    switch (event['type']) {
      case 'found':
        _sightings.add(
          NearbyPeerSighting(transportId: peerId, seenAt: DateTime.now()),
        );
      case 'incoming':
        _incoming.add(_open(peerId, isInitiator: false));
      case 'data':
        final bytes = event['bytes'];
        if (bytes is Uint8List) _ends[peerId]?._receive(bytes);
      case 'closed':
        _ends.remove(peerId)?._closeLocally();
      case 'proximity':
        final meters = event['meters'];
        if (meters is num) {
          _proximity.add((transportId: peerId, meters: meters.toDouble()));
        }
    }
    return null;
  }

  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    for (final end in _ends.values.toList()) {
      end._closeLocally();
    }
    _ends.clear();
    await _sightings.close();
    await _incoming.close();
    await _availability.close();
    await _proximity.close();
  }
}

class _MultipeerEnd implements NearbyEndpoint {
  _MultipeerEnd(this._carrier, this.transportId, this.isInitiator);

  final MultipeerNearbyCarrier _carrier;
  final _inbound = StreamController<Uint8List>();
  bool _closed = false;

  @override
  final String transportId;

  @override
  final bool isInitiator;

  @override
  Stream<Uint8List> get inbound => _inbound.stream;

  void _receive(Uint8List bytes) {
    if (!_closed) _inbound.add(bytes);
  }

  void _closeLocally() {
    if (_closed) return;
    _closed = true;
    unawaited(_inbound.close());
  }

  @override
  Future<void> send(Uint8List bytes) async {
    if (_closed) throw const NearbyLinkClosed();
    try {
      await _carrier._channel.invokeMethod('send', {
        'peerId': transportId,
        'bytes': bytes,
      });
    } on PlatformException {
      _closeLocally();
      throw const NearbyLinkClosed();
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closeLocally();
    if (_carrier._ends[transportId] == this) {
      _carrier._ends.remove(transportId);
    }
    await _carrier._channel.invokeMethod('close', {'peerId': transportId});
  }
}
