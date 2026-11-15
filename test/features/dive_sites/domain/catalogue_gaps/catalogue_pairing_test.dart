import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pairing.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_catalogue_answers.dart';

// About 111 m per 0.001 degree of latitude.
const _here = GeoPoint(12.0000, -68.0000);
const _north40m = GeoPoint(12.00036, -68.0000);
const _north100m = GeoPoint(12.0009, -68.0000);
const _north145m = GeoPoint(12.0013, -68.0000);
const _north156m = GeoPoint(12.0014, -68.0000);

CatalogueSite _record(
  String id,
  String name, {
  GeoPoint? at = _here,
  CatalogueKind kind = CatalogueKind.site,
  CatalogueTrust trust = CatalogueTrust.verified,
  String? countryCode,
  double? maxDepth,
}) => CatalogueSite(
  id: id,
  name: name,
  location: at,
  kind: kind,
  trust: trust,
  countryCode: countryCode,
  maxDepth: maxDepth,
  source: 'osm',
);

DiveSite _site(
  String id,
  String name, {
  GeoPoint? at = _here,
  String? link,
  String? country,
  String? countryCode,
  SiteCatalogueAnswers answers = SiteCatalogueAnswers.empty,
}) => DiveSite(
  id: id,
  name: name,
  location: at,
  catalogueId: link,
  country: country,
  countryCode: countryCode,
  catalogueAnswers: answers,
);

List<CataloguePair> _pair(
  List<DiveSite> sites, {
  Map<String, CatalogueSite> linked = const {},
  Map<String, List<CatalogueSite>> near = const {},
  Map<String, List<CatalogueSite>> named = const {},
  Set<String> claimed = const {},
  Set<String> sitesWithTypes = const {},
}) => pairSitesWithCatalogue(
  sites: sites,
  sitesWithTypes: sitesWithTypes,
  claimed: claimed,
  candidates: PairingCandidates(
    linkedRecords: linked,
    near: near,
    named: named,
  ),
);

