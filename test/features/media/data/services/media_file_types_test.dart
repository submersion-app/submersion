import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/media/data/services/media_file_types.dart';

void main() {
  group('isLinkableMediaPath', () {
    test('accepts photo and video extensions in any case', () {
      for (final name in [
        'P4204060.jpg',
        'shot.JPEG',
        'scan.png',
        'iphone.HEIC',
        'burst.heif',
        'web.webp',
        'anim.gif',
        'GX010100.MP4',
        'clip.mov',
        'clip.m4v',
      ]) {
        expect(isLinkableMediaPath(p.join('pics', name)), isTrue, reason: name);
      }
    });

    test('rejects dive logs and extensionless files', () {
      for (final name in ['dive.fit', 'log.uddf', 'export.csv', 'README']) {
        expect(
          isLinkableMediaPath(p.join('logs', name)),
          isFalse,
          reason: name,
        );
      }
    });
  });

  group('scanFolderForMediaFiles', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('media_file_types_test');
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    test('returns photos and videos from nested folders, sorted', () async {
      final nested = Directory(p.join(root.path, 'dive 2'))..createSync();
      File(p.join(root.path, 'b.jpg')).writeAsStringSync('x');
      File(p.join(nested.path, 'a.mp4')).writeAsStringSync('x');
      File(p.join(root.path, 'dive.fit')).writeAsStringSync('x');

      final found = await scanFolderForMediaFiles(root.path);

      expect(
        found,
        [p.join(root.path, 'b.jpg'), p.join(nested.path, 'a.mp4')]..sort(),
      );
    });

    test('skips hidden files and folders', () async {
      // AppleDouble sidecars on exFAT camera cards carry the photo's own
      // extension but no image, and would be staged as junk photos.
      final trash = Directory(p.join(root.path, '.Trashes'))..createSync();
      File(p.join(root.path, 'P1.jpg')).writeAsStringSync('x');
      File(p.join(root.path, '._P1.jpg')).writeAsStringSync('x');
      File(p.join(trash.path, 'old.jpg')).writeAsStringSync('x');

      final found = await scanFolderForMediaFiles(root.path);

      expect(found, [p.join(root.path, 'P1.jpg')]);
    });

    test('returns nothing for a folder that does not exist', () async {
      final found = await scanFolderForMediaFiles(p.join(root.path, 'gone'));

      expect(found, isEmpty);
    });
  });
}
