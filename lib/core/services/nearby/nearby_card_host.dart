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

/// [from]'s request went unanswered for the whole window; any open
/// question about it should close.
class CardRequestExpired extends NearbyCardEvent {
  const CardRequestExpired(this.from);
  final NearbyCardPeer from;
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
    this.mutualGrace = const Duration(seconds: 10),
    this.step = const Duration(seconds: 10),
    this.dialRetry = const Duration(seconds: 10),
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

  /// How long after a swap a crossing link counts as the same swap.
  final Duration mutualGrace;

  /// How long one step of the exchange may take.
  final Duration step;

  /// How soon a dial that did not connect is tried again.
  final Duration dialRetry;
  final String swapId;
  final DateTime Function() _now;

  final _events = StreamController<NearbyCardEvent>.broadcast();
  final _peers = <String, NearbyCardPeer>{};
  final _pending = <String>{};
  final _lastDial = <String, DateTime>{};
  final _lastSeen = <String, DateTime>{};
  final _lastSighted = <String, DateTime>{};
  final _requested = <String>{};

  /// When each diver's card last arrived. Within [mutualGrace] a second
  /// link carrying the same swap is quiet (no second card, no question);
  /// after it, a new request is a new question.
  final _swappedAt = <String, DateTime>{};

  /// Every transport each diver was dialled over, so a sighting on any of
  /// them keeps the diver listed.
  final _transportsBySwap = <String, Set<String>>{};
  final _requestTimers = <String, Timer>{};
  final _channels = <NearbyCardChannel>{};
  NearbyCardDialer? _dial;

  /// Dialers for carriers outside the link manager, by transport prefix.
  final _carrierDials = <String, NearbyCardDialer>{};
  bool _disposed = false;

  Stream<NearbyCardEvent> get events => _events.stream;

  /// The divers seen lately, in the order first seen.
  List<NearbyCardPeer> get peers {
    final now = _now();
    bool fresh(NearbyCardPeer p) {
      final transports = {?p.transportId, ...?_transportsBySwap[p.swapId]};
      DateTime? seen = _lastSeen[p.swapId];
      for (final t in transports) {
        final at = _lastSighted[t];
        if (at != null && (seen == null || at.isAfter(seen))) seen = at;
      }
      return seen != null && now.difference(seen) <= staleAfter;
    }

    return List.unmodifiable(_peers.values.where(fresh));
  }

  /// The longest name a nearby diver is listed by, as on a buddy card.
  static const int maxNameLength = 200;

  static String _newSwapId() {
    final random = Random.secure();
    return base64Url.encode(List.generate(9, (_) => random.nextInt(256)));
  }

  /// Set by the link manager when card mode starts; null when it ends.
  void attach(NearbyCardDialer? dial) => _dial = dial;

  /// A carrier outside the link manager (Multipeer) whose transport ids
  /// start with [prefix]; null [dial] detaches it.
  void attachCarrier(String prefix, NearbyCardDialer? dial) {
    if (dial == null) {
      _carrierDials.remove(prefix);
    } else {
      _carrierDials[prefix] = dial;
    }
  }

  NearbyCardDialer? _dialerFor(String transportId) {
    for (final entry in _carrierDials.entries) {
      if (transportId.startsWith(entry.key)) return entry.value;
    }
    return _dial;
  }

  /// Whether [transportId] is on a carrier outside the link manager, which
  /// is faster and preferred for a diver seen over both.
  bool _isPreferred(String? transportId) =>
      transportId != null &&
      _carrierDials.keys.any((prefix) => transportId.startsWith(prefix));

  /// A Submersion device was seen at [transportId]: look at who it is,
  /// at most once per [summaryRefresh].
  void onSighting(String transportId) {
    if (_disposed || _dialerFor(transportId) == null) return;
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
  /// waits for their next look at this one, for at most [answerWindow].
  /// A request that cannot reach them ends with [CardSwapFailed].
  Future<void> request(NearbyCardPeer peer) async {
    if (_disposed) return;
    final id = peer.swapId;
    _pending.add(id);
    _requested.add(id);
    _swappedAt.remove(id);
    final transport = peer.transportId;
    if (transport == null) {
      _requestTimers[id]?.cancel();
      _requestTimers[id] = Timer(answerWindow, () {
        _requestTimers.remove(id);
        if (_pending.remove(id)) _fail(peer, NearbyCardFailure.timedOut);
      });
      return;
    }
    _lastDial[transport] = _now();
    await _dialAndRun(transport);
    // No session heard them (the dial failed, or the link ended before
    // their summary): free the row rather than let the request fire
    // minutes later on an unrelated look.
    if (_pending.remove(id)) _fail(peer, NearbyCardFailure.lost);
  }

  Future<void> _dialAndRun(String transportId) async {
    final dial = _dialerFor(transportId);
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
      // A dial that did not connect is tried again on a sighting after
      // [dialRetry], not a whole [summaryRefresh] later.
      _lastDial[transportId] = _now().subtract(summaryRefresh - dialRetry);
      return;
    }
    await _run(channel, dialled: transportId);
  }

