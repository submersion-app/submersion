import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_crypto.dart';
import 'package:submersion/core/services/nearby/nearby_export_planner.dart';
import 'package:submersion/core/services/nearby/nearby_frame.dart';
import 'package:submersion/core/services/nearby/nearby_hello.dart';
import 'package:submersion/core/services/nearby/nearby_inbox.dart';
import 'package:submersion/core/services/nearby/nearby_peer_store.dart';
import 'package:submersion/core/services/nearby/nearby_session.dart';
import 'package:submersion/core/services/nearby/nearby_sync_engine.dart';
import 'package:submersion/core/services/nearby/nearby_transfer.dart';
import 'package:submersion/core/services/nearby/nearby_watermarks.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart'
    show NearbyApplyResult;

export 'package:submersion/core/services/nearby/nearby_peer_store.dart'
    show NearbyPeerError;

/// How one nearby sync session went, from this device's side.
class NearbySyncOutcome {
  const NearbySyncOutcome({this.error, this.applied = 0, this.sent = 0});

  /// The first lasting error, else the first transient one, else null.
  final NearbyPeerError? error;

  /// Records this device applied.
  final int applied;

  /// Payload bytes this device sent.
  final int sent;
}

/// The row error for a refusal the peer sent: what the peer found. Every
/// one is worth a row, so a refused Sync now never reads as a clean one.
NearbyPeerError nearbyPeerRefusalError(NearbyErrorCode code) => switch (code) {
  // The peer cannot read this device's rows: it needs the update.
  NearbyErrorCode.newerApp => NearbyPeerError.peerOlderApp,
  NearbyErrorCode.olderApp => NearbyPeerError.newerApp,
  NearbyErrorCode.differentLibrary => NearbyPeerError.differentLibrary,
  NearbyErrorCode.notPaired => NearbyPeerError.notPaired,
  // notSwapping answers only a card hello, never a sync.
  NearbyErrorCode.protocol ||
  NearbyErrorCode.busy ||
  NearbyErrorCode.notSwapping => NearbyPeerError.unreachable,
};

/// The row error for a refusal this device made, or null when it is not
/// the diver's to act on (a malformed or forged handshake).
NearbyPeerError? nearbyOwnRefusalError(NearbyErrorCode code) => switch (code) {
  // A peer on a newer protocol: this device needs the update.
  NearbyErrorCode.newerApp => NearbyPeerError.newerApp,
  NearbyErrorCode.differentLibrary => NearbyPeerError.differentLibrary,
  _ => null,
};

/// A refusal or failure inside one direction.
class _DirectionFailed implements Exception {
  const _DirectionFailed(this.error, {this.tellPeer});

  final NearbyPeerError error;

  /// Sent to the peer before giving up the direction, when it is still
  /// waiting on this device.
  final NearbyErrorCode? tellPeer;
}

/// Sort-first clock: a writer the receiver had never heard of is relayed
/// from the start.
const _zeroFloor = '000000000000000:000000:';

/// One sync session over an open [NearbyChannel]: each side, in turn, says
/// what it already holds per writer and receives what it lacks.
///
/// The initiator sends first. Every payload, delta or full copy, travels
/// gzipped as one offer, a request for the parts from some index (0, or
/// where a dropped transfer stopped), the parts, and an `applied` reply.
class NearbySyncProtocol {
  static final _log = LoggerService.forClass(NearbySyncProtocol);

  NearbySyncProtocol({
    required NearbyChannel channel,
    required NearbySyncEngine engine,
    required NearbyPeerStore peers,
    required Future<Directory> Function() tempDir,
    DateTime Function() now = DateTime.now,
    this.partSize = 262144,
    this.messageTimeout = const Duration(seconds: 60),
    this.partTimeout = const Duration(minutes: 5),
    this.offerTimeout = const Duration(minutes: 15),
    this.applyTimeout = const Duration(minutes: 30),
    this.onProgress,
  }) : _channel = channel,
       _engine = engine,
       _peers = peers,
       _tempDir = tempDir,
       _now = now,
       _messages = StreamIterator(channel.messages);

