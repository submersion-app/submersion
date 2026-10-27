import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_frame.dart';
import 'package:submersion/core/services/nearby/nearby_hello.dart';
import 'package:submersion/core/services/nearby/nearby_session.dart';

import '../../../support/in_memory_nearby_carrier.dart';

class _MemorySecrets implements NearbyPairSecrets {
  final map = <String, Uint8List>{};

  @override
  Future<Uint8List?> secretFor(String peerDeviceId) async => map[peerDeviceId];

  @override
  Future<void> store(String peerDeviceId, Uint8List secret) async =>
      map[peerDeviceId] = secret;

  @override
  Future<void> remove(String peerDeviceId) async => map.remove(peerDeviceId);
}

NearbyIdentity _identity(
  String id, {
  String? epoch = 'epoch-1',
  bool hasDives = true,
  int schema = 319,
}) => NearbyIdentity(
  deviceId: id,
  deviceName: 'Device $id',
  appVersion: '1.8.4',
  schemaVersion: schema,
  epochId: epoch,
  hasDives: hasDives,
);

/// Opens a link from 'laptop' (initiator) to 'phone' (responder).
Future<(NearbyEndpoint, NearbyEndpoint)> _link() async {
  final hub = InMemoryNearbyHub();
  final phone = hub.join('phone');
  final laptop = hub.join('laptop');
  await phone.startAdvertising();
  final incoming = phone.incoming.first;
  final out = await laptop.connect('phone');
  return (out, await incoming);
}

Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group('pairing', () {
    test(
      'both sides show the same code and confirm stores one secret each',
      () async {
        final (out, into) = await _link();
        final laptopSecrets = _MemorySecrets();
        final phoneSecrets = _MemorySecrets();
        final laptop = NearbySession(
          endpoint: out,
          identity: _identity('L'),
          secrets: laptopSecrets,
        );
        final phone = NearbySession(
          endpoint: into,
          identity: _identity('P'),
          secrets: phoneSecrets,
        );

        final incoming = phone.accept(allowPairing: true);
        final outgoing = await laptop.openPairing();
        final accepted = await incoming as NearbyIncomingPairing;

        expect(outgoing.code, accepted.pairing.code);
        expect(outgoing.peer.deviceId, 'P');
        expect(accepted.pairing.peer.deviceId, 'L');

        final channels = await Future.wait([
          outgoing.confirm(),
          accepted.pairing.confirm(),
        ]);
        expect(laptopSecrets.map['P'], isNotNull);
        expect(laptopSecrets.map['P'], phoneSecrets.map['L']);

        // The channel after pairing is keyed with the stored secret.
        final got = channels[1].messages.first;
        await channels[0].send(NearbyMessageType.watermarks, _utf8('{}'));
        expect(utf8.decode((await got).body), '{}');
      },
    );

    test('reject on one side fails the other and stores nothing', () async {
      final (out, into) = await _link();
      final laptopSecrets = _MemorySecrets();
      final phoneSecrets = _MemorySecrets();
      final incoming = NearbySession(
        endpoint: into,
        identity: _identity('P'),
        secrets: phoneSecrets,
      ).accept(allowPairing: true);
      final outgoing = await NearbySession(
        endpoint: out,
        identity: _identity('L'),
        secrets: laptopSecrets,
      ).openPairing();
      final accepted = await incoming as NearbyIncomingPairing;

      final confirm = outgoing.confirm();
      await accepted.pairing.reject();
      await expectLater(confirm, throwsA(isA<NearbyPairingRejected>()));
      expect(laptopSecrets.map, isEmpty);
      expect(phoneSecrets.map, isEmpty);
    });

    test('a responder not in pairing mode refuses a pairing', () async {
      final (out, into) = await _link();
      final incoming = NearbySession(
        endpoint: into,
        identity: _identity('P'),
        secrets: _MemorySecrets(),
      ).accept(allowPairing: false);
      final outgoing = NearbySession(
        endpoint: out,
        identity: _identity('L'),
        secrets: _MemorySecrets(),
      ).openPairing();
      await Future.wait([
        expectLater(
          outgoing,
          throwsA(
            isA<NearbySessionRefused>()
                .having((e) => e.code, 'code', NearbyErrorCode.notPaired)
                .having((e) => e.fromPeer, 'fromPeer', isTrue),
          ),
        ),
        expectLater(incoming, throwsA(isA<NearbySessionRefused>())),
      ]);
    });

    test('bothPopulated is true only when both hellos carry dives', () async {
      for (final (laptopDives, phoneDives, expected) in [
        (true, true, true),
        (true, false, false),
        (false, false, false),
      ]) {
        final (out, into) = await _link();
        final incoming = NearbySession(
          endpoint: into,
          identity: _identity('P', hasDives: phoneDives),
          secrets: _MemorySecrets(),
        ).accept(allowPairing: true);
        final outgoing = await NearbySession(
          endpoint: out,
          identity: _identity('L', hasDives: laptopDives),
          secrets: _MemorySecrets(),
        ).openPairing();
        final accepted = await incoming as NearbyIncomingPairing;
        expect(outgoing.bothPopulated, expected);
        expect(accepted.pairing.bothPopulated, expected);
        await outgoing.reject();
      }
    });
  });

  group('sync', () {
    /// Pairs L and P and returns their secret stores.
    Future<(_MemorySecrets, _MemorySecrets)> paired() async {
      final (out, into) = await _link();
      final l = _MemorySecrets();
      final p = _MemorySecrets();
      final incoming = NearbySession(
        endpoint: into,
        identity: _identity('P'),
        secrets: p,
      ).accept(allowPairing: true);
      final outgoing = await NearbySession(
        endpoint: out,
        identity: _identity('L'),
        secrets: l,
      ).openPairing();
      final accepted = await incoming as NearbyIncomingPairing;
      await Future.wait([outgoing.confirm(), accepted.pairing.confirm()]);
      return (l, p);
    }

    test(
      'stored secrets yield encrypted channels that exchange a message',
      () async {
        final (l, p) = await paired();
        final (out, into) = await _link();
        final incoming = NearbySession(
          endpoint: into,
          identity: _identity('P'),
          secrets: p,
        ).accept(allowPairing: false);
        final laptop = await NearbySession(
          endpoint: out,
          identity: _identity('L'),
          secrets: l,
        ).openSync();
        final phone = (await incoming as NearbyIncomingSync).channel;
        expect(laptop.peer.deviceId, 'P');
        expect(phone.peer.deviceId, 'L');
        expect(laptop.isInitiator, isTrue);
        expect(phone.isInitiator, isFalse);

        final got = laptop.messages.first;
        await phone.send(NearbyMessageType.applied, _utf8('done'));
        final message = await got;
        expect(message.type, NearbyMessageType.applied);
        expect(utf8.decode(message.body), 'done');
      },
    );

    test('a peer that removed its secret refuses with notPaired', () async {
      final (l, p) = await paired();
      await p.remove('L');
      final (out, into) = await _link();
      final incoming = NearbySession(
        endpoint: into,
        identity: _identity('P'),
        secrets: p,
      ).accept(allowPairing: false);
      await Future.wait([
        expectLater(
          NearbySession(
            endpoint: out,
            identity: _identity('L'),
            secrets: l,
          ).openSync(),
          throwsA(
            isA<NearbySessionRefused>()
                .having((e) => e.code, 'code', NearbyErrorCode.notPaired)
                .having((e) => e.fromPeer, 'fromPeer', isTrue),
          ),
        ),
        expectLater(incoming, throwsA(isA<NearbySessionRefused>())),
      ]);
    });

    test('mismatched secrets fail the key check with notPaired', () async {
      final (l, p) = await paired();
      p.map['L'] = Uint8List(32); // re-paired elsewhere, different secret
      final (out, into) = await _link();
      final incoming = NearbySession(
        endpoint: into,
        identity: _identity('P'),
        secrets: p,
      ).accept(allowPairing: false);
      await Future.wait([
        expectLater(
          NearbySession(
            endpoint: out,
            identity: _identity('L'),
            secrets: l,
          ).openSync(),
          throwsA(
            isA<NearbySessionRefused>().having(
              (e) => e.code,
              'code',
              NearbyErrorCode.notPaired,
            ),
          ),
        ),
        expectLater(incoming, throwsA(isA<NearbySessionRefused>())),
      ]);
    });

    test('different non-null epochs refuse with differentLibrary', () async {
      final (out, into) = await _link();
      final incoming = NearbySession(
        endpoint: into,
        identity: _identity('P', epoch: 'other'),
        secrets: _MemorySecrets(),
      ).accept(allowPairing: true);
      await Future.wait([
        expectLater(
          NearbySession(
            endpoint: out,
            identity: _identity('L'),
            secrets: _MemorySecrets(),
          ).openPairing(),
          throwsA(
            isA<NearbySessionRefused>().having(
              (e) => e.code,
              'code',
              NearbyErrorCode.differentLibrary,
            ),
          ),
        ),
        expectLater(incoming, throwsA(isA<NearbySessionRefused>())),
      ]);
    });

    test('a null epoch on one side is not a refusal', () async {
      final (out, into) = await _link();
      final incoming = NearbySession(
        endpoint: into,
        identity: _identity('P', epoch: null),
        secrets: _MemorySecrets(),
      ).accept(allowPairing: true);
      final outgoing = await NearbySession(
        endpoint: out,
        identity: _identity('L'),
        secrets: _MemorySecrets(),
      ).openPairing();
      expect(
        (await incoming as NearbyIncomingPairing).pairing.peer.epochId,
        'epoch-1',
      );
      expect(outgoing.peer.epochId, isNull);
      await outgoing.reject();
    });

    test('a newer protocol version refuses with newerApp', () async {
      final (out, into) = await _link();
      final incoming = NearbySession(
        endpoint: into,
        identity: _identity('P'),
        secrets: _MemorySecrets(),
      ).accept(allowPairing: true);
      final hello = NearbyHello(
        protocolVersion: NearbyHello.currentProtocolVersion + 1,
        deviceId: 'L',
        deviceName: 'Future',
        appVersion: '9.0.0',
        schemaVersion: 999,
        epochId: null,
        hasDives: false,
        intent: NearbyIntent.pair,
        commitment: Uint8List(32),
      );
      final replies = <NearbyMessage>[];
      final decoder = FrameDecoder();
      out.inbound.listen(decoder.add);
      decoder.messages.listen(replies.add);
      await out.send(
        FrameEncoder.encode(
          NearbyMessageType.hello,
          Uint8List.fromList(utf8.encode(jsonEncode(hello.toJson()))),
        ),
      );
      await expectLater(
        incoming,
        throwsA(
          isA<NearbySessionRefused>()
              .having((e) => e.code, 'code', NearbyErrorCode.newerApp)
              .having((e) => e.fromPeer, 'fromPeer', isFalse),
        ),
      );
      await pumpEventQueue();
      expect(replies.first.type, NearbyMessageType.error);
      expect(replies.first.body, [NearbyErrorCode.newerApp.index]);
    });

    test('a forged initiator key fails the commitment check', () async {
      final (out, into) = await _link();
      final incoming = NearbySession(
        endpoint: into,
        identity: _identity('P'),
        secrets: _MemorySecrets(),
      ).accept(allowPairing: true);
      // Commit to one key, then reveal another.
      final hello = NearbyHello(
        protocolVersion: NearbyHello.currentProtocolVersion,
        deviceId: 'L',
        deviceName: 'Mallory',
        appVersion: '1.8.4',
        schemaVersion: 319,
        epochId: null,
        hasDives: false,
        intent: NearbyIntent.pair,
        commitment: Uint8List(32),
      );
      await out.send(
        FrameEncoder.encode(
          NearbyMessageType.hello,
          Uint8List.fromList(utf8.encode(jsonEncode(hello.toJson()))),
        ),
      );
      await out.send(
        FrameEncoder.encode(NearbyMessageType.helloReveal, Uint8List(32)),
      );
      await expectLater(
        incoming,
        throwsA(
          isA<NearbySessionRefused>().having(
            (e) => e.code,
            'code',
            NearbyErrorCode.protocol,
          ),
        ),
      );
    });

    test('no hello within helloTimeout throws NearbyHelloTimeout', () {
      fakeAsync((async) {
        late NearbyEndpoint into;
        _link().then((pair) => into = pair.$2);
        async.flushMicrotasks();
        Object? error;
        NearbySession(
              endpoint: into,
              identity: _identity('P'),
              secrets: _MemorySecrets(),
              helloTimeout: const Duration(seconds: 10),
            )
            .accept(allowPairing: true)
            .then(
              (_) {},
              onError: (Object e) {
                error = e;
              },
            );
        async.elapse(const Duration(seconds: 9));
        expect(error, isNull);
        async.elapse(const Duration(seconds: 2));
        expect(error, isA<NearbyHelloTimeout>());
      });
    });
  });
}
