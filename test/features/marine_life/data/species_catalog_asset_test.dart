import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/marine_life/data/services/species_seed_service.dart';

final _assetPath = p.join('assets', 'data', 'species.json');

/// The bundled catalog itself (issue #4966): one row per species, and every
/// retired id names a row that is still there.
void main() {
  test('no two catalog rows share a scientific name', () async {
    final catalog = SpeciesSeedService.parseCatalog(
      await File(_assetPath).readAsString(),
    );
    final byName = <String, List<String>>{};
    for (final species in catalog.species) {
      final name = species.scientificName?.trim().toLowerCase() ?? '';
      if (name.isEmpty) continue;
      byName.putIfAbsent(name, () => []).add(species.id);
    }
    final twins = {
      for (final entry in byName.entries)
        if (entry.value.length > 1) entry.key: entry.value,
    };
    expect(twins, isEmpty);
  });

  test('every retired id is gone and names a row that is there', () async {
    final catalog = SpeciesSeedService.parseCatalog(
      await File(_assetPath).readAsString(),
    );
    final ids = catalog.species.map((s) => s.id).toSet();
    expect(catalog.retired, isNotEmpty);
    for (final entry in catalog.retired.entries) {
      expect(ids, isNot(contains(entry.key)), reason: entry.key);
      expect(ids, contains(entry.value), reason: entry.value);
    }
  });

  test('a catalog without a retired map retires nothing', () {
    final catalog = SpeciesSeedService.parseCatalog(
      '{"version": 1, "species": []}',
    );
    expect(catalog.retired, isEmpty);
  });
}
