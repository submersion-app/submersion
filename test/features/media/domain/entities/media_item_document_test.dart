import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

MediaItem _doc(String? filename) => MediaItem(
  id: 'm1',
  mediaType: MediaType.document,
  originalFilename: filename,
  takenAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('MediaType.document round-trips through fromString', () {
    expect(MediaType.fromString('document'), MediaType.document);
    expect(MediaType.document.name, 'document');
  });

  test('every MediaType has a display name, including document', () {
    expect(MediaType.document.displayName, 'Document');
    // Guards the switch against a future member being added without a case.
    for (final type in MediaType.values) {
      expect(type.displayName, isNotEmpty, reason: '$type');
    }
  });

  test('isDocument true only for document type', () {
    expect(_doc('map.pdf').isDocument, isTrue);
    expect(
      _doc('map.pdf').copyWith(mediaType: MediaType.photo).isDocument,
      isFalse,
    );
  });

  test('isPdf keys on extension case-insensitively', () {
    expect(_doc('reef-map.pdf').isPdf, isTrue);
    expect(_doc('reef-map.PDF').isPdf, isTrue);
    expect(_doc('notes.docx').isPdf, isFalse);
    expect(_doc(null).isPdf, isFalse);
  });

  test('documentExtension lowercases and strips the dot', () {
    expect(_doc('Map.PDF').documentExtension, 'pdf');
    expect(_doc('notes.docx').documentExtension, 'docx');
    expect(_doc('README').documentExtension, '');
    expect(_doc(null).documentExtension, '');
  });

  test('shareMimeType maps pdf', () {
    expect(_doc('map.pdf').shareMimeType, 'application/pdf');
  });
}
