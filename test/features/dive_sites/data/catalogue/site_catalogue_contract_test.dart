import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/site_type_seed.dart';
import 'package:submersion/core/geography/country_code.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_parser.dart';

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

  test('every contract country resolves to its code in the app', () {
    // The contract's table may lag the app's (an alias the app adds later
    // is fine); a name the catalogue writes must never fail to resolve.
    expect(countries.length, greaterThan(400));
    for (final MapEntry(:key, :value) in countries.entries) {
      expect(countryCodeFor(key), value, reason: key);
    }
  });
}