  final NearbyChannel _channel;
  final NearbySyncEngine _engine;
  final NearbyPeerStore _peers;
  final Future<Directory> Function() _tempDir;
  final DateTime Function() _now;
  final StreamIterator<NearbyMessage> _messages;
  final int partSize;
  final Duration messageTimeout;

  /// The wait for one base part: [partSize] bytes take minutes on a slow
  /// link (an iPhone serving reads of under 200 bytes, about one per two
  /// connection events, is near 3 KB/s), far past [messageTimeout].
  final Duration partTimeout;

  /// The wait for the offer while the peer exports and compresses what it
  /// sends: minutes for a large first copy.
  final Duration offerTimeout;

  /// The wait for `applied` after the last part, while the peer merges.
  final Duration applyTimeout;

  /// (bytes done, bytes total) of the transfer in either direction.
  final void Function(int done, int total)? onProgress;

  late NearbyIdentity _self;
  late NearbyTransferFiles _files;
  int _applied = 0;
  int _sent = 0;
  final _errors = <NearbyPeerError>[];

  String get _peerId => _channel.peer.deviceId;

  Future<NearbySyncOutcome> run() async {
    // The peer's id names this session's temp files.
    if (!NearbyTransferFiles.isSafeName(_peerId)) {
      return const NearbySyncOutcome(error: NearbyPeerError.unreachable);
    }
    try {
      _self = await _engine.identity();
      _files = NearbyTransferFiles(await _tempDir(), now: _now);
      await _files.sweepStale();
      await _settleEpoch();
      if (_channel.isInitiator) {
        await _direction(_send);
        await _direction(_receive);
      } else {
        await _direction(_receive);
        await _direction(_send);
      }
    } on _LinkLost {
      _errors.add(NearbyPeerError.unreachable);
    }
    final lasting = _errors.where((e) => e.isLasting);
    return NearbySyncOutcome(
      error: lasting.isNotEmpty ? lasting.first : _errors.firstOrNull,
      applied: _applied,
      sent: _sent,
    );
  }

  /// Runs one direction; a refusal ends that direction only, a lost link
  /// ends the session.
  Future<void> _direction(Future<void> Function() body) async {
    try {
      await body();
    } on _DirectionFailed catch (f) {
      _errors.add(f.error);
      final code = f.tellPeer;
      if (code != null) await _sendError(code);
    } on NearbyLinkClosed {
      throw const _LinkLost();
    } on NearbyTimeout {
      throw const _LinkLost();
    } on NearbyAuthFailure {
      throw const _LinkLost();
    } on FrameError {
      throw const _LinkLost();
    }
  }

  // ---------------------------------------------------------------------
  // Library epoch

  Future<void> _settleEpoch() async {
    final theirs = _channel.peer.epochId;
    if (_self.epochId == null && theirs != null) {
      await _adopt(theirs);
    } else if (_self.epochId == null &&
        theirs == null &&
        _channel.isInitiator) {
      // Neither device has joined a library: they start one together. The
      // responder learns it from this side's first offer or watermarks.
      await _adopt(const Uuid().v4());
    }
  }

  Future<void> _adopt(String epochId) async {
    await _engine.adoptEpoch(epochId);
    _self = _self.copyWith(epochId: epochId);
  }

  Future<void> _adoptFrom(Map<String, Object?> body) async {
    final epoch = body['epoch'];
    if (_self.epochId == null && epoch is String) await _adopt(epoch);
  }

  // ---------------------------------------------------------------------
  // Receiving

