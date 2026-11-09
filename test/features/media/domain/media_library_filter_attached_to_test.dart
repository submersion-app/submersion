import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';

/// The Attached to facet of the library filter (issue #4224): what a
/// picture is attached to, which smart albums store and sync.
void main() {
  test('an attachedTo selection makes the filter non-empty', () {
    expect(MediaLibraryFilter.none.attachedTo, isEmpty);
    expect(
      const MediaLibraryFilter(attachedTo: {MediaAttachmentKind.site}).isEmpty,
      isFalse,
    );
  });

  test('equality and hash treat attachedTo as a set', () {
    const a = MediaLibraryFilter(
      attachedTo: {MediaAttachmentKind.site, MediaAttachmentKind.dive},
    );
    const b = MediaLibraryFilter(
      attachedTo: {MediaAttachmentKind.dive, MediaAttachmentKind.site},
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(
      a,
      isNot(const MediaLibraryFilter(attachedTo: {MediaAttachmentKind.dive})),
    );
  });

  test('copyWith keeps, replaces and clears attachedTo', () {
    const filter = MediaLibraryFilter(
      attachedTo: {MediaAttachmentKind.site},
      siteId: 's1',
    );
    expect(filter.copyWith(siteId: null).attachedTo, {
      MediaAttachmentKind.site,
    });
    expect(
      filter.copyWith(attachedTo: {MediaAttachmentKind.unlinked}).attachedTo,
      {MediaAttachmentKind.unlinked},
    );
    expect(
      filter
          .copyWith(attachedTo: const <MediaAttachmentKind>{}, siteId: null)
          .isEmpty,
      isTrue,
    );
  });

  test('toJson writes a sorted list and leaves it out when empty', () {
    const filter = MediaLibraryFilter(
      attachedTo: {MediaAttachmentKind.unlinked, MediaAttachmentKind.dive},
    );
    expect(filter.toJson()['attachedTo'], ['dive', 'unlinked']);
    expect(MediaLibraryFilter.none.toJson().containsKey('attachedTo'), isFalse);
  });

  test('fromJson round-trips the selection', () {
    const filter = MediaLibraryFilter(
      attachedTo: {MediaAttachmentKind.site, MediaAttachmentKind.equipment},
    );
    expect(MediaLibraryFilter.fromJson(filter.toJson()), filter);
  });

  test('fromJson drops names it does not know, and a non-list value', () {
    expect(
      MediaLibraryFilter.fromJson({
        'attachedTo': ['site', 'boat', 7],
      }).attachedTo,
      {MediaAttachmentKind.site},
    );
    expect(
      MediaLibraryFilter.fromJson({'attachedTo': 'site'}).attachedTo,
      isEmpty,
    );
  });

  test('the retired health "unlinked" value still means no constraint', () {
    // Albums saved before August 2026 can hold it. They have shown every
    // picture since the value was removed, and stay that way (issue #4224).
    final filter = MediaLibraryFilter.fromJson({'health': 'unlinked'});
    expect(filter.health, isNull);
    expect(filter.attachedTo, isEmpty);
    expect(filter.isEmpty, isTrue);
  });
}
