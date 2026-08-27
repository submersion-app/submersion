import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface/subsurface_site_folder.dart';

void main() {
  group('foldSubsurfaceSites', () {
    test('leaves the caller\'s site maps untouched', () async {
      final first = <String, dynamic>{'uddfId': 'aaa', 'name': 'Blue Hole'};
      final second = <String, dynamic>{
        'uddfId': 'bbb',
        'name': 'Blue Hole',
        'latitude': 18.465562,
        'longitude': -66.084902,
        'country': 'Puerto Rico',
      };

      final folded = foldSubsurfaceSites([first, second]);

      // The survivor picks up what the first entry was missing...
      expect(folded.sites.length, 1);
      expect(folded.sites[0]['country'], 'Puerto Rico');
      expect(folded.aliases, {'bbb': 'aaa'});

      // ...without writing any of it back into the inputs.
      expect(first, {'uddfId': 'aaa', 'name': 'Blue Hole'});
      expect(second.containsKey('country'), isTrue);
      expect(second['uddfId'], 'bbb');
    });

    test('returns an empty result for no sites', () async {
      final folded = foldSubsurfaceSites([]);
      expect(folded.sites, isEmpty);
      expect(folded.aliases, isEmpty);
    });
  });
}
