import 'dart:async';
import 'dart:typed_data';

import 'package:submersion/core/services/nearby/nearby_carrier.dart';

/// A room full of nearby devices in one process, for tests: carriers joined
/// to the same hub see each other's advertising and connect through
/// in-memory pipes.
class InMemoryNearbyHub {
  /// [centralIds]: a device that connects shows up at the other end under
  /// an id of its own, not its advertised one, as on Bluetooth.
  InMemoryNearbyHub({this.centralIds = false});

  final bool centralIds;
  final _carriers = <String, InMemoryNearbyCarrier>{};
  final _budgets = <String, int>{};

  InMemoryNearbyCarrier join(String transportId, {bool canAdvertise = true}) {
    final carrier = InMemoryNearbyCarrier._(this, transportId, canAdvertise);
    _carriers[transportId] = carrier;
    return carrier;
  }

  /// The carrier already joined as [transportId], if any.
  InMemoryNearbyCarrier? carrier(String transportId) => _carriers[transportId];

  /// Every link that [transportId] opens or accepts from now on closes, at
  /// both ends, once a send would take the bytes crossed past [bytes]. The
  /// send that crosses the budget delivers nothing.
  void cutAfterBytes(String transportId, int bytes) {
    _budgets[transportId] = bytes;
    for (final pipe in _carriers[transportId]?._pipes ?? const <_Pipe>[]) {
      pipe.budget = bytes - pipe.crossed;
    }
  }

  /// Bytes sent, both ways, over every link [transportId] opened or
  /// accepted so far.
  int bytesCrossed(String transportId) => [
    for (final pipe in _carriers[transportId]?._pipes ?? const <_Pipe>[])
      pipe.crossed,
  ].fold(0, (a, b) => a + b);

  /// Links still open, across every device: a Bluetooth peripheral holds
  /// one connection at a time, so short sessions must close theirs.
  int get openLinks => {
    for (final c in _carriers.values)
      for (final pipe in c._pipes)
        if (!pipe.closed) pipe,
  }.length;

  /// Removes a cut set by [cutAfterBytes] for links opened from now on.
  void heal(String transportId) => _budgets.remove(transportId);

  void setAvailability(String transportId, NearbyAvailability state) {
    final carrier = _carriers[transportId];
    if (carrier == null) return;
    carrier._state = state;
    carrier._availability.add(state);
  }

  void _advertised(InMemoryNearbyCarrier advertiser) {
    for (final c in _carriers.values) {
      if (c != advertiser && c._scanning) c._sight(advertiser.transportId);
    }
  }
}

class InMemoryNearbyCarrier implements NearbyCarrier {
  InMemoryNearbyCarrier._(this._hub, this.transportId, this.canAdvertise);

  final InMemoryNearbyHub _hub;
  final String transportId;

  @override
  final bool canAdvertise;

  bool _advertising = false;
  NearbyAvailability _state = NearbyAvailability.ready;
  bool _scanning = false;
  final _pipes = <_Pipe>[];
  final _sightings = StreamController<NearbyPeerSighting>.broadcast();
  final _incoming = StreamController<NearbyEndpoint>.broadcast();
  final _availability = StreamController<NearbyAvailability>.broadcast();

  /// Every connect from this carrier fails, as a busy or out-of-range
  /// radio's would.
  bool refuseConnects = false;

  bool get isAdvertising => _advertising;
  bool get isScanning => _scanning;

  void _sight(String id) => _sightings.add(
    NearbyPeerSighting(transportId: id, seenAt: DateTime.now()),
  );

  @override
  Future<void> startAdvertising() async {
    if (!canAdvertise) {
      throw UnsupportedError('$transportId cannot advertise');
    }
    _advertising = true;
    _hub._advertised(this);
  }

  @override
  Future<void> stopAdvertising() async => _advertising = false;

  @override
  Future<void> startScanning() async {
    _scanning = true;
    for (final c in _hub._carriers.values) {
      if (c != this && c._advertising) _sight(c.transportId);
    }
  }

  @override
  Future<void> stopScanning() async => _scanning = false;

  @override
  Stream<NearbyPeerSighting> get sightings => _sightings.stream;

  @override
  Stream<NearbyEndpoint> get incoming => _incoming.stream;

  @override
  Stream<NearbyAvailability> get availability => _availability.stream;

  @override
  Future<NearbyAvailability> checkAvailability() async => _state;

  @override
  Future<NearbyEndpoint> connect(String targetId) async {
    if (refuseConnects) throw const NearbyConnectFailed('refused by the test');
    final target = _hub._carriers[targetId];
    if (target == null || !target._advertising) {
      throw NearbyConnectFailed('$targetId is not advertising');
    }
    final budget = _hub._budgets[transportId] ?? _hub._budgets[targetId];
    final pipe = _Pipe(budget);
    _pipes.add(pipe);
    target._pipes.add(pipe);
    final initiator = _PipeEnd(pipe, isInitiator: true, transportId: targetId);
    final responder = _PipeEnd(
      pipe,
      isInitiator: false,
      transportId: _hub.centralIds ? 'central-$transportId' : transportId,
    );
    pipe.ends = (initiator, responder);
    target._incoming.add(responder);
    return initiator;
  }
}

class _Pipe {
  _Pipe(this.budget);

  int? budget;
  int crossed = 0;
  bool closed = false;
  late (_PipeEnd, _PipeEnd) ends;

  void close() {
    if (closed) return;
    closed = true;
    // Queued behind any delivery already scheduled, so bytes sent before
    // the close still arrive, as they would over a real link.
    scheduleMicrotask(() {
      ends.$1._inbound.close();
      ends.$2._inbound.close();
    });
  }
}

class _PipeEnd implements NearbyEndpoint {
  _PipeEnd(this._pipe, {required this.isInitiator, required this.transportId});

  final _Pipe _pipe;
  final _inbound = StreamController<Uint8List>();

  @override
  final bool isInitiator;

  @override
  final String transportId;

  _PipeEnd get _other => isInitiator ? _pipe.ends.$2 : _pipe.ends.$1;

  @override
  Stream<Uint8List> get inbound => _inbound.stream;

  @override
  Future<void> send(Uint8List bytes) async {
    if (_pipe.closed) throw const NearbyLinkClosed();
    final budget = _pipe.budget;
    if (budget != null && _pipe.crossed + bytes.length > budget) {
      _pipe.close();
      return;
    }
    _pipe.crossed += bytes.length;
    // Deliver asynchronously, as a radio would.
    final copy = Uint8List.fromList(bytes);
    scheduleMicrotask(() {
      if (!_other._inbound.isClosed) _other._inbound.add(copy);
    });
  }

  @override
  Future<void> close() async => _pipe.close();
}
