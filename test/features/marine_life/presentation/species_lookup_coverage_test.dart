import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/presentation/species_description_lookup.dart';
import 'package:submersion/features/marine_life/presentation/species_name_lookup.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

/// Binds the three artifacts that must move together: the bundled asset,
/// the English ARB keys, and the two generated lookup switches. A species
/// added to the asset without its keys or its cases fails here instead of
/// silently rendering in English.
void main() {
  late Map<String, dynamic> raw;
  late List<Map<String, dynamic>> catalog;

  setUpAll(() async {
    raw =
        jsonDecode(await File('assets/data/species.json').readAsString())
            as Map<String, dynamic>;
    catalog = (raw['species'] as List).cast<Map<String, dynamic>>();
  });

  test('the catalog carries a version of at least 2', () {
    expect(raw['version'], isA<int>());
    expect(raw['version'] as int, greaterThanOrEqualTo(2));
  });

  test('ids are unique and slug-shaped', () {
    final ids = catalog.map((r) => r['id'] as String).toList();
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(id, matches(RegExp(r'^sp_[a-z0-9_]+$')));
    }
  });

  test('every row resolves through the English ARB to its own text', () {
    final l10n = AppLocalizationsEn();
    for (final row in catalog) {
      final id = row['id'] as String;
      expect(builtInSpeciesName(l10n, id), row['commonName'], reason: id);
      expect(
        builtInSpeciesDescription(l10n, id),
        row['description'],
        reason: id,
      );
    }
  });

  test('the switches carry no case the catalog lacks', () async {
    final ids = catalog.map((r) => r['id'] as String).toSet();
    for (final path in [
      'lib/features/marine_life/presentation/species_name_lookup.dart',
      'lib/features/marine_life/presentation/species_description_lookup.dart',
    ]) {
      final cases = RegExp(r"^  '(sp_[a-z0-9_]+)' =>", multiLine: true)
          .allMatches(await File(path).readAsString())
          .map((m) => m.group(1)!)
          .toList();
      expect(cases.length, ids.length, reason: path);
      expect(cases.toSet().difference(ids), isEmpty, reason: path);
    }
  });
}