void main() {
  group('sure', () {
    test('the same name within reach is a sure pair, listed ticked', () {
      final site = _site('s1', 'Salt Pier');
      final record = _record('r1', 'salt-pier', at: _north40m, maxDepth: 15);

      final pair = _pair(
        [site],
        near: {
          's1': [record],
        },
      ).single;

      expect(pair.kind, CataloguePairKind.sure);
      expect(pair.site, site);
      expect(pair.record, record);
      expect(pair.fields, {CatalogueGapField.depth});
      expect(pair.distanceMeters, closeTo(40, 1));
      expect(pair.addsLink, isTrue);
      expect(pair.preTicked, isTrue);
    });

    test('it is kept even when the record has nothing more to give', () {
      final pair = _pair(
        [_site('s1', 'Salt Pier')],
        near: {
          's1': [_record('r1', 'Salt Pier')],
        },
      ).single;

      expect(pair.kind, CataloguePairKind.sure);
      expect(pair.fields, isEmpty);
    });

    test('just inside the distance pairs, just outside does not', () {
      List<CataloguePair> at(GeoPoint point) => _pair(
        [_site('s1', 'Salt Pier')],
        near: {
          's1': [_record('r1', 'Salt Pier', at: point)],
        },
      );

      expect(at(_north145m), hasLength(1));
      expect(at(_north156m), isEmpty);
    });

    test('an equal name beats a nearer record of another name', () {
      final pair = _pair(
        [_site('s1', 'Barracuda West')],
        near: {
          's1': [
            _record('east', 'Barracuda East', at: _north40m),
            _record('west', 'Barracuda West', at: _north100m),
          ],
        },
      ).single;

      expect(pair.kind, CataloguePairKind.sure);
      expect(pair.record.id, 'west');
    });

    test('of two equal names, a dive site beats a nearer wreck record', () {
      final pair = _pair(
        [_site('s1', 'Hilma Hooker')],
        near: {
          's1': [
            _record('wreck', 'Hilma Hooker', kind: CatalogueKind.register),
            _record('site', 'Hilma Hooker', at: _north100m),
          ],
        },
      ).single;

      expect(pair.record.id, 'site');
    });

    test('of two equal names of one kind, the nearer wins', () {
      final pair = _pair(
        [_site('s1', 'Hilma Hooker')],
        near: {
          's1': [
            _record('far', 'Hilma Hooker', at: _north100m),
            _record('near', 'Hilma Hooker', at: _north40m),
          ],
        },
      ).single;

      expect(pair.record.id, 'near');
    });

    test('a researched record is never listed ticked', () {
      final pair = _pair(
        [_site('s1', 'Salt Pier')],
        near: {
          's1': [_record('r1', 'Salt Pier', trust: CatalogueTrust.researched)],
        },
      ).single;

      expect(pair.kind, CataloguePairKind.sure);
      expect(pair.preTicked, isFalse);
    });
  });

  group('nearby', () {
    test('a record within reach under another name is listed un-ticked', () {
      final pair = _pair(
        [_site('s1', 'Thistlegorm')],
        near: {
          's1': [_record('r1', 'SS Thistlegorm', at: _north40m)],
        },
      ).single;

      expect(pair.kind, CataloguePairKind.nearby);
      expect(pair.distanceMeters, closeTo(40, 1));
      expect(pair.preTicked, isFalse);
    });

    test('a dive site record beats a nearer wreck record', () {
      final pair = _pair(
        [_site('s1', 'My Spot')],
        near: {
          's1': [
            _record(
              'wreck',
              'Tug',
              at: _north40m,
              kind: CatalogueKind.register,
            ),
            _record('site', 'House Reef', at: _north100m),
          ],
        },
      ).single;

      expect(pair.record.id, 'site');
    });

    test('a site with a blank name can still pair by position', () {
      final pair = _pair(
        [_site('s1', '  ')],
        near: {
          's1': [_record('r1', 'House Reef', at: _north40m)],
        },
      ).single;

      expect(pair.kind, CataloguePairKind.nearby);
    });

    test('two blank names are not a sure pair', () {
      final pair = _pair(
        [_site('s1', '?')],
        near: {
          's1': [_record('r1', '!')],
        },
      ).single;

      expect(pair.kind, CataloguePairKind.nearby);
    });
  });

  group('named', () {
    test('a site with no position and one record of its name', () {
      final site = _site('s1', 'Blue Hole', at: null);
      final record = _record('r1', 'Blue Hole');

      final pair = _pair(
        [site],
        named: {
          's1': [record],
        },
      ).single;

      expect(pair.kind, CataloguePairKind.named);
      expect(pair.fields, contains(CatalogueGapField.position));
      expect(pair.distanceMeters, isNull);
      expect(pair.preTicked, isFalse);
    });

    test('two records of the name: no pair', () {
      expect(
        _pair(
          [_site('s1', 'Blue Hole', at: null)],
          named: {
            's1': [_record('r1', 'Blue Hole'), _record('r2', 'Blue Hole')],
          },
        ),
        isEmpty,
      );
    });

    test('no record of the name: no pair', () {
      expect(_pair([_site('s1', 'Blue Hole', at: null)]), isEmpty);
    });

    test("the site's country code narrows two records to one", () {
      final pair = _pair(
        [_site('s1', 'Blue Hole', at: null, countryCode: 'EG')],
        named: {
          's1': [
            _record('eg', 'Blue Hole', countryCode: 'EG'),
            _record('bz', 'Blue Hole', countryCode: 'BZ'),
          ],
        },
      ).single;

      expect(pair.record.id, 'eg');
    });

    test('a country typed as text narrows them too', () {
      final pair = _pair(
        [_site('s1', 'Blue Hole', at: null, country: 'Egypt')],
        named: {
          's1': [
            _record('eg', 'Blue Hole', countryCode: 'EG'),
            _record('bz', 'Blue Hole', countryCode: 'BZ'),
          ],
        },
      ).single;

      expect(pair.record.id, 'eg');
    });

    test('a site in one country is not paired with a record in another', () {
      expect(
        _pair(
          [_site('s1', 'Blue Hole', at: null, countryCode: 'EG')],
          named: {
            's1': [_record('bz', 'Blue Hole', countryCode: 'BZ')],
          },
        ),
        isEmpty,
      );
    });

    test('a namesake another site already has leaves the name ambiguous', () {
      // The diver's other "Blue Hole" is linked to Dahab's record. This
      // one, with no position, is not handed Belize's for being the only
      // one left.
      expect(
        _pair(
          [_site('s1', 'Blue Hole', at: null)],
          named: {
            's1': [
              _record('dahab', 'Blue Hole'),
              _record('belize', 'Blue Hole', at: const GeoPoint(17.3, -87.5)),
            ],
          },
          claimed: {'dahab'},
        ),
        isEmpty,
      );
    });

    test('a namesake a located site just took leaves it ambiguous too', () {
      final dahab = _record('dahab', 'Blue Hole');
      final pairs = _pair(
        [_site('located', 'Blue Hole'), _site('bare', 'Blue Hole', at: null)],
        near: {
          'located': [dahab],
        },
        named: {
          'bare': [
            dahab,
            _record('belize', 'Blue Hole', at: const GeoPoint(17.3, -87.5)),
          ],
        },
      );

      expect([for (final p in pairs) p.site.id], ['located']);
    });

    test('a record without a position is not a candidate', () {
      expect(
        _pair(
          [_site('s1', 'Blue Hole', at: null)],
          named: {
            's1': [_record('r1', 'Blue Hole', at: null)],
          },
        ),
        isEmpty,
      );
    });

    test('a site that has a position is never paired by name alone', () {
      expect(
        _pair(
          [_site('s1', 'Blue Hole')],
          named: {
            's1': [
              _record('r1', 'Blue Hole', at: const GeoPoint(28.57, 34.53)),
            ],
          },
        ),
        isEmpty,
      );
    });
  });

  group('linked', () {
    test('a linked site whose record has more to give is listed ticked', () {
      final site = _site('s1', 'Salt Pier', link: 'r1');
      final record = _record('r1', 'Salt Pier', maxDepth: 15);

      final pair = _pair([site], linked: {'s1': record}).single;

      expect(pair.kind, CataloguePairKind.linked);
      expect(pair.fields, {CatalogueGapField.depth});
      expect(pair.addsLink, isFalse);
      expect(pair.preTicked, isTrue);
    });

    test('a linked site with nothing to take is not listed', () {
      expect(
        _pair(
          [_site('s1', 'Salt Pier', link: 'r1')],
          linked: {'s1': _record('r1', 'Salt Pier')},
        ),
        isEmpty,
      );
    });

    test('a link to a record the catalogue dropped gives nothing', () {
      expect(_pair([_site('s1', 'Salt Pier', link: 'gone')]), isEmpty);
    });

    test('a linked site with no position is listed un-ticked', () {
      final pair = _pair(
        [_site('s1', 'Salt Pier', at: null, link: 'r1')],
        linked: {'s1': _record('r1', 'Salt Pier')},
      ).single;

      expect(pair.kind, CataloguePairKind.linked);
      expect(pair.fields, contains(CatalogueGapField.position));
      expect(pair.preTicked, isFalse);
    });

    test('a linked site is not paired with a neighbouring record', () {
      expect(
        _pair(
          [_site('s1', 'Salt Pier', link: 'r1')],
          linked: {'s1': _record('r1', 'Salt Pier')},
          near: {
            's1': [_record('r2', 'Salt Pier', at: _north40m)],
          },
          claimed: {'r1'},
        ),
        isEmpty,
      );
    });

    test('site types count as filled when the site has some', () {
      const record = CatalogueSite(
        id: 'r1',
        name: 'Salt Pier',
        location: _here,
        typeIds: ['reef'],
        source: 'osm',
      );
      final site = _site('s1', 'Salt Pier', link: 'r1');

      expect(_pair([site], linked: {'s1': record}), hasLength(1));
      expect(
        _pair([site], linked: {'s1': record}, sitesWithTypes: {'s1'}),
        isEmpty,
      );
    });
  });

  group('records that are never candidates', () {
    test('a record another site claims', () {
      expect(
        _pair(
          [_site('s1', 'Salt Pier')],
          near: {
            's1': [_record('r1', 'Salt Pier')],
          },
          claimed: {'r1'},
        ),
        isEmpty,
      );
    });

    test('a site whose own record another site has is not handed a '
        'neighbour', () {
      // The diver has this place twice; the other copy is the linked one.
      expect(
        _pair(
          [_site('s1', 'Salt Pier')],
          near: {
            's1': [
              _record('r1', 'Salt Pier'),
              _record('r2', 'Salt Pier North', at: _north100m),
            ],
          },
          claimed: {'r1'},
        ),
        isEmpty,
      );
    });

    test('a record the site said it is not', () {
      expect(
        _pair(
          [
            _site(
              's1',
              'Thistlegorm',
              answers: const SiteCatalogueAnswers(notSame: {'r1'}),
            ),
          ],
          near: {
            's1': [_record('r1', 'SS Thistlegorm', at: _north40m)],
          },
        ),
        isEmpty,
      );
    });

    test('the next candidate is taken when the first is ruled out', () {
      final pair = _pair(
        [
          _site(
            's1',
            'Thistlegorm',
            answers: const SiteCatalogueAnswers(notSame: {'r1'}),
          ),
        ],
        near: {
          's1': [
            _record('r1', 'SS Thistlegorm', at: _north40m),
            _record('r2', 'Thistlegorm Wreck', at: _north100m),
          ],
        },
      ).single;

      expect(pair.record.id, 'r2');
    });

    test('a named record the site said it is not leaves the other one', () {
      final pair = _pair(
        [
          _site(
            's1',
            'Blue Hole',
            at: null,
            answers: const SiteCatalogueAnswers(notSame: {'r1'}),
          ),
        ],
        named: {
          's1': [_record('r1', 'Blue Hole'), _record('r2', 'Blue Hole')],
        },
      ).single;

      expect(pair.record.id, 'r2');
    });
  });

  group('one record, two sites', () {
    test('the nearer site gets a contested sure record', () {
      final record = _record('r1', 'Salt Pier');
      final pairs = _pair(
        [
          _site('far', 'Salt Pier', at: _north100m),
          _site('near', 'Salt Pier', at: _north40m),
        ],
        near: {
          'far': [record],
          'near': [record],
        },
      );

      expect(pairs.single.site.id, 'near');
    });

    test('the loser takes its next equal-named record', () {
      final contested = _record('r1', 'Salt Pier');
      final other = _record('r2', 'Salt Pier', at: _north145m);
      final pairs = _pair(
        [
          _site('far', 'Salt Pier', at: _north100m),
          _site('near', 'Salt Pier', at: _north40m),
        ],
        near: {
          'far': [contested, other],
          'near': [contested],
        },
      );

      expect(
        {for (final p in pairs) p.site.id: p.record.id},
        {'near': 'r1', 'far': 'r2'},
      );
    });

    test('a sure claim beats a nearer site with another name', () {
      final record = _record('r1', 'Salt Pier');
      final pairs = _pair(
        [
          _site('other', 'Pier Dive', at: _north40m),
          _site('same', 'Salt Pier', at: _north100m),
        ],
        near: {
          'other': [record],
          'same': [record],
        },
      );

      expect(pairs.single.site.id, 'same');
      expect(pairs.single.kind, CataloguePairKind.sure);
    });

    test('a site whose equal-named record went to another gets no pair', () {
      final contested = _record('r1', 'Salt Pier');
      final neighbour = _record('r2', 'Pier South', at: _north40m);
      final pairs = _pair(
        [
          _site('far', 'Salt Pier', at: _north100m),
          _site('near', 'Salt Pier', at: _north40m),
        ],
        near: {
          'far': [contested, neighbour],
          'near': [contested],
        },
      );

      expect(pairs.single.site.id, 'near');
    });

    test('two sites of one name without a position share one record', () {
      final record = _record('r1', 'Blue Hole');
      final pairs = _pair(
        [_site('b', 'Blue Hole', at: null), _site('a', 'Blue Hole', at: null)],
        named: {
          'a': [record],
          'b': [record],
        },
      );

      expect(pairs.single.site.id, 'a');
    });

    test('a record taken by position is not also given by name', () {
      final record = _record('r1', 'Blue Hole');
      final pairs = _pair(
        [_site('located', 'Blue Hole'), _site('bare', 'Blue Hole', at: null)],
        near: {
          'located': [record],
        },
        named: {
          'bare': [record],
        },
      );

      expect(pairs.single.site.id, 'located');
    });
  });

  test('pairs come ticked first, then by kind, each by site name', () {
    final pairs = _pair(
      [
        _site('n', 'Zeta', at: null),
        _site('y', 'Yankee'),
        _site('l', 'Mike', link: 'rl'),
        _site('s', 'Alpha'),
      ],
      linked: {'l': _record('rl', 'Mike', maxDepth: 9)},
      near: {
        's': [_record('rs', 'Alpha')],
        'y': [_record('ry', 'Other', at: _north40m)],
      },
      named: {
        'n': [_record('rn', 'Zeta')],
      },
    );

    expect([for (final p in pairs) p.site.id], ['s', 'l', 'y', 'n']);
  });

  group('the key the notice remembers', () {
    test('names the site, the record and the fields on offer', () {
      final pair = _pair(
        [_site('s1', 'Salt Pier', link: 'r1')],
        linked: {'s1': _record('r1', 'Salt Pier', maxDepth: 15)},
      ).single;

      expect(pair.key, 's1|r1|depth');
    });

    test('changes when the offer grows', () {
      CataloguePair withRecord(CatalogueSite record) => _pair(
        [_site('s1', 'Salt Pier', link: 'r1')],
        linked: {'s1': record},
      ).single;

      final before = withRecord(_record('r1', 'Salt Pier', maxDepth: 15));
      final after = withRecord(
        const CatalogueSite(
          id: 'r1',
          name: 'Salt Pier',
          location: _here,
          maxDepth: 15,
          description: 'Pillars.',
          source: 'osm',
        ),
      );

      expect(after.key, isNot(before.key));
    });
  });
}
