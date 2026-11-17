import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/site_type_seed.dart';
import 'package:submersion/core/geography/country_code.dart';
import 'package:submersion/features/dive_sites/data/catalogue/catalogue_enum_names.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_parser.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_withdrawal.dart';

/// The format contract of the catalogue release the app ships, copied from
/// the release by its intake PR (scripts/site_catalogue_intake.py). A
/// release whose contract the app cannot read fails here, in that PR, before
/// it reaches a build.
Map<String, dynamic> _read(String name) =>
    jsonDecode(
          File(
            p.join(
              'test',
              'features',
              'dive_sites',
              'data',
              'catalogue',
              'contract',
              name,
            ),
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

void main() {
  final contract = _read('format.json');
  final countries = (_read('countries.json')['names'] as Map)
      .cast<String, String>();

  test('the catalogue format is one this app reads', () {
    expect(
      contract['format'] as int,
      lessThanOrEqualTo(kSupportedCatalogueFormat),
    );
  });

  test('every site type in the contract is one the app seeds', () {
    final seeded = {for (final t in kBuiltInSiteTypes) t.id};
    expect(seeded, containsAll(contract['site_types'] as List));
  });

  test('every entry method in the contract is an EntryMethod', () {
    final names = EntryMethod.values.map((e) => e.name).toSet();
    expect(names, containsAll(contract['entry_methods'] as List));
  });

  test('every record field the contract lists is one the parser reads', () {
    expect(
      kParsedCatalogueFields,
      containsAll((contract['fields'] as Map).keys),
    );
  });

  test('the parser reads every field it says it reads', () {
    // The set above is kept by hand: each of its fields must be one the
    // parser actually takes from a record, or the gate passes for a field
    // the app drops.
    final source = File(
      p.join(
        'lib',
        'features',
        'dive_sites',
        'data',
        'catalogue',
        'site_catalogue_parser.dart',
      ),
    ).readAsStringSync();
    for (final field in kParsedCatalogueFields) {
      expect(source, contains("raw['$field']"), reason: field);
    }
  });

  test('every trust level and kind in the contract is one the app knows', () {
    // The parser reads an unknown trust as verified and an unknown kind as
    // a dive site: a new value must reach the app before a release uses it.
    expect(
      catalogueTrustByName.keys,
      containsAll(contract['trust_levels'] as List),
    );
    expect(catalogueKindsByName.keys, containsAll(contract['kinds'] as List));
  });

  test('every position_from value in the contract is one the app reads', () {
    // The parser knows only "map"; any other value would read as a stated
    // position and lose the map-read record's wider reach.
    expect(contract['position_from'], ['map']);
  });

  // The contract's hazard_codes are not checked: they are the research
  // evidence's codes, which the pipeline writes into each record as
  // sentences, and the app reads a record's hazards as free text.

  test('every withdrawal reason in the contract is one the app knows', () {
    for (final reason in contract['withdrawal_reasons'] as List) {
      expect(
        catalogueWithdrawalReasonFromName(reason) !=
                CatalogueWithdrawalReason.other ||
            reason == 'other',
        isTrue,
        reason: '$reason',
      );
    }
  });

  test('every contract country resolves to its code in the app', () {
    // The contract's table may lag the app's (an alias the app adds later
    // is fine); a name the catalogue writes must never fail to resolve.
    expect(countries.length, greaterThan(400));
    for (final MapEntry(:key, :value) in countries.entries) {
      expect(countryCodeFor(key), value, reason: key);
    }
  });
}
