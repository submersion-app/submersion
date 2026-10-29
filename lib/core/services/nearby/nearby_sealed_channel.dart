part of 'nearby_session.dart';

/// An authenticated, encrypted message channel to one peer. Every frame is
/// sealed, `error` and `bye` included, so nobody in range can end a session
/// with a forged refusal.
class NearbySealedChannel {
  NearbySealedChannel._({
    required this.isInitiator,
    required NearbyEndpoint endpoint,
    required NearbySessionCipher cipher,
    required Stream<NearbyMessage> raw,
  }) : _endpoint = endpoint,
       _cipher = cipher {
    messages = raw
        .asyncMap((m) async => NearbyMessage(m.type, await cipher.open(m.body)))
        .takeWhile((_) => !_closing);
  }

  final bool isInitiator;
  final NearbyEndpoint _endpoint;
  final NearbySessionCipher _cipher;

  /// Decrypted messages in order. A box that fails to open is a stream
  /// error ([NearbyAuthFailure]); the stream ends when the link does, or
  /// after [close] at the next frame, so a replaced or ended session reads
  /// none of the frames still in flight.
  late final Stream<NearbyMessage> messages;

  bool _closing = false;

  Future<void> _tail = Future.value();

  /// Sends are queued so the nonce counter and the frames stay in order.
  Future<void> send(NearbyMessageType type, Uint8List body) {
    final next = _tail.then((_) async {
      final payload = await _cipher.seal(body);
      await _endpoint.send(FrameEncoder.encode(type, payload));
    });
    _tail = next.catchError((Object _) {});
    return next;
  }

  /// The longest [close] waits for its `bye` to go out. The bye queues
  /// behind every earlier send, and a stalled link (a central that stopped
  /// reading a full outbox) would otherwise hold an unpair or the move to
  /// the background until the peer caught up.
  static const byeTimeout = Duration(seconds: 2);

  /// Says `bye` (best effort) and closes the link.
  Future<void> close() async {
    _closing = true;
    try {
      await send(NearbyMessageType.bye, Uint8List(0)).timeout(byeTimeout);
    } on NearbyLinkClosed {
      // Already closed.
    } on TimeoutException {
      // Stalled: hang up without it.
    }
    await _endpoint.close();
  }
}
