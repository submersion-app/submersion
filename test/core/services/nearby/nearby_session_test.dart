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

  @override
  Future<Map<String, Uint8List>> all() async => Map.of(map);
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
  schemaFloor: 308,
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

/// Passes everything through and keeps a copy of what this side sent.
class _Recording implements NearbyEndpoint {
  _Recording(this._inner);

  final NearbyEndpoint _inner;
  final sent = <int>[];

  @override
  Stream<Uint8List> get inbound => _inner.inbound;

  @override
  Future<void> send(Uint8List bytes) {
    sent.addAll(bytes);
    return _inner.send(bytes);
  }

  @override
  Future<void> close() => _inner.close();

  @override
  bool get isInitiator => _inner.isInitiator;

  @override
  String get transportId => _inner.transportId;
}

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

    test('a stranger learns nothing about the device it connects to', () async {
      final (out, into) = await _link();
      final phoneEnd = _Recording(into);
      final stranger = NearbySession(
        endpoint: out,
        identity: _identity('stranger-device-0000'),
        secrets: _MemorySecrets()..map['someone-else'] = Uint8List(32),
      ).openSync();
      final incoming = NearbySession(
        endpoint: phoneEnd,
        identity: _identity('phone-device-1234', epoch: 'library-epoch-5678'),
        secrets: _MemorySecrets()..map['laptop-device-9999'] = Uint8List(32),
      ).accept(allowPairing: false);
      await Future.wait([
        expectLater(stranger, throwsA(isA<NearbySessionRefused>())),
        expectLater(incoming, throwsA(isA<NearbySessionRefused>())),
      ]);
      final text = latin1.decode(phoneEnd.sent);
      expect(text, isNot(contains('phone-device-1234')));
      expect(text, isNot(contains('Device phone')));
      expect(text, isNot(contains('library-epoch-5678')));
    });

    test('the plaintext sync hello names neither device', () async {
      final (l, p) = await paired();
      final (out, into) = await _link();
      final laptopEnd = _Recording(out);
      final incoming = NearbySession(
        endpoint: into,
        identity: _identity('P'),
        secrets: p,
      ).accept(allowPairing: false);
      final channel = await NearbySession(
        endpoint: laptopEnd,
        identity: _identity('L'),
        secrets: l,
      ).openSync();
      expect(channel.peer.deviceId, 'P');
      expect(
        ((await incoming) as NearbyIncomingSync).channel.peer.deviceId,
        'L',
      );
      // The first frame is the plaintext hello.
      final helloLength = ByteData.sublistView(
        Uint8List.fromList(laptopEnd.sent),
      ).getUint32(0);
      final hello = latin1.decode(laptopEnd.sent.sublist(5, 4 + helloLength));
      expect(hello, contains('tags'));
      expect(hello, isNot(contains('Device L')));
      expect(hello, isNot(contains('epoch-1')));
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
