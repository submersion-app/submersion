import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_crypto.dart';
import 'package:submersion/core/services/nearby/nearby_frame.dart';
import 'package:submersion/core/services/nearby/nearby_hello.dart';
import 'package:submersion/core/services/nearby/nearby_inbox.dart';

/// The long-lived pair secrets, one per paired peer, keyed by device id.
abstract class NearbyPairSecrets {
  Future<Uint8List?> secretFor(String peerDeviceId);

  Future<void> store(String peerDeviceId, Uint8List secret);

  Future<void> remove(String peerDeviceId);
}

/// A session ended before it started. [fromPeer] is true when the other
/// device sent the refusal, false when this device refused.
class NearbySessionRefused implements Exception {
  const NearbySessionRefused(this.code, {required this.fromPeer});

  final NearbyErrorCode code;
  final bool fromPeer;

  @override
  String toString() =>
      'NearbySessionRefused(${code.name}, fromPeer: $fromPeer)';
}

/// The peer's hello (or key reveal) did not arrive in time.
class NearbyHelloTimeout extends NearbyTimeout {
  const NearbyHelloTimeout() : super('hello');
}

/// The other diver tapped "Not mine".
class NearbyPairingRejected implements Exception {
  const NearbyPairingRejected();

  @override
  String toString() => 'NearbyPairingRejected';
}

/// What a responder found when a device connected to it.
sealed class NearbyIncoming {
  const NearbyIncoming();
}

class NearbyIncomingSync extends NearbyIncoming {
  const NearbyIncomingSync(this.channel);

  final NearbyChannel channel;
}

class NearbyIncomingPairing extends NearbyIncoming {
  const NearbyIncomingPairing(this.pairing);

  final NearbyPairing pairing;
}

const _keyCheckText = 'submersion-nearby-key-check';

bool _isPlaintext(NearbyMessageType type) =>
    type == NearbyMessageType.error || type == NearbyMessageType.bye;

/// Opens one link: hello both ways, the key reveal, the key check, and for
/// pairing the code on both screens.
///
/// The initiator (the device that connected) calls [openSync] or
/// [openPairing]; the responder calls [accept] and learns the intent from
/// the initiator's hello.
class NearbySession {
  NearbySession({
    required NearbyEndpoint endpoint,
    required NearbyIdentity identity,
    required NearbyPairSecrets secrets,
    this.helloTimeout = const Duration(seconds: 10),
    this.confirmTimeout = const Duration(minutes: 2),
  }) : _endpoint = endpoint,
       _identity = identity,
       _secrets = secrets,
       _inbox = NearbyInbox(endpoint.inbound);

  final NearbyEndpoint _endpoint;
  final NearbyIdentity _identity;
  final NearbyPairSecrets _secrets;
  final NearbyInbox _inbox;
  final Duration helloTimeout;
  final Duration confirmTimeout;

  Future<NearbyChannel> openSync() async {
    final (peer, shared) = await _initiate(NearbyIntent.sync);
    final secret = await _secrets.secretFor(peer.deviceId);
    if (secret == null) await _refuse(NearbyErrorCode.notPaired);
    final cipher = await shared.sessionCipher(pairSecret: secret);
    await _keyCheck(cipher);
    return _channel(peer, cipher);
  }

  Future<NearbyPairing> openPairing() async {
    final (peer, shared) = await _initiate(NearbyIntent.pair);
    final cipher = await shared.sessionCipher();
    await _keyCheck(cipher);
    return NearbyPairing._(this, peer, shared, cipher);
  }

  Future<NearbyIncoming> accept({required bool allowPairing}) async {
    final peer = await _readHello();
    if (peer.commitment == null) await _refuse(NearbyErrorCode.protocol);
    await _checkPeer(peer);
    Uint8List? secret;
    if (peer.intent == NearbyIntent.sync) {
      secret = await _secrets.secretFor(peer.deviceId);
      if (secret == null) await _refuse(NearbyErrorCode.notPaired);
    } else if (!allowPairing) {
      await _refuse(NearbyErrorCode.notPaired);
    }

    final handshake = await NearbyHandshake.start();
    await _sendFrame(
      NearbyMessageType.hello,
      NearbyHello.from(
        _identity,
        intent: peer.intent,
        publicKey: handshake.publicKey,
      ).toBytes(),
    );
    final reveal = await _expect(NearbyMessageType.helloReveal, hello: true);
    if (!await NearbyHandshake.verifyCommitment(
      peer.commitment!,
      reveal.body,
    )) {
      await _refuse(NearbyErrorCode.protocol);
    }
    final NearbySharedSecret shared;
    try {
      shared = await handshake.complete(reveal.body, isInitiator: false);
    } on NearbyAuthFailure {
      return _refuse(NearbyErrorCode.protocol);
    }
    final revealed = NearbyHello(
      protocolVersion: peer.protocolVersion,
      deviceId: peer.deviceId,
      deviceName: peer.deviceName,
      appVersion: peer.appVersion,
      schemaVersion: peer.schemaVersion,
      epochId: peer.epochId,
      hasDives: peer.hasDives,
      intent: peer.intent,
      publicKey: reveal.body,
    );
    if (peer.intent == NearbyIntent.sync) {
      final cipher = await shared.sessionCipher(pairSecret: secret);
      await _keyCheck(cipher);
      return NearbyIncomingSync(_channel(revealed, cipher));
    }
    final cipher = await shared.sessionCipher();
    await _keyCheck(cipher);
    return NearbyIncomingPairing(
      NearbyPairing._(this, revealed, shared, cipher),
    );
  }

