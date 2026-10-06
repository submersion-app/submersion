import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';

DiveSite _s(String id, {String? country, String? region}) =>
    DiveSite(id: id, name: id, country: country, region: region);

List<SiteCountryGroup<DiveSite>> _group(List<DiveSite> sites) =>
    groupSitesByLocation(sites, (s) => s);

String _key(String country) => siteCountryKey(_s('x', country: country));

void main() {
  group('groupSitesByLocation', () {
    test('orders countries alphabetically, ignoring case and accents', () {
      final groups = _group([
        _s('a', country: 'mexico'),
        _s('b', country: 'Égypte'),
        _s('c', country: 'Australia'),
      ]);
      expect(groups.map((g) => g.label), ['Australia', 'Égypte', 'mexico']);
    });

    test('folds spellings into one group labelled by the commonest', () {
      final groups = _group([
        _s('a', country: 'australia'),
        _s('b', country: 'Australia '),
        _s('c', country: 'Australia'),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.label, 'Australia');
      expect(groups.single.siteCount, 3);
    });

    test('a spelling tie keeps the first one seen', () {
      final groups = _group([
        _s('a', country: 'australia'),
        _s('b', country: 'Australia'),
      ]);
      expect(groups.single.label, 'australia');
    });

    test('blank and missing countries go to a last No country group', () {
      final groups = _group([
        _s('a'),
        _s('b', country: '   '),
        _s('c', country: 'Belize'),
      ]);
      expect(groups.map((g) => g.key), [_key('Belize'), noCountryGroupKey]);
      expect(groups.last.isNoCountry, isTrue);
      expect(groups.last.label, '');
      expect(groups.last.allItems.map((s) => s.id), ['a', 'b']);
    });

    test('no-region sites come first, then regions alphabetically', () {
      final group = _group([
        _s('q1', country: 'Australia', region: 'Queensland'),
        _s('n1', country: 'Australia'),
        _s('w1', country: 'Australia', region: 'western australia'),
        _s('b1', country: 'Australia', region: ' '),
        _s('q2', country: 'Australia', region: 'queensland'),
      ]).single;
      expect(group.unregioned.map((s) => s.id), ['n1', 'b1']);
      expect(group.regions.map((r) => r.label), [
        'Queensland',
        'western australia',
      ]);
      expect(group.regions.first.items.map((s) => s.id), ['q1', 'q2']);
      expect(group.allItems.map((s) => s.id), ['n1', 'b1', 'q1', 'q2', 'w1']);
    });

    test('keeps the input order inside every group', () {
      final group = _group([
        _s('z', country: 'Fiji'),
        _s('a', country: 'Fiji'),
        _s('m', country: 'Fiji'),
      ]).single;
      expect(group.unregioned.map((s) => s.id), ['z', 'a', 'm']);
    });

    test('groups any item type through siteOf', () {
      final groups = groupSitesByLocation<(DiveSite, int)>([
        (_s('a', country: 'Fiji'), 3),
      ], (pair) => pair.$1);
      expect(groups.single.unregioned.single.$2, 3);
    });
  });

  group('flattenSiteGroups', () {
    final groups = _group([
      _s('fiji1', country: 'Fiji'),
      _s('aus1', country: 'Australia', region: 'Queensland'),
      _s('aus0', country: 'Australia'),
    ]);

    String describe(SiteListRow<DiveSite> row) => switch (row) {
      CountryHeaderRow(:final group, :final isExpanded) =>
        'C:${group.label}:${isExpanded ? 'open' : 'closed'}',
      RegionHeaderRow(:final label) => 'R:$label',
      SiteRow(:final item) => 'S:${item.id}',
    };

    test('collapsed countries show only their header', () {
      expect(flattenSiteGroups(groups, expanded: const {}).map(describe), [
        'C:Australia:closed',
        'C:Fiji:closed',
      ]);
    });

    test('an expanded country lists unregioned sites, then regions', () {
      expect(
        flattenSiteGroups(groups, expanded: {_key('Australia')}).map(describe),
        [
          'C:Australia:open',
          'S:aus0',
          'R:Queensland',
          'S:aus1',
          'C:Fiji:closed',
        ],
      );
    });
  });

  group('initialExpandedCountries', () {
    test('opens the selected site country', () {
      final groups = _group([
        _s('a', country: 'Fiji'),
        _s('b', country: 'Palau'),
      ]);
      expect(
        initialExpandedCountries(groups, selected: _s('b', country: 'Palau')),
        {_key('Palau')},
      );
    });

    test('opens the only group, even No country', () {
      final groups = _group([_s('a'), _s('b')]);
      expect(initialExpandedCountries(groups), {noCountryGroupKey});
    });

    test('opens nothing for several groups and no selection', () {
      final groups = _group([
        _s('a', country: 'Fiji'),
        _s('b', country: 'Palau'),
      ]);
      expect(initialExpandedCountries(groups), isEmpty);
    });
  });

  test('allCountryKeys lists every group key', () {
    final groups = _group([_s('a', country: 'Fiji'), _s('b')]);
    expect(allCountryKeys(groups), {_key('Fiji'), noCountryGroupKey});
  });

  group('toggleCountryKey', () {
    test('adds a missing key and removes a present one, copying', () {
      const keys = {'a'};
      expect(toggleCountryKey(keys, 'b'), {'a', 'b'});
      expect(toggleCountryKey(keys, 'a'), isEmpty);
      expect(keys, {'a'});
    });
  });
}
