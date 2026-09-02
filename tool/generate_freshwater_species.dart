// Turns tool/data/freshwater_species_seed.json into catalog rows. Names come
// from iNaturalist, then tool/data/freshwater_species_name_overrides.json
// (hand-authored, locale by locale) fills or corrects them.
//
//   dart run tool/generate_freshwater_species.dart
//
// Network (iNaturalist, one request per species, one per second). Writes
// assets/data/species.json (appended rows, version bumped) and
// tool/data/freshwater_species_localized.json, then prints the follow-ups.
import 'dart:convert';
import 'dart:io';

import 'src/inaturalist_names_client.dart';
import 'src/species_tool_support.dart';

Future<void> main() async {
  final seed =
      (jsonDecode(
                await File(
                  'tool/data/freshwater_species_seed.json',
                ).readAsString(),
              )
              as List)
          .cast<Map<String, dynamic>>();
  final catalogFile = File('assets/data/species.json');
  final catalog =
      jsonDecode(await catalogFile.readAsString()) as Map<String, dynamic>;
  final rows = (catalog['species'] as List).cast<Map<String, dynamic>>();
  final existingIds = rows.map((r) => r['id']).toSet();
  final existingSci = rows
      .map((r) => r['scientificName'])
      .whereType<String>()
      .toSet();

  final seenIds = <String>{};
  for (final entry in seed) {
    final id = entry['id'] as String;
    speciesSlug(id);
    if (!seenIds.add(id)) throw StateError('$id appears twice in the seed');
    if (existingIds.contains(id)) {
      throw StateError('$id already in the catalog');
    }
    if (existingSci.contains(entry['scientificName'])) {
      throw StateError('${entry['scientificName']} already in the catalog');
    }
    final descriptions = entry['description'] as Map<String, dynamic>;
    for (final locale in appLocales) {
      if (descriptions[locale] is! String ||
          (descriptions[locale] as String).isEmpty) {
        throw StateError('$id lacks a $locale description');
      }
    }
  }

  final overridesFile = File(
    'tool/data/freshwater_species_name_overrides.json',
  );
  final overrides = overridesFile.existsSync()
      ? (jsonDecode(await overridesFile.readAsString()) as Map<String, dynamic>)
      : const <String, dynamic>{};

  final client = InaturalistNamesClient();
  final localized = <Map<String, dynamic>>[];
  final added = <Map<String, dynamic>>[];
  try {
    for (final entry in seed) {
      final scientific = entry['scientificName'] as String;
      final taxon = await client.taxonByScientificName(
        scientific,
        taxonId: entry['inaturalistTaxonId'] as int?,
      );
      if (taxon == null) stderr.writeln('No iNaturalist taxon for $scientific');
      final commonName = entry['commonName'] as String;
      final names = applyCuratedNames(
        localizedNamesFromTaxon(taxon ?? const {}, englishFallback: commonName),
        commonName,
        overrides:
            (overrides[entry['id']] as Map<String, dynamic>?) ?? const {},
      );
      added.add({
        'id': entry['id'],
        'commonName': names['en'],
        'scientificName': scientific,
        'category': entry['category'],
        'taxonomyClass': entry['taxonomyClass'],
        'description': (entry['description'] as Map<String, dynamic>)['en'],
      });
      localized.add({
        'id': entry['id'],
        'names': names,
        'descriptions': entry['description'],
      });
      stdout.writeln(
        '${entry['id']}: ${names['en']} (${taxon?['id'] ?? 'no taxon'})',
      );
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  } finally {
    client.close();
  }

  const encoder = JsonEncoder.withIndent('  ');
  await catalogFile.writeAsString(
    '${encoder.convert({
      'version': (catalog['version'] as int? ?? 1) + 1,
      'species': [...rows, ...added],
    })}\n',
  );
  await File(
    'tool/data/freshwater_species_localized.json',
  ).writeAsString('${encoder.convert(localized)}\n');
  stdout.writeln('Added ${added.length} rows. Now run:');
  stdout.writeln('  dart run tool/generate_species_arb_keys.dart');
  stdout.writeln('  flutter gen-l10n');
  stdout.writeln('  dart run tool/generate_species_lookups.dart');
  stdout.writeln('  dart run tool/generate_species_gbif_keys.dart');
}
