import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/nearby/nearby_frame.dart';
import 'package:submersion/core/services/nearby/nearby_hello.dart';
import 'package:submersion/core/services/nearby/nearby_session.dart';

/// A diver seen on the buddy card swap screen (issue #3728).
class NearbyCardPeer {
  const NearbyCardPeer({
    required this.swapId,
    required this.name,
    this.transportId,
    this.photo,
  });

  /// Random per swap screen, so one diver seen over two carriers or two
  /// links shows once.
  final String swapId;
  final String name;

  /// Where this device can dial the peer; null when it has only dialled us.
  final String? transportId;
  final Uint8List? photo;
}

enum NearbyCardFailure { declined, timedOut, lost, newerApp }

typedef NearbyCardDecision = void Function(bool accept);

sealed class NearbyCardEvent {
  const NearbyCardEvent();
}

class CardPeersChanged extends NearbyCardEvent {
  const CardPeersChanged(this.peers);
  final List<NearbyCardPeer> peers;
}

/// [from] asks to swap; call [decide] once with the diver's answer.
class CardRequested extends NearbyCardEvent {
  const CardRequested(this.from, this.decide);
  final NearbyCardPeer from;
  final NearbyCardDecision decide;
}

class CardReceived extends NearbyCardEvent {
  const CardReceived(this.from, this.cardBytes);
  final NearbyCardPeer from;
  final Uint8List cardBytes;
}

class CardSwapFailed extends NearbyCardEvent {
  const CardSwapFailed(this.peer, this.reason);
  final NearbyCardPeer peer;
  final NearbyCardFailure reason;
}

/// Opens a card session to [transportId] over whichever carrier saw it.
typedef NearbyCardDialer =
    Future<NearbyCardChannel> Function(String transportId);

/// The buddy card swap over the nearby link (issue #3728), while the swap
/// screen is open.
///
/// Every session runs the same short exchange. Both sides send a
/// `cardSummary` (a random swap id, the name and a thumbnail), then one
/// `cardRequest` saying whether they want to swap now. Nobody wanting
/// closes the link at once: a Bluetooth peripheral holds one connection
/// at a time, so a listing never keeps one open. One side wanting asks the
/// other diver, who answers `cardAccept` or `cardDecline`; both wanting is
/// a swap with no question. A swap is each side's full card, then `bye`.
class NearbyCardHost {
  NearbyCardHost({
    required this.name,
    this.photo,
    required Future<Uint8List> Function() card,
    this.answerWindow = const Duration(seconds: 60),
    this.summaryRefresh = const Duration(minutes: 2),
    this.staleAfter = const Duration(seconds: 45),
    String? swapId,
    DateTime Function()? now,
  }) : _card = card,
       swapId = swapId ?? _newSwapId(),
       _now = now ?? DateTime.now;

  static final _log = LoggerService.forClass(NearbyCardHost);

  final String name;
  final Uint8List? photo;
  final Future<Uint8List> Function() _card;
  final Duration answerWindow;
  final Duration summaryRefresh;

  /// A diver not seen for this long has left the screen or the boat.
  final Duration staleAfter;
  final String swapId;
  final DateTime Function() _now;

  final _events = StreamController<NearbyCardEvent>.broadcast();
  final _peers = <String, NearbyCardPeer>{};
  final _pending = <String>{};
  final _lastDial = <String, DateTime>{};
  final _lastSeen = <String, DateTime>{};
  final _lastSighted = <String, DateTime>{};
  final _requested = <String>{};
  final _received = <String>{};
  final _channels = <NearbyCardChannel>{};
  NearbyCardDialer? _dial;
  bool _disposed = false;

  Stream<NearbyCardEvent> get events => _events.stream;

  /// The divers seen lately, in the order first seen.
  List<NearbyCardPeer> get peers {
    final now = _now();
    bool fresh(NearbyCardPeer p) {
      final transport = p.transportId;
      final seen =
          [
            _lastSeen[p.swapId],
            if (transport != null) _lastSighted[transport],
          ].whereType<DateTime>().fold<DateTime?>(
            null,
            (a, b) => a == null || b.isAfter(a) ? b : a,
          );
      return seen != null && now.difference(seen) <= staleAfter;
    }

    return List.unmodifiable(_peers.values.where(fresh));
  }

