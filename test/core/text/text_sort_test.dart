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

  group('sortedByText', () {
    test('orders by the folded text without touching the input', () {
      final input = List<String>.unmodifiable(['plage', 'Zebra', 'Écueil']);

      expect(sortedByText(input, (s) => s), ['Écueil', 'plage', 'Zebra']);
      expect(input, ['plage', 'Zebra', 'Écueil']);
    });

    test('re-sorts only within runs sharing a group key', () {
      // SQL already ordered these by category; only the names within each
      // category are out of order.
      final rows = [
        ('fish', 'zebra'),
        ('fish', 'Angel'),
        ('coral', 'staghorn'),
        ('coral', 'Brain'),
        ('fish', 'eel'),
      ];

      expect(sortedByText(rows, (r) => r.$2, groupOf: (r) => r.$1), [
        ('fish', 'Angel'),
        ('fish', 'zebra'),
        ('coral', 'Brain'),
        ('coral', 'staghorn'),
        ('fish', 'eel'),
      ]);
    });

    test('keeps the incoming order of identical names (stable)', () {
      final rows = [for (var i = 0; i < 40; i++) (i, i.isEven ? 'b' : 'a')];

      final sorted = sortedByText(rows, (r) => r.$2);

      final ids = sorted.map((r) => r.$1).toList();
      expect(ids.take(20), [for (var i = 1; i < 40; i += 2) i]);
      expect(ids.skip(20), [for (var i = 0; i < 40; i += 2) i]);
    });
  });
}
