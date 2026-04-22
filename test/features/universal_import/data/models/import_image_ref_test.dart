import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';

void main() {
  group('ImportImageRef', () {
    test('preserves fields verbatim', () {
      const ref = ImportImageRef(
        originalPath: '/Users/me/Pictures/shark.jpg',
        diveSourceUuid: 'dive-1',
        caption: 'Shark!',
        position: 2,
        sourceUuid: 'img-1',
      );
      expect(ref.originalPath, '/Users/me/Pictures/shark.jpg');
      expect(ref.diveSourceUuid, 'dive-1');
      expect(ref.caption, 'Shark!');
      expect(ref.position, 2);
      expect(ref.sourceUuid, 'img-1');
    });

    test('optional fields default sensibly', () {
      const ref = ImportImageRef(
        originalPath: 'a.jpg',
        diveSourceUuid: 'dive-1',
      );
      expect(ref.caption, isNull);
      expect(ref.position, 0);
      expect(ref.sourceUuid, isNull);
    });

    group('filename', () {
      test('extracts basename from POSIX path', () {
        const ref = ImportImageRef(
          originalPath: '/Users/me/Pictures/shark.jpg',
          diveSourceUuid: 'd',
        );
        expect(ref.filename, 'shark.jpg');
      });

      test('extracts basename from Windows-style path', () {
        const ref = ImportImageRef(
          originalPath: r'C:\Users\me\Pictures\shark.jpg',
          diveSourceUuid: 'd',
        );
        expect(ref.filename, 'shark.jpg');
      });

      test('returns path unchanged when no separator', () {
        const ref = ImportImageRef(
          originalPath: 'shark.jpg',
          diveSourceUuid: 'd',
        );
        expect(ref.filename, 'shark.jpg');
      });
    });
  });
}
