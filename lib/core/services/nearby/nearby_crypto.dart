import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// A box did not authenticate, a public key was malformed, or a nonce
/// counter ran out. The link ends the session on any of these.
class NearbyAuthFailure implements Exception {
  const NearbyAuthFailure(this.message);

  final String message;

  @override
  String toString() => 'NearbyAuthFailure: $message';
}

const _sasInfo = 'submersion-nearby-sas-v1';
const _pairInfo = 'submersion-nearby-pair-v1';
const _sessionInfo = 'submersion-nearby-session-v1';
const _unpairedSessionInfo = 'submersion-nearby-session-unpaired-v1';

/// Whether [a] and [b] hold the same bytes, in time that depends on their
/// length only: a tag, commitment or key check compared byte by byte with
/// an early exit would tell a stranger how much of a guess was right.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

const _x25519 = DartX25519();
const _sha256 = DartSha256();
final _aesGcm = DartAesGcm.with256bits();

Future<Uint8List> _hkdf({
  required List<int> ikm,
  required List<int> salt,
  required String info,
  int length = 32,
}) async {
  final hkdf = DartHkdf(hmac: const DartHmac(_sha256), outputLength: length);
  final key = await hkdf.deriveKey(
    secretKey: SecretKeyData(ikm),
    nonce: salt,
    info: utf8.encode(info),
  );
  return Uint8List.fromList(await key.extractBytes());
}

/// One side of an ephemeral X25519 exchange.
///
/// The initiator sends [commitment] before it learns the responder's key
/// and reveals [publicKey] only after: a device in the middle must then fix
/// its own key before it can see the one it would need to match, so the
/// six-digit code on both screens matches by chance one time in a million
/// rather than after a quick search.
class NearbyHandshake {
  NearbyHandshake._(this._keyPair, this.publicKey, this.commitment);

  final SimpleKeyPair _keyPair;
  final Uint8List publicKey;
  final Uint8List commitment;

  static Future<NearbyHandshake> start() async {
    final keyPair = await _x25519.newKeyPair();
    final pub = await keyPair.extractPublicKey();
    final bytes = Uint8List.fromList(pub.bytes);
    return NearbyHandshake._(keyPair, bytes, await _commit(bytes));
  }

  static Future<Uint8List> _commit(Uint8List publicKey) async {
    final hash = await _sha256.hash(publicKey);
    return Uint8List.fromList(hash.bytes);
  }

  static Future<bool> verifyCommitment(
    Uint8List commitment,
    Uint8List publicKey,
  ) async => constantTimeEquals(await _commit(publicKey), commitment);

  /// An anonymous 8-byte proof of holding [secret], bound to [data] (this
  /// session's commitment, and for the responder also its public key).
  static Future<Uint8List> tag(
    Uint8List secret,
    String label,
    List<int> data,
  ) async {
    final mac = await const DartHmac(_sha256).calculateMac([
      ...utf8.encode('submersion-nearby-tag-$label-v1'),
      ...data,
    ], secretKey: SecretKeyData(secret));
    return Uint8List.fromList(mac.bytes.sublist(0, 8));
  }

  Future<NearbySharedSecret> complete(
    Uint8List peerPublicKey, {
    required bool isInitiator,
  }) async {
    if (peerPublicKey.length != 32) {
      throw const NearbyAuthFailure('public key must be 32 bytes');
    }
    final shared = await _x25519.sharedSecretKey(
      keyPair: _keyPair,
      remotePublicKey: SimplePublicKey(peerPublicKey, type: KeyPairType.x25519),
    );
    final ecdh = Uint8List.fromList(await shared.extractBytes());
    final salt = Uint8List.fromList([
      ...(isInitiator ? publicKey : peerPublicKey),
      ...(isInitiator ? peerPublicKey : publicKey),
    ]);
    final sas = await _hkdf(ikm: ecdh, salt: salt, info: _sasInfo, length: 4);
    final number = ByteData.sublistView(sas).getUint32(0) % 1000000;
    return NearbySharedSecret._(
      ecdh: ecdh,
      salt: salt,
      isInitiator: isInitiator,
      pairingCode: number.toString().padLeft(6, '0'),
    );
  }
}

/// What both sides of one handshake agree on.
class NearbySharedSecret {
  const NearbySharedSecret._({
    required Uint8List ecdh,
    required Uint8List salt,
    required this.isInitiator,
    required this.pairingCode,
  }) : _ecdh = ecdh,
       _salt = salt;

  final Uint8List _ecdh;
  final Uint8List _salt;
  final bool isInitiator;

  /// Six digits, zero padded, the same on both devices.
  final String pairingCode;

  /// The long-lived secret two devices keep after the diver confirms the
  /// code on both screens.
  Future<Uint8List> pairSecret() =>
      _hkdf(ikm: _ecdh, salt: _salt, info: _pairInfo);

  /// The cipher for this session. With [pairSecret] the key also proves
  /// both sides hold the stored pair secret; without it the key rests on
  /// this handshake alone (pairing, and later the unpaired card swap).
  Future<NearbySessionCipher> sessionCipher({Uint8List? pairSecret}) async {
    final key = pairSecret == null
        ? await _hkdf(ikm: _ecdh, salt: _salt, info: _unpairedSessionInfo)
        : await _hkdf(
            ikm: [...pairSecret, ..._ecdh],
            salt: _salt,
            info: _sessionInfo,
          );
    return NearbySessionCipher._(key, isInitiator);
  }
}

/// AES-256-GCM over an ordered, reliable link.
///
/// The nonce is never sent: it is a 4-byte direction (0 from initiator to
/// responder, 1 the other way) and an 8-byte counter each side keeps per
/// direction, so a reordered, replayed or reflected box fails to open.
class NearbySessionCipher {
  NearbySessionCipher._(Uint8List key, this._isInitiator)
    : _key = SecretKeyData(key);

  final SecretKeyData _key;
  final bool _isInitiator;
  int _sent = 0;
  int _received = 0;

  static const _macLength = 16;

  List<int> _nonce(int direction, int counter) {
    final nonce = Uint8List(12);
    final view = ByteData.sublistView(nonce);
    view.setUint32(0, direction);
    view.setUint64(4, counter);
    return nonce;
  }

  Future<Uint8List> seal(Uint8List plaintext) async {
    if (_sent < 0) throw const NearbyAuthFailure('nonce counter exhausted');
    final box = await _aesGcm.encrypt(
      plaintext,
      secretKey: _key,
      nonce: _nonce(_isInitiator ? 0 : 1, _sent++),
    );
    final text = box.cipherText;
    final mac = box.mac.bytes;
    return Uint8List(text.length + mac.length)
      ..setRange(0, text.length, text)
      ..setRange(text.length, text.length + mac.length, mac);
  }

  Future<Uint8List> open(Uint8List sealed) async {
    if (sealed.length < _macLength) {
      throw const NearbyAuthFailure('box too short');
    }
    final split = sealed.length - _macLength;
    final box = SecretBox(
      Uint8List.sublistView(sealed, 0, split),
      nonce: _nonce(_isInitiator ? 1 : 0, _received),
      mac: Mac(Uint8List.sublistView(sealed, split)),
    );
    try {
      final plain = await _aesGcm.decrypt(box, secretKey: _key);
      _received++;
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const NearbyAuthFailure('box did not authenticate');
    }
  }
}
