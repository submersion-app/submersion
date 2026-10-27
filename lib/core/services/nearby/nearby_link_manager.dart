import 'dart:async';
import 'dart:io';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_hello.dart';
import 'package:submersion/core/services/nearby/nearby_peer_store.dart';
import 'package:submersion/core/services/nearby/nearby_session.dart';
import 'package:submersion/core/services/nearby/nearby_sync_engine.dart';
import 'package:submersion/core/services/nearby/nearby_sync_protocol.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';

enum NearbyLinkState { off, scanning, syncing }

/// How far the transfer with one peer has got; [finished] marks the end
/// of its session.
class NearbySyncProgress {
  const NearbySyncProgress({
    required this.peerDeviceId,
    required this.done,
    required this.total,
    this.finished = false,
  });

  final String peerDeviceId;
  final int done;
  final int total;
  final bool finished;
}

/// A pairing waiting for the diver to compare the codes on both screens.
abstract class NearbyPairingOffer {
  NearbyIdentity get peer;
  String get code;
  bool get bothPopulated;

  /// Completes once both divers confirmed: the devices are paired and the
  /// first sync has started. Throws [NearbyPairingRejected] when the other
  /// diver tapped "Not mine", or a timeout when they never answered.
  Future<void> confirm();

  Future<void> reject();
}

class NearbyPairingHandle implements NearbyPairingOffer {
  NearbyPairingHandle._(
    this._manager,
    this._pairing, {
    required this.initiatorId,
  });

  final NearbyLinkManager _manager;
  final NearbyPairing _pairing;

  /// The device that connected; with two pairings between the same pair
  /// of devices, the one started by the lower device id is kept.
  final String initiatorId;

  @override
  NearbyIdentity get peer => _pairing.peer;

  @override
  String get code => _pairing.code;

  @override
  bool get bothPopulated => _pairing.bothPopulated;

  @override
  Future<void> confirm() => _manager._confirm(this);

  @override
  Future<void> reject() => _manager._reject(this);
}

class _Live {
  _Live(this.channel, this.initiatorId);

  final NearbyChannel channel;
  final String initiatorId;
  bool superseded = false;
}

/// Runs the nearby link for this device: when to have the radio on, which
/// sightings to connect to, one session per peer, automatic re-syncs, and
/// what each session leaves on the paired-devices row.
///
/// The radio is on only while the app is in the foreground and either
/// pairing mode is on or automatic sync is on with at least one paired
/// device. Every device scans; every device that can also advertises.
class NearbyLinkManager {
  NearbyLinkManager({
    required NearbyCarrier carrier,
    required NearbySyncEngine engine,
    required NearbyPairSecrets secrets,
    required NearbyPeerStore peers,
    required PeerCursorStore cursors,
    required bool Function() autoSyncEnabled,
    required Future<Directory> Function() tempDir,
    Stream<void>? localChanges,
    DateTime Function() now = DateTime.now,
    this.changeDebounce = const Duration(seconds: 5),
    this.perPeerCooldown = const Duration(minutes: 10),
    this.retryAfter = const Duration(seconds: 30),
    this.partSize = 262144,
  }) : _carrier = carrier,
       _engine = engine,
       _secrets = secrets,
       _peers = peers,
       _cursors = cursors,
       _autoSyncEnabled = autoSyncEnabled,
       _tempDir = tempDir,
       _now = now {
    _subs.addAll([
      carrier.sightings.listen((s) => _onSighting(s.transportId)),
      carrier.incoming.listen((e) => unawaited(_onIncoming(e))),
      carrier.availability.listen((_) => unawaited(refresh())),
      if (localChanges != null) localChanges.listen((_) => _onLocalChange()),
    ]);
  }

  static final _log = LoggerService.forClass(NearbyLinkManager);

  final NearbyCarrier _carrier;
  final NearbySyncEngine _engine;
  final NearbyPairSecrets _secrets;
  final NearbyPeerStore _peers;
  final PeerCursorStore _cursors;
  final bool Function() _autoSyncEnabled;
  final Future<Directory> Function() _tempDir;
  final DateTime Function() _now;
  final Duration changeDebounce;
  final Duration perPeerCooldown;

  /// The least time between two connection attempts to one radio address.
  final Duration retryAfter;
  final int partSize;

  final _subs = <StreamSubscription<Object?>>[];
  final _stateController = StreamController<NearbyLinkState>.broadcast();
  final _progressController = StreamController<NearbySyncProgress>.broadcast();
  final _appliedController = StreamController<void>.broadcast();
  final _pendingController =
      StreamController<List<NearbyPairingHandle>>.broadcast();
  final _refusalController = StreamController<NearbyErrorCode>.broadcast();

