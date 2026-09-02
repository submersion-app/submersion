// Inserts species name and description keys for new catalog rows into every
// ARB file, from the localized file the freshwater generator writes.
//
//   dart run tool/generate_species_arb_keys.dart [tool/data/freshwater_species_localized.json]
//
// No network. Follow with: flutter gen-l10n
import 'dart:convert';
import 'dart:io';

import 'src/species_tool_support.dart';

Future<void> main(List<String> args) async {
  final source = args.isEmpty
      ? 'tool/data/freshwater_species_localized.json'
      : args.first;
  final localized = (jsonDecode(await File(source).readAsString()) as List)
      .cast<Map<String, dynamic>>();

  for (final locale in appLocales) {
    final path = 'lib/l10n/arb/app_$locale.arb';
    final entries = [
      for (final row in localized)
        ArbSpeciesEntry(
          id: row['id'] as String,
          name: (row['names'] as Map<String, dynamic>)[locale] as String,
          description:
              (row['descriptions'] as Map<String, dynamic>)[locale] as String,
        ),
    ];
    final text = await File(path).readAsString();
    final updated = insertSpeciesArbKeys(text, entries);
    jsonDecode(updated); // refuse to write anything that does not parse
    await File(path).writeAsString(updated);
    stdout.writeln('$locale: added ${entries.length * 2} keys');
  }
}