  Future<(NearbyHello, NearbySharedSecret)> _initiate(
    NearbyIntent intent,
  ) async {
    final handshake = await NearbyHandshake.start();
    await _sendFrame(
      NearbyMessageType.hello,
      NearbyHello.from(
        _identity,
        intent: intent,
        commitment: handshake.commitment,
      ).toBytes(),
    );
    final peer = await _readHello();
    await _checkPeer(peer);
    final peerKey = peer.publicKey;
    if (peerKey == null) await _refuse(NearbyErrorCode.protocol);
    await _sendFrame(NearbyMessageType.helloReveal, handshake.publicKey);
    try {
      return (peer, await handshake.complete(peerKey!, isInitiator: true));
    } on NearbyAuthFailure {
      return _refuse(NearbyErrorCode.protocol);
    }
  }

  Future<void> _checkPeer(NearbyHello peer) async {
    if (peer.protocolVersion > NearbyHello.currentProtocolVersion) {
      await _refuse(NearbyErrorCode.newerApp);
    }
    final mine = _identity.epochId;
    final theirs = peer.epochId;
    if (mine != null && theirs != null && mine != theirs) {
      await _refuse(NearbyErrorCode.differentLibrary);
    }
  }

  Future<NearbyHello> _readHello() async {
    final message = await _expect(NearbyMessageType.hello, hello: true);
    try {
      return NearbyHello.fromBytes(message.body);
    } on FormatException {
      return _refuse(NearbyErrorCode.protocol);
    }
  }

  /// Both sides send a sealed known text and open the other's. A failure
  /// means the two derived different keys: one of them no longer holds the
  /// pair secret the other does.
  Future<void> _keyCheck(NearbySessionCipher cipher) async {
    await _sendFrame(
      NearbyMessageType.keyCheck,
      await cipher.seal(Uint8List.fromList(utf8.encode(_keyCheckText))),
    );
    final message = await _expect(NearbyMessageType.keyCheck, hello: true);
    try {
      final text = utf8.decode(await cipher.open(message.body));
      if (text != _keyCheckText) await _refuse(NearbyErrorCode.notPaired);
    } on NearbyAuthFailure {
      await _refuse(NearbyErrorCode.notPaired);
    }
  }

  /// Reads the next frame and insists on [type]. An `error` frame becomes
  /// a refusal from the peer; anything else is a protocol violation.
  Future<NearbyMessage> _expect(
    NearbyMessageType type, {
    required bool hello,
    Duration? timeout,
  }) async {
    final NearbyMessage message;
    try {
      message = await _inbox.next(
        timeout: timeout ?? helloTimeout,
        waitingFor: type.name,
      );
    } on NearbyTimeout catch (e) {
      await _endpoint.close();
      if (hello) throw const NearbyHelloTimeout();
      throw e;
    } on NearbyLinkClosed {
      rethrow;
    } on Object {
      return _refuse(NearbyErrorCode.protocol);
    }
    if (message.type == type) return message;
    if (message.type == NearbyMessageType.error) {
      await _endpoint.close();
      throw NearbySessionRefused(
        NearbyErrorCode.fromByte(message.body.isEmpty ? 255 : message.body[0]),
        fromPeer: true,
      );
    }
    if (message.type == NearbyMessageType.bye) {
      await _endpoint.close();
      throw const NearbySessionRefused(
        NearbyErrorCode.protocol,
        fromPeer: true,
      );
    }
    return _refuse(NearbyErrorCode.protocol);
  }

  Future<void> _sendFrame(NearbyMessageType type, Uint8List body) =>
      _endpoint.send(FrameEncoder.encode(type, body));

