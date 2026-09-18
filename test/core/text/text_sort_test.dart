import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/text/text_sort.dart';

void main() {
  group('compareTextForSort', () {
    test('orders names alphabetically regardless of case (issue #2038)', () {
      // A code-unit sort puts every capitalised name first: Plage, Zebra,
      // anchor, plage.
      final names = ['plage', 'Zebra', 'anchor', 'Plage']
        ..sort(compareTextForSort);

      expect(names, ['anchor', 'Plage', 'plage', 'Zebra']);
    });

    test('sorts accented initials with their base letter', () {
      final names = ['Zanzibar', 'Écueil', 'Eel Garden', 'Ark']
        ..sort(compareTextForSort);

      expect(names, ['Ark', 'Écueil', 'Eel Garden', 'Zanzibar']);
    });

    test(
      'breaks case-only ties deterministically, whatever the input order',
      () {
        final forward = ['plage', 'Plage']..sort(compareTextForSort);
        final backward = ['Plage', 'plage']..sort(compareTextForSort);

        expect(forward, ['Plage', 'plage']);
        expect(backward, ['Plage', 'plage']);
      },
    );

    test('equal strings compare as zero', () {
      expect(compareTextForSort('Blue Hole', 'Blue Hole'), 0);
    });
  });

  group('TextCollator', () {
    test('matches compareTextForSort for every pair', () {
      const samples = ['plage', 'Plage', 'Écueil', 'eel', 'Zebra', '', ' a'];
      final collator = TextCollator();
      for (final a in samples) {
        for (final b in samples) {
          expect(
            collator.compare(a, b).sign,
            compareTextForSort(a, b).sign,
            reason: '"$a" vs "$b"',
          );
        }
      }
    });
  });
}