  Future<void> _receive() async {
    if (_self.schemaVersion < _channel.peer.schemaFloor) {
      throw const _DirectionFailed(
        NearbyPeerError.newerApp,
        tellPeer: NearbyErrorCode.newerApp,
      );
    }
    final before = await _engine.watermarks();
    await _sendJson(NearbyMessageType.watermarks, {
      ...before.toJson(),
      'epoch': _self.epochId,
    });
    final offer = await _expectJson(
      NearbyMessageType.baseOffer,
      timeout: offerTimeout,
    );
    await _adoptFrom(offer);
    final kind = offer['kind'];
    if (kind == 'none') {
      await _finishReceive(before, before, lowest: null);
      return;
    }
    // A kind this build does not know is never applied as a full copy.
    if (kind != 'delta' && kind != 'full') {
      throw const _DirectionFailed(
        NearbyPeerError.unreachable,
        tellPeer: NearbyErrorCode.protocol,
      );
    }
    final gz = await _receiveParts(offer);
    final File json;
    try {
      json = await _files.gunzip(gz);
    } on Object catch (e) {
      _log.warning('Nearby copy from $_peerId did not unpack: $e');
      await _dropIncoming(gz);
      throw const _DirectionFailed(
        NearbyPeerError.applyFailed,
        tellPeer: NearbyErrorCode.protocol,
      );
    }
    try {
      final NearbyApplyResult result;
      if (kind == 'delta') {
        final payload = SyncPayload.fromJson(
          jsonDecode(await json.readAsString()) as Map<String, dynamic>,
        );
        if (!SyncDataSerializer.checksumIsValid(payload)) {
          throw const FormatException('nearby delta checksum');
        }
        result = await _engine.applyPayload(payload, peerDeviceId: _peerId);
      } else {
        result = await _engine.applyBaseFile(json.path, peerDeviceId: _peerId);
      }
      _applied += result.recordsApplied;
      // Rows the merge could not take: not a clean session, as on the cloud
      // path, though what did apply is still acknowledged below.
      if (result.recordsFailed > 0) _errors.add(NearbyPeerError.applyFailed);
    } on Object catch (e, stack) {
      _log.warning(
        'Nearby apply from $_peerId failed: $e',
        error: e,
        stackTrace: stack,
      );
      await _dropIncoming(gz);
      throw const _DirectionFailed(
        NearbyPeerError.applyFailed,
        tellPeer: NearbyErrorCode.protocol,
      );
    } finally {
      if (await json.exists()) await json.delete();
    }
    await _dropIncoming(gz);
    final after = await _engine.watermarks();
    await _finishReceive(
      before,
      after,
      lowest: await _lowestMoved(before, after),
    );
  }

  /// [gz] is done with, applied or refused: neither it nor its resume
  /// record is kept. A refused one could never be resumed anyway, since
  /// the sender makes a fresh copy after a refusal.
  Future<void> _dropIncoming(File gz) async {
    if (await gz.exists()) await gz.delete();
    await _peers.setResume(_peerId);
  }

  Future<void> _finishReceive(
    NearbyWatermarks before,
    NearbyWatermarks after, {
    required String? lowest,
  }) async {
    final ack = after.highByWriter[_peerId];
    await _engine.recordApplied(
      peerDeviceId: _peerId,
      appliedHlcHigh: ack,
      lowestAppliedHlc: lowest,
    );
    await _sendJson(NearbyMessageType.applied, {'ack': ack});
  }

  /// The clock to relay from: for each writer whose mark moved, its old
  /// mark (every row now held above it is new here); for a writer this
  /// device had never heard of, its oldest clock now held here.
  Future<String?> _lowestMoved(
    NearbyWatermarks before,
    NearbyWatermarks after,
  ) async {
    String? low;
    for (final entry in after.highByWriter.entries) {
      final old = before.highByWriter[entry.key];
      if (old == entry.value) continue;
      final floor = old ?? await _engine.lowestClockOf(entry.key) ?? _zeroFloor;
      if (low == null || floor.compareTo(low) < 0) low = floor;
    }
    return low;
  }

