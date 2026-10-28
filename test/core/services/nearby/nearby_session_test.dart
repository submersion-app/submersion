import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_frame.dart';
import 'package:submersion/core/services/nearby/nearby_hello.dart';
import 'package:submersion/core/services/nearby/nearby_session.dart';

import '../../../support/memory_nearby_secrets.dart';
import '../../../support/nearby_session_harness.dart';

NearbyIdentity _identity(
  String id, {
  String? epoch = 'epoch-1',
  bool hasDives = true,
  int schema = 319,
}) =>
    nearbySessionIdentity(id, epoch: epoch, hasDives: hasDives, schema: schema);

Future<(NearbyEndpoint, NearbyEndpoint)> _link() => nearbyLink();

Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

typedef _Recording = RecordingNearbyEndpoint;

void main() {
  group('pairing', () {
    test(
      'both sides show the same code and confirm stores one secret each',
      () async {
        final (out, into) = await _link();
        final laptopSecrets = MemoryNearbySecrets();
        final phoneSecrets = MemoryNearbySecrets();
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
        // Before both divers confirm, each side knows only the other's name.
        expect(outgoing.preview.name, 'Device P');
        expect(accepted.pairing.preview.name, 'Device L');
        expect(outgoing.preview.toJson().keys, {
          'name',
          'dives',
          'epochTag',
          'nonce',
        });

        final channels = await Future.wait([
          outgoing.confirm(),
          accepted.pairing.confirm(),
        ]);
        // After, the full identities, and the secret is keyed by device id.
        expect(channels[0].peer.deviceId, 'P');
        expect(channels[1].peer.deviceId, 'L');
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
      final laptopSecrets = MemoryNearbySecrets();
      final phoneSecrets = MemoryNearbySecrets();
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

    test('a "Not mine" forged in the clear is not believed', () async {
      final (out, into) = await _link();
      final incoming = NearbySession(
        endpoint: into,
        identity: _identity('P'),
        secrets: MemoryNearbySecrets(),
      ).accept(allowPairing: true);
      final outgoing = await NearbySession(
        endpoint: out,
        identity: _identity('L'),
        secrets: MemoryNearbySecrets(),
      ).openPairing();
      await incoming;

      final confirm = outgoing.confirm();
      // A reject without the session key, as if from someone in range.
      await into.send(
        FrameEncoder.encode(NearbyMessageType.pairReject, Uint8List(0)),
      );
      await expectLater(
        confirm,
        throwsA(
          isA<NearbySessionRefused>().having(
            (e) => e.code,
            'code',
            NearbyErrorCode.protocol,
          ),
        ),
      );
    });

    test('a device reporting the same id as this one (a cloned install) is '
        'never paired with it', () async {
      final (out, into) = await _link();
      final laptopSecrets = MemoryNearbySecrets();
      final phoneSecrets = MemoryNearbySecrets();
      final incoming = NearbySession(
        endpoint: into,
        identity: _identity('same'),
        secrets: phoneSecrets,
      ).accept(allowPairing: true);
      final outgoing = await NearbySession(
        endpoint: out,
        identity: _identity('same'),
        secrets: laptopSecrets,
      ).openPairing();
      final accepted = await incoming as NearbyIncomingPairing;

      final results = await Future.wait([
        outgoing.confirm().then<Object?>((c) => c, onError: (Object e) => e),
        accepted.pairing.confirm().then<Object?>(
          (c) => c,
          onError: (Object e) => e,
        ),
      ]);
      expect(results, everyElement(isA<NearbySessionRefused>()));
      expect(laptopSecrets.map, isEmpty);
      expect(phoneSecrets.map, isEmpty);
    });

    test('a responder not in pairing mode refuses a pairing', () async {
      final (out, into) = await _link();
      final incoming = NearbySession(
        endpoint: into,
        identity: _identity('P'),
        secrets: MemoryNearbySecrets(),
      ).accept(allowPairing: false);
      final outgoing = NearbySession(
        endpoint: out,
        identity: _identity('L'),
        secrets: MemoryNearbySecrets(),
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
          secrets: MemoryNearbySecrets(),
        ).accept(allowPairing: true);
        final outgoing = await NearbySession(
          endpoint: out,
          identity: _identity('L', hasDives: laptopDives, epoch: null),
          secrets: MemoryNearbySecrets(),
        ).openPairing();
        final accepted = await incoming as NearbyIncomingPairing;
        expect(outgoing.bothPopulated, expected);
        expect(accepted.pairing.bothPopulated, expected);
        await outgoing.reject();
      }
    });
  });

  group('sync', () {
    Future<(MemoryNearbySecrets, MemoryNearbySecrets)> paired() =>
        pairNearbySessions();

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

    test('a closed channel hands over nothing more, not even frames already '
        'on their way: a replaced or ended session stops at once', () async {
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
      final reader = StreamIterator(phone.messages);

      await laptop.send(NearbyMessageType.basePart, _utf8('part 0'));
      await laptop.send(NearbyMessageType.basePart, _utf8('part 1'));
      await pumpEventQueue();
      await phone.close();
      expect(await reader.moveNext(), isFalse);
    });

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
        secrets: MemoryNearbySecrets(),
      ).accept(allowPairing: true);
      await Future.wait([
        expectLater(
          NearbySession(
            endpoint: out,
            identity: _identity('L'),
            secrets: MemoryNearbySecrets(),
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
        secrets: MemoryNearbySecrets(),
      ).accept(allowPairing: true);
      final outgoing = await NearbySession(
        endpoint: out,
        identity: _identity('L'),
        secrets: MemoryNearbySecrets(),
      ).openPairing();
      expect(
        (await incoming as NearbyIncomingPairing).pairing.code,
        isNotEmpty,
      );
      await outgoing.reject();
    });

    test(
      'the pairing preview carries no device id and no library epoch',
      () async {
        final (out, into) = await _link();
        final incoming = NearbySession(
          endpoint: into,
          identity: _identity('phone-id-1234', epoch: 'library-epoch-9'),
          secrets: MemoryNearbySecrets(),
        ).accept(allowPairing: true);
        final outgoing = await NearbySession(
          endpoint: out,
          identity: _identity('laptop-id', epoch: 'library-epoch-9'),
          secrets: MemoryNearbySecrets(),
        ).openPairing();
        await incoming;
        final preview = jsonEncode(outgoing.preview.toJson());
        // The display name is all it says about the device (this test's
        // names embed the id; a real one is the diver's own name for it).
        expect(outgoing.preview.toJson().keys, isNot(contains('id')));
        expect(preview, isNot(contains('"phone-id-1234"')));
        expect(preview, isNot(contains('library-epoch-9')));
        await outgoing.reject();
      },
    );

    test(
      'two devices on the same library are not told they will merge',
      () async {
        final (out, into) = await _link();
        final incoming = NearbySession(
          endpoint: into,
          identity: _identity('P'),
          secrets: MemoryNearbySecrets(),
        ).accept(allowPairing: true);
        final outgoing = await NearbySession(
          endpoint: out,
          identity: _identity('L'),
          secrets: MemoryNearbySecrets(),
        ).openPairing();
        final accepted = await incoming as NearbyIncomingPairing;
        // Both hold dives, but they are one library already (epoch-1).
        expect(outgoing.bothPopulated, isFalse);
        expect(accepted.pairing.bothPopulated, isFalse);
        await outgoing.reject();
      },
    );

    test('a device that unpaired this one says so, naming itself', () async {
      final (l, p) = await paired();
      await p.revoke('L');
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
                .having((e) => e.fromPeer, 'fromPeer', isTrue)
                .having((e) => e.peerDeviceId, 'peerDeviceId', 'P'),
          ),
        ),
        expectLater(incoming, throwsA(isA<NearbySessionRefused>())),
      ]);
    });

    test('a malformed hello is refused, not left hanging', () async {
      final (out, into) = await _link();
      final incoming = NearbySession(
        endpoint: into,
        identity: _identity('P'),
        secrets: MemoryNearbySecrets(),
      ).accept(allowPairing: true);
      await out.send(
        FrameEncoder.encode(
          NearbyMessageType.hello,
          _utf8('{"v":1,"intent":"sync","commit":"AAAA","tags":[null]}'),
        ),
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

    test('an error frame injected in the clear after the handshake is not '
        'believed', () async {
      final (l, p) = await paired();
      final (out, into) = await _link();
      final laptopEnd = _Recording(out);
      final incoming = NearbySession(
        endpoint: into,
        identity: _identity('P'),
        secrets: p,
      ).accept(allowPairing: false);
      await NearbySession(
        endpoint: laptopEnd,
        identity: _identity('L'),
        secrets: l,
      ).openSync();
      final phone = (await incoming as NearbyIncomingSync).channel;
      final first = phone.messages.first;
      // Someone in range forges a refusal frame without the session key.
      await out.send(
        FrameEncoder.encode(
          NearbyMessageType.error,
          Uint8List.fromList([NearbyErrorCode.differentLibrary.index]),
        ),
      );
      await expectLater(first, throwsA(isA<Object>()));
    });

    test('a newer protocol version refuses with newerApp', () async {
      final (out, into) = await _link();
      final incoming = NearbySession(
        endpoint: into,
        identity: _identity('P'),
        secrets: MemoryNearbySecrets(),
      ).accept(allowPairing: true);
      final hello = NearbyHello(
        protocolVersion: NearbyHello.maxProtocolVersion + 1,
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
        secrets: MemoryNearbySecrets(),
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
        secrets: MemoryNearbySecrets()..map['someone-else'] = Uint8List(32),
      ).openSync();
      final incoming = NearbySession(
        endpoint: phoneEnd,
        identity: _identity('phone-device-1234', epoch: 'library-epoch-5678'),
        secrets: MemoryNearbySecrets()
          ..map['laptop-device-9999'] = Uint8List(32),
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
              secrets: MemoryNearbySecrets(),
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

  test('the hello always carries as many tags, however many devices are '
      'paired', () {
    Uint8List t(int v) => Uint8List(8)..[0] = v;
    final one = NearbySession.paddedTags([t(1)]);
    final three = NearbySession.paddedTags([t(1), t(2), t(3)]);
    expect(one, hasLength(NearbySession.minHelloTags));
    expect(three, hasLength(NearbySession.minHelloTags));
    expect(one.every((x) => x.length == 8), isTrue);
    expect(
      three.where((x) => x[0] == 2 && x.skip(1).every((b) => b == 0)),
      hasLength(1),
    );
    final many = [for (var i = 0; i < 11; i++) t(i)];
    expect(NearbySession.paddedTags(many), hasLength(11));
  });
}
