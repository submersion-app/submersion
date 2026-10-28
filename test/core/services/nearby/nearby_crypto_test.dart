import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_crypto.dart';

/// Runs both halves of a handshake and returns (initiator, responder).
Future<(NearbySharedSecret, NearbySharedSecret)> _pair() async {
  final a = await NearbyHandshake.start();
  final b = await NearbyHandshake.start();
  final initiator = await a.complete(b.publicKey, isInitiator: true);
  final responder = await b.complete(a.publicKey, isInitiator: false);
  return (initiator, responder);
}

Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group('NearbyHandshake', () {
    test('both sides derive the same six-digit code', () async {
      final (initiator, responder) = await _pair();
      expect(initiator.pairingCode, responder.pairingCode);
      expect(initiator.pairingCode, matches(RegExp(r'^\d{6}$')));
    });

    test('a third public key gives a different code', () async {
      final a = await NearbyHandshake.start();
      final b = await NearbyHandshake.start();
      final m = await NearbyHandshake.start();
      final real = await a.complete(b.publicKey, isInitiator: true);
      final spoofed = await a.complete(m.publicKey, isInitiator: true);
      expect(real.pairingCode, isNot(spoofed.pairingCode));
    });

    test('the commitment verifies only its own public key', () async {
      final a = await NearbyHandshake.start();
      final b = await NearbyHandshake.start();
      expect(
        await NearbyHandshake.verifyCommitment(a.commitment, a.publicKey),
        isTrue,
      );
      expect(
        await NearbyHandshake.verifyCommitment(a.commitment, b.publicKey),
        isFalse,
      );
    });

    test('a public key of the wrong length is rejected', () async {
      final a = await NearbyHandshake.start();
      expect(
        () => a.complete(Uint8List(31), isInitiator: true),
        throwsA(isA<NearbyAuthFailure>()),
      );
    });

    test('both sides derive the same pair secret', () async {
      final (initiator, responder) = await _pair();
      final x = await initiator.pairSecret();
      final y = await responder.pairSecret();
      expect(x, hasLength(32));
      expect(x, y);
    });
  });

  group('NearbySessionCipher', () {
    test('seal and open round-trip in both directions, in order', () async {
      final (i, r) = await _pair();
      final iCipher = await i.sessionCipher();
      final rCipher = await r.sessionCipher();
      for (var n = 0; n < 3; n++) {
        final box = await iCipher.seal(_utf8('to responder $n'));
        expect(utf8.decode(await rCipher.open(box)), 'to responder $n');
        final back = await rCipher.seal(_utf8('to initiator $n'));
        expect(utf8.decode(await iCipher.open(back)), 'to initiator $n');
      }
    });

    test('open fails on a flipped byte', () async {
      final (i, r) = await _pair();
      final iCipher = await i.sessionCipher();
      final rCipher = await r.sessionCipher();
      final box = await iCipher.seal(_utf8('hello'));
      box[0] ^= 0x01;
      expect(() => rCipher.open(box), throwsA(isA<NearbyAuthFailure>()));
    });

    test('a replayed box fails because the counter moved on', () async {
      final (i, r) = await _pair();
      final iCipher = await i.sessionCipher();
      final rCipher = await r.sessionCipher();
      final box = await iCipher.seal(_utf8('once'));
      await rCipher.open(Uint8List.fromList(box));
      expect(() => rCipher.open(box), throwsA(isA<NearbyAuthFailure>()));
    });

    test(
      'a box sealed by the opener itself does not open (direction)',
      () async {
        final (i, _) = await _pair();
        final iCipher = await i.sessionCipher();
        final iCipher2 = await i.sessionCipher();
        final box = await iCipher.seal(_utf8('loop'));
        expect(() => iCipher2.open(box), throwsA(isA<NearbyAuthFailure>()));
      },
    );

    test('paired and unpaired session keys differ', () async {
      final (i, r) = await _pair();
      final secret = await i.pairSecret();
      final paired = await i.sessionCipher(pairSecret: secret);
      final unpaired = await r.sessionCipher();
      final box = await paired.seal(_utf8('x'));
      expect(() => unpaired.open(box), throwsA(isA<NearbyAuthFailure>()));
    });

    test('both sides holding the pair secret can talk', () async {
      final (i, r) = await _pair();
      final secret = await i.pairSecret();
      final a = await i.sessionCipher(pairSecret: secret);
      final b = await r.sessionCipher(pairSecret: secret);
      expect(utf8.decode(await b.open(await a.seal(_utf8('ok')))), 'ok');
    });
  });
}
