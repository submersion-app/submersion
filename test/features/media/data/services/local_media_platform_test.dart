import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.submersion.app/local_media');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'createBookmark':
              return Uint8List.fromList([1, 2, 3]);
            case 'resolveBookmark':
              return {
                'bookmarkRef': 'session-1',
                'filePath': '/Users/me/x.jpg',
                'stale': false,
              };
            case 'releaseBookmark':
              return null;
            case 'releaseAllBookmarks':
              return null;
            case 'takePersistableUri':
              return call.arguments['uri'] as String;
            case 'listPersistedUris':
              return ['content://example/1', 'content://example/2'];
            case 'readBookmarkBytes':
              return Uint8List.fromList([4, 5, 6]);
            case 'readUriBytes':
              return Uint8List.fromList([7, 8, 9]);
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'createBookmark returns blob bytes',
    () async {
      final platform = LocalMediaPlatform();
      final blob = await platform.createBookmark('/Users/me/x.jpg');
      expect(blob, isA<Uint8List>());
      expect(blob, [1, 2, 3]);
    },
    skip: 'createBookmark uses Platform.isIOS/macOS — runs only on those hosts',
  );

  test(
    'resolveBookmark returns ref + path',
    () async {
      final platform = LocalMediaPlatform();
      final r = await platform.resolveBookmark(Uint8List.fromList([1, 2, 3]));
      expect(r.bookmarkRef, 'session-1');
      expect(r.filePath, '/Users/me/x.jpg');
      expect(r.stale, isFalse);
    },
    skip:
        'resolveBookmark uses Platform.isIOS/macOS — runs only on those hosts',
  );

  test('ResolvedBookmark constructor', () {
    const r = ResolvedBookmark(bookmarkRef: 'r', filePath: '/x', stale: true);
    expect(r.bookmarkRef, 'r');
    expect(r.filePath, '/x');
    expect(r.stale, isTrue);
  });

  // The host-platform check for readBookmarkBytes lives in
  // local_media_platform_linux_test.dart (covers non-iOS/macOS hosts).
  // On macOS hosts the channel call would actually fire — covered by
  // local_file_resolver_test.dart's BytesData round-trip test.

  test('readBookmarkBytes returns bytes on iOS/macOS hosts', () async {
    if (!Platform.isIOS && !Platform.isMacOS) return;
    final platform = LocalMediaPlatform();
    final result = await platform.readBookmarkBytes(
      Uint8List.fromList([1, 2, 3]),
    );
    expect(result, [4, 5, 6]);
  });
}
