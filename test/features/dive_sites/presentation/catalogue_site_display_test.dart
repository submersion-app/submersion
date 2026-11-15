import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/catalogue_site_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

  const full = CatalogueSite(
    id: 'a',
    name: 'Salt Pier',
    location: GeoPoint(12.08, -68.28),
    country: 'Caribbean Netherlands',
    region: 'Kralendijk',
    locality: 'Belnem',
    island: 'Bonaire',
    minDepth: 5,
    maxDepth: 15,
    typeIds: ['reef', 'pier'],
    entryMethods: [EntryMethod.shore, EntryMethod.ladder],
    source: 'osm',
  );

  group('catalogueDepthRange', () {
    test('joins a minimum and a maximum in the diver\'s unit', () {
      expect(catalogueDepthRange(full, metric), '5m–15m');
      expect(catalogueDepthRange(full, imperial), '16ft–49ft');
    });

    test('shows a lone maximum alone', () {
      const site = CatalogueSite(id: 'a', name: 'A', maxDepth: 30, source: 'x');

      expect(catalogueDepthRange(site, metric), '30m');
      expect(catalogueDepthRange(site, imperial), '98ft');
    });

    test('shows a lone minimum alone', () {
      const site = CatalogueSite(id: 'a', name: 'A', minDepth: 8, source: 'x');

      expect(catalogueDepthRange(site, metric), '8m');
    });

    test('is null without a depth', () {
      const site = CatalogueSite(id: 'a', name: 'A', source: 'x');

      expect(catalogueDepthRange(site, metric), isNull);
    });
  });

  group('cataloguePlace', () {
    test('is the island, else the region, else the country', () {
      expect(cataloguePlace(full), 'Bonaire');
      expect(
        cataloguePlace(
          const CatalogueSite(
            id: 'a',
            name: 'A',
            region: 'Palawan',
            country: 'Philippines',
            source: 'x',
          ),
        ),
        'Palawan',
      );
      expect(
        cataloguePlace(
          const CatalogueSite(
            id: 'a',
            name: 'A',
            country: 'Egypt',
            source: 'x',
          ),
        ),
        'Egypt',
      );
      expect(
        cataloguePlace(const CatalogueSite(id: 'a', name: 'A', source: 'x')),
        isNull,
      );
    });
  });

  group('catalogueLocationLine', () {
    test('lists every place part once, most local first', () {
      expect(
        catalogueLocationLine(full),
        'Belnem, Bonaire, Kralendijk, Caribbean Netherlands',
      );
    });

    test('drops a part that repeats another', () {
      const site = CatalogueSite(
        id: 'a',
        name: 'A',
        island: 'Bonaire',
        region: 'Bonaire',
        country: 'Caribbean Netherlands',
        source: 'x',
      );

      expect(catalogueLocationLine(site), 'Bonaire, Caribbean Netherlands');
    });

    test('is empty without a place', () {
      expect(
        catalogueLocationLine(
          const CatalogueSite(id: 'a', name: 'A', source: 'x'),
        ),
        '',
      );
    });
  });

  group('catalogueWebsiteUri', () {
    test('accepts web addresses', () {
      expect(
        catalogueWebsiteUri('https://example.org/salt-pier'),
        Uri.parse('https://example.org/salt-pier'),
      );
      expect(
        catalogueWebsiteUri(' http://example.org '),
        Uri.parse('http://example.org'),
      );
    });

    test('refuses everything a "Website" button must not open', () {
      // The value comes from a source anyone can edit.
      for (final raw in [
        'tel:+15551234',
        'mailto:shop@example.org',
        'javascript:alert(1)',
        'intent://scan/#Intent;scheme=zxing;end',
        'submersion://settings',
        'file:///etc/passwd',
        'https://',
        'www.example.org',
        'not a link',
        '',
        null,
      ]) {
        expect(catalogueWebsiteUri(raw), isNull, reason: '$raw');
      }
    });
  });

  group('catalogueSiteSummary', () {
    test('joins place, entry, depth and types', () {
      expect(
        catalogueSiteSummary(full, metric, l10n),
        'Bonaire · Shore, Ladder · 5m–15m · Reef, Pier / jetty',
      );
    });

    test('leaves out what is missing, with no stray separator', () {
      const site = CatalogueSite(
        id: 'a',
        name: 'A',
        country: 'Egypt',
        typeIds: ['wreck'],
        source: 'x',
      );

      expect(catalogueSiteSummary(site, metric, l10n), 'Egypt · Wreck');
    });

    test('is empty for a site that has only a name', () {
      expect(
        catalogueSiteSummary(
          const CatalogueSite(id: 'a', name: 'A', source: 'x'),
          metric,
          l10n,
        ),
        '',
      );
    });
  });

  group('catalogueSitePath', () {
    test('is the record\'s own page', () {
      expect(catalogueSitePath('osm_node_1'), '/sites/catalogue/osm_node_1');
    });

    test('keeps an id that is not path-safe in one path segment', () {
      // No id is like this today; a later source's might be.
      final path = catalogueSitePath('researched/blue hole?v=2#a');

      final segments = Uri.parse(path).pathSegments;
      expect(segments, ['sites', 'catalogue', 'researched/blue hole?v=2#a']);
      expect(Uri.parse(path).hasQuery, isFalse);
      expect(Uri.parse(path).hasFragment, isFalse);
    });
  });

  group('catalogueKindLabel', () {
    CatalogueSite register(List<String> types) => CatalogueSite(
      id: 'r',
      name: 'R',
      typeIds: types,
      source: 'ukho',
      kind: CatalogueKind.register,
    );

    test('a record from a dive site source is a built-in dive site', () {
      expect(catalogueKindLabel(full, l10n), 'Built-in dive site');
      // Whatever its types say: a dive site at a wreck is still a dive site.
      expect(
        catalogueKindLabel(
          const CatalogueSite(
            id: 'a',
            name: 'A',
            typeIds: ['wreck'],
            source: 'osm',
          ),
          l10n,
        ),
        'Built-in dive site',
      );
    });

    test('a register record typed as a wreck is a charted wreck', () {
      expect(catalogueKindLabel(register(['wreck']), l10n), 'Charted wreck');
      // A ship sunk as a reef is listed as both.
      expect(
        catalogueKindLabel(register(['artificial_reef', 'wreck']), l10n),
        'Charted wreck',
      );
    });

    test('any other register record is a charted reef', () {
      expect(
        catalogueKindLabel(register(['artificial_reef']), l10n),
        'Charted reef',
      );
      expect(catalogueKindLabel(register([]), l10n), 'Charted reef');
    });
  });

  group('catalogueSourceLinkUri', () {
    const ukho = CatalogueSource(
      key: 'ukho',
      name: 'UK Hydrographic Office Wrecks and Obstructions',
      licence: 'OGL-UK-3.0',
      licenceUrl:
          'https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/',
      credit: 'UK Hydrographic Office',
    );

    CatalogueSite from(String? ref) =>
        CatalogueSite(id: 'a', name: 'A', source: 'ukho', sourceRef: ref);

    test('a record\'s own page, or its dataset\'s, is offered', () {
      expect(
        catalogueSourceLinkUri(
          from('https://www.openstreetmap.org/node/10011808941'),
          ukho,
        ).toString(),
        'https://www.openstreetmap.org/node/10011808941',
      );
      expect(
        catalogueSourceLinkUri(
          from('https://datahub.admiralty.co.uk/portal/apps/sites/#/x'),
          ukho,
        ),
        isNotNull,
      );
    });

    test('the same address as the licence link is not offered twice', () {
      expect(catalogueSourceLinkUri(from(ukho.licenceUrl), ukho), isNull);
    });

    test('a data file to download is not offered', () {
      for (final ref in [
        'https://web.archive.org/web/2024/https://wrecks.example.gov/AWOIS_Wrecks.kml',
        'https://example.org/data/Reefs.ZIP',
        'https://example.org/sites.geojson',
      ]) {
        expect(catalogueSourceLinkUri(from(ref), ukho), isNull, reason: ref);
      }
    });

    test('only a web address is offered', () {
      for (final ref in [
        'mailto:a@example.org',
        'tel:+1',
        'example',
        '',
        null,
      ]) {
        expect(catalogueSourceLinkUri(from(ref), ukho), isNull, reason: '$ref');
      }
    });

    test('a record whose source is not known still gets its link', () {
      expect(
        catalogueSourceLinkUri(from('https://example.org/record/1'), null),
        isNotNull,
      );
    });
  });
}
