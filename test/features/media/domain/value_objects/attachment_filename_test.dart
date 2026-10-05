import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/value_objects/attachment_filename.dart';

void main() {
  group('AttachmentFilename.split', () {
    test('splits on the last dot and keeps the extension case', () {
      final f = AttachmentFilename.split('Bonaire.Map.PDF');
      expect(f.stem, 'Bonaire.Map');
      expect(f.extension, 'PDF');
    });

    test('a name with no dot is all stem', () {
      final f = AttachmentFilename.split('README');
      expect(f.stem, 'README');
      expect(f.extension, '');
    });

    test(
      'a trailing dot is part of the stem, as documentExtension reads it',
      () {
        final f = AttachmentFilename.split('map.');
        expect(f.stem, 'map.');
        expect(f.extension, '');
      },
    );

    test('a leading-dot name has an empty stem', () {
      final f = AttachmentFilename.split('.gpx');
      expect(f.stem, '');
      expect(f.extension, 'gpx');
    });

    test('null is empty', () {
      final f = AttachmentFilename.split(null);
      expect(f.stem, '');
      expect(f.extension, '');
    });
  });

  group('compose', () {
    test('re-attaches the fixed extension and trims the stem', () {
      expect(
        AttachmentFilename.split('a.pdf').compose('  Reef map '),
        'Reef map.pdf',
      );
    });

    test('no extension composes to the bare stem', () {
      expect(AttachmentFilename.split('notes').compose('Notes v2'), 'Notes v2');
    });
  });

  group('validate', () {
    test('accepts an ordinary name', () {
      expect(AttachmentFilename.validate('North wall map'), isNull);
    });

    test('rejects blank and whitespace-only stems', () {
      expect(AttachmentFilename.validate(''), AttachmentNameError.blank);
      expect(AttachmentFilename.validate('   '), AttachmentNameError.blank);
    });

    test('rejects every forbidden character', () {
      for (final ch in ['/', r'\', ':', '*', '?', '"', '<', '>', '|']) {
        expect(
          AttachmentFilename.validate('map${ch}1'),
          AttachmentNameError.forbiddenCharacter,
          reason: ch,
        );
      }
    });

    test('rejects control characters', () {
      expect(
        AttachmentFilename.validate('map${String.fromCharCode(9)}1'),
        AttachmentNameError.forbiddenCharacter,
      );
    });
  });
}
