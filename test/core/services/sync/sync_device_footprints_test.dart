import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/retirement_marker.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/core/services/sync/sync_device_footprint.dart';
import 'package:submersion/core/services/sync/sync_device_footprints.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';

/// Issue #1032: a user found 400+ files on Dropbox from what should have been a
/// single syncing device, with nothing in the app able to account for them.
/// These tests pin the survey that explains the folder and the safe removal of
/// one device's share of it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCloudStorageProvider cloud;
  late SyncDeviceFootprints footprints;

  setUp(() {
    cloud = FakeCloudStorageProvider();
    footprints = SyncDeviceFootprints();
  });

  /// Same object under a timeout short enough to observe without waiting one
  /// out. The production default is 8s.
  SyncDeviceFootprints impatient() =>
      SyncDeviceFootprints(cloudCallTimeout: const Duration(milliseconds: 20));

  Uint8List bytes(String s) => Uint8List.fromList(s.codeUnits);

  void seedManifest(
    String deviceId, {
    String? epochId,
    String? deviceName,
    int updatedAt = 1000,
    int? schemaVersion,
  }) {
    cloud.seedFile(
      ChangesetLogLayout.manifestName(deviceId),
      SyncManifest(
        deviceId: deviceId,
        deviceName: deviceName,
        provider: 'fake',
        headSeq: 1,
        updatedAt: updatedAt,
        epochId: epochId,
        schemaVersion: schemaVersion,
      ).toBytes(),
    );
  }

  group('list', () {
    test('groups every file under the device that published it', () async {
      seedManifest('dev1', epochId: 'e1', deviceName: 'Pixel');
      for (var i = 0; i < 3; i++) {
        cloud.seedFile(
          ChangesetLogLayout.basePartName('dev1', 1, i),
          bytes('xxxxx'),
        );
      }
      seedManifest('dev2', epochId: 'e1');

      final all = await footprints.list(
        provider: cloud,
        selfDeviceId: 'dev1',
        currentEpochId: 'e1',
      );

      expect(all.map((f) => f.deviceId), containsAll(['dev1', 'dev2']));
      final dev1 = all.firstWhere((f) => f.deviceId == 'dev1');
      expect(dev1.fileCount, 4, reason: 'manifest + 3 base parts');
      expect(
        dev1.byteCount,
        15 + cloud.bytesOf(ChangesetLogLayout.manifestName('dev1'))!.length,
        reason: 'the manifest occupies backend space too, so it counts',
      );
      expect(dev1.deviceName, 'Pixel');
      expect(dev1.isSelf, isTrue);
      expect(dev1.state, SyncDeviceFootprintState.active);
    });

    test('flags a device stamped with a superseded epoch as stale', () async {
      // Exactly the "shadow copy" the reporter asked to be able to see: files
      // left behind by an earlier library that no current device will ever read.
      seedManifest('ghost', epochId: 'old-epoch');

      final all = await footprints.list(
        provider: cloud,
        selfDeviceId: 'me',
        currentEpochId: 'new-epoch',
      );

      final ghost = all.single;
      expect(ghost.state, SyncDeviceFootprintState.staleEpoch);
      expect(ghost.isSafeToRemove, isTrue);
    });

    test('a retired device is reported as retired, not stale', () async {
      seedManifest('old', epochId: 'e1');
      cloud.seedFile(
        ChangesetLogLayout.retiredMarkerName('old'),
        const RetirementMarker(deviceId: 'old', retiredAt: 5).toBytes(),
      );

      final all = await footprints.list(
        provider: cloud,
        selfDeviceId: 'me',
        currentEpochId: 'e1',
      );

      expect(all.single.state, SyncDeviceFootprintState.retired);
    });

    test(
      'files with no readable manifest are unreadable, never stale',
      () async {
        // An interrupted publish looks exactly like this. Calling it stale would
        // invite the user to delete an upload that is still in flight.
        cloud.seedFile(
          ChangesetLogLayout.basePartName('half', 1, 0),
          bytes('partial'),
        );

        final all = await footprints.list(
          provider: cloud,
          selfDeviceId: 'me',
          currentEpochId: 'e1',
        );

        expect(all.single.state, SyncDeviceFootprintState.unreadable);
        expect(
          all.single.isSafeToRemove,
          isFalse,
          reason: 'no manifest means no basis to judge it disposable',
        );
      },
    );

    test(
      'a corrupt manifest downgrades one device, not the whole survey',
      () async {
        seedManifest('good', epochId: 'e1');
        cloud.seedFile(
          ChangesetLogLayout.manifestName('bad'),
          bytes('not json'),
        );

        final all = await footprints.list(
          provider: cloud,
          selfDeviceId: 'me',
          currentEpochId: 'e1',
        );

        expect(all, hasLength(2));
        expect(
          all.firstWhere((f) => f.deviceId == 'bad').state,
          SyncDeviceFootprintState.unreadable,
        );
        expect(
          all.firstWhere((f) => f.deviceId == 'good').state,
          SyncDeviceFootprintState.active,
        );
      },
    );

    test('sorts this device first, then most recently published', () async {
      seedManifest('me', epochId: 'e1', updatedAt: 1);
      seedManifest('older', epochId: 'e1', updatedAt: 10);
      seedManifest('newer', epochId: 'e1', updatedAt: 99);

      final all = await footprints.list(
        provider: cloud,
        selfDeviceId: 'me',
        currentEpochId: 'e1',
      );

      expect(all.map((f) => f.deviceId), ['me', 'newer', 'older']);
    });
  });

  group('a stalled backend cannot strand the user (PR #1033 review)', () {
    // Both entry points run in front of a user who cannot leave: the listing
    // behind a page-filling spinner, and the retire behind a deliberately
    // non-dismissible dialog with no back button. An unbounded cloud call
    // against a dead connection is the "app is hung, force-quit it" failure
    // this whole change set exists to end -- and force-quitting mid-retire is
    // what leaves a device half-deleted.

    test('list gives up rather than hanging on the folder listing', () async {
      cloud.hangOperations = true;

      await expectLater(
        impatient().list(provider: cloud, selfDeviceId: 'me'),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('one stalled manifest read does not stall the survey', () async {
      seedManifest('stalled', epochId: 'e1');
      seedManifest('fine', epochId: 'e1');
      // The listing succeeds; the per-device manifest reads never return.
      cloud.hangDownloads = true;

      final all = await impatient().list(
        provider: cloud,
        selfDeviceId: 'me',
        currentEpochId: 'e1',
      );

      expect(all, hasLength(2));
      expect(
        all.every((f) => f.state == SyncDeviceFootprintState.unreadable),
        isTrue,
        reason:
            'a device whose manifest could not be read is reported as '
            'unreadable, which is never offered as safe to remove',
      );
      expect(all.any((f) => f.isSafeToRemove), isFalse);
    });

    test('retirePeer gives up when the fence marker will not upload', () async {
      seedManifest('peer', epochId: 'old');
      cloud.hangOperations = true;

      final outcome = await impatient().retirePeer(
        provider: cloud,
        deviceId: 'peer',
        selfDeviceId: 'me',
      );

      expect(outcome.deleted, 0);
      expect(outcome.isComplete, isFalse);
      expect(
        cloud.bytesOf(ChangesetLogLayout.manifestName('peer')),
        isNotNull,
        reason: 'a timed-out marker is no fence, so nothing may be deleted',
      );
    });

    test('a hung delete is counted, not waited on forever', () async {
      seedManifest('peer', epochId: 'old');
      cloud.seedFile(
        ChangesetLogLayout.basePartName('peer', 1, 0),
        bytes('data'),
      );
      final slow = impatient();

      // Let the marker upload and the listing succeed, then stall deletes.
      var listed = false;
      final outcome = await slow.retirePeer(
        provider: cloud,
        deviceId: 'peer',
        selfDeviceId: 'me',
        onProgress: (done, total) {
          if (!listed) {
            listed = true;
            cloud.hangOperations = true;
          }
        },
      );

      expect(outcome.failed, greaterThan(0));
      expect(outcome.isComplete, isFalse);
    });
  });

  group('retirePeer', () {
    test('writes the fence marker before deleting anything', () async {
      seedManifest('peer', epochId: 'old');
      cloud.seedFile(
        ChangesetLogLayout.basePartName('peer', 1, 0),
        bytes('data'),
      );

      final outcome = await footprints.retirePeer(
        provider: cloud,
        deviceId: 'peer',
        selfDeviceId: 'me',
      );

      final marker = 'upload:${ChangesetLogLayout.retiredMarkerName('peer')}';
      final firstDelete = cloud.operationLog.indexWhere(
        (op) => op.startsWith('delete:'),
      );
      expect(
        cloud.operationLog.indexOf(marker),
        lessThan(firstDelete),
        reason:
            'a device that comes back online must find the marker; deleting '
            'first would let its stale rows resurrect fleet-wide',
      );
      expect(outcome.deleted, 2);
      expect(outcome.isComplete, isTrue);
    });

    test('keeps the retirement marker it just wrote', () async {
      seedManifest('peer', epochId: 'old');

      await footprints.retirePeer(
        provider: cloud,
        deviceId: 'peer',
        selfDeviceId: 'me',
      );

      expect(
        cloud.bytesOf(ChangesetLogLayout.retiredMarkerName('peer')),
        isNotNull,
      );
      expect(cloud.bytesOf(ChangesetLogLayout.manifestName('peer')), isNull);
    });

    test('leaves other devices untouched', () async {
      seedManifest('peer', epochId: 'old');
      seedManifest('keeper', epochId: 'e1');

      await footprints.retirePeer(
        provider: cloud,
        deviceId: 'peer',
        selfDeviceId: 'me',
      );

      expect(
        cloud.bytesOf(ChangesetLogLayout.manifestName('keeper')),
        isNotNull,
      );
    });

    test('deletes nothing when the marker cannot be written', () async {
      seedManifest('peer', epochId: 'old');
      cloud.failUploads = true;

      final outcome = await footprints.retirePeer(
        provider: cloud,
        deviceId: 'peer',
        selfDeviceId: 'me',
      );

      expect(outcome.deleted, 0);
      expect(outcome.isComplete, isFalse);
      expect(
        cloud.bytesOf(ChangesetLogLayout.manifestName('peer')),
        isNotNull,
        reason: 'no fence, no deletion -- unfenced removal is the unsafe case',
      );
    });

    test('refuses to retire this device through the peer path', () async {
      expect(
        () => footprints.retirePeer(
          provider: cloud,
          deviceId: 'me',
          selfDeviceId: 'me',
        ),
        throwsArgumentError,
      );
    });

    test('reports progress per file', () async {
      seedManifest('peer', epochId: 'old');
      for (var i = 0; i < 3; i++) {
        cloud.seedFile(
          ChangesetLogLayout.basePartName('peer', 1, i),
          bytes('d'),
        );
      }

      final seen = <({int done, int total})>[];
      await footprints.retirePeer(
        provider: cloud,
        deviceId: 'peer',
        selfDeviceId: 'me',
        onProgress: (done, total) => seen.add((done: done, total: total)),
      );

      expect(seen.first, (done: 0, total: 4));
      expect(seen.last, (done: 4, total: 4));
    });
  });
}
