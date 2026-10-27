import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_frame.dart';

/// No message arrived in time.
class NearbyTimeout implements Exception {
  const NearbyTimeout(this.waitingFor);

  final String waitingFor;

  @override
  String toString() => 'NearbyTimeout: waiting for $waitingFor';
}

/// Decoded frames from one endpoint, read one at a time during the
/// handshake and then handed over whole to the channel as a stream.
class NearbyInbox {
  NearbyInbox(Stream<Uint8List> inbound) {
    final decoder = FrameDecoder();
    _inboundSub = inbound.listen(
      decoder.add,
      onDone: decoder.close,
      onError: (Object e) => _push(_Event.error(e)),
    );
    decoder.messages.listen(
      (m) => _push(_Event.message(m)),
      onError: (Object e) => _push(_Event.error(e)),
      onDone: () => _push(const _Event.done()),
    );
  }

  late final StreamSubscription<Uint8List> _inboundSub;
  final _queue = Queue<_Event>();
  Completer<void>? _arrived;
  StreamController<NearbyMessage>? _forward;

  void _push(_Event event) {
    final forward = _forward;
    if (forward != null) {
      _emit(forward, event);
      return;
    }
    _queue.add(event);
    _arrived?.complete();
    _arrived = null;
  }

  static void _emit(StreamController<NearbyMessage> c, _Event event) {
    if (c.isClosed) return;
    switch (event) {
      case _Event(:final message?):
        c.add(message);
      case _Event(:final error?):
        c.addError(error);
      default:
        c.close();
    }
  }

  /// The next message. Throws a frame error as it arrived, [NearbyLinkClosed]
  /// when the link ended first, or [NearbyTimeout] after [timeout].
  Future<NearbyMessage> next({
    required Duration timeout,
    required String waitingFor,
  }) async {
    if (_queue.isEmpty) {
      final arrived = _arrived ??= Completer<void>();
      await arrived.future.timeout(
        timeout,
        onTimeout: () => throw NearbyTimeout(waitingFor),
      );
    }
    final event = _queue.removeFirst();
    if (event.message != null) return event.message!;
    if (event.error != null) throw event.error!;
    // Put the end back so a later read sees it too.
    _queue.addFirst(event);
    throw const NearbyLinkClosed();
  }

  /// Everything not yet read, then everything that follows. The inbox
  /// cannot be read with [next] afterwards.
  Stream<NearbyMessage> rest() {
    final forward = StreamController<NearbyMessage>(
      onCancel: () => _inboundSub.cancel(),
    );
    while (_queue.isNotEmpty) {
      _emit(forward, _queue.removeFirst());
    }
    _forward = forward;
    return forward.stream;
  }
}

class _Event {
  const _Event.message(NearbyMessage this.message) : error = null;
  const _Event.error(Object this.error) : message = null;
  const _Event.done() : message = null, error = null;

  final NearbyMessage? message;
  final Object? error;
}
