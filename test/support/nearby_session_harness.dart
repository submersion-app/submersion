import 'dart:typed_data';

import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_hello.dart';
import 'package:submersion/core/services/nearby/nearby_session.dart';

import 'in_memory_nearby_carrier.dart';
import 'memory_nearby_secrets.dart';

NearbyIdentity nearbySessionIdentity(
  String id, {
  String? epoch = 'epoch-1',
  bool hasDives = true,
  int schema = 319,
}) => NearbyIdentity(
  deviceId: id,
  deviceName: 'Device $id',
  appVersion: '1.8.4',
  schemaVersion: schema,
  schemaFloor: 308,
  epochId: epoch,
  hasDives: hasDives,
);

/// Opens a link from 'laptop' (initiator) to 'phone' (responder).
Future<(NearbyEndpoint, NearbyEndpoint)> nearbyLink() async {
  final hub = InMemoryNearbyHub();
  final phone = hub.join('phone');
  final laptop = hub.join('laptop');
  await phone.startAdvertising();
  final incoming = phone.incoming.first;
  final out = await laptop.connect('phone');
  return (out, await incoming);
}

/// Pairs devices L and P over a fresh link and returns their secret
/// stores.
Future<(MemoryNearbySecrets, MemoryNearbySecrets)> pairNearbySessions() async {
  final (out, into) = await nearbyLink();
  final l = MemoryNearbySecrets();
  final p = MemoryNearbySecrets();
  final incoming = NearbySession(
    endpoint: into,
    identity: nearbySessionIdentity('P'),
    secrets: p,
  ).accept(allowPairing: true);
  final outgoing = await NearbySession(
    endpoint: out,
    identity: nearbySessionIdentity('L'),
    secrets: l,
  ).openPairing();
  final accepted = await incoming as NearbyIncomingPairing;
  await Future.wait([outgoing.confirm(), accepted.pairing.confirm()]);
  return (l, p);
}

/// Passes everything through and keeps a copy of what this side sent.
class RecordingNearbyEndpoint implements NearbyEndpoint {
  RecordingNearbyEndpoint(this._inner);

  final NearbyEndpoint _inner;
  final sent = <int>[];

  @override
  Stream<Uint8List> get inbound => _inner.inbound;

  @override
  Future<void> send(Uint8List bytes) {
    sent.addAll(bytes);
    return _inner.send(bytes);
  }

  @override
  Future<void> close() => _inner.close();

  @override
  bool get isInitiator => _inner.isInitiator;

  @override
  String get transportId => _inner.transportId;
}
