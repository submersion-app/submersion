import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';

void main() {
  test('a library row is never destroyable through the profile rule', () {
    expect(
      canDestroySharedItem(
        ownerId: null,
        activeDiverId: 'd',
        isLibrarySite: true,
      ),
      isFalse,
    );
    expect(canDestroySharedItem(ownerId: null, activeDiverId: 'd'), isTrue);
  });

  test('a library row is hideable by any profile that sees it', () {
    expect(
      canHideSharedItem(
        ownerId: null,
        isShared: false,
        activeDiverId: 'd',
        isLibrarySite: true,
      ),
      isTrue,
    );
    expect(
      canHideSharedItem(ownerId: null, isShared: false, activeDiverId: 'd'),
      isFalse,
    );
  });

  test('splitForBulkDelete leaves library rows out of both lists', () {
    final split = splitForBulkDelete<String>(
      ['lib', 'mine'],
      ownerOf: (id) => id == 'mine' ? 'd' : null,
      isSharedOf: (_) => false,
      isLibraryOf: (id) => id == 'lib',
      activeDiverId: 'd',
    );
    expect(split.destroy, ['mine']);
    expect(split.hide, isEmpty);
  });

  test('roles gate edit, delete, manage and suggest', () {
    expect(canEditLibrarySite(SharedLibraryRole.reader), isFalse);
    expect(canEditLibrarySite(SharedLibraryRole.editor), isTrue);
    expect(canDeleteLibrarySite(SharedLibraryRole.editor), isTrue);
    expect(canDeleteLibrarySite(SharedLibraryRole.reader), isFalse);
    expect(canManageLibrary(SharedLibraryRole.editor), isFalse);
    expect(canManageLibrary(SharedLibraryRole.owner), isTrue);
    expect(canSuggestOnLibrarySite(SharedLibraryRole.reader), isTrue);
    expect(canSuggestOnLibrarySite(SharedLibraryRole.owner), isFalse);
  });
}