  /// Tells the peer why, closes the link, and throws.
  Future<Never> _refuse(NearbyErrorCode code) async {
    try {
      await _sendFrame(
        NearbyMessageType.error,
        Uint8List.fromList([code.index]),
      );
      await _sendFrame(NearbyMessageType.bye, Uint8List(0));
    } on NearbyLinkClosed {
      // The peer is already gone; the refusal stands.
    }
    await _endpoint.close();
    throw NearbySessionRefused(code, fromPeer: false);
  }

  NearbyChannel _channel(NearbyHello peer, NearbySessionCipher cipher) =>
      NearbyChannel._(
        peer: peer,
        isInitiator: _endpoint.isInitiator,
        endpoint: _endpoint,
        cipher: cipher,
        raw: _inbox.rest(),
      );
}

/// A pairing waiting for the diver on each device to compare the codes.
class NearbyPairing {
  NearbyPairing._(this._session, this.peer, this._shared, this._cipher);

  final NearbySession _session;
  final NearbyHello peer;
  final NearbySharedSecret _shared;
  final NearbySessionCipher _cipher;

  String get code => _shared.pairingCode;

  /// Both devices already hold dives: pairing merges two logbooks.
  bool get bothPopulated => peer.hasDives && _session._identity.hasDives;

  /// This diver tapped "Same code". Completes once the other diver did too,
  /// with both pair secrets stored and the channel re-keyed with them.
  Future<NearbyChannel> confirm() async {
    final s = _session;
    await s._sendFrame(
      NearbyMessageType.pairConfirm,
      await _cipher.seal(Uint8List(0)),
    );
    final NearbyMessage reply;
    try {
      reply = await s._inbox.next(
        timeout: s.confirmTimeout,
        waitingFor: 'the other device to confirm',
      );
    } on NearbyTimeout {
      await s._endpoint.close();
      rethrow;
    }
    switch (reply.type) {
      case NearbyMessageType.pairConfirm:
        try {
          await _cipher.open(reply.body);
        } on NearbyAuthFailure {
          return s._refuse(NearbyErrorCode.protocol);
        }
      case NearbyMessageType.pairReject:
        await s._endpoint.close();
        throw const NearbyPairingRejected();
      case NearbyMessageType.error:
        await s._endpoint.close();
        throw NearbySessionRefused(
          NearbyErrorCode.fromByte(reply.body.isEmpty ? 255 : reply.body[0]),
          fromPeer: true,
        );
      case NearbyMessageType.bye:
        await s._endpoint.close();
        throw const NearbyPairingRejected();
      default:
        return s._refuse(NearbyErrorCode.protocol);
    }
    final secret = await _shared.pairSecret();
    await s._secrets.store(peer.deviceId, secret);
    return s._channel(peer, await _shared.sessionCipher(pairSecret: secret));
  }

  /// This diver tapped "Not mine": nothing is stored on either device.
  Future<void> reject() async {
    final s = _session;
    try {
      await s._sendFrame(
        NearbyMessageType.pairReject,
        await _cipher.seal(Uint8List(0)),
      );
      await s._sendFrame(NearbyMessageType.bye, Uint8List(0));
    } on NearbyLinkClosed {
      // Already gone.
    }
    await s._endpoint.close();
  }
}

/// An authenticated, encrypted message channel to one peer. `error` and
/// `bye` travel in the clear; every other body is sealed.
class NearbyChannel {
  NearbyChannel._({
    required this.peer,
    required this.isInitiator,
    required NearbyEndpoint endpoint,
    required NearbySessionCipher cipher,
    required Stream<NearbyMessage> raw,
  }) : _endpoint = endpoint,
       _cipher = cipher,
       messages = raw.asyncMap(
         (m) async => _isPlaintext(m.type)
             ? m
             : NearbyMessage(m.type, await cipher.open(m.body)),
       );

  final NearbyHello peer;
  final bool isInitiator;
  final NearbyEndpoint _endpoint;
  final NearbySessionCipher _cipher;

  /// Decrypted messages in order. A box that fails to open is a stream
  /// error ([NearbyAuthFailure]); the stream ends when the link does.
  final Stream<NearbyMessage> messages;

  Future<void> _tail = Future.value();

  /// Sends are queued so the nonce counter and the frames stay in order.
  Future<void> send(NearbyMessageType type, Uint8List body) {
    final next = _tail.then((_) async {
      final payload = _isPlaintext(type) ? body : await _cipher.seal(body);
      await _endpoint.send(FrameEncoder.encode(type, payload));
    });
    _tail = next.catchError((Object _) {});
    return next;
  }

  /// Says `bye` (best effort) and closes the link.
  Future<void> close() async {
    try {
      await send(NearbyMessageType.bye, Uint8List(0));
    } on NearbyLinkClosed {
      // Already closed.
    }
    await _endpoint.close();
  }
}
