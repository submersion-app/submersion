part of 'nearby_session.dart';

/// A buddy card session someone else opened (issue #3728).
class NearbyIncomingCard extends NearbyIncoming {
  const NearbyIncomingCard(this.channel);

  final NearbyCardChannel channel;
}

/// The sealed channel of a buddy card session (issue #3728). The two
/// devices are strangers: no pair secret, no identity exchange, and a key
/// from this session's ephemeral exchange alone. No code is compared; each
/// diver confirms what arrives on a preview instead.
class NearbyCardChannel extends NearbySealedChannel {
  NearbyCardChannel._({
    required super.isInitiator,
    required super.endpoint,
    required super.cipher,
    required super.raw,
  }) : super._();
}

extension NearbySessionCard on NearbySession {
  /// Opens a buddy card session to a device on its swap screen. Throws
  /// [NearbySessionRefused] with `notSwapping` when it is not, and with
  /// `newerApp` from a build that predates card swaps.
  Future<NearbyCardChannel> openCard() async {
    final handshake = await NearbyHandshake.start();
    await _sendHello(
      NearbyHello(
        protocolVersion: NearbyHello.cardProtocolVersion,
        intent: NearbyIntent.card,
        commitment: handshake.commitment,
      ),
    );
    final reply = await _readHello();
    final peerKey = reply.publicKey;
    if (peerKey == null) await _refuse(NearbyErrorCode.protocol);
    final shared = await _reveal(handshake, peerKey);
    final cipher = await shared.sessionCipher();
    await _keyCheck(cipher);
    return _cardChannel(cipher);
  }

  NearbyCardChannel _cardChannel(NearbySessionCipher cipher) =>
      NearbyCardChannel._(
        isInitiator: _endpoint.isInitiator,
        endpoint: _endpoint,
        cipher: cipher,
        raw: _inbox.rest(),
      );
}
