import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/syntax/query_suggestions.dart';
import 'package:submersion/core/text/fuzzy_match.dart';

/// [suggestNames]'s contract spelled out the slow, obvious way: every
/// candidate scored in full, ties in listing order. It shares no scoring code
/// with the real one, so the two can disagree.
List<String> _reference(String typed, List<String> candidates) {
  final t = typed.toLowerCase();
  final scored = <(int, double)>[];
  for (var i = 0; i < candidates.length; i++) {
    final lower = candidates[i].toLowerCase();
    final double score;
    if (lower.startsWith(t) && t.isNotEmpty) {
      score = 1.0;
    } else {
      final maxLen = max(t.length, lower.length);
      final edit = maxLen == 0 ? 0.0 : 1 - _distance(t, lower) / maxLen;
      score = max(_dice(t, lower), edit);
    }
    if (score >= 0.5) scored.add((i, score));
  }
  scored.sort((a, b) {
    final byScore = b.$2.compareTo(a.$2);
    return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
  });
  return [for (final s in scored.take(5)) candidates[s.$1]];
}

double _dice(String a, String b) {
  final na = normalize(a);
  final nb = normalize(b);
  if (na == nb) return 1.0;
  if (na.length < 2 || nb.length < 2) return 0.0;
  List<String> pairs(String s) => [
    for (var i = 0; i < s.length - 1; i++) s.substring(i, i + 2),
  ];
  final left = pairs(na);
  final right = pairs(nb);
  final total = left.length + right.length;
  var shared = 0;
  for (final pair in left) {
    if (right.remove(pair)) shared++;
  }
  return (2.0 * shared) / total;
}

int _distance(String a, String b) {
  final d = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = 0; i <= a.length; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= b.length; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      d[i][j] = min(
        min(d[i - 1][j] + 1, d[i][j - 1] + 1),
        d[i - 1][j - 1] + cost,
      );
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1);
      }
    }
  }
  return d[a.length][b.length];
}

const _names = [
  'Salt Pier',
  'Salt Pier North',
  'Bonaire',
  'Blue Hole',
  'Blue Heron Bridge',
  'Cancún',
  'Cenote Dos Ojos',
  'Tiefbrunnen Überlingen',
  'Őrség',
  'Manta Point',
  'Molasses Reef',
  'SS Thistlegorm',
  'USS Oriskany',
  'Yongala',
  'Ab',
  'A',
  'aaaa aaaa',
  'name',
  '  Spaced Out  ',
  'Şile',
  'İstanbul',
  '海の家',
  'Reef 𝔊 Garden',
  '',
];

/// A word as a hurried diver might type it.
String _mangle(String word, Random random) {
  if (word.length < 2) return word;
  final at = random.nextInt(word.length - 1);
  return switch (random.nextInt(6)) {
    0 =>
      '${word.substring(0, at)}${word[at + 1]}${word[at]}'
          '${word.substring(at + 2)}',
    1 => word.replaceRange(at, at + 1, ''),
    2 => word.replaceRange(at, at + 1, 'x'),
    3 => word.substring(0, at + 1),
    4 => word.toUpperCase(),
    _ => '$word ${word[at]}',
  };
}

void main() {
  group('suggestNames', () {
    test('a transposition finds a name sharing no bigram with it', () {
      expect(suggestNames('nmae', ['name', 'site']), ['name']);
    });

    test('a prefix always ranks, however long the name', () {
      const long = 'Salt Pier and the long jetty beside the old loading dock';
      expect(suggestNames('sa', [long]), [long]);
    });

    test('accents compare equal', () {
      expect(suggestNames('cancun', ['Cancún', 'Bonaire']), ['Cancún']);
      expect(suggestNames('CANCÚN', ['Cancun']), ['Cancun']);
    });

    test('offers at most five, best first', () {
      expect(
        suggestNames('Salt Pier', [
          'Salt Rock',
          'Salt Pie',
          'Salt Pier 2',
          'Salt Pier',
          'Salt Piers',
          'Salty Pier',
          'Salt Pi',
        ]),
        ['Salt Pier 2', 'Salt Pier', 'Salt Piers', 'Salt Pie', 'Salty Pier'],
      );
    });

    test('nothing close offers nothing', () {
      expect(suggestNames('Bonaire', ['Xqzjw', 'Thistlegorm']), isEmpty);
    });

    test('an empty typed word only matches an empty label', () {
      expect(suggestNames('', ['Salt Pier']), isEmpty);
      expect(suggestNames('', ['']), ['']);
    });

    test('ties keep listing order on a list too long to sort stably', () {
      final names = [for (var i = 0; i < 200; i++) 'Blue $i'];
      expect(suggestNames('blue', names), names.take(5).toList());
    });

    test('agrees with the full scoring on a mixed catalog', () {
      final random = Random(3849);
      for (var round = 0; round < 40; round++) {
        final catalog = [
          ..._names,
          for (var i = 0; i < 30; i++)
            _mangle(_names[random.nextInt(_names.length)], random),
        ];
        final typed = [
          ..._names,
          for (var i = 0; i < 40; i++)
            _mangle(_names[random.nextInt(_names.length)], random),
        ];
        for (final t in typed) {
          expect(
            suggestNames(t, catalog),
            _reference(t, catalog),
            reason: 'typed "$t"',
          );
        }
      }
    });
  });

  group('NameSuggester', () {
    test('reads its candidates once and answers every edit', () {
      var reads = 0;
      Iterable<String> names() sync* {
        reads++;
        yield 'Salt Pier';
        yield 'Bonaire';
      }

      final suggester = NameSuggester(names());
      expect(suggester.suggest('Salt Pi'), ['Salt Pier']);
      expect(suggester.suggest('Salt Pir'), ['Salt Pier']);
      expect(suggester.suggest('Bonaier'), ['Bonaire']);
      expect(suggester.suggest('Xqzjw'), isEmpty);
      expect(reads, 1);
    });

    test('a typed word longer than every name stays in the table', () {
      final near = 'a' * 300;
      final far = 'b' * 300;
      expect(NameSuggester([far, near]).suggest('a' * 500), [near]);
    });

    test('a later comparison does not inherit an earlier one', () {
      final catalog = ['Thistlegorm', 'Yongala', 'name', 'Salt Pier'];
      final suggester = NameSuggester(catalog);
      for (final t in ['nmae', 'Yonagla', 'Thistlegrom', 'Salt Peir', 'nmae']) {
        expect(suggester.suggest(t), _reference(t, catalog), reason: t);
      }
    });

    test('an empty list suggests nothing', () {
      expect(NameSuggester(const []).suggest('Salt Pier'), isEmpty);
    });
  });
}
