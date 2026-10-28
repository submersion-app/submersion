import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_crypto.dart';
import 'package:submersion/core/services/nearby/nearby_frame.dart';
import 'package:submersion/core/services/nearby/nearby_hello.dart';
import 'package:submersion/core/services/nearby/nearby_inbox.dart';

part 'nearby_sealed_channel.dart';
part 'nearby_session_card.dart';

/// The long-lived pair secrets, one per paired peer, keyed by device id.
abstract class NearbyPairSecrets {
  Future<Uint8List?> secretFor(String peerDeviceId);

  Future<void> store(String peerDeviceId, Uint8List secret);

  Future<void> remove(String peerDeviceId);

  /// Unpairs [peerDeviceId] but keeps its secret aside, so this device can
  /// still recognise that peer and tell it, authenticated, that it is no
  /// longer paired. Storing a new secret for it clears the revocation.
  Future<void> revoke(String peerDeviceId);

  /// Every stored secret by peer device id, for the anonymous tags.
  Future<Map<String, Uint8List>> all();

  /// The revoked secrets by peer device id.
  Future<Map<String, Uint8List>> revoked();
}

/// A session ended before it started. [fromPeer] is true when the other
/// device sent the refusal, false when this device refused.
class NearbySessionRefused implements Exception {
  const NearbySessionRefused(
    this.code, {
    required this.fromPeer,
    this.peerDeviceId,
  });

  final NearbyErrorCode code;
  final bool fromPeer;

  /// The peer the refusal is known to come from, when the handshake got far
  /// enough to authenticate it (a device that unpaired this one says so
  /// after the key check). Null for a refusal from an unknown device.
  final String? peerDeviceId;

  @override
  String toString() =>
      'NearbySessionRefused(${code.name}, fromPeer: $fromPeer, '
      'peer: $peerDeviceId)';
}

/// What two devices show each other before both divers confirm a pairing:
/// a name, whether it holds dives, an [epochTag] that matches the other's
/// only when both are on the same library (it reveals nothing else about
/// the library), and a [nonce] that names this pairing attempt without
/// naming the device.
class NearbyPairingPreview {
  const NearbyPairingPreview({
    required this.name,
    required this.hasDives,
    required this.epochTag,
    required this.nonce,
  });

  final String name;
  final bool hasDives;
  final Uint8List? epochTag;
  final String nonce;

  Map<String, Object?> toJson() => {
    'name': name,
    'dives': hasDives,
    'epochTag': epochTag == null ? null : base64Encode(epochTag!),
    'nonce': nonce,
  };

