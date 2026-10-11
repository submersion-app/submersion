import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';

DiveSite _s(
  String id, {
  String? country,
  String? region,
  String? bodyOfWater,
}) => DiveSite(
  id: id,
  name: id,
  country: country,
  region: region,
  bodyOfWater: bodyOfWater,
);

List<SiteOuterGroup<DiveSite>> _group(List<DiveSite> sites) =>
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
      expect(groups.map((g) => g.key), [_key('Belize'), noGroupKey]);
      expect(groups.last.isUngroupedKey, isTrue);
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
      expect(group.ungrouped.map((s) => s.id), ['n1', 'b1']);
      expect(group.subgroups.map((r) => r.label), [
        'Queensland',
        'western australia',
      ]);
      expect(group.subgroups.first.items.map((s) => s.id), ['q1', 'q2']);
      expect(group.allItems.map((s) => s.id), ['n1', 'b1', 'q1', 'q2', 'w1']);
    });

    test('keeps the input order inside every group', () {
      final group = _group([
        _s('z', country: 'Fiji'),
        _s('a', country: 'Fiji'),
        _s('m', country: 'Fiji'),
      ]).single;
      expect(group.ungrouped.map((s) => s.id), ['z', 'a', 'm']);
    });

    test('groups any item type through siteOf', () {
      final groups = groupSitesByLocation<(DiveSite, int)>([
        (_s('a', country: 'Fiji'), 3),
      ], (pair) => pair.$1);
      expect(groups.single.ungrouped.single.$2, 3);
    });
  });

  group('groupSitesByWater', () {
    List<SiteOuterGroup<DiveSite>> group(List<DiveSite> sites) =>
        groupSitesByWater(sites, (s) => s);

    test('groups by body of water alone, with no subgroups', () {
      final groups = group([
        _s('a', bodyOfWater: 'Red Sea'),
        _s('b', bodyOfWater: 'red sea'),
        _s('c', bodyOfWater: 'Lake Zurich'),
      ]);
      expect(groups.map((g) => g.label), ['Lake Zurich', 'Red Sea']);
      expect(groups.every((g) => g.subgroups.isEmpty), isTrue);
      expect(groups.first.siteCount, 1);
    });

    test('sites with no body of water go to a last ungrouped group', () {
      final groups = group([
        _s('a'),
        _s('b', bodyOfWater: '  '),
        _s('c', bodyOfWater: 'Red Sea'),
      ]);
      expect(groups.map((g) => g.key), [
        siteBodyOfWaterKey(_s('x', bodyOfWater: 'Red Sea')),
        noGroupKey,
      ]);
      expect(groups.last.allItems.map((s) => s.id), ['a', 'b']);
    });
  });

  group('groupSitesByLocationAndWater', () {
    List<SiteOuterGroup<DiveSite>> group(List<DiveSite> sites) =>
        groupSitesByLocationAndWater(sites, (s) => s);

    test('bundles sites with no body of water into their own last subgroup '
        'rather than leaving the outer group ungrouped', () {
      final groups = group([
        _s('a', country: 'Egypt', bodyOfWater: 'Red Sea'),
        _s('b', country: 'Egypt'),
        _s('c', country: 'Egypt', bodyOfWater: 'red sea'),
        _s('d', country: 'Egypt', bodyOfWater: '  '),
      ]);
      final egypt = groups.single;
      expect(egypt.ungrouped, isEmpty);
      expect(egypt.subgroups.map((s) => s.key), [
        textSortKey('Red Sea'),
        noGroupKey,
      ]);
      expect(egypt.subgroups.first.items.map((s) => s.id), ['a', 'c']);
      final ungroupedSub = egypt.subgroups.last;
      expect(ungroupedSub.isUngroupedKey, isTrue);
      expect(ungroupedSub.label, '');
      expect(ungroupedSub.items.map((s) => s.id), ['b', 'd']);
    });
  });

  group('flattenSiteGroups', () {
    final groups = _group([
      _s('fiji1', country: 'Fiji'),
      _s('aus1', country: 'Australia', region: 'Queensland'),
      _s('aus0', country: 'Australia'),
    ]);

    String describe(SiteListRow<DiveSite> row) => switch (row) {
      OuterHeaderRow(:final group, :final isExpanded) =>
        'C:${group.label}:${isExpanded ? 'open' : 'closed'}',
      SubHeaderRow(:final subgroup, :final isExpanded) =>
        'R:${subgroup.label}:${isExpanded ? 'open' : 'closed'}',
      SiteRow(:final item) => 'S:${item.id}',
    };

    test('collapsed outer groups show only their header', () {
      expect(flattenSiteGroups(groups, expanded: const {}).map(describe), [
        'C:Australia:closed',
        'C:Fiji:closed',
      ]);
    });

    test('an expanded outer group lists ungrouped sites, then collapsed '
        'subgroup headers', () {
      expect(
        flattenSiteGroups(groups, expanded: {_key('Australia')}).map(describe),
        ['C:Australia:open', 'S:aus0', 'R:Queensland:closed', 'C:Fiji:closed'],
      );
    });

    test('an expanded subgroup additionally lists its own sites', () {
      final australia = groups.firstWhere((g) => g.label == 'Australia');
      final queensland = australia.subgroups.single;
      expect(
        flattenSiteGroups(
          groups,
          expanded: {
            _key('Australia'),
            subGroupExpansionKey(australia.key, queensland.key),
          },
        ).map(describe),
        [
          'C:Australia:open',
          'S:aus0',
          'R:Queensland:open',
          'S:aus1',
          'C:Fiji:closed',
        ],
      );
    });

    test(
      'a subgroup cannot show its sites while its outer group is closed',
      () {
        final australia = groups.firstWhere((g) => g.label == 'Australia');
        final queensland = australia.subgroups.single;
        expect(
          flattenSiteGroups(
            groups,
            expanded: {subGroupExpansionKey(australia.key, queensland.key)},
          ).map(describe),
          ['C:Australia:closed', 'C:Fiji:closed'],
        );
      },
    );
  });

  group('subGroupExpansionKey', () {
    test('scopes the same subgroup key to different outer groups', () {
      expect(
        subGroupExpansionKey('egypt', 'red-sea'),
        isNot(subGroupExpansionKey('jordan', 'red-sea')),
      );
    });
  });

  group('allSubGroupKeys', () {
    test('lists every subgroup key, scoped to its outer group', () {
      final groups = groupSitesByLocation([
        _s('a', country: 'Australia', region: 'Queensland'),
        _s('b', country: 'Fiji'),
      ], (s) => s);
      final australia = groups.firstWhere((g) => g.label == 'Australia');
      expect(allSubGroupKeys(groups), {
        subGroupExpansionKey(australia.key, australia.subgroups.single.key),
      });
    });
  });

  group('initialExpandedGroups', () {
    test('opens the selected site country', () {
      final groups = _group([
        _s('a', country: 'Fiji'),
        _s('b', country: 'Palau'),
      ]);
      expect(
        initialExpandedGroups(
          groups,
          outerKeyOf: siteCountryKey,
          selected: _s('b', country: 'Palau'),
        ),
        {_key('Palau')},
      );
    });

    test('opens the only group, even No country', () {
      final groups = _group([_s('a'), _s('b')]);
      expect(initialExpandedGroups(groups, outerKeyOf: siteCountryKey), {
        noGroupKey,
      });
    });

    test('opens nothing for several groups and no selection', () {
      final groups = _group([
        _s('a', country: 'Fiji'),
        _s('b', country: 'Palau'),
      ]);
      expect(
        initialExpandedGroups(groups, outerKeyOf: siteCountryKey),
        isEmpty,
      );
    });

    test(
      'also opens the selected site\'s subgroup when innerKeyOf is given',
      () {
        final groups = _group([
          _s('a', country: 'Australia', region: 'Queensland'),
          _s('b', country: 'Australia', region: 'Western Australia'),
        ]);
        final australia = groups.single;
        final selected = _s('a', country: 'Australia', region: 'Queensland');
        expect(
          initialExpandedGroups(
            groups,
            outerKeyOf: siteCountryKey,
            innerKeyOf: innerKeyOfMode(SiteGroupBy.location),
            selected: selected,
          ),
          {
            australia.key,
            subGroupExpansionKey(australia.key, textSortKey('Queensland')),
          },
        );
      },
    );

    test(
      'does not open a subgroup for a selected site with no inner value',
      () {
        final groups = _group([_s('a', country: 'Fiji')]);
        expect(
          initialExpandedGroups(
            groups,
            outerKeyOf: siteCountryKey,
            innerKeyOf: innerKeyOfMode(SiteGroupBy.location),
            selected: _s('a', country: 'Fiji'),
          ),
          {groups.single.key},
        );
      },
    );

    test('opens a selected site\'s bundled "no body of water" subgroup, '
        'unlike a plain no-inner-value site', () {
      final groups = groupSitesByLocationAndWater([
        _s('a', country: 'Egypt'),
        _s('b', country: 'Egypt', bodyOfWater: 'Red Sea'),
      ], (s) => s);
      final egypt = groups.single;
      final selected = _s('a', country: 'Egypt');
      expect(
        initialExpandedGroups(
          groups,
          outerKeyOf: siteCountryKey,
          innerKeyOf: innerKeyOfMode(SiteGroupBy.locationAndWater),
          bundlesInner: bundlesUnlabeledInner(SiteGroupBy.locationAndWater),
          selected: selected,
        ),
        {egypt.key, subGroupExpansionKey(egypt.key, noGroupKey)},
      );
    });
  });

  group('bundlesUnlabeledInner', () {
    test('is true only for the combined country-and-water mode', () {
      expect(bundlesUnlabeledInner(SiteGroupBy.locationAndWater), isTrue);
      expect(bundlesUnlabeledInner(SiteGroupBy.location), isFalse);
      expect(bundlesUnlabeledInner(SiteGroupBy.water), isFalse);
      expect(bundlesUnlabeledInner(SiteGroupBy.none), isFalse);
    });
  });

  test('allGroupKeys lists every group key', () {
    final groups = _group([_s('a', country: 'Fiji'), _s('b')]);
    expect(allGroupKeys(groups), {_key('Fiji'), noGroupKey});
  });

  group('toggleGroupKey', () {
    test('adds a missing key and removes a present one, copying', () {
      const keys = {'a'};
      expect(toggleGroupKey(keys, 'b'), {'a', 'b'});
      expect(toggleGroupKey(keys, 'a'), isEmpty);
      expect(keys, {'a'});
    });
  });

  group('outerKeyOfMode', () {
    test('is the country key for both country-based modes', () {
      final site = _s('a', country: 'Fiji', bodyOfWater: 'Pacific');
      expect(outerKeyOfMode(SiteGroupBy.location)(site), siteCountryKey(site));
      expect(
        outerKeyOfMode(SiteGroupBy.locationAndWater)(site),
        siteCountryKey(site),
      );
    });

    test('is the body of water key for the water-only mode', () {
      final site = _s('a', country: 'Fiji', bodyOfWater: 'Pacific');
      expect(outerKeyOfMode(SiteGroupBy.water)(site), siteBodyOfWaterKey(site));
    });
  });

  group('innerKeyOfMode', () {
    test('is the region key for the location mode', () {
      final site = _s('a', country: 'Fiji', region: 'Viti Levu');
      expect(
        innerKeyOfMode(SiteGroupBy.location)!(site),
        textSortKey('Viti Levu'),
      );
    });

    test('is the body of water key for the combined mode', () {
      final site = _s('a', country: 'Fiji', bodyOfWater: 'Pacific');
      expect(
        innerKeyOfMode(SiteGroupBy.locationAndWater)!(site),
        siteBodyOfWaterKey(site),
      );
    });

    test('is null for modes with no subgrouping', () {
      expect(innerKeyOfMode(SiteGroupBy.none), isNull);
      expect(innerKeyOfMode(SiteGroupBy.water), isNull);
    });
  });

  group('groupSitesFor', () {
    test('returns no groups for SiteGroupBy.none', () {
      expect(
        groupSitesFor(SiteGroupBy.none, [_s('a', country: 'Fiji')], (s) => s),
        isEmpty,
      );
    });

    test('dispatches to the matching grouping function per mode', () {
      final sites = [
        _s('a', country: 'Egypt', bodyOfWater: 'Red Sea'),
        _s('b', country: 'Egypt'),
      ];
      expect(
        groupSitesFor(SiteGroupBy.location, sites, (s) => s).map((g) => g.key),
        groupSitesByLocation(sites, (s) => s).map((g) => g.key),
      );
      expect(
        groupSitesFor(SiteGroupBy.water, sites, (s) => s).map((g) => g.key),
        groupSitesByWater(sites, (s) => s).map((g) => g.key),
      );
      expect(
        groupSitesFor(
          SiteGroupBy.locationAndWater,
          sites,
          (s) => s,
        ).map((g) => g.key),
        groupSitesByLocationAndWater(sites, (s) => s).map((g) => g.key),
      );
    });
  });
}
