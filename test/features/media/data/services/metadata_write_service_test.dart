import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/metadata_write_service.dart';

/// Mirrors `MetadataWriteService.isSupported`, which is checked BEFORE the
/// platform channel: on an unsupported host the service throws outright and
/// the mocked channel is never reached, so every case that asserts on a
/// channel response has to be skipped there.
final bool _metadataWriteSupported =
    Platform.isIOS || Platform.isMacOS || Platform.isAndroid;

/// Enough dive data to clear the service's `hasData` guard.
const _metadata = DiveMediaMetadata(
  depthMeters: 18.3,
  temperatureCelsius: 21.5,
  latitude: 36.9,
  longitude: -25.1,
  siteName: 'Dom Pedro',
  elapsedSeconds: 600,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.submersion.app/metadata');
  late Future<Object?> Function(MethodCall) handler;

  setUp(() {
    handler = (_) async => true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) => handler(call));
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> write() => MetadataWriteService().writeMetadata(
    platformAssetId: 'asset-1',
    metadata: _metadata,
    isVideo: false,
  );

  group('live photos', () {
    test('the native refusal is carried through as a distinct code', () async {
      handler = (_) async => throw PlatformException(
        code: metadataWriteLivePhotoUnsupportedCode,
        message: 'Live Photos are not supported.',
      );

      await expectLater(
        write(),
        throwsA(
          isA<MetadataWriteException>().having(
            (e) => e.code,
            'code',
            metadataWriteLivePhotoUnsupportedCode,
          ),
        ),
      );
    }, skip: !_metadataWriteSupported);

    test('the raw PhotoKit error never reaches the message', () async {
      // Before the native Live Photo check existed, PhotoKit rejected the
      // rewritten still and its untranslated error text was shown verbatim.
      handler = (_) async => throw PlatformException(
        code: metadataWriteLivePhotoUnsupportedCode,
        message:
            "The operation couldn't be completed. "
            '(PHPhotosErrorDomain error 3302.)',
      );

      await expectLater(
        write(),
        throwsA(
          isA<MetadataWriteException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Live Photo'),
              isNot(contains('PHPhotosErrorDomain')),
            ),
          ),
        ),
      );
    }, skip: !_metadataWriteSupported);
  });

  group('other platform failures', () {
    test('a known code keeps its curated message and its code', () async {
      handler = (_) async =>
          throw PlatformException(code: 'READ_ONLY', message: 'raw native');

      await expectLater(
        write(),
        throwsA(
          isA<MetadataWriteException>()
              .having((e) => e.code, 'code', 'READ_ONLY')
              .having((e) => e.message, 'message', contains('read-only')),
        ),
      );
    }, skip: !_metadataWriteSupported);

    test('WRITE_FAILED still passes the native message through', () async {
      handler = (_) async =>
          throw PlatformException(code: 'WRITE_FAILED', message: 'disk full');

      await expectLater(
        write(),
        throwsA(
          isA<MetadataWriteException>()
              .having((e) => e.code, 'code', 'WRITE_FAILED')
              .having((e) => e.message, 'message', 'disk full'),
        ),
      );
    }, skip: !_metadataWriteSupported);

    test('a failure raised on the Dart side carries no code', () async {
      // A `false` result is rejected by a throw inside the service's own try,
      // so it reaches the untyped catch rather than the PlatformException one
      // and no native code is available to attach. Callers keying off `code`
      // must therefore tolerate null and fall back to the message.
      handler = (_) async => false;

      await expectLater(
        write(),
        throwsA(
          isA<MetadataWriteException>().having((e) => e.code, 'code', isNull),
        ),
      );
    }, skip: !_metadataWriteSupported);

    test('a thrown non-platform error is still surfaced', () async {
      // The mock messenger re-wraps anything that is not a PlatformException
      // into `PlatformException(code: 'error')`, so this arrives typed.
      handler = (_) async => throw StateError('boom');

      await expectLater(write(), throwsA(isA<MetadataWriteException>()));
    }, skip: !_metadataWriteSupported);
  });
}
