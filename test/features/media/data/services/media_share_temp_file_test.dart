import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/media/data/services/media_share_temp_file.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');

  // Same failure mode as PR #555 (sync_temp_dir_test.dart), reproduced for
  // the media share flow: getTemporaryDirectory() may hand back a path that
  // does not exist yet (macOS Library/Caches/<bundle-id>, absent on a fresh
  // install), and writeAsBytes throws PathNotFoundException when opening a
  // file for write inside a missing directory.
  group('writeShareTempFile', () {
    late Directory parent;
    late Directory missing;
    late DateTime now;

    setUp(() async {
      now = DateTime(2024, 6, 15, 10, 30);
      parent = await Directory.systemTemp.createTemp(
        'media_share_temp_file_test_',
      );
      missing = Directory('${parent.path}/Library/Caches/app.submersion');
      expect(
        missing.existsSync(),
        isFalse,
        reason: 'precondition: the resolved dir does not exist yet',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async =>
                call.method == 'getTemporaryDirectory' ? missing.path : null,
          );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (parent.existsSync()) await parent.delete(recursive: true);
    });

    test('creates the temp directory when it does not exist yet', () async {
      final item = MediaItem(
        id: 'media-1',
        diveId: 'dive-1',
        mediaType: MediaType.photo,
        originalFilename: 'IMG_1234.jpg',
        takenAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final file = await writeShareTempFile(
        item,
        Uint8List.fromList([1, 2, 3]),
      );

      expect(
        missing.existsSync(),
        isTrue,
        reason: 'the missing temp dir must be created before writing',
      );
      expect(file.existsSync(), isTrue);
      expect(file.readAsBytesSync(), [1, 2, 3]);
    });

    test(
      'names the file after shareFilename, honoring the blank fallback',
      () async {
        final item = MediaItem(
          id: 'media-1',
          diveId: 'dive-1',
          mediaType: MediaType.video,
          originalFilename: '',
          takenAt: now,
          createdAt: now,
          updatedAt: now,
        );

        final file = await writeShareTempFile(item, Uint8List.fromList([9]));

        expect(p.basename(file.path), 'dive_video.mp4');
      },
    );

    test('items with the same name get separate files', () async {
      MediaItem named(String id, String name) => MediaItem(
        id: id,
        diveId: 'dive-1',
        mediaType: MediaType.photo,
        originalFilename: name,
        takenAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final a = await writeShareTempFile(
        named('a', 'IMG_1.HEIC'),
        Uint8List.fromList([1]),
        filename: 'IMG_1.jpg',
      );
      final b = await writeShareTempFile(
        named('b', 'IMG_1.jpg'),
        Uint8List.fromList([2]),
      );

      expect(p.basename(a.path), p.basename(b.path));
      expect(a.path, isNot(b.path));
      expect(a.readAsBytesSync(), [1]);
      expect(b.readAsBytesSync(), [2]);
    });
  });
}
