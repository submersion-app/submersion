import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_gap_service.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/catalogue_gap_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _record = CatalogueSite(
  id: 'r1',
  name: 'Salt Pier',
  location: GeoPoint(12.0835, -68.2826),
  countryCode: 'BQ',
  country: 'Caribbean Netherlands',
  region: 'Bonaire',
  locality: 'Kralendijk',
  island: 'Bonaire',
  bodyOfWater: 'Caribbean Sea',
  waterType: WaterType.salt,
  minDepth: 5,
  maxDepth: 15,
  typeIds: ['reef', 'wall'],
  entryMethods: [EntryMethod.shore],
  difficulty: SiteDifficulty.beginner,
  hazards: 'Boat traffic',
  description: 'Pillars covered in sponges, with schools of fish between them.',
  source: 'osm',
);

CataloguePair _pair(Set<CatalogueGapField> fields, {String? link}) =>
    CataloguePair(
      site: DiveSite(id: 's1', name: 'Salt Pier', catalogueId: link),
      record: _record,
      kind: link == null ? CataloguePairKind.sure : CataloguePairKind.linked,
      fields: fields,
    );

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

  group('the line that says what a pair adds', () {
    test('leads with the link for a site that has none', () {
      expect(
        catalogueGapAddsLine(_pair({CatalogueGapField.depth}), metric, l10n),
        'Adds: link, 5m–15m',
      );
    });

    test('leaves the link out for a site already linked', () {
      expect(
        catalogueGapAddsLine(
          _pair({CatalogueGapField.depth}, link: 'r1'),
          metric,
          l10n,
        ),
        'Adds: 5m–15m',
      );
    });

    test('names only the chosen details when some are left out', () {
      expect(
        catalogueGapAddsLine(
          _pair({CatalogueGapField.depth, CatalogueGapField.siteTypes}),
          metric,
          l10n,
          fields: {CatalogueGapField.depth},
        ),
        'Adds: link, 5m–15m',
      );
    });

    test('a linked site with nothing chosen is being turned down', () {
      expect(
        catalogueGapAddsLine(
          _pair({CatalogueGapField.depth}, link: 'r1'),
          metric,
          l10n,
          fields: const {},
        ),
        'No thanks',
      );
    });

    test('a pair that only links says so', () {
      expect(catalogueGapAddsLine(_pair({}), metric, l10n), 'Adds: link');
    });

    test('depth follows the diver\'s unit', () {
      expect(
        catalogueGapAddsLine(
          _pair({CatalogueGapField.depth}, link: 'r1'),
          imperial,
          l10n,
        ),
        'Adds: 16ft–49ft',
      );
    });

    test('short details are shown, long ones named', () {
      expect(
        catalogueGapAddsLine(
          _pair({
            CatalogueGapField.position,
            CatalogueGapField.country,
            CatalogueGapField.siteTypes,
            CatalogueGapField.entry,
            CatalogueGapField.hazards,
            CatalogueGapField.description,
          }, link: 'r1'),
          metric,
          l10n,
        ),
        'Adds: GPS Coordinates, Caribbean Netherlands, Reef, Wall, Shore, '
        'Hazards, Description',
      );
    });
  });

  group('the value shown for a field', () {
    String value(CatalogueGapField field, [UnitFormatter units = metric]) =>
        catalogueGapFieldValue(field, _record, units, l10n);

    test('each field reads from the record', () {
      expect(value(CatalogueGapField.position), '12.0835, -68.2826');
      expect(value(CatalogueGapField.depth), '5m–15m');
      expect(value(CatalogueGapField.depth, imperial), '16ft–49ft');
      expect(value(CatalogueGapField.country), 'Caribbean Netherlands');
      expect(value(CatalogueGapField.region), 'Bonaire');
      expect(value(CatalogueGapField.city), 'Kralendijk');
      expect(value(CatalogueGapField.island), 'Bonaire');
      expect(value(CatalogueGapField.bodyOfWater), 'Caribbean Sea');
      expect(value(CatalogueGapField.waterType), 'Salt Water');
      expect(value(CatalogueGapField.siteTypes), 'Reef, Wall');
      expect(value(CatalogueGapField.entry), 'Shore');
      expect(value(CatalogueGapField.difficulty), 'Beginner');
      expect(value(CatalogueGapField.hazards), 'Boat traffic');
    });

    test('a description is shown whole', () {
      expect(value(CatalogueGapField.description), _record.description);
    });

    test('a field the record lacks reads as nothing', () {
      const bare = CatalogueSite(id: 'r2', name: 'X', source: 'osm');
      for (final field in CatalogueGapField.values) {
        expect(catalogueGapFieldValue(field, bare, metric, l10n), '');
      }
    });
  });

  group('the message after applying', () {
    test('says how many sites were linked and how many filled', () {
      expect(
        catalogueApplyResultMessage(
          const CatalogueApplyResult(linked: 3, filled: 1),
          l10n,
        ),
        'Sites linked: 3. Sites with details filled: 1.',
      );
    });

    test('adds how many could not be applied', () {
      expect(
        catalogueApplyResultMessage(
          const CatalogueApplyResult(linked: 3, filled: 1, notApplied: 2),
          l10n,
        ),
        'Sites linked: 3. Sites with details filled: 1. Not applied: 2.',
      );
    });
  });

  test('coordinates are written to four decimal places', () {
    expect(
      catalogueCoordinatesText(const GeoPoint(27.81416, -33.9)),
      '27.8142, -33.9000',
    );
  });

  test('every field has a label', () {
    final labels = {
      for (final field in CatalogueGapField.values)
        catalogueGapFieldLabel(field, l10n),
    };
    expect(labels, hasLength(CatalogueGapField.values.length));
    expect(labels.every((label) => label.isNotEmpty), isTrue);
    expect(
      catalogueGapFieldLabel(CatalogueGapField.depth, l10n),
      'Depth Range',
    );
  });
}
