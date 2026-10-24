import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';

/// The tag facet of the library filter (issue #1970), which smart albums
/// store and sync.
void main() {
  test('a tag selection makes the filter non-empty', () {
    expect(MediaLibraryFilter.none.tagIds, isEmpty);
    expect(const MediaLibraryFilter(tagIds: {'t1'}).isEmpty, isFalse);
  });

  test('copyWith sets and clears the tag selection', () {
    const filter = MediaLibraryFilter(tagIds: {'t1'}, siteId: 's1');
    expect(filter.copyWith(tagIds: {'t2'}).tagIds, {'t2'});
    expect(filter.copyWith(siteId: null).tagIds, {'t1'});
    expect(filter.copyWith(tagIds: const <String>{}).isEmpty, isFalse);
    expect(
      filter.copyWith(tagIds: const <String>{}, siteId: null).isEmpty,
      isTrue,
    );
  });

  test('equality ignores the order the tags were picked in', () {
    expect(
      const MediaLibraryFilter(tagIds: {'a', 'b'}),
      const MediaLibraryFilter(tagIds: {'b', 'a'}),
    );
    expect(
      const MediaLibraryFilter(tagIds: {'a', 'b'}).hashCode,
      const MediaLibraryFilter(tagIds: {'b', 'a'}).hashCode,
    );
    expect(
      const MediaLibraryFilter(tagIds: {'a'}),
      isNot(const MediaLibraryFilter(tagIds: {'b'})),
    );
  });

  test('the tag selection round-trips through JSON', () {
    const filter = MediaLibraryFilter(tagIds: {'b', 'a'});
    final json = filter.toJson();
    expect(json['tagIds'], ['a', 'b'], reason: 'sorted, so albums compare');
    expect(MediaLibraryFilter.fromJson(json), filter);
  });

  test('an album without tags, or with a bad value, decodes to none', () {
    expect(MediaLibraryFilter.fromJson(const {}).tagIds, isEmpty);
    expect(
      MediaLibraryFilter.fromJson(const {'tagIds': 'not-a-list'}).tagIds,
      isEmpty,
    );
    expect(
      MediaLibraryFilter.fromJson(const {
        'tagIds': ['t1', 3, null],
      }).tagIds,
      {'t1'},
    );
  });

  test('an empty selection is left out of the JSON', () {
    expect(MediaLibraryFilter.none.toJson().containsKey('tagIds'), isFalse);
  });
}
