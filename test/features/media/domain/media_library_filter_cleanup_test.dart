import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';

/// The two cleanup facets of the library filter (issue #4148): items with no
/// one tagged, and dive items not placed in their dive. Smart albums store
/// and sync both, so they round-trip through JSON like the other facets.
void main() {
  test('either facet makes the filter non-empty', () {
    expect(MediaLibraryFilter.none.noPeople, isFalse);
    expect(MediaLibraryFilter.none.notPlacedInDive, isFalse);
    expect(const MediaLibraryFilter(noPeople: true).isEmpty, isFalse);
    expect(const MediaLibraryFilter(notPlacedInDive: true).isEmpty, isFalse);
  });

  test('"no one tagged" is not a people selection', () {
    // hasPeople narrows to tagged people; noPeople is its opposite.
    expect(const MediaLibraryFilter(noPeople: true).hasPeople, isFalse);
  });

  test('copyWith sets, keeps and clears both facets', () {
    const filter = MediaLibraryFilter(noPeople: true, notPlacedInDive: true);
    expect(filter.copyWith(siteId: null).noPeople, isTrue);
    expect(filter.copyWith(siteId: null).notPlacedInDive, isTrue);
    expect(
      filter.copyWith(noPeople: false, notPlacedInDive: false).isEmpty,
      isTrue,
    );
    expect(MediaLibraryFilter.none.copyWith(noPeople: true).noPeople, isTrue);
  });

  test('equality and hash take both facets into account', () {
    expect(
      const MediaLibraryFilter(noPeople: true),
      isNot(MediaLibraryFilter.none),
    );
    expect(
      const MediaLibraryFilter(notPlacedInDive: true),
      isNot(MediaLibraryFilter.none),
    );
    expect(
      const MediaLibraryFilter(noPeople: true),
      isNot(const MediaLibraryFilter(notPlacedInDive: true)),
    );
    expect(
      const MediaLibraryFilter(noPeople: true).hashCode,
      const MediaLibraryFilter(noPeople: true).hashCode,
    );
  });

  test('both facets round-trip, and are omitted when off', () {
    const filter = MediaLibraryFilter(noPeople: true, notPlacedInDive: true);
    final json = filter.toJson();
    expect(json['noPeople'], isTrue);
    expect(json['notPlacedInDive'], isTrue);
    expect(MediaLibraryFilter.fromJson(json), filter);

    final none = MediaLibraryFilter.none.toJson();
    expect(none.containsKey('noPeople'), isFalse);
    expect(none.containsKey('notPlacedInDive'), isFalse);
  });

  test('an album saved before these facets decodes with both off', () {
    final old = MediaLibraryFilter.fromJson({'speciesId': 'sp1'});
    expect(old.noPeople, isFalse);
    expect(old.notPlacedInDive, isFalse);
  });

  test('a value that is not true decodes as off', () {
    final odd = MediaLibraryFilter.fromJson({
      'noPeople': 'yes',
      'notPlacedInDive': 1,
    });
    expect(odd.noPeople, isFalse);
    expect(odd.notPlacedInDive, isFalse);
  });
}