  /// Throws [FormatException] on anything but a well-formed preview.
  factory NearbyPairingPreview.fromJson(Map<String, Object?> json) {
    final name = json['name'];
    final dives = json['dives'];
    final tag = json['epochTag'];
    final nonce = json['nonce'];
    if (name is! String || dives is! bool || nonce is! String) {
      throw const FormatException('pairing preview');
    }
    if (tag != null && tag is! String) {
      throw const FormatException('pairing preview epochTag');
    }
    return NearbyPairingPreview(
      name: name,
      hasDives: dives,
      epochTag: tag == null ? null : base64Decode(tag as String),
      nonce: nonce,
    );
  }
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

/// What a revoked pairing sends in place of its identity.
const _refusedNotPaired = 'notPaired';

String _newNonce() {
  final random = Random.secure();
  return base64Url.encode(List.generate(12, (_) => random.nextInt(256)));
}

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
    String? pairingNonce,
    this.helloTimeout = const Duration(seconds: 10),
    this.confirmTimeout = const Duration(minutes: 2),
  }) : _endpoint = endpoint,
       _identity = identity,
       _secrets = secrets,
       pairingNonce = pairingNonce ?? _newNonce(),
       _inbox = NearbyInbox(endpoint.inbound);

  /// Names this device in pairing previews: random and short-lived, so a
  /// stranger nearby cannot follow the device from one pairing to the next.
  final String pairingNonce;

  /// A fresh value for [pairingNonce], one per pairing mode.
  static String newPairingNonce() => _newNonce();

  /// The fewest tags a sync hello carries. The hello is plaintext, so one
  /// tag per pairing would tell anyone in range how many devices this one
  /// is paired with; random tags pad it, and match no secret.
  static const minHelloTags = 8;

  /// [real] padded with random tags to [minHelloTags], in random order.
  static List<Uint8List> paddedTags(List<Uint8List> real) {
    final random = Random.secure();
    final out = [
      ...real,
      for (var i = real.length; i < minHelloTags; i++)
        Uint8List.fromList(List.generate(8, (_) => random.nextInt(256))),
    ]..shuffle(random);
    return out;
  }

  final NearbyEndpoint _endpoint;
  final NearbyIdentity _identity;
  final NearbyPairSecrets _secrets;
  final NearbyInbox _inbox;
  final Duration helloTimeout;
  final Duration confirmTimeout;

  Future<NearbyChannel> openSync() async {
    final handshake = await NearbyHandshake.start();
    final secrets = await _secrets.all();
    await _sendHello(
      NearbyHello(
        protocolVersion: NearbyHello.currentProtocolVersion,
        intent: NearbyIntent.sync,
        commitment: handshake.commitment,
        tags: paddedTags([
          for (final secret in secrets.values)
            await NearbyHandshake.tag(secret, 'i', handshake.commitment),
        ]),
      ),
    );
    final reply = await _readHello();
    final peerKey = reply.publicKey;
    final peerTag = reply.tag;
    if (peerKey == null || peerTag == null) {
      await _refuse(NearbyErrorCode.protocol);
    }
    String? peerId;
    for (final entry in secrets.entries) {
      final expected = await NearbyHandshake.tag(entry.value, 'r', [
        ...handshake.commitment,
        ...peerKey,
      ]);
      if (constantTimeEquals(expected, peerTag)) peerId = entry.key;
    }
    if (peerId == null) await _refuse(NearbyErrorCode.notPaired);
    final shared = await _reveal(handshake, peerKey);
    final cipher = await shared.sessionCipher(pairSecret: secrets[peerId]);
    await _keyCheck(cipher);
    final peer = await _exchangeIdentity(cipher, expectedId: peerId);
    return _channel(peer, cipher);
  }

  Future<NearbyPairing> openPairing() async {
    final handshake = await NearbyHandshake.start();
    await _sendHello(
      NearbyHello(
        protocolVersion: NearbyHello.currentProtocolVersion,
        intent: NearbyIntent.pair,
        commitment: handshake.commitment,
      ),
    );
    final reply = await _readHello();
    final peerKey = reply.publicKey;
    if (peerKey == null) await _refuse(NearbyErrorCode.protocol);
    final shared = await _reveal(handshake, peerKey);
    final cipher = await shared.sessionCipher();
    await _keyCheck(cipher);
    final (mine, peer) = await _exchangePreview(cipher, shared);
    return NearbyPairing._(this, mine, peer, shared, cipher);
  }

  /// [allowCard] while the buddy card swap screen is open (issue #3728);
  /// otherwise a card hello is refused with `notSwapping`.
  Future<NearbyIncoming> accept({
    required bool allowPairing,
    bool allowCard = false,
  }) async {
    final hello = await _readHello();
    final commitment = hello.commitment;
    if (commitment == null) await _refuse(NearbyErrorCode.protocol);
    String? peerId;
    Uint8List? secret;
    var revoked = false;
    if (hello.intent == NearbyIntent.sync) {
      Future<void> match(Map<String, Uint8List> candidates) async {
        for (final entry in candidates.entries) {
          final expected = await NearbyHandshake.tag(
            entry.value,
            'i',
            commitment,
          );
          if (hello.tags.any((t) => constantTimeEquals(t, expected))) {
            peerId = entry.key;
            secret = entry.value;
          }
        }
      }

      await match(await _secrets.all());
      if (peerId == null) {
        // A device this one unpaired: finish the handshake with the old
        // secret so the refusal reaches it authenticated and named.
        await match(await _secrets.revoked());
        revoked = peerId != null;
      }
      if (peerId == null) await _refuse(NearbyErrorCode.notPaired);
    } else if (hello.intent == NearbyIntent.card) {
      if (!allowCard) await _refuse(NearbyErrorCode.notSwapping);
    } else if (!allowPairing) {
      await _refuse(NearbyErrorCode.notPaired);
    }

    final handshake = await NearbyHandshake.start();
    await _sendHello(
      NearbyHello(
        protocolVersion: hello.intent == NearbyIntent.card
            ? NearbyHello.cardProtocolVersion
            : NearbyHello.currentProtocolVersion,
        intent: hello.intent,
        publicKey: handshake.publicKey,
        tag: secret == null
            ? null
            : await NearbyHandshake.tag(secret!, 'r', [
                ...commitment,
                ...handshake.publicKey,
              ]),
      ),
    );
    final reveal = await _expect(NearbyMessageType.helloReveal, hello: true);
    if (!await NearbyHandshake.verifyCommitment(commitment, reveal.body)) {
      await _refuse(NearbyErrorCode.protocol);
    }
    final NearbySharedSecret shared;
    try {
      shared = await handshake.complete(reveal.body, isInitiator: false);
    } on NearbyAuthFailure {
      return _refuse(NearbyErrorCode.protocol);
    }
    final cipher = await shared.sessionCipher(pairSecret: secret);
    await _keyCheck(cipher);
    if (hello.intent == NearbyIntent.card) {
      return NearbyIncomingCard(_cardChannel(cipher));
    }
    if (hello.intent == NearbyIntent.pair) {
      final (mine, peer) = await _exchangePreview(cipher, shared);
      return NearbyIncomingPairing(
        NearbyPairing._(this, mine, peer, shared, cipher),
      );
    }
    if (revoked) {
      await _sendFrame(
        NearbyMessageType.identity,
        await cipher.seal(
          Uint8List.fromList(
            utf8.encode(jsonEncode({'refused': _refusedNotPaired})),
          ),
        ),
      );
      await _endpoint.close();
      throw NearbySessionRefused(
        NearbyErrorCode.notPaired,
        fromPeer: false,
        peerDeviceId: peerId,
      );
    }
    final peer = await _exchangeIdentity(cipher, expectedId: peerId);
    return NearbyIncomingSync(_channel(peer, cipher));
  }

  /// Both sides of a pairing show each other a preview, sealed: a name and
  /// whether they hold dives, never a device id or a library epoch. Two
  /// different libraries are refused here, before either diver confirms.
  Future<(NearbyPairingPreview, NearbyPairingPreview)> _exchangePreview(
    NearbySessionCipher cipher,
    NearbySharedSecret shared,
  ) async {
    final epoch = _identity.epochId;
    final mine = NearbyPairingPreview(
      name: _identity.deviceName,
      hasDives: _identity.hasDives,
      epochTag: epoch == null
          ? null
          : await NearbyHandshake.tag(
              await shared.pairSecret(),
              'epoch',
              utf8.encode(epoch),
            ),
      nonce: pairingNonce,
    );
    await _sendFrame(
      NearbyMessageType.identity,
      await cipher.seal(
        Uint8List.fromList(utf8.encode(jsonEncode(mine.toJson()))),
      ),
    );
    final message = await _expect(
      NearbyMessageType.identity,
      hello: true,
      cipher: cipher,
    );
    final NearbyPairingPreview peer;
    try {
      final decoded = jsonDecode(utf8.decode(await cipher.open(message.body)));
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('pairing preview');
      }
      peer = NearbyPairingPreview.fromJson(decoded);
    } on NearbyAuthFailure {
      return _refuse(NearbyErrorCode.protocol, cipher: cipher);
    } on FormatException {
      return _refuse(NearbyErrorCode.protocol, cipher: cipher);
    }
    final a = mine.epochTag;
    final b = peer.epochTag;
    if (a != null && b != null && !constantTimeEquals(a, b)) {
      await _refuse(NearbyErrorCode.differentLibrary, cipher: cipher);
    }
    return (mine, peer);
  }

  Future<void> _sendHello(NearbyHello hello) =>
      _sendFrame(NearbyMessageType.hello, hello.toBytes());

  /// The initiator's half after the responder's hello: reveal the key it
  /// committed to and derive the shared secret.
  Future<NearbySharedSecret> _reveal(
    NearbyHandshake handshake,
    Uint8List peerKey,
  ) async {
    await _sendFrame(NearbyMessageType.helloReveal, handshake.publicKey);
    try {
      return await handshake.complete(peerKey, isInitiator: true);
    } on NearbyAuthFailure {
      return _refuse(NearbyErrorCode.protocol);
    }
  }

  /// Both sides send who they are, sealed, and read the other's. A sync
  /// peer must be the device its tag named; two libraries never meet.
  Future<NearbyIdentity> _exchangeIdentity(
    NearbySessionCipher cipher, {
    String? expectedId,
  }) async {
    try {
      await _sendFrame(
        NearbyMessageType.identity,
        await cipher.seal(_identity.toBytes()),
      );
    } on NearbyLinkClosed {
      // A peer that unpaired this device sends its sealed refusal and hangs
      // up at once; the refusal is already in the inbox.
    }
    final message = await _expect(
      NearbyMessageType.identity,
      hello: true,
      cipher: cipher,
    );
    final NearbyIdentity peer;
    try {
      final decoded = jsonDecode(utf8.decode(await cipher.open(message.body)));
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('identity');
      }
      if (decoded['refused'] == _refusedNotPaired) {
        // The peer this device is paired with unpaired it. The refusal is
        // sealed under the pair key, so it is genuine.
        await _endpoint.close();
        throw NearbySessionRefused(
          NearbyErrorCode.notPaired,
          fromPeer: true,
          peerDeviceId: expectedId,
        );
      }
      peer = NearbyIdentity.fromJson(decoded);
    } on NearbyAuthFailure {
      return _refuse(NearbyErrorCode.protocol, cipher: cipher);
    } on FormatException {
      return _refuse(NearbyErrorCode.protocol, cipher: cipher);
    }
    // A cloned install reports this device's own id; pairing with it would
    // merge two writers into one.
    if (peer.deviceId == _identity.deviceId ||
        (expectedId != null && peer.deviceId != expectedId)) {
      await _refuse(NearbyErrorCode.protocol, cipher: cipher);
    }
    final mine = _identity.epochId;
    final theirs = peer.epochId;
    if (mine != null && theirs != null && mine != theirs) {
      // Both sides refuse here at once, so neither hears the other's
      // refusal: a paired peer is named, for its row to say so.
      await _refuse(
        NearbyErrorCode.differentLibrary,
        peerDeviceId: expectedId,
        cipher: cipher,
      );
    }
    return peer;
  }

  Future<NearbyHello> _readHello() async {
    final message = await _expect(NearbyMessageType.hello, hello: true);
    // The version first, on its own: a newer peer's hello may carry an
    // intent or a field this build cannot parse, and it must still learn
    // which side needs the update.
    final version = NearbyHello.versionOf(message.body);
    if (version != null && version > NearbyHello.maxProtocolVersion) {
      await _refuse(NearbyErrorCode.newerApp);
    }
    final NearbyHello hello;
    try {
      hello = NearbyHello.fromBytes(message.body);
    } on Object {
      // Malformed in any way, typed or not: refuse rather than hang.
      return _refuse(NearbyErrorCode.protocol);
    }
    // Only a card hello may go past the sync and pair version (issue
    // #3728): a sync or pair hello above it is from a newer build.
    if (hello.intent != NearbyIntent.card &&
        hello.protocolVersion > NearbyHello.currentProtocolVersion) {
      await _refuse(NearbyErrorCode.newerApp);
    }
    return hello;
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
  /// a refusal from the peer; anything else is a protocol violation. With
  /// [cipher] (after the key check) an `error` or `bye` must be sealed.
  Future<NearbyMessage> _expect(
    NearbyMessageType type, {
    required bool hello,
    Duration? timeout,
    NearbySessionCipher? cipher,
  }) async {
    final NearbyMessage message;
    try {
      message = await _inbox.next(
        timeout: timeout ?? helloTimeout,
        waitingFor: type.name,
      );
    } on NearbyTimeout {
      await _endpoint.close();
      if (hello) throw const NearbyHelloTimeout();
      rethrow;
    } on NearbyLinkClosed {
      rethrow;
    } on Object {
      return _refuse(NearbyErrorCode.protocol);
    }
    if (message.type == type) return message;
    if (message.type == NearbyMessageType.error) {
      final body = await _openControl(message, cipher);
      await _endpoint.close();
      throw NearbySessionRefused(
        NearbyErrorCode.fromByte(body.isEmpty ? 255 : body[0]),
        fromPeer: true,
      );
    }
    if (message.type == NearbyMessageType.bye) {
      await _openControl(message, cipher);
      await _endpoint.close();
      throw const NearbySessionRefused(
        NearbyErrorCode.protocol,
        fromPeer: true,
      );
    }
    return _refuse(NearbyErrorCode.protocol, cipher: cipher);
  }

  /// The body of an `error` or `bye`. Once [cipher] exists it must open:
  /// a bare one could come from anyone in range, so it is a protocol
  /// violation rather than the peer's word.
  Future<Uint8List> _openControl(
    NearbyMessage message,
    NearbySessionCipher? cipher,
  ) async {
    if (cipher == null) return message.body;
    try {
      return await cipher.open(message.body);
    } on NearbyAuthFailure {
      return _refuse(NearbyErrorCode.protocol, cipher: cipher);
    }
  }

  Future<void> _sendFrame(NearbyMessageType type, Uint8List body) =>
      _endpoint.send(FrameEncoder.encode(type, body));

  /// Tells the peer why, closes the link, and throws. [peerDeviceId] names
  /// the peer once the handshake has authenticated it. After the key check
  /// both frames go sealed under [cipher], as every later frame does.
  Future<Never> _refuse(
    NearbyErrorCode code, {
    String? peerDeviceId,
    NearbySessionCipher? cipher,
  }) async {
    Future<Uint8List> body(List<int> plain) async {
      final bytes = Uint8List.fromList(plain);
      return cipher == null ? bytes : cipher.seal(bytes);
    }

    try {
      await _sendFrame(NearbyMessageType.error, await body([code.index]));
      await _sendFrame(NearbyMessageType.bye, await body(const []));
    } on NearbyLinkClosed {
      // The peer is already gone; the refusal stands.
    }
    await _endpoint.close();
    throw NearbySessionRefused(
      code,
      fromPeer: false,
      peerDeviceId: peerDeviceId,
    );
  }

  NearbyChannel _channel(NearbyIdentity peer, NearbySessionCipher cipher) =>
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
  NearbyPairing._(
    this._session,
    this._mine,
    this.preview,
    this._shared,
    this._cipher,
  );

  final NearbySession _session;
  final NearbyPairingPreview _mine;

  /// The other device, as far as this one may know it before both confirm.
  final NearbyPairingPreview preview;
  final NearbySharedSecret _shared;
  final NearbySessionCipher _cipher;

  String get code => _shared.pairingCode;

  bool get sameLibrary {
    final a = _mine.epochTag;
    final b = preview.epochTag;
    return a != null && b != null && constantTimeEquals(a, b);
  }

  /// Both devices hold dives of two different logbooks: pairing merges them.
  bool get bothPopulated => preview.hasDives && _mine.hasDives && !sameLibrary;

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
          return s._refuse(NearbyErrorCode.protocol, cipher: _cipher);
        }
      case NearbyMessageType.pairReject:
        // Sealed like the confirm: anyone in range could send it bare.
        try {
          await _cipher.open(reply.body);
        } on NearbyAuthFailure {
          return s._refuse(NearbyErrorCode.protocol, cipher: _cipher);
        }
        await s._endpoint.close();
        throw const NearbyPairingRejected();
      case NearbyMessageType.error:
        final body = await s._openControl(reply, _cipher);
        await s._endpoint.close();
        throw NearbySessionRefused(
          NearbyErrorCode.fromByte(body.isEmpty ? 255 : body[0]),
          fromPeer: true,
        );
      case NearbyMessageType.bye:
        // A bye says nothing about the other diver: a real "Not mine"
        // arrives as its own sealed frame before it.
        await s._openControl(reply, _cipher);
        await s._endpoint.close();
        throw const NearbyLinkClosed();
      default:
        return s._refuse(NearbyErrorCode.protocol, cipher: _cipher);
    }
    // Both confirmed: re-key with the pair secret, then exchange the full
    // identities, which only now either device may know.
    final secret = await _shared.pairSecret();
    final cipher = await _shared.sessionCipher(pairSecret: secret);
    final peer = await s._exchangeIdentity(cipher);
    await s._secrets.store(peer.deviceId, secret);
    return s._channel(peer, cipher);
  }

  /// This diver tapped "Not mine": nothing is stored on either device.
  Future<void> reject() async {
    final s = _session;
    try {
      await s._sendFrame(
        NearbyMessageType.pairReject,
        await _cipher.seal(Uint8List(0)),
      );
      await s._sendFrame(
        NearbyMessageType.bye,
        await _cipher.seal(Uint8List(0)),
      );
    } on NearbyLinkClosed {
      // Already gone.
    }
    await s._endpoint.close();
  }
}

/// The sealed channel of a sync or pairing session, to one known peer.
class NearbyChannel extends NearbySealedChannel {
  NearbyChannel._({
    required this.peer,
    required super.isInitiator,
    required super.endpoint,
    required super.cipher,
    required super.raw,
  }) : super._();

  final NearbyIdentity peer;
}
