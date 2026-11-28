import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/library_document_guards.dart';

/// The personal-sync guard for shared library documents (issue #4713).
void main() {
  test('a shared documents row is refused on a device holding none', () {
    final row = {'id': 'x', 'sharedLibraryId': 'L'};
    expect(isLibraryDocumentRow('documents', row, const {}), isTrue);
    expect(withoutLibraryDocumentRows('documents', [row], const {}), isEmpty);
  });

  test('a personal documents row passes', () {
    final row = {'id': 'x', 'sharedLibraryId': null};
    expect(isLibraryDocumentRow('documents', row, const {}), isFalse);
    expect(isLibraryDocumentRow('documents', row, const {'y'}), isFalse);
  });

  test('a child of a local library document is refused', () {
    expect(
      isLibraryDocumentRow('documentPages', {'documentId': 'y'}, const {'y'}),
      isTrue,
    );
  });
}
