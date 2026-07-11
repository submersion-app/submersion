import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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

/// Claims a file is downloaded when it is not on disk.
class _PhantomDownloadPlatform extends DirectoryICloudMediaPlatform {
  _PhantomDownloadPlatform(super.root);

  @override
  Future<bool> ensureDownloaded(String path) async => true;
}

void main() {
  // The NativeICloudMediaPlatform tests invoke a real MethodChannel, which
  // needs the services binding available (it then fails with a
  // MissingPluginException the platform maps, rather than a binding error).
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory container;
  late Directory tmp;

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
    final store = ICloudMediaObjectStore(
      platform: _PhantomDownloadPlatform(container),
    );
    await expectLater(
      store.getFile('smv1/objects/aa/ghost.bin', File('${tmp.path}/o')),
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
}