  bool _foreground = false;
  bool _pairingMode = false;
  bool _running = false;
  bool _disposed = false;
  Future<void> _refreshTail = Future.value();
  Timer? _debounce;
  DateTime? _lastChangeAt;

  final _lastAttempt = <String, DateTime>{};
  final _connecting = <String>{};
  final _pairingTried = <String>{};
  final _deviceByTransport = <String, String>{};
  final _transportByDevice = <String, String>{};
  final _active = <String, _Live>{};
  final _lastSessionAt = <String, DateTime>{};
  final _pending = <NearbyPairingHandle>[];

  NearbyLinkState get state => !_running && _active.isEmpty
      ? NearbyLinkState.off
      : _active.isNotEmpty
      ? NearbyLinkState.syncing
      : NearbyLinkState.scanning;

  Stream<NearbyLinkState> get states => _stateController.stream;

  Stream<NearbySyncProgress> get progress => _progressController.stream;

  /// Fires after a session applied a peer's rows here.
  Stream<void> get applied => _appliedController.stream;

  /// Pairings waiting for the diver, in pairing mode.
  Stream<List<NearbyPairingHandle>> get pendingPairings =>
      _pendingController.stream;

  List<NearbyPairingHandle> get currentPairings => List.unmodifiable(_pending);

  /// Why a pairing in pairing mode could not open, for the pairing page:
  /// today only a device on another library is worth telling the diver.
  Stream<NearbyErrorCode> get pairingRefusals => _refusalController.stream;

  void _reportPairingRefusal(Object error) {
    if (error is NearbySessionRefused &&
        error.code == NearbyErrorCode.differentLibrary &&
        !_refusalController.isClosed) {
      _refusalController.add(error.code);
    }
  }

  Future<NearbyAvailability> checkAvailability() =>
      _carrier.checkAvailability();

  bool get canAdvertise => _carrier.canAdvertise;

  void _emitState() {
    if (!_stateController.isClosed) _stateController.add(state);
  }

  void _emitPending() {
    if (!_pendingController.isClosed) {
      _pendingController.add(List.unmodifiable(_pending));
    }
  }

  Future<void> setForeground(bool inForeground) {
    _foreground = inForeground;
    return refresh();
  }

  Future<void> enterPairingMode() {
    _pairingMode = true;
    _pairingTried.clear();
    return refresh();
  }

  Future<void> leavePairingMode() async {
    _pairingMode = false;
    for (final handle in List.of(_pending)) {
      await _reject(handle);
    }
    await refresh();
  }

  /// Re-decides whether the radio is on, and restarts the scan so nearby
  /// devices are sighted afresh.
  Future<void> refresh() {
    final next = _refreshTail.then((_) => _refresh());
    _refreshTail = next.catchError((Object e) {
      _log.warning('Nearby refresh failed: $e');
    });
    return _refreshTail;
  }

  Future<void> _refresh() async {
    if (_disposed) return;
    final wanted =
        _foreground &&
        (_pairingMode ||
            (_autoSyncEnabled() && (await _peers.all()).isNotEmpty));
    if (!wanted) {
      await _stopRadio();
      return;
    }
    final availability = await _carrier.checkAvailability();
    if (availability != NearbyAvailability.ready) {
      await _stopRadio();
      if (availability != NearbyAvailability.unsupported) {
        await _markRadioOff();
      }
      return;
    }
    await _clearRadioOff();
    if (_carrier.canAdvertise) {
      try {
        await _carrier.startAdvertising();
      } on Object catch (e) {
        _log.warning('Nearby advertising did not start: $e');
      }
    }
    // Running before the scan starts: a carrier may deliver its first
    // sightings while startScanning is still in flight.
    _running = true;
    await _carrier.stopScanning();
    await _carrier.startScanning();
    _emitState();
  }

  Future<void> _stopRadio() async {
    if (!_running) return;
    _running = false;
    await _carrier.stopScanning();
    await _carrier.stopAdvertising();
    _emitState();
  }

  /// While the radio is off, every row says so, unless it already carries
  /// an error the diver has to act on.
  Future<void> _markRadioOff() async {
    for (final peer in await _peers.all()) {
      final error = _peers.errorOf(peer);
      if (error == null || !error.isLasting) {
        await _peers.setError(peer.peerDeviceId, NearbyPeerError.bluetoothOff);
      }
    }
  }

  Future<void> _clearRadioOff() async {
    for (final peer in await _peers.all()) {
      if (_peers.errorOf(peer) == NearbyPeerError.bluetoothOff) {
        await _peers.setError(peer.peerDeviceId, null);
      }
    }
  }

  bool _due(String deviceId) {
    final last = _lastSessionAt[deviceId];
    if (last == null) return true;
    if (_now().difference(last) >= perPeerCooldown) return true;
    final change = _lastChangeAt;
    return change != null && change.isAfter(last);
  }

