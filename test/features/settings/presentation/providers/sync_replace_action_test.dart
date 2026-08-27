import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

void main() {
  group('skippedPeerLabels', () {
    test('uses the published name when there is one', () {
      final labels = SyncNotifier.skippedPeerLabels(
        const SyncResult(
          status: SyncResultStatus.success,
          skippedPeerDeviceIds: {'a1b2c3d4e5f6'},
          skippedPeerNames: {'a1b2c3d4e5f6': 'Erics-iPhone'},
        ),
      );

      expect(labels.single.name, 'Erics-iPhone');
      expect(labels.single.shortId, 'a1b2c3d4');
    });

    test('leaves the name null for a peer that published none', () {
      // A peer on a manifest written before deviceName existed. The page
      // turns a null name into the localized "device <shortId>" label.
      final labels = SyncNotifier.skippedPeerLabels(
        const SyncResult(
          status: SyncResultStatus.success,
          skippedPeerDeviceIds: {'a1b2c3d4e5f6'},
        ),
      );

      expect(labels.single.name, isNull);
      expect(labels.single.shortId, 'a1b2c3d4');
    });

    test('treats an empty published name as absent', () {
      final labels = SyncNotifier.skippedPeerLabels(
        const SyncResult(
          status: SyncResultStatus.success,
          skippedPeerDeviceIds: {'a1b2c3d4e5f6'},
          skippedPeerNames: {'a1b2c3d4e5f6': ''},
        ),
      );

      expect(labels.single.name, isNull);
    });

    test('does not truncate a device id shorter than the label length', () {
      final labels = SyncNotifier.skippedPeerLabels(
        const SyncResult(
          status: SyncResultStatus.success,
          skippedPeerDeviceIds: {'short'},
        ),
      );

      expect(labels.single.shortId, 'short');
    });

    test('sorts by display label so the banner is stable across syncs', () {
      // Set iteration order is not guaranteed to be stable across pulls; the
      // banner text must not reshuffle on every sync.
      final labels = SyncNotifier.skippedPeerLabels(
        const SyncResult(
          status: SyncResultStatus.success,
          skippedPeerDeviceIds: {'zzz11111', 'aaa22222', 'mmm33333'},
          skippedPeerNames: {'zzz11111': 'Alpha', 'mmm33333': 'Beta'},
        ),
      );

      // 'Alpha', 'aaa22222' (unnamed, sorts by id), 'Beta'.
      expect(labels.map((l) => l.name ?? l.shortId), [
        'Alpha',
        'Beta',
        'aaa22222',
      ]);
    });

    test('is empty when nothing was skipped', () {
      final labels = SyncNotifier.skippedPeerLabels(
        const SyncResult(status: SyncResultStatus.success),
      );

      expect(labels, isEmpty);
    });
  });

  group('ReplacePreflight', () {
    test('a null peer count means the listing did not succeed', () {
      const preflight = ReplacePreflight(localDiveCount: 1247);

      expect(preflight.localDiveCount, 1247);
      expect(preflight.peerFileCount, isNull);
      expect(preflight.hasPeerCount, isFalse);
    });

    test('a known peer count is reported', () {
      const preflight = ReplacePreflight(
        localDiveCount: 1247,
        peerFileCount: 2,
      );

      expect(preflight.peerFileCount, 2);
      expect(preflight.hasPeerCount, isTrue);
    });

    test('zero peers is a known count, not an unknown one', () {
      // A solo device must still be able to replace: the dialog says "every
      // other device" only when the listing FAILED, never when it found none.
      const preflight = ReplacePreflight(localDiveCount: 10, peerFileCount: 0);

      expect(preflight.hasPeerCount, isTrue);
    });
  });
}
