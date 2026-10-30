import 'dart:typed_data';

import 'package:submersion/core/services/nearby/nearby_carrier.dart';

/// An endpoint that passes everything to [inner]; a test wrapper extends
/// it and overrides only what it changes (usually [send]).
class ForwardingNearbyEndpoint implements NearbyEndpoint {
  ForwardingNearbyEndpoint(this.inner);

  final NearbyEndpoint inner;

  @override
  Stream<Uint8List> get inbound => inner.inbound;

  @override
  Future<void> send(Uint8List bytes) => inner.send(bytes);

  @override
  Future<void> close() => inner.close();

  @override
  bool get isInitiator => inner.isInitiator;

  @override
  String get transportId => inner.transportId;
}