  bool _swappedLately(String swapId) {
    final at = _swappedAt[swapId];
    return at != null && _now().difference(at) < mutualGrace;
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
    // This diver said yes to their request: a link lost after that is
    // reported, though they were not the one asking.
    var acceptedTheirs = false;
    Future<NearbyMessage?> next(Duration within) async =>
        await reader.moveNext().timeout(within) ? reader.current : null;

    try {
      await channel.send(NearbyMessageType.cardSummary, _summary());
      final summary = await next(step);
      if (summary?.type != NearbyMessageType.cardSummary) return;
      peer = _readSummary(summary!.body, dialled);
      if (peer == null) return;
      final theirId = peer.swapId;

      final iWant = _pending.remove(theirId);
      await channel.send(
        NearbyMessageType.cardRequest,
        _jsonBytes({'want': iWant}),
      );
      final theirRequest = await next(step);
      if (theirRequest?.type != NearbyMessageType.cardRequest) {
        if (iWant) _fail(peer, NearbyCardFailure.lost);
        return;
      }
      final theyWant = _json(theirRequest!.body)?['want'] == true;
      if (!iWant && !theyWant) return;

      if (!iWant) {
        // Asked while this diver asked them too, or after a swap on this
        // screen already: both said yes, so no question.
        final mutual = _requested.contains(theirId) || _swappedLately(theirId);
        final accepted = mutual || await _ask(peer, channel);
        acceptedTheirs = accepted;
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
      _requestTimers.remove(theirId)?.cancel();
      if (!_swappedLately(theirId)) {
        _swappedAt[theirId] = _now();
        _emit(CardReceived(peer, theirCard!.body));
      }
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
      if (peer != null &&
          (acceptedTheirs || _requested.contains(peer.swapId))) {
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
    final rawName = json?['n'];
    if (theirId is! String || rawName is! String || theirId == swapId) {
      return null;
    }
    // A diver is listed by a real name, kept to a card's length: a blank
    // name lists nobody, and a huge one (from anything in range) is cut.
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return null;
    final theirName = trimmed.length <= maxNameLength
        ? trimmed
        : trimmed.substring(0, maxNameLength);
    final known = _peers[theirId];
    final photoText = json!['p'];
    final peer = NearbyCardPeer(
      swapId: theirId,
      name: theirName,
      transportId: _isPreferred(known?.transportId) && !_isPreferred(dialled)
          ? known!.transportId
          : dialled ?? known?.transportId,
      photo: photoText is String ? _photo(photoText) : known?.photo,
    );
    _peers[theirId] = peer;
    _lastSeen[theirId] = _now();
    if (dialled != null) {
      (_transportsBySwap[theirId] ??= <String>{}).add(dialled);
    }
    _emitPeers();
    return peer;
  }

  /// Reports [reason] for [peer], unless their card already arrived over
  /// another link.
  void _fail(NearbyCardPeer peer, NearbyCardFailure reason) {
    if (_swappedLately(peer.swapId)) return;
    _requested.remove(peer.swapId);
    _requestTimers.remove(peer.swapId)?.cancel();
    _emit(CardSwapFailed(peer, reason));
  }

  static Uint8List _jsonBytes(Map<String, Object?> json) =>
      Uint8List.fromList(utf8.encode(jsonEncode(json)));

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
      _emit(CardRequestExpired(peer));
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
    _carrierDials.clear();
    for (final timer in _requestTimers.values) {
      timer.cancel();
    }
    _requestTimers.clear();
    await Future.wait([for (final c in _channels.toList()) c.close()]);
    await _events.close();
  }
}

class _AnswerTimedOut implements Exception {
  const _AnswerTimedOut();
}
