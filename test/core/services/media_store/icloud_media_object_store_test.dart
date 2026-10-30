import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/media_store/icloud_media_object_store.dart';
import 'package:submersion/core/services/media_store/icloud_media_platform.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';

import 'media_object_store_contract.dart';

class _NoContainerPlatform extends DirectoryICloudMediaPlatform {
  _NoContainerPlatform(super.root);

  @override
  Future<String?> containerPath() async => null;
}

/// Reports a failed coordinated move (the OS refused the transfer).
class _FailedMovePlatform extends DirectoryICloudMediaPlatform {
  _FailedMovePlatform(super.root);

  @override
  Future<bool> moveIntoContainer(String s, String d) async => false;
}

/// Reports a file iCloud knows about but could not materialize in time. The
/// native downloadIfNeeded answers false only on that path: the placeholder
/// exists, startDownloadingUbiquitousItem succeeded, and the 12 s poll ran out.
/// A file the container has never held short-circuits to true instead.
class _UndownloadablePlatform extends DirectoryICloudMediaPlatform {
  _UndownloadablePlatform(super.root);

  @override
  Future<bool> ensureDownloaded(String path) async => false;
}

/// Counts the refreshes that make iCloud download every evicted item.
class _CountingPlatform extends DirectoryICloudMediaPlatform {
  _CountingPlatform(super.root);

  int refreshes = 0;

  @override
  Future<void> refreshFolder(String path) async => refreshes++;
}

