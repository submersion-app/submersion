import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/metadata_write_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

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
    // `isSupported` is checked before the channel, and CI runs its test shards
    // on Linux; without this the whole file would silently skip there.
    MetadataWriteService.debugSupportedOverride = true;
    handler = (_) async => true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) => handler(call));
  });

  tearDown(() {
    MetadataWriteService.debugSupportedOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> write() => MetadataWriteService().writeMetadata(
    platformAssetId: 'asset-1',
    metadata: _metadata,
    isVideo: false,
  );

  group('canWriteTo', () {
    MediaItem media({
      String? platformAssetId = 'asset-1',
      MediaType mediaType = MediaType.photo,
    }) => MediaItem(
      id: 'm1',
      platformAssetId: platformAssetId,
      mediaType: mediaType,
      takenAt: DateTime.utc(2026, 7, 1, 10),
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );

    test('accepts a photo in the device library', () {
      expect(MetadataWriteService().canWriteTo(media()), isTrue);
    });

    test('refuses media with no library asset (issue #3808)', () {
      expect(
        MetadataWriteService().canWriteTo(media(platformAssetId: null)),
        isFalse,
      );
    });

    test('refuses a video (issue #1472)', () {
      expect(
        MetadataWriteService().canWriteTo(media(mediaType: MediaType.video)),
        isFalse,
      );
    });

    test('refuses everything on a platform with no native writer', () {
      MetadataWriteService.debugSupportedOverride = false;
      expect(MetadataWriteService().canWriteTo(media()), isFalse);
    });
  });

  group('videos (issue #1472)', () {
    test('a video write is refused before the platform channel', () async {
      var invoked = false;
      handler = (_) async {
        invoked = true;
        return true;
      };

      await expectLater(
        MetadataWriteService().writeMetadata(
          platformAssetId: 'asset-1',
          metadata: _metadata,
          isVideo: true,
        ),
        throwsA(isA<MetadataWriteException>()),
      );
      expect(
        invoked,
        isFalse,
        reason: 'the native video path is gone; nothing should reach it',
      );
    });

    test('the channel payload carries no keep-original instruction', () async {
      MethodCall? seen;
      handler = (call) async {
        seen = call;
        return true;
      };

      await write();

      final args = seen!.arguments as Map;
      expect(
        args.containsKey('keepOriginal'),
        isFalse,
        reason:
            'issue #1472: no argument may tell the native side whether to '
            'delete the original',
      );
    });

    test('a native video refusal is given a curated message', () async {
      // Reachable only if an asset labelled a photo turns out to be a video.
      handler = (_) async => throw PlatformException(
        code: metadataWriteVideoUnsupportedCode,
        message: 'raw native',
      );

      await expectLater(
        write(),
        throwsA(
          isA<MetadataWriteException>()
              .having((e) => e.code, 'code', metadataWriteVideoUnsupportedCode)
              .having((e) => e.message, 'message', isNot(contains('raw'))),
        ),
      );
    });
  });

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
    });

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
    });
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
    });

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
    });

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
    });

    test('an unknown code with no message still names the code', () async {
      handler = (_) async => throw PlatformException(code: 'MYSTERY');

      await expectLater(
        write(),
        throwsA(
          isA<MetadataWriteException>().having(
            (e) => e.message,
            'message',
            contains('MYSTERY'),
          ),
        ),
      );
    });

    test('a thrown non-platform error is still surfaced', () async {
      // The mock messenger re-wraps anything that is not a PlatformException
      // into `PlatformException(code: 'error')`, so this arrives typed.
      handler = (_) async => throw StateError('boom');

      await expectLater(write(), throwsA(isA<MetadataWriteException>()));
    });
  });
}
