import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_frame.dart';
import 'package:submersion/core/services/nearby/nearby_hello.dart';
import 'package:submersion/core/services/nearby/nearby_session.dart';

import '../../../support/forwarding_nearby_endpoint.dart';
import '../../../support/memory_nearby_secrets.dart';
import '../../../support/nearby_session_harness.dart';

/// Passes everything through until [stalled], then never finishes a send:
/// a peripheral whose central stopped reading a full outbox.
class _StallingEndpoint extends ForwardingNearbyEndpoint {
  _StallingEndpoint(super.inner);

  bool stalled = false;
  bool closed = false;

  @override
  Future<void> send(Uint8List bytes) =>
      stalled ? Completer<void>().future : super.send(bytes);

  @override
  Future<void> close() {
    closed = true;
    return super.close();
  }
}

/// Slips a bare frame of its own onto the link just before the peer's
/// [at]th frame: someone in range writing to it.
class _InjectingEndpoint extends ForwardingNearbyEndpoint {
  _InjectingEndpoint(super.inner, {required this.at, required this.frame});

  final int at;
  final Uint8List frame;
  var _sent = 0;

  @override
  Future<void> send(Uint8List bytes) async {
    if (++_sent == at) await super.send(frame);
    return super.send(bytes);
  }
}

/// Refusals that must name the peer, frames that must not be believed, and
/// a link that must still close (issue #3731).
void main() {
  test('a paired peer on another library is refused naming the peer, on '
      'both sides', () async {
    final (l, p) = await pairNearbySessions();
    final (out, into) = await nearbyLink();
    final incoming = NearbySession(
      endpoint: into,
      identity: nearbySessionIdentity('P', epoch: 'other'),
      secrets: p,
    ).accept(allowPairing: false);
    final outgoing = NearbySession(
      endpoint: out,
      identity: nearbySessionIdentity('L'),
      secrets: l,
    ).openSync();

    Matcher refusedNaming(String id) => throwsA(
      isA<NearbySessionRefused>()
          .having((e) => e.code, 'code', NearbyErrorCode.differentLibrary)
          .having((e) => e.peerDeviceId, 'peerDeviceId', id),
    );
    await Future.wait([
      expectLater(outgoing, refusedNaming('P')),
      expectLater(incoming, refusedNaming('L')),
    ]);
  });

  test(
    'a bare refusal that arrives after the key check is not believed',
    () async {
      final (l, p) = await pairNearbySessions();
      final (out, into) = await nearbyLink();
      // After P's hello and key check, where its identity should come.
      final forged = _InjectingEndpoint(
        into,
        at: 3,
        frame: FrameEncoder.encode(
          NearbyMessageType.error,
          Uint8List.fromList([NearbyErrorCode.differentLibrary.index]),
        ),
      );
      final incoming = NearbySession(
        endpoint: forged,
        identity: nearbySessionIdentity('P'),
        secrets: p,
      ).accept(allowPairing: false);
      final outgoing = NearbySession(
        endpoint: out,
        identity: nearbySessionIdentity('L'),
        secrets: l,
      ).openSync();
      unawaited(incoming.then<void>((_) {}, onError: (Object _) {}));

      await expectLater(
        outgoing,
        throwsA(
          isA<NearbySessionRefused>()
              .having((e) => e.code, 'code', NearbyErrorCode.protocol)
              .having((e) => e.fromPeer, 'fromPeer', isFalse),
        ),
      );
    },
  );

  test('a bye sent in the clear while waiting for the other diver is not '
      'read as their "Not mine"', () async {
    final (out, into) = await nearbyLink();
    final incoming = NearbySession(
      endpoint: into,
      identity: nearbySessionIdentity('P'),
      secrets: MemoryNearbySecrets(),
    ).accept(allowPairing: true);
    final outgoing = await NearbySession(
      endpoint: out,
      identity: nearbySessionIdentity('L'),
      secrets: MemoryNearbySecrets(),
    ).openPairing();
    await incoming;

    final confirm = outgoing.confirm();
    await into.send(FrameEncoder.encode(NearbyMessageType.bye, Uint8List(0)));
    // Not sealed, so a protocol violation: never the diver's answer.
    await expectLater(
      confirm,
      throwsA(
        isA<NearbySessionRefused>()
            .having((e) => e.code, 'code', NearbyErrorCode.protocol)
            .having((e) => e.fromPeer, 'fromPeer', isFalse),
      ),
    );
  });

  test('a newer hello this build cannot parse is still refused as newer, so '
      'the peer shows who needs the update', () async {
    final (out, into) = await nearbyLink();
    final incoming = NearbySession(
      endpoint: into,
      identity: nearbySessionIdentity('P'),
      secrets: MemoryNearbySecrets(),
    ).accept(allowPairing: true);
    final replies = <NearbyMessage>[];
    final decoder = FrameDecoder();
    out.inbound.listen(decoder.add);
    decoder.messages.listen(replies.add);
    // A later build's hello, with an intent this one has never heard of.
    await out.send(
      FrameEncoder.encode(
        NearbyMessageType.hello,
        Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'v': NearbyHello.maxProtocolVersion + 1,
              'intent': 'swapCards',
              'commit': base64Encode(Uint8List(32)),
            }),
          ),
        ),
      ),
    );
    await expectLater(
      incoming,
      throwsA(
        isA<NearbySessionRefused>().having(
          (e) => e.code,
          'code',
          NearbyErrorCode.newerApp,
        ),
      ),
    );
    await pumpEventQueue();
    expect(replies.first.type, NearbyMessageType.error);
    expect(replies.first.body, [NearbyErrorCode.newerApp.index]);
  });

  test('a sync hello above the sync version is refused as newer, though '
      'card hellos go higher', () async {
    final (out, into) = await nearbyLink();
    final incoming = NearbySession(
      endpoint: into,
      identity: nearbySessionIdentity('P'),
      secrets: MemoryNearbySecrets(),
    ).accept(allowPairing: true, allowCard: true);
    await out.send(
      FrameEncoder.encode(
        NearbyMessageType.hello,
        NearbyHello(
          protocolVersion: NearbyHello.currentProtocolVersion + 1,
          intent: NearbyIntent.sync,
          commitment: Uint8List(32),
        ).toBytes(),
      ),
    );
    await expectLater(
      incoming,
      throwsA(
        isA<NearbySessionRefused>().having(
          (e) => e.code,
          'code',
          NearbyErrorCode.newerApp,
        ),
      ),
    );
  });

  test('closing a channel whose link has stalled hangs up without waiting '
      'for the bye', () async {
    final (l, p) = await pairNearbySessions();
    final (out, into) = await nearbyLink();
    final stalling = _StallingEndpoint(out);
    final incoming = NearbySession(
      endpoint: into,
      identity: nearbySessionIdentity('P'),
      secrets: p,
    ).accept(allowPairing: false);
    final laptop = await NearbySession(
      endpoint: stalling,
      identity: nearbySessionIdentity('L'),
      secrets: l,
    ).openSync();
    await incoming;

    stalling.stalled = true; // the other side stops taking bytes
    await laptop.close().timeout(const Duration(seconds: 5));
    expect(stalling.closed, isTrue);
  });
}