void main() {
  // The NativeICloudMediaPlatform tests invoke a real MethodChannel, which
  // needs the services binding available (it then fails with a
  // MissingPluginException the platform maps, rather than a binding error).
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory container;
  late Directory tmp;

  /// A media object's path inside the container's store root.
  String objectPath(String shard, String name) => p.join(
    container.path,
    'submersion-media',
    'smv1',
    'objects',
    shard,
    name,
  );

  ICloudMediaObjectStore build({int? smallFileThresholdBytes}) {
    return ICloudMediaObjectStore(
      platform: DirectoryICloudMediaPlatform(container),
      smallFileThresholdBytes: smallFileThresholdBytes ?? 8 * 1024 * 1024,
    );
  }

  setUp(() async {
    container = await Directory.systemTemp.createTemp('icloud_container');
    tmp = await Directory.systemTemp.createTemp('icloud_mos_test');
  });

  tearDown(() async {
    await container.delete(recursive: true);
    await tmp.delete(recursive: true);
  });

  runMediaObjectStoreContract('ICloudMediaObjectStore', () async {
    // Fresh container per contract test.
    container = await Directory.systemTemp.createTemp('icloud_contract');
    return build();
  });

  test('large putFile lands via moveIntoContainer and the staging copy is '
      'gone', () async {
    final store = build(smallFileThresholdBytes: 1024);
    final bytes = List<int>.generate(4096, (i) => i % 251);
    final src = File('${tmp.path}/video.mp4')..writeAsBytesSync(bytes);

    final progress = <int>[];
    await store.putFile(
      'smv1/objects/aa/video.mp4',
      src,
      contentType: 'video/mp4',
      onProgress: (sent, total) => progress.add(sent),
    );

    final landed = File(
      '${container.path}/submersion-media/smv1/objects/aa/video.mp4',
    );
    expect(await landed.readAsBytes(), bytes);
    expect(
      File(
        '${container.path}/submersion-media/smv1/objects/aa/'
        'video.mp4.uploading',
      ).existsSync(),
      isFalse,
    );
    expect(progress.single, bytes.length);
    // The .uploading staging suffix never leaks into listings.
    final keys = await store.list('smv1/').map((o) => o.key).toList();
    expect(keys, ['smv1/objects/aa/video.mp4']);
  });

  test('a large upload is dated by the upload, not the source file', () async {
    // The cleanup's grace window and early delete are measured from
    // lastModified. A copy that kept the photo's capture date would make a
    // fresh upload look months old to a device that has not seen its row.
    final store = build(smallFileThresholdBytes: 1024);
    final src = File('${tmp.path}/old-video.mp4')
      ..writeAsBytesSync(List<int>.filled(4096, 7))
      ..setLastModifiedSync(DateTime(2025, 1, 1));
    final before = DateTime.now().subtract(const Duration(seconds: 5));

    await store.putFile(
      'smv1/objects/aa/old-video.mp4',
      src,
      contentType: 'video/mp4',
    );

    final listed = await store.list('smv1/objects/').single;
    expect(listed.lastModified.isAfter(before), isTrue);
  });

  test('an upload that cannot be dated is not published', () async {
    // Published with the source's old time, a fresh upload could look past
    // the grace window to a device that has not seen its row yet.
    final store = ICloudMediaObjectStore(
      platform: DirectoryICloudMediaPlatform(container),
      smallFileThresholdBytes: 1024,
      dateStagedCopy: (file, at) async =>
          throw FileSystemException('read-only', file.path),
    );
    final src = File('${tmp.path}/old-video.mp4')
      ..writeAsBytesSync(List<int>.filled(4096, 7));

    await expectLater(
      store.putFile('smv1/objects/aa/old-video.mp4', src, contentType: 'v'),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.kind,
          'kind',
          MediaStoreErrorKind.transient,
        ),
      ),
    );
    expect(await store.list('smv1/').toList(), isEmpty);
    final staged = Directory(
      '${container.path}/submersion-media',
    ).listSync(recursive: true).whereType<File>();
    expect(staged, isEmpty, reason: 'the staging copy is removed');
  });

  group('local listing', () {
    test('asks iCloud for nothing', () async {
      // A refresh starts downloading every evicted item; a measurement
      // must not pull the whole media library back onto the disk.
      final platform = _CountingPlatform(container);
      final store = ICloudMediaObjectStore(platform: platform);
      File(objectPath('aa', 'aabb.jpg'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);

      final listed = await store.listLocal('smv1/').toList();

      expect(platform.refreshes, 0);
      expect(listed.single.key, 'smv1/objects/aa/aabb.jpg');
      expect(listed.single.sizeBytes, 3);
    });

    test('reports an evicted item under its key, size unknown', () async {
      // Where eviction leaves a .<name>.icloud placeholder, the object is
      // still there; only its size is not known on this device.
      final store = ICloudMediaObjectStore(
        platform: DirectoryICloudMediaPlatform(container),
      );
      File(objectPath('aa', '.aabb.jpg.icloud'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([9]);

      final listed = await store.listLocal('smv1/').toList();

      expect(listed.single.key, 'smv1/objects/aa/aabb.jpg');
      expect(listed.single.sizeBytes, isNull);
    });

    test('the full listing still refreshes', () async {
      final platform = _CountingPlatform(container);
      final store = ICloudMediaObjectStore(platform: platform);

      await store.list('smv1/').toList();

      expect(platform.refreshes, 1);
    });
  });

  group('evicted objects and ages', () {
    test('the full listing reports an evicted object under its key', () async {
      // A deleting sweep's reverse repair checks exact keys: a placeholder
      // listed under its own name made a present object look missing, and
      // the repair cleared its synced upload stamps on every device.
      final store = ICloudMediaObjectStore(
        platform: DirectoryICloudMediaPlatform(container),
      );
      File(objectPath('aa', '.aabb.jpg.icloud'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([9]);

      final listed = await store.list('smv1/').toList();

      expect(listed.single.key, 'smv1/objects/aa/aabb.jpg');
      expect(listed.single.sizeBytes, isNull);
    });

    test('an object copied with an old date is aged by its arrival', () async {
      // Builds before the upload-time fix staged copies with the source's
      // modification time; the change time still says when the file
      // arrived, so the grace window starts there.
      final store = ICloudMediaObjectStore(
        platform: DirectoryICloudMediaPlatform(container),
      );
      final before = DateTime.now().subtract(const Duration(seconds: 5));
      File(objectPath('aa', 'aabb.jpg'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3])
        ..setLastModifiedSync(DateTime(2024, 1, 1));

      final listed = await store.list('smv1/').single;
      final head = await store.head('smv1/objects/aa/aabb.jpg');

      expect(listed.lastModified.isAfter(before), isTrue);
      expect(head!.lastModified.isAfter(before), isTrue);
    });

    test('deleting an evicted object removes its placeholder', () async {
      final store = ICloudMediaObjectStore(
        platform: DirectoryICloudMediaPlatform(container),
      );
      final placeholder = File(objectPath('aa', '.aabb.jpg.icloud'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([9]);

      await store.delete('smv1/objects/aa/aabb.jpg');

      expect(placeholder.existsSync(), isFalse);
    });
  });

  test('null container path maps to a fatal MediaStoreException', () async {
    final store = ICloudMediaObjectStore(
      platform: _NoContainerPlatform(container),
    );
    final src = File('${tmp.path}/x.jpg')
      ..writeAsBytesSync(Uint8List.fromList([1]));
    await expectLater(
      store.putFile('smv1/objects/aa/x.jpg', src, contentType: 'image/jpeg'),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.kind,
          'kind',
          MediaStoreErrorKind.fatal,
        ),
      ),
    );
  });

  test('a missing source file is a fatal MediaStoreException', () async {
    final store = build();
    await expectLater(
      store.putFile(
        'smv1/objects/aa/gone.bin',
        File('${tmp.path}/nope.bin'),
        contentType: 'x',
      ),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.kind,
          'kind',
          MediaStoreErrorKind.fatal,
        ),
      ),
    );
  });

  test('a failed coordinated move surfaces a transient error', () async {
    final store = ICloudMediaObjectStore(
      platform: _FailedMovePlatform(container),
      smallFileThresholdBytes: 1024,
    );
    final src = File('${tmp.path}/big.mp4')
      ..writeAsBytesSync(List<int>.generate(4096, (i) => i % 251));
    await expectLater(
      store.putFile('smv1/objects/aa/big.mp4', src, contentType: 'video/mp4'),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.kind,
          'kind',
          MediaStoreErrorKind.transient,
        ),
      ),
    );
  });

  test('getFile treats a phantom download (no file on disk) as not '
      'found', () async {
    await expectLater(
      build().getFile('smv1/objects/aa/ghost.bin', File('${tmp.path}/o')),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.kind,
          'kind',
          MediaStoreErrorKind.notFound,
        ),
      ),
    );
  });

  group('NativeICloudMediaPlatform', () {
    final platform = NativeICloudMediaPlatform();

    test(
      'writeSmallFile wraps the native failure as a MediaStoreException',
      () {
        // No iCloud plugin in a unit test, so the native call fails and the
        // platform maps it to a fatal MediaStoreException.
        return expectLater(
          platform.writeSmallFile('${tmp.path}/x', Uint8List.fromList([1])),
          throwsA(isA<MediaStoreException>()),
        );
      },
    );

    test('containerPath returns null without the plugin', () async {
      expect(await platform.containerPath(), isNull);
    });

    test('the remaining delegations forward without crashing', () async {
      // These forward straight to ICloudNativeService; they either
      // short-circuit (non-Apple host) or fail on the absent channel, but
      // must not crash the caller.
      for (final call in [
        () => platform.moveIntoContainer('${tmp.path}/a', '${tmp.path}/b'),
        () => platform.ensureDownloaded('${tmp.path}/x'),
        () => platform.refreshFolder('${tmp.path}/x'),
      ]) {
        try {
          await call();
        } catch (_) {
          // Channel-absent failures are expected off-device.
        }
      }
    });
  });

  test('reapStaleUploadSessions is a self-expiry no-op', () async {
    expect(
      await build().reapStaleUploadSessions(olderThan: DateTime.utc(2026)),
      0,
    );
  });

  // Issue #1356: the second device to connect read the first device's
  // store.json before iCloud had finished downloading it. Reporting that as
  // notFound made StoreMarkerStore.ensure mint a fresh store id and overwrite
  // the marker, splitting the store's identity between the two devices.
  test('getFile on a placeholder that would not download in time is '
      'transient, not notFound', () async {
    final store = ICloudMediaObjectStore(
      platform: _UndownloadablePlatform(container),
    );
    File('${container.path}/submersion-media/smv1/store.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"storeId":"a","formatVersion":1}');
    await expectLater(
      store.getFile('smv1/store.json', File('${tmp.path}/o')),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.kind,
          'kind',
          MediaStoreErrorKind.transient,
        ),
      ),
    );
  });

  // null means "not in the store" to every caller, and the upload pipeline
  // answers that by uploading: reporting a placeholder still coming down as
  // absent re-uploads the whole library from the second device.
  test('head on a placeholder that would not download in time is transient, '
      'not absent', () async {
    final store = ICloudMediaObjectStore(
      platform: _UndownloadablePlatform(container),
    );
    File('${container.path}/submersion-media/smv1/objects/aa/x.jpg')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    await expectLater(
      store.head('smv1/objects/aa/x.jpg'),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.kind,
          'kind',
          MediaStoreErrorKind.transient,
        ),
      ),
    );
  });

  test('head on a key the container has never held is absent', () async {
    expect(await build().head('smv1/objects/aa/never.bin'), isNull);
  });

  test('getFile on a key the container has never held is notFound', () async {
    await expectLater(
      build().getFile('smv1/objects/aa/never.bin', File('${tmp.path}/o')),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.kind,
          'kind',
          MediaStoreErrorKind.notFound,
        ),
      ),
    );
  });
}
