import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/core/services/sync/peer_sync_snapshot.dart';

SyncManifest _manifest(String deviceId, int updatedAt) => SyncManifest(
  deviceId: deviceId,
  provider: 'test',
  headSeq: 1,
  updatedAt: updatedAt,
);

void main() {
  final now = DateTime(2026, 10, 17, 12);

  PeerSyncSnapshot build({
    List<SyncManifest>? manifests,
    Set<String> fenced = const {},
    Set<String> readFailed = const {},
    Set<String> newerSchema = const {},
    Set<String> incomplete = const {},
    Set<String> unpublished = const {},
    Set<String> skipped = const {},
    int recordsFailed = 0,
    Map<String, DateTime> listedAt = const {},
  }) => buildPeerSyncSnapshot(
    now: now,
    providerId: 'dropbox',
    selfDeviceId: 'self',
    peerManifests: manifests ?? [_manifest('a', 1000)],
    fencedPeerIds: fenced,
    readFailedPeerIds: readFailed,
    newerSchemaPeerIds: newerSchema,
    incompletePeerIds: incomplete,
    unpublishedPeerIds: unpublished,
    skippedPeerIds: skipped,
    recordsFailed: recordsFailed,
    manifestListedAt: listedAt,
  );

  test('excludes self and fenced peers', () {
    final snapshot = build(
      manifests: [
        _manifest('self', 5),
        _manifest('a', 1000),
        _manifest('b', 2000),
      ],
      fenced: {'b'},
    );

    expect(snapshot.takenAt, now);
    expect(snapshot.providerId, 'dropbox');
    expect(snapshot.peers.map((p) => p.deviceId), ['a']);
    expect(
      snapshot.peers.single.publishedAt,
      DateTime.fromMillisecondsSinceEpoch(1000),
    );
  });

  test('dates a publish by the earlier of its own clock and the cloud', () {
    // A peer whose clock runs ahead claims a publish after an upload it has
    // not seen; the cloud's own listing time caps that claim.
    final ahead = build(
      manifests: [_manifest('a', 5000)],
      listedAt: {'a': DateTime.fromMillisecondsSinceEpoch(3000)},
    );
    expect(
      ahead.peers.single.publishedAt,
      DateTime.fromMillisecondsSinceEpoch(3000),
    );

    final behind = build(
      manifests: [_manifest('a', 1000)],
      listedAt: {'a': DateTime.fromMillisecondsSinceEpoch(3000)},
    );
    expect(
      behind.peers.single.publishedAt,
      DateTime.fromMillisecondsSinceEpoch(1000),
    );
  });

  test('keeps a stale-epoch peer, which can still upload media', () {
    // A peer halted awaiting adoption is inert for merging, but it keeps
    // uploading; early delete must wait for it to publish like any other.
    final snapshot = build(
      manifests: [_manifest('a', 1000), _manifest('stale', 500)],
    );

    expect(snapshot.peers.map((p) => p.deviceId), ['a', 'stale']);
  });

  test('is caught up only after a clean pull that reached every head', () {
    expect(build().caughtUp, isTrue);
    expect(build(recordsFailed: 1).caughtUp, isFalse);
    expect(build(readFailed: {'a'}).caughtUp, isFalse);
    expect(build(newerSchema: {'a'}).caughtUp, isFalse);
    expect(build(incomplete: {'a'}).caughtUp, isFalse);
  });

  test('records devices that have not published a manifest yet', () {
    expect(build().hasUnappliedPeers, isFalse);
    expect(build(unpublished: {'new-device'}).hasUnappliedPeers, isTrue);
  });

  test('a skipped stale-epoch peer blocks early delete, not caught up', () {
    // Its changesets are never applied here, so its publish time says
    // nothing about which of its rows reached this device. It still gets
    // the grace window; blocking every delete would stall the cleanup for
    // as long as the device stays unadopted.
    final snapshot = build(
      manifests: [_manifest('a', 1000), _manifest('stale', 500)],
      skipped: {'stale'},
    );

    expect(snapshot.hasUnappliedPeers, isTrue);
    expect(snapshot.caughtUp, isTrue);
  });

  group('PeerSyncSnapshotStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('round-trips through the store', () async {
      final store = PeerSyncSnapshotStore(
        await SharedPreferences.getInstance(),
      );
      final snapshot = build();

      await store.write(snapshot);
      final read = store.read()!;

      expect(read.takenAt, snapshot.takenAt);
      expect(read.caughtUp, isTrue);
      expect(read.providerId, 'dropbox');
      expect(read.hasUnappliedPeers, isFalse);
      expect(read.peers.single.deviceId, 'a');
      expect(read.peers.single.publishedAt, snapshot.peers.single.publishedAt);
    });

    test('read returns null when nothing was written', () async {
      final store = PeerSyncSnapshotStore(
        await SharedPreferences.getInstance(),
      );
      expect(store.read(), isNull);
    });

    test('read returns null for malformed json', () async {
      SharedPreferences.setMockInitialValues({PeerSyncSnapshotStore.key: '{'});
      final store = PeerSyncSnapshotStore(
        await SharedPreferences.getInstance(),
      );
      expect(store.read(), isNull);
    });

    test('markNotCaughtUp keeps the peers and clears caughtUp', () async {
      final store = PeerSyncSnapshotStore(
        await SharedPreferences.getInstance(),
      );
      await store.markNotCaughtUp(); // nothing written: still nothing
      expect(store.read(), isNull);

      await store.write(build());
      await store.markNotCaughtUp();

      final read = store.read()!;
      expect(read.caughtUp, isFalse);
      expect(read.peers.single.deviceId, 'a');
      expect(read.takenAt, now);
    });
  });
}
