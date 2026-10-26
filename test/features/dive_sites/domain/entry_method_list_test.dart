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

  test('joinEntryMethodNames joins in list order', () {
    expect(
      joinEntryMethodNames(const [
        EntryMethod.backRoll,
        EntryMethod.ladder,
      ], (m) => m.displayName),
      'Back Roll, Ladder',
    );
    expect(joinEntryMethodNames(const [], (m) => m.displayName), '');
  });

  group('exitDiffersFromEntry', () {
    const entry = [EntryMethod.shore, EntryMethod.boat];

    test('empty exits mean same as entry', () {
      expect(exitDiffersFromEntry(entry, const []), isFalse);
    });

    test('the same set in another order is not different', () {
      expect(
        exitDiffersFromEntry(entry, const [
          EntryMethod.boat,
          EntryMethod.shore,
        ]),
        isFalse,
      );
    });

    test('a subset, superset or other set is different', () {
      expect(exitDiffersFromEntry(entry, const [EntryMethod.shore]), isTrue);
      expect(
        exitDiffersFromEntry(entry, const [
          EntryMethod.shore,
          EntryMethod.boat,
          EntryMethod.ladder,
        ]),
        isTrue,
      );
      expect(exitDiffersFromEntry(entry, const [EntryMethod.ladder]), isTrue);
    });

    test('exits with no entries are different', () {
      expect(
        exitDiffersFromEntry(const [], const [EntryMethod.ladder]),
        isTrue,
      );
    });
  });
}
