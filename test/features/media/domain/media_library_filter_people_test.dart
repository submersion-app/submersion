import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';

/// The people facet of the library filter (issue #1745), which smart albums
/// store and sync. "Me" is a flag, never a diver id: an album is shared by
/// every profile on the device and shows each one its own photos.
void main() {
  test('a people selection makes the filter non-empty', () {
    expect(MediaLibraryFilter.none.hasPeople, isFalse);
    expect(const MediaLibraryFilter(buddyIds: {'b1'}).isEmpty, isFalse);
    expect(const MediaLibraryFilter(includeMe: true).isEmpty, isFalse);
    expect(const MediaLibraryFilter(includeMe: true).hasPeople, isTrue);
  });

  test('copyWith sets and clears people', () {
    const filter = MediaLibraryFilter(buddyIds: {'b1'}, includeMe: true);
    expect(filter.copyWith(buddyIds: {'b2'}).buddyIds, {'b2'});
    expect(filter.copyWith(siteId: null).includeMe, isTrue);
    expect(
      filter.copyWith(buddyIds: const <String>{}, includeMe: false).isEmpty,
      isTrue,
    );
  });

  test('equality ignores the order buddies were picked in', () {
    expect(
      const MediaLibraryFilter(buddyIds: {'a', 'b'}),
      const MediaLibraryFilter(buddyIds: {'b', 'a'}),
    );
    expect(
      const MediaLibraryFilter(buddyIds: {'a', 'b'}).hashCode,
      const MediaLibraryFilter(buddyIds: {'b', 'a'}).hashCode,
    );
    expect(
      const MediaLibraryFilter(includeMe: true),
      isNot(MediaLibraryFilter.none),
    );
  });

  test('buddyIds and me round-trip, sorted, omitted when empty', () {
    const filter = MediaLibraryFilter(buddyIds: {'b', 'a'}, includeMe: true);
    final json = filter.toJson();
    expect(json['buddyIds'], ['a', 'b']);
    expect(json['me'], isTrue);
    expect(MediaLibraryFilter.fromJson(json), filter);

    final none = MediaLibraryFilter.none.toJson();
    expect(none.containsKey('buddyIds'), isFalse);
    expect(none.containsKey('me'), isFalse);
  });

  test('an album saved before people decodes to no people facet', () {
    final old = MediaLibraryFilter.fromJson({'speciesId': 'sp1'});
    expect(old.buddyIds, isEmpty);
    expect(old.includeMe, isFalse);
  });

  test('unknown keys survive a rewrite through toJson', () {
    final decoded = <String, dynamic>{
      'buddyIds': ['b1'],
      'futureKey': 7,
    };
    final filter = MediaLibraryFilter.fromJson(decoded);
    final rewritten = {
      ...decoded,
      ...filter.copyWith(buddyIds: {'b2'}).toJson(),
    };
    expect(rewritten['futureKey'], 7);
    expect(rewritten['buddyIds'], ['b2']);
  });
}