  Future<File> _receiveParts(Map<String, Object?> offer) async {
    final id = offer['id'];
    final parts = offer['parts'];
    final bytes = offer['bytes'];
    final size = offer['partSize'];
    if (id is! String ||
        !NearbyTransferFiles.isSafeName(id) ||
        parts is! int ||
        bytes is! int ||
        size is! int ||
        parts < 0 ||
        bytes < 0 ||
        size <= 0) {
      throw const _DirectionFailed(
        NearbyPeerError.unreachable,
        tellPeer: NearbyErrorCode.protocol,
      );
    }
    final file = _files.incoming(_peerId, id);
    await _files.discardOtherIncoming(_peerId, keep: id);
    final row = await _peers.get(_peerId);
    final offeredAt = row?.resumeOfferedAt;
    final lastPart = row?.resumePartIndex;
    var from = 0;
    if (row?.resumeBaseId == id &&
        offeredAt != null &&
        _now().millisecondsSinceEpoch - offeredAt <
            nearbyResumeWindow.inMilliseconds &&
        lastPart != null &&
        await file.exists() &&
        await file.length() == (lastPart + 1) * size) {
      from = lastPart + 1;
    } else {
      if (await file.exists()) await file.delete();
      await _peers.setResume(
        _peerId,
        baseId: id,
        offeredAt: _now().millisecondsSinceEpoch,
      );
    }
    final startedAt = (await _peers.get(_peerId))?.resumeOfferedAt;
    await _sendJson(NearbyMessageType.baseRequest, {'from': from});
    var done = from * size;
    for (var i = from; i < parts; i++) {
      final m = await _expect(NearbyMessageType.basePart, timeout: partTimeout);
      if (m.body.length < 4 || ByteData.sublistView(m.body).getUint32(0) != i) {
        throw const _DirectionFailed(
          NearbyPeerError.unreachable,
          tellPeer: NearbyErrorCode.protocol,
        );
      }
      final chunk = Uint8List.sublistView(m.body, 4);
      await file.writeAsBytes(chunk, mode: FileMode.append, flush: true);
      await _peers.setResume(
        _peerId,
        baseId: id,
        partIndex: i,
        offeredAt: startedAt,
      );
      done += chunk.length;
      onProgress?.call(done, bytes);
    }
    if (!await file.exists() || await file.length() != bytes) {
      if (await file.exists()) await file.delete();
      await _peers.setResume(_peerId);
      throw const _DirectionFailed(
        NearbyPeerError.unreachable,
        tellPeer: NearbyErrorCode.protocol,
      );
    }
    return file;
  }

  // ---------------------------------------------------------------------
  // Sending

  Future<void> _send() async {
    final first = await _messages.moveNext().timeout(
      messageTimeout,
      onTimeout: () => throw const NearbyTimeout('watermarks'),
    );
    if (!first) throw const NearbyLinkClosed();
    final message = _messages.current;
    if (message.type == NearbyMessageType.error) {
      throw _DirectionFailed(_peerRefusal(message));
    }
    if (message.type != NearbyMessageType.watermarks) {
      throw const _DirectionFailed(NearbyPeerError.unreachable);
    }
    final body = _decode(message);
    await _adoptFrom(body);
    final NearbyWatermarks theirs;
    try {
      theirs = NearbyWatermarks.fromJson(body);
    } on FormatException {
      throw const _DirectionFailed(NearbyPeerError.unreachable);
    }

    final outgoing = await _prepare(theirs);
    final Map<String, Object?> applied;
    try {
      if (outgoing == null) {
        await _sendJson(NearbyMessageType.baseOffer, {
          'kind': 'none',
          'epoch': _self.epochId,
        });
      } else {
        await _sendParts(outgoing);
      }
      applied = await _expectJson(
        NearbyMessageType.applied,
        timeout: applyTimeout,
      );
    } on Object catch (e) {
      // A delta is rebuilt every session; only a full copy waits for a
      // resume, and only after a lost link: one the peer refused (it could
      // not unpack or apply it) is made afresh next time.
      if (outgoing != null && outgoing.kind == 'full') {
        if (e is _DirectionFailed) await _files.discardOutgoing(_peerId);
      } else if (outgoing != null && await outgoing.file.exists()) {
        await outgoing.file.delete();
      }
      rethrow;
    }
    final ack = applied['ack'];
    await _engine.recordPeerAck(
      peerDeviceId: _peerId,
      peerAppliedHlcHigh: ack is String ? ack : null,
    );
    if (outgoing != null) {
      if (outgoing.kind == 'full') await _files.discardOutgoing(_peerId);
      if (await outgoing.file.exists()) await outgoing.file.delete();
    }
  }

