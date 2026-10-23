import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/entry_method_list.dart';

void main() {
  group('encodeEntryMethods', () {
    test('an empty list is stored as null', () {
      expect(encodeEntryMethods(const []), isNull);
    });

    test('a single method is stored exactly as before', () {
      expect(encodeEntryMethods(const [EntryMethod.shore]), 'shore');
    });

    test('several methods are deduplicated and stored in enum order', () {
      expect(
        encodeEntryMethods(const [
          EntryMethod.boat,
          EntryMethod.shore,
          EntryMethod.boat,
        ]),
        'shore,boat',
      );
    });
  });

  group('decodeEntryMethods', () {
    test('null and empty decode to no methods', () {
      expect(decodeEntryMethods(null), isEmpty);
      expect(decodeEntryMethods(''), isEmpty);
    });

    test('a single stored name decodes to one method', () {
      expect(decodeEntryMethods('shore'), [EntryMethod.shore]);
    });

    test('stray spaces and duplicates are tolerated', () {
      expect(decodeEntryMethods('boat, shore,boat'), [
        EntryMethod.shore,
        EntryMethod.boat,
      ]);
    });

    test('unknown names from a newer peer are dropped', () {
      expect(decodeEntryMethods('shore,jetpack'), [EntryMethod.shore]);
      expect(decodeEntryMethods('jetpack'), isEmpty);
    });

    test('every method round-trips on its own', () {
      for (final m in EntryMethod.values) {
        expect(decodeEntryMethods(encodeEntryMethods([m])), [m]);
      }
    });
  });

  test('canonicalEntryMethods dedupes and orders by declaration', () {
    expect(
      canonicalEntryMethods(const [
        EntryMethod.ladder,
        EntryMethod.shore,
        EntryMethod.ladder,
      ]),
      [EntryMethod.shore, EntryMethod.ladder],
    );
  });
}