  static String _newSwapId() {
    final random = Random.secure();
    return base64Url.encode(List.generate(9, (_) => random.nextInt(256)));
  }

  /// Set by the link manager when card mode starts; null when it ends.
  void attach(NearbyCardDialer? dial) => _dial = dial;

  /// A Submersion device was seen at [transportId]: look at who it is,
  /// at most once per [summaryRefresh].
  void onSighting(String transportId) {
    if (_disposed || _dial == null) return;
    _lastSighted[transportId] = _now();
    final last = _lastDial[transportId];
    if (last != null && _now().difference(last) < summaryRefresh) return;
    _lastDial[transportId] = _now();
    unawaited(_dialAndRun(transportId));
  }

  /// A card session someone else opened.
  void onIncoming(NearbyCardChannel channel) {
    if (_disposed) {
      unawaited(channel.close());
      return;
    }
    unawaited(_run(channel, dialled: null));
  }

  /// Asks [peer] to swap. When this device cannot dial them, the request
  /// waits for their next look at this one.
  Future<void> request(NearbyCardPeer peer) async {
    if (_disposed) return;
    _pending.add(peer.swapId);
    _requested.add(peer.swapId);
    final transport = peer.transportId;
    if (transport != null) {
      _lastDial[transport] = _now();
      await _dialAndRun(transport);
    }
  }

  Future<void> _dialAndRun(String transportId) async {
    final dial = _dial;
    if (dial == null) return;
    final NearbyCardChannel channel;
    try {
      channel = await dial(transportId);
    } on NearbySessionRefused catch (e) {
      // Off its swap screen, or a build without card swaps: not listed.
      _forgetTransport(transportId);
      _log.info('Card session to $transportId refused: ${e.code}');
      return;
    } on Object catch (e) {
      _log.info('Card session to $transportId failed: $e');
      return;
    }
    await _run(channel, dialled: transportId);
  }

  void _forgetTransport(String transportId) {
    final gone = [
      for (final p in _peers.values)
        if (p.transportId == transportId) p.swapId,
    ];
    if (gone.isEmpty) return;
    gone.forEach(_peers.remove);
    _emitPeers();
  }

  void _emitPeers() {
    if (!_events.isClosed) _events.add(CardPeersChanged(peers));
  }

