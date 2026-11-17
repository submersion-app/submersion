import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_types/domain/favourite_dive_types.dart';

/// Favourite dive types listed first in the pickers (issue #4413).
void main() {
  String idOf(String s) => s;

  group('favouritesFirst', () {
    test('lifts favourites to the front, each group in incoming order', () {
      expect(favouritesFirst(['a', 'b', 'c', 'd'], {'c', 'a'}, idOf: idOf), [
        'a',
        'c',
        'b',
        'd',
      ]);
    });

    test('returns the list itself when nothing is starred', () {
      final all = ['a', 'b'];
      expect(identical(favouritesFirst(all, const {}, idOf: idOf), all), true);
    });

    test('ignores a starred id that matches no entry', () {
      final all = ['a', 'b'];
      expect(identical(favouritesFirst(all, {'zzz'}, idOf: idOf), all), true);
    });
  });

  group('withDiveTypeFavourite', () {
    test('stars an id', () {
      expect(withDiveTypeFavourite({'a'}, 'b', true), {'a', 'b'});
    });

    test('unstars an id', () {
      expect(withDiveTypeFavourite({'a'}, 'a', false), isEmpty);
    });

    test('returns the set itself when nothing changes', () {
      final current = {'a'};
      expect(
        identical(withDiveTypeFavourite(current, 'a', true), current),
        true,
      );
      expect(
        identical(withDiveTypeFavourite(current, 'b', false), current),
        true,
      );
    });
  });
}
