import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/import_site_fold.dart';

void main() {
  group('foldImportSites', () {
    test('leaves the caller\'s site maps untouched', () async {
      final first = <String, dynamic>{'uddfId': 'aaa', 'name': 'Blue Hole'};
      final second = <String, dynamic>{
        'uddfId': 'bbb',
        'name': 'Blue Hole',
        'latitude': 18.465562,
        'longitude': -66.084902,
        'country': 'Puerto Rico',
      };

      final folded = foldImportSites([first, second]);

      // The survivor picks up what the first entry was missing...
      expect(folded.sites.length, 1);
      expect(folded.sites[0]['country'], 'Puerto Rico');
      expect(folded.aliases, {'bbb': 'aaa'});

      // ...without writing any of it back into the inputs.
      expect(first, {'uddfId': 'aaa', 'name': 'Blue Hole'});
      expect(second.containsKey('country'), isTrue);
      expect(second['uddfId'], 'bbb');
    });

    test('without foldSameName keeps namesakes apart but still folds '
        'unnamed entries', () async {
      final folded = foldImportSites([
        {
          'uddfId': 'a',
          'name': 'House Reef',
          'latitude': 19.5,
          'longitude': -155.9,
        },
        {
          'uddfId': 'b',
          'name': 'House Reef',
          'latitude': 19.5,
          'longitude': -155.9,
        },
        {'uddfId': 'c', 'latitude': 19.5, 'longitude': -155.9},
      ], foldSameName: false);

      expect(folded.sites.map((s) => s['uddfId']), ['a', 'b']);
      expect(folded.aliases, {'c': 'a'});
    });

    test('a survivor with no id takes the id of the first entry folded '
        'into it', () async {
      final folded = foldImportSites([
        {'name': 'Kealakekua Bay', 'latitude': 19.5, 'longitude': -155.9},
        {'uddfId': 'a', 'latitude': 19.5, 'longitude': -155.9},
        {'uddfId': 'b', 'latitude': 19.5, 'longitude': -155.9},
      ], foldSameName: false);

      expect(folded.sites.single['uddfId'], 'a');
      expect(folded.aliases, {'b': 'a'});
    });

    test('returns an empty result for no sites', () async {
      final folded = foldImportSites([]);
      expect(folded.sites, isEmpty);
      expect(folded.aliases, isEmpty);
    });
  });
}