  /// What this direction sends, or null for nothing.
  Future<NearbyOutgoing?> _prepare(NearbyWatermarks theirs) async {
    final mine = await _engine.watermarks();
    var kind = NearbyExportPlanner.decide(mine: mine, peers: theirs);
    String? from;
    if (kind == NearbyExportKind.delta) {
      from = NearbyExportPlanner.deltaWatermark(mine: mine, peers: theirs);
      if (from == null) return null;
      if (await _engine.deltaBlobBytes(from) > _engine.maxDeltaBlobBytes) {
        kind = NearbyExportKind.full;
      }
    }
    switch (kind) {
      case NearbyExportKind.nothing:
        return null;
      case NearbyExportKind.full:
        final reused = await _files.reusableFull(_peerId);
        if (reused != null) return reused;
        final base = await _engine.exportFull();
        return _files.prepareFull(_peerId, const Uuid().v4(), File(base.path));
      case NearbyExportKind.delta:
        final payload = NearbyExportPlanner.filterByWriter(
          await _engine.exportDelta(from!),
          theirs,
        );
        if (_isEmpty(payload)) return null;
        return _files.prepareDelta(
          _peerId,
          const Uuid().v4(),
          jsonEncode(payload.toJson()),
        );
    }
  }

  static bool _isEmpty(SyncPayload payload) {
    for (final value in payload.data.toJson().values) {
      if (value is List && value.isNotEmpty) return false;
    }
    for (final list in payload.deletions.values) {
      if (list.isNotEmpty) return false;
    }
    return true;
  }

  Future<void> _sendParts(NearbyOutgoing out) async {
    final parts = out.partCount(partSize);
    await _sendJson(NearbyMessageType.baseOffer, {
      'id': out.id,
      'kind': out.kind,
      'parts': parts,
      'bytes': out.byteLength,
      'partSize': partSize,
      'epoch': _self.epochId,
    });
    final request = await _expectJson(NearbyMessageType.baseRequest);
    final from = request['from'];
    if (from is! int || from < 0 || from > parts) {
      throw const _DirectionFailed(NearbyPeerError.unreachable);
    }
    var done = from * partSize;
    for (var i = from; i < parts; i++) {
      final chunk = await out.readPart(i, partSize);
      final body = Uint8List(4 + chunk.length);
      ByteData.sublistView(body).setUint32(0, i);
      body.setRange(4, body.length, chunk);
      await _channel.send(NearbyMessageType.basePart, body);
      _sent += chunk.length;
      done += chunk.length;
      onProgress?.call(done, out.byteLength);
    }
  }

  // ---------------------------------------------------------------------
  // Messages

  NearbyPeerError _peerRefusal(NearbyMessage m) => nearbyPeerRefusalError(
    NearbyErrorCode.fromByte(m.body.isEmpty ? 255 : m.body[0]),
  );

  Future<NearbyMessage> _expect(
    NearbyMessageType type, {
    Duration? timeout,
  }) async {
    final has = await _messages.moveNext().timeout(
      timeout ?? messageTimeout,
      onTimeout: () => throw NearbyTimeout(type.name),
    );
    if (!has) throw const NearbyLinkClosed();
    final m = _messages.current;
    if (m.type == type) return m;
    if (m.type == NearbyMessageType.error) {
      throw _DirectionFailed(_peerRefusal(m));
    }
    if (m.type == NearbyMessageType.bye) throw const NearbyLinkClosed();
    throw const _DirectionFailed(
      NearbyPeerError.unreachable,
      tellPeer: NearbyErrorCode.protocol,
    );
  }

  Future<Map<String, Object?>> _expectJson(
    NearbyMessageType type, {
    Duration? timeout,
  }) async => _decode(await _expect(type, timeout: timeout));

  Map<String, Object?> _decode(NearbyMessage m) {
    try {
      final value = jsonDecode(utf8.decode(m.body));
      if (value is Map<String, Object?>) return value;
    } on FormatException {
      // Falls through to the refusal.
    }
    throw const _DirectionFailed(
      NearbyPeerError.unreachable,
      tellPeer: NearbyErrorCode.protocol,
    );
  }

  Future<void> _sendJson(NearbyMessageType type, Map<String, Object?> body) =>
      _channel.send(type, Uint8List.fromList(utf8.encode(jsonEncode(body))));

  Future<void> _sendError(NearbyErrorCode code) async {
    try {
      await _channel.send(
        NearbyMessageType.error,
        Uint8List.fromList([code.index]),
      );
    } on NearbyLinkClosed {
      throw const _LinkLost();
    }
  }
}

class _LinkLost implements Exception {
  const _LinkLost();
}