  void _onSighting(String transportId) {
    if (!_running || _disposed || _connecting.contains(transportId)) return;
    final last = _lastAttempt[transportId];
    if (last != null && _now().difference(last) < retryAfter) return;
    final device = _deviceByTransport[transportId];
    if (device != null && _active.containsKey(device)) return;
    if (_pairingMode) {
      if (!_pairingTried.add(transportId)) return;
      unawaited(_openPairing(transportId));
      return;
    }
    if (!_autoSyncEnabled()) return;
    if (device != null && !_due(device)) return;
    unawaited(_openSync(transportId));
  }

  void _onLocalChange() {
    _debounce?.cancel();
    _debounce = Timer(changeDebounce, () {
      _lastChangeAt = _now();
      if (!_running || !_autoSyncEnabled()) return;
      for (final entry in _transportByDevice.entries) {
        if (!_active.containsKey(entry.key) &&
            !_connecting.contains(entry.value)) {
          unawaited(_openSync(entry.value));
        }
      }
    });
  }

  /// One session with [peerDeviceId] now, whatever the cooldown. Null when
  /// this device has not seen that peer's radio in this run, or a session
  /// with it is already running.
  Future<NearbySyncOutcome?> syncNow(String peerDeviceId) async {
    final transport = _transportByDevice[peerDeviceId];
    if (transport == null || _active.containsKey(peerDeviceId)) return null;
    return _openSync(transport);
  }

  Future<NearbyEndpoint?> _connect(String transportId) async {
    _lastAttempt[transportId] = _now();
    try {
      return await _carrier.connect(transportId);
    } on NearbyConnectFailed catch (e) {
      _log.info('Nearby connect to $transportId failed: $e');
      return null;
    }
  }

  Future<NearbySyncOutcome?> _openSync(String transportId) async {
    _connecting.add(transportId);
    final NearbyChannel channel;
    try {
      final endpoint = await _connect(transportId);
      if (endpoint == null) return null;
      try {
        channel = await NearbySession(
          endpoint: endpoint,
          identity: await _engine.identity(),
          secrets: _secrets,
        ).openSync();
      } on NearbySessionRefused catch (e) {
        await _recordRefusal(transportId, e);
        return null;
      } on Object catch (e) {
        _log.info('Nearby session with $transportId did not open: $e');
        await endpoint.close();
        return null;
      }
    } finally {
      _connecting.remove(transportId);
    }
    _learn(transportId, channel.peer.deviceId);
    return _run(channel);
  }

  /// A refusal names nobody (the hello is anonymous), so it is recorded
  /// only on a peer this run already met at that radio address.
  Future<void> _recordRefusal(
    String transportId,
    NearbySessionRefused e,
  ) async {
    final device = _deviceByTransport[transportId];
    if (device == null || !e.fromPeer) return;
    final error = switch (e.code) {
      NearbyErrorCode.notPaired => NearbyPeerError.notPaired,
      NearbyErrorCode.differentLibrary => NearbyPeerError.differentLibrary,
      NearbyErrorCode.newerApp => NearbyPeerError.peerOlderApp,
      _ => null,
    };
    if (error != null) await _peers.setError(device, error);
  }

  void _learn(String transportId, String deviceId) {
    _deviceByTransport[transportId] = deviceId;
    _transportByDevice[deviceId] = transportId;
  }

  Future<void> _onIncoming(NearbyEndpoint endpoint) async {
    if (_disposed) {
      await endpoint.close();
      return;
    }
    final NearbyIncoming incoming;
    try {
      incoming = await NearbySession(
        endpoint: endpoint,
        identity: await _engine.identity(),
        secrets: _secrets,
      ).accept(allowPairing: _pairingMode);
    } on Object catch (e) {
      _log.info('Nearby incoming from ${endpoint.transportId} refused: $e');
      if (_pairingMode) _reportPairingRefusal(e);
      return;
    }
    switch (incoming) {
      case NearbyIncomingSync(:final channel):
        _learn(endpoint.transportId, channel.peer.deviceId);
        await _run(channel);
      case NearbyIncomingPairing(:final pairing):
        await _offer(
          NearbyPairingHandle._(
            this,
            pairing,
            initiatorId: pairing.peer.deviceId,
          ),
        );
    }
  }

  Future<String> _myId() async => (await _engine.identity()).deviceId;

