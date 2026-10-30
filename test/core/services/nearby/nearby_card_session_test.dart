import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_frame.dart';
import 'package:submersion/core/services/nearby/nearby_hello.dart';
import 'package:submersion/core/services/nearby/nearby_session.dart';

import '../../../support/memory_nearby_secrets.dart';
import '../../../support/nearby_session_harness.dart';

/// The buddy card session (issue #3728): an unpaired, encrypted exchange
/// between two strangers' phones, accepted only while the swap screen is
/// open.
void main() {
  NearbySession session(endpoint, String id) => NearbySession(
    endpoint: endpoint,
    identity: nearbySessionIdentity(id),
    secrets: MemoryNearbySecrets(),
  );

  Future<List<NearbyMessage>> framesOf(List<int> bytes) async {
    final out = <NearbyMessage>[];
    final decoder = FrameDecoder()..messages.listen(out.add);
    decoder.add(Uint8List.fromList(bytes));
    await pumpEventQueue();
    return out;
  }

  test(
    'opens with allowCard and exchanges sealed messages both ways',
    () async {
      final (out, into) = await nearbyLink();
      final incoming = session(
        into,
        'P',
      ).accept(allowPairing: false, allowCard: true);
      final mine = await session(out, 'L').openCard();
      final theirs = (await incoming as NearbyIncomingCard).channel;

      final toPhone = theirs.messages.first;
      await mine.send(
        NearbyMessageType.cardSummary,
        Uint8List.fromList([1, 2]),
      );
      expect((await toPhone).body, [1, 2]);
      expect((await toPhone).type, NearbyMessageType.cardSummary);

      final toLaptop = mine.messages.first;
      await theirs.send(NearbyMessageType.card, Uint8List.fromList([3]));
      expect((await toLaptop).body, [3]);
      expect(mine.isInitiator, isTrue);
      expect(theirs.isInitiator, isFalse);
    },
  );

  test('card hellos carry version 2, sync and pair hellos version 1', () async {
    expect(NearbyHello.cardProtocolVersion, 2);
    expect(NearbyHello.currentProtocolVersion, 1);
    expect(NearbyHello.maxProtocolVersion, 2);

    final (out, into) = await nearbyLink();
    final laptopEnd = RecordingNearbyEndpoint(out);
    final incoming = session(
      into,
      'P',
    ).accept(allowPairing: false, allowCard: true);
    await session(laptopEnd, 'L').openCard();
    await incoming;
    final hello = (await framesOf(laptopEnd.sent)).first;
    expect(hello.type, NearbyMessageType.hello);
    expect(NearbyHello.versionOf(hello.body), 2);
  });

  test('responder without allowCard refuses with notSwapping', () async {
    final (out, into) = await nearbyLink();
    final incoming = session(into, 'P').accept(allowPairing: true);
    final opening = session(out, 'L').openCard();
    await expectLater(
      incoming,
      throwsA(
        isA<NearbySessionRefused>().having(
          (e) => e.code,
          'code',
          NearbyErrorCode.notSwapping,
        ),
      ),
    );
    await expectLater(
      opening,
      throwsA(
        isA<NearbySessionRefused>()
            .having((e) => e.code, 'code', NearbyErrorCode.notSwapping)
            .having((e) => e.fromPeer, 'fromPeer', isTrue),
      ),
    );
  });

  test('an older build reads notSwapping as a protocol refusal', () {
    // Appended, never inserted: older builds map unknown bytes to protocol.
    expect(
      NearbyErrorCode.notSwapping.index,
      NearbyErrorCode.values.length - 1,
    );
    expect(
      NearbyErrorCode.fromByte(NearbyErrorCode.values.length),
      NearbyErrorCode.protocol,
    );
  });

  test('a card session needs no pair secret and sends no identity', () async {
    final (out, into) = await nearbyLink();
    final laptopEnd = RecordingNearbyEndpoint(out);
    final phoneEnd = RecordingNearbyEndpoint(into);
    final incoming = session(
      phoneEnd,
      'P',
    ).accept(allowPairing: false, allowCard: true);
    await session(laptopEnd, 'L').openCard();
    await incoming;
    final types = [
      ...await framesOf(laptopEnd.sent),
      ...await framesOf(phoneEnd.sent),
    ].map((m) => m.type);
    // The handshake did run: hellos and key checks went both ways.
    expect(types, contains(NearbyMessageType.keyCheck));
    expect(types, isNot(contains(NearbyMessageType.identity)));
  });

  test('an unsealed error after the key check is not believed', () async {
    final (out, into) = await nearbyLink();
    final incoming = session(
      into,
      'P',
    ).accept(allowPairing: false, allowCard: true);
    await session(out, 'L').openCard();
    final phone = (await incoming as NearbyIncomingCard).channel;
    final first = phone.messages.first;
    await out.send(
      FrameEncoder.encode(
        NearbyMessageType.error,
        Uint8List.fromList([NearbyErrorCode.busy.index]),
      ),
    );
    await expectLater(first, throwsA(isA<Object>()));
  });

  test(
    'a sync hello still opens a paired sync while card mode is on',
    () async {
      final (l, p) = await pairNearbySessions();
      final (out, into) = await nearbyLink();
      final incoming = NearbySession(
        endpoint: into,
        identity: nearbySessionIdentity('P'),
        secrets: p,
      ).accept(allowPairing: false, allowCard: true);
      await NearbySession(
        endpoint: out,
        identity: nearbySessionIdentity('L'),
        secrets: l,
      ).openSync();
      expect(await incoming, isA<NearbyIncomingSync>());
      expect(utf8.decode(const []), '');
    },
  );
}
