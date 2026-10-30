import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/core/services/sync/changeset_log/tombstone_horizon.dart';

void main() {
  const now = 1000000000000;
  const month = 30 * 24 * 60 * 60 * 1000;

  SyncManifest peer(
    String id, {
    int ageMillis = 0,
    Map<String, String> applied = const {},
  }) => SyncManifest(
    deviceId: id,
    provider: 'fake',
    headSeq: 1,
    updatedAt: now - ageMillis,
    appliedPeerHlc: applied,
  );

  test('no live peers: GC unbounded', () {
    final d = TombstoneHorizon.compute(
      selfDeviceId: 'self',
      peerManifests: const [],
      retiredPeerIds: const {},
    );
    expect(d.allowed, isTrue);
    expect(d.upToHlc, isNull);
  });

  test('live peer without an ack entry blocks GC', () {
    final d = TombstoneHorizon.compute(
      selfDeviceId: 'self',
      peerManifests: [peer('p1')],
      retiredPeerIds: const {},
    );
    expect(d.allowed, isFalse);
  });

  test('horizon is the minimum ack across live peers', () {
    final d = TombstoneHorizon.compute(
      selfDeviceId: 'self',
      peerManifests: [
        peer('p1', applied: {'self': '00000000000020:000000:x'}),
        peer('p2', applied: {'self': '00000000000010:000000:x'}),
      ],
      retiredPeerIds: const {},
    );
    expect(d.allowed, isTrue);
    expect(d.upToHlc, '00000000000010:000000:x');
  });

  test('retired (marker-durable) peers do not count', () {
    final d = TombstoneHorizon.compute(
      selfDeviceId: 'self',
      peerManifests: [
        peer('gone', ageMillis: 13 * month), // retired below
        peer('live', applied: {'self': '00000000000030:000000:x'}),
      ],
      retiredPeerIds: const {'gone'},
    );
    expect(d.allowed, isTrue);
    expect(d.upToHlc, '00000000000030:000000:x');
  });

  test('a stale peer WITHOUT a durable marker still blocks GC', () {
    // Age alone must never remove a peer from the constraint set: if the
    // retirement sweep failed to write the marker, the peer is unfenced and
    // could later rejoin holding rows whose tombstones we would have GC'd.
    final d = TombstoneHorizon.compute(
      selfDeviceId: 'self',
      peerManifests: [
        peer('stale-unfenced', ageMillis: 13 * month),
        peer('live', applied: {'self': '00000000000030:000000:x'}),
      ],
      retiredPeerIds: const {},
    );
    expect(d.allowed, isFalse);
  });

  test('a stale unmarked peer WITH an ack constrains the horizon', () {
    final d = TombstoneHorizon.compute(
      selfDeviceId: 'self',
      peerManifests: [
        peer(
          'stale-acked',
          ageMillis: 13 * month,
          applied: {'self': '00000000000005:000000:x'},
        ),
        peer('live', applied: {'self': '00000000000030:000000:x'}),
      ],
      retiredPeerIds: const {},
    );
    expect(d.allowed, isTrue);
    expect(d.upToHlc, '00000000000005:000000:x');
  });

  test('own manifest is ignored', () {
    final d = TombstoneHorizon.compute(
      selfDeviceId: 'self',
      peerManifests: [peer('self')],
      retiredPeerIds: const {},
    );
    expect(d.allowed, isTrue);
    expect(d.upToHlc, isNull);
  });

  group('nearby peers (issue #3731)', () {
    const year = 365 * 24 * 60 * 60 * 1000;

    NearbyTombstoneAck ack(String id, String? hlc, {int ageMillis = 0}) =>
        NearbyTombstoneAck(
          deviceId: id,
          ackedHlc: hlc,
          lastSeenAt: now - ageMillis,
        );

    test('a nearby peer with an older ack lowers the horizon', () {
      final d = TombstoneHorizon.compute(
        selfDeviceId: 'self',
        peerManifests: [
          peer('p1', applied: const {'self': '000000000000500:000000:self'}),
        ],
        retiredPeerIds: const {},
        nearbyPeers: [ack('n1', '000000000000300:000000:self')],
        nowMillis: now,
      );
      expect(d.allowed, isTrue);
      expect(d.upToHlc, '000000000000300:000000:self');
    });

    test('a nearby peer alone bounds the horizon', () {
      final d = TombstoneHorizon.compute(
        selfDeviceId: 'self',
        peerManifests: const [],
        retiredPeerIds: const {},
        nearbyPeers: [ack('n1', '000000000000300:000000:self')],
        nowMillis: now,
      );
      expect(d.upToHlc, '000000000000300:000000:self');
    });

    test('a nearby peer that never acked blocks GC', () {
      final d = TombstoneHorizon.compute(
        selfDeviceId: 'self',
        peerManifests: const [],
        retiredPeerIds: const {},
        nearbyPeers: [ack('n1', null)],
        nowMillis: now,
      );
      expect(d.allowed, isFalse);
    });

    test('a nearby peer silent past the retirement period is ignored', () {
      final d = TombstoneHorizon.compute(
        selfDeviceId: 'self',
        peerManifests: const [],
        retiredPeerIds: const {},
        nearbyPeers: [
          ack('n1', null, ageMillis: year + month),
          ack('n2', '000000000000700:000000:self'),
        ],
        nowMillis: now,
      );
      expect(d.allowed, isTrue);
      expect(d.upToHlc, '000000000000700:000000:self');
    });
  });
}
