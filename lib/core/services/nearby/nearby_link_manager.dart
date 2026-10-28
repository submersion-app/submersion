import 'dart:async';
import 'dart:io';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_hello.dart';
import 'package:submersion/core/services/nearby/nearby_peer_store.dart';
import 'package:submersion/core/services/nearby/nearby_session.dart';
import 'package:submersion/core/services/nearby/nearby_sync_engine.dart';
import 'package:submersion/core/services/nearby/nearby_sync_protocol.dart';
import 'package:submersion/core/services/nearby/nearby_transfer.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';

part 'nearby_link_pairing.dart';
part 'nearby_link_radio.dart';

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

class _Live {
  _Live(this.channel, this.initiatorId, this.startedAt);

  final NearbyChannel channel;
  final String initiatorId;

  /// When the session began: a local change after this may have missed it.
  final DateTime startedAt;
  bool superseded = false;

  /// The session that replaced this one when both devices connected at
  /// once; null when this one was ended for good (unpair, dispose).
  _Live? successor;

  /// Completes with the session's outcome, or null when it was superseded.
  final done = Completer<NearbySyncOutcome?>();
}

/// Runs the nearby link for this device: when to have the radio on, which
/// sightings to connect to, one session per peer, automatic re-syncs, and
/// what each session leaves on the paired-devices row.
///
/// The radio is on only while the app is in the foreground and either
/// pairing mode is on, a one-off "Sync now" is looking for its device, or
/// automatic sync is on with at least one paired device. Every device
/// scans; every device that can also advertises.
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
    this.strangerBackoff = const Duration(minutes: 1),
    this.maxStrangerBackoff = const Duration(minutes: 30),
    this.syncNowTimeout = const Duration(seconds: 20),
    this.recentSighting = const Duration(minutes: 2),
    this.scanRestartAfter = const Duration(seconds: 10),
    this.partSize = 262144,
    String Function() pairingNonce = NearbySession.newPairingNonce,
  }) : _carrier = carrier,
       _engine = engine,
       _secrets = secrets,
       _peers = peers,
       _cursors = cursors,
       _autoSyncEnabled = autoSyncEnabled,
       _tempDir = tempDir,
       _now = now,
       _newPairingNonce = pairingNonce {
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
  final String Function() _newPairingNonce;
  final Duration changeDebounce;
  final Duration perPeerCooldown;

  /// The least time between two connection attempts to one radio address.
  final Duration retryAfter;

  /// How long an address that turned out to be a stranger is left alone,
  /// doubling with every refusal up to [maxStrangerBackoff].
  final Duration strangerBackoff;
  final Duration maxStrangerBackoff;

  /// How long "Sync now" looks for its device.
  final Duration syncNowTimeout;

  /// A local change dials only peers sighted this recently.
  final Duration recentSighting;

  /// The least time between two starts of a running scan. Real radios
  /// report every advertisement, so a restart only freshens the sightings,
  /// and Android stops delivering results to an app that starts five scans
  /// in 30 seconds.
  final Duration scanRestartAfter;
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
  bool _prunedSecrets = false;
  Future<void> _refreshTail = Future.value();
  Timer? _debounce;
  DateTime? _scanStartedAt;

  /// The last availability check found Bluetooth off or not allowed.
  bool _radioOff = false;
  DateTime? _lastChangeAt;

  /// This device's id, cached by every session as it opens so the
  /// duplicate check in [_run] needs no await.
  String? _me;
  String _pairingNonce = '';

  final _lastAttempt = <String, DateTime>{};
  final _lastSighted = <String, DateTime>{};

  /// When each stranger last refused, and how long it is left alone.
  final _strangerSince = <String, DateTime>{};
  final _strangerWait = <String, Duration>{};
  final _connecting = <String>{};
  final _pairingTried = <String>{};
  final _deviceByTransport = <String, String>{};
  final _transportByDevice = <String, String>{};
  final _active = <String, _Live>{};
  final _lastSessionAt = <String, DateTime>{};

  /// Transient failures in a row per peer, for [_holdAfter].
  final _transientRuns = <String, int>{};
  final _pending = <NearbyPairingHandle>[];
  final _syncNowWaiters = <String, Completer<NearbySyncOutcome?>>{};

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

  Future<NearbyIdentity> _identity() async {
    final identity = await _engine.identity();
    _me = identity.deviceId;
    return identity;
  }

  Future<void> setForeground(bool inForeground) async {
    _foreground = inForeground;
    if (!inForeground) await _endSessions();
    return refresh();
  }

  /// Ends every running session without recording an outcome. Stopping
  /// the radio leaves an open link connected, and nearby sync is
  /// foreground-only. The peer is due again on return, and a full copy
  /// resumes from its last part. With [untilEnded], returns only once each
  /// session's run has finished, so none still reads or writes the
  /// database it started on.
  Future<void> _endSessions({bool untilEnded = false}) async {
    final ended = <_Live>[];
    for (final entry in _active.entries.toList()) {
      _active.remove(entry.key);
      entry.value.superseded = true;
      ended.add(entry.value);
      try {
        await entry.value.channel.close();
      } on Object {
        // Already closed.
      }
    }
    _emitState();
    if (untilEnded) await Future.wait([for (final l in ended) l.done.future]);
  }

  Future<void> enterPairingMode() {
    _pairingMode = true;
    _pairingTried.clear();
    _forgetStrangers();
    // A pairing confirmed before the diver left keeps its nonce, so the
    // other device sees a redial as the same attempt, not a second one.
    if (!_pending.any((h) => h._confirming)) {
      _pairingNonce = _newPairingNonce();
    }
    return refresh();
  }

  /// Rejects the pairings still waiting for this diver. One they already
  /// confirmed is left to finish: it ends when the other diver answers.
  Future<void> leavePairingMode() async {
    _pairingMode = false;
    for (final handle in List.of(_pending)) {
      if (!handle._confirming) await _reject(handle);
    }
    await refresh();
  }

  void _forgetStrangers() {
    _strangerSince.clear();
    _strangerWait.clear();
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
    // The sample logbook (demo mode) has a database of its own but shares
    // secure storage with the real library: its empty paired-devices table
    // must never be read as "every secret is an orphan", and nothing nearby
    // may reach it. A session already running ends before the sample
    // logbook opens (entering demo mode refreshes here first).
    if (DemoModeGate.instance.isActive) {
      await _stopRadio();
      await _endSessions(untilEnded: true);
      return;
    }
    if (!_prunedSecrets) {
      _prunedSecrets = true;
      await _pruneOrphans();
    }
    final wanted =
        _foreground &&
        (_pairingMode ||
            _syncNowWaiters.isNotEmpty ||
            (_autoSyncEnabled() && (await _peers.all()).isNotEmpty));
    if (!wanted) {
      await _stopRadio();
      // The radio is not in use, so whether Bluetooth is on says nothing
      // about why a device is not syncing.
      await _clearRadioOff();
      return;
    }
    final availability = await _carrier.checkAvailability();
    _radioOff =
        availability == NearbyAvailability.bluetoothOff ||
        availability == NearbyAvailability.unauthorized;
    if (availability != NearbyAvailability.ready) {
      await _stopRadio();
      if (_radioOff) await _markRadioOff();
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
    final startedAt = _scanStartedAt;
    final restart =
        !_running || startedAt == null || _waited(startedAt, scanRestartAfter);
    // Running before the scan starts: a carrier may deliver its first
    // sightings while startScanning is still in flight.
    _running = true;
    if (restart) {
      _scanStartedAt = _now();
      await _carrier.stopScanning();
      await _carrier.startScanning();
    }
    _emitState();
  }

  /// Whether [wait] has passed since [since]. A clock set back since then
  /// counts as passed, so no wait outlasts the change.
  bool _waited(DateTime since, Duration wait) {
    final elapsed = _now().difference(since);
    return elapsed.isNegative || elapsed >= wait;
  }

  bool _due(String deviceId) {
    final last = _lastSessionAt[deviceId];
    if (last == null || _waited(last, perPeerCooldown)) return true;
    final change = _lastChangeAt;
    return change != null && change.isAfter(last);
  }

  bool _mayDial(String transportId) {
    if (_connecting.contains(transportId)) return false;
    final last = _lastAttempt[transportId];
    if (last != null && !_waited(last, retryAfter)) return false;
    final since = _strangerSince[transportId];
    return since == null ||
        _waited(since, _strangerWait[transportId] ?? strangerBackoff);
  }

  void _onSighting(String transportId) {
    if (!_running || _disposed) return;
    _lastSighted[transportId] = _now();
    if (!_mayDial(transportId)) return;
    final device = _deviceByTransport[transportId];
    if (device != null && _active.containsKey(device)) return;
    if (_pairingMode) {
      if (!_pairingTried.add(transportId)) return;
      unawaited(_openPairing(transportId));
      return;
    }
    if (_syncNowWaiters.isNotEmpty &&
        (device == null || _syncNowWaiters.containsKey(device))) {
      // A one-off Sync now dials whatever might be its device until it
      // finds it. Another known device keeps to its own rules below.
      unawaited(_openSync(transportId));
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
      final now = _now();
      for (final entry in _transportByDevice.entries) {
        final seen = _lastSighted[entry.value];
        if (seen == null || now.difference(seen) > recentSighting) continue;
        if (_active.containsKey(entry.key) || !_mayDial(entry.value)) {
          continue;
        }
        unawaited(_openSync(entry.value));
      }
    });
  }

  /// One session with [peerDeviceId] now, whatever the cooldown and the
  /// automatic switch: the radio comes on until the peer is found or
  /// [syncNowTimeout] passes. Null when it was not found, or a session
  /// with it is already running; [NearbyPeerError.notPaired] when it was
  /// unpaired meanwhile.
  Future<NearbySyncOutcome?> syncNow(String peerDeviceId) async {
    if (_disposed) return null;
    // Already syncing with it: that session is the answer.
    final running = _active[peerDeviceId];
    if (running != null) return running.done.future;
    final existing = _syncNowWaiters[peerDeviceId];
    if (existing != null) return existing.future;
    final waiter = Completer<NearbySyncOutcome?>();
    _syncNowWaiters[peerDeviceId] = waiter;
    _lastSessionAt.remove(peerDeviceId);
    await refresh();
    if (!_running) {
      // The radio could not come on, so no sighting will answer: say why
      // now rather than after the timeout.
      final outcome = _radioOff
          ? const NearbySyncOutcome(error: NearbyPeerError.bluetoothOff)
          : null;
      _completeSyncNow(peerDeviceId, outcome);
      _syncNowWaiters.remove(peerDeviceId);
      return outcome;
    }
    final known = _transportByDevice[peerDeviceId];
    if (known != null) {
      // The diver asked: the spacing that keeps sightings from redialling
      // does not hold back a tap made just after the last session.
      _lastAttempt.remove(known);
      if (_mayDial(known)) unawaited(_openSync(known));
    }
    final outcome = await waiter.future.timeout(
      syncNowTimeout,
      onTimeout: () => null,
    );
    _syncNowWaiters.remove(peerDeviceId);
    await refresh();
    return outcome;
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
    // Who the caller dialled, as far as it knew: the rules for that device
    // were applied before dialling.
    final expected = _deviceByTransport[transportId];
    _connecting.add(transportId);
    final NearbyChannel channel;
    try {
      final endpoint = await _connect(transportId);
      if (endpoint == null) return null;
      try {
        channel = await NearbySession(
          endpoint: endpoint,
          identity: await _identity(),
          secrets: _secrets,
        ).openSync();
      } on NearbySessionRefused catch (e) {
        await _recordRefusal(transportId, e, dialled: true);
        return null;
      } on Object catch (e) {
        _log.info('Nearby session with $transportId did not open: $e');
        await endpoint.close();
        return null;
      }
    } finally {
      _connecting.remove(transportId);
    }
    final peer = channel.peer.deviceId;
    _learn(transportId, peer);
    if (peer != expected &&
        !_syncNowWaiters.containsKey(peer) &&
        !(_autoSyncEnabled() && _due(peer))) {
      // Dialled before its address was known (by a Sync now looking for
      // another device, or at a first sighting): now that it is, it keeps
      // to the cooldown and the automatic switch.
      await channel.close();
      return null;
    }
    return _run(channel);
  }

  /// A refusal is recorded on the peer it authenticated as, or on the peer
  /// already met at that radio address in this run. A refusal from nobody
  /// known is a stranger: its address is left alone for a while, longer
  /// each time.
  Future<void> _recordRefusal(
    String transportId,
    NearbySessionRefused e, {
    required bool dialled,
  }) async {
    final device = e.peerDeviceId ?? _deviceByTransport[transportId];
    if (device == null || await _peers.get(device) == null) {
      final wait = _strangerWait[transportId];
      final next = wait == null
          ? strangerBackoff
          : (wait * 2 > maxStrangerBackoff ? maxStrangerBackoff : wait * 2);
      _strangerWait[transportId] = next;
      _strangerSince[transportId] = _now();
      return;
    }
    // A refused session still opened: the peer is around, and its row
    // keeps holding tombstones back until it can sync again.
    await _peers.markSeen(device, _now().millisecondsSinceEpoch);
    final error = e.fromPeer
        ? nearbyPeerRefusalError(e.code)
        : nearbyOwnRefusalError(e.code);
    if (error == null) return;
    if (dialled) _learn(transportId, device);
    await _peers.setError(device, error);
    // A refusal the diver has to fix waits out the cooldown like a synced
    // session, instead of a redial on every sighting.
    _holdAfter(device, error, _now());
    _completeSyncNow(device, NearbySyncOutcome(error: error));
  }

  /// Starts [deviceId]'s cooldown from [at] after a session or refusal that
  /// ended with [error]. A transient one (a lost link) is due again at the
  /// next sighting instead, so a full copy resumes soon, but only
  /// [_quickRetries] times in a row: a peer that fails the same way every
  /// time (a full disk on either side, a refusal it always gives) then
  /// waits like any other.
  void _holdAfter(String deviceId, NearbyPeerError? error, DateTime at) {
    if (error != null && !error.isLasting) {
      final runs = (_transientRuns[deviceId] ?? 0) + 1;
      _transientRuns[deviceId] = runs;
      if (runs <= _quickRetries) return;
    } else {
      _transientRuns.remove(deviceId);
    }
    _lastSessionAt[deviceId] = at;
  }

  static const _quickRetries = 3;

  void _completeSyncNow(String deviceId, NearbySyncOutcome? outcome) {
    final waiter = _syncNowWaiters[deviceId];
    if (waiter != null && !waiter.isCompleted) waiter.complete(outcome);
  }

  /// [transportId] is where [deviceId] can be dialled: called only for
  /// links this device opened. A link the peer opened arrives under its
  /// central's id, which on Bluetooth is not the address it advertises.
  void _learn(String transportId, String deviceId) {
    _deviceByTransport[transportId] = deviceId;
    _transportByDevice[deviceId] = transportId;
    _strangerSince.remove(transportId);
    _strangerWait.remove(transportId);
  }

  Future<void> _onIncoming(NearbyEndpoint endpoint) async {
    // Entering demo mode closes the gate before the app restarts, with the
    // radio still on: no session may run in between.
    if (_disposed || !_foreground || DemoModeGate.instance.isActive) {
      await endpoint.close();
      return;
    }
    final NearbyIncoming incoming;
    try {
      incoming = await NearbySession(
        endpoint: endpoint,
        identity: await _identity(),
        secrets: _secrets,
        pairingNonce: _pairingNonce.isEmpty ? null : _pairingNonce,
      ).accept(allowPairing: _pairingMode);
    } on Object catch (e) {
      _log.info('Nearby incoming from ${endpoint.transportId} refused: $e');
      if (_pairingMode) _reportPairingRefusal(e);
      // A refusal naming a paired peer goes on its row, as one met by
      // dialling does: often both sides refuse at once (another library),
      // and this side may be the one that never dials (a Linux peer).
      final peer = e is NearbySessionRefused ? e.peerDeviceId : null;
      if (peer != null && await _peers.get(peer) != null) {
        await _recordRefusal(
          endpoint.transportId,
          e as NearbySessionRefused,
          dialled: false,
        );
      }
      return;
    }
    switch (incoming) {
      case NearbyIncomingSync(:final channel):
        // With the automatic switch off the radio is on only for pairing
        // or a Sync now: any other paired device that dials in is turned
        // away, as one this device dialled is.
        if (!_autoSyncEnabled() &&
            !_syncNowWaiters.containsKey(channel.peer.deviceId)) {
          await channel.close();
          return;
        }
        await _run(channel);
      case NearbyIncomingPairing(:final pairing):
        await _offer(
          NearbyPairingHandle._(
            this,
            pairing,
            transportId: endpoint.transportId,
            dialled: false,
            initiatorKey: pairing.preview.nonce,
          ),
        );
    }
  }

  Future<NearbySyncOutcome?> _run(NearbyChannel channel) async {
    // A handshake that finished after the app left the foreground, after
    // demo mode closed the gate, or after this manager was disposed.
    if (_disposed || !_foreground || DemoModeGate.instance.isActive) {
      await channel.close();
      return null;
    }
    final peerId = channel.peer.deviceId;
    final myId = _me!;
    final live = _Live(channel, channel.isInitiator ? myId : peerId, _now());
    // Checked and registered with no await in between: two sessions with
    // the same peer finishing their handshakes together must not both run.
    final existing = _active[peerId];
    if (existing != null) {
      // Both devices connected to each other at once. Each keeps the one
      // the lower device id started, so both keep the same one.
      final preferred = myId.compareTo(peerId) < 0 ? myId : peerId;
      if (live.initiatorId == preferred && existing.initiatorId != preferred) {
        existing
          ..superseded = true
          ..successor = live;
        _active[peerId] = live;
        unawaited(existing.channel.close());
      } else {
        await channel.close();
        return null;
      }
    } else {
      _active[peerId] = live;
    }
    _emitState();
    // Seen from the start too: a full copy can run long, and tombstone
    // cleanup elsewhere must not take a peer mid-session for a silent one.
    if (await _peers.get(peerId) != null) {
      await _peers.markSeen(peerId, live.startedAt.millisecondsSinceEpoch);
    }
    NearbySyncOutcome outcome;
    try {
      outcome = await NearbySyncProtocol(
        channel: channel,
        engine: _engine,
        peers: _peers,
        tempDir: _tempDir,
        now: _now,
        partSize: partSize,
        onProgress: (done, total) {
          if (_progressController.isClosed) return;
          _progressController.add(
            NearbySyncProgress(peerDeviceId: peerId, done: done, total: total),
          );
        },
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
    // A twin that replaced this session reports its own progress, and its
    // own end.
    final replaced = live.superseded && live.successor != null;
    if (!replaced && !_progressController.isClosed) {
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
    if (live.superseded || _disposed) {
      final next = _disposed ? null : live.successor;
      if (!live.done.isCompleted) {
        live.done.complete(next?.done.future);
      }
      return null;
    }
    final at = _now();
    // From the start: a change made while it ran may not be in it.
    final error = outcome.error;
    _holdAfter(peerId, error, live.startedAt);
    if (await _peers.get(peerId) != null) {
      await _peers.markSeen(peerId, at.millisecondsSinceEpoch);
      await _peers.setError(peerId, error);
      if (error == null) {
        await _peers.markSynced(peerId, at: at.millisecondsSinceEpoch);
      }
    }
    if (outcome.applied > 0 && !_appliedController.isClosed) {
      _appliedController.add(null);
    }
    _completeSyncNow(peerId, outcome);
    if (!live.done.isCompleted) live.done.complete(outcome);
    return outcome;
  }

  /// Forgets [peerDeviceId]: its row and its progress. The secret is kept
  /// aside so the peer can be told, authenticated, that it is unpaired.
  Future<void> unpair(String peerDeviceId) async {
    // A Sync now waiting on it, or on its running session, ends here: it
    // hears why, rather than calling the device not in range.
    const unpaired = NearbySyncOutcome(error: NearbyPeerError.notPaired);
    final live = _active.remove(peerDeviceId);
    if (live != null) {
      live.superseded = true;
      if (!live.done.isCompleted) live.done.complete(unpaired);
      await live.channel.close();
    }
    _completeSyncNow(peerDeviceId, unpaired);
    _syncNowWaiters.remove(peerDeviceId);
    await _secrets.revoke(peerDeviceId);
    await _peers.remove(peerDeviceId);
    await _cursors.remove(peerDeviceId, nearbyCursorProvider);
    _lastSessionAt.remove(peerDeviceId);
    _transientRuns.remove(peerDeviceId);
    _forgetStrangers();
    try {
      // The copies kept for a resume with it can never be resumed now.
      await NearbyTransferFiles(
        await _tempDir(),
        now: _now,
      ).discardPeer(peerDeviceId);
    } on Object catch (e) {
      _log.info('Nearby transfer files for $peerDeviceId stayed: $e');
    }
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
    for (final waiter in _syncNowWaiters.values) {
      if (!waiter.isCompleted) waiter.complete(null);
    }
    // A refresh already past its disposed check may still turn the radio
    // on; any refresh queued after it returns at once.
    await _refreshTail;
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
