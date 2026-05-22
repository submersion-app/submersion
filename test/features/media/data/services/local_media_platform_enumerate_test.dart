import 'dart:io';
import 'dart:typed_data';

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
            case 'enumerateScopedDirectory':
              return <Map<Object?, Object?>>[
                {
                  'basename': 'a.jpg',
                  'bookmarkBlob': Uint8List.fromList([1, 2]),
                },
                {
                  'basename': 'b.png',
                  'bookmarkBlob': Uint8List.fromList([3, 4]),
                },
              ];
            case 'enumerateTree':
              return <Map<Object?, Object?>>[
                {'basename': 'c.jpg', 'contentUri': 'content://tree/doc/c'},
              ];
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
    'enumerateScopedDirectory returns basename+blob entries (iOS/macOS)',
    () async {
      final folderBookmark = Uint8List.fromList([1, 2, 3]);
      if (!Platform.isIOS && !Platform.isMacOS) {
        expect(
          () => LocalMediaPlatform().enumerateScopedDirectory(folderBookmark),
          throwsUnsupportedError,
        );
        return;
      }
      final entries = await LocalMediaPlatform().enumerateScopedDirectory(
        folderBookmark,
      );
      expect(entries.length, 2);
      expect(entries.first.basename, 'a.jpg');
      expect(entries.first.bookmarkBlob, [1, 2]);
    },
  );

  test('enumerateTree returns basename+contentUri entries (Android)', () async {
    if (!Platform.isAndroid) {
      expect(
        () => LocalMediaPlatform().enumerateTree('content://tree/x'),
        throwsUnsupportedError,
      );
      return;
    }
    final entries = await LocalMediaPlatform().enumerateTree(
      'content://tree/x',
    );
    expect(entries.single.basename, 'c.jpg');
    expect(entries.single.contentUri, 'content://tree/doc/c');
  });
}