  void _emit(NearbyCardEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  Uint8List _summary() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        's': swapId,
        'n': name,
        if (photo != null) 'p': base64Encode(photo!),
      }),
    ),
  );

  static Map<String, Object?>? _json(Uint8List body) {
    try {
      final decoded = jsonDecode(utf8.decode(body));
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _run(NearbyCardChannel channel, {String? dialled}) async {
    _channels.add(channel);
    final reader = StreamIterator(channel.messages);
    NearbyCardPeer? peer;
    Future<NearbyMessage?> next(Duration within) async =>
        await reader.moveNext().timeout(within) ? reader.current : null;

    try {
      await channel.send(NearbyMessageType.cardSummary, _summary());
      final summary = await next(_step);
      if (summary?.type != NearbyMessageType.cardSummary) return;
      peer = _readSummary(summary!.body, dialled);
      if (peer == null) return;
      final theirId = peer.swapId;

      final iWant = _pending.remove(theirId);
      await channel.send(
        NearbyMessageType.cardRequest,
        _jsonBytes({'want': iWant}),
      );
      final theirRequest = await next(_step);
      if (theirRequest?.type != NearbyMessageType.cardRequest) {
        if (iWant) _fail(peer, NearbyCardFailure.lost);
        return;
      }
      final theyWant = _json(theirRequest!.body)?['want'] == true;
      if (!iWant && !theyWant) return;

      if (!iWant) {
        // Asked while this diver asked them too, or after a swap on this
        // screen already: both said yes, so no question.
        final mutual =
            _requested.contains(theirId) || _received.contains(theirId);
        final accepted = mutual || await _ask(peer, channel);
        await channel.send(
          accepted
              ? NearbyMessageType.cardAccept
              : NearbyMessageType.cardDecline,
          _jsonBytes(accepted ? const {} : const {'r': 'declined'}),
        );
        if (!accepted) return;
      } else if (!theyWant) {
        final answer = await next(answerWindow + _slack);
        if (answer?.type == NearbyMessageType.cardDecline) {
          _fail(
            peer,
            _json(answer!.body)?['r'] == 'timeout'
                ? NearbyCardFailure.timedOut
                : NearbyCardFailure.declined,
          );
          return;
        }
        // The other diver left their screen (a bye) or the link dropped.
        if (answer?.type != NearbyMessageType.cardAccept) {
          _fail(peer, NearbyCardFailure.lost);
          return;
        }
      }

      await channel.send(NearbyMessageType.card, await _card());
      final theirCard = await next(_cardStep);
      if (theirCard?.type != NearbyMessageType.card) {
        _fail(peer, NearbyCardFailure.lost);
        return;
      }
      _requested.remove(theirId);
      // Two links to one diver (both asked at once) both carry the card;
      // the diver sees it once.
      if (_received.add(theirId)) _emit(CardReceived(peer, theirCard!.body));
    } on _AnswerTimedOut {
      // This diver did not answer; the asker was told.
    } on TimeoutException {
      if (peer != null) _fail(peer, NearbyCardFailure.timedOut);
    } on NearbySessionRefused catch (e) {
      if (peer != null) {
        _fail(
          peer,
          e.code == NearbyErrorCode.newerApp
              ? NearbyCardFailure.newerApp
              : NearbyCardFailure.lost,
        );
      }
    } on Object catch (e) {
      _log.info('Card session ended: $e');
      if (peer != null && _requested.contains(peer.swapId)) {
        _fail(peer, NearbyCardFailure.lost);
      }
    } finally {
      _channels.remove(channel);
      await reader.cancel();
      await channel.close();
    }
  }

  NearbyCardPeer? _readSummary(Uint8List body, String? dialled) {
    final json = _json(body);
    final theirId = json?['s'];
    final theirName = json?['n'];
    if (theirId is! String || theirName is! String || theirId == swapId) {
      return null;
    }
    final known = _peers[theirId];
    final photoText = json!['p'];
    final peer = NearbyCardPeer(
      swapId: theirId,
      name: theirName,
      transportId: dialled ?? known?.transportId,
      photo: photoText is String ? _photo(photoText) : known?.photo,
    );
    _peers[theirId] = peer;
    _lastSeen[theirId] = _now();
    _emitPeers();
    return peer;
  }

  /// Reports [reason] for [peer], unless their card already arrived over
  /// another link.
  void _fail(NearbyCardPeer peer, NearbyCardFailure reason) {
    if (_received.contains(peer.swapId)) return;
    _requested.remove(peer.swapId);
    _emit(CardSwapFailed(peer, reason));
  }

  static Uint8List _jsonBytes(Map<String, Object?> json) =>
      Uint8List.fromList(utf8.encode(jsonEncode(json)));

  /// How long one step of the exchange may take.
  static const _step = Duration(seconds: 10);
  static const _cardStep = Duration(seconds: 30);

  /// Extra time a waiting asker allows past the answer window, for the
  /// other side's timeout message to arrive.
  static const _slack = Duration(seconds: 2);

  /// Shows the request to this diver; on no answer within [answerWindow],
  /// tells the asker it timed out and throws [_AnswerTimedOut].
  Future<bool> _ask(NearbyCardPeer peer, NearbyCardChannel channel) async {
    final answer = Completer<bool>();
    _emit(
      CardRequested(peer, (accept) {
        if (!answer.isCompleted) answer.complete(accept);
      }),
    );
    try {
      return await answer.future.timeout(answerWindow);
    } on TimeoutException {
      await channel.send(
        NearbyMessageType.cardDecline,
        _jsonBytes(const {'r': 'timeout'}),
      );
      throw const _AnswerTimedOut();
    }
  }

  static Uint8List? _photo(String text) {
    try {
      final bytes = base64Decode(text);
      return bytes.length > 16 * 1024 ? null : bytes;
    } on FormatException {
      return null;
    }
  }

  /// Ends every session and stops listening.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _dial = null;
    await Future.wait([for (final c in _channels.toList()) c.close()]);
    await _events.close();
  }
}

class _AnswerTimedOut implements Exception {
  const _AnswerTimedOut();
}