  Future<NearbySyncOutcome?> _run(NearbyChannel channel) async {
    final peerId = channel.peer.deviceId;
    final myId = await _myId();
    final live = _Live(channel, channel.isInitiator ? myId : peerId);
    final existing = _active[peerId];
    if (existing != null) {
      // Both devices connected to each other at once. Each keeps the one
      // the lower device id started, so both keep the same one.
      final preferred = myId.compareTo(peerId) < 0 ? myId : peerId;
      if (live.initiatorId == preferred && existing.initiatorId != preferred) {
        existing.superseded = true;
        await existing.channel.close();
      } else {
        await channel.close();
        return null;
      }
    }
    _active[peerId] = live;
    _emitState();
    NearbySyncOutcome outcome;
    try {
      outcome = await NearbySyncProtocol(
        channel: channel,
        engine: _engine,
        peers: _peers,
        tempDir: _tempDir,
        now: _now,
        partSize: partSize,
        onProgress: (done, total) => _progressController.add(
          NearbySyncProgress(peerDeviceId: peerId, done: done, total: total),
        ),
      ).run();
    } on Object catch (e) {
      _log.warning('Nearby sync with $peerId failed: $e');
      outcome = const NearbySyncOutcome(error: NearbyPeerError.unreachable);
    }
    if (_active[peerId] == live) _active.remove(peerId);
    try {
      await channel.close();
    } on Object {
      // Already closed.
    }
    if (!_progressController.isClosed) {
      _progressController.add(
        NearbySyncProgress(
          peerDeviceId: peerId,
          done: 0,
          total: 0,
          finished: true,
        ),
      );
    }
    _emitState();
    if (live.superseded || _disposed) return null;
    final at = _now();
    _lastSessionAt[peerId] = at;
    if (await _peers.get(peerId) != null) {
      await _peers.markSeen(peerId, at.millisecondsSinceEpoch);
      await _peers.setError(peerId, outcome.error);
    }
    if (outcome.applied > 0 && !_appliedController.isClosed) {
      _appliedController.add(null);
    }
    return outcome;
  }

  // -------------------------------------------------------------------
  // Pairing

  Future<void> _openPairing(String transportId) async {
    _connecting.add(transportId);
    try {
      final endpoint = await _connect(transportId);
      if (endpoint == null) return;
      try {
        final pairing = await NearbySession(
          endpoint: endpoint,
          identity: await _engine.identity(),
          secrets: _secrets,
        ).openPairing();
        _learn(transportId, pairing.peer.deviceId);
        await _offer(
          NearbyPairingHandle._(this, pairing, initiatorId: await _myId()),
        );
      } on Object catch (e) {
        _log.info('Nearby pairing with $transportId did not open: $e');
        _reportPairingRefusal(e);
        await endpoint.close();
      }
    } finally {
      _connecting.remove(transportId);
    }
  }

  /// Shows [handle], unless a pairing with the same device is already
  /// shown: then the one the lower device id started stays.
  Future<void> _offer(NearbyPairingHandle handle) async {
    if (!_pairingMode || _disposed) {
      await handle._pairing.reject();
      return;
    }
    final peerId = handle.peer.deviceId;
    final existing = _pending.where((h) => h.peer.deviceId == peerId);
    if (existing.isNotEmpty) {
      final other = existing.first;
      final myId = await _myId();
      final preferred = myId.compareTo(peerId) < 0 ? myId : peerId;
      if (handle.initiatorId == preferred && other.initiatorId != preferred) {
        _pending.remove(other);
        await other._pairing.reject();
      } else {
        await handle._pairing.reject();
        return;
      }
    }
    _pending.add(handle);
    _emitPending();
  }

  Future<void> _confirm(NearbyPairingHandle handle) async {
    final NearbyChannel channel;
    try {
      channel = await handle._pairing.confirm();
    } finally {
      _pending.remove(handle);
      _emitPending();
    }
    final peer = channel.peer;
    await _peers.upsertPaired(
      peerDeviceId: peer.deviceId,
      displayName: peer.deviceName,
      pairedAt: _now().millisecondsSinceEpoch,
    );
    unawaited(_run(channel));
    unawaited(refresh());
  }

  Future<void> _reject(NearbyPairingHandle handle) async {
    _pending.remove(handle);
    _emitPending();
    await handle._pairing.reject();
  }

  /// Forgets [peerDeviceId]: its pair secret, its row and its progress.
  Future<void> unpair(String peerDeviceId) async {
    await _secrets.remove(peerDeviceId);
    await _peers.remove(peerDeviceId);
    await _cursors.remove(peerDeviceId, nearbyCursorProvider);
    _lastSessionAt.remove(peerDeviceId);
    await _active[peerDeviceId]?.channel.close();
    await refresh();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _debounce?.cancel();
    for (final sub in _subs) {
      await sub.cancel();
    }
    for (final live in _active.values.toList()) {
      await live.channel.close();
    }
    for (final handle in List.of(_pending)) {
      await handle._pairing.reject();
    }
    _pending.clear();
    if (_running) {
      _running = false;
      await _carrier.stopScanning();
      await _carrier.stopAdvertising();
    }
    await _stateController.close();
    await _progressController.close();
    await _appliedController.close();
    await _pendingController.close();
    await _refusalController.close();
  }
}
