import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_frame.dart';
import 'package:submersion/core/services/nearby/nearby_session.dart';

import '../../../support/forwarding_nearby_endpoint.dart';
import '../../../support/memory_nearby_secrets.dart';
import '../../../support/nearby_session_harness.dart';

/// Loses this side's full identity, the second identity frame it sends
/// (the first is the pairing preview). With [failSend] the send throws, as
/// a write on a dropped link does; otherwise the bytes simply never arrive,
/// as bytes a Bluetooth peripheral queued and the central never read.
class _LosesIdentity extends ForwardingNearbyEndpoint {
  _LosesIdentity(super.inner, {required this.failSend});

  final bool failSend;
  var _identities = 0;

  @override
  Future<void> send(Uint8List bytes) async {
    final isIdentity =
        bytes.length > 4 && bytes[4] == NearbyMessageType.identity.code;
    if (isIdentity && ++_identities == 2) {
      if (!failSend) return;
      // The peer's identity is already on its way, as it was on the
      // devices: the Mac queued its confirm and identity back to back.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      throw const NearbyLinkClosed();
    }
    return super.send(bytes);
  }
}

const _shortWait = Duration(milliseconds: 300);

/// Opens a pairing from L (initiator) to P (responder), with L's or P's
/// endpoint wrapped by [wrapL] or [wrapP], and confirms it on both.
/// Returns each side's outcome and secret store.
Future<
  ({
    Object? laptopError,
    Object? phoneError,
    MemoryNearbySecrets laptop,
    MemoryNearbySecrets phone,
  })
>
_confirmBoth({
  NearbyEndpoint Function(NearbyEndpoint)? wrapL,
  NearbyEndpoint Function(NearbyEndpoint)? wrapP,
}) async {
  final (out, into) = await nearbyLink();
  final laptop = MemoryNearbySecrets();
  final phone = MemoryNearbySecrets();
  final incoming = NearbySession(
    endpoint: wrapP?.call(into) ?? into,
    identity: nearbySessionIdentity('P'),
    secrets: phone,
    helloTimeout: _shortWait,
  ).accept(allowPairing: true);
  final outgoing = await NearbySession(
    endpoint: wrapL?.call(out) ?? out,
    identity: nearbySessionIdentity('L'),
    secrets: laptop,
    helloTimeout: _shortWait,
  ).openPairing();
  final accepted = await incoming as NearbyIncomingPairing;

  Future<Object?> outcome(Future<NearbyChannel> confirm) async {
    try {
      await confirm;
      return null;
    } on Object catch (e) {
      return e;
    }
  }

  final results = await Future.wait([
    outcome(outgoing.confirm()),
    outcome(accepted.pairing.confirm()),
  ]);
  return (
    laptopError: results[0],
    phoneError: results[1],
    laptop: laptop,
    phone: phone,
  );
}

void main() {
  group('a pairing is kept on both devices or on neither (issue #4154)', () {
    test('a device whose identity could not be sent does not keep the '
        'pairing', () async {
      final r = await _confirmBoth(
        wrapL: (e) => _LosesIdentity(e, failSend: true),
      );
      expect(r.laptopError, isA<NearbyLinkClosed>());
      expect(r.phoneError, isNotNull);
      expect(r.laptop.map, isEmpty);
      expect(r.phone.map, isEmpty);
    });

    test('a device whose identity never reached the other does not keep '
        'the pairing', () async {
      final r = await _confirmBoth(
        wrapP: (e) => _LosesIdentity(e, failSend: false),
      );
      // The laptop meets P's acknowledgement where P's identity belongs.
      expect(r.laptopError, isA<NearbySessionRefused>());
      expect(r.phoneError, isNotNull);
      expect(r.laptop.map, isEmpty);
      expect(r.phone.map, isEmpty);
    });

    test('with nothing lost both keep the same secret', () async {
      final r = await _confirmBoth();
      expect(r.laptopError, isNull);
      expect(r.phoneError, isNull);
      expect(r.laptop.map['P'], isNotNull);
      expect(r.laptop.map['P'], r.phone.map['L']);
    });
  });
}
